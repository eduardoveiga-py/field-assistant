import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../core/app_logger.dart';
import 'email_html_sanitizer.dart';
import 'jw_email_service.dart';
import 'oauth_token_store.dart';
import 'web_url_cleaner.dart';

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
    defaultValue: '15f221b3-c233-4f70-96b0-2b2a62229222',
  );

  static const String redirectUri = 'ministeriopessoal://oauth2redirect';

  /// Retorna o URI de redirecionamento apropriado para a plataforma (Web ou nativo)
  static String getEffectiveRedirectUri() {
    if (kIsWeb) {
      final base = Uri.base;
      var path = base.path;
      if (!path.endsWith('/')) {
        path = '$path/';
      }
      return '${base.origin}$path';
    }
    return redirectUri;
  }

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
    final effectiveRedirect = getEffectiveRedirectUri();

    final authUri = Uri.parse(authorizationEndpoint).replace(
      queryParameters: {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': effectiveRedirect,
        'response_mode': 'query',
        'scope': defaultScopes.join(' '),
        'state': state,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
      },
    );

    if (kIsWeb) {
      // Na Web, salva verifier e state para conferência no retorno e redireciona no mesmo contexto
      await _tokenStore.savePendingWebAuth(state: state, verifier: verifier);
      final launched = await launchUrl(authUri, webOnlyWindowName: '_self');
      if (!launched) {
        throw Exception(
          'Não foi possível redirecionar para a autenticação da Microsoft.',
        );
      }
      return null;
    }

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
        'redirect_uri': effectiveRedirect,
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

  /// Verifica se a aplicação foi aberta com retorno OAuth da Microsoft via Web Redirect
  Future<MicrosoftAuthResult?> checkAndCompleteWebRedirect() async {
    if (!kIsWeb) return null;
    final query = Uri.base.queryParameters;
    final code = query['code'];
    final state = query['state'];
    if (code == null || code.isEmpty) return null;

    final pending = await _tokenStore.readPendingWebAuth();
    if (pending == null) return null;

    final savedState = pending['state'];
    final verifier = pending['verifier'];

    if (savedState == null || verifier == null || savedState != state) {
      await _tokenStore.clearPendingWebAuth();
      cleanWebUrlQuery();
      AppLogger.warning(
        'Falha de integridade CSRF no retorno da Microsoft: state divergente.',
      );
      return null;
    }

    try {
      final effectiveRedirect = getEffectiveRedirectUri();
      final tokenResp = await _httpClient.post(
        Uri.parse(tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': clientId,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': effectiveRedirect,
          'code_verifier': verifier,
        },
      );

      if (tokenResp.statusCode != 200) {
        AppLogger.warning(
          'Falha ao trocar código por token Microsoft na Web (HTTP ${tokenResp.statusCode}): ${tokenResp.body}',
        );
        return null;
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
    } finally {
      await _tokenStore.clearPendingWebAuth();
      cleanWebUrlQuery();
    }
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

  /// Busca mensagens de e-mail das principais pastas do Microsoft Graph com paginação real.
  ///
  /// Quando [knownMessageIds] contém o ID da mensagem, evita baixar anexos novamente,
  /// retornando apenas os metadados de estado (`isRead`, pasta) para reconciliação.
  Future<List<JwEmailMessage>> fetchMessages({
    required String accountId,
    required String accountEmail,
    int maxResults = 200,
    Set<String> knownMessageIds = const {},
    List<String>? folderWarnings,
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
    final messages = <JwEmailMessage>[];
    final seenIds = <String>{};
    String? lastError;
    var successCalls = 0;

    int getFolderQuota(String folderKey) {
      if (maxResults <= 30) {
        return (maxResults / folders.length).ceil().clamp(1, 30);
      }
      switch (folderKey) {
        case 'inbox':
        case 'sentitems':
          return ((maxResults * 60) / 195).round().clamp(5, 100);
        default:
          return ((maxResults * 25) / 195).round().clamp(5, 50);
      }
    }

    for (final folderKey in folders) {
      try {
        final folderQuota = getFolderQuota(folderKey);
        var fetchedForFolder = 0;
        final topParam = folderQuota < 50 ? folderQuota : 50;

        final orderByField = folderKey == 'sentitems'
            ? 'sentDateTime'
            : 'receivedDateTime';
        String? nextUrl =
            '$graphBaseUrl/me/mailFolders/$folderKey/messages'
            '?\$top=$topParam'
            '&\$orderby=$orderByField%20desc'
            '&\$select=id,subject,body,from,toRecipients,ccRecipients,bccRecipients,receivedDateTime,sentDateTime,isRead,hasAttachments';

        const maxPagesPerFolder = 10;
        var pageCount = 0;
        var retriedWithoutOrderBy = false;

        while (nextUrl != null &&
            nextUrl.isNotEmpty &&
            fetchedForFolder < folderQuota &&
            pageCount < maxPagesPerFolder) {
          pageCount++;
          final uri = Uri.parse(nextUrl);
          var resp = await _httpClient.get(uri, headers: headers);
          if (resp.statusCode == 400 && !retriedWithoutOrderBy) {
            retriedWithoutOrderBy = true;
            nextUrl =
                '$graphBaseUrl/me/mailFolders/$folderKey/messages'
                '?\$top=$topParam'
                '&\$select=id,subject,body,from,toRecipients,ccRecipients,bccRecipients,receivedDateTime,sentDateTime,isRead,hasAttachments';
            resp = await _httpClient.get(Uri.parse(nextUrl), headers: headers);
          }
          if (resp.statusCode != 200) {
            lastError = 'Microsoft Graph HTTP ${resp.statusCode}: ${resp.body}';
            folderWarnings?.add('Microsoft ($folderKey): $lastError');
            AppLogger.warning(
              'Falha ao listar mensagens da pasta $folderKey do Graph: $lastError',
            );
            break;
          }
          successCalls++;

          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final list = data['value'] as List<dynamic>? ?? [];
          if (list.isEmpty) break;

          var processedInPage = 0;
          for (final item in list) {
            if (item is! Map) continue;
            final msgMap = Map<String, dynamic>.from(item);
            final id = msgMap['id'] as String?;
            if (id == null || seenIds.contains(id)) continue;
            seenIds.add(id);

            final isKnown = knownMessageIds.contains(id);
            final parsed = parseGraphMessage(
              msgMap,
              accountEmail: accountEmail,
              folderKey: folderKey,
            );

            // Se já conhecida no banco local, reconcilia apenas estado (isRead/pasta) sem re-baixar anexos
            if (parsed != null && isKnown) {
              messages.add(parsed.copyWith(isMetadataOnly: true));
              fetchedForFolder++;
            } else if (parsed != null &&
                (msgMap['hasAttachments'] as bool? ?? false)) {
              final attachments = await _fetchAttachmentMetadata(
                messageId: id,
                headers: headers,
              );
              messages.add(parsed.copyWith(attachments: attachments));
              fetchedForFolder++;
            } else if (parsed != null) {
              messages.add(parsed);
              fetchedForFolder++;
            }

            processedInPage++;
            if (kIsWeb && processedInPage % 4 == 0) {
              await Future<void>.delayed(Duration.zero);
            }

            if (fetchedForFolder >= folderQuota) break;
          }

          final nextLink = data['@odata.nextLink'] as String?;
          if (fetchedForFolder < folderQuota &&
              nextLink != null &&
              nextLink.isNotEmpty) {
            nextUrl = nextLink;
          } else {
            nextUrl = null;
          }
        }
      } catch (e, st) {
        lastError = e.toString();
        AppLogger.warning(
          'Erro ao consultar pasta $folderKey no Microsoft Graph: $e',
          e,
          st,
        );
      }
    }

    if (successCalls == 0 && lastError != null) {
      if (lastError.contains('403') || lastError.contains('Forbidden')) {
        throw Exception(
          'Acesso ao Microsoft Graph negado (403). Verifique se as permissões Mail.ReadWrite e Mail.Send foram concedidas no Azure.',
        );
      }
      if (lastError.contains('401') || lastError.contains('Unauthorized')) {
        throw Exception(
          'Sessão da Microsoft expirada ou não autorizada (401). Reconecte a conta nas Configurações.',
        );
      }
      throw Exception('Falha ao sincronizar Microsoft: $lastError');
    }

    return messages;
  }

  Future<List<Map<String, dynamic>>> _fetchAttachmentMetadata({
    required String messageId,
    required Map<String, String> headers,
  }) async {
    try {
      final uri = Uri.parse(
        '$graphBaseUrl/me/messages/$messageId/attachments?\$select=id,name,contentType,size,isInline,contentId,contentBytes',
      );
      final resp = await _httpClient.get(uri, headers: headers);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = data['value'] as List<dynamic>? ?? [];
        var cumulativeBytes = 0;
        const maxCumulativeBytes = 5 * 1024 * 1024; // 5 MB teto cumulativo
        const maxSingleAutoBytes = 2 * 1024 * 1024; // 2 MB para auto-download

        return list.map((a) {
          final m = Map<String, dynamic>.from(a as Map);
          final name = m['name'] as String? ?? 'anexo';
          final mime =
              m['contentType'] as String? ?? 'application/octet-stream';
          final size = m['size'] as int? ?? 0;
          final isInline = m['isInline'] as bool? ?? false;
          final rawCid = m['contentId'] as String?;
          final contentId = rawCid?.replaceAll(RegExp(r'^<|>$'), '').trim();
          final contentBytes = m['contentBytes'] as String?;

          String? base64Data;
          Uint8List? rawBytes;

          if (contentBytes != null &&
              contentBytes.isNotEmpty &&
              (isInline || size <= maxSingleAutoBytes) &&
              (cumulativeBytes + size <= maxCumulativeBytes)) {
            base64Data = contentBytes;
            try {
              rawBytes = base64.decode(contentBytes);
              cumulativeBytes += size;
            } catch (_) {}
          }

          return {
            'name': name,
            'attachmentId': m['id'] ?? '',
            'size': size,
            'contentType': mime,
            'mimeType': mime,
            'isInline': isInline,
            'contentId': contentId,
            'base64': base64Data,
            'type': _determineFileType(name, mime),
            'rawBytes': rawBytes,
          };
        }).toList();
      }
    } catch (e, st) {
      AppLogger.warning(
        'Erro ao buscar anexos da mensagem $messageId no Microsoft Graph: $e',
        e,
        st,
      );
    }
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
    final emailObj = fromMap?['emailAddress'] as Map<String, dynamic>?;
    final address = emailObj?['address'] as String? ?? accountEmail;
    final name = emailObj?['name'] as String?;
    final from =
        (name != null &&
            name.trim().isNotEmpty &&
            name.trim().toLowerCase() != address.trim().toLowerCase())
        ? '${name.trim()} <${address.trim()}>'
        : address.trim();

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
    final dateStr = folderKey == 'sentitems'
        ? (msg['sentDateTime'] as String? ?? msg['receivedDateTime'] as String?)
        : (msg['receivedDateTime'] as String? ??
              msg['sentDateTime'] as String?);
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
      bodyText = EmailHtmlSanitizer.extractPlainText(content);
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

  static String _stripEmailPrefix(String id) =>
      id.startsWith('email_') ? id.substring(6) : id;

  static String _mapFolderNameToGraphId(String targetFolderName) {
    switch (targetFolderName) {
      case 'Enviadas':
      case 'Enviados':
        return 'sentitems';
      case 'Rascunhos':
        return 'drafts';
      case 'Spam':
        return 'junkemail';
      case 'Lixeira':
        return 'deleteditems';
      case 'Caixa de Entrada':
      default:
        return 'inbox';
    }
  }

  /// Atualiza o status `isRead` no Microsoft Graph.
  Future<bool> markMessageRead({
    required String accountId,
    required String messageId,
    required bool isRead,
  }) async {
    final token = await getValidAccessToken(accountId);
    if (token == null || token.isEmpty) {
      throw Exception('Conta Microsoft não autenticada.');
    }
    final rawId = _stripEmailPrefix(messageId);
    final resp = await _httpClient.patch(
      Uri.parse('$graphBaseUrl/me/messages/$rawId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'isRead': isRead}),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) return true;
    throw Exception(
      'Microsoft Graph recusou atualização de leitura (HTTP ${resp.statusCode}): ${resp.body}',
    );
  }

  /// Move uma mensagem no Microsoft Graph e retorna o novo ID remoto atribuído pela pasta de destino (se houver).
  Future<String?> moveMessageToFolder({
    required String accountId,
    required String messageId,
    required String targetFolderName,
  }) async {
    final token = await getValidAccessToken(accountId);
    if (token == null || token.isEmpty) {
      throw Exception('Conta Microsoft não autenticada.');
    }
    final rawId = _stripEmailPrefix(messageId);
    final destinationId = _mapFolderNameToGraphId(targetFolderName);
    final resp = await _httpClient.post(
      Uri.parse('$graphBaseUrl/me/messages/$rawId/move'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'destinationId': destinationId}),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.body.isNotEmpty) {
        try {
          final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
          return decoded['id'] as String?;
        } catch (_) {}
      }
      return null;
    }
    throw Exception(
      'Microsoft Graph recusou mover mensagem para $targetFolderName (HTTP ${resp.statusCode}): ${resp.body}',
    );
  }

  /// Move mensagem para Itens Excluídos (`deleteditems`) ou remove permanentemente no Microsoft Graph.
  Future<String?> deleteMessage({
    required String accountId,
    required String messageId,
    bool permanent = false,
  }) async {
    if (!permanent) {
      return moveMessageToFolder(
        accountId: accountId,
        messageId: messageId,
        targetFolderName: 'Lixeira',
      );
    }
    final token = await getValidAccessToken(accountId);
    if (token == null || token.isEmpty) {
      throw Exception('Conta Microsoft não autenticada.');
    }
    final rawId = _stripEmailPrefix(messageId);
    final resp = await _httpClient.delete(
      Uri.parse('$graphBaseUrl/me/messages/$rawId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode == 200 ||
        resp.statusCode == 202 ||
        resp.statusCode == 204 ||
        resp.statusCode == 404) {
      return null;
    }
    throw Exception(
      'Microsoft Graph recusou exclusão definitiva (HTTP ${resp.statusCode}): ${resp.body}',
    );
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
