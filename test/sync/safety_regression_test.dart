import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

http.Response jsonResponse(http.Request request, Object value, {int status = 200}) =>
    http.Response(jsonEncode(value), status, request: request,
        headers: {'content-type': 'application/json', 'content-range': '*/0'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late AppRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = AppRepository(db);
  });
  tearDown(() async => db.close());

  SupabaseSyncService service(MockClient mock) {
    final result = SupabaseSyncService(
      db: db,
      repository: repo,
      clientOverride: SupabaseClient('https://mock.supabase.co', 'dummy-key', httpClient: mock),
    );
    addTearDown(result.dispose);
    return result;
  }

  test('erro da RPC não faz upsert sem trava nem marca sucesso', () async {
    await repo.createPerson(name: 'Teste');
    var directWrites = 0;
    final sync = service(MockClient((request) async {
      if (request.url.path.endsWith('/rpc/sync_upsert_if_unchanged')) {
        return jsonResponse(request, {'message': 'unavailable', 'code': 'PGRST202'}, status: 404);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/people')) directWrites++;
      return jsonResponse(request, []);
    }));
    final result = await sync.processQueue();
    expect(result.failureCount, 1);
    expect(directWrites, 0);
    final op = (await db.select(db.syncQueue).get()).single;
    expect(op.status, 'pending');
    expect(op.attempts, 1);
  });

  test('resposta inesperada da RPC mantém operação para nova tentativa', () async {
    await repo.createPerson(name: 'Teste');
    var directWrites = 0;
    final sync = service(MockClient((request) async {
      if (request.url.path.endsWith('/rpc/sync_upsert_if_unchanged')) return jsonResponse(request, {});
      if (request.method == 'POST' && request.url.path.endsWith('/people')) directWrites++;
      return jsonResponse(request, []);
    }));
    final result = await sync.processQueue();
    expect(result.failureCount, 1);
    expect(directWrites, 0);
    expect((await db.select(db.syncQueue).get()).single.status, 'pending');
  });

  test('insert e alterações sucessivas são consolidadas e enviam estado final', () async {
    final person = await repo.createPerson(name: 'Primeiro');
    await repo.updatePerson(person.copyWith(name: 'Último'));
    Map<String, dynamic>? sent;
    final sync = service(MockClient((request) async {
      if (request.url.path.endsWith('/rpc/sync_upsert_if_unchanged')) {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return jsonResponse(request, {'success': true});
      }
      return jsonResponse(request, []);
    }));
    final result = await sync.processQueue();
    expect(result.failureCount, 0);
    expect(result.successCount, 1);
    expect((sent!['p_payload'] as Map)['name'], 'Último');
    expect((await db.select(db.syncQueue).get()).single.status, 'synced');
    expect((await repo.getPersonById(person.id))!.name, 'Último');
  });

  test('RPC recebe a linha exata lida para comparação atômica', () async {
    final person = await repo.createPerson(name: 'Linha existente');
    final remote = SupabaseSyncService.toRemotePayload('people', person.toJson());
    remote['owner_id'] = '00000000-0000-4000-8000-000000000001';
    Map<String, dynamic>? sent;
    final sync = service(MockClient((request) async {
      if (request.url.path.endsWith('/rpc/sync_upsert_if_unchanged')) {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return jsonResponse(request, {'success': true});
      }
      if (request.url.path.endsWith('/people')) return jsonResponse(request, [remote]);
      return jsonResponse(request, []);
    }));
    final result = await sync.processQueue();
    expect(result.failureCount, 0);
    expect(sent?['p_expected_record'], remote);
  });

  test('updates sucessivos mantêm a base mais antiga para detectar conflitos', () async {
    final initial = await repo.createPerson(name: 'Base');
    await db.delete(db.syncQueue).go();
    await repo.updatePerson(initial.copyWith(name: 'Primeira edição'));
    final once = (await repo.getPersonById(initial.id))!;
    await repo.updatePerson(once.copyWith(name: 'Última edição'));
    final sync = service(MockClient((request) async {
      if (request.url.path.endsWith('/rpc/sync_upsert_if_unchanged')) {
        return jsonResponse(request, {'message': 'erro', 'code': 'PGRST202'}, status: 404);
      }
      return jsonResponse(request, []);
    }));
    await sync.processQueue();
    final combined = (await db.select(db.syncQueue).get()).single;
    final payload = jsonDecode(combined.payload) as Map<String, dynamic>;
    expect(payload['name'], 'Última edição');
    expect((payload['_base'] as Map)['name'], 'Base');
    expect(combined.status, 'pending');
  });

  test('múltiplas operações com tentativa anterior não são compactadas', () async {
    final person = await repo.createPerson(name: 'Primeiro');
    await repo.updatePerson(person.copyWith(name: 'Último'));
    final ops = await db.select(db.syncQueue).get();
    await (db.update(db.syncQueue)..where((t) => t.id.equals(ops.first.id)))
        .write(const SyncQueueCompanion(attempts: drift.Value(1)));
    var writes = 0;
    final sync = service(MockClient((request) async {
      if (request.method == 'POST') writes++;
      return jsonResponse(request, []);
    }));
    final result = await sync.processQueue();
    expect(result.failureCount, greaterThan(0));
    expect(writes, 0);
    expect((await db.select(db.syncQueue).get()).length, 2);
  });

  test('pull preserva mutações múltiplas e não avança cursor', () async {
    final person = await repo.createPerson(name: 'Local inicial');
    await repo.updatePerson(person.copyWith(name: 'Local final'));
    final ops = await db.select(db.syncQueue).get();
    await (db.update(db.syncQueue)..where((t) => t.id.equals(ops.first.id)))
        .write(const SyncQueueCompanion(attempts: drift.Value(1)));
    final sync = service(MockClient((request) async {
      if (request.url.path.endsWith('/people')) {
        return jsonResponse(request, [{
          'id': person.id, 'name': 'Remoto',
          'updated_at': '2026-02-01T00:00:00Z',
        }]);
      }
      return jsonResponse(request, []);
    }));
    final result = await sync.fetchRemoteChanges();
    expect(result.failureCount, greaterThan(0));
    expect((await repo.getPersonById(person.id))!.name, 'Local final');
    expect((await db.select(db.syncQueue).get()).map((e) => e.status), everyElement('pending'));
    final cursor = await (db.select(db.appKvStore)
      ..where((t) => t.key.equals('last_synced_at_people'))).getSingleOrNull();
    expect(cursor, isNull);
  });

  test('pendência de outra tabela com o mesmo ID não bloqueia pull', () async {
    final now = DateTime.now();
    await db.into(db.syncQueue).insert(SyncQueueCompanion.insert(
      id: 'op', entityType: 'tasks', entityId: 'shared', operation: 'UPDATE',
      payload: '{}', createdAt: now));
    final sync = service(MockClient((request) async {
      if (request.url.path.endsWith('/people')) {
        return jsonResponse(request, [{
          'id': 'shared', 'name': 'Pessoa', 'updated_at': '2026-02-01T00:00:00Z',
        }]);
      }
      return jsonResponse(request, []);
    }));
    final result = await sync.fetchRemoteChanges();
    expect(result.failureCount, 0);
    expect((await repo.getPersonById('shared'))?.name, 'Pessoa');
  });

  test('pull não avança cursor se registro anterior falhou e sync não envia fila', () async {
    await repo.createPerson(name: 'Pendente');
    var writes = 0;
    final sync = service(MockClient((request) async {
      if (request.method == 'POST') writes++;
      if (request.url.path.endsWith('/people')) {
        return jsonResponse(request, [
          {'id': 'invalid', 'updated_at': 'invalid'},
          {'id': 'remote', 'name': 'Remoto', 'updated_at': '2026-01-02T00:00:00Z'},
        ]);
      }
      return jsonResponse(request, []);
    }));
    await db.into(db.appKvStore).insert(AppKvStoreCompanion.insert(
      key: 'last_synced_at_people', value: '2026-01-01T00:00:00.000Z',
    ));
    final result = await sync.sync();
    expect(result.failureCount, greaterThan(0));
    expect(writes, 0);
    final row = await (db.select(db.appKvStore)
      ..where((t) => t.key.equals('last_synced_at_people'))).getSingle();
    expect(row.value, '2026-01-01T00:00:00.000Z');
  });

  test('cursor é inclusivo e pagina por timestamp e ID', () async {
    final seenQueries = <Map<String, String>>[];
    final sync = service(MockClient((request) async {
      if (request.url.path.endsWith('/people')) {
        seenQueries.add(request.url.queryParameters);
        final start = request.url.queryParameters.containsKey('or') ? 100 : 0;
        return jsonResponse(request, List.generate(start == 0 ? 100 : 1, (i) => {
          'id': 'p${(start + i).toString().padLeft(3, '0')}',
          'name': 'Teste', 'updated_at': '2026-01-01T00:00:00.000Z',
        }));
      }
      return jsonResponse(request, []);
    }));
    await db.into(db.appKvStore).insert(AppKvStoreCompanion.insert(
      key: 'last_synced_at_people', value: '2026-01-01T00:00:00.000Z',
      updatedAt: drift.Value(DateTime.now()),
    ));
    final result = await sync.fetchRemoteChanges();
    expect(result.failureCount, 0);
    expect((await db.select(db.people).get()).length, 101);
    expect(seenQueries.first['updated_at'], startsWith('gte.'));
    expect(seenQueries[1]['or'], contains('id.gt.p099'));
  });
}
