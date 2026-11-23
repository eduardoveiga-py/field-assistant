import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/inbox/email_account_model.dart';
import 'package:ministerio_pessoal/inbox/oauth_token_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OAuthTokenBundle Tests', () {
    test(
      'isExpiredOrExpiringSoon returns false when > 5 minutes remaining',
      () {
        final bundle = OAuthTokenBundle(
          accessToken: 'valid_access_token',
          refreshToken: 'valid_refresh_token',
          expiresAt: DateTime.now().add(const Duration(minutes: 10)),
          scopes: const ['Mail.Read'],
        );

        expect(bundle.isExpiredOrExpiringSoon, isFalse);
      },
    );

    test(
      'isExpiredOrExpiringSoon returns true when <= 5 minutes remaining',
      () {
        final bundle = OAuthTokenBundle(
          accessToken: 'expiring_soon_token',
          refreshToken: 'valid_refresh_token',
          expiresAt: DateTime.now().add(const Duration(minutes: 4)),
          scopes: const ['Mail.Read'],
        );

        expect(bundle.isExpiredOrExpiringSoon, isTrue);
      },
    );

    test(
      'isExpiredOrExpiringSoon returns true when already expired in past',
      () {
        final bundle = OAuthTokenBundle(
          accessToken: 'expired_token',
          refreshToken: 'valid_refresh_token',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
          scopes: const ['Mail.Read'],
        );

        expect(bundle.isExpiredOrExpiringSoon, isTrue);
      },
    );

    test('isExpired returns true only when current time is strictly after expiresAt', () {
      final futureBundle = OAuthTokenBundle(
        accessToken: 'valid_token',
        expiresAt: DateTime.now().add(const Duration(minutes: 2)),
      );
      expect(futureBundle.isExpired, isFalse);

      final pastBundle = OAuthTokenBundle(
        accessToken: 'expired_token',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 10)),
      );
      expect(pastBundle.isExpired, isTrue);
    });

    test('serialization roundtrip preserves all fields', () {
      final now = DateTime.now();
      final bundle = OAuthTokenBundle(
        accessToken: 'token_123',
        refreshToken: 'refresh_456',
        expiresAt: now,
        scopes: const ['https://mail.google.com/', 'email'],
      );

      final json = bundle.toJson();
      final recovered = OAuthTokenBundle.fromJson(json);

      expect(recovered.accessToken, equals('token_123'));
      expect(recovered.refreshToken, equals('refresh_456'));
      expect(
        recovered.expiresAt.millisecondsSinceEpoch,
        equals(now.millisecondsSinceEpoch),
      );
      expect(recovered.scopes, equals(['https://mail.google.com/', 'email']));
    });
  });

  group('OAuthTokenStore Tests', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test(
      'saveTokenBundle and readTokenBundle persist and retrieve bundle',
      () async {
        const store = OAuthTokenStore();
        const accountId = 'acc_google_123';
        final bundle = OAuthTokenBundle(
          accessToken: 'access_abc',
          refreshToken: 'refresh_xyz',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          scopes: const ['email', 'profile'],
        );

        await store.saveTokenBundle(accountId, bundle);
        final read = await store.readTokenBundle(accountId);

        expect(read, isNotNull);
        expect(read!.accessToken, equals('access_abc'));
        expect(read.refreshToken, equals('refresh_xyz'));
        expect(read.scopes, equals(['email', 'profile']));
        expect(read.isExpiredOrExpiringSoon, isFalse);
      },
    );

    test('deleteTokenBundle removes bundle from storage', () async {
      const store = OAuthTokenStore();
      const accountId = 'acc_ms_999';
      final bundle = OAuthTokenBundle(
        accessToken: 'access_def',
        expiresAt: DateTime.now().add(const Duration(hours: 2)),
      );

      await store.saveTokenBundle(accountId, bundle);
      expect(await store.readTokenBundle(accountId), isNotNull);

      await store.deleteTokenBundle(accountId);
      expect(await store.readTokenBundle(accountId), isNull);
    });

    test('readTokenBundle returns null for missing accountId', () async {
      const store = OAuthTokenStore();
      final read = await store.readTokenBundle('non_existent_account');
      expect(read, isNull);
    });

    test('EmailAccountsManager.deleteAccount removes both password and OAuth tokens', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      try {
        const accountId = 'oauth_account_to_delete';
        final account = EmailAccount(
          id: accountId,
          name: 'Conta OAuth Teste',
          email: 'teste@exemplo.com',
          providerType: EmailProviderType.google,
          incomingHost: 'gmail.googleapis.com',
          incomingProtocol: 'gmail_api',
          outgoingHost: 'gmail.googleapis.com',
          outgoingProtocol: 'gmail_api',
          username: 'teste@exemplo.com',
          createdAt: DateTime.now(),
        );

        await EmailAccountsManager.saveAccount(
          db,
          account,
          password: 'secret_password_if_any',
        );

        const store = OAuthTokenStore();
        await store.saveTokenBundle(
          accountId,
          OAuthTokenBundle(
            accessToken: 'oauth_secret_token',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        );

        expect(await store.readTokenBundle(accountId), isNotNull);
        expect(
          await EmailAccountsManager.getAccountPassword(accountId),
          isNotNull,
        );

        await EmailAccountsManager.deleteAccount(db, accountId);

        expect(await store.readTokenBundle(accountId), isNull);
        expect(
          await EmailAccountsManager.getAccountPassword(accountId),
          isNull,
        );
      } finally {
        await db.close();
      }
    });

    test(
      'saveAccount deduplicates accounts with same username and protocol',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        try {
          final acc1 = EmailAccount(
            id: 'uuid-1',
            name: 'Gmail Conta',
            email: 'usuario@gmail.com',
            providerType: EmailProviderType.google,
            incomingHost: 'gmail.googleapis.com',
            incomingPort: 443,
            incomingProtocol: 'gmail_api',
            outgoingHost: 'gmail.googleapis.com',
            outgoingPort: 443,
            outgoingSecurity: 'ssl',
            outgoingProtocol: 'gmail_api',
            username: 'usuario@gmail.com',
            createdAt: DateTime.now(),
          );

          await EmailAccountsManager.saveAccount(db, acc1);
          var accounts = await EmailAccountsManager.loadAccounts(db);
          expect(accounts.length, equals(1));
          expect(accounts.first.id, equals('uuid-1'));

          // Reconexão gerando novo ID para mesmo e-mail e protocolo
          final acc2 = EmailAccount(
            id: 'uuid-2',
            name: 'Gmail Reconectado',
            email: 'USUARIO@GMAIL.COM ',
            providerType: EmailProviderType.google,
            incomingHost: 'gmail.googleapis.com',
            incomingPort: 443,
            incomingProtocol: 'gmail_api',
            outgoingHost: 'gmail.googleapis.com',
            outgoingPort: 443,
            outgoingSecurity: 'ssl',
            outgoingProtocol: 'gmail_api',
            username: 'usuario@gmail.com',
            createdAt: DateTime.now(),
          );

          await EmailAccountsManager.saveAccount(db, acc2);
          accounts = await EmailAccountsManager.loadAccounts(db);
          expect(accounts.length, equals(1));
          expect(accounts.first.id, equals('uuid-2'));
          expect(accounts.first.name, equals('Gmail Reconectado'));
        } finally {
          await db.close();
        }
      },
    );
  });
}
