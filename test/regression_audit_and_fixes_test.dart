import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/core/app_version.dart';
import 'package:ministerio_pessoal/core/demo_data.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/inbox/jw_email_service.dart';
import 'package:ministerio_pessoal/media/person_photos_manager.dart';
import 'package:ministerio_pessoal/settings/backup_service.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:ministerio_pessoal/territory/landmark_manager.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_native.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_service.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/settings_screen.dart';
import 'package:ministerio_pessoal/ui/widgets/universal_attachment_viewer.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:supabase_flutter/supabase_flutter.dart';

http.Response _jsonRes(
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

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Regression Fixes Audit (Sync, UI, Backup, Email, MBTiles, A10)', () {
    late AppDatabase db;
    late AppRepository repo;
    late Directory tempDir;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
      tempDir = await Directory.systemTemp.createTemp('reg_fixes_test_');
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets(
      'SyncQueueManagementSheet displays _conflicts local/remote diffs and Manter Local syncs entity SQLite revision',
      (tester) async {
        final person = await repo.createPerson(name: 'Ana Local');
        final qOp = (await (db.select(db.syncQueue)
              ..where((t) => t.entityId.equals(person.id)))
            .getSingle());

        await repo.markSyncOperationConflict(
          qOp.id,
          'Conflito de edição concorrente',
          remoteData: {
            'id': person.id,
            'name': 'Ana Remota',
            'revision': 5,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          },
          conflicts: [
            {
              'field': 'name',
              'local': 'Ana Local',
              'remote': 'Ana Remota',
            },
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: const MaterialApp(
              home: Scaffold(body: SyncQueueManagementSheet()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Local="Ana Local" vs Remoto="Ana Remota"'),
          findsOneWidget,
        );

        await tester.tap(find.text('Manter Local'));
        await tester.pumpAndSettle();

        final updatedQueue = await (db.select(db.syncQueue)
              ..where((t) => t.id.equals(qOp.id)))
            .getSingle();
        expect(updatedQueue.status, equals('pending'));
        final payload = jsonDecode(updatedQueue.payload) as Map<String, dynamic>;
        expect(payload['revision'], equals(6));

        final updatedPerson = await repo.getPersonById(person.id);
        expect(updatedPerson?.revision, equals(6));
      },
    );

    test(
      'C2 Two-device concurrent divergence when remoteRev == localRev and remoteUpdated < localUpdated triggers 3-way conflict & orthogonal auto-merge',
      () async {
        final baseTime = DateTime.utc(2026, 11, 10, 10, 0);

        // Caso A: Mesmo campo alterado por 2 dispositivos offline na rev 2 (remoto 1 min mais antigo que local)
        final pConflict = await repo.createPerson(
          name: 'Maria Base',
          phone: '1111',
        );
        await (db.delete(db.syncQueue)..where((t) => t.entityId.equals(pConflict.id))).go();
        await (db.update(db.people)..where((t) => t.id.equals(pConflict.id))).write(
          PeopleCompanion(
            name: const drift.Value('Maria Local'),
            revision: const drift.Value(2),
            updatedAt: drift.Value(baseTime.add(const Duration(minutes: 5))),
          ),
        );
        await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: 'op_eq_rev_conflict',
            entityType: 'people',
            entityId: pConflict.id,
            operation: 'UPDATE',
            payload: jsonEncode({
              'id': pConflict.id,
              'name': 'Maria Local',
              'phone': '1111',
              'status': 'interessado',
              'tags': '[]',
              'firstContactAt': baseTime.toIso8601String(),
              'createdAt': baseTime.toIso8601String(),
              'updatedAt': baseTime.add(const Duration(minutes: 5)).toIso8601String(),
              'revision': 2,
              '_base': {
                'id': pConflict.id,
                'name': 'Maria Base',
                'phone': '1111',
                'status': 'interessado',
                'tags': '[]',
                'revision': 1,
              },
            }),
            createdAt: baseTime,
          ),
        );

        // Caso B: Campos ortogonais (local editou phone, remoto editou name) na mesma rev 2
        final pMerge = await repo.createPerson(
          name: 'João Base',
          phone: '3333',
        );
        await (db.delete(db.syncQueue)..where((t) => t.entityId.equals(pMerge.id))).go();
        await (db.update(db.people)..where((t) => t.id.equals(pMerge.id))).write(
          PeopleCompanion(
            phone: const drift.Value('4444'),
            revision: const drift.Value(2),
            updatedAt: drift.Value(baseTime.add(const Duration(minutes: 5))),
          ),
        );
        await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: 'op_eq_rev_merge',
            entityType: 'people',
            entityId: pMerge.id,
            operation: 'UPDATE',
            payload: jsonEncode({
              'id': pMerge.id,
              'name': 'João Base',
              'phone': '4444',
              'status': 'interessado',
              'tags': '[]',
              'firstContactAt': baseTime.toIso8601String(),
              'createdAt': baseTime.toIso8601String(),
              'updatedAt': baseTime.add(const Duration(minutes: 5)).toIso8601String(),
              'revision': 2,
              '_base': {
                'id': pMerge.id,
                'name': 'João Base',
                'phone': '3333',
                'status': 'interessado',
                'tags': '[]',
                'revision': 1,
              },
            }),
            createdAt: baseTime.add(const Duration(seconds: 1)),
          ),
        );

        final pushedUpserts = <String, Map<String, dynamic>>{};
        final mockClient = MockClient((request) async {
          final path = request.url.path;
          final query = request.url.query;
          if (request.method == 'GET' && path.contains('/rest/v1/people')) {
            if (query.contains(pConflict.id)) {
              return _jsonRes(
                request,
                [
                  {
                    'id': pConflict.id,
                    'name': 'Maria Remota',
                    'phone': '1111',
                    'status': 'interessado',
                    'tags': '[]',
                    'first_contact_at': baseTime.toIso8601String(),
                    'created_at': baseTime.toIso8601String(),
                    'updated_at': baseTime.add(const Duration(minutes: 2)).toIso8601String(),
                    'revision': 2,
                  },
                ],
                contentRange: '0-0/1',
              );
            }
            if (query.contains(pMerge.id)) {
              return _jsonRes(
                request,
                [
                  {
                    'id': pMerge.id,
                    'name': 'João Editado Remoto',
                    'phone': '3333',
                    'status': 'interessado',
                    'tags': '[]',
                    'first_contact_at': baseTime.toIso8601String(),
                    'created_at': baseTime.toIso8601String(),
                    'updated_at': baseTime.add(const Duration(minutes: 2)).toIso8601String(),
                    'revision': 2,
                  },
                ],
                contentRange: '0-0/1',
              );
            }
          }
          if (request.method == 'POST' && path.endsWith('/rest/v1/rpc/sync_upsert_if_unchanged')) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final p = Map<String, dynamic>.from(body['p_payload'] as Map);
            pushedUpserts[p['id'] as String] = p;
            return _jsonRes(request, {'success': true});
          }
          return _jsonRes(request, []);
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
        expect(res.successCount, equals(1));
        expect(pushedUpserts.containsKey(pConflict.id), isFalse);
        expect(pushedUpserts[pMerge.id]?['name'], equals('João Editado Remoto'));
        expect(pushedUpserts[pMerge.id]?['phone'], equals('4444'));
        expect(pushedUpserts[pMerge.id]?['revision'], equals(3));

        final localMerged = await repo.getPersonById(pMerge.id);
        expect(localMerged?.name, equals('João Editado Remoto'));
        expect(localMerged?.phone, equals('4444'));
        expect(localMerged?.revision, equals(3));
      },
    );

    test(
      'HARD_DELETE operation executes remote DELETE and leaves zero stuck pending items',
      () async {
        final person = await repo.createPerson(name: 'Para Excluir Definitivamente');
        await db.delete(db.syncQueue).go();
        await repo.permanentlyDeleteItem('people', person.id);

        var deleteCalled = false;
        final mockClient = MockClient((request) async {
          if (request.method == 'DELETE' &&
              request.url.path.contains('/rest/v1/people') &&
              request.url.query.contains(person.id)) {
            deleteCalled = true;
            return _jsonRes(request, []);
          }
          return _jsonRes(request, []);
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
        expect(deleteCalled, isTrue);
        expect(res.successCount, equals(1));
        expect(res.failureCount, equals(0));

        final remaining = await (db.select(db.syncQueue)
              ..where((t) => t.status.equals('pending')))
            .get();
        expect(remaining, isEmpty);
      },
    );

    test(
      'Ticuna words/phrases preserve non-tca language_id across hydration and pull, and M4 disables voice_notes upload fallback',
      () async {
        final now = DateTime.now().toUtc();
        await db.customInsert(
          '''
          INSERT INTO ticuna_words (
            id, word, translation, is_favorite, review_level, review_count, language_id, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          variables: [
            drift.Variable.withString('tw_gub_1'),
            drift.Variable.withString('Katu'),
            drift.Variable.withString('Bom'),
            drift.Variable.withInt(1),
            drift.Variable.withInt(2),
            drift.Variable.withInt(3),
            drift.Variable.withString('gub'),
            drift.Variable.withString(now.toIso8601String()),
            drift.Variable.withString(now.toIso8601String()),
          ],
        );
        await db.customInsert(
          '''
          INSERT INTO ticuna_phrases (
            id, phrase, translation, is_favorite, language_id, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?)
          ''',
          variables: [
            drift.Variable.withString('tp_gub_1'),
            drift.Variable.withString('Nerê'),
            drift.Variable.withString('Olá'),
            drift.Variable.withInt(0),
            drift.Variable.withString('gub'),
            drift.Variable.withString(now.toIso8601String()),
            drift.Variable.withString(now.toIso8601String()),
          ],
        );

        await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: 'q_tw_gub',
            entityType: 'ticuna_words',
            entityId: 'tw_gub_1',
            operation: 'INSERT',
            payload: jsonEncode({'id': 'tw_gub_1'}),
            createdAt: now,
          ),
        );
        await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: 'q_tp_gub',
            entityType: 'ticuna_phrases',
            entityId: 'tp_gub_1',
            operation: 'INSERT',
            payload: jsonEncode({'id': 'tp_gub_1'}),
            createdAt: now.add(const Duration(milliseconds: 5)),
          ),
        );

        // Caso M4: palavra com áudio local cujo upload no bucket ticuna_audio falha
        final audioFile = File(p.join(tempDir.path, 'gub_fail.m4a'))
          ..writeAsBytesSync([1, 2, 3, 4, 5, 6]);
        await db.customInsert(
          '''
          INSERT INTO ticuna_words (
            id, word, translation, audio_path, language_id, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?)
          ''',
          variables: [
            drift.Variable.withString('tw_audio_fail'),
            drift.Variable.withString('Pura'),
            drift.Variable.withString('Canto'),
            drift.Variable.withString(audioFile.path),
            drift.Variable.withString('gub'),
            drift.Variable.withString(now.toIso8601String()),
            drift.Variable.withString(now.toIso8601String()),
          ],
        );
        await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: 'q_tw_audio_fail',
            entityType: 'ticuna_words',
            entityId: 'tw_audio_fail',
            operation: 'INSERT',
            payload: jsonEncode({'id': 'tw_audio_fail'}),
            createdAt: now.add(const Duration(milliseconds: 10)),
          ),
        );

        final pushed = <String, Map<String, dynamic>>{};
        var uploadedToVoiceNotesBucket = false;
        final mockClient = MockClient((request) async {
          final path = request.url.path;
          if (path.contains('/storage/v1/object/voice_notes')) {
            uploadedToVoiceNotesBucket = true;
            return _jsonRes(request, {'Key': 'leaked'});
          }
          if (path.contains('/storage/v1/object/ticuna_audio')) {
            return _jsonRes(request, {'error': 'Bucket missing'}, statusCode: 500);
          }
          if (request.method == 'POST' && path.endsWith('/rest/v1/rpc/sync_upsert_if_unchanged')) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final p = Map<String, dynamic>.from(body['p_payload'] as Map);
            pushed[p['id'] as String] = p;
            return _jsonRes(request, {'success': true});
          }
          if (request.method == 'GET' && path.contains('/rest/v1/ticuna_words')) {
            return _jsonRes(
              request,
              [
                {
                  'id': 'tw_pull_gub',
                  'word': 'Igapó',
                  'translation': 'Água',
                  'tags': '[]',
                  'is_favorite': 1,
                  'language_id': 'gub',
                  'created_at': now.toIso8601String(),
                  'updated_at': now.toIso8601String(),
                  'revision': 1,
                },
              ],
              contentRange: '0-0/1',
            );
          }
          if (request.method == 'GET' && path.contains('/rest/v1/ticuna_phrases')) {
            return _jsonRes(
              request,
              [
                {
                  'id': 'tp_pull_yan',
                  'phrase': 'Kami yã',
                  'translation': 'Eu aqui',
                  'tags': '[]',
                  'is_favorite': 0,
                  'language_id': 'yan',
                  'created_at': now.toIso8601String(),
                  'updated_at': now.toIso8601String(),
                  'revision': 1,
                },
              ],
              contentRange: '0-0/1',
            );
          }
          return _jsonRes(request, []);
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
        expect(pushRes.successCount, equals(2));
        expect(pushRes.failureCount, equals(1));
        expect(uploadedToVoiceNotesBucket, isFalse);
        expect(pushed['tw_gub_1']?['language_id'], equals('gub'));
        expect(pushed['tp_gub_1']?['language_id'], equals('gub'));

        final pullRes = await syncSvc.fetchRemoteChanges();
        expect(pullRes.failureCount, equals(0));
        final pulledWord = await db
            .customSelect("SELECT language_id FROM ticuna_words WHERE id = 'tw_pull_gub'")
            .getSingle();
        final pulledPhrase = await db
            .customSelect("SELECT language_id FROM ticuna_phrases WHERE id = 'tp_pull_yan'")
            .getSingle();
        expect(pulledWord.read<String>('language_id'), equals('gub'));
        expect(pulledPhrase.read<String>('language_id'), equals('yan'));
      },
    );

    test(
      'BackupService clears cross-device filePath when exporting/restoring personPhotos with base64 imageData',
      () async {
        final srcDir = Directory(p.join(tempDir.path, 'src_docs'))..createSync();
        final dstDir = Directory(p.join(tempDir.path, 'dst_docs'))..createSync();
        final dstDb = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(dstDb.close);
        final dstRepo = AppRepository(dstDb);

        final srcBackup = BackupService(
          repo,
          documentsDirectoryProvider: () async => srcDir,
        );
        final dstBackup = BackupService(
          dstRepo,
          documentsDirectoryProvider: () async => dstDir,
        );

        final person = await repo.createPerson(name: 'Pessoa Foto Portátil');
        final photoDir = Directory(p.join(srcDir.path, 'person_photos'))..createSync();
        final photoFile = File(p.join(photoDir.path, 'p1.jpg'))
          ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0, 10, 20, 30]);

        await db.into(db.personPhotos).insert(
          PersonPhotosCompanion.insert(
            id: 'ph_cross_1',
            personId: person.id,
            photoType: 'person',
            filePath: drift.Value(photoFile.path),
            imageData: const drift.Value(''),
            createdAt: DateTime.now().toUtc(),
          ),
        );

        const pwd = 'CrossDevicePhoto#2026';
        final encrypted = await srcBackup.exportEncryptedBackup(pwd, iterations: 1000);
        // Apaga arquivo de origem simulando restauração em um segundo dispositivo
        photoFile.deleteSync();

        final preview = await dstBackup.previewBackup(
          encryptedDataString: encrypted,
          password: pwd,
        );
        // Também injeta cenário legado onde filePath antigo veio preenchido no payload
        final photosJson = preview.rawDecryptedData['personPhotos'] as List<dynamic>;
        expect((photosJson.first as Map)['filePath'], isNull);
        photosJson.add({
          'id': 'ph_legacy_dead_path',
          'personId': person.id,
          'photoType': 'house',
          'filePath': '/device1/inexistente/dead_photo.jpg',
          'imageData': 'data:image/jpeg;base64,/9j/4AAQSkZJRg==',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'revision': 1,
        });

        await dstBackup.commitRestore(preview);
        final restored = await dstDb.select(dstDb.personPhotos).get();
        expect(restored.length, equals(2));
        for (final row in restored) {
          expect(row.filePath, isNull);
          expect(row.imageData, startsWith('data:image/jpeg;base64,'));
          expect(
            PersonPhotoItem.fromEntry(row).effectiveImageSource,
            startsWith('data:image/jpeg;base64,'),
          );
        }
      },
    );

    test(
      'JwImapClient preserves Subject:/From:/Date: lines inside BODY[TEXT] and trailing parenthesized text',
      () {
        const client = JwImapClient();
        final msgs = client.parseImapResponsesForTest([
          '* 1 FETCH (UID 901 BODY[HEADER.FIELDS (Subject From To Date)] {110}',
          'Subject: Convite Real do Circuito',
          'From: escritorio@hub.jw.org',
          'To: irmao@jw.org',
          'Date: Mon, 10 Nov 2026 12:00:00 -0400',
          '',
          'BODY[TEXT] {140}',
          'Subject: Assunto citado dentro do corpo do e-mail',
          'From: remetente_citado@example.com',
          '(Nota importante)',
          ')',
          'A004 OK FETCH completed',
        ]);

        expect(msgs.length, equals(1));
        expect(msgs.single.subject, equals('Convite Real do Circuito'));
        expect(msgs.single.from, equals('escritorio@hub.jw.org'));
        expect(msgs.single.bodyText, contains('Subject: Assunto citado dentro do corpo do e-mail'));
        expect(msgs.single.bodyText, contains('From: remetente_citado@example.com'));
        expect(msgs.single.bodyText, contains('(Nota importante)'));
        expect(msgs.single.bodyText.endsWith(')'), isTrue);
        expect(msgs.single.bodyText.split('\n').last.trim(), equals('(Nota importante)'));
      },
    );

    test(
      'MBTilesNative rejects non-SQLite payloads and SQLite databases missing the tiles table',
      () async {
        final mbDir = Directory(p.join(tempDir.path, 'mb_check'))..createSync();
        final backend = MBTilesNative(customDir: mbDir);
        final mbService = MBTilesService.custom(backend: backend);
        addTearDown(() {
          mbService.dispose();
          backend.dispose();
        });
        await mbService.init();

        final htmlClient = MockClient(
          (req) async => http.Response('<html>Not MBTiles</html>', 200),
        );
        await expectLater(
          () => mbService.downloadRegion('br_am_solimoes', httpClient: htmlClient),
          throwsA(isA<FormatException>()),
        );
        expect(backend.isRegionInstalled('br_am_solimoes'), isFalse);
        expect(mbDir.listSync(), isEmpty);

        // SQLite válido mas sem tabela 'tiles'
        final noTilesPath = p.join(tempDir.path, 'no_tiles.db');
        final rawDb = sql.sqlite3.open(noTilesPath);
        rawDb.execute('CREATE TABLE metadata (name TEXT, value TEXT);');
        rawDb.close();
        final noTilesBytes = File(noTilesPath).readAsBytesSync();

        final noTilesClient = MockClient(
          (req) async => http.Response.bytes(noTilesBytes, 200),
        );
        await expectLater(
          () => mbService.downloadRegion('br_am_solimoes', httpClient: noTilesClient),
          throwsA(isA<FormatException>()),
        );
        expect(backend.isRegionInstalled('br_am_solimoes'), isFalse);
        expect(mbDir.listSync(), isEmpty);
      },
    );

    test(
      'DemoDataGenerator.clearDemoData purges demo sync_queue & Beatriz Martins (Demo) while preserving real user records',
      () async {
        final realPerson = await repo.createPerson(name: 'Irmão Real Presencial');
        await repo.createActivityRecord(
          date: DateTime.now(),
          durationSeconds: 3600,
          modality: 'campo',
          notes: '[Publicações: 4] Campanha real do fim de semana',
        );

        await DemoDataGenerator.populateDemoData(repo);
        expect(await DemoDataGenerator.hasDemoData(repo), isTrue);

        final removed = await DemoDataGenerator.clearDemoData(repo);
        expect(removed, equals(4));

        final peopleAfter = await repo.getAllPeople();
        expect(peopleAfter.map((p) => p.id), equals([realPerson.id]));

        final activitiesAfter = await db.select(db.activityRecords).get();
        expect(activitiesAfter.length, equals(1));
        expect(activitiesAfter.single.notes, contains('Campanha real do fim de semana'));

        final queueAfter = await db.select(db.syncQueue).get();
        expect(queueAfter.map((q) => q.entityId).toSet(), contains(realPerson.id));
        expect(
          queueAfter.where((q) => q.entityType == 'people').length,
          equals(1),
        );
      },
    );

    test(
      'LandmarkManager persists and enqueues INSERT/UPDATE/DELETE transactionally with incrementing revision',
      () async {
        final mgr = LandmarkManager(db);
        final created = await mgr.addLandmark(
          name: 'Porto Central',
          category: 'transporte',
          latitude: -3.1022,
          longitude: -67.9397,
        );

        var row = await (db.select(db.territoryLandmarks)
              ..where((t) => t.id.equals(created.id)))
            .getSingle();
        expect(row.revision, equals(1));

        await mgr.updateLandmark(
          TerritoryLandmark(
            id: created.id,
            name: 'Porto Central Atualizado',
            category: 'transporte',
            latitude: -3.1025,
            longitude: -67.9399,
            createdAt: created.createdAt,
          ),
        );
        row = await (db.select(db.territoryLandmarks)
              ..where((t) => t.id.equals(created.id)))
            .getSingle();
        expect(row.revision, equals(2));

        await mgr.deleteLandmark(created.id);
        row = await (db.select(db.territoryLandmarks)
              ..where((t) => t.id.equals(created.id)))
            .getSingle();
        expect(row.revision, equals(3));
        expect(row.deletedAt, isNotNull);

        final ops = await (db.select(db.syncQueue)
              ..where((t) => t.entityId.equals(created.id))
              ..orderBy([(t) => drift.OrderingTerm.asc(t.createdAt)]))
            .get();
        expect(ops.map((o) => o.operation).toList(), equals(['INSERT', 'UPDATE', 'DELETE']));
        expect((jsonDecode(ops[0].payload) as Map)['revision'], equals(1));
        expect((jsonDecode(ops[1].payload) as Map)['revision'], equals(2));
        expect((jsonDecode(ops[2].payload) as Map)['revision'], equals(3));
      },
    );

    test(
      'A10: AppVersion.liveContainerSourceUrl and apps.json URLs point to immutable release tag/asset, not @master',
      () {
        expect(
          AppVersion.liveContainerSourceUrl,
          equals('livecontainer://sources?url=${Uri.encodeComponent(AppVersion.releaseAppsJsonUrl)}'),
        );
        expect(AppVersion.liveContainerSourceUrl, isNot(contains('%40master')));

        final appsJson = jsonDecode(File('apps.json').readAsStringSync()) as Map<String, dynamic>;
        expect(appsJson['sourceURL'], equals(AppVersion.releaseAppsJsonUrl));
        final firstApp = (appsJson['apps'] as List).first as Map<String, dynamic>;
        for (final key in ['iconURL', 'headerURL']) {
          final url = appsJson[key]?.toString() ?? '';
          expect(url, isNotEmpty);
          expect(url, isNot(contains('@master')));
          expect(url, contains('@v${AppVersion.version}'));
        }
        final appIcon = firstApp['iconURL']?.toString() ?? '';
        expect(appIcon, isNotEmpty);
        expect(appIcon, isNot(contains('@master')));
        expect(appIcon, contains('@v${AppVersion.version}'));
      },
    );

    testWidgets(
      'UniversalAttachmentViewerDialog renders preloaded MemoryImage without FileImage/inline FutureBuilder',
      (tester) async {
        // PNG mínimo válido 1x1 transparente
        final pngBytes = Uint8List.fromList(const [
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
          0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
          0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
          0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
          0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
          0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
          0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
          0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
          0x42, 0x60, 0x82,
        ]);
        final imgFile = File(p.join(tempDir.path, 'sample.png'))
          ..writeAsBytesSync(pngBytes);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UniversalAttachmentViewerDialog(
                filePath: imgFile.path,
                fileType: 'png',
              ),
            ),
          ),
        );
        for (int i = 0; i < 40; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)),
          );
          await tester.pump();
          if (find.byType(Image).evaluate().isNotEmpty) break;
        }
        await tester.pumpAndSettle();

        final imgFinder = find.byType(Image);
        expect(imgFinder, findsOneWidget);
        final imgWidget = tester.widget<Image>(imgFinder);
        expect(imgWidget.image, isA<MemoryImage>());
      },
    );
  });
}
