import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/inbox/microsoft_oauth_service.dart';
import 'package:ministerio_pessoal/inbox/oauth_token_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Microsoft PKCE & Cryptography Tests', () {
    test(
      'generateCodeVerifier creates URL-safe string of specified length',
      () {
        final verifier64 = MicrosoftOAuthService.generateCodeVerifier(
          length: 64,
        );
        final verifier128 = MicrosoftOAuthService.generateCodeVerifier(
          length: 128,
        );

        expect(verifier64.length, equals(64));
        expect(verifier128.length, equals(128));

        // RFC 7636 unreserved charset: [A-Z], [a-z], [0-9], "-", ".", "_", "~"
        final regex = RegExp(r'^[a-zA-Z0-9\-._~]+$');
        expect(regex.hasMatch(verifier64), isTrue);
        expect(regex.hasMatch(verifier128), isTrue);
      },
    );

    test('generateCodeChallenge produces correct S256 base64Url string without padding', () {
      const knownVerifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
      final challenge = MicrosoftOAuthService.generateCodeChallenge(
        knownVerifier,
      );

      // Verify no padding character '=' is present
      expect(challenge.contains('='), isFalse);

      // Compute independently with crypto and compare
      final expectedDigest = crypto.sha256.convert(ascii.encode(knownVerifier));
      final expectedChallenge = base64Url
          .encode(expectedDigest.bytes)
          .replaceAll('=', '');

      expect(challenge, equals(expectedChallenge));
    });
  });

  group('Microsoft Graph Parser & Payload Tests', () {
    test(
      'parseGraphMessage maps well-known folders and formats message model',
      () {
        final graphJson = {
          'id': 'AAMkAGI2AAAt1234',
          'subject': 'Informativo Mensal de Campo',
          'from': {
            'emailAddress': {
              'name': 'Superintendente',
              'address': 'superintendente@outlook.com',
            },
          },
          'toRecipients': [
            {
              'emailAddress': {
                'name': 'Pioneiro',
                'address': 'pioneiro@outlook.com',
              },
            },
          ],
          'ccRecipients': [
            {
              'emailAddress': {
                'name': 'Ajudante',
                'address': 'ajudante@outlook.com',
              },
            },
          ],
          'bccRecipients': <dynamic>[],
          'receivedDateTime': '2026-11-22T08:30:00Z',
          'isRead': true,
          'hasAttachments': false,
          'body': {
            'contentType': 'html',
            'content': '<p>Segue a <b>escala</b> de serviço de campo.</p>',
          },
        };

        final parsed = MicrosoftOAuthService.parseGraphMessage(
          graphJson,
          accountEmail: 'pioneiro@outlook.com',
          folderKey: 'inbox',
        );

        expect(parsed, isNotNull);
        expect(parsed!.id, equals('AAMkAGI2AAAt1234'));
        expect(parsed.subject, equals('Informativo Mensal de Campo'));
        expect(parsed.from, equals('superintendente@outlook.com'));
        expect(parsed.to, equals('pioneiro@outlook.com'));
        expect(parsed.cc, equals(['ajudante@outlook.com']));
        expect(parsed.folderName, equals('Caixa de Entrada'));
        expect(
          parsed.bodyHtml,
          equals('<p>Segue a <b>escala</b> de serviço de campo.</p>'),
        );
        expect(
          parsed.bodyText,
          contains('Segue a escala de serviço de campo.'),
        );
        expect(parsed.isRead, isTrue);
        expect(parsed.isDraft, isFalse);
      },
    );

    test('parseGraphMessage marks isDraft true when folderKey is drafts', () {
      final graphJson = {
        'id': 'draft_msg_001',
        'subject': 'Rascunho de Carta',
        'from': {
          'emailAddress': {'address': 'mim@outlook.com'},
        },
        'toRecipients': <dynamic>[],
        'body': {'contentType': 'text', 'content': 'Texto do rascunho.'},
      };

      final parsed = MicrosoftOAuthService.parseGraphMessage(
        graphJson,
        accountEmail: 'mim@outlook.com',
        folderKey: 'drafts',
      );

      expect(parsed, isNotNull);
      expect(parsed!.isDraft, isTrue);
      expect(parsed.folderName, equals('Rascunhos'));
    });

    test('buildSendMailPayload constructs expected Graph API JSON body', () {
      final payload = MicrosoftOAuthService.buildSendMailPayload(
        to: ['destinatario@outlook.com'],
        cc: ['copia@outlook.com'],
        bcc: ['oculto@outlook.com'],
        subject: 'Assunto do Envio',
        bodyText: 'Texto simples',
        bodyHtml: '<p>HTML formatado</p>',
        attachments: [
          {
            'name': 'foto.png',
            'contentType': 'image/png',
            'bytes': Uint8List.fromList([137, 80, 78, 71]),
          },
        ],
      );

      final msg = payload['message'] as Map<String, dynamic>;
      expect(msg['subject'], equals('Assunto do Envio'));
      expect(msg['body']['contentType'], equals('HTML'));
      expect(msg['body']['content'], equals('<p>HTML formatado</p>'));

      final toList = msg['toRecipients'] as List;
      expect(
        toList.first['emailAddress']['address'],
        equals('destinatario@outlook.com'),
      );

      final ccList = msg['ccRecipients'] as List;
      expect(
        ccList.first['emailAddress']['address'],
        equals('copia@outlook.com'),
      );

      final bccList = msg['bccRecipients'] as List;
      expect(
        bccList.first['emailAddress']['address'],
        equals('oculto@outlook.com'),
      );

      final attList = msg['attachments'] as List;
      expect(attList.length, equals(1));
      expect(
        attList.first['@odata.type'],
        equals('#microsoft.graph.fileAttachment'),
      );
      expect(attList.first['name'], equals('foto.png'));
      expect(attList.first['contentType'], equals('image/png'));
      expect(
        attList.first['contentBytes'],
        equals(base64.encode([137, 80, 78, 71])),
      );
      expect(payload['saveToSentItems'], equals('true'));
    });
  });

  group('MicrosoftOAuthService MockClient Tests', () {
    late OAuthTokenStore tokenStore;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      tokenStore = const OAuthTokenStore();
    });

    test('getValidAccessToken automatically refreshes expiring token via refresh_token', () async {
      const accountId = 'ms_acc_refresh';
      const clientId = 'ms_test_client_id';

      // Token prestes a expirar (menos de 5 minutos restantes)
      final expiringBundle = OAuthTokenBundle(
        accessToken: 'old_expiring_access_token',
        refreshToken: 'valid_refresh_token_123',
        expiresAt: DateTime.now().add(const Duration(minutes: 2)),
        scopes: const ['User.Read', 'Mail.ReadWrite'],
      );
      await tokenStore.saveTokenBundle(accountId, expiringBundle);

      var refreshEndpointCalled = false;

      final mockClient = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(
          request.url.toString(),
          equals('https://login.microsoftonline.com/common/oauth2/v2.0/token'),
        );

        final body = request.body;
        expect(body, contains('grant_type=refresh_token'));
        expect(body, contains('refresh_token=valid_refresh_token_123'));
        expect(body, contains('client_id=ms_test_client_id'));

        refreshEndpointCalled = true;

        return http.Response(
          jsonEncode({
            'access_token': 'new_refreshed_access_token_999',
            'refresh_token': 'new_refresh_token_456',
            'expires_in': 3600,
            'scope': 'User.Read Mail.ReadWrite',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = MicrosoftOAuthService(
        httpClient: mockClient,
        tokenStore: tokenStore,
        clientId: clientId,
      );

      final token = await service.getValidAccessToken(accountId);

      expect(refreshEndpointCalled, isTrue);
      expect(token, equals('new_refreshed_access_token_999'));

      // Verifica se o bundle atualizado foi gravado no OAuthTokenStore
      final updatedBundle = await tokenStore.readTokenBundle(accountId);
      expect(updatedBundle, isNotNull);
      expect(
        updatedBundle!.accessToken,
        equals('new_refreshed_access_token_999'),
      );
      expect(updatedBundle.refreshToken, equals('new_refresh_token_456'));
      expect(updatedBundle.isExpiredOrExpiringSoon, isFalse);
    });

    test(
      'downloadAttachment downloads attachment bytes via Graph API MockClient',
      () async {
        const accountId = 'ms_acc_download';
        await tokenStore.saveTokenBundle(
          accountId,
          OAuthTokenBundle(
            accessToken: 'graph_token',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        );

        final dummyBytes = Uint8List.fromList([7, 8, 9, 10, 11]);

        final mockClient = MockClient((request) async {
          expect(request.method, equals('GET'));
          expect(
            request.url.toString(),
            equals(
              'https://graph.microsoft.com/v1.0/me/messages/m1/attachments/a1',
            ),
          );
          expect(
            request.headers['Authorization'],
            equals('Bearer graph_token'),
          );

          return http.Response(
            jsonEncode({
              '@odata.type': '#microsoft.graph.fileAttachment',
              'id': 'a1',
              'name': 'documento.docx',
              'contentType': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
              'contentBytes': base64.encode(dummyBytes),
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = MicrosoftOAuthService(
          httpClient: mockClient,
          tokenStore: tokenStore,
        );

        final result = await service.downloadAttachment(
          accountId: accountId,
          messageId: 'm1',
          attachmentId: 'a1',
        );

        expect(result, equals(dummyBytes));
      },
    );

    test(
      'sendEmail posts JSON payload to Graph /me/sendMail via MockClient',
      () async {
        const accountId = 'ms_acc_sendmail';
        await tokenStore.saveTokenBundle(
          accountId,
          OAuthTokenBundle(
            accessToken: 'graph_send_token',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        );

        var sendMailCalled = false;

        final mockClient = MockClient((request) async {
          expect(request.method, equals('POST'));
          expect(
            request.url.toString(),
            equals('https://graph.microsoft.com/v1.0/me/sendMail'),
          );
          expect(
            request.headers['Authorization'],
            equals('Bearer graph_send_token'),
          );
          expect(request.headers['Content-Type'], equals('application/json'));

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final message = body['message'] as Map<String, dynamic>;
          expect(message['subject'], equals('Teste Envio Microsoft Graph'));
          expect(body['saveToSentItems'], equals('true'));

          sendMailCalled = true;

          return http.Response('', 202); // 202 Accepted
        });

        final service = MicrosoftOAuthService(
          httpClient: mockClient,
          tokenStore: tokenStore,
        );

        await service.sendEmail(
          accountId: accountId,
          to: ['destinatario@outlook.com'],
          subject: 'Teste Envio Microsoft Graph',
          bodyText: 'Corpo do e-mail Microsoft',
        );

        expect(sendMailCalled, isTrue);
      },
    );
  });
}
