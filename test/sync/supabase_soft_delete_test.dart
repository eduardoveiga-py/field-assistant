import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/contacts/phone_contacts_manager.dart';
import 'package:ministerio_pessoal/core/app_config.dart';
import 'package:ministerio_pessoal/core/supabase_initializer.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:ministerio_pessoal/territory/landmark_manager.dart';
import 'package:ministerio_pessoal/voice_notes/voice_note_models.dart';
import 'package:ministerio_pessoal/voice_notes/voice_notes_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servidor simulado PostgREST com suporte a triggers PostgreSQL de preservação
/// de tombstones e cursor incremental composto (U3.1).
class MockSupabaseServer {
  final Map<String, Map<String, Map<String, dynamic>>> tables = {};
  int physicalDeleteCalls = 0;
  int tombstoneUpdateCalls = 0;
  bool simulateNetworkDropOnPatch = false;

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
    final path = request.url.path;
    final match = RegExp(r'/rest/v1/([a-z_]+)').firstMatch(path);
    if (match == null) {
      return _json(request, []);
    }
    final table = match.group(1)!;
    final tableMap = tables.putIfAbsent(table, () => {});

    // Interceptação de exclusão física:
    if (request.method == 'DELETE') {
      physicalDeleteCalls++;
      final idParam = request.url.queryParameters['id'];
      if (idParam != null && idParam.startsWith('eq.')) {
        final id = idParam.substring(3);
        tableMap.remove(id);
      }
      return _json(request, []);
    }

    // Atualização de tombstone (PATCH):
    if (request.method == 'PATCH') {
      if (simulateNetworkDropOnPatch) {
        return http.Response(
          'Network Timeout / Conexão Perdida',
          504,
          request: request,
        );
      }
      final idParam = request.url.queryParameters['id'];
      final id = (idParam != null && idParam.startsWith('eq.'))
          ? idParam.substring(3)
          : null;
      final body = jsonDecode(request.body) as Map<String, dynamic>;

      if (body.containsKey('deleted_at') && body['deleted_at'] != null) {
        tombstoneUpdateCalls++;
      }

      if (id != null) {
        final existing = tableMap[id] ?? <String, dynamic>{'id': id};
        body.forEach((k, v) {
          existing[k] = v;
        });
        tableMap[id] = existing;
      }
      return _json(request, [body]);
    }

    // Upsert (POST) com simulação do trigger PostgreSQL prevent_stale_resurrection:
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

          if (oldDeletedAt != null) {
            // Registro no servidor já é tombstone
            if (newDeletedAt == null) {
              // Upsert desatualizado tentando ressuscitar registro excluído
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
                // REGRA DO TRIGGER PG: PRESERVA O TOMBSTONE!
                item['deleted_at'] = oldDeletedAt;
                final oldUpdRaw =
                    existing['updated_at'] ?? existing['updatedAt'];
                final oldUpd = oldUpdRaw != null
                    ? DateTime.tryParse(oldUpdRaw.toString())
                    : null;
                if (oldUpd != null &&
                    newUpd != null &&
                    oldUpd.isAfter(newUpd)) {
                  item['updated_at'] = oldUpdRaw;
                }
                item['revision'] = oldRev > newRev ? oldRev : newRev;
              }
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

    // Consulta incremental (GET):
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
        } else if (gteFilter.startsWith('gt.')) {
          final target = DateTime.tryParse(gteFilter.substring(3));
          if (target != null) {
            rows = rows.where((row) {
              final upRaw = row['updated_at'] ?? row['updatedAt'];
              final dt = upRaw != null
                  ? DateTime.tryParse(upRaw.toString())
                  : null;
              if (dt == null) return false;
              return dt.isAfter(target);
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
        final c = dtA.compareTo(dtB);
        if (c != 0) return c;
        return (a['id'] ?? '').toString().compareTo((b['id'] ?? '').toString());
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
  group('U3.1: Integridade de Exclusões, Tombstones e Prevenção de Ressurreição', () {
    late AppDatabase dbA;
    late AppRepository repoA;
    late AppDatabase dbB;
    late AppRepository repoB;
    late MockSupabaseServer server;
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
      tempDirA = await Directory.systemTemp.createTemp('sync_u31_a_');

      dbB = AppDatabase.forTesting(NativeDatabase.memory());
      repoB = AppRepository(dbB);
      tempDirB = await Directory.systemTemp.createTemp('sync_u31_b_');

      server = MockSupabaseServer();
    });

    tearDown(() async {
      await dbA.close();
      await dbB.close();
      if (await tempDirA.exists()) await tempDirA.delete(recursive: true);
      if (await tempDirB.exists()) await tempDirB.delete(recursive: true);
    });

    SupabaseSyncService createServiceA() {
      final mockClient = MockClient((req) async => server.handleRequest(req));
      return SupabaseSyncService(
        db: dbA,
        repository: repoA,
        config: testConfig,
        supabaseUrl: testConfig.supabaseUrl,
        supabaseAnonKey: testConfig.supabaseAnonKey,
        clientOverride: SupabaseClient(
          testConfig.supabaseUrl,
          testConfig.supabaseAnonKey,
          httpClient: mockClient,
        ),
        documentsDirectoryProvider: () async => tempDirA.path,
      );
    }

    SupabaseSyncService createServiceB() {
      final mockClient = MockClient((req) async => server.handleRequest(req));
      return SupabaseSyncService(
        db: dbB,
        repository: repoB,
        config: testConfig,
        supabaseUrl: testConfig.supabaseUrl,
        supabaseAnonKey: testConfig.supabaseAnonKey,
        clientOverride: SupabaseClient(
          testConfig.supabaseUrl,
          testConfig.supabaseAnonKey,
          httpClient: mockClient,
        ),
        documentsDirectoryProvider: () async => tempDirB.path,
      );
    }

    test('Teste A — Exclusão de A propagada para B via Tombstone', () async {
      final syncA = createServiceA();
      final syncB = createServiceB();
      addTearDown(syncA.dispose);
      addTearDown(syncB.dispose);

      // 1. A e B possuem o mesmo registro
      final personA = await repoA.createPerson(name: 'Irmão Carlos');
      await syncA.processQueue(); // A envia ao Supabase

      // B sincroniza e recebe a pessoa
      await syncB.fetchRemoteChanges();
      final peopleB = await repoB.getAllPeople();
      expect(peopleB.length, equals(1));
      expect(peopleB.first.id, equals(personA.id));

      // 2. A exclui o registro
      await repoA.deletePerson(personA.id);
      final activeA = await repoA.getAllPeople();
      expect(activeA.isEmpty, isTrue);

      // 3. A sincroniza (push outbox)
      final pushA = await syncA.processQueue();
      expect(pushA.successCount, equals(1));

      // 4. O Supabase mantém o registro com deleted_at (NÃO executa exclusão física!)
      expect(server.physicalDeleteCalls, equals(0));
      expect(server.tombstoneUpdateCalls, greaterThanOrEqualTo(1));
      final remoteRow = server.getRow('people', personA.id);
      expect(remoteRow, isNotNull);
      expect(remoteRow!['deleted_at'], isNotNull);
      expect(remoteRow['updated_at'], isNotNull);

      // 5. B sincroniza (pull)
      final pullB = await syncB.fetchRemoteChanges();
      expect(pullB.successCount, greaterThanOrEqualTo(1));

      // 6. B reconhece a exclusão e marca o registro local como excluído
      final activeB = await repoB.getAllPeople();
      expect(activeB.isEmpty, isTrue);

      final rawLocalB = await (dbB.select(
        dbB.people,
      )..where((t) => t.id.equals(personA.id))).getSingle();
      final expectedDeletedAt = DateTime.parse(
        remoteRow['deleted_at'].toString(),
      );
      expect(
        rawLocalB.deletedAt!.difference(expectedDeletedAt).inSeconds.abs(),
        lessThanOrEqualTo(1),
      );
    });

    test('Teste B — Upsert antigo não ressuscita registro excluído', () async {
      final syncA = createServiceA();
      final syncB = createServiceB();
      addTearDown(syncA.dispose);
      addTearDown(syncB.dispose);

      // 1. A e B possuem o mesmo registro
      final now = DateTime.now().toUtc();
      final personA = await repoA.createPerson(name: 'Maria Oliveira');
      await syncA.processQueue();
      await syncB.fetchRemoteChanges();

      // 2. B exclui e sincroniza tombstone
      await repoB.deletePerson(personA.id);
      await syncB.processQueue();

      // O servidor armazena o tombstone mais recente
      final remoteBefore = server.getRow('people', personA.id);
      expect(remoteBefore, isNotNull);
      expect(remoteBefore!['deleted_at'], isNotNull);
      final tombstoneTimestamp = remoteBefore['deleted_at'];

      // 3. A permaneceu offline e mantém cópia antiga ativa
      // 4. A tenta enviar um upsert com estado ativo (ex: edição desatualizada na outbox)
      await dbA
          .into(dbA.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: 'q_stale_update',
              entityType: 'people',
              entityId: personA.id,
              operation: 'UPDATE',
              payload: jsonEncode({
                'id': personA.id,
                'name': 'Maria Oliveira (Edição Atrasada)',
                'updatedAt': now.toIso8601String(),
                'revision': 1, // Revisão antiga
              }),
              createdAt: now,
              status: const drift.Value('pending'),
            ),
          );

      // A executa envio do upsert
      await syncA.processQueue();

      // 5. O servidor mantém o tombstone mais recente (não ressuscita!)
      final remoteAfter = server.getRow('people', personA.id);
      expect(remoteAfter, isNotNull);
      expect(remoteAfter!['deleted_at'], equals(tombstoneTimestamp));

      // A executa pull e recebe o tombstone, atualizando seu banco local
      await syncA.fetchRemoteChanges();
      final peopleAAfter = await repoA.getAllPeople();
      expect(peopleAAfter.any((p) => p.id == personA.id), isFalse);

      final personARaw = await (dbA.select(
        dbA.people,
      )..where((t) => t.id.equals(personA.id))).getSingle();
      expect(personARaw.deletedAt, isNotNull);
    });

    test('Teste C — Exclusão repetida e idempotência', () async {
      final syncA = createServiceA();
      addTearDown(syncA.dispose);

      final person = await repoA.createPerson(name: 'João repetido');
      await syncA.processQueue();

      // Executa exclusão
      await repoA.deletePerson(person.id);
      final push1 = await syncA.processQueue();
      expect(push1.successCount, equals(1));

      // Reenvia a mesma exclusão (simula reexecução ou duplicata)
      await dbA
          .into(dbA.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: 'q_dup_delete',
              entityType: 'people',
              entityId: person.id,
              operation: 'DELETE',
              payload: jsonEncode({
                'id': person.id,
                'deletedAt': DateTime.now().toUtc().toIso8601String(),
                'updatedAt': DateTime.now().toUtc().toIso8601String(),
                'revision': 2,
              }),
              createdAt: DateTime.now(),
              status: const drift.Value('pending'),
            ),
          );

      final push2 = await syncA.processQueue();
      expect(push2.successCount, equals(1));
      expect(push2.failureCount, equals(0));

      final remoteRow = server.getRow('people', person.id);
      expect(remoteRow, isNotNull);
      expect(remoteRow!['deleted_at'], isNotNull);
      expect(server.physicalDeleteCalls, equals(0));
    });

    test(
      'Teste D — Falha após aplicação remota e recuperação da outbox',
      () async {
        final syncA = createServiceA();
        addTearDown(syncA.dispose);

        final person = await repoA.createPerson(name: 'Falha Teste');
        await syncA.processQueue();

        await repoA.deletePerson(person.id);

        // Simula queda de conexão do cliente imediatamente na chamada de PATCH
        server.simulateNetworkDropOnPatch = true;

        final pushFail = await syncA.processQueue();
        expect(pushFail.failureCount, equals(1));

        // Operação permaneceu pendente na outbox local
        final pendingOps = await repoA.getPendingSyncOperations();
        expect(pendingOps.length, equals(1));
        expect(pendingOps.first.entityId, equals(person.id));

        // Conexão restabelecida: retenta com sucesso
        server.simulateNetworkDropOnPatch = false;
        SupabaseInitializer.setMockStateForTesting(
          state: SupabaseConnectionState.connected,
          config: testConfig,
        );
        final pushRetry = await syncA.processQueue(ignoreBackoff: true);
        expect(pushRetry.successCount, equals(1));

        // Agora a fila está vazia e o tombstone está preservado no servidor
        final pendingAfter = await repoA.getPendingSyncOperations();
        expect(pendingAfter.isEmpty, isTrue);

        final remoteRow = server.getRow('people', person.id);
        expect(remoteRow!['deleted_at'], isNotNull);
      },
    );

    test(
      'Teste E — Cursor incremental: nenhum tombstone relevante é ignorado',
      () async {
        final syncB = createServiceB();
        addTearDown(syncB.dispose);

        final tCursor = DateTime.utc(2026, 11, 2, 12, 0, 0);

        // Define o cursor inicial
        await dbB
            .into(dbB.appKvStore)
            .insert(
              AppKvStoreCompanion.insert(
                key: 'last_synced_at_people',
                value: tCursor.toIso8601String(),
                updatedAt: drift.Value(DateTime.now()),
              ),
            );
        await dbB
            .into(dbB.appKvStore)
            .insert(
              AppKvStoreCompanion.insert(
                key: 'last_synced_id_people',
                value: 'p_cursor_bound',
                updatedAt: drift.Value(DateTime.now()),
              ),
            );

        // Semeia registros no servidor:
        // 1. updated_at anterior ao cursor -> deve ser ignorado
        server.seed('people', {
          'id': 'p_old',
          'name': 'Pessoa Antiga',
          'updated_at': tCursor
              .subtract(const Duration(minutes: 10))
              .toIso8601String(),
          'created_at': tCursor
              .subtract(const Duration(minutes: 10))
              .toIso8601String(),
        });

        // 2. updated_at igual ao cursor com id anterior/igual ao cursor -> já sincronizado
        server.seed('people', {
          'id': 'p_cursor_bound',
          'name': 'Pessoa do Cursor',
          'updated_at': tCursor.toIso8601String(),
          'created_at': tCursor.toIso8601String(),
        });

        // 3. tombstone com timestamp igual ao cursor mas id superior -> NÃO PODE SER IGNORADO
        server.seed('people', {
          'id': 'p_tomb_equal_cursor',
          'name': 'Tombstone Igual Cursor',
          'updated_at': tCursor.toIso8601String(),
          'deleted_at': tCursor.toIso8601String(),
          'created_at': tCursor
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
        });

        // 4. tombstone com timestamp posterior ao cursor -> DEVE SER PROCESSADO
        server.seed('people', {
          'id': 'p_tomb_newer',
          'name': 'Tombstone Posterior',
          'updated_at': tCursor
              .add(const Duration(minutes: 5))
              .toIso8601String(),
          'deleted_at': tCursor
              .add(const Duration(minutes: 5))
              .toIso8601String(),
          'created_at': tCursor.toIso8601String(),
        });

        // 5. registro ativo posterior ao cursor -> DEVE SER PROCESSADO
        server.seed('people', {
          'id': 'p_active_newer',
          'name': 'Ativo Posterior',
          'updated_at': tCursor
              .add(const Duration(minutes: 6))
              .toIso8601String(),
          'created_at': tCursor.toIso8601String(),
        });

        final pull = await syncB.fetchRemoteChanges();
        expect(pull.successCount, equals(3)); // 3 registros novos/tombstones

        // Verifica se o tombstone com timestamp igual ao cursor foi recebido
        final tombEqual = await (dbB.select(
          dbB.people,
        )..where((t) => t.id.equals('p_tomb_equal_cursor'))).getSingleOrNull();
        expect(tombEqual, isNotNull);
        expect(tombEqual!.deletedAt, isNotNull);

        // Verifica se o tombstone posterior foi recebido
        final tombNewer = await (dbB.select(
          dbB.people,
        )..where((t) => t.id.equals('p_tomb_newer'))).getSingleOrNull();
        expect(tombNewer, isNotNull);
        expect(tombNewer!.deletedAt, isNotNull);

        // Verifica se o registro antigo não foi baixado
        final oldRow = await (dbB.select(
          dbB.people,
        )..where((t) => t.id.equals('p_old'))).getSingleOrNull();
        expect(oldRow, isNull);
      },
    );

    test('Teste F — Sincronização sem loop ao receber tombstone', () async {
      final syncB = createServiceB();
      addTearDown(syncB.dispose);

      final now = DateTime.now().toUtc();
      server.seed('people', {
        'id': 'p_no_loop',
        'name': 'Sem Loop',
        'updated_at': now.toIso8601String(),
        'deleted_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      });

      final pull = await syncB.fetchRemoteChanges();
      expect(pull.successCount, equals(1));

      // CRÍTICO: nenhuma nova operação deve ser criada na outbox do dispositivo B!
      final pendingOpsB = await repoB.getPendingSyncOperations();
      expect(pendingOpsB.isEmpty, isTrue);

      // Executa push em B para confirmar que nada é enviado em resposta
      final pushB = await syncB.processQueue();
      expect(pushB.totalProcessed, equals(0));
    });

    test('Teste G — Validação de Soft Delete em todas as 10 tabelas sincronizadas', () async {
      final syncA = createServiceA();
      final syncB = createServiceB();
      addTearDown(syncA.dispose);
      addTearDown(syncB.dispose);

      final now = DateTime.now().toUtc();

      // Prepara registros para todas as 10 tabelas:
      // 1. people
      final person = await repoA.createPerson(name: 'Pessoa G');
      // 2. visits
      final visit = await repoA.createVisit(
        personId: person.id,
        dateTime: now,
        contactType: 'revisita',
        result: 'contato',
      );
      // 3. bible_studies
      final study = await repoA.createStudy(
        title: 'Estudo G',
        publicationId: 'lff-book',
        participantPersonIds: [person.id],
      );
      // 4. study_participants (criado automaticamente pelo createStudy)
      final participants = await repoA.getParticipantsForStudy(study.id);
      final participantId = participants.first.id;
      // 5. study_sessions
      final session = await repoA.createStudySession(
        studyId: study.id,
        dateTime: now,
        publicationCode: 'lff',
        lessonCovered: 1,
      );
      // 6. appointments
      final appt = await repoA.createAppointment(
        title: 'Compromisso G',
        startTime: now,
        endTime: now.add(const Duration(minutes: 30)),
        personId: person.id,
      );
      // 7. activity_records
      final activity = await repoA.createActivityRecord(
        date: now,
        durationSeconds: 3600,
        modality: 'campo',
      );
      // 8. voice_notes
      final vnManagerA = VoiceNotesManager(dbA);
      final vnItem = VoiceNoteItem(
        id: 'vn-g-1',
        personId: person.id,
        transcription: 'Nota de voz G',
        audioDurationSeconds: 10,
        createdAt: now,
        updatedAt: now,
      );
      await vnManagerA.saveVoiceNote(vnItem);
      // 9. phone_contacts
      final phoneManagerA = PhoneContactsManager(dbA);
      final phoneContact = await phoneManagerA.addPhoneContact(
        name: 'Contato Telefônico G',
        phone: '11988887777',
      );
      // 10. territory_landmarks
      final landmarkManagerA = LandmarkManager(dbA);
      final landmark = await landmarkManagerA.addLandmark(
        name: 'Landmark G',
        category: 'comercio',
      );

      // Sincroniza criação no Supabase
      await syncA.processQueue();
      await syncB.fetchRemoteChanges();

      // Executa exclusão local em todas as entidades:
      final delTime = DateTime.now().toUtc();
      final delTimeIso = delTime.toIso8601String();
      await repoA.deletePerson(person.id);
      await repoA.deleteVisit(visit.id);
      await repoA.deleteStudy(study.id);
      await (dbA.update(
        dbA.studyParticipants,
      )..where((t) => t.id.equals(participantId))).write(
        StudyParticipantsCompanion(
          deletedAt: drift.Value(delTime),
          updatedAt: drift.Value(delTime),
        ),
      );
      await dbA
          .into(dbA.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: 'q_del_part',
              entityType: 'study_participants',
              entityId: participantId,
              operation: 'DELETE',
              payload: jsonEncode({
                'id': participantId,
                'studyId': study.id,
                'personId': person.id,
                'deletedAt': delTimeIso,
                'updatedAt': delTimeIso,
                'revision': 2,
              }),
              createdAt: delTime,
              status: const drift.Value('pending'),
            ),
          );
      await (dbA.update(
        dbA.studySessions,
      )..where((t) => t.id.equals(session.id))).write(
        StudySessionsCompanion(
          deletedAt: drift.Value(delTime),
          updatedAt: drift.Value(delTime),
        ),
      );
      await dbA
          .into(dbA.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: 'q_del_sess',
              entityType: 'study_sessions',
              entityId: session.id,
              operation: 'DELETE',
              payload: jsonEncode({
                'id': session.id,
                'studyId': session.studyId,
                'deletedAt': delTimeIso,
                'updatedAt': delTimeIso,
                'revision': session.revision + 1,
              }),
              createdAt: delTime,
              status: const drift.Value('pending'),
            ),
          );
      await repoA.deleteAppointment(appt.id);
      await repoA.deleteActivityRecord(activity.id);
      await vnManagerA.deleteVoiceNote(vnItem.id);
      await phoneManagerA.deletePhoneContact(phoneContact.id);
      await landmarkManagerA.deleteLandmark(landmark.id);

      // A envia exclusões (todas devem ser soft-delete update, NENHUMA física!)
      final pushA = await syncA.processQueue();
      expect(pushA.failureCount, equals(0));
      expect(pushA.successCount, equals(10));
      expect(server.physicalDeleteCalls, equals(0));

      // B puxa alterações remotas
      final pullB = await syncB.fetchRemoteChanges();
      expect(pullB.failureCount, equals(0));
      expect(pullB.successCount, greaterThanOrEqualTo(10));

      // Valida que todas as 10 entidades em B foram marcadas como soft-deleted:
      final pB = await (dbB.select(
        dbB.people,
      )..where((t) => t.id.equals(person.id))).getSingle();
      expect(pB.deletedAt, isNotNull);

      final vB = await (dbB.select(
        dbB.visits,
      )..where((t) => t.id.equals(visit.id))).getSingle();
      expect(vB.deletedAt, isNotNull);

      final sB = await (dbB.select(
        dbB.bibleStudies,
      )..where((t) => t.id.equals(study.id))).getSingle();
      expect(sB.deletedAt, isNotNull);

      final spB = await (dbB.select(
        dbB.studyParticipants,
      )..where((t) => t.id.equals(participantId))).getSingle();
      expect(spB.deletedAt, isNotNull);

      final ssB = await (dbB.select(
        dbB.studySessions,
      )..where((t) => t.id.equals(session.id))).getSingle();
      expect(ssB.deletedAt, isNotNull);

      final aB = await (dbB.select(
        dbB.appointments,
      )..where((t) => t.id.equals(appt.id))).getSingle();
      expect(aB.deletedAt, isNotNull);

      final actB = await (dbB.select(
        dbB.activityRecords,
      )..where((t) => t.id.equals(activity.id))).getSingle();
      expect(actB.deletedAt, isNotNull);

      final vnB = await (dbB.select(
        dbB.voiceNotes,
      )..where((t) => t.id.equals(vnItem.id))).getSingle();
      expect(vnB.deletedAt, isNotNull);

      final pcB = await (dbB.select(
        dbB.phoneContacts,
      )..where((t) => t.id.equals(phoneContact.id))).getSingle();
      expect(pcB.deletedAt, isNotNull);

      final tlB = await (dbB.select(
        dbB.territoryLandmarks,
      )..where((t) => t.id.equals(landmark.id))).getSingle();
      expect(tlB.deletedAt, isNotNull);
    });
  });
}
