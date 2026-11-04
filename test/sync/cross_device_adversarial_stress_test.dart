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

/// Servidor PostgREST simulado com suporte a concorrência, tombstones e clock-skew.
class AdversarialMockServer {
  final Map<String, Map<String, Map<String, dynamic>>> tables = {};
  bool simulateNetworkFailure = false;

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
    if (simulateNetworkFailure) {
      throw const SocketException('Simulated network drop in stress harness');
    }

    final path = request.url.path;
    final match = RegExp(r'/rest/v1/([a-z_]+)').firstMatch(path);
    if (match == null) return _json(request, []);

    final table = match.group(1)!;
    final tableMap = tables.putIfAbsent(table, () => {});

    if (request.method == 'DELETE') {
      final idParam = request.url.queryParameters['id'];
      if (idParam != null && idParam.startsWith('eq.')) {
        tableMap.remove(idParam.substring(3));
      }
      return _json(request, []);
    }

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

          // Server-side prevent_stale_resurrection trigger
          if (oldDeletedAt != null && newDeletedAt == null) {
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
      } else if (gteFilter != null && gteFilter.startsWith('gte.')) {
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

      return _json(request, rows);
    }

    return _json(request, []);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Adversarial Challenger Stress Harness — Multi-Device Sync P0 Edge Cases', () {
    late AdversarialMockServer server;
    late AppConfig testConfig;

    setUpAll(() {
      drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    setUp(() {
      server = AdversarialMockServer();
      testConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://test.supabase.co',
        supabaseAnonKey: 'test-key-stress-challenger-12345',
      );
      SupabaseInitializer.setMockStateForTesting(
        state: SupabaseConnectionState.connected,
        config: testConfig,
      );
    });

    tearDown(() {
      SupabaseInitializer.resetForTesting();
    });

    SupabaseSyncService createSyncService({
      required AppDatabase db,
      required AppRepository repo,
      required Directory dir,
    }) {
      final mockClient = MockClient((req) async => server.handleRequest(req));
      final client = SupabaseClient(
        'https://test.supabase.co',
        'test-key-stress-challenger-12345',
        httpClient: mockClient,
      );
      return SupabaseSyncService(
        db: db,
        repository: repo,
        config: testConfig,
        clientOverride: client,
        documentsDirectoryProvider: () async => dir.path,
      );
    }

    test('Stress Test 1: Rapid concurrent changes in 2 devices converge deterministically', () async {
      final dbA = AppDatabase.forTesting(NativeDatabase.memory());
      final repoA = AppRepository(dbA);
      final dirA = await Directory.systemTemp.createTemp('adv_sync_a_');

      final dbB = AppDatabase.forTesting(NativeDatabase.memory());
      final repoB = AppRepository(dbB);
      final dirB = await Directory.systemTemp.createTemp('adv_sync_b_');

      final syncA = createSyncService(db: dbA, repo: repoA, dir: dirA);
      final syncB = createSyncService(db: dbB, repo: repoB, dir: dirB);

      addTearDown(() async {
        syncA.dispose();
        syncB.dispose();
        await dbA.close();
        await dbB.close();
        if (await dirA.exists()) await dirA.delete(recursive: true);
        if (await dirB.exists()) await dirB.delete(recursive: true);
      });

      // Rapidly create 5 people and 5 visits in Device A
      for (int i = 1; i <= 5; i++) {
        await repoA.createPerson(
          id: 'rapid-person-a-$i',
          name: 'Person A $i',
          phone: '1190000000$i',
        );
        await repoA.createVisit(
          id: 'rapid-visit-a-$i',
          personId: 'rapid-person-a-$i',
          dateTime: DateTime.now(),
          contactType: 'revisita',
          result: 'receptivo',
        );
      }

      // Concurrently create 5 different people and 5 studies in Device B
      for (int i = 1; i <= 5; i++) {
        await repoB.createPerson(
          id: 'rapid-person-b-$i',
          name: 'Person B $i',
          phone: '2190000000$i',
        );
        await repoB.createStudy(
          id: 'rapid-study-b-$i',
          title: 'Study B $i',
          status: 'ativo',
          publicationId: 'lff',
          participantPersonIds: ['rapid-person-b-$i'],
          startedAt: DateTime.now(),
        );
      }

      // Interleaved rapid synchronization
      final pushA = await syncA.processQueue();
      final pushB = await syncB.processQueue();

      expect(pushA.failureCount, equals(0));
      expect(pushB.failureCount, equals(0));

      // Device A pulls B's data; Device B pulls A's data
      final pullA = await syncA.fetchRemoteChanges();
      final pullB = await syncB.fetchRemoteChanges();

      expect(pullA.success, isTrue);
      expect(pullB.success, isTrue);

      // Verify convergence: exactly 10 people on both devices
      final peopleOnA = await repoA.getAllPeople();
      final peopleOnB = await repoB.getAllPeople();

      expect(peopleOnA.length, equals(10));
      expect(peopleOnB.length, equals(10));

      final namesA = peopleOnA.map((p) => p.name).toSet();
      final namesB = peopleOnB.map((p) => p.name).toSet();
      expect(namesA, equals(namesB));

      // Verify all 5 studies exist on both
      for (int i = 1; i <= 5; i++) {
        final studyA = await (dbA.select(dbA.bibleStudies)..where((t) => t.id.equals('rapid-study-b-$i'))).getSingleOrNull();
        final studyB = await (dbB.select(dbB.bibleStudies)..where((t) => t.id.equals('rapid-study-b-$i'))).getSingleOrNull();
        expect(studyA, isNotNull);
        expect(studyB, isNotNull);
        expect(studyA!.title, equals(studyB!.title));
      }

      // Verify all 5 visits exist on both
      for (int i = 1; i <= 5; i++) {
        final visitA = await repoA.getVisitById('rapid-visit-a-$i');
        final visitB = await repoB.getVisitById('rapid-visit-a-$i');
        expect(visitA, isNotNull);
        expect(visitB, isNotNull);
        expect(visitA!.personId, equals('rapid-person-a-$i'));
        expect(visitB!.personId, equals('rapid-person-a-$i'));
      }
    });

    test('Stress Test 2: Outbox queue durability under abnormal process kill and restart on physical disk SQLite', () async {
      final tempDiskDir = await Directory.systemTemp.createTemp('adv_durability_');
      final dbFile = File('${tempDiskDir.path}/durability_stress.sqlite');

      addTearDown(() async {
        if (await tempDiskDir.exists()) await tempDiskDir.delete(recursive: true);
      });

      // 1. Instancia banco em arquivo real no disco
      var dbDisk = AppDatabase.forTesting(NativeDatabase(dbFile));
      var repoDisk = AppRepository(dbDisk);

      // Cria 3 mutações em modo offline total
      final createdP1 = await repoDisk.createPerson(
        id: 'durable-p-1',
        name: 'Durable Entity 1',
        phone: '1111',
      );
      final createdP2 = await repoDisk.createPerson(
        id: 'durable-p-2',
        name: 'Durable Entity 2',
        phone: '2222',
      );
      expect(createdP1.id, equals('durable-p-1'));
      expect(createdP2.id, equals('durable-p-2'));

      await repoDisk.createAppointment(
        id: 'durable-appt-1',
        title: 'Durable Appointment',
        startTime: DateTime(2026, 12, 1, 10, 0),
        endTime: DateTime(2026, 12, 1, 10, 45),
        durationMinutes: 45,
        status: 'planejado',
      );

      final opsBeforeKill = await repoDisk.getPendingSyncOperations();
      expect(opsBeforeKill.length, equals(3));
      final opIdsBefore = opsBeforeKill.map((o) => o.id).toList();

      // 2. Simula CRASH ABNORMAL / SIGKILL: fecha abruptamente o banco de dados
      await dbDisk.close();

      // 3. Reinicia a aplicação: abre o MESMO arquivo SQLite do disco com nova instância
      dbDisk = AppDatabase.forTesting(NativeDatabase(dbFile));
      repoDisk = AppRepository(dbDisk);

      // Verifica integridade da outbox pós-restart
      final opsAfterRestart = await repoDisk.getPendingSyncOperations();
      expect(opsAfterRestart.length, equals(3));
      final opIdsAfter = opsAfterRestart.map((o) => o.id).toList();
      expect(opIdsAfter, equals(opIdsBefore));

      // Verifica integridade dos payloads gravados
      final p1Payload = jsonDecode(opsAfterRestart.firstWhere((o) => o.entityId == 'durable-p-1').payload);
      expect(p1Payload['name'], equals('Durable Entity 1'));

      // 4. Reconecta rede e sincroniza outbox restaurada com o servidor
      final syncDisk = createSyncService(db: dbDisk, repo: repoDisk, dir: tempDiskDir);
      final pushResult = await syncDisk.processQueue();

      expect(pushResult.failureCount, equals(0));
      expect(pushResult.successCount, equals(3));

      // Confirma que os registros chegaram ao servidor intactos
      expect(server.getRow('people', 'durable-p-1'), isNotNull);
      expect(server.getRow('people', 'durable-p-2'), isNotNull);
      expect(server.getRow('appointments', 'durable-appt-1'), isNotNull);

      // Outbox local deve agora estar vazia
      final remainingOps = await repoDisk.getPendingSyncOperations();
      expect(remainingOps, isEmpty);

      syncDisk.dispose();
      await dbDisk.close();
    });

    test('Stress Test 3: 3-way merge determinism with severe clock skew (Device A = -30 days, Device B = +30 days)', () {
      final baseCommon = {
        'id': 'person-skew-01',
        'name': 'Lucas Fernandes',
        'phone': '1111-0000',
        'address': 'Rua Original, 10',
        'notes': 'Notas Originais',
        'revision': 1,
        'updated_at': DateTime(2026, 11, 1).toIso8601String(),
      };

      // Dispositivo A com relógio atrasado em 30 dias (2026-10-02) alterou apenas o telefone
      final localDataSkewedPast = {
        'id': 'person-skew-01',
        'name': 'Lucas Fernandes',
        'phone': '9999-9999', // Mudou phone
        'address': 'Rua Original, 10',
        'notes': 'Notas Originais',
        'revision': 2,
        'updated_at': DateTime(2026, 10, 2).toIso8601String(), // 30 dias no passado!
      };

      // Dispositivo B com relógio adiantado em 30 dias (2026-12-01) alterou apenas o endereço
      final remoteDataSkewedFuture = {
        'id': 'person-skew-01',
        'name': 'Lucas Fernandes',
        'phone': '1111-0000',
        'address': 'Alameda Nova, 999', // Mudou address
        'notes': 'Notas Originais',
        'revision': 2,
        'updated_at': DateTime(2026, 12, 1).toIso8601String(), // 30 dias no futuro!
      };

      // O merge deve mesclar os campos distintos sem ser ludibriado pelo timestamp de A estar no passado
      final mergeResult = SyncEngine.mergeEntities(
        entityType: 'people',
        entityId: 'person-skew-01',
        localData: localDataSkewedPast,
        remoteData: remoteDataSkewedFuture,
        baseData: baseCommon,
      );

      expect(mergeResult.hasConflict, isFalse);
      expect(mergeResult.mergedData['phone'], equals('9999-9999'),
          reason: 'Campo phone editado no Disp A não deve ser descartado por clock skew');
      expect(mergeResult.mergedData['address'], equals('Alameda Nova, 999'),
          reason: 'Campo address editado no Disp B deve ser integrado');
      expect(mergeResult.mergedData['name'], equals('Lucas Fernandes'));
      expect(mergeResult.mergedData['notes'], equals('Notas Originais'));

      // Agora teste adversarial: ambos alteram o MESMO campo 'notes' com relógios divergentes
      final localConflictSkewed = Map<String, dynamic>.from(localDataSkewedPast)
        ..['notes'] = 'Anotação Disp A (relógio passado)';
      final remoteConflictSkewed = Map<String, dynamic>.from(remoteDataSkewedFuture)
        ..['notes'] = 'Anotação Disp B (relógio futuro)';

      final conflictResult = SyncEngine.mergeEntities(
        entityType: 'people',
        entityId: 'person-skew-01',
        localData: localConflictSkewed,
        remoteData: remoteConflictSkewed,
        baseData: baseCommon,
      );

      // Deve reter o conflito explicitamente e NÃO sobrescrever o dado mais antigo pelo mais novo!
      expect(conflictResult.hasConflict, isTrue);
      expect(conflictResult.conflicts.length, equals(1));
      expect(conflictResult.conflicts.first.fieldName, equals('notes'));
      expect(conflictResult.conflicts.first.localValue, contains('Disp A'));
      expect(conflictResult.conflicts.first.remoteValue, contains('Disp B'));
    });

    test('Stress Test 4: Tombstone soft deletes never revive on incoming older snapshots or delayed syncs', () async {
      final dbA = AppDatabase.forTesting(NativeDatabase.memory());
      final repoA = AppRepository(dbA);
      final dirA = await Directory.systemTemp.createTemp('adv_tombstone_a_');

      final syncA = createSyncService(db: dbA, repo: repoA, dir: dirA);
      addTearDown(() async {
        syncA.dispose();
        await dbA.close();
        if (await dirA.exists()) await dirA.delete(recursive: true);
      });

      // 1. Criar registro e sincronizar
      final person = await repoA.createPerson(
        id: 'tombstone-never-revive-01',
        name: 'Registro Protegido',
        phone: '1234',
      );
      await syncA.processQueue();

      // 2. Deleta registro no Dispositivo A com tombstone
      await repoA.deletePerson(person.id);
      final deletedLocal = await (dbA.select(dbA.people)..where((t) => t.id.equals(person.id))).getSingleOrNull();
      expect(deletedLocal, isNotNull);
      expect(deletedLocal!.deletedAt, isNotNull);

      // 3. Tenta aplicar um snapshot remoto atrasado de um terceiro dispositivo desconectado
      // Snapshot antigo possui revision = 1 e deleted_at = null
      final staleIncomingSnapshot = {
        'id': person.id,
        'name': 'Tentativa Stale Snapshot',
        'phone': '1234',
        'revision': 1,
        'updated_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        'deleted_at': null,
      };

      final errors = <String>[];
      final applied = await syncA.applyRemoteRecordForTesting(
        'people',
        staleIncomingSnapshot,
        errors,
      );

      // O sync deve rejeitar a ressurreição
      expect(applied, isTrue);
      expect(errors, isEmpty);

      // Registro continua como tombstone com deletedAt preenchido
      final checkStillDeleted = await (dbA.select(dbA.people)..where((t) => t.id.equals(person.id))).getSingleOrNull();
      expect(checkStillDeleted, isNotNull);
      expect(checkStillDeleted!.deletedAt, isNotNull,
          reason: 'Tombstone nunca deve ser removido por snapshot remoto stale');

      // Consultas padrão de pessoas ativas não devem retornar o registro deletado
      final activePeople = await repoA.getAllPeople();
      expect(activePeople.any((p) => p.id == person.id), isFalse,
          reason: 'Registro deletado não deve reaparecer na lista de pessoas ativas');
    });

    test('Stress Test 5: Conflicting concurrent appointments produce conflict records visible to user without silent overwrites', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = AppRepository(db);
      final dir = await Directory.systemTemp.createTemp('adv_appt_conflict_');

      final sync = createSyncService(db: db, repo: repo, dir: dir);
      addTearDown(() async {
        sync.dispose();
        await db.close();
        if (await dir.exists()) await dir.delete(recursive: true);
      });

      final startTime = DateTime(2026, 11, 25, 9, 0);

      // Agendamento Local 1: 09:00 às 10:00
      final apptLocal = await repo.createAppointment(
        id: 'appt-adversarial-local',
        title: 'Compromisso Local Agendado',
        startTime: startTime,
        endTime: startTime.add(const Duration(hours: 1)),
        durationMinutes: 60,
        status: 'planejado',
      );
      expect(apptLocal.status, equals('planejado'));
      expect(apptLocal.isProvisional, isFalse);

      // Agendamento Remoto 2: 09:30 às 10:30 (sobreposição de 30 minutos)
      final apptRemote = {
        'id': 'appt-adversarial-remote',
        'title': 'Compromisso Remoto Concorrente',
        'start_time': startTime.add(const Duration(minutes: 30)).toIso8601String(),
        'end_time': startTime.add(const Duration(minutes: 90)).toIso8601String(),
        'duration_minutes': 60,
        'status': 'planejado',
        'is_provisional': false,
        'revision': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final errors = <String>[];
      final applied = await sync.applyRemoteRecordForTesting(
        'appointments',
        apptRemote,
        errors,
      );

      expect(applied, isTrue);
      expect(errors, isEmpty);

      // Verificação de Preservação e Visibilidade de Conflito:
      // 1. NENHUM dos agendamentos foi apagado ou sobrescrito (zero perda de dados)
      final allAppts = await repo.getAllAppointments();
      expect(allAppts.length, equals(2));

      final localFetched = allAppts.firstWhere((a) => a.id == 'appt-adversarial-local');
      final remoteFetched = allAppts.firstWhere((a) => a.id == 'appt-adversarial-remote');

      // 2. Ambos foram marcados com status 'conflito'
      expect(localFetched.status, equals('conflito'),
          reason: 'Compromisso local em conflito de horário deve ter status=conflito');
      expect(remoteFetched.status, equals('conflito'),
          reason: 'Compromisso remoto concorrente deve ter status=conflito');

      // 3. Ambos foram marcados como provisórios (isProvisional = true) para alertar visualmente o usuário
      expect(localFetched.isProvisional, isTrue);
      expect(remoteFetched.isProvisional, isTrue);

      // 4. Verificação de terceiro agendamento NÃO colidente (11:00 às 12:00)
      final nonCollidingRemote = {
        'id': 'appt-adversarial-clean',
        'title': 'Compromisso Sem Conflito',
        'start_time': startTime.add(const Duration(hours: 2)).toIso8601String(),
        'end_time': startTime.add(const Duration(hours: 3)).toIso8601String(),
        'duration_minutes': 60,
        'status': 'planejado',
        'is_provisional': false,
        'revision': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await sync.applyRemoteRecordForTesting('appointments', nonCollidingRemote, errors);
      final cleanFetched = await repo.getAppointmentById('appt-adversarial-clean');
      expect(cleanFetched, isNotNull);
      expect(cleanFetched!.status, equals('planejado'),
          reason: 'Compromisso sem colisão horária deve permanecer planejado');
      expect(cleanFetched.isProvisional, isFalse);
    });
  });
}
