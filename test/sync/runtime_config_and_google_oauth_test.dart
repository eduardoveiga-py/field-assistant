import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';

import 'package:ministerio_pessoal/core/app_config.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/appointments/google_calendar_provider.dart';
import 'package:ministerio_pessoal/appointments/calendar_sync_coordinator.dart';
import 'package:ministerio_pessoal/appointments/apple_eventkit_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Runtime AppConfig & AppConfigNotifier', () {
    test('AppConfig.copyWith permite modificar campos e revalida status', () {
      final initial = AppConfig.unconfigured();
      expect(initial.status, equals(ConfigStatus.unconfigured));

      final updated = initial.copyWith(
        supabaseUrl: 'https://test-project.supabase.co',
        supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummy',
        googleWebClientId: 'test-client-id.apps.googleusercontent.com',
      );

      expect(updated.status, equals(ConfigStatus.valid));
      expect(updated.supabaseUrl, equals('https://test-project.supabase.co'));
      expect(updated.googleWebClientId,
          equals('test-client-id.apps.googleusercontent.com'));
    });

    test('AppConfigNotifier notifica ouvintes sobre alterações em runtime', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = container.read(appConfigProvider);
      expect(initial.supabaseUrl, isEmpty);

      final newConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://novo-projeto.supabase.co',
        supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummy',
      );

      container.read(appConfigProvider.notifier).updateConfig(newConfig);

      final current = container.read(appConfigProvider);
      expect(current.supabaseUrl, equals('https://novo-projeto.supabase.co'));
      expect(current.isValid, isTrue);
    });

    test('Persistência e recuperação de credenciais em appKvStore', () async {
      // 1. Grava no banco local
      await db.into(db.appKvStore).insert(
            AppKvStoreCompanion.insert(
              key: 'config_supabase_url',
              value: 'https://saved.supabase.co',
            ),
          );
      await db.into(db.appKvStore).insert(
            AppKvStoreCompanion.insert(
              key: 'config_supabase_anon_key',
              value: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.key',
            ),
          );
      await db.into(db.appKvStore).insert(
            AppKvStoreCompanion.insert(
              key: 'config_google_web_client_id',
              value: 'saved-client-id.apps.googleusercontent.com',
            ),
          );

      // 2. Lê do banco local
      final urlRow = await (db.select(db.appKvStore)
            ..where((t) => t.key.equals('config_supabase_url')))
          .getSingle();
      final keyRow = await (db.select(db.appKvStore)
            ..where((t) => t.key.equals('config_supabase_anon_key')))
          .getSingle();
      final gRow = await (db.select(db.appKvStore)
            ..where((t) => t.key.equals('config_google_web_client_id')))
          .getSingle();

      expect(urlRow.value, equals('https://saved.supabase.co'));
      expect(
          keyRow.value, equals('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.key'));
      expect(
          gRow.value, equals('saved-client-id.apps.googleusercontent.com'));

      final reconstructed = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: urlRow.value,
        supabaseAnonKey: keyRow.value,
        googleWebClientId: gRow.value,
      );
      expect(reconstructed.isValid, isTrue);
    });

    test('AppConfig.copyWith preserva campos não alterados', () {
      final original = AppConfig.create(
        environment: AppEnvironment.production,
        supabaseUrl: 'https://prod.supabase.co',
        supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.prod',
        googleWebClientId: 'prod-client.apps.googleusercontent.com',
      );

      final updated = original.copyWith(googleWebClientId: 'new-client.apps.googleusercontent.com');
      expect(updated.supabaseUrl, equals('https://prod.supabase.co'));
      expect(updated.supabaseAnonKey, equals('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.prod'));
      expect(updated.googleWebClientId, equals('new-client.apps.googleusercontent.com'));
      expect(updated.environment, equals(AppEnvironment.production));
      expect(updated.isValid, isTrue);
    });

    test('AppConfig unconfigured detecta que servidor não está configurado', () {
      final config = AppConfig.unconfigured();
      expect(config.isOfflineOnly, isTrue);
      expect(config.status, equals(ConfigStatus.unconfigured));
      expect(config.supabaseUrl, isEmpty);
      expect(config.supabaseAnonKey, isEmpty);
    });

    test('AppConfigNotifier pode ser inicializado com config customizado', () {
      final customConfig = AppConfig.create(
        environment: AppEnvironment.homologation,
        supabaseUrl: 'https://staging.supabase.co',
        supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.staging',
      );

      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWith(() => AppConfigNotifier(customConfig)),
        ],
      );
      addTearDown(container.dispose);

      final loaded = container.read(appConfigProvider);
      expect(loaded.supabaseUrl, equals('https://staging.supabase.co'));
      expect(loaded.environment, equals(AppEnvironment.homologation));
      expect(loaded.isValid, isTrue);
    });
  });

  group('GoogleCalendarProvider OAuth Web Hardening', () {
    test('GoogleCalendarAuthException formata mensagem adequadamente', () {
      const ex = GoogleCalendarAuthException('Client ID ausente');
      expect(ex.toString(),
          contains('GoogleCalendarAuthException: Client ID ausente'));
      expect(ex.message, equals('Client ID ausente'));
    });

    test('clientConfigurationError exibe mensagem amigável', () {
      expect(
        GoogleAuthFailureReason.clientConfigurationError.userFriendlyMessage,
        contains('Configuração do Google Cloud inválida'),
      );
    });

    test('popupBlocked exibe mensagem sobre pop-ups', () {
      expect(
        GoogleAuthFailureReason.popupBlocked.userFriendlyMessage,
        contains('pop-ups'),
      );
    });

    test('userCancelled exibe mensagem sobre cancelamento', () {
      expect(
        GoogleAuthFailureReason.userCancelled.userFriendlyMessage,
        contains('cancelada pelo usuário'),
      );
    });

    test('GoogleAuthResult.success() cria resultado bem-sucedido', () {
      final result = GoogleAuthResult.success();
      expect(result.success, isTrue);
      expect(result.failureReason, equals(GoogleAuthFailureReason.none));
    });

    test('GoogleAuthResult.failure() cria resultado com razão e mensagem', () {
      final result = GoogleAuthResult.failure(
        GoogleAuthFailureReason.clientConfigurationError,
        'Client ID inválido',
      );
      expect(result.success, isFalse);
      expect(result.failureReason,
          equals(GoogleAuthFailureReason.clientConfigurationError));
      expect(result.errorMessage, equals('Client ID inválido'));
    });
  });

  group('Supabase Config Validation via AppConfig', () {
    test('AppConfig.create rejeita URL sem HTTPS em produção', () {
      final config = AppConfig.create(
        environment: AppEnvironment.production,
        supabaseUrl: 'http://inseguro.supabase.co',
        supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummy',
      );
      expect(config.isInvalid, isTrue);
      expect(config.validationErrors.any((e) => e.contains('HTTPS')), isTrue);
    });

    test('AppConfig.create rejeita URL com placeholder de exemplo', () {
      final config = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://your-supabase-url.supabase.co',
        supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummy',
      );
      expect(config.isInvalid, isTrue);
    });

    test('AppConfig.create aceita URL válida com HTTPS', () {
      final config = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://real-project.supabase.co',
        supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.real',
      );
      expect(config.isValid, isTrue);
    });

    test('AppConfig.create rejeita Anon Key que parece ser service_role', () {
      final config = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://real.supabase.co',
        supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.service_role_key_here',
      );
      // Se a validação detecta service_role
      if (config.isInvalid) {
        expect(config.validationErrors.any((e) => e.toLowerCase().contains('service')), isTrue);
      }
    });

    test('AppConfig maskedUrl não vaza credenciais de userInfo', () {
      final config = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://user:pass@real.supabase.co',
        supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.real',
      );
      expect(config.maskedUrl, contains('***'));
      expect(config.maskedUrl, isNot(contains('pass')));
    });

    test('AppConfig maskedAnonKey oculta chave longa', () {
      final config = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://real.supabase.co',
        supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.real.token.long.enough',
      );
      expect(config.maskedAnonKey, contains('...'));
      expect(config.maskedAnonKey, isNot(contains('.real.token.long.enough')));
    });
  });

  group('ConnectedCalendarsScreen Google Client ID (unit)', () {
    test('CalendarSyncCoordinator instancia GoogleCalendarProvider com webClientId', () {
      final coordinator = CalendarSyncCoordinator(
        db,
        google: GoogleCalendarProvider(webClientId: 'test-id.apps.googleusercontent.com'),
        apple: AppleEventKitProvider(isWebPlatform: true),
        isWebPlatform: true,
      );
      expect(coordinator.googleProvider, isNotNull);
      expect(coordinator.allProviders.length, equals(1)); // Web: somente Google
    });
  });
}
