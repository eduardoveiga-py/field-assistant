import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/appointments/google_calendar_provider.dart';
import 'package:ministerio_pessoal/inbox/oauth_token_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoogleCalendarProvider - Sessão Persistente', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('getValidAccessToken reutiliza token válido do OAuthTokenStore sem interação', () async {
      final tokenStore = OAuthTokenStore();
      final bundle = OAuthTokenBundle(
        accessToken: 'valid_gcal_token_xyz_456',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        scopes: const ['https://www.googleapis.com/auth/calendar.events'],
      );
      await tokenStore.saveNamedTokenBundle(
        'google_calendar_oauth_tokens',
        bundle,
      );

      final provider = GoogleCalendarProvider(tokenStore: tokenStore);
      final token = await provider.getValidAccessToken(interactive: false);

      expect(token, equals('valid_gcal_token_xyz_456'));
    });

    test(
      'interactive: false retorna null sem disparar popups quando não há token',
      () async {
        final tokenStore = OAuthTokenStore();
        final provider = GoogleCalendarProvider(tokenStore: tokenStore);

        final token = await provider.getValidAccessToken(interactive: false);

        expect(token, isNull);
      },
    );

    test('isAuthorized reflete sessão persistente válida', () async {
      const storage = FlutterSecureStorage();
      await storage.write(
        key: 'google_calendar_explicitly_connected',
        value: 'true',
      );
      final tokenStore = OAuthTokenStore();
      final bundle = OAuthTokenBundle(
        accessToken: 'authorized_token_test',
        expiresAt: DateTime.now().add(const Duration(hours: 2)),
      );
      await tokenStore.saveNamedTokenBundle(
        'google_calendar_oauth_tokens',
        bundle,
      );

      final provider = GoogleCalendarProvider(
        tokenStore: tokenStore,
        secureStorage: storage,
      );
      final authorized = await provider.isAuthorized();

      expect(authorized, isTrue);
    });

    test('disconnect remove named token bundle do Google Calendar e dados associados', () async {
      const storage = FlutterSecureStorage();
      await storage.write(
        key: 'google_calendar_explicitly_connected',
        value: 'true',
      );
      await storage.write(
        key: 'google_calendar_connected_email',
        value: 'teste@gmail.com',
      );
      final tokenStore = OAuthTokenStore();
      final bundle = OAuthTokenBundle(
        accessToken: 'token_to_disconnect',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      await tokenStore.saveNamedTokenBundle(
        'google_calendar_oauth_tokens',
        bundle,
      );

      final provider = GoogleCalendarProvider(
        tokenStore: tokenStore,
        secureStorage: storage,
      );
      await provider.disconnect();

      final remainingToken = await tokenStore.readNamedTokenBundle(
        'google_calendar_oauth_tokens',
      );
      expect(remainingToken, isNull);
      expect(
        await storage.read(key: 'google_calendar_connected_email'),
        isNull,
      );
      expect(
        await storage.read(key: 'google_calendar_explicitly_connected'),
        isNull,
      );
    });
  });
}
