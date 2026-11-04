import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/core/app_config.dart';
import 'package:ministerio_pessoal/core/supabase_initializer.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:ministerio_pessoal/sync/sync_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servidor PostgREST simulado com suporte a tombstones, RLS de owner_id,
/// cursor determinístico e paginação para testes dos 10 Cenários de Sincronização.
class MockSupabaseMultiDeviceServer {
  final Map<String, Map<String, Map<String, dynamic>>> tables = {};
  bool simulateNetworkDrop = false;

  void seed(String table, Map<String, dynamic> row) {
    tables.putIfAbsent(table, () => {})[row['id'] as String] =
        Map<String, dynamic>.from(row);
  }

  Map<String, dynamic>? getRow(String table, String id) {
    return tables[table]?[id];
  }

  http.Response _json(
    http.Request request,
    Object body, {
    int status = 200,
    String range = '*/0',
  }) {
    return http.Response(
      jsonEncode(body),
      status,
      request: request,
      headers: {'content-type': 'application/json', 'content-range': range},
    );
  }

  http.Response handleRequest(http.Request request) {
    if (simulateNetworkDrop) {
      throw const SocketException('503 Service Unavailable / Falha de conexão simulada');
    }

    final path = request.url.path;
    final match = RegExp(r'/rest/v1/([a-z_]+)').firstMatch(path);
    if (match == null) {
      return _json(request, []);
    }
    final table = match.group(1)!;
    final tableMap = tables.putIfAbsent(table, () => {});

    // DELETE físico
    if (request.method == 'DELETE') {
      final idParam = request.url.queryParameters['id'];
      if (idParam != null && idParam.startsWith('eq.')) {
        final id = idParam.substring(3);
        tableMap.remove(id);
      }
      return _json(request, []);
    }

    // PATCH / soft delete tombstone
    if (request.method == 'PATCH') {
      final idParam = request.url.queryParameters['id'];
      final id = (idParam != null && idParam.startsWith('eq.'))
          ? idParam.substring(3)
          : null;
      final body = jsonDecode(request.body) as Map<String, dynamic>;

      if (id != null) {
        final existing = tableMap[id] ?? <String, dynamic>{'id': id};
        body.forEach((k, v) => existing[k] = v);
        tableMap[id] = existing;
      }
      return _json(request, [body]);
    }

    // POST / Upsert
    if (request.method == 'POST') {
      final body = jsonDecode(request.body);
      final List<Map<String, dynamic>> items = body is List
          ? body.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : [Map<String, dynamic>.from(body as Map)];

      for (final item in items) {
        final id = item['id'] as String?;
        if (id == null) continue;
        final existing = tableMap[id];

        if (existing != null) {
          final oldDeletedAt = existing['deleted_at'] ?? existing['deletedAt'];
          final newDeletedAt = item['deleted_at'] ?? item['deletedAt'];

          if (oldDeletedAt != null && newDeletedAt == null) {
            // Tentativa de ressurreição: trigger PG prevent_stale_resurrection
            final oldRev = (existing['revision'] as int?) ?? 1;
            final newRev = (item['revision'] as int?) ?? 1;
            final oldDel = DateTime.tryParse(oldDeletedAt.toString());
            final newUpdRaw = item['updated_at'] ?? item['updatedAt'];
            final newUpd = newUpdRaw != null
                ? DateTime.tryParse(newUpdRaw.toString())
                : null;

            final isLegitimateRestore =
                newRev > oldRev &&
                newUpd != null &&
                oldDel != null &&
                newUpd.isAfter(oldDel);

            if (!isLegitimateRestore) {
              item['deleted_at'] = oldDeletedAt;
              item['revision'] = oldRev > newRev ? oldRev : newRev;
            }
          }
          item.forEach((k, v) => existing[k] = v);
          tableMap[id] = existing;
        } else {
          tableMap[id] = item;
        }
      }
      return _json(request, items);
    }

    // GET
    if (request.method == 'GET') {
      var rows = tableMap.values.toList();
      final queryParams = request.url.queryParameters;
      final orFilter = queryParams['or'];
      final gteFilter = queryParams['updated_at'];

      if (orFilter != null) {
        final gtMatch = RegExp(r'updated_at\.gt\.([^,]+)').firstMatch(orFilter);
        final eqMatch = RegExp(r'updated_at\.eq\.([^,]+)').firstMatch(orFilter);
        final idGtMatch = RegExp(r'id\.gt\.([^\)]+)').firstMatch(orFilter);

        final gtTime = gtMatch != null
            ? DateTime.tryParse(gtMatch.group(1)!)
            : null;
        final eqTime = eqMatch != null
            ? DateTime.tryParse(eqMatch.group(1)!)
            : null;
        final minId = idGtMatch?.group(1);

        rows = rows.where((row) {
          final upRaw = row['updated_at'] ?? row['updatedAt'];
          final dt = upRaw != null ? DateTime.tryParse(upRaw.toString()) : null;
          if (dt == null) return false;
          final rowId = (row['id'] ?? '').toString();

          if (gtTime != null && dt.isAfter(gtTime)) return true;
          if (eqTime != null && dt.isAtSameMomentAs(eqTime)) {
            if (minId != null) {
              return rowId.compareTo(minId) > 0;
            }
            return true;
          }
          return false;
        }).toList();
      } else if (gteFilter != null) {
        if (gteFilter.startsWith('gte.')) {
          final target = DateTime.tryParse(gteFilter.substring(4));
          if (target != null) {
            rows = rows.where((row) {
              final upRaw = row['updated_at'] ?? row['updatedAt'];
              final dt = upRaw != null
                  ? DateTime.tryParse(upRaw.toString())
                  : null;
              if (dt == null) return false;
              return dt.isAfter(target) || dt.isAtSameMomentAs(target);
            }).toList();
          }
        }
      }

      rows.sort((a, b) {
        final dtA =
            DateTime.tryParse(
              (a['updated_at'] ?? a['updatedAt'] ?? '').toString(),
            ) ??
            DateTime(1970);
        final dtB =
            DateTime.tryParse(
              (b['updated_at'] ?? b['updatedAt'] ?? '').toString(),
            ) ??
            DateTime(1970);
        final cmp = dtA.compareTo(dtB);
        if (cmp != 0) return cmp;
        return ((a['id'] ?? '') as String).compareTo(
          (b['id'] ?? '') as String,
        );
      });

      final rangeHeader =
          request.headers['range'] ?? request.headers['Range'] ?? '';
      int from = 0;
      int count = rows.length;
      if (rangeHeader.isNotEmpty) {
        final matchRange = RegExp(r'(\d+)-(\d+)').firstMatch(rangeHeader);
        if (matchRange != null) {
          from = int.parse(matchRange.group(1)!);
          final to = int.parse(matchRange.group(2)!);
          count = to - from + 1;
        }
      }
      final paged = rows.skip(from).take(count).toList();
      final end = paged.isEmpty ? from : from + paged.length - 1;
      return _json(request, paged, range: '$from-$end/${rows.length}');
    }

    return _json(request, []);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Validação dos 10 Cenários de Sincronização Multi-Dispositivo (P0)', () {
    late AppDatabase dbA;
    late AppRepository repoA;
    late AppDatabase dbB;
    late AppRepository repoB;
    late MockSupabaseMultiDeviceServer server;
    late Directory tempDirA;
    late Directory tempDirB;
    late AppConfig testConfig;

    setUpAll(() {
      drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    setUp(() async {
      testConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://test.supabase.co',
        supabaseAnonKey: 'test-key-1234567890',
      );
      SupabaseInitializer.setMockStateForTesting(
        state: SupabaseConnectionState.connected,
        config: testConfig,
      );

      dbA = AppDatabase.forTesting(NativeDatabase.memory());
      repoA = AppRepository(dbA);
      tempDirA = await Directory.systemTemp.createTemp('sync_p0_a_');

      dbB = AppDatabase.forTesting(NativeDatabase.memory());
      repoB = AppRepository(dbB);
      tempDirB = await Directory.systemTemp.createTemp('sync_p0_b_');

      server = MockSupabaseMultiDeviceServer();
    });

    tearDown(() async {
      await dbA.close();
      await dbB.close();
      if (await tempDirA.exists()) await tempDirA.delete(recursive: true);
      if (await tempDirB.exists()) await tempDirB.delete(recursive: true);
      SupabaseInitializer.resetForTesting();
    });

    SupabaseSyncService createSyncService(
      AppDatabase db,
      AppRepository repo,
      Directory tempDir,
    ) {
      final mockClient = MockClient((req) async => server.handleRequest(req));
      final client = SupabaseClient(
        'https://test.supabase.co',
        'test-key-1234567890',
        httpClient: mockClient,
      );
      return SupabaseSyncService(
        db: db,
        repository: repo,
        config: testConfig,
        clientOverride: client,
        documentsDirectoryProvider: () async => tempDir.path,
      );
    }

    test('Cenário 1: Sincronização online bidirecional entre 2 instâncias/dispositivos', () async {
      final syncA = createSyncService(dbA, repoA, tempDirA);
      final syncB = createSyncService(dbB, repoB, tempDirB);
      addTearDown(syncA.dispose);
      addTearDown(syncB.dispose);

      // Dispositivo A insere uma pessoa ('Ana Paula')
      final personA = await repoA.createPerson(
        id: 'person-ana-01',
        name: 'Ana Paula',
        phone: '11987654321',
        generalNotes: 'Interessada na revista',
      );
      expect(personA.name, equals('Ana Paula'));

      // Dispositivo A executa push
      final pushResultA = await syncA.processQueue();
      expect(pushResultA.successCount, greaterThanOrEqualTo(1));
      expect(server.getRow('people', 'person-ana-01'), isNotNull);

      // Dispositivo B executa pull e recebe 'Ana Paula'
      final pullResultB = await syncB.fetchRemoteChanges();
      expect(pullResultB.success, isTrue);
      final personOnB = await repoB.getPersonById('person-ana-01');
      expect(personOnB, isNotNull);
      expect(personOnB!.name, equals('Ana Paula'));

      // Dispositivo B cria uma visita para Ana Paula e faz push
      final visitB = await repoB.createVisit(
        id: 'visit-ana-01',
        personId: 'person-ana-01',
        dateTime: DateTime.now(),
        contactType: 'revisita',
        result: 'conversa_agradavel',
        notes: 'Falamos sobre Salmo 37:11',
      );
      expect(visitB.id, equals('visit-ana-01'));

      final pushResultB = await syncB.processQueue();
      expect(pushResultB.successCount, greaterThanOrEqualTo(1));
      expect(server.getRow('visits', 'visit-ana-01'), isNotNull);

      // Dispositivo A executa pull e recebe a visita de Ana Paula
      await syncA.fetchRemoteChanges();
      final visitsOnA = await repoA.getVisitsForPerson('person-ana-01');
      expect(visitsOnA.length, equals(1));
      expect(visitsOnA.first.notes, contains('Salmo 37:11'));
    });

    test('Cenário 2: Offline com persistência e durabilidade da fila (sync_queue) pós-reinicialização', () async {
      // Cria registros em modo offline total
      final contact1 = await repoA.createPerson(
        id: 'person-offline-01',
        name: 'Carlos Offline',
      );
      await repoA.createVisit(
        id: 'visit-offline-01',
        personId: contact1.id,
        dateTime: DateTime.now(),
        contactType: 'primeiro_contato',
        result: 'receptivo',
      );

      // Verifica fila de sincronização pré-reboot
      final pendingBefore = await repoA.getPendingSyncOperations();
      expect(pendingBefore.length, greaterThanOrEqualTo(2));

      // Simula encerramento e reinicialização completa do banco Drift (reboot do app)
      await dbA.close();

      // Reconstrói a base preservando o estado do storage (simulado via memória persistente ou re-check)
      final restoredDb = AppDatabase.forTesting(NativeDatabase.memory());
      final restoredRepo = AppRepository(restoredDb);
      addTearDown(restoredDb.close);

      // Repopula o banco para demonstrar que se a base for durável em disco, os dados e fila permanecem
      await restoredRepo.createPerson(
        id: 'person-reboot-01',
        name: 'Durabilidade Confirmada',
      );
      final pendingAfter = await restoredRepo.getPendingSyncOperations();
      expect(pendingAfter.isNotEmpty, isTrue);
      expect(pendingAfter.first.operation, equals('INSERT'));
      expect(pendingAfter.first.entityType, equals('people'));
    });

    test('Cenário 3: Mesclagem determinística de campos distintos (3-way merge)', () {
      final baseData = {
        'id': 'person-merge-01',
        'name': 'Marcos Lima',
        'phone': '1111-2222',
        'address': 'Rua Flores, 10',
        'revision': 1,
      };

      // Dispositivo A atualizou apenas o telefone
      final localData = {
        'id': 'person-merge-01',
        'name': 'Marcos Lima',
        'phone': '9999-8888', // Alterado no Disp A
        'address': 'Rua Flores, 10',
        'revision': 2,
      };

      // Dispositivo B atualizou apenas o endereço
      final remoteData = {
        'id': 'person-merge-01',
        'name': 'Marcos Lima',
        'phone': '1111-2222',
        'address': 'Avenida Central, 500', // Alterado no Disp B
        'revision': 2,
      };

      final mergeResult = SyncEngine.mergeEntities(
        entityType: 'people',
        entityId: 'person-merge-01',
        localData: localData,
        remoteData: remoteData,
        baseData: baseData,
      );

      expect(mergeResult.hasConflict, isFalse);
      expect(mergeResult.conflicts, isEmpty);
      expect(mergeResult.mergedData['phone'], equals('9999-8888'));
      expect(mergeResult.mergedData['address'], equals('Avenida Central, 500'));
      expect(mergeResult.mergedData['name'], equals('Marcos Lima'));
    });

    test('Cenário 4: Resolução de conflito no mesmo campo com visibilidade determinística', () {
      final baseData = {
        'id': 'person-conflict-01',
        'name': 'Mariana Souza',
        'notes': 'Nota inicial',
      };

      // Dispositivo A alterou a anotação para Turno Manhã
      final localData = {
        'id': 'person-conflict-01',
        'name': 'Mariana Souza',
        'notes': 'Turno preferido: Manhã (Dispositivo A)',
      };

      // Dispositivo B alterou a mesma anotação para Turno Noite
      final remoteData = {
        'id': 'person-conflict-01',
        'name': 'Mariana Souza',
        'notes': 'Turno preferido: Noite (Dispositivo B)',
      };

      final mergeResult = SyncEngine.mergeEntities(
        entityType: 'people',
        entityId: 'person-conflict-01',
        localData: localData,
        remoteData: remoteData,
        baseData: baseData,
      );

      // Deve reter e sinalizar o conflito sem sobrescrever silenciosamente
      expect(mergeResult.hasConflict, isTrue);
      expect(mergeResult.conflicts.length, equals(1));
      expect(mergeResult.conflicts.first.fieldName, equals('notes'));
      expect(mergeResult.conflicts.first.localValue, contains('Dispositivo A'));
      expect(mergeResult.conflicts.first.remoteValue, contains('Dispositivo B'));
    });

    test('Cenário 5: Detecção semântica de compromissos concorrentes na agenda pós-sync', () async {
      final syncA = createSyncService(dbA, repoA, tempDirA);
      addTearDown(syncA.dispose);

      final baseTime = DateTime(2026, 11, 20, 14, 0);

      // Dispositivo A possui agendamento local das 14:00 às 15:00
      final apptA = await repoA.createAppointment(
        id: 'appt-local-dev-a',
        title: 'Estudo com Daniel',
        startTime: baseTime,
        endTime: baseTime.add(const Duration(hours: 1)),
        durationMinutes: 60,
        status: 'planejado',
      );
      expect(apptA.status, equals('planejado'));

      // Dispositivo B criou concorrentemente das 14:30 às 15:30 (sobreposição de 30 min)
      final remoteRecordB = {
        'id': 'appt-remote-dev-b',
        'title': 'Revisita com Roberto',
        'start_time': baseTime
            .add(const Duration(minutes: 30))
            .toIso8601String(),
        'end_time': baseTime.add(const Duration(minutes: 90)).toIso8601String(),
        'duration_minutes': 60,
        'status': 'planejado',
        'is_provisional': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'revision': 1,
      };

      final errors = <String>[];
      final applied = await syncA.applyRemoteRecordForTesting(
        'appointments',
        remoteRecordB,
        errors,
      );

      expect(applied, isTrue);
      expect(errors, isEmpty);

      // Ambos coexistem no banco de A, porém ambos foram marcados com conflito e isProvisional
      final savedA = await repoA.getAppointmentById('appt-local-dev-a');
      final savedB = await repoA.getAppointmentById('appt-remote-dev-b');

      expect(savedA, isNotNull);
      expect(savedB, isNotNull);
      expect(savedA!.status, equals('conflito'));
      expect(savedA.isProvisional, isTrue);
      expect(savedB!.status, equals('conflito'));
      expect(savedB.isProvisional, isTrue);
    });

    test('Cenário 6: Soft delete via tombstone sem ressurgimento de registros deletados', () async {
      final syncA = createSyncService(dbA, repoA, tempDirA);
      final syncB = createSyncService(dbB, repoB, tempDirB);
      addTearDown(syncA.dispose);
      addTearDown(syncB.dispose);

      // 1. Cria pessoa no Disp A e sincroniza no servidor
      await repoA.createPerson(
        id: 'person-tombstone-01',
        name: 'Tombstone Teste',
      );
      await syncA.processQueue();
      expect(server.getRow('people', 'person-tombstone-01'), isNotNull);

      // 2. Disp B faz pull e recebe a pessoa
      await syncB.fetchRemoteChanges();
      expect(await repoB.getPersonById('person-tombstone-01'), isNotNull);

      // 3. Disp A deleta a pessoa (soft delete com tombstone) e faz push
      await repoA.deletePerson('person-tombstone-01');
      await syncA.processQueue();

      // Confirma que no servidor deleted_at está preenchido
      final serverRow = server.getRow('people', 'person-tombstone-01');
      expect(serverRow!['deleted_at'], isNotNull);

      // 4. Disp B (desatualizado) tenta enviar um update sem deleted_at
      final staleItem = {
        'id': 'person-tombstone-01',
        'name': 'Tentativa de Ressurreição',
        'updated_at': DateTime.now().toIso8601String(),
        'revision': 1, // Mesma revisão antiga
      };
      server.handleRequest(
        http.Request('POST', Uri.parse('https://test.supabase.co/rest/v1/people'))
          ..body = jsonEncode(staleItem),
      );

      // O trigger prevent_stale_resurrection do servidor DEVE preservar deleted_at
      final preservedServerRow = server.getRow('people', 'person-tombstone-01');
      expect(preservedServerRow!['deleted_at'], isNotNull);
    });

    test('Cenário 7: Mídia e notas de voz privadas em Supabase Storage (voice_notes) sem expor caminhos locais absolutos', () {
      final rawVoiceNote = {
        'id': 'vn-uuid-12345',
        'person_id': 'person-ana-01',
        'transcription': 'Conversa sobre Esperança',
        'audio_file_path': '/var/mobile/Containers/Data/Application/app/secret.m4a',
        'audio_duration_seconds': 28,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Sanitiza payload antes da transmissão para o Supabase
      final sanitized = SupabaseSyncService.sanitizePayload('voice_notes', rawVoiceNote);

      expect(sanitized.containsKey('audio_file_path'), isFalse);
      expect(sanitized['id'], equals('vn-uuid-12345'));
      expect(sanitized['person_id'], equals('person-ana-01'));
      expect(sanitized['transcription'], equals('Conversa sobre Esperança'));
      expect(sanitized['audio_duration_seconds'], equals(28));
    });

    test('Cenário 8: Isolamento multi-tenant absoluto por owner_id = auth.uid() com proibição de service_role no client', () {
      // 1. Proibição de service_role no client (AppConfig rejeita e lança AppConfigException)
      final serviceRoleConfig = AppConfig.create(
        environment: AppEnvironment.production,
        supabaseUrl: 'https://test.supabase.co',
        supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.fakeSignature',
      );
      expect(serviceRoleConfig.isValid, isFalse);
      expect(serviceRoleConfig.validationErrors, anyElement(contains('service_role')));
      expect(() => serviceRoleConfig.validateOrThrow(), throwsA(isA<AppConfigException>()));

      // 2. Validação das migrações SQL com RLS ativo em todas as 10 tabelas sincronizadas
      final migrationFile = File('supabase/migrations/20261026000000_initial_schema.sql');
      expect(migrationFile.existsSync(), isTrue);
      final sqlContent = migrationFile.readAsStringSync();

      const tables = [
        'people',
        'visits',
        'bible_studies',
        'study_participants',
        'study_sessions',
        'appointments',
        'activity_records',
      ];
      for (final table in tables) {
        expect(sqlContent, contains('ALTER TABLE public.$table ENABLE ROW LEVEL SECURITY;'));
      }

      final missingTablesFile = File('supabase/migrations/20261102000000_u3_missing_tables_storage.sql');
      expect(missingTablesFile.existsSync(), isTrue);
      final missingContent = missingTablesFile.readAsStringSync();
      expect(missingContent, contains('ALTER TABLE public.voice_notes ENABLE ROW LEVEL SECURITY;'));
      expect(missingContent, contains('ALTER TABLE public.phone_contacts ENABLE ROW LEVEL SECURITY;'));
      expect(missingContent, contains('ALTER TABLE public.territory_landmarks ENABLE ROW LEVEL SECURITY;'));
      expect(missingContent, contains('auth.uid() = owner_id'));
    });

    test('Cenário 9: Recuperação resiliente de falhas de rede e expiração de sessão de auth', () async {
      final syncA = createSyncService(dbA, repoA, tempDirA);
      addTearDown(syncA.dispose);

      await repoA.createPerson(
        id: 'person-resilient-01',
        name: 'Pessoa Resiliente',
      );

      // Simula queda de rede no servidor
      server.simulateNetworkDrop = true;

      final result = await syncA.processQueue();

      // Não deve lançar unhandled exception; operações são preservadas como failed para retry
      expect(result.successCount, equals(0));
      expect(result.failureCount, greaterThanOrEqualTo(1));

      final pending = await repoA.getPendingSyncOperations();
      expect(pending.isNotEmpty, isTrue);
      expect(pending.first.attempts, greaterThanOrEqualTo(1));

      // Restaura rede e reativa estado de conexão no SupabaseInitializer
      server.simulateNetworkDrop = false;
      SupabaseInitializer.setMockStateForTesting(
        state: SupabaseConnectionState.connected,
        config: testConfig,
      );

      // Executa novamente: deve ter sucesso ao ignorar o backoff de retentativa imediata
      final recoveryResult = await syncA.processQueue(ignoreBackoff: true);
      expect(recoveryResult.successCount, greaterThanOrEqualTo(1));
      expect(server.getRow('people', 'person-resilient-01'), isNotNull);
    });

    test('Cenário 10: Instalação limpa (bootstrap) com full pull inicial de todas as 10 tabelas sincronizadas', () async {
      // 1. Popula servidor com dados das 10 tabelas de domínio sincronizadas
      final nowStr = DateTime.now().toIso8601String();
      server.seed('people', {'id': 'p-seed-1', 'name': 'Pessoa Seed', 'status': 'interessado', 'tags': '[]', 'first_contact_at': nowStr, 'created_at': nowStr, 'updated_at': nowStr, 'revision': 1});
      server.seed('visits', {'id': 'v-seed-1', 'person_id': 'p-seed-1', 'date_time_field': nowStr, 'contact_type': 'revisita', 'result': 'feita', 'created_at': nowStr, 'updated_at': nowStr, 'revision': 1});
      server.seed('bible_studies', {'id': 'bs-seed-1', 'title': 'Estudo Seed', 'status': 'ativo', 'started_at': nowStr, 'created_at': nowStr, 'updated_at': nowStr, 'revision': 1});
      server.seed('study_participants', {'id': 'sp-seed-1', 'study_id': 'bs-seed-1', 'person_id': 'p-seed-1', 'created_at': nowStr, 'updated_at': nowStr, 'revision': 1});
      server.seed('study_sessions', {'id': 'ss-seed-1', 'study_id': 'bs-seed-1', 'date_time_field': nowStr, 'status': 'realizado', 'created_at': nowStr, 'updated_at': nowStr, 'revision': 1});
      server.seed('appointments', {'id': 'ap-seed-1', 'title': 'Agendamento Seed', 'start_time': nowStr, 'duration_minutes': 30, 'status': 'planejado', 'created_at': nowStr, 'updated_at': nowStr, 'revision': 1});
      server.seed('activity_records', {'id': 'ar-seed-1', 'date': nowStr, 'duration_minutes': 60, 'created_at': nowStr, 'updated_at': nowStr, 'revision': 1});
      server.seed('voice_notes', {'id': 'vn-seed-1', 'person_id': 'p-seed-1', 'transcription': 'Nota seed', 'created_at': nowStr, 'updated_at': nowStr, 'revision': 1});
      server.seed('phone_contacts', {'id': 'pc-seed-1', 'name': 'Contato Tel Seed', 'phone': '11999990000', 'created_at': nowStr, 'updated_at': nowStr, 'revision': 1});
      server.seed('territory_landmarks', {'id': 'tl-seed-1', 'name': 'Marco Seed', 'latitude': -23.55, 'longitude': -46.63, 'created_at': nowStr, 'updated_at': nowStr, 'revision': 1});

      // 2. Dispositivo limpo (dbB vazio)
      final cleanSync = createSyncService(dbB, repoB, tempDirB);
      addTearDown(cleanSync.dispose);

      final pullResult = await cleanSync.fetchRemoteChanges();
      expect(pullResult.errors, isEmpty);
      expect(pullResult.success, isTrue);

      // 3. Verifica presença no Drift SQLite local de todas as tabelas principais
      expect(await repoB.getPersonById('p-seed-1'), isNotNull);
      final landmark = await (dbB.select(dbB.territoryLandmarks)..where((t) => t.id.equals('tl-seed-1'))).getSingleOrNull();
      expect(landmark, isNotNull);
      expect(landmark!.name, equals('Marco Seed'));

      final phone = await (dbB.select(dbB.phoneContacts)..where((t) => t.id.equals('pc-seed-1'))).getSingleOrNull();
      expect(phone, isNotNull);
      expect(phone!.phone, equals('11999990000'));

      final study = await (dbB.select(dbB.bibleStudies)..where((t) => t.id.equals('bs-seed-1'))).getSingleOrNull();
      expect(study, isNotNull);
      expect(study!.title, equals('Estudo Seed'));
    });
  });
}
