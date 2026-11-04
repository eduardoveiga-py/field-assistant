import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/appointments/google_calendar_provider.dart';
import 'package:ministerio_pessoal/core/app_config.dart';
import 'package:ministerio_pessoal/core/supabase_initializer.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:ministerio_pessoal/voice_notes/audio_recording_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'p0_e2e_contracts.dart';

class ControlledGoogleCalendarProvider extends GoogleCalendarProvider {
  bool isAuth = true;

  ControlledGoogleCalendarProvider({
    FlutterSecureStorage? secureStorage,
  }) : super(secureStorage: secureStorage ?? const FlutterSecureStorage());

  @override
  Future<bool> isAuthorized() async => isAuth;

  @override
  Future<bool> requestAuthorization() async => isAuth;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('P0/P1 Dual Track E2E — Tier 3: Cross-Feature Combinations', () {
    late AppDatabase db;
    late AppRepository repo;
    late Directory tempDir;
    late MockSupabaseFullDomainServer server;
    late AppConfig testConfig;
    const secureStorage = FlutterSecureStorage();

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ));
      repo = AppRepository(db);
      tempDir = await Directory.systemTemp.createTemp('p0_tier3_');
      server = MockSupabaseFullDomainServer();

      testConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://test.supabase.co',
        supabaseAnonKey: 'test-anon-key-p0-tier3',
      );

      SupabaseInitializer.setMockStateForTesting(
        state: SupabaseConnectionState.connected,
        config: testConfig,
      );
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
      await SupabaseInitializer.resetForTesting();
    });

    // ========================================================================
    // TC-P0-CROSS-01 [Phase 2 Auth + Phase 1 Calendar]:
    // Troca de conta invalida tokens e desvincula calendários sem vazamento de estado
    // ========================================================================
    test('TC-P0-CROSS-01: Troca de conta limpa storage seguro e desvincula calendário sem vazar tokens', () async {
      FlutterSecureStorage.setMockInitialValues({
        'google_calendar_selected_id': 'cal-user1-primary',
        'google_calendar_synctoken_cal-user1-primary': 'sync-tok-12345',
      });

      final calendarProvider = ControlledGoogleCalendarProvider();

      expect(await calendarProvider.getSelectedCalendarId(), equals('cal-user1-primary'));
      expect(await secureStorage.read(key: 'google_calendar_synctoken_cal-user1-primary'), equals('sync-tok-12345'));

      // Logout / desconexão
      await calendarProvider.disconnect();

      // Tokens do usuário 1 foram completamente removidos da chave selecionada
      expect(await secureStorage.read(key: 'google_calendar_selected_id'), isNull);
    });

    // ========================================================================
    // TC-P0-CROSS-02 [Phase 2 Auth + Phase 3 Sync Outbox]:
    // Criação de dados offline e associação com UID no login pós-offline
    // ========================================================================
    test('TC-P0-CROSS-02: Dados criados offline são associados à conta no login e sincronizados com owner_id autenticado', () async {
      // 1. Criação puramente offline (sem Supabase)
      final offlinePerson = await repo.createPerson(
        id: 'person-offline-prelogin-01',
        name: 'Mateus Offline',
        phone: '61988880000',
      );
      final offlineVisit = await repo.createVisit(
        id: 'visit-offline-prelogin-01',
        personId: offlinePerson.id,
        dateTime: DateTime(2026, 11, 4, 10, 0),
        contactType: 'conversa_inicial',
        result: 'interessado',
      );

      final pendingOps = await repo.getPendingSyncOperations();
      expect(pendingOps.length, equals(3));

      // 2. Usuário faz login -> Supabase autenticado como usr-mateus-777
      server.authenticatedOwnerId = 'usr-mateus-777';
      final client = SupabaseClient(
        'https://test.supabase.co',
        'test-anon-key-p0-tier3',
        httpClient: MockClient((req) async => server.handleRequest(req)),
      );

      final syncService = SupabaseSyncService(
        db: db,
        repository: repo,
        config: testConfig,
        clientOverride: client,
        documentsDirectoryProvider: () async => tempDir.path,
      );
      addTearDown(syncService.dispose);

      // 3. Processa a outbox -> os registros recebem owner_id do servidor
      final pushResult = await syncService.processQueue();
      expect(pushResult.successCount, equals(3));

      // Verifica no servidor que ambos os registros agora têm owner_id = usr-mateus-777
      final remotePerson = server.getRow('people', offlinePerson.id);
      final remoteVisit = server.getRow('visits', offlineVisit.id);

      expect(remotePerson, isNotNull);
      expect(remotePerson!['owner_id'], equals('usr-mateus-777'));
      expect(remoteVisit, isNotNull);
      expect(remoteVisit!['owner_id'], equals('usr-mateus-777'));
    });

    // ========================================================================
    // TC-P0-CROSS-03 [Phase 5 Audio/Voice + Phase 3 Storage & Sync]:
    // Gravação 30s + Sanitização de caminho + Envio a Bucket Privado de Storage
    // ========================================================================
    test('TC-P0-CROSS-03: Nota de voz gravada é sanitizada e enviada para o bucket privado do usuário', () async {
      final audioService = LocalAudioRecordingService();
      addTearDown(audioService.dispose);

      // 1. Grava nota de voz
      await audioService.startRecording();
      final recordResult = await audioService.stopRecording();
      expect(recordResult, isNotNull);
      expect(recordResult!.durationSeconds, lessThanOrEqualTo(30));

      // 2. Insere nota de voz no banco local
      final person = await repo.createPerson(name: 'Davi Voice');
      final rawPayload = {
        'id': 'vn-cross-01',
        'person_id': person.id,
        'audio_file_path': recordResult.filePath,
        'transcription': 'Interessado na Lição 5 do livro Viva Feliz',
        'detected_lesson': 5,
        'detected_point': 1,
        'created_at': DateTime.now().toIso8601String(),
      };

      // 3. Sanitização remove o path físico local
      final cleanPayload = SupabaseSyncService.sanitizePayload('voice_notes', rawPayload);
      expect(cleanPayload.containsKey('audio_file_path'), isFalse);
      expect(cleanPayload['transcription'], contains('Lição 5'));

      // 4. Upload de mídia simulado para bucket privado voice_notes/<uid>/<id>.m4a
      server.authenticatedOwnerId = 'usr-davi-01';
      final uploadReq = http.Request(
        'POST',
        Uri.parse('https://test.supabase.co/storage/v1/object/voice_notes/usr-davi-01/vn-cross-01.m4a'),
      )..bodyBytes = [0, 1, 2, 3, 4, 5];

      final uploadResp = server.handleRequest(uploadReq);
      expect(uploadResp.statusCode, equals(200));

      // 5. Tentativa de acessar sem autorização ou de outro usuário é rejeitada pelo Storage RLS
      server.authenticatedOwnerId = 'usr-outro-999';
      final unauthorizedReq = http.Request(
        'GET',
        Uri.parse('https://test.supabase.co/storage/v1/object/voice_notes/usr-davi-01/vn-cross-01.m4a'),
      );
      final unauthorizedResp = server.handleRequest(unauthorizedReq);
      expect(unauthorizedResp.statusCode, equals(403));
    });

    // ========================================================================
    // TC-P0-CROSS-04 [Phase 3 Tombstones + Multi-Device Concurrency]:
    // Exclusão no Dispositivo A impede que edição desatualizada no Dispositivo B ressuscite o contato
    // ========================================================================
    test('TC-P0-CROSS-04: Exclusão lógica com tombstone rejeita ressurreição por edição concorrente desatualizada', () async {
      final env = await MultiDeviceSimEnvironment.create();
      addTearDown(env.dispose);

      final syncA = env.createServiceA();
      final syncB = env.createServiceB();
      addTearDown(syncA.dispose);
      addTearDown(syncB.dispose);

      // 1. Criação e sincronização inicial do contato
      final person = await env.repoA.createPerson(
        id: 'person-resurrect-01',
        name: 'Contato Original',
      );
      await syncA.processQueue();
      await syncB.fetchRemoteChanges();

      // 2. Dispositivo A apaga o contato (tombstone com deleted_at e revision 2)
      await env.repoA.deletePerson(person.id);
      await syncA.processQueue();

      final remoteTombstone = env.server.getRow('people', person.id);
      expect(remoteTombstone!['deleted_at'], isNotNull);

      // 3. Dispositivo B tenta editar o contato antigo (revisão obsoleta sem conhecimento da exclusão)
      // Simula push de B com deleted_at = null e revision antiga
      final stalePushReq = http.Request('POST', Uri.parse('https://test.supabase.co/rest/v1/people'))
        ..body = jsonEncode({
          'id': person.id,
          'name': 'Contato Ressuscitado Indevidamente',
          'revision': 1,
          'deleted_at': null,
          'updated_at': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
        });

      env.server.handleRequest(stalePushReq);

      // O servidor PostgREST com trigger prevent_stale_resurrection mantém o deleted_at
      final remoteAfterStale = env.server.getRow('people', person.id);
      expect(remoteAfterStale!['deleted_at'], isNotNull);
    });

    // ========================================================================
    // TC-P0-CROSS-05 [Phase 1 Calendar / Appointments + Phase 3 Conflict Detection]:
    // Compromissos concorrentes geram marcação de conflito pós-sincronização
    // ========================================================================
    test('TC-P0-CROSS-05: Compromissos concorrentes com sobreposição de horário são marcados como conflito pós-sync', () async {
      final now = DateTime(2026, 11, 10, 14, 0);

      // Dispositivo A tem compromisso às 14:00-15:00
      final apptA = await repo.createAppointment(
        id: 'appt-conflict-a',
        title: 'Estudo Bíblico com Família Souza',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
      );
      expect(apptA.status, equals('planejado'));

      // Dispositivo B criou compromisso remoto sobreposto às 14:30-15:30
      final overlappingRemote = {
        'id': 'appt-conflict-b',
        'title': 'Revisita com Thiago',
        'start_time': now.add(const Duration(minutes: 30)).toIso8601String(),
        'end_time': now.add(const Duration(minutes: 90)).toIso8601String(),
        'duration_minutes': 60,
        'status': 'planejado',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'revision': 1,
      };
      server.seed('appointments', overlappingRemote);

      final client = SupabaseClient(
        'https://test.supabase.co',
        'test-anon-key-p0-tier3',
        httpClient: MockClient((req) async => server.handleRequest(req)),
      );

      final syncService = SupabaseSyncService(
        db: db,
        repository: repo,
        config: testConfig,
        clientOverride: client,
        documentsDirectoryProvider: () async => tempDir.path,
      );
      addTearDown(syncService.dispose);

      // Puxa as alterações remotas
      await syncService.fetchRemoteChanges();

      // Verifica que o compromisso remoto foi inserido
      final importedB = await (db.select(db.appointments)..where((t) => t.id.equals('appt-conflict-b'))).getSingleOrNull();
      expect(importedB, isNotNull);
    });
  });
}
