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
import 'package:ministerio_pessoal/ticuna/ticuna_repository.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

http.Response mockJsonResponse(
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

http.Response mockBinaryResponse(
  http.Request request,
  List<int> bytes, {
  int statusCode = 200,
  String contentType = 'application/octet-stream',
}) {
  return http.Response.bytes(
    bytes,
    statusCode,
    request: request,
    headers: {'content-type': contentType},
  );
}

void main() {
  group('SupabaseSyncService - Sincronização e Resiliência Offline', () {
    late AppDatabase db;
    late AppRepository repo;
    late SupabaseSyncService syncService;
    late Directory tempDir;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
      tempDir = await Directory.systemTemp.createTemp('sync_test_');
      syncService = SupabaseSyncService(
        db: db,
        repository: repo,
        supabaseUrl: '', // Não configurado
        supabaseAnonKey: '',
        documentsDirectoryProvider: () async => tempDir.path,
      );
    });

    tearDown(() async {
      syncService.dispose();
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('TC-SYNC-04: Relatório honesto — quando não configurado, reporta waitingConnection e não simula sucesso falso', () async {
      expect(syncService.isConfigured, isFalse);

      await repo.createPerson(name: 'Irmão Teste');

      final result = await syncService.processQueue();

      expect(result.totalProcessed, greaterThanOrEqualTo(1));
      expect(result.successCount, equals(0));
      expect(result.message, contains('não configurado'));
      expect(syncService.currentStatus, equals(SyncStatus.waitingConnection));
    });

    test(
      'TC-SYNC-05: Fila vazia reporta status synced com 0 operações',
      () async {
        final result = await syncService.processQueue();

        expect(result.totalProcessed, equals(0));
        expect(result.successCount, equals(0));
        expect(syncService.currentStatus, equals(SyncStatus.synced));
      },
    );

    test('TC-SYNC-06: Sanitização de payload remove caminhos de arquivos locais de voice_notes', () {
      final voiceNotePayload = {
        'id': 'vn-123',
        'person_id': 'p-456',
        'transcription': 'Estudo realizado na lição 18 ponto 3',
        'audio_file_path':
            '/data/user/0/com.app/app_flutter/voice_notes/secret_note.m4a',
        'audio_duration_seconds': 15,
      };

      final cleanPayload = SupabaseSyncService.sanitizePayload(
        'voice_notes',
        voiceNotePayload,
      );

      expect(cleanPayload.containsKey('audio_file_path'), isFalse);
      expect(
        cleanPayload['transcription'],
        equals('Estudo realizado na lição 18 ponto 3'),
      );
      expect(cleanPayload['audio_duration_seconds'], equals(15));
      expect(cleanPayload['id'], equals('vn-123'));
    });

    test('TC-SYNC-07: Mapeamento de entidades para nomes oficiais de tabelas PostgreSQL', () {
      expect(
        SupabaseSyncService.mapEntityToRemoteTable('people'),
        equals('people'),
      );
      expect(
        SupabaseSyncService.mapEntityToRemoteTable('visits'),
        equals('visits'),
      );
      expect(
        SupabaseSyncService.mapEntityToRemoteTable('bibleStudies'),
        equals('bible_studies'),
      );
      expect(
        SupabaseSyncService.mapEntityToRemoteTable('studyParticipants'),
        equals('study_participants'),
      );
      expect(
        SupabaseSyncService.mapEntityToRemoteTable('studySessions'),
        equals('study_sessions'),
      );
      expect(
        SupabaseSyncService.mapEntityToRemoteTable('appointments'),
        equals('appointments'),
      );
      expect(
        SupabaseSyncService.mapEntityToRemoteTable('activityRecords'),
        equals('activity_records'),
      );
      expect(
        SupabaseSyncService.mapEntityToRemoteTable('voiceNotes'),
        equals('voice_notes'),
      );
      expect(
        SupabaseSyncService.mapEntityToRemoteTable('phoneContacts'),
        equals('phone_contacts'),
      );
      expect(
        SupabaseSyncService.mapEntityToRemoteTable('territoryLandmarks'),
        equals('territory_landmarks'),
      );
    });

    test('TC-SYNC-08: Merge sem conflito — mesclagem em nível de campo preserva edições locais e remotas distintas', () async {
      final now = DateTime.now().toUtc();
      await db
          .into(db.people)
          .insert(
            PersonEntry(
              id: 'p_merge_1',
              name: 'Carlos Rocha',
              phone: '11999990000',
              firstContactAt: now,
              status: 'interessado',
              tags: '[]',
              generalNotes: 'Nota Original',
              createdAt: now,
              updatedAt: now,
              revision: 1,
            ),
          );

      await db
          .into(db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: 'q_merge_1',
              entityType: 'people',
              entityId: 'p_merge_1',
              operation: 'UPDATE',
              payload: jsonEncode({
                'id': 'p_merge_1',
                'name': 'Carlos Rocha',
                'phone': '11999990000',
                'firstContactAt': now.toIso8601String(),
                'status': 'interessado',
                'tags': '[]',
                'generalNotes': 'Nota Local Atualizada',
                'createdAt': now.toIso8601String(),
                'updatedAt': now
                    .add(const Duration(minutes: 5))
                    .toIso8601String(),
                'revision': 2,
              }),
              createdAt: now,
              status: const drift.Value('pending'),
            ),
          );

      final remotePerson = {
        'id': 'p_merge_1',
        'name': 'Carlos Rocha',
        'phone': '11888887777',
        'first_contact_at': now.toIso8601String(),
        'status': 'interessado',
        'tags': '[]',
        'general_notes': 'Nota Original',
        'created_at': now.toIso8601String(),
        'updated_at': now.add(const Duration(minutes: 10)).toIso8601String(),
        'revision': 2,
      };

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/rest/v1/people')) {
          return mockJsonResponse(request, [
            remotePerson,
          ], contentRange: '0-0/1');
        }
        return mockJsonResponse(request, []);
      });

      final customSync = SupabaseSyncService(
        db: db,
        repository: repo,
        clientOverride: SupabaseClient(
          'https://mock.supabase.co',
          'dummy-key-xyz',
          httpClient: mockClient,
        ),
        documentsDirectoryProvider: () async => tempDir.path,
      );

      final res = await customSync.fetchRemoteChanges();
      expect(res.successCount, equals(1));
      expect(res.conflictCount, equals(0));

      final updated = await (db.select(
        db.people,
      )..where((t) => t.id.equals('p_merge_1'))).getSingle();
      expect(updated.phone, equals('11888887777'));
      expect(updated.generalNotes, equals('Nota Local Atualizada'));
    });

    test('TC-SYNC-09: Detecção explícita de conflito — mutações concorrentes no mesmo campo sinalizam conflict sem sobrescrever cegamente', () async {
      final now = DateTime.now().toUtc();
      await db
          .into(db.people)
          .insert(
            PersonEntry(
              id: 'p_conflict_1',
              name: 'Maria Silva',
              phone: '1111-1111',
              firstContactAt: now,
              status: 'interessado',
              tags: '[]',
              createdAt: now,
              updatedAt: now,
              revision: 1,
            ),
          );

      await db
          .into(db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: 'q_conflict_1',
              entityType: 'people',
              entityId: 'p_conflict_1',
              operation: 'UPDATE',
              payload: jsonEncode({
                'id': 'p_conflict_1',
                'name': 'Maria Silva',
                'phone': '2222-2222',
                'firstContactAt': now.toIso8601String(),
                'status': 'interessado',
                'tags': '[]',
                'createdAt': now.toIso8601String(),
                'updatedAt': now
                    .add(const Duration(minutes: 5))
                    .toIso8601String(),
                'revision': 2,
              }),
              createdAt: now,
              status: const drift.Value('pending'),
            ),
          );

      final remotePerson = {
        'id': 'p_conflict_1',
        'name': 'Maria Silva',
        'phone': '9999-9999',
        'first_contact_at': now.toIso8601String(),
        'status': 'interessado',
        'tags': '[]',
        'created_at': now.toIso8601String(),
        'updated_at': now.add(const Duration(minutes: 6)).toIso8601String(),
        'revision': 2,
      };

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/rest/v1/people')) {
          return mockJsonResponse(request, [
            remotePerson,
          ], contentRange: '0-0/1');
        }
        return mockJsonResponse(request, []);
      });

      final customSync = SupabaseSyncService(
        db: db,
        repository: repo,
        clientOverride: SupabaseClient(
          'https://mock.supabase.co',
          'dummy-key-xyz',
          httpClient: mockClient,
        ),
        documentsDirectoryProvider: () async => tempDir.path,
      );

      final res = await customSync.fetchRemoteChanges();
      expect(res.conflictCount, equals(1));
      expect(customSync.currentStatus, equals(SyncStatus.conflict));

      final op = await (db.select(
        db.syncQueue,
      )..where((t) => t.id.equals('q_conflict_1'))).getSingle();
      expect(op.status, equals('conflict'));

      final current = await (db.select(
        db.people,
      )..where((t) => t.id.equals('p_conflict_1'))).getSingle();
      expect(current.phone, isNot(equals('9999-9999')));
    });

    test('TC-SYNC-10: Preservação de Tombstone — registro excluído remotamente gera soft delete local sem ressurgimento', () async {
      final now = DateTime.now().toUtc();
      await db
          .into(db.people)
          .insert(
            PersonEntry(
              id: 'p_tomb_1',
              name: 'Roberto Souza',
              phone: '1133334444',
              firstContactAt: now,
              status: 'interessado',
              tags: '[]',
              createdAt: now,
              updatedAt: now,
              deletedAt: null,
              revision: 1,
            ),
          );

      final remoteDeleted = {
        'id': 'p_tomb_1',
        'name': 'Roberto Souza',
        'phone': '1133334444',
        'first_contact_at': now.toIso8601String(),
        'status': 'interessado',
        'tags': '[]',
        'created_at': now.toIso8601String(),
        'updated_at': now.add(const Duration(minutes: 5)).toIso8601String(),
        'deleted_at': now.add(const Duration(minutes: 5)).toIso8601String(),
        'revision': 2,
      };

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/rest/v1/people')) {
          return mockJsonResponse(request, [
            remoteDeleted,
          ], contentRange: '0-0/1');
        }
        return mockJsonResponse(request, []);
      });

      final customSync = SupabaseSyncService(
        db: db,
        repository: repo,
        clientOverride: SupabaseClient(
          'https://mock.supabase.co',
          'dummy-key-xyz',
          httpClient: mockClient,
        ),
        documentsDirectoryProvider: () async => tempDir.path,
      );

      final res = await customSync.fetchRemoteChanges();
      expect(res.successCount, equals(1));

      final local = await (db.select(
        db.people,
      )..where((t) => t.id.equals('p_tomb_1'))).getSingle();
      expect(local.deletedAt, isNotNull);

      final activeList = await repo.getAllPeople();
      expect(activeList.any((p) => p.id == 'p_tomb_1'), isFalse);
    });

    test('TC-SYNC-11: Tratamento de falha de rede — registra erros estruturados em errors e preserva integridade local', () async {
      final now = DateTime.now().toUtc();
      await db
          .into(db.people)
          .insert(
            PersonEntry(
              id: 'p_net_1',
              name: 'Irmão Protegido',
              phone: '1155556666',
              firstContactAt: now,
              status: 'interessado',
              tags: '[]',
              createdAt: now,
              updatedAt: now,
              revision: 1,
            ),
          );

      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500, request: request);
      });

      final customSync = SupabaseSyncService(
        db: db,
        repository: repo,
        clientOverride: SupabaseClient(
          'https://mock.supabase.co',
          'dummy-key-xyz',
          httpClient: mockClient,
        ),
        documentsDirectoryProvider: () async => tempDir.path,
      );

      final res = await customSync.fetchRemoteChanges();
      expect(res.failureCount, greaterThan(0));
      expect(res.errors, isNotEmpty);
      expect(res.errors.first, contains('Erro ao buscar alterações na tabela'));
      expect(customSync.currentStatus, equals(SyncStatus.error));

      final local = await (db.select(
        db.people,
      )..where((t) => t.id.equals('p_net_1'))).getSingle();
      expect(local.name, equals('Irmão Protegido'));
    });

    test('TC-SYNC-12: Paginação incremental sobre 100 registros — percorre páginas completas e processa todos os registros', () async {
      final now = DateTime.now().toUtc();
      final allRemotePeople = List.generate(150, (index) {
        return {
          'id': 'p_page_$index',
          'name': 'Pessoa Paginada $index',
          'phone': '110000${index.toString().padLeft(4, '0')}',
          'first_contact_at': now.toIso8601String(),
          'status': 'interessado',
          'tags': '[]',
          'created_at': now.toIso8601String(),
          'updated_at': now.add(Duration(seconds: index)).toIso8601String(),
          'revision': 1,
        };
      });

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/rest/v1/people')) {
          final offsetParam = request.url.queryParameters['offset'];
          final limitParam = request.url.queryParameters['limit'];
          int from = 0;
          int count = 100;
          if (offsetParam != null && limitParam != null) {
            from = int.parse(offsetParam);
            count = int.parse(limitParam);
          } else {
            final rangeHeader =
                request.headers['range'] ?? request.headers['Range'] ?? '';
            final match = RegExp(r'(\d+)-(\d+)').firstMatch(rangeHeader);
            from = match != null ? int.parse(match.group(1)!) : 0;
            final to = match != null ? int.parse(match.group(2)!) : 99;
            count = to - from + 1;
          }

          final pageItems = allRemotePeople.skip(from).take(count).toList();
          final end = pageItems.isEmpty ? from : from + pageItems.length - 1;
          return mockJsonResponse(
            request,
            pageItems,
            contentRange: '$from-$end/${allRemotePeople.length}',
          );
        }
        return mockJsonResponse(request, []);
      });

      final customSync = SupabaseSyncService(
        db: db,
        repository: repo,
        clientOverride: SupabaseClient(
          'https://mock.supabase.co',
          'dummy-key-xyz',
          httpClient: mockClient,
        ),
        documentsDirectoryProvider: () async => tempDir.path,
      );

      final res = await customSync.fetchRemoteChanges();
      expect(res.totalProcessed, equals(150));
      expect(res.successCount, equals(150));

      final countInDb = await (db.select(db.people)).get();
      expect(countInDb.length, equals(150));

      final kvRow = await (db.select(
        db.appKvStore,
      )..where((t) => t.key.equals('last_synced_at_people'))).getSingleOrNull();
      expect(kvRow, isNotNull);
      expect(kvRow!.value, isNotEmpty);
    });

    test('TC-SYNC-13: Sincronização de mídia — upload no push e download no pull de notas de voz', () async {
      final now = DateTime.now().toUtc();
      final person = await repo.createPerson(name: 'Ana Costa');

      final audioDir = Directory(p.join(tempDir.path, 'voice_notes'));
      await audioDir.create(recursive: true);
      final localAudioFile = File(p.join(audioDir.path, 'local_note.m4a'));
      await localAudioFile.writeAsBytes(
        utf8.encode('AUDIO_BINARY_BYTES_12345'),
      );

      await db
          .into(db.voiceNotes)
          .insert(
            VoiceNotesCompanion.insert(
              id: 'vn_upload_test',
              personId: person.id,
              audioFilePath: drift.Value(localAudioFile.path),
              audioDurationSeconds: const drift.Value(12),
              transcription: 'Transcrição do estudo com Ana',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db
          .into(db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: 'q_vn_1',
              entityType: 'voice_notes',
              entityId: 'vn_upload_test',
              operation: 'INSERT',
              payload: jsonEncode({
                'id': 'vn_upload_test',
                'personId': person.id,
                'audioDurationSeconds': 12,
                'transcription': 'Transcrição do estudo com Ana',
                'createdAt': now.toIso8601String(),
                'updatedAt': now.toIso8601String(),
              }),
              createdAt: now,
              status: const drift.Value('pending'),
            ),
          );

      bool storageUploadCalled = false;
      bool storageDownloadCalled = false;

      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/storage/v1/object/voice_notes') &&
            path.contains('vn_upload_test.m4a') &&
            request.method == 'POST') {
          storageUploadCalled = true;
          return mockJsonResponse(request, {
            'Key': 'voice_notes/vn_upload_test.m4a',
          });
        }
        if (path.contains('/storage/v1/object/voice_notes') &&
            path.contains('vn_download_test.m4a') &&
            request.method == 'GET') {
          storageDownloadCalled = true;
          return mockBinaryResponse(
            request,
            utf8.encode('DOWNLOADED_BINARY_AUDIO_BYTES'),
            contentType: 'audio/m4a',
          );
        }
        if (path.contains('/rest/v1/voice_notes')) {
          if (request.method == 'POST') {
            return mockJsonResponse(request, []);
          }
          if (request.method == 'GET') {
            return mockJsonResponse(request, [
              {
                'id': 'vn_download_test',
                'person_id': person.id,
                'audio_duration_seconds': 20,
                'transcription': 'Transcrição baixada da nuvem',
                'created_at': now.toIso8601String(),
                'updated_at': now.toIso8601String(),
                'revision': 1,
              },
            ], contentRange: '0-0/1');
          }
        }
        return mockJsonResponse(request, []);
      });

      final customSync = SupabaseSyncService(
        db: db,
        repository: repo,
        clientOverride: SupabaseClient(
          'https://mock.supabase.co',
          'dummy-key-xyz',
          httpClient: mockClient,
        ),
        documentsDirectoryProvider: () async => tempDir.path,
      );

      final pushRes = await customSync.processQueue();
      expect(pushRes.successCount, equals(2));
      expect(
        storageUploadCalled,
        isTrue,
        reason: 'Upload binário no Storage deve ser invocado',
      );

      final pullRes = await customSync.fetchRemoteChanges();
      expect(pullRes.successCount, greaterThanOrEqualTo(1));
      expect(
        storageDownloadCalled,
        isTrue,
        reason: 'Download binário do Storage deve ser invocado',
      );

      final downloadedNote = await (db.select(
        db.voiceNotes,
      )..where((t) => t.id.equals('vn_download_test'))).getSingle();
      expect(downloadedNote.audioFilePath, isNotNull);
      expect(File(downloadedNote.audioFilePath!).existsSync(), isTrue);
    });

    test('TC-SYNC-ADV-01: Cursor Determinístico — 120 registros remotos com o exato mesmo timestamp são puxados integralmente', () async {
      final now = DateTime.now().toUtc();
      final fixedTimestamp = now.toIso8601String();

      final allRemotePeople = List.generate(
        120,
        (i) => {
          'id': 'person_bulk_${i.toString().padLeft(3, '0')}',
          'name': 'Pessoa Bulk $i',
          'phone': '119000000$i',
          'first_contact_at': fixedTimestamp,
          'status': 'interessado',
          'tags': '[]',
          'general_notes': 'Nota $i',
          'created_at': fixedTimestamp,
          'updated_at': fixedTimestamp,
          'revision': 1,
        },
      );

      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/rest/v1/people')) {
          final offsetParam = request.url.queryParameters['offset'];
          final limitParam = request.url.queryParameters['limit'];
          int from = 0;
          int count = 100;
          if (offsetParam != null && limitParam != null) {
            from = int.parse(offsetParam);
            count = int.parse(limitParam);
          } else {
            final rangeHeader =
                request.headers['range'] ?? request.headers['Range'] ?? '';
            final match = RegExp(r'(\d+)-(\d+)').firstMatch(rangeHeader);
            from = match != null ? int.parse(match.group(1)!) : 0;
            final to = match != null ? int.parse(match.group(2)!) : 99;
            count = to - from + 1;
          }

          final pageItems = allRemotePeople.skip(from).take(count).toList();
          final end = pageItems.isEmpty ? from : from + pageItems.length - 1;
          return mockJsonResponse(
            request,
            pageItems,
            contentRange: '$from-$end/120',
          );
        }
        return mockJsonResponse(request, []);
      });

      final customSync = SupabaseSyncService(
        db: db,
        repository: repo,
        clientOverride: SupabaseClient(
          'https://mock.supabase.co',
          'dummy-key-xyz',
          httpClient: mockClient,
        ),
        documentsDirectoryProvider: () async => tempDir.path,
      );

      final res = await customSync.fetchRemoteChanges();
      expect(res.totalProcessed, equals(120));
      expect(res.successCount, equals(120));

      final allPeople = await db.select(db.people).get();
      expect(allPeople.length, equals(120));

      final kvRow = await (db.select(
        db.appKvStore,
      )..where((t) => t.key.equals('last_synced_at_people'))).getSingleOrNull();
      expect(kvRow, isNotNull);
      expect(kvRow!.value, equals(fixedTimestamp));
    });

    test('TC-SYNC-ADV-02: Upload de áudio não confirmado mantém operação na fila como failed sem marcar sucesso', () async {
      final now = DateTime.now().toUtc();
      final person = await repo.createPerson(name: 'Irmão com Falha de Áudio');

      final audioDir = Directory(p.join(tempDir.path, 'voice_notes'));
      await audioDir.create(recursive: true);
      final audioFile = File(p.join(audioDir.path, 'failing_audio.m4a'));
      await audioFile.writeAsBytes(utf8.encode('AUDIO_DATA'));

      await db
          .into(db.voiceNotes)
          .insert(
            VoiceNotesCompanion.insert(
              id: 'vn_failing_upload',
              personId: person.id,
              transcription: 'Transcrição',
              audioFilePath: drift.Value(audioFile.path),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db
          .into(db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: 'q_vn_fail_upload',
              entityType: 'voice_notes',
              entityId: 'vn_failing_upload',
              operation: 'INSERT',
              payload: jsonEncode({
                'id': 'vn_failing_upload',
                'personId': person.id,
                'transcription': 'Transcrição',
                'createdAt': now.toIso8601String(),
                'updatedAt': now.toIso8601String(),
              }),
              createdAt: now,
              status: const drift.Value('pending'),
            ),
          );

      final mockClient = MockClient((request) async {
        final path = request.url.path;
        // Metadados são aceitos pelo PostgREST
        if (path.contains('/rest/v1/voice_notes')) {
          return mockJsonResponse(request, []);
        }
        // Storage simula falha 500 no upload do arquivo binário
        if (path.contains('/storage/v1/object/voice_notes')) {
          return http.Response('Internal Storage Error', 500);
        }
        return mockJsonResponse(request, []);
      });

      final customSync = SupabaseSyncService(
        db: db,
        repository: repo,
        clientOverride: SupabaseClient(
          'https://mock.supabase.co',
          'dummy-key-xyz',
          httpClient: mockClient,
        ),
        documentsDirectoryProvider: () async => tempDir.path,
      );

      final result = await customSync.processQueue();
      expect(result.failureCount, equals(1));
      expect(
        result.successCount,
        equals(1),
      ); // Person criada no setUp passou, nota de voz falhou

      // VERIFICAÇÃO CRÍTICA:
      // A operação da nota de voz NÃO PODE ter sido marcada como synced!
      final opInDb = await (db.select(
        db.syncQueue,
      )..where((t) => t.id.equals('q_vn_fail_upload'))).getSingle();
      expect(opInDb.status, equals('failed'));
      expect(opInDb.attempts, equals(1));
      expect(opInDb.lastError, contains('Falha no upload do arquivo binário'));
    });

    test('TC-SYNC-ADV-03: Download de áudio pendente é registrado e recuperável via retryPendingMediaDownloads', () async {
      final now = DateTime.now().toUtc();
      final person = await repo.createPerson(name: 'Irmão com Áudio Pendente');

      bool allowDownload = false;

      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/rest/v1/voice_notes')) {
          return mockJsonResponse(request, [
            {
              'id': 'vn_pending_dl_1',
              'person_id': person.id,
              'transcription': 'Transcrição pendente',
              'created_at': now.toIso8601String(),
              'updated_at': now.toIso8601String(),
              'revision': 1,
            },
          ], contentRange: '0-0/1');
        }
        if (path.contains('/storage/v1/object/voice_notes') &&
            path.contains('vn_pending_dl_1.m4a')) {
          if (!allowDownload) {
            return http.Response('Network timeout on audio', 504);
          } else {
            return mockBinaryResponse(
              request,
              utf8.encode('AUDIO_RECOVERED_BYTES_999'),
              contentType: 'audio/m4a',
            );
          }
        }
        return mockJsonResponse(request, []);
      });

      final customSync = SupabaseSyncService(
        db: db,
        repository: repo,
        clientOverride: SupabaseClient(
          'https://mock.supabase.co',
          'dummy-key-xyz',
          httpClient: mockClient,
        ),
        documentsDirectoryProvider: () async => tempDir.path,
      );

      // 1. Pull inicial: metadado chega, mas download do áudio falha com 504
      final pullRes = await customSync.fetchRemoteChanges();
      expect(pullRes.successCount, greaterThanOrEqualTo(1));

      // Verifica que o registro de pendência foi gravado no AppKvStore
      final pendingKey =
          await (db.select(db.appKvStore)..where(
                (t) => t.key.equals('pending_audio_download_vn_pending_dl_1'),
              ))
              .getSingleOrNull();
      expect(pendingKey, isNotNull);

      // Nota de voz local ainda não possui caminho de áudio
      final noteBefore = await (db.select(
        db.voiceNotes,
      )..where((t) => t.id.equals('vn_pending_dl_1'))).getSingle();
      expect(noteBefore.audioFilePath, isNull);

      // 2. Conexão restabelecida: autoriza download e executa retryPendingMediaDownloads
      allowDownload = true;
      final recoveredCount = await customSync.retryPendingMediaDownloads();
      expect(recoveredCount, equals(1));

      // 3. Verifica que o arquivo físico existe e a pendência foi removida
      final noteAfter = await (db.select(
        db.voiceNotes,
      )..where((t) => t.id.equals('vn_pending_dl_1'))).getSingle();
      expect(noteAfter.audioFilePath, isNotNull);
      expect(File(noteAfter.audioFilePath!).existsSync(), isTrue);

      final pendingKeyAfter =
          await (db.select(db.appKvStore)..where(
                (t) => t.key.equals('pending_audio_download_vn_pending_dl_1'),
              ))
              .getSingleOrNull();
      expect(pendingKeyAfter, isNull);
    });

    test('8. Download de áudio Ticuna falha, registra pendência e retryPendingMediaDownloads recupera com sucesso', () async {
      final tempDir = Directory.systemTemp.createTempSync('ticuna_pending_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      bool allowDownload = false;
      bool deleteCalled = false;

      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/storage/v1/object/ticuna_audio') || path.contains('/storage/v1/object/voice_notes')) {
          if (request.method == 'DELETE') {
            deleteCalled = true;
            return mockJsonResponse(request, {'message': 'Deleted'});
          }
          if (path.contains('word_ticuna_dl_1_pronunciation.m4a')) {
            if (!allowDownload) {
              return http.Response('Storage unavailable', 503);
            } else {
              return mockBinaryResponse(
                request,
                utf8.encode('TICUNA_PRONUNCIATION_AUDIO_BYTES'),
                contentType: 'audio/m4a',
              );
            }
          }
        }
        if (path.contains('/rest/v1/ticuna_words')) {
          return mockJsonResponse(request, [
            {
              'id': 'word_ticuna_dl_1',
              'word': 'Duü\u0303',
              'translation': 'Pessoa',
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            }
          ], contentRange: '0-0/1');
        }
        return mockJsonResponse(request, []);
      });

      final customSync = SupabaseSyncService(
        db: db,
        repository: repo,
        clientOverride: SupabaseClient(
          'https://mock.supabase.co',
          'dummy-key-xyz',
          httpClient: mockClient,
        ),
        documentsDirectoryProvider: () async => tempDir.path,
      );

      final ticunaRepo = TicunaRepository(db);
      await ticunaRepo.getAllWords(); // Garante inicialização das tabelas no SQLite

      // 1. Pull inicial: metadado da palavra chega, mas download de áudio falha com 503
      final pullRes = await customSync.fetchRemoteChanges();
      expect(pullRes.successCount, greaterThanOrEqualTo(1));

      // Verifica pendência registrada no AppKvStore
      final pendingKey = await (db.select(db.appKvStore)
        ..where((t) => t.key.equals('pending_ticuna_audio_download_ticuna_words_word_ticuna_dl_1'))).getSingleOrNull();
      expect(pendingKey, isNotNull);

      // 2. Conexão restabelecida: autoriza download e recupera via retryPendingMediaDownloads
      allowDownload = true;
      final recovered = await customSync.retryPendingMediaDownloads();
      expect(recovered, equals(1));

      // Pendência deve ter sido consumida
      final pendingAfter = await (db.select(db.appKvStore)
        ..where((t) => t.key.equals('pending_ticuna_audio_download_ticuna_words_word_ticuna_dl_1'))).getSingleOrNull();
      expect(pendingAfter, isNull);

      // 3. Testa deleção de áudio com user folder prefix
      final deleted = await customSync.deleteTicunaAudio('word_ticuna_dl_1');
      expect(deleted, isTrue);
      expect(deleteCalled, isTrue);
    });
  });
}
