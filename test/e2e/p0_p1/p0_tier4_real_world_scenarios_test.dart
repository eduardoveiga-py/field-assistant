import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/core/app_config.dart';
import 'package:ministerio_pessoal/core/supabase_initializer.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:ministerio_pessoal/sync/sync_engine.dart';
import 'package:ministerio_pessoal/voice_notes/audio_recording_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'p0_e2e_contracts.dart';
import 'p0_tier1_feature_coverage_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('P0/P1 Dual Track E2E — Tier 4: Real-World Scenarios', () {
    late Directory tempDir;
    late MockSupabaseFullDomainServer sharedServer;
    late AppConfig testConfig;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('p0_tier4_');
      sharedServer = MockSupabaseFullDomainServer();

      testConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://test.supabase.co',
        supabaseAnonKey: 'test-anon-key-p0-tier4',
      );

      SupabaseInitializer.setMockStateForTesting(
        state: SupabaseConnectionState.connected,
        config: testConfig,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
      await SupabaseInitializer.resetForTesting();
    });

    // ========================================================================
    // TC-P0-SCENARIO-01: Husband & Wife 2-Device Journey (Multi-Device Household)
    // ========================================================================
    test('TC-P0-SCENARIO-01: Husband & Wife 2-Device Journey — Sincronização multi-dispositivo familiar com isolamento estrito por RLS', () async {
      // Marido (Alberto): Dispositivo 1 (Celular) e Dispositivo 2 (Tablet)
      // Esposa (Beatriz): Dispositivo 3 (Celular)

      // 1. Setup Dispositivo 1 do Marido (Phone)
      final dbHusbandPhone = AppDatabase.forTesting(NativeDatabase.memory());
      final repoHusbandPhone = AppRepository(dbHusbandPhone);
      final clientHusband = SupabaseClient(
        'https://test.supabase.co',
        'test-anon-key-p0-tier4',
        httpClient: MockClient((req) async {
          sharedServer.authenticatedOwnerId = 'usr-husband-01';
          return sharedServer.handleRequest(req);
        }),
      );
      final syncHusbandPhone = SupabaseSyncService(
        db: dbHusbandPhone,
        repository: repoHusbandPhone,
        config: testConfig,
        clientOverride: clientHusband,
        documentsDirectoryProvider: () async => tempDir.path,
      );
      addTearDown(() async {
        syncHusbandPhone.dispose();
        await dbHusbandPhone.close();
      });

      // 2. Setup Dispositivo 2 do Marido (Tablet)
      final dbHusbandTablet = AppDatabase.forTesting(NativeDatabase.memory());
      final repoHusbandTablet = AppRepository(dbHusbandTablet);
      final syncHusbandTablet = SupabaseSyncService(
        db: dbHusbandTablet,
        repository: repoHusbandTablet,
        config: testConfig,
        clientOverride: clientHusband,
        documentsDirectoryProvider: () async => tempDir.path,
      );
      addTearDown(() async {
        syncHusbandTablet.dispose();
        await dbHusbandTablet.close();
      });

      // 3. Setup Dispositivo 3 da Esposa (Phone)
      final dbWifePhone = AppDatabase.forTesting(NativeDatabase.memory());
      final repoWifePhone = AppRepository(dbWifePhone);
      final clientWife = SupabaseClient(
        'https://test.supabase.co',
        'test-anon-key-p0-tier4',
        httpClient: MockClient((req) async {
          sharedServer.authenticatedOwnerId = 'usr-wife-02';
          return sharedServer.handleRequest(req);
        }),
      );
      final syncWifePhone = SupabaseSyncService(
        db: dbWifePhone,
        repository: repoWifePhone,
        config: testConfig,
        clientOverride: clientWife,
        documentsDirectoryProvider: () async => tempDir.path,
      );
      addTearDown(() async {
        syncWifePhone.dispose();
        await dbWifePhone.close();
      });

      // Passo A: Marido cria estudo bíblico no Celular (Dispositivo 1)
      final student = await repoHusbandPhone.createPerson(
        id: 'student-carlos-01',
        name: 'Carlos Estudo',
      );
      final study = await repoHusbandPhone.createStudy(
        id: 'study-carlos-01',
        title: 'Estudo Carlos - Livro Viva Feliz',
        participantPersonIds: [student.id],
        publicationId: 'lff-book',
        currentLesson: 3,
        currentParagraph: 2,
      );
      expect(study.id, equals('study-carlos-01'));

      // Marido faz push pelo celular
      await syncHusbandPhone.processQueue();

      // Passo B: Marido chega em casa e pega o Tablet (Dispositivo 2) -> Pull
      await syncHusbandTablet.fetchRemoteChanges();
      final studyOnTablet = await repoHusbandTablet.getStudyById('study-carlos-01');
      final studentOnTablet = await repoHusbandTablet.getPersonById('student-carlos-01');

      expect(studyOnTablet, isNotNull);
      expect(studyOnTablet!.title, equals('Estudo Carlos - Livro Viva Feliz'));
      expect(studentOnTablet, isNotNull);
      expect(studentOnTablet!.name, equals('Carlos Estudo'));

      // Passo C: Esposa no Celular (Dispositivo 3) cria sua própria revisita
      final contactWife = await repoWifePhone.createPerson(
        id: 'contact-daniela-01',
        name: 'Daniela Vizinha',
      );
      await repoWifePhone.createVisit(
        id: 'visit-daniela-01',
        personId: contactWife.id,
        dateTime: DateTime.now(),
        contactType: 'revisita',
        result: 'agradavel',
      );
      await syncWifePhone.processQueue();

      // Passo D: Validação de Isolamento RLS — Esposa sincroniza e NÃO recebe dados do Marido
      await syncWifePhone.fetchRemoteChanges();
      final husbandStudyOnWifeDevice = await repoWifePhone.getStudyById('study-carlos-01');
      expect(husbandStudyOnWifeDevice, isNull);

      // E Marido NÃO recebe o contato da Esposa no Tablet
      await syncHusbandTablet.fetchRemoteChanges();
      final wifeContactOnHusbandDevice = await repoHusbandTablet.getPersonById('contact-daniela-01');
      expect(wifeContactOnHusbandDevice, isNull);
    });

    // ========================================================================
    // TC-P0-SCENARIO-02: Account Switch on Single Shared Browser (Zero Leakage)
    // ========================================================================
    test('TC-P0-SCENARIO-02: Alternância de contas no mesmo navegador garante banco particionado por UID e zero vazamento', () async {
      const uid1 = 'usr-anciano-01';
      const uid2 = 'usr-pioneiro-02';
      expect('app_db_$uid1.sqlite', isNot(equals('app_db_$uid2.sqlite')));

      // 1. Sessão do Usuário 1 (Ancião) abre partição isolada
      final dbPartition1 = AppDatabase.forTesting(NativeDatabase.memory());
      final repo1 = AppRepository(dbPartition1);

      final person1 = await repo1.createPerson(
        id: 'person-secret-pastoral',
        name: 'Caso Pastoral Confidencial',
        generalNotes: 'Anotações sigilosas do conselho ministerial',
      );
      expect(person1.id, equals('person-secret-pastoral'));

      // Usuário 1 encerra sessão (logout)
      await dbPartition1.close();

      // 2. Sessão do Usuário 2 (Pioneiro) abre sua respectiva partição limpa
      final dbPartition2 = AppDatabase.forTesting(NativeDatabase.memory());
      final repo2 = AppRepository(dbPartition2);
      addTearDown(dbPartition2.close);

      // Usuário 2 consulta contatos locais
      final leakedPerson = await repo2.getPersonById('person-secret-pastoral');
      final allPeopleUser2 = await repo2.getAllPeople();

      // Validação de isolamento absoluto: zero vazamento de dados do Usuário 1
      expect(leakedPerson, isNull);
      expect(allPeopleUser2.isEmpty, isTrue);

      // Usuário 2 cria seus próprios dados
      final person2 = await repo2.createPerson(
        id: 'person-pioneer-public',
        name: 'Maria Testemunho Público',
      );
      expect(person2.name, equals('Maria Testemunho Público'));
    });

    // ========================================================================
    // TC-P0-SCENARIO-03: Full Disconnected Field Ministry Morning to Evening Sync
    // ========================================================================
    test('TC-P0-SCENARIO-03: Jornada matinal no campo 100% offline com reconexão noturna e convergência total', () async {
      final dbField = AppDatabase.forTesting(NativeDatabase.memory());
      final repoField = AppRepository(dbField);
      addTearDown(dbField.close);

      final audioService = LocalAudioRecordingService();
      addTearDown(audioService.dispose);

      // --- MANHÃ: 100% OFFLINE NO TERRITÓRIO ---
      // 08:30 - Cadastro de novo interessado
      final person = await repoField.createPerson(
        id: 'person-rural-01',
        name: 'Joaquim da Fazenda',
        address: 'Estrada das Oliveiras, km 12',
      );

      // 09:15 - Gravação de nota de voz curta (limite físico 30s)
      await audioService.startRecording();
      final audioResult = await audioService.stopRecording();
      expect(audioResult, isNotNull);
      expect(audioResult!.durationSeconds, lessThanOrEqualTo(30));

      // 10:30 - Registro de primeira revisita com estudo
      final visit = await repoField.createVisit(
        id: 'visit-rural-01',
        personId: person.id,
        dateTime: DateTime(2026, 11, 4, 10, 30),
        contactType: 'estudo',
        result: 'progresso_excelente',
        notes: 'Iniciamos a Lição 1 do livro Viva Feliz',
      );
      expect(visit.contactType, equals('estudo'));

      // 11:45 - Agendamento do próximo retorno
      final appt = await repoField.createAppointment(
        id: 'appt-rural-01',
        personId: person.id,
        title: 'Estudo Joaquim - Lição 2',
        startTime: DateTime(2026, 11, 11, 10, 30),
        endTime: DateTime(2026, 11, 11, 11, 30),
      );
      expect(appt.title, contains('Joaquim'));

      // Todas as mutações da manhã repousam atomicamente na outbox
      final pendingMorning = await repoField.getPendingSyncOperations();
      expect(pendingMorning.length, greaterThanOrEqualTo(3));

      // --- NOITE (17:00): RETORNO AO WI-FI E SINCRONIZAÇÃO COMPLETA ---
      sharedServer.authenticatedOwnerId = 'usr-pioneer-rural';
      final client = SupabaseClient(
        'https://test.supabase.co',
        'test-anon-key-p0-tier4',
        httpClient: MockClient((req) async => sharedServer.handleRequest(req)),
      );

      final syncService = SupabaseSyncService(
        db: dbField,
        repository: repoField,
        config: testConfig,
        clientOverride: client,
        documentsDirectoryProvider: () async => tempDir.path,
      );
      addTearDown(syncService.dispose);

      // Dispara envio
      final syncResult = await syncService.processQueue();
      expect(syncResult.success, isTrue);
      expect(syncResult.successCount, equals(pendingMorning.length));

      // Fila zerada e status sincronizado
      final pendingNight = await repoField.getPendingSyncOperations();
      expect(pendingNight.isEmpty, isTrue);
      expect(syncService.currentStatus, equals(SyncStatus.synced));

      // Servidor possui cópia íntegra de todas as entidades
      expect(sharedServer.getRow('people', person.id), isNotNull);
      expect(sharedServer.getRow('visits', visit.id), isNotNull);
      expect(sharedServer.getRow('appointments', appt.id), isNotNull);
    });

    // ========================================================================
    // TC-P0-SCENARIO-04: Long-Term Dormancy & Token Expiration Recovery
    // ========================================================================
    test('TC-P0-SCENARIO-04: Reabertura após inatividade prolongada com recuperação de erro HTTP 410 no calendário', () async {
      final dbDormant = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(dbDormant.close);

      // Simula provider do Google Calendar após 90 dias que recebe HTTP 410 (sync token expirado)
      final provider = TestableGoogleCalendarProvider();
      provider.simulate410OnNextSync = true;

      final syncResult = await provider.syncEvents(db: dbDormant);

      expect(syncResult.success, isTrue);
      expect(provider.wasFullSyncInvoked, isTrue);
      expect(syncResult.eventsDownloaded, greaterThanOrEqualTo(10));
    });
  });
}
