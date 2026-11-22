import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/inbox/email_contacts_manager.dart';
import 'package:ministerio_pessoal/inbox/email_sync_coordinator.dart';
import 'package:ministerio_pessoal/inbox/gmail_oauth_service.dart';
import 'package:ministerio_pessoal/inbox/jw_email_service.dart';
import 'package:ministerio_pessoal/inbox/microsoft_oauth_service.dart';
import 'package:ministerio_pessoal/inbox/oauth_token_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('OAuthTokenStore Pending Web Auth Tests', () {
    test('save, read and clear pending web auth parameters', () async {
      const store = OAuthTokenStore();
      await store.savePendingWebAuth(
        state: 'state_123',
        verifier: 'verifier_abc',
      );

      final read = await store.readPendingWebAuth();
      expect(read, isNotNull);
      expect(read!['state'], equals('state_123'));
      expect(read['verifier'], equals('verifier_abc'));

      await store.clearPendingWebAuth();
      final readAfterClear = await store.readPendingWebAuth();
      expect(readAfterClear, isNull);
    });
  });

  group('MicrosoftOAuthService Redirect URI & Error Tests', () {
    test(
      'getEffectiveRedirectUri returns ministeriopessoal:// scheme on non-web',
      () {
        final uri = MicrosoftOAuthService.getEffectiveRedirectUri();
        expect(uri, equals(MicrosoftOAuthService.redirectUri));
      },
    );

    test(
      'fetchMessages throws descriptive error when Graph API returns 403',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': {'code': 'Forbidden', 'message': 'Access denied'},
            }),
            403,
            headers: {'content-type': 'application/json'},
          );
        });

        const tokenStore = OAuthTokenStore();
        await tokenStore.saveTokenBundle(
          'acc_ms_test',
          OAuthTokenBundle(
            accessToken: 'test_token',
            refreshToken: null,
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        );

        final service = MicrosoftOAuthService(
          httpClient: mockClient,
          tokenStore: tokenStore,
          clientId: 'test-client-id',
        );

        expect(
          () => service.fetchMessages(
            accountId: 'acc_ms_test',
            accountEmail: 'user@outlook.com',
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Acesso ao Microsoft Graph negado (403)'),
            ),
          ),
        );
      },
    );
  });

  group('GmailOAuthService Error Reporting Tests', () {
    test(
      'fetchMessages throws descriptive error when Gmail API returns 403',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 403,
                'message': 'Gmail API has not been used in project before or it is disabled.',
                'status': 'PERMISSION_DENIED',
              },
            }),
            403,
            headers: {'content-type': 'application/json'},
          );
        });

        const tokenStore = OAuthTokenStore();
        await tokenStore.saveTokenBundle(
          'acc_gmail_test',
          OAuthTokenBundle(
            accessToken: 'test_token',
            refreshToken: null,
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        );

        final service = GmailOAuthService(
          httpClient: mockClient,
          tokenStore: tokenStore,
        );

        expect(
          () => service.fetchMessages(
            accountId: 'acc_gmail_test',
            accountEmail: 'user@gmail.com',
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Acesso à Gmail API negado (403)'),
            ),
          ),
        );
      },
    );
  });

  group('EmailSyncCoordinator Tests', () {
    test('syncAll returns empty result when no accounts configured', () async {
      final coordinator = EmailSyncCoordinator(db);
      final result = await coordinator.syncAll();

      expect(result.accountsSynced, equals(0));
      expect(result.totalMessagesSaved, equals(0));
      expect(result.failedDetails, isEmpty);
      expect(result.hasErrors, isFalse);
    });

    test(
      'persistSyncedMessages inserts messages idempotently and records sender',
      () async {
        final coordinator = EmailSyncCoordinator(db);
        final messages = [
          JwEmailMessage(
            id: 'test_msg_001',
            subject: 'Boletim do Campo',
            from: 'irmao@exemplo.com',
            to: 'mim@exemplo.com',
            date: DateTime.now(),
            bodyText: 'Mensagem de teste de sincronização',
            folderName: 'Caixa de Entrada',
          ),
        ];

        final saved = await coordinator.persistSyncedMessages(
          messages,
          'gmail_api',
        );
        expect(saved, equals(1));

        // Idempotência: segunda execução não duplica
        final savedSecond = await coordinator.persistSyncedMessages(
          messages,
          'gmail_api',
        );
        expect(savedSecond, equals(0));

        final entries = await db.select(db.inboxEntries).get();
        expect(entries.length, equals(1));
        expect(entries.first.id, equals('email_test_msg_001'));
        expect(entries.first.content, contains('Boletim do Campo'));

        // Verifica se o remetente foi registrado nos contatos
        final contacts = await EmailContactsManager.getAllSuggestions(db);
        expect(contacts.any((c) => c.email == 'irmao@exemplo.com'), isTrue);
      },
    );
  });
}
