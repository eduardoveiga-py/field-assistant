import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/inbox/gmail_oauth_service.dart';
import 'package:ministerio_pessoal/inbox/oauth_token_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GmailOAuthService Utility Tests', () {
    test('mapLabelToFolderName maps Gmail system labels correctly', () {
      expect(
        GmailOAuthService.mapLabelToFolderName(['INBOX', 'UNREAD']),
        equals('Caixa de Entrada'),
      );
      expect(
        GmailOAuthService.mapLabelToFolderName(['SENT']),
        equals('Enviadas'),
      );
      expect(
        GmailOAuthService.mapLabelToFolderName(['DRAFT']),
        equals('Rascunhos'),
      );
      expect(GmailOAuthService.mapLabelToFolderName(['SPAM']), equals('Spam'));
      expect(
        GmailOAuthService.mapLabelToFolderName(['TRASH']),
        equals('Lixeira'),
      );
    });

    test(
      'decodeBase64UrlBytes handles unpadded and URL-safe strings safely',
      () {
        // "Hello World" in base64 is "SGVsbG8gV29ybGQ=" (length 16)
        // without padding: "SGVsbG8gV29ybGQ" (length 15, remainder 3)
        final unpadded = 'SGVsbG8gV29ybGQ';
        final decoded = GmailOAuthService.decodeBase64UrlString(unpadded);
        expect(decoded, equals('Hello World'));

        // Test with url characters '-' and '_'
        final specialText = '>>>???';
        final encodedSpecial = base64Url
            .encode(utf8.encode(specialText))
            .replaceAll('=', '');
        final recovered = GmailOAuthService.decodeBase64UrlString(
          encodedSpecial,
        );
        expect(recovered, equals(specialText));
      },
    );

    test('buildRfc2822 produces well-formed MIME message with attachments', () {
      final rfc = GmailOAuthService.buildRfc2822(
        from: 'remetente@gmail.com',
        to: ['destinatario@exemplo.com'],
        cc: ['copia@exemplo.com'],
        subject: 'Assunto com acentuação e cedilha: Atenção',
        bodyText: 'Olá, corpo em texto puro.',
        bodyHtml: '<p>Olá, corpo em HTML.</p>',
        attachments: [
          {
            'name': 'documento.pdf',
            'contentType': 'application/pdf',
            'bytes': Uint8List.fromList([1, 2, 3, 4, 5]),
          },
        ],
      );

      expect(rfc, contains('From: remetente@gmail.com'));
      expect(rfc, contains('To: destinatario@exemplo.com'));
      expect(rfc, contains('Cc: copia@exemplo.com'));
      expect(rfc, contains('Subject: =?UTF-8?B?'));
      expect(rfc, contains('Content-Type: multipart/mixed;'));
      expect(rfc, contains('Content-Type: application/pdf; name='));
      expect(rfc, contains('Olá, corpo em texto puro.'));
      expect(rfc, contains('<p>Olá, corpo em HTML.</p>'));
    });

    test('parseGmailMessage decodes multi-part payload and attachments', () {
      final textData = base64Url
          .encode(utf8.encode('Mensagem em texto simples'))
          .replaceAll('=', '');
      final htmlData = base64Url
          .encode(utf8.encode('<b>Mensagem em HTML</b>'))
          .replaceAll('=', '');

      final msgJson = {
        'id': '18f123456789abcd',
        'threadId': 'thread_001',
        'labelIds': ['INBOX', 'UNREAD'],
        'internalDate': '1700000000000',
        'payload': {
          'mimeType': 'multipart/mixed',
          'headers': [
            {'name': 'Subject', 'value': 'Reunião de Serviço'},
            {'name': 'From', 'value': 'anciao@jw.org'},
            {'name': 'To', 'value': 'publicador@gmail.com'},
            {'name': 'Date', 'value': 'Wed, 22 Nov 2026 10:00:00 +0000'},
          ],
          'parts': [
            {
              'mimeType': 'multipart/alternative',
              'parts': [
                {
                  'mimeType': 'text/plain',
                  'body': {'size': 25, 'data': textData},
                },
                {
                  'mimeType': 'text/html',
                  'body': {'size': 30, 'data': htmlData},
                },
              ],
            },
            {
              'filename': 'designacao.pdf',
              'mimeType': 'application/pdf',
              'body': {'attachmentId': 'att_pdf_123', 'size': 1024},
            },
          ],
        },
      };

      final parsed = GmailOAuthService.parseGmailMessage(
        msgJson,
        accountEmail: 'publicador@gmail.com',
      );

      expect(parsed, isNotNull);
      expect(parsed!.id, equals('18f123456789abcd'));
      expect(parsed.subject, equals('Reunião de Serviço'));
      expect(parsed.from, equals('anciao@jw.org'));
      expect(parsed.to, equals('publicador@gmail.com'));
      expect(parsed.bodyText, equals('Mensagem em texto simples'));
      expect(parsed.bodyHtml, equals('<b>Mensagem em HTML</b>'));
      expect(parsed.isRead, isFalse);
      expect(parsed.isDraft, isFalse);
      expect(parsed.folderName, equals('Caixa de Entrada'));
      expect(parsed.attachments.length, equals(1));
      expect(parsed.attachments.first['name'], equals('designacao.pdf'));
      expect(parsed.attachments.first['attachmentId'], equals('att_pdf_123'));
      expect(parsed.attachments.first['type'], equals('pdf'));
    });
  });

  group('GmailOAuthService MockClient API Tests', () {
    late OAuthTokenStore tokenStore;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      tokenStore = const OAuthTokenStore();
    });

    test(
      'downloadAttachment fetches and decodes binary attachment via MockClient',
      () async {
        const accountId = 'gmail_acc_test';
        final dummyToken = OAuthTokenBundle(
          accessToken: 'valid_bearer_token_gmail',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        await tokenStore.saveTokenBundle(accountId, dummyToken);

        final originalBytes = Uint8List.fromList([10, 20, 30, 40, 50, 60]);
        final base64UrlData = base64Url
            .encode(originalBytes)
            .replaceAll('=', '');

        final mockClient = MockClient((request) async {
          expect(request.method, equals('GET'));
          expect(
            request.url.toString(),
            equals(
              'https://gmail.googleapis.com/gmail/v1/users/me/messages/msg_99/attachments/att_88',
            ),
          );
          expect(
            request.headers['Authorization'],
            equals('Bearer valid_bearer_token_gmail'),
          );

          return http.Response(
            jsonEncode({'size': originalBytes.length, 'data': base64UrlData}),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = GmailOAuthService(
          httpClient: mockClient,
          tokenStore: tokenStore,
        );

        final downloaded = await service.downloadAttachment(
          accountId: accountId,
          messageId: 'msg_99',
          attachmentId: 'att_88',
        );

        expect(downloaded, equals(originalBytes));
      },
    );

    test(
      'sendEmail posts RFC 2822 base64Url to messages/send via MockClient',
      () async {
        const accountId = 'gmail_acc_send';
        final dummyToken = OAuthTokenBundle(
          accessToken: 'send_bearer_token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        await tokenStore.saveTokenBundle(accountId, dummyToken);

        var sendCalled = false;

        final mockClient = MockClient((request) async {
          expect(request.method, equals('POST'));
          expect(
            request.url.toString(),
            equals(
              'https://gmail.googleapis.com/gmail/v1/users/me/messages/send',
            ),
          );
          expect(
            request.headers['Authorization'],
            equals('Bearer send_bearer_token'),
          );

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body.containsKey('raw'), isTrue);

          final rawBase64 = body['raw'] as String;
          final decodedRfc = GmailOAuthService.decodeBase64UrlString(rawBase64);
          expect(decodedRfc, contains('From: remetente@gmail.com'));
          expect(decodedRfc, contains('To: destino@exemplo.com'));
          expect(decodedRfc, contains('Corpo do e-mail para envio'));

          sendCalled = true;
          return http.Response(
            jsonEncode({'id': 'new_msg_id', 'threadId': 't_123'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = GmailOAuthService(
          httpClient: mockClient,
          tokenStore: tokenStore,
        );

        await service.sendEmail(
          accountId: accountId,
          from: 'remetente@gmail.com',
          to: ['destino@exemplo.com'],
          subject: 'Teste Envio Gmail',
          bodyText: 'Corpo do e-mail para envio',
        );

        expect(sendCalled, isTrue);
      },
    );

    test(
      'fetchMessages queries folders and parses messages via MockClient',
      () async {
        const accountId = 'gmail_acc_fetch';
        await tokenStore.saveTokenBundle(
          accountId,
          OAuthTokenBundle(
            accessToken: 'fetch_token',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        );

        final textData = base64Url
            .encode(utf8.encode('Conteudo da mensagem inbox'))
            .replaceAll('=', '');

        final mockClient = MockClient((request) async {
          final url = request.url.toString();
          if (url.contains('/messages?') && url.contains('labelIds=INBOX')) {
            return http.Response(
              jsonEncode({
                'messages': [
                  {'id': 'msg_inbox_1', 'threadId': 't1'},
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          } else if (url.contains('/messages/msg_inbox_1')) {
            return http.Response(
              jsonEncode({
                'id': 'msg_inbox_1',
                'labelIds': ['INBOX'],
                'internalDate': '1700000000000',
                'payload': {
                  'mimeType': 'text/plain',
                  'headers': [
                    {'name': 'Subject', 'value': 'Assunto Inbox'},
                    {'name': 'From', 'value': 'amigo@jw.org'},
                    {'name': 'To', 'value': 'eu@gmail.com'},
                  ],
                  'body': {'data': textData},
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          // Outros labels retornam lista vazia
          return http.Response(
            jsonEncode({'messages': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = GmailOAuthService(
          httpClient: mockClient,
          tokenStore: tokenStore,
        );

        final msgs = await service.fetchMessages(
          accountId: accountId,
          accountEmail: 'eu@gmail.com',
        );

        expect(msgs.length, equals(1));
        expect(msgs.first.id, equals('msg_inbox_1'));
        expect(msgs.first.subject, equals('Assunto Inbox'));
        expect(msgs.first.bodyText, equals('Conteudo da mensagem inbox'));
        expect(msgs.first.folderName, equals('Caixa de Entrada'));
      },
    );

    test('getValidAccessToken returns null when token is expired and renewal fails', () async {
      const accountId = 'expired_acc';
      await tokenStore.saveTokenBundle(
        accountId,
        OAuthTokenBundle(
          accessToken: 'expired_token',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
      );

      final mockClient = MockClient((request) async => http.Response('', 400));
      final service = GmailOAuthService(
        httpClient: mockClient,
        tokenStore: tokenStore,
      );

      final token = await service.getValidAccessToken(accountId);
      expect(token, isNull);
    });

    test(
      'fetchMessages throws immediately when INBOX returns 401 or 403',
      () async {
        const accountId = 'inbox_401_acc';
        await tokenStore.saveTokenBundle(
          accountId,
          OAuthTokenBundle(
            accessToken: 'valid_token',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        );

        final mockClient = MockClient((request) async {
          if (request.url.toString().contains('labelIds=INBOX')) {
            return http.Response(
              jsonEncode({
                'error': {'code': 401, 'message': 'UNAUTHENTICATED'},
              }),
              401,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(jsonEncode({'messages': []}), 200);
        });

        final service = GmailOAuthService(
          httpClient: mockClient,
          tokenStore: tokenStore,
        );

        expect(
          () => service.fetchMessages(
            accountId: accountId,
            accountEmail: 'user@gmail.com',
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Sessão do Gmail expirada ou não autorizada (401)'),
            ),
          ),
        );
      },
    );

    test('fetchMessages throws when messageRefs is not empty but all messages fail to download', () async {
      const accountId = 'fetch_fail_acc';
      await tokenStore.saveTokenBundle(
        accountId,
        OAuthTokenBundle(
          accessToken: 'valid_token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );

      final mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('labelIds=INBOX')) {
          return http.Response(
            jsonEncode({
              'messages': [
                {'id': 'msg_err_1'},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (url.contains('/messages/msg_err_1')) {
          return http.Response(
            jsonEncode({'error': 'Internal server error'}),
            500,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(jsonEncode({'messages': []}), 200);
      });

      final service = GmailOAuthService(
        httpClient: mockClient,
        tokenStore: tokenStore,
      );

      expect(
        () => service.fetchMessages(
          accountId: accountId,
          accountEmail: 'user@gmail.com',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
