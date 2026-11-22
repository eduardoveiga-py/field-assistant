import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'jw_email_service.dart';
import 'oauth_token_store.dart';

/// Resultado do fluxo de autenticação do Microsoft Graph
class MicrosoftAuthResult {
  final String email;
  final String? displayName;
  final OAuthTokenBundle tokenBundle;

  const MicrosoftAuthResult({
    required this.email,
    this.displayName,
    required this.tokenBundle,
  });
}

/// Serviço de autenticação e comunicação com Microsoft Graph API v1.0 com PKCE
class MicrosoftOAuthService {
  final http.Client _httpClient;
  final OAuthTokenStore _tokenStore;
  final String clientId;
  final AppLinks _appLinks;

  static const String defaultMicrosoftClientId = String.fromEnvironment(
    'MICROSOFT_CLIENT_ID',
    defaultValue: '',
  );

  static const String redirectUri = 'ministeriopessoal://oauth2redirect';
  static const String authorizationEndpoint =
      'https://login.microsoftonline.com/common/oauth2/v2.0/authorize';
  static const String tokenEndpoint =
      'https://login.microsoftonline.com/common/oauth2/v2.0/token';
  static const String graphBaseUrl = 'https://graph.microsoft.com/v1.0';

  static const List<String> defaultScopes = [
    'offline_access',
    'User.Read',
    'Mail.ReadWrite',
    'Mail.Send',
  ];

  static const Map<String, String> wellKnownFolderMap = {
    'inbox': 'Caixa de Entrada',
    'sentitems': 'Enviadas',
    'drafts': 'Rascunhos',
    'junkemail': 'Spam',
    'deleteditems': 'Lixeira',
  };

  MicrosoftOAuthService({
    http.Client? httpClient,
    OAuthTokenStore? tokenStore,
    String? clientId,
    AppLinks? appLinks,
  }) : _httpClient = httpClient ?? http.Client(),
       _tokenStore = tokenStore ?? const OAuthTokenStore(),
       clientId = clientId ?? defaultMicrosoftClientId,
       _appLinks = appLinks ?? AppLinks();

  /// Gera um Code Verifier seguro e compatível com RFC 7636 (PKCE)
  static String generateCodeVerifier({int length = 64}) {
    final random = Random.secure();
    const charset =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// Gera o Code Challenge S256 correspondente em Base64Url sem padding `=`
  static String generateCodeChallenge(String verifier) {
    final bytes = ascii.encode(verifier);
    final digest = crypto.sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Executa o fluxo de autenticação OAuth 2.0 com PKCE
  Future<MicrosoftAuthResult?> authenticateUser({
    Duration timeout = const Duration(minutes: 5),
  }) async {
    if (clientId.trim().isEmpty) {
      throw Exception(
        'MICROSOFT_CLIENT_ID não configurado. Por favor, adicione sua credencial do Azure AD no arquivo .env ou compile com --dart-define=MICROSOFT_CLIENT_ID=seu_client_id.',
      );
    }

    final verifier = generateCodeVerifier();
    final challenge = generateCodeChallenge(verifier);
    final state = const Uuid().v4();

    final authUri = Uri.parse(authorizationEndpoint).replace(
      queryParameters: {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': redirectUri,
        'response_mode': 'query',
        'scope': defaultScopes.join(' '),
        'state': state,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
      },
    );

    final completer = Completer<Uri>();
    final linkSub = _appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme == 'ministeriopessoal' && uri.host == 'oauth2redirect') {
        if (!completer.isCompleted) {
          completer.complete(uri);
        }
      }
    });

    Uri callbackUri;
    try {
      final launched = await launchUrl(
        authUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception(
          'Não foi possível abrir o navegador para login Microsoft.',
        );
      }

      callbackUri = await completer.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException(
          'Tempo limite esgotado aguardando autorização da conta Microsoft.',
        ),
      );
    } finally {
      await linkSub.cancel();
    }

    final query = callbackUri.queryParameters;
    if (query.containsKey('error')) {
      final desc = query['error_description'] ?? query['error'];
      throw Exception('Erro retornado pela Microsoft: $desc');
    }

    final returnedState = query['state'];
    if (returnedState != state) {
      throw Exception('Falha de integridade CSRF: state divergente recebido.');
    }

    final code = query['code'];
    if (code == null || code.isEmpty) {
      throw Exception(
        'Nenhum código de autorização foi retornado pela Microsoft.',
      );
    }

    // Troca o código pelo bundle de tokens
    final tokenResp = await _httpClient.post(
      Uri.parse(tokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
        'code_verifier': verifier,
      },
    );

    if (tokenResp.statusCode != 200) {
      throw Exception(
        'Falha ao trocar código por token Microsoft (HTTP ${tokenResp.statusCode}): ${tokenResp.body}',
      );
    }

    final tokenData = jsonDecode(tokenResp.body) as Map<String, dynamic>;
    final accessToken = tokenData['access_token'] as String;
    final refreshToken = tokenData['refresh_token'] as String?;
    final expiresIn = tokenData['expires_in'] as int? ?? 3600;
    final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    final scopesReturned =
        (tokenData['scope'] as String?)?.split(' ') ?? defaultScopes;

    final tokenBundle = OAuthTokenBundle(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      scopes: scopesReturned,
    );

    // Consulta perfil do usuário no Graph API para obter e-mail e nome
    String email = '';
    String? displayName;
    try {
      final profileResp = await _httpClient.get(
        Uri.parse('$graphBaseUrl/me'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );
      if (profileResp.statusCode == 200) {
        final profileData =
            jsonDecode(profileResp.body) as Map<String, dynamic>;
        email =
            (profileData['mail'] as String?)?.trim() ??
            (profileData['userPrincipalName'] as String?)?.trim() ??
            '';
        displayName = profileData['displayName'] as String?;
      }
    } catch (_) {}

    return MicrosoftAuthResult(
      email: email,
      displayName: displayName,
      tokenBundle: tokenBundle,
    );
  }

  /// Conveniência: autentica e retorna o bundle de tokens
  Future<OAuthTokenBundle?> authenticate() async {
    final res = await authenticateUser();
    return res?.tokenBundle;
  }

  /// Retorna um token de acesso válido, renovando automaticamente se expirando
  Future<String?> getValidAccessToken(String accountId) async {
    final bundle = await _tokenStore.readTokenBundle(accountId);
    if (bundle == null) return null;

    if (!bundle.isExpiredOrExpiringSoon && bundle.accessToken.isNotEmpty) {
      return bundle.accessToken;
    }

    // Se o token expirou ou expira em breve, renova via refresh_token
    final refreshToken = bundle.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      // Sem refresh_token, retorna o token atual se ainda dentro do prazo absoluto
      if (DateTime.now().isBefore(bundle.expiresAt)) {
        return bundle.accessToken;
      }
      return null;
    }

    try {
      final resp = await _httpClient.post(
        Uri.parse(tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': clientId,
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'scope': (bundle.scopes.isNotEmpty ? bundle.scopes : defaultScopes)
              .join(' '),
        },
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final newAccessToken = data['access_token'] as String;
        final newRefreshToken =
            data['refresh_token'] as String? ?? refreshToken;
        final expiresIn = data['expires_in'] as int? ?? 3600;
        final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
        final scopesReturned =
            (data['scope'] as String?)?.split(' ') ?? bundle.scopes;

        final updated = OAuthTokenBundle(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
          expiresAt: expiresAt,
          scopes: scopesReturned,
        );

        await _tokenStore.saveTokenBundle(accountId, updated);
        return newAccessToken;
      }
    } catch (_) {}

    // Fallback: se a renovação falhar por rede temporária mas o token ainda não venceu
    if (DateTime.now().isBefore(bundle.expiresAt) &&
        bundle.accessToken.isNotEmpty) {
      return bundle.accessToken;
    }

    return null;
  }

  /// Busca mensagens de e-mail das principais pastas do Microsoft Graph
  Future<List<JwEmailMessage>> fetchMessages({
    required String accountId,
    required String accountEmail,
    int maxResults = 30,
  }) async {
    final token = await getValidAccessToken(accountId);
    if (token == null || token.isEmpty) {
      throw Exception('Conta Microsoft não autenticada ou token expirado.');
    }

    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };

    final folders = wellKnownFolderMap.keys.toList();
    final perFolderLimit = (maxResults / folders.length).ceil().clamp(5, 30);
    final messages = <JwEmailMessage>[];
    final seenIds = <String>{};

    for (final folderKey in folders) {
      try {
        final uri = Uri.parse(
          '$graphBaseUrl/me/mailFolders/$folderKey/messages'
          '?\$top=$perFolderLimit'
          '&\$select=id,subject,body,from,toRecipients,ccRecipients,bccRecipients,receivedDateTime,sentDateTime,isRead,hasAttachments',
        );

        final resp = await _httpClient.get(uri, headers: headers);
        if (resp.statusCode != 200) continue;

        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = data['value'] as List<dynamic>? ?? [];

        for (final item in list) {
          if (item is! Map) continue;
          final msgMap = Map<String, dynamic>.from(item);
          final id = msgMap['id'] as String?;
          if (id == null || seenIds.contains(id)) continue;
          seenIds.add(id);

          final parsed = parseGraphMessage(
            msgMap,
            accountEmail: accountEmail,
            folderKey: folderKey,
          );

          // Se tem anexos, busca metadados
          if (parsed != null && (msgMap['hasAttachments'] as bool? ?? false)) {
            final attachments = await _fetchAttachmentMetadata(
              messageId: id,
              headers: headers,
            );
            messages.add(parsed.copyWith(attachments: attachments));
          } else if (parsed != null) {
            messages.add(parsed);
          }
        }
      } catch (_) {}
    }

    return messages;
  }

  Future<List<Map<String, dynamic>>> _fetchAttachmentMetadata({
    required String messageId,
    required Map<String, String> headers,
  }) async {
    try {
      final uri = Uri.parse(
        '$graphBaseUrl/me/messages/$messageId/attachments?\$select=id,name,contentType,size,isInline',
      );
      final resp = await _httpClient.get(uri, headers: headers);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = data['value'] as List<dynamic>? ?? [];
        return list.map((a) {
          final m = Map<String, dynamic>.from(a as Map);
          final name = m['name'] as String? ?? 'anexo';
          final mime =
              m['contentType'] as String? ?? 'application/octet-stream';
          return {
            'name': name,
            'attachmentId': m['id'] ?? '',
            'size': m['size'] as int? ?? 0,
            'contentType': mime,
            'isInline': m['isInline'] as bool? ?? false,
            'type': _determineFileType(name, mime),
            'rawBytes': null, // Download sob demanda
          };
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Faz o parsing de um objeto JSON de mensagem do Microsoft Graph para `JwEmailMessage`
  static JwEmailMessage? parseGraphMessage(
    Map<String, dynamic> msg, {
    required String accountEmail,
    required String folderKey,
  }) {
    final id = msg['id'] as String?;
    if (id == null) return null;

    final subject = msg['subject'] as String? ?? '(Sem assunto)';
    final fromMap = msg['from'] as Map<String, dynamic>?;
    final from =
        fromMap?['emailAddress']?['address'] as String? ?? accountEmail;

    String? extractAddress(dynamic recipient) {
      if (recipient is Map) {
        final emailObj = recipient['emailAddress'];
        if (emailObj is Map) {
          return emailObj['address'] as String?;
        }
      }
      return null;
    }

    final toList = msg['toRecipients'] as List<dynamic>? ?? [];
    final to = toList.map(extractAddress).whereType<String>().join(', ');

    final ccList = msg['ccRecipients'] as List<dynamic>? ?? [];
    final cc = ccList.map(extractAddress).whereType<String>().toList();

    final bccList = msg['bccRecipients'] as List<dynamic>? ?? [];
    final bcc = bccList.map(extractAddress).whereType<String>().toList();

    DateTime date = DateTime.now();
    final dateStr =
        msg['receivedDateTime'] as String? ?? msg['sentDateTime'] as String?;
    if (dateStr != null) {
      date = DateTime.tryParse(dateStr) ?? DateTime.now();
    }

    final isRead = msg['isRead'] as bool? ?? true;
    final isDraft = folderKey == 'drafts';
    final folderName = wellKnownFolderMap[folderKey] ?? 'Caixa de Entrada';

    final bodyMap = msg['body'] as Map<String, dynamic>? ?? {};
    final content = bodyMap['content'] as String? ?? '';
    final contentType = (bodyMap['contentType'] as String? ?? 'text')
        .toLowerCase();

    String bodyText;
    String? bodyHtml;

    if (contentType == 'html') {
      bodyHtml = content;
      bodyText = content.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    } else {
      bodyText = content.trim();
      bodyHtml = null;
    }

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
      bodyText: bodyText,
      bodyHtml: bodyHtml,
      attachments: const [],
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

  /// Download sob demanda de anexo via Graph API
  Future<Uint8List> downloadAttachment({
    required String accountId,
    required String messageId,
    required String attachmentId,
  }) async {
    final token = await getValidAccessToken(accountId);
    if (token == null || token.isEmpty) {
      throw Exception('Conta Microsoft não autenticada.');
    }

    final uri = Uri.parse(
      '$graphBaseUrl/me/messages/$messageId/attachments/$attachmentId',
    );
    final resp = await _httpClient.get(
      uri,
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (resp.statusCode != 200) {
      throw Exception(
        'Falha ao baixar anexo da Microsoft (HTTP ${resp.statusCode}): ${resp.body}',
      );
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data.containsKey('contentBytes')) {
      final b64 = data['contentBytes'] as String? ?? '';
      return base64.decode(b64);
    }

    // Se veio binário direto no body
    return resp.bodyBytes;
  }

  /// Envia um e-mail via endpoint sendMail do Microsoft Graph API
  Future<void> sendEmail({
    required String accountId,
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
      throw Exception('Conta Microsoft não autenticada.');
    }

    final payload = buildSendMailPayload(
      to: to,
      cc: cc,
      bcc: bcc,
      subject: subject,
      bodyText: bodyText,
      bodyHtml: bodyHtml,
      attachments: attachments,
    );

    final uri = Uri.parse('$graphBaseUrl/me/sendMail');
    final resp = await _httpClient.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (resp.statusCode != 200 && resp.statusCode != 202) {
      throw Exception(
        'Erro ao enviar e-mail via Microsoft Graph (HTTP ${resp.statusCode}): ${resp.body}',
      );
    }
  }

  /// Constrói o payload JSON do sendMail para Microsoft Graph
  static Map<String, dynamic> buildSendMailPayload({
    required List<String> to,
    List<String>? cc,
    List<String>? bcc,
    required String subject,
    String? bodyText,
    String? bodyHtml,
    List<Map<String, dynamic>>? attachments,
  }) {
    final hasHtml = bodyHtml != null && bodyHtml.trim().isNotEmpty;
    final messageMap = <String, dynamic>{
      'subject': subject,
      'body': {
        'contentType': hasHtml ? 'HTML' : 'Text',
        'content': hasHtml ? bodyHtml : (bodyText ?? ''),
      },
      'toRecipients': to
          .map(
            (email) => {
              'emailAddress': {'address': email.trim()},
            },
          )
          .toList(),
    };

    if (cc != null && cc.isNotEmpty) {
      messageMap['ccRecipients'] = cc
          .map(
            (email) => {
              'emailAddress': {'address': email.trim()},
            },
          )
          .toList();
    }

    if (bcc != null && bcc.isNotEmpty) {
      messageMap['bccRecipients'] = bcc
          .map(
            (email) => {
              'emailAddress': {'address': email.trim()},
            },
          )
          .toList();
    }

    if (attachments != null && attachments.isNotEmpty) {
      messageMap['attachments'] = attachments.map((att) {
        final name = att['name'] as String? ?? 'anexo';
        final mime =
            att['contentType'] as String? ?? 'application/octet-stream';
        final bytes =
            att['bytes'] as Uint8List? ??
            (att['rawBytes'] as Uint8List? ?? Uint8List(0));
        return {
          '@odata.type': '#microsoft.graph.fileAttachment',
          'name': name,
          'contentType': mime,
          'contentBytes': base64.encode(bytes),
        };
      }).toList();
    }

    return {'message': messageMap, 'saveToSentItems': 'true'};
  }
}
