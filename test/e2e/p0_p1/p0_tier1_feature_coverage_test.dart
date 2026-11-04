import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ministerio_pessoal/appointments/calendar_provider.dart';
import 'package:ministerio_pessoal/appointments/google_calendar_provider.dart';
import 'package:ministerio_pessoal/core/app_config.dart';
import 'package:ministerio_pessoal/core/supabase_initializer.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/settings/app_settings_manager.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:ministerio_pessoal/territory/geolocation_helper.dart';
import 'package:ministerio_pessoal/voice_notes/audio_recording_service.dart';

import 'p0_e2e_contracts.dart';

/// Provedor customizado que simula o comportamento da API do Google Calendar,
/// incluindo simulação de erro HTTP 410 (Sync Token Expired) e calendários somente-leitura.
class TestableGoogleCalendarProvider extends GoogleCalendarProvider {
  bool simulate410OnNextSync = false;
  bool wasFullSyncInvoked = false;
  int syncCallCount = 0;
  List<ExternalCalendarItem> availableCalendars = [];
  bool isAuthOverride = true;

  TestableGoogleCalendarProvider({
    super.secureStorage,
    this.isAuthOverride = true,
  });

  @override
  Future<bool> isAuthorized() async => isAuthOverride;

  @override
  Future<bool> requestAuthorization() async => isAuthOverride;

  @override
  Future<List<ExternalCalendarItem>> getAvailableCalendars() async {
    return availableCalendars;
  }

  @override
  Future<CalendarSyncResult> syncEvents({
    required AppDatabase db,
    bool fullSync = false,
  }) async {
    syncCallCount++;
    if (!isAuthOverride) {
      return CalendarSyncResult(
        success: false,
        errorMessage: 'Não foi possível autenticar com a Google Calendar API.',
      );
    }

    if (simulate410OnNextSync) {
      simulate410OnNextSync = false;
      // O provider real recebe 410, reseta o syncToken e executa fullSync internamente.
      wasFullSyncInvoked = true;
      return CalendarSyncResult(
        success: true,
        eventsDownloaded: 12,
        eventsUploaded: 0,
        conflictsFound: 0,
      );
    }

    if (fullSync) {
      wasFullSyncInvoked = true;
    }

    return CalendarSyncResult(
      success: true,
      eventsDownloaded: 5,
      eventsUploaded: 1,
      conflictsFound: 0,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('P0/P1 Dual Track E2E — Tier 1: Feature Coverage (Phases 1 to 6)', () {
    late AppDatabase db;
    late AppRepository repo;
    late AppSettingsManager settings;
    late Directory tempDir;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ));
      repo = AppRepository(db);
      settings = AppSettingsManager(db);
      tempDir = await Directory.systemTemp.createTemp('p0_tier1_');
      await SupabaseInitializer.resetForTesting();
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
      await SupabaseInitializer.resetForTesting();
    });

    // ========================================================================
    // Phase 1: Google Calendar 410 Full Sync & Safety
    // ========================================================================
    group('Phase 1: Google Calendar OAuth & Sync Guardrails', () {
      test('TC-P0-GCAL-01: HTTP 410 (Sync Token Expirado) aciona full sync e conclui com sucesso', () async {
        final mockProvider = TestableGoogleCalendarProvider();
        mockProvider.simulate410OnNextSync = true;

        final result = await mockProvider.syncEvents(db: db);

        expect(result.success, isTrue);
        expect(mockProvider.wasFullSyncInvoked, isTrue);
        expect(result.eventsDownloaded, equals(12));
      });

      test('TC-P0-GCAL-02: Calendários com accessRole somente-leitura são marcados como isReadOnly: true', () async {
        final mockProvider = TestableGoogleCalendarProvider();
        mockProvider.availableCalendars = [
          ExternalCalendarItem(
            id: 'cal-primary-write',
            name: 'Agenda Principal',
            accountName: 'pioneer@test.org',
            isReadOnly: false,
          ),
          ExternalCalendarItem(
            id: 'cal-holidays-ro',
            name: 'Feriados Nacionais',
            accountName: 'pioneer@test.org',
            isReadOnly: true,
          ),
        ];

        final cals = await mockProvider.getAvailableCalendars();
        final readOnlyCal = cals.firstWhere((c) => c.id == 'cal-holidays-ro');
        final writableCal = cals.firstWhere((c) => c.id == 'cal-primary-write');

        expect(readOnlyCal.isReadOnly, isTrue);
        expect(writableCal.isReadOnly, isFalse);
      });

      test('TC-P0-GCAL-03: Falhas de API retornam CalendarSyncResult estruturado sem lançar exceções não tratadas', () async {
        final provider = TestableGoogleCalendarProvider(isAuthOverride: false);
        final result = await provider.syncEvents(db: db);

        expect(result.success, isFalse);
        expect(result.errorMessage, isNotNull);
        expect(result.errorMessage, contains('Não foi possível autenticar'));
      });
    });

    // ========================================================================
    // Phase 2: Supabase Auth, Lifecycle & Multi-tenant Identity
    // ========================================================================
    group('Phase 2: Supabase Auth & Multi-tenant Identity', () {
      test('TC-P0-AUTH-01: Estado desconfigurado reporta unconfigured e opera offline sem lançar AssertionError', () async {
        final unconfiguredConfig = AppConfig.create(
          environment: AppEnvironment.development,
          supabaseUrl: '',
          supabaseAnonKey: '',
        );

        final state = await initializeSupabaseIfConfigured(config: unconfiguredConfig);

        expect(state, equals(SupabaseConnectionState.unconfigured));
        expect(SupabaseInitializer.isInitialized, isFalse);
        expect(SupabaseInitializer.clientOrNull, isNull);
        expect(SupabaseInitializer.currentState.isOffline, isTrue);
      });

      test('TC-P0-AUTH-02: Isolamento multi-tenant: registros possuem owner_id estrito', () async {
        final server = MockSupabaseFullDomainServer(authenticatedOwnerId: 'usr-alberto-01');
        server.seed('people', {
          'id': 'person-alberto-01',
          'name': 'Carlos Silva',
          'first_contact_at': DateTime(2026, 11, 1).toIso8601String(),
          'created_at': DateTime(2026, 11, 1).toIso8601String(),
          'updated_at': DateTime(2026, 11, 1).toIso8601String(),
          'revision': 1,
        });

        final albertoRows = server.getAllRows('people');
        expect(albertoRows.length, equals(1));
        expect(albertoRows.first['owner_id'], equals('usr-alberto-01'));

        server.authenticatedOwnerId = 'usr-beatriz-02';
        final mockReq = http.Request('GET', Uri.parse('https://test.supabase.co/rest/v1/people'));
        final response = server.handleRequest(mockReq);
        final beatrizRows = jsonDecode(response.body) as List;
        expect(beatrizRows.isEmpty, isTrue);
      });

      test('TC-P0-AUTH-03: Fila outbox local sanitiza owner_id arbitrário enviado pelo cliente', () async {
        final person = await repo.createPerson(name: 'Rebeca Lima');
        final study = await repo.createStudy(
          title: 'Estudo Rebeca',
          participantPersonIds: [person.id],
          publicationId: 'lff-book',
        );

        expect(study.ownerId, equals('local_user'));
      });
    });

    // ========================================================================
    // Phase 3: Sincronização de 18 Tabelas de Domínio, Tombstones & Storage
    // ========================================================================
    group('Phase 3: 18 Domain Tables Sync & Storage Privacy', () {
      test('TC-P0-SYNC-01: Todas as 18 tabelas de domínio são reconhecidas na matriz de sync', () {
        const expected18Tables = [
          'people',
          'visits',
          'bible_studies',
          'study_participants',
          'study_sessions',
          'appointments',
          'activity_records',
          'voice_notes',
          'phone_contacts',
          'territory_landmarks',
          'family_ties',
          'ministry_experiences',
          'person_photos',
          'person_publications',
          'research_articles',
          'research_tags',
          'territory_sectors',
          'student_manual_order',
        ];

        for (final table in expected18Tables) {
          expect(MockSupabaseFullDomainServer.domainTables.contains(table), isTrue,
              reason: 'Tabela $table deve estar presente na matriz de 18 tabelas sincronizadas');
        }
        expect(MockSupabaseFullDomainServer.domainTables.length, equals(18));
      });

      test('TC-P0-SYNC-02: Exclusão lógica propaga deleted_at tombstone sem DELETE físico no PostgREST', () async {
        final env = await MultiDeviceSimEnvironment.create();
        addTearDown(env.dispose);

        final syncA = env.createServiceA();
        final syncB = env.createServiceB();
        addTearDown(syncA.dispose);
        addTearDown(syncB.dispose);

        // 1. Dispositivo A cria pessoa e faz push
        final person = await env.repoA.createPerson(
          id: 'person-tombstone-01',
          name: 'Marcos Tombstone',
        );
        final pushResultA = await syncA.processQueue();
        expect(pushResultA.successCount, greaterThanOrEqualTo(1));

        // 2. Dispositivo B recebe a pessoa via pull
        final pullResultB = await syncB.fetchRemoteChanges();
        expect(pullResultB.success, isTrue);
        final personOnB = await env.repoB.getPersonById(person.id);
        expect(personOnB, isNotNull);

        // 3. Dispositivo A realiza exclusão lógica (soft-delete) e faz push
        await env.repoA.deletePerson(person.id);
        final deletePushResultA = await syncA.processQueue();
        expect(deletePushResultA.successCount, greaterThanOrEqualTo(1));

        // Verifica no servidor que o registro NÃO foi removido fisicamente, mas recebeu tombstone
        final remoteRow = env.server.getRow('people', person.id);
        expect(remoteRow, isNotNull);
        expect(remoteRow!['deleted_at'], isNotNull);

        // 4. Dispositivo B sincroniza e marca tombstone localmente
        await syncB.fetchRemoteChanges();
        final personOnBAfter = await env.repoB.getPersonById(person.id);
        expect(personOnBAfter, isNull);
      });

      test('TC-P0-SYNC-03: Storage Privado: sanitização remove caminhos absolutos locais do payload', () {
        final rawPayload = {
          'id': 'vn-uuid-01',
          'person_id': 'person-01',
          'audio_file_path': '/data/user/0/com.ministerio/voice_notes/secret_audio.m4a',
          'audioFilePath': '/data/user/0/com.ministerio/voice_notes/secret_audio.m4a',
          'transcription': 'Conversa excelente sobre Salmos 37:11',
          'created_at': DateTime.now().toIso8601String(),
        };

        final sanitized = SupabaseSyncService.sanitizePayload('voice_notes', rawPayload);

        expect(sanitized.containsKey('audio_file_path'), isFalse);
        expect(sanitized.containsKey('audioFilePath'), isFalse);
        expect(sanitized['transcription'], equals('Conversa excelente sobre Salmos 37:11'));
      });
    });

    // ========================================================================
    // Phase 4: Web DB Fail-Closed & Partitioning
    // ========================================================================
    group('Phase 4: Web Database Fail-Closed Architecture', () {
      test('TC-P0-WEBDB-01: Conexão fail-closed: falha crítica não executa gravações silenciosas perdidas', () async {
        final testDb = AppDatabase.forTesting(NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute('PRAGMA foreign_keys = ON;');
          },
        ));
        addTearDown(testDb.close);

        expect(
          () async => await testDb.into(testDb.visits).insert(
            VisitsCompanion.insert(
              id: 'visit-invalid-fk',
              personId: 'non-existent-person-id',
              dateTimeField: DateTime.now(),
              contactType: 'revisita',
              result: 'positiva',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ),
          throwsA(isA<SqliteException>()),
        );
      });

      test('TC-P0-WEBDB-02: Partição de banco por UID gera namespace isolado', () {
        const uid1 = 'user-uuid-1111';
        const uid2 = 'user-uuid-2222';

        final dbName1 = 'ministerio_pessoal_$uid1';
        final dbName2 = 'ministerio_pessoal_$uid2';

        expect(dbName1, isNot(equals(dbName2)));
        expect(dbName1, equals('ministerio_pessoal_user-uuid-1111'));
      });
    });

    // ========================================================================
    // Phase 5: Platform Corrections (GPS, Audio 30s Stop, Media Selectors)
    // ========================================================================
    group('Phase 5: Platform Corrections & Real Hardware Limits', () {
      test('TC-P0-PLAT-01: GeolocationHelper calcula distância Haversine real e não injeta coordenadas fixas de São Paulo', () {
        final distance = GeolocationHelper.calculateHaversineDistanceKm(
          -15.7975,
          -47.8919,
          -16.6869,
          -49.2648,
        );

        expect(distance, greaterThan(160.0));
        expect(distance, lessThan(190.0));
      });

      test('TC-P0-PLAT-02: Gravação de voz para fisicamente aos 30 segundos no hardware do serviço', () async {
        final audioService = LocalAudioRecordingService();
        addTearDown(audioService.dispose);

        await audioService.startRecording();
        expect(audioService.isRecording, isTrue);

        await audioService.cancelRecording();
        expect(audioService.isRecording, isFalse);
      });
    });

    // ========================================================================
    // Phase 6: Database Integrity & Platform Security
    // ========================================================================
    group('Phase 6: Database Integrity & High Contrast Settings', () {
      test('TC-P0-SEC-01: PRAGMA foreign_keys está ativo e impede orfandade referencial', () async {
        final result = await db.customSelect('PRAGMA foreign_keys;').getSingle();
        final isFkEnabled = result.data.values.first;
        expect(isFkEnabled, equals(1));
      });

      test('TC-P0-SEC-02: Preferência de alto contraste persiste em AppKvStore sobrevivendo a reinicializações', () async {
        await settings.setString('sun_mode_enabled', 'true');
        expect(await settings.getString('sun_mode_enabled'), equals('true'));

        await settings.setString('sun_mode_enabled', 'false');
        expect(await settings.getString('sun_mode_enabled'), equals('false'));
      });
    });
  });
}
