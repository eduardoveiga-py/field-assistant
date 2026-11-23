import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../core/app_logger.dart';
import 'jw_email_service.dart';
import 'oauth_token_store.dart';

/// Resultado do fluxo de autenticação do Gmail
class GmailAuthResult {
  final String email;
  final String? displayName;
  final OAuthTokenBundle tokenBundle;

  const GmailAuthResult({
    required this.email,
    this.displayName,
    required this.tokenBundle,
  });
}

/// Serviço de integração com o Gmail via OAuth 2.0 e Gmail REST API v1
class GmailOAuthService {
  final http.Client _httpClient;
  final GoogleSignIn _googleSignIn;
  final OAuthTokenStore _tokenStore;

  static const String gmailModifyScope =
      'https://www.googleapis.com/auth/gmail.modify';
  static const String gmailSendScope =
      'https://www.googleapis.com/auth/gmail.send';
  static const String userEmailScope =
      'https://www.googleapis.com/auth/userinfo.email';

  static const List<String> defaultScopes = [
    gmailModifyScope,
    gmailSendScope,
    userEmailScope,
  ];

  static const String defaultWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );
  static const String defaultIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );

  bool _initialized = false;
  String? _lastAuthenticatedEmail;

  GmailOAuthService({
    http.Client? httpClient,
    GoogleSignIn? googleSignIn,
    OAuthTokenStore? tokenStore,
  }) : _httpClient = httpClient ?? http.Client(),
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _tokenStore = tokenStore ?? const OAuthTokenStore();

  String? get lastAuthenticatedEmail => _lastAuthenticatedEmail;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      if (kIsWeb) {
        if (defaultWebClientId.trim().isNotEmpty) {
          await _googleSignIn.initialize(clientId: defaultWebClientId);
        }
      } else {
        final isIos = defaultTargetPlatform == TargetPlatform.iOS;
        final iosClientId = defaultIosClientId.trim();
        await _googleSignIn.initialize(
          clientId: isIos && iosClientId.isNotEmpty ? iosClientId : null,
        );
      }
    } catch (_) {}
    _initialized = true;
  }

  static String? _extractBearerToken(Map<String, String>? headers) {
    if (headers == null || headers.isEmpty) return null;
    final authHeader = headers['Authorization'] ?? headers['authorization'];
    if (authHeader == null || authHeader.isEmpty) return null;
    return authHeader
        .replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '')
        .trim();
  }

  /// Autentica o usuário no Google com os escopos do Gmail
  Future<GmailAuthResult?> authenticateUser() async {
    await _ensureInitialized();
    try {
      if (kIsWeb) {
        Map<String, String>? headers;
        try {
          headers = await _googleSignIn.authorizationClient
              .authorizationHeaders(defaultScopes, promptIfNecessary: true);
        } catch (_) {}

        String? token = _extractBearerToken(headers);

        String email = '';
        String? displayName;

        if (token != null && token.isNotEmpty) {
          try {
            final userinfoResp = await _httpClient.get(
              Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
              headers: {'Authorization': 'Bearer $token'},
            );
            if (userinfoResp.statusCode == 200) {
              final data =
                  jsonDecode(userinfoResp.body) as Map<String, dynamic>;
              email = data['email'] as String? ?? '';
              displayName = data['name'] as String?;
            }
          } catch (_) {}
        }

        if (token == null || token.isEmpty) {
          final account = await _googleSignIn.authenticate(
            scopeHint: defaultScopes,
          );
          email = account.email;
          displayName = account.displayName;
          try {
            final accHeaders = await account.authorizationClient
                .authorizationHeaders(defaultScopes, promptIfNecessary: true);
            token = _extractBearerToken(accHeaders);
          } catch (_) {}
        }

        if (token != null && token.isNotEmpty) {
          _lastAuthenticatedEmail = email;
          final bundle = OAuthTokenBundle(
            accessToken: token,
            refreshToken: null,
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
            scopes: defaultScopes,
          );
          return GmailAuthResult(
            email: email,
            displayName: displayName,
            tokenBundle: bundle,
          );
        }
        return null;
      }

      // Plataformas móveis nativas (iOS e Android)
      final account = await _googleSignIn.authenticate(
        scopeHint: defaultScopes,
      );

      String? token;
      try {
        final headers = await account.authorizationClient.authorizationHeaders(
          defaultScopes,
          promptIfNecessary: true,
        );
        token = _extractBearerToken(headers);
      } catch (e, st) {
        AppLogger.warning(
          'Falha ao obter credenciais/escopos do Google: $e',
          e,
          st,
        );
        throw Exception('Falha ao autorizar escopos do Gmail com o Google: $e');
      }

      if (token != null && token.isNotEmpty) {
        _lastAuthenticatedEmail = account.email;
        final bundle = OAuthTokenBundle(
          accessToken: token,
          refreshToken: null,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          scopes: defaultScopes,
        );
        return GmailAuthResult(
          email: account.email,
          displayName: account.displayName,
          tokenBundle: bundle,
        );
      }
      return null;
    } catch (e, st) {
      AppLogger.warning('Falha na autenticação do Google/Gmail: $e', e, st);
      rethrow;
    }
  }

  /// Conveniência: autentica e retorna o bundle de tokens
  Future<OAuthTokenBundle?> authenticate() async {
    final result = await authenticateUser();
    return result?.tokenBundle;
  }

  /// Retorna um token de acesso válido, renovando silenciosamente se necessário
  Future<String?> getValidAccessToken(String accountId) async {
    final bundle = await _tokenStore.readTokenBundle(accountId);
    if (bundle == null) return null;

    if (!bundle.isExpiredOrExpiringSoon && bundle.accessToken.isNotEmpty) {
      return bundle.accessToken;
    }

    await _ensureInitialized();
    try {
      if (kIsWeb) {
        try {
          final account = await _googleSignIn
              .attemptLightweightAuthentication();
          if (account != null) {
            final headers = await account.authorizationClient
                .authorizationHeaders(defaultScopes, promptIfNecessary: false);
            final newToken = _extractBearerToken(headers);
            if (newToken != null && newToken.isNotEmpty) {
              final updated = OAuthTokenBundle(
                accessToken: newToken,
                refreshToken: bundle.refreshToken,
                expiresAt: DateTime.now().add(const Duration(hours: 1)),
                scopes: bundle.scopes.isNotEmpty
                    ? bundle.scopes
                    : defaultScopes,
              );
              await _tokenStore.saveTokenBundle(accountId, updated);
              return newToken;
            }
          }
        } catch (_) {}

        final headers = await _googleSignIn.authorizationClient
            .authorizationHeaders(defaultScopes, promptIfNecessary: false);
        final authHeader =
            headers?['Authorization'] ?? headers?['authorization'];
        if (authHeader != null) {
          final newToken = authHeader
              .replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '')
              .trim();
          if (newToken.isNotEmpty) {
            final updated = OAuthTokenBundle(
              accessToken: newToken,
              refreshToken: bundle.refreshToken,
              expiresAt: DateTime.now().add(const Duration(hours: 1)),
              scopes: bundle.scopes.isNotEmpty ? bundle.scopes : defaultScopes,
            );
            await _tokenStore.saveTokenBundle(accountId, updated);
            return newToken;
          }
        }
      } else {
        final account = await _googleSignIn.attemptLightweightAuthentication();
        if (account != null) {
          String? newToken;
          try {
            final headers = await account.authorizationClient
                .authorizationHeaders(defaultScopes, promptIfNecessary: false);
            newToken = _extractBearerToken(headers);
          } catch (_) {}
          if (newToken != null && newToken.isNotEmpty) {
            final updated = OAuthTokenBundle(
              accessToken: newToken,
              refreshToken: bundle.refreshToken,
              expiresAt: DateTime.now().add(const Duration(hours: 1)),
              scopes: bundle.scopes.isNotEmpty ? bundle.scopes : defaultScopes,
            );
            await _tokenStore.saveTokenBundle(accountId, updated);
            return newToken;
          }
        }
      }
    } catch (_) {}

    // Fallback: se ainda estiver dentro do prazo real de expiração
    if (DateTime.now().isBefore(bundle.expiresAt) &&
        bundle.accessToken.isNotEmpty) {
      return bundle.accessToken;
    }
    if (bundle.isExpired) {
      return null;
    }
    return bundle.accessToken.isNotEmpty ? bundle.accessToken : null;
  }

  /// Decodificador Base64Url resiliente que repara padding ausente
  static Uint8List decodeBase64UrlBytes(String input) {
    var clean = input.replaceAll('-', '+').replaceAll('_', '/').trim();
    final remainder = clean.length % 4;
    if (remainder > 0) {
      clean += '=' * (4 - remainder);
    }
    return base64.decode(clean);
  }

  /// Decodifica string Base64Url resiliente para UTF-8
  static String decodeBase64UrlString(String input) {
    if (input.isEmpty) return '';
    try {
      return utf8.decode(decodeBase64UrlBytes(input), allowMalformed: true);
    } catch (_) {
      return '';
    }
  }

  /// Mapeia labels do Gmail para as pastas de exibição do Field Assistant
  static String mapLabelToFolderName(List<String> labelIds) {
    if (labelIds.contains('DRAFT')) return 'Rascunhos';
    if (labelIds.contains('SENT')) return 'Enviadas';
    if (labelIds.contains('TRASH')) return 'Lixeira';
    if (labelIds.contains('SPAM')) return 'Spam';
    return 'Caixa de Entrada';
  }

  static Never _throwDescriptiveGmailError(String error) {
    if (error.contains('403') ||
        error.contains('PERMISSION_DENIED') ||
        error.contains('has not been used')) {
      throw Exception(
        'Acesso à Gmail API negado (403). Certifique-se de ativar a "Gmail API" no Google Cloud Console e de que o usuário está cadastrado em Usuários de Teste.',
      );
    }
    if (error.contains('401') || error.contains('UNAUTHENTICATED')) {
      throw Exception(
        'Sessão do Gmail expirada ou não autorizada (401). Reconecte a conta nas Configurações.',
      );
    }
    throw Exception('Falha ao sincronizar Gmail: $error');
  }

  /// Sincroniza e busca mensagens de e-mail do Gmail com paginação real
  Future<List<JwEmailMessage>> fetchMessages({
    required String accountId,
    required String accountEmail,
    int maxResults = 200,
  }) async {
    final token = await getValidAccessToken(accountId);
    if (token == null || token.isEmpty) {
      throw Exception('Conta Gmail não autenticada ou token expirado.');
    }

    final authHeaders = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };

    final labelsToSync = ['INBOX', 'SENT', 'DRAFT', 'SPAM', 'TRASH'];
    final seenMessageIds = <String>{};
    final messages = <JwEmailMessage>[];
    String? lastError;
    var successCalls = 0;

    int getLabelQuota(String labelId) {
      if (maxResults <= 30) {
        return (maxResults / labelsToSync.length).ceil().clamp(1, 30);
      }
      switch (labelId) {
        case 'INBOX':
        case 'SENT':
          return ((maxResults * 60) / 195).round().clamp(5, 100);
        default:
          return ((maxResults * 25) / 195).round().clamp(5, 50);
      }
    }

    for (final labelId in labelsToSync) {
      try {
        final labelQuota = getLabelQuota(labelId);
        final allMessageRefs = <Map<String, dynamic>>[];
        String? pageToken;
        var pageCount = 0;
        const maxPagesPerLabel = 10;

        do {
          pageCount++;
          final remaining = labelQuota - allMessageRefs.length;
          final pageSize = remaining.clamp(1, 50);
          var listUrl =
              'https://gmail.googleapis.com/gmail/v1/users/me/messages?labelIds=$labelId&maxResults=$pageSize';
          if (pageToken != null && pageToken.isNotEmpty) {
            listUrl += '&pageToken=$pageToken';
          }
          final listResp = await _httpClient.get(
            Uri.parse(listUrl),
            headers: authHeaders,
          );
          if (listResp.statusCode != 200) {
            lastError =
                'Gmail API HTTP ${listResp.statusCode}: ${listResp.body}';
            AppLogger.warning(
              'Falha ao listar mensagens da label $labelId: $lastError',
            );
            if (labelId == 'INBOX' && allMessageRefs.isEmpty) {
              _throwDescriptiveGmailError(lastError);
            }
            break;
          }
          successCalls++;

          final listData = jsonDecode(listResp.body) as Map<String, dynamic>;
          final refs = listData['messages'] as List<dynamic>? ?? [];
          for (final r in refs) {
            if (r is Map) {
              allMessageRefs.add(Map<String, dynamic>.from(r));
            }
          }
          pageToken = listData['nextPageToken'] as String?;
        } while (pageToken != null &&
            pageToken.isNotEmpty &&
            allMessageRefs.length < labelQuota &&
            pageCount < maxPagesPerLabel);

        var fetchedForLabel = 0;
        String? lastMessageError;

        // Processa os detalhes das mensagens em lotes paralelos controlados de 6
        const batchSize = 6;
        for (var i = 0; i < allMessageRefs.length; i += batchSize) {
          final batch = allMessageRefs.sublist(
            i,
            (i + batchSize > allMessageRefs.length)
                ? allMessageRefs.length
                : i + batchSize,
          );

          final batchFutures = batch.map((ref) async {
            final id = ref['id'] as String?;
            if (id == null) return null;
            if (seenMessageIds.contains(id)) return null;
            seenMessageIds.add(id);

            try {
              final msgUri = Uri.parse(
                'https://gmail.googleapis.com/gmail/v1/users/me/messages/$id?format=full',
              );
              final msgResp = await _httpClient.get(
                msgUri,
                headers: authHeaders,
              );
              if (msgResp.statusCode == 200) {
                final msgData =
                    jsonDecode(msgResp.body) as Map<String, dynamic>;
                final parsed = parseGmailMessage(
                  msgData,
                  accountEmail: accountEmail,
                  preferredFolder: mapLabelToFolderName([labelId]),
                );
                return parsed;
              } else {
                lastMessageError =
                    'HTTP ${msgResp.statusCode}: ${msgResp.body}';
                AppLogger.warning(
                  'Falha ao buscar mensagem $id: HTTP ${msgResp.statusCode}',
                );
              }
            } catch (e, st) {
              lastMessageError = e.toString();
              AppLogger.warning(
                'Erro ao processar mensagem Gmail $id: $e',
                e,
                st,
              );
            }
            return null;
          });

          final results = await Future.wait(batchFutures);
          for (final parsed in results) {
            if (parsed != null) {
              messages.add(parsed);
              fetchedForLabel++;
            }
          }
        }

        final currentMsgError = lastMessageError;
        if (allMessageRefs.isNotEmpty &&
            fetchedForLabel == 0 &&
            currentMsgError != null) {
          AppLogger.error(
            'Todas as mensagens listadas para a label $labelId falharam ao baixar: $currentMsgError',
          );
          _throwDescriptiveGmailError(currentMsgError);
        }
      } catch (e, st) {
        if (labelId == 'INBOX') rethrow;
        lastError = e.toString();
        AppLogger.warning(
          'Erro na chamada da label $labelId do Gmail: $e',
          e,
          st,
        );
      }
    }

    if (successCalls == 0 && lastError != null) {
      _throwDescriptiveGmailError(lastError);
    }

    return messages;
  }

  /// Faz o parsing de um payload JSON de mensagem do Gmail para `JwEmailMessage`
  static JwEmailMessage? parseGmailMessage(
    Map<String, dynamic> msgData, {
    required String accountEmail,
    String? preferredFolder,
  }) {
    final id = msgData['id'] as String?;
    if (id == null) return null;

    final labelIds =
        (msgData['labelIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final isDraft = labelIds.contains('DRAFT');
    final isRead = !labelIds.contains('UNREAD');
    final folderName = preferredFolder ?? mapLabelToFolderName(labelIds);

    final payload = msgData['payload'] as Map<String, dynamic>? ?? {};
    final headersList = payload['headers'] as List<dynamic>? ?? [];
    final headers = <String, String>{};
    for (final h in headersList) {
      if (h is Map && h['name'] != null && h['value'] != null) {
        headers[(h['name'] as String).toLowerCase()] = h['value'] as String;
      }
    }

    final subject = headers['subject'] ?? '(Sem assunto)';
    final from = headers['from'] ?? accountEmail;
    final to = headers['to'] ?? '';
    final ccRaw = headers['cc'] ?? '';
    final bccRaw = headers['bcc'] ?? '';
    final cc = ccRaw.isNotEmpty
        ? ccRaw
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList()
        : <String>[];
    final bcc = bccRaw.isNotEmpty
        ? bccRaw
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList()
        : <String>[];

    DateTime date = DateTime.now();
    final internalDate = msgData['internalDate'] as String?;
    if (internalDate != null) {
      final millis = int.tryParse(internalDate);
      if (millis != null) {
        date = DateTime.fromMillisecondsSinceEpoch(millis);
      }
    } else if (headers['date'] != null) {
      date = DateTime.tryParse(headers['date']!) ?? DateTime.now();
    }

    // Extração recursiva de corpo e anexos
    final bodyTexts = <String>[];
    final bodyHtmls = <String>[];
    final attachments = <Map<String, dynamic>>[];

    void parsePart(Map<String, dynamic> part) {
      final mimeType = (part['mimeType'] as String? ?? '').toLowerCase().trim();
      final filename = part['filename'] as String? ?? '';
      final body = part['body'] as Map<String, dynamic>? ?? {};
      final attachmentId = body['attachmentId'] as String?;
      final size = body['size'] as int? ?? 0;
      final data = body['data'] as String?;

      if (filename.isNotEmpty || attachmentId != null) {
        attachments.add({
          'name': filename.isNotEmpty ? filename : 'anexo',
          'attachmentId': attachmentId ?? '',
          'size': size,
          'contentType': mimeType.isNotEmpty
              ? mimeType
              : 'application/octet-stream',
          'isInline': false,
          'type': _determineFileType(filename, mimeType),
          'rawBytes': data != null ? decodeBase64UrlBytes(data) : null,
        });
      } else if (mimeType == 'text/plain' && data != null) {
        bodyTexts.add(decodeBase64UrlString(data));
      } else if (mimeType == 'text/html' && data != null) {
        bodyHtmls.add(decodeBase64UrlString(data));
      }

      final subparts = part['parts'] as List<dynamic>?;
      if (subparts != null) {
        for (final sp in subparts) {
          if (sp is Map<String, dynamic>) {
            parsePart(sp);
          } else if (sp is Map) {
            parsePart(Map<String, dynamic>.from(sp));
          }
        }
      }
    }

    parsePart(payload);

    final bodyText = bodyTexts.join('\n\n').trim();
    final bodyHtml = bodyHtmls.isNotEmpty ? bodyHtmls.join('\n') : null;

    final numericUid =
        int.tryParse(id.replaceAll(RegExp(r'\D'), '')) ??
        (id.hashCode.abs() % 1000000000);

    return JwEmailMessage(
      id: id,
      remoteUid: numericUid,
      folderId: folderName,
      folderName: folderName,
      subject: subject,
      from: from,
      to: to,
      cc: cc,
      bcc: bcc,
      accountEmail: accountEmail,
      date: date,
      bodyText: bodyText.isNotEmpty
          ? bodyText
          : (bodyHtml != null
                ? bodyHtml.replaceAll(RegExp(r'<[^>]*>'), '')
                : ''),
      bodyHtml: bodyHtml,
      attachments: attachments,
      isRead: isRead,
      isDraft: isDraft,
    );
  }

  static String _determineFileType(String filename, String mimeType) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf') || mimeType.contains('pdf')) return 'pdf';
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        mimeType.startsWith('image/')) {
      return 'image';
    }
    if (lower.endsWith('.doc') ||
        lower.endsWith('.docx') ||
        lower.endsWith('.txt') ||
        lower.endsWith('.rtf') ||
        mimeType.contains('word') ||
        mimeType.contains('document')) {
      return 'doc';
    }
    return 'file';
  }

  /// Download sob demanda de um anexo do Gmail
  Future<Uint8List> downloadAttachment({
    required String accountId,
    required String messageId,
    required String attachmentId,
  }) async {
    final token = await getValidAccessToken(accountId);
    if (token == null || token.isEmpty) {
      throw Exception('Conta Gmail não autenticada.');
    }

    final uri = Uri.parse(
      'https://gmail.googleapis.com/gmail/v1/users/me/messages/$messageId/attachments/$attachmentId',
    );
    final resp = await _httpClient.get(
      uri,
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (resp.statusCode != 200) {
      throw Exception(
        'Falha ao baixar anexo do Gmail (HTTP ${resp.statusCode}): ${resp.body}',
      );
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final rawBase64 = data['data'] as String? ?? '';
    return decodeBase64UrlBytes(rawBase64);
  }

  /// Envia um e-mail via Gmail REST API montando mensagem RFC 2822
  Future<void> sendEmail({
    required String accountId,
    required String from,
    required List<String> to,
    List<String>? cc,
    List<String>? bcc,
    required String subject,
    String? bodyText,
    String? bodyHtml,
    List<Map<String, dynamic>>? attachments,
  }) async {
    final token = await getValidAccessToken(accountId);
    if (token == null || token.isEmpty) {
      throw Exception('Conta Gmail não autenticada.');
    }

    final rfc2822 = buildRfc2822(
      from: from,
      to: to,
      cc: cc,
      bcc: bcc,
      subject: subject,
      bodyText: bodyText,
      bodyHtml: bodyHtml,
      attachments: attachments,
    );

    final bytes = utf8.encode(rfc2822);
    final rawBase64Url = base64Url.encode(bytes).replaceAll('=', '');

    final uri = Uri.parse(
      'https://gmail.googleapis.com/gmail/v1/users/me/messages/send',
    );
    final resp = await _httpClient.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'raw': rawBase64Url}),
    );

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception(
        'Erro ao enviar e-mail via Gmail REST API (HTTP ${resp.statusCode}): ${resp.body}',
      );
    }
  }

  /// Constrói mensagem compatível com RFC 2822
  static String buildRfc2822({
    required String from,
    required List<String> to,
    List<String>? cc,
    List<String>? bcc,
    required String subject,
    String? bodyText,
    String? bodyHtml,
    List<Map<String, dynamic>>? attachments,
  }) {
    final buffer = StringBuffer();
    final boundaryMixed =
        '===_Mixed_Part_${DateTime.now().millisecondsSinceEpoch}_===';
    final boundaryAlt =
        '===_Alt_Part_${DateTime.now().millisecondsSinceEpoch}_===';
    final hasAttachments = attachments != null && attachments.isNotEmpty;
    final hasHtml = bodyHtml != null && bodyHtml.trim().isNotEmpty;

    String encodeHeader(String val) {
      final sanitized = val.replaceAll('\r', '').replaceAll('\n', '');
      final isAscii = RegExp(r'^[\x00-\x7F]*$').hasMatch(sanitized);
      if (isAscii) return sanitized;
      return '=?UTF-8?B?${base64.encode(utf8.encode(sanitized))}?=';
    }

    String formatRfcDate(DateTime dt) {
      final utc = dt.toUtc();
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      String two(int n) => n.toString().padLeft(2, '0');
      return '${weekdays[utc.weekday - 1]}, ${two(utc.day)} ${months[utc.month - 1]} '
          '${utc.year} ${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)} +0000';
    }

    buffer.write('From: $from\r\n');
    buffer.write('To: ${to.join(', ')}\r\n');
    if (cc != null && cc.isNotEmpty) {
      buffer.write('Cc: ${cc.join(', ')}\r\n');
    }
    if (bcc != null && bcc.isNotEmpty) {
      buffer.write('Bcc: ${bcc.join(', ')}\r\n');
    }
    buffer.write('Subject: ${encodeHeader(subject)}\r\n');
    buffer.write('Date: ${formatRfcDate(DateTime.now())}\r\n');
    buffer.write('MIME-Version: 1.0\r\n');

    if (hasAttachments) {
      buffer.write(
        'Content-Type: multipart/mixed; boundary="$boundaryMixed"\r\n\r\n',
      );

      // Parte do conteúdo textual
      buffer.write('--$boundaryMixed\r\n');
      if (hasHtml) {
        buffer.write(
          'Content-Type: multipart/alternative; boundary="$boundaryAlt"\r\n\r\n',
        );
        buffer.write('--$boundaryAlt\r\n');
        buffer.write('Content-Type: text/plain; charset=UTF-8\r\n');
        buffer.write('Content-Transfer-Encoding: 8bit\r\n\r\n');
        buffer.write('${bodyText ?? ''}\r\n\r\n');
        buffer.write('--$boundaryAlt\r\n');
        buffer.write('Content-Type: text/html; charset=UTF-8\r\n');
        buffer.write('Content-Transfer-Encoding: 8bit\r\n\r\n');
        buffer.write('$bodyHtml\r\n\r\n');
        buffer.write('--$boundaryAlt--\r\n');
      } else {
        buffer.write('Content-Type: text/plain; charset=UTF-8\r\n');
        buffer.write('Content-Transfer-Encoding: 8bit\r\n\r\n');
        buffer.write('${bodyText ?? ''}\r\n\r\n');
      }

      // Anexos
      for (final att in attachments) {
        final name = att['name'] as String? ?? 'anexo';
        final mime =
            att['contentType'] as String? ?? 'application/octet-stream';
        final bytes =
            att['bytes'] as Uint8List? ??
            (att['rawBytes'] as Uint8List? ?? Uint8List(0));

        buffer.write('--$boundaryMixed\r\n');
        buffer.write('Content-Type: $mime; name="${encodeHeader(name)}"\r\n');
        buffer.write(
          'Content-Disposition: attachment; filename="${encodeHeader(name)}"\r\n',
        );
        buffer.write('Content-Transfer-Encoding: base64\r\n\r\n');

        final b64 = base64.encode(bytes);
        // Divide em linhas de 76 chars
        for (int i = 0; i < b64.length; i += 76) {
          final end = (i + 76 < b64.length) ? i + 76 : b64.length;
          buffer.write('${b64.substring(i, end)}\r\n');
        }
        buffer.write('\r\n');
      }

      buffer.write('--$boundaryMixed--\r\n');
    } else if (hasHtml) {
      buffer.write(
        'Content-Type: multipart/alternative; boundary="$boundaryAlt"\r\n\r\n',
      );
      buffer.write('--$boundaryAlt\r\n');
      buffer.write('Content-Type: text/plain; charset=UTF-8\r\n');
      buffer.write('Content-Transfer-Encoding: 8bit\r\n\r\n');
      buffer.write('${bodyText ?? ''}\r\n\r\n');
      buffer.write('--$boundaryAlt\r\n');
      buffer.write('Content-Type: text/html; charset=UTF-8\r\n');
      buffer.write('Content-Transfer-Encoding: 8bit\r\n\r\n');
      buffer.write('$bodyHtml\r\n\r\n');
      buffer.write('--$boundaryAlt--\r\n');
    } else {
      buffer.write('Content-Type: text/plain; charset=UTF-8\r\n');
      buffer.write('Content-Transfer-Encoding: 8bit\r\n\r\n');
      buffer.write('${bodyText ?? ''}\r\n');
    }

    return buffer.toString();
  }
}
