import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:ministerio_pessoal/sync/sync_engine.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

http.Response _mockJson(
  http.Request request,
  Object body, {
  int statusCode = 200,
  String contentRange = '*/0',
}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    request: request,
    headers: {
      'content-type': 'application/json',
      'content-range': contentRange,
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('C2/M5 Push Revision Guard & A3 PersonPhotos Storage Sync', () {
    late AppDatabase db;
    late AppRepository repo;
    late Directory tempDir;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
      tempDir = await Directory.systemTemp.createTemp('push_guard_test_');
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'C2 Camada 1: Pré-verificação detecta revisão remota maior com divergência incompatível e evita overwrite',
      () async {
        final now = DateTime.now().toUtc();
        final person = await repo.createPerson(
          name: 'Ana Original',
          generalNotes: 'Nota base',
        );
        // Altera localmente (rev 2)
        await repo.updatePerson(
          person.copyWith(
            name: 'Ana Editada Localmente',
          ),
        );
        // Mantém somente o UPDATE mais recente na fila para isolar a asserção
        await (db.delete(db.syncQueue)..where((t) => t.operation.equals('INSERT'))).go();

        var rpcOrUpsertCalled = false;
        final mockClient = MockClient((request) async {
          final path = request.url.path;
          if (request.method == 'GET' && path.contains('/rest/v1/people')) {
            return _mockJson(
              request,
              [
                {
                  'id': person.id,
                  'name': 'Ana Editada Remotamente',
                  'status': person.status,
                  'notes': 'Nota base',
                  'tags': '[]',
                  'first_contact_at': person.firstContactAt.toUtc().toIso8601String(),
                  'created_at': person.createdAt.toUtc().toIso8601String(),
                  'updated_at': now.add(const Duration(minutes: 10)).toUtc().toIso8601String(),
                  'revision': 5,
                },
              ],
              contentRange: '0-0/1',
            );
          }
          if (path.contains('/rpc/sync_upsert_if_unchanged') ||
              (request.method == 'POST' && path.contains('/rest/v1/people'))) {
            rpcOrUpsertCalled = true;
            return _mockJson(request, {'success': true});
          }
          return _mockJson(request, []);
        });

        final syncSvc = SupabaseSyncService(
          db: db,
          repository: repo,
          clientOverride: SupabaseClient(
            'https://mock.supabase.co',
            'dummy-key',
            httpClient: mockClient,
          ),
          documentsDirectoryProvider: () async => tempDir.path,
        );
        addTearDown(syncSvc.dispose);

        final res = await syncSvc.processQueue();
        expect(rpcOrUpsertCalled, isFalse,
            reason: 'Não pode sobrescrever registro remoto em conflito');
        expect(res.conflictCount, equals(1));
        expect(syncSvc.currentStatus, equals(SyncStatus.conflict));

        final op = (await db.select(db.syncQueue).get()).single;
        expect(op.status, equals('conflict'));
        final payload = jsonDecode(op.payload) as Map<String, dynamic>;
        expect(payload['_remote'], isA<Map>());
        expect(payload['_conflicts'], isA<List>());
      },
    );

    test(
      'C2 Camada 2: RPC sync_upsert retornando conflict=true (ex: 23505) marca operação como conflict com server_record',
      () async {
        final now = DateTime.now().toUtc();
        final person = await repo.createPerson(name: 'Carlos RPC Conflito');

        final mockClient = MockClient((request) async {
          final path = request.url.path;
          if (request.method == 'GET' && path.contains('/rest/v1/people')) {
            return _mockJson(request, []);
          }
          if (request.method == 'POST' && path.endsWith('/rest/v1/rpc/sync_upsert_if_unchanged')) {
            return _mockJson(request, {
              'conflict': true,
              'code': '23505',
              'message': 'Revision mismatch on server',
              'server_record': {
                'id': person.id,
                'name': 'Carlos Servidor Mais Novo',
                'status': 'estudo',
                'tags': '[]',
                'first_contact_at': now.toUtc().toIso8601String(),
                'created_at': now.toUtc().toIso8601String(),
                'updated_at': now.add(const Duration(minutes: 5)).toUtc().toIso8601String(),
                'revision': 9,
              },
            });
          }
          return _mockJson(request, []);
        });

        final syncSvc = SupabaseSyncService(
          db: db,
          repository: repo,
          clientOverride: SupabaseClient(
            'https://mock.supabase.co',
            'dummy-key',
            httpClient: mockClient,
          ),
          documentsDirectoryProvider: () async => tempDir.path,
        );
        addTearDown(syncSvc.dispose);

        final res = await syncSvc.processQueue();
        expect(res.conflictCount, equals(1));
        expect(res.successCount, equals(0));
        expect(syncSvc.currentStatus, equals(SyncStatus.conflict));

        final op = (await db.select(db.syncQueue).get()).single;
        expect(op.status, equals('conflict'));
        final decoded = jsonDecode(op.payload) as Map<String, dynamic>;
        expect((decoded['_remote'] as Map)['revision'], equals(9));
      },
    );

    test(
      'M5: DELETE bloqueia soft-delete remoto se servidor tiver revisão superior (conflict) e aplica quando revisão é compatível',
      () async {
        final now = DateTime.now().toUtc();
        final pBlocked = await repo.createPerson(name: 'Excluir Bloqueado');
        final pAllowed = await repo.createPerson(name: 'Excluir Permitido');

        // Remove INSERTs da fila e deixa apenas DELETEs
        await db.delete(db.syncQueue).go();
        await repo.deletePerson(pBlocked.id);
        await repo.deletePerson(pAllowed.id);

        var patchedBlocked = false;
        var patchedAllowed = false;

        final mockClient = MockClient((request) async {
          final path = request.url.path;
          final query = request.url.query;
          if (request.method == 'GET' && path.contains('/rest/v1/people')) {
            if (query.contains(pBlocked.id)) {
              return _mockJson(
                request,
                [
                  {
                    'id': pBlocked.id,
                    'name': 'Editado no Outro Dispositivo',
                    'status': 'estudo',
                    'tags': '[]',
                    'first_contact_at': now.toIso8601String(),
                    'created_at': now.toIso8601String(),
                    'updated_at': now.add(const Duration(minutes: 3)).toIso8601String(),
                    'revision': 99,
                  },
                ],
                contentRange: '0-0/1',
              );
            }
            if (query.contains(pAllowed.id)) {
              return _mockJson(
                request,
                [
                  {
                    'id': pAllowed.id,
                    'name': 'Excluir Permitido',
                    'status': 'interessado',
                    'tags': '[]',
                    'first_contact_at': now.toIso8601String(),
                    'created_at': now.toIso8601String(),
                    'updated_at': now.subtract(const Duration(minutes: 10)).toIso8601String(),
                    'revision': 1,
                  },
                ],
                contentRange: '0-0/1',
              );
            }
          }
          if (request.method == 'PATCH' && path.contains('/rest/v1/people')) {
            if (query.contains(pBlocked.id)) patchedBlocked = true;
            if (query.contains(pAllowed.id)) patchedAllowed = true;
            return _mockJson(request, []);
          }
          return _mockJson(request, []);
        });

        final syncSvc = SupabaseSyncService(
          db: db,
          repository: repo,
          clientOverride: SupabaseClient(
            'https://mock.supabase.co',
            'dummy-key',
            httpClient: mockClient,
          ),
          documentsDirectoryProvider: () async => tempDir.path,
        );
        addTearDown(syncSvc.dispose);

        final res = await syncSvc.processQueue();
        expect(patchedBlocked, isFalse,
            reason: 'DELETE não pode apagar registro cuja revisão remota avançou');
        expect(patchedAllowed, isTrue,
            reason: 'DELETE com revisão >= remota deve aplicar soft-delete');
        expect(res.conflictCount, equals(1));
        expect(res.successCount, equals(1));
      },
    );

    test(
      'A3: person_photos realiza upload binário para Storage limpando image_data no PostgREST e persiste file_path no pull',
      () async {
        final now = DateTime.now().toUtc();
        final person = await repo.createPerson(name: 'Contato Foto');
        await db.delete(db.syncQueue).go();

        final photosDir = Directory(p.join(tempDir.path, 'person_photos'));
        await photosDir.create(recursive: true);
        final localPhoto = File(p.join(photosDir.path, 'local_photo.jpg'));
        final sampleJpeg = <int>[0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4];
        await localPhoto.writeAsBytes(sampleJpeg);

        await db.into(db.personPhotos).insert(
          PersonPhotosCompanion.insert(
            id: 'photo_up_1',
            personId: person.id,
            photoType: 'person',
            filePath: drift.Value(localPhoto.path),
            imageData: const drift.Value(''),
            createdAt: now,
            updatedAt: drift.Value(now),
          ),
        );
        await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: 'q_photo_up_1',
            entityType: 'person_photos',
            entityId: 'photo_up_1',
            operation: 'INSERT',
            payload: jsonEncode({
              'id': 'photo_up_1',
              'personId': person.id,
              'photoType': 'person',
              'filePath': localPhoto.path,
              'imageData': '',
              'createdAt': now.toIso8601String(),
              'updatedAt': now.toIso8601String(),
            }),
            createdAt: now,
            status: const drift.Value('pending'),
          ),
        );

        var uploadedStorageBytes = <int>[];
        Map<String, dynamic>? pushedPhotoPayload;
        final downloadedBytes = <int>[0xFF, 0xD8, 0xFF, 0xD9, 9, 8, 7, 6];

        final mockClient = MockClient((request) async {
          final path = request.url.path;
          if (path.contains('/storage/v1/object/person_photos') &&
              (request.method == 'POST' || request.method == 'PUT')) {
            uploadedStorageBytes = request.bodyBytes;
            return _mockJson(request, {'Key': 'person_photos/test_mock_uid/photo_up_1.jpg'});
          }
          if (request.method == 'POST' && path.endsWith('/rest/v1/rpc/sync_upsert_if_unchanged')) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            if (body['p_table'] == 'person_photos') {
              pushedPhotoPayload = Map<String, dynamic>.from(body['p_payload'] as Map);
            }
            return _mockJson(request, {'success': true});
          }
          if (request.method == 'GET' && path.contains('/rest/v1/person_photos')) {
            return _mockJson(
              request,
              [
                {
                  'id': 'photo_dl_1',
                  'person_id': person.id,
                  'photo_type': 'person',
                  'file_path': 'test_mock_uid/photo_dl_1.jpg',
                  'image_data': '',
                  'created_at': now.toIso8601String(),
                  'updated_at': now.toIso8601String(),
                  'revision': 1,
                },
              ],
              contentRange: '0-0/1',
            );
          }
          if (request.method == 'GET' &&
              path.contains('/storage/v1/object/person_photos') &&
              path.contains('photo_dl_1.jpg')) {
            return http.Response.bytes(
              downloadedBytes,
              200,
              request: request,
              headers: {'content-type': 'image/jpeg'},
            );
          }
          return _mockJson(request, []);
        });

        final syncSvc = SupabaseSyncService(
          db: db,
          repository: repo,
          clientOverride: SupabaseClient(
            'https://mock.supabase.co',
            'dummy-key',
            httpClient: mockClient,
          ),
          documentsDirectoryProvider: () async => tempDir.path,
        );
        addTearDown(syncSvc.dispose);

        final pushRes = await syncSvc.processQueue();
        expect(pushRes.failureCount, equals(0));
        expect(pushRes.successCount, equals(1));
        expect(uploadedStorageBytes, isNotEmpty);
        var containsJpegBytes = false;
        for (var i = 0; i <= uploadedStorageBytes.length - sampleJpeg.length; i++) {
          var match = true;
          for (var j = 0; j < sampleJpeg.length; j++) {
            if (uploadedStorageBytes[i + j] != sampleJpeg[j]) {
              match = false;
              break;
            }
          }
          if (match) {
            containsJpegBytes = true;
            break;
          }
        }
        expect(containsJpegBytes, isTrue,
            reason: 'Corpo multipart enviado ao Storage deve conter os bytes JPEG originais');
        expect(pushedPhotoPayload, isNotNull);
        expect(pushedPhotoPayload!['file_path'], equals('test_mock_uid/photo_up_1.jpg'));
        expect(pushedPhotoPayload!['image_data'], equals(''));

        final pullRes = await syncSvc.fetchRemoteChanges();
        expect(pullRes.failureCount, equals(0));

        final pulledPhoto = await (db.select(db.personPhotos)
              ..where((t) => t.id.equals('photo_dl_1')))
            .getSingle();
        expect(pulledPhoto.filePath, isNotNull);
        expect(File(pulledPhoto.filePath!).existsSync(), isTrue);
        expect(await File(pulledPhoto.filePath!).readAsBytes(), equals(downloadedBytes));
        expect(pulledPhoto.imageData, equals(''));
      },
    );
  });
}
