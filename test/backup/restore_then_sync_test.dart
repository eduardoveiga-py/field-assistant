import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/settings/backup_service.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:ministerio_pessoal/ticuna/ticuna_repository.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

http.Response _mockJsonResponse(http.Request request, Object body) {
  return http.Response(
    jsonEncode(body),
    200,
    request: request,
    headers: {
      'content-type': 'application/json',
      'content-range': '*/0',
    },
  );
}

String _buildLegacyV1BackupContainer({
  required String password,
  required Map<String, dynamic> rawData,
}) {
  final rawJson = jsonEncode(rawData);
  final checksum = sha256.convert(utf8.encode(rawJson)).toString();
  final envelopeJson = jsonEncode({
    'version': 1,
    'exported_at': DateTime.utc(2026, 1, 10, 12, 0).toIso8601String(),
    'checksum': checksum,
    'data': rawJson,
  });

  final keyDigest = sha256.convert(utf8.encode('${password}ministerio_pessoal_salt_v1'));
  final key = enc.Key(Uint8List.fromList(keyDigest.bytes));
  final iv = enc.IV.fromSecureRandom(16);
  final encrypter = enc.Encrypter(enc.AES(key));
  final encrypted = encrypter.encrypt(envelopeJson, iv: iv);

  return jsonEncode({
    'version': 1,
    'iv': iv.base64,
    'ciphertext': encrypted.base64,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('C5 Restore-then-Sync, A2 Key/Legacy Guard & F10 Full Backup Tables/Docs', () {
    late AppDatabase sourceDb;
    late AppRepository sourceRepo;
    late BackupService sourceBackup;
    late Directory sourceDocsDir;

    late AppDatabase targetDb;
    late AppRepository targetRepo;
    late BackupService targetBackup;
    late Directory targetDocsDir;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      sourceDocsDir = await Directory.systemTemp.createTemp('bak_src_');
      targetDocsDir = await Directory.systemTemp.createTemp('bak_dst_');

      sourceDb = AppDatabase.forTesting(NativeDatabase.memory());
      sourceRepo = AppRepository(sourceDb);
      sourceBackup = BackupService(
        sourceRepo,
        documentsDirectoryProvider: () async => sourceDocsDir,
      );

      targetDb = AppDatabase.forTesting(NativeDatabase.memory());
      targetRepo = AppRepository(targetDb);
      targetBackup = BackupService(
        targetRepo,
        documentsDirectoryProvider: () async => targetDocsDir,
      );
    });

    tearDown(() async {
      await sourceDb.close();
      await targetDb.close();
      if (await sourceDocsDir.exists()) {
        await sourceDocsDir.delete(recursive: true);
      }
      if (await targetDocsDir.exists()) {
        await targetDocsDir.delete(recursive: true);
      }
    });

    test(
      'C5 + F10: Backup exporta/restaura app_languages, ticuna_words/phrases/tags e binários de knowledge_documents, reconstituindo sync_queue com datas ISO válidas',
      () async {
        final now = DateTime.utc(2026, 11, 5, 14, 30);

        // 1. Dados relacionais básicos
        final person = await sourceRepo.createPerson(
          name: 'Mateus Ribeiro',
          status: 'estudo',
          firstContactAt: now,
        );
        final study = await sourceRepo.createStudy(
          title: 'Estudo de Mateus',
          publicationId: 'lff-book',
          language: 'pt',
          participantPersonIds: [person.id],
          primaryParticipantId: person.id,
        );
        await sourceRepo.createAppointment(
          personId: person.id,
          studyId: study.id,
          title: 'Sessão de Campo',
          startTime: now.add(const Duration(days: 1)),
          endTime: now.add(const Duration(days: 1, hours: 1)),
          durationMinutes: 60,
          status: 'confirmado',
        );

        // 2. Idioma customizado em app_languages
        await sourceDb.into(sourceDb.appLanguages).insert(
          AppLanguagesCompanion.insert(
            id: 'yrl_custom',
            name: 'Nheengatu',
            code: 'yrl',
            symbol: '🦜',
            diacritics: const drift.Value('["ã","õ"]'),
            isDefault: const drift.Value(false),
            createdAt: now,
            updatedAt: now,
          ),
        );

        // 3. Ticuna (palavras, frases e tags)
        final sourceTicuna = TicunaRepository(sourceDb);
        await sourceTicuna.addWord(
          word: 'Ĩxã_Backup',
          translation: 'Água limpa teste',
          languageId: 'tca',
          tags: ['BackupTag'],
        );
        await sourceDb.customStatement(
          '''
          INSERT OR REPLACE INTO ticuna_tags (id, name, created_at)
          VALUES (?, ?, ?)
          ''',
          ['tag_bak_1', 'CampoBackupTag', now.toIso8601String()],
        );
        await sourceDb.customStatement(
          '''
          INSERT OR REPLACE INTO ticuna_phrases (
            id, phrase, translation, category, phonetics, notes, tags,
            is_favorite, audio_path, audio_duration_seconds, language_id, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            'phrase_bak_1',
            'Tamaü rü wena',
            'Bom dia amigo',
            'Saudações',
            'ta-ma-ü',
            'Nota backup',
            '["Saudações"]',
            1,
            null,
            null,
            'tca',
            now.toIso8601String(),
            now.toIso8601String(),
          ],
        );

        // 4. Documento de conhecimento com binário real em disco
        final docFile = File(p.join(sourceDocsDir.path, 'folheto_estudo.pdf'));
        final docBytes = utf8.encode('%PDF-1.4\n1 0 obj<<>>endobj\n%%EOF');
        await docFile.writeAsBytes(docBytes);
        await sourceDb.into(sourceDb.knowledgeDocuments).insert(
          KnowledgeDocumentsCompanion.insert(
            id: 'kdoc_bak_1',
            title: 'Folheto Digital',
            fileName: 'folheto_estudo.pdf',
            fileType: 'pdf',
            fileSize: docBytes.length,
            filePath: docFile.path,
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Exporta da origem e restaura no destino limpo
        const pwd = 'BackupStrongPassword#2026';
        final encrypted = await sourceBackup.exportEncryptedBackup(pwd, iterations: 1000);
        final preview = await targetBackup.previewBackup(
          encryptedDataString: encrypted,
          password: pwd,
        );

        expect(preview.appLanguagesToAdd, greaterThanOrEqualTo(1));
        expect(preview.ticunaWordsToAdd, greaterThanOrEqualTo(1));
        expect(preview.ticunaPhrasesToAdd, greaterThanOrEqualTo(1));
        expect(preview.ticunaTagsToAdd, greaterThanOrEqualTo(1));
        expect(preview.knowledgeDocumentsToAdd, equals(1));

        final restoreRes = await targetBackup.commitRestore(preview);
        expect(restoreRes.isIntegral, isTrue);

        // Verifica idioma customizado restaurado
        final restoredLang = await (targetDb.select(targetDb.appLanguages)
              ..where((t) => t.id.equals('yrl_custom')))
            .getSingleOrNull();
        expect(restoredLang, isNotNull);
        expect(restoredLang!.name, equals('Nheengatu'));

        // Verifica Ticuna restaurado (considerando normalização NFC de Ĩxã_Backup)
        final restoredWords = await targetDb.customSelect(
          "SELECT * FROM ticuna_words WHERE translation = 'Água limpa teste'",
        ).get();
        final restoredPhrases = await targetDb.customSelect(
          "SELECT * FROM ticuna_phrases WHERE id = 'phrase_bak_1'",
        ).get();
        final restoredTags = await targetDb.customSelect(
          "SELECT * FROM ticuna_tags WHERE id = 'tag_bak_1'",
        ).get();
        expect(restoredWords, isNotEmpty);
        expect(restoredWords.single.data['word'].toString(), contains('Backup'));
        expect(restoredPhrases.single.data['phrase'], equals('Tamaü rü wena'));
        expect(restoredTags.single.data['name'], equals('CampoBackupTag'));

        // Verifica documento e bytes restaurados no novo diretório do dispositivo destino
        final restoredDoc = await (targetDb.select(targetDb.knowledgeDocuments)
              ..where((t) => t.id.equals('kdoc_bak_1')))
            .getSingle();
        expect(restoredDoc.filePath, startsWith(targetDocsDir.path));
        expect(File(restoredDoc.filePath).existsSync(), isTrue);
        expect(await File(restoredDoc.filePath).readAsBytes(), equals(docBytes));

        // C5: Valida que a fila sync_queue reconstituída possui datas ISO-8601 (jamais inteiros/epoch)
        // e sincroniza com Supabase mockado sem falhas
        final targetQueue = await targetDb.select(targetDb.syncQueue).get();
        expect(targetQueue, isNotEmpty);
        for (final q in targetQueue) {
          final decoded = jsonDecode(q.payload) as Map<String, dynamic>;
          if (decoded.containsKey('createdAt')) {
            expect(decoded['createdAt'], isA<String>());
            expect(DateTime.tryParse(decoded['createdAt'] as String), isNotNull);
          }
          if (decoded.containsKey('updatedAt')) {
            expect(decoded['updatedAt'], isA<String>());
            expect(DateTime.tryParse(decoded['updatedAt'] as String), isNotNull);
          }
        }

        final pushedTables = <String, Map<String, dynamic>>{};
        final mockClient = MockClient((request) async {
          final path = request.url.path;
          if (request.method == 'POST' && path.endsWith('/rest/v1/rpc/sync_upsert_if_unchanged')) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final table = body['p_table'] as String;
            final payload = Map<String, dynamic>.from(body['p_payload'] as Map);
            pushedTables[table] = payload;
            return _mockJsonResponse(request, {'success': true});
          }
          if (path.contains('/storage/v1/object/knowledge_vault')) {
            return _mockJsonResponse(request, {'Key': 'ok'});
          }
          return _mockJsonResponse(request, []);
        });

        final syncSvc = SupabaseSyncService(
          db: targetDb,
          repository: targetRepo,
          clientOverride: SupabaseClient(
            'https://mock.supabase.co',
            'dummy-key',
            httpClient: mockClient,
          ),
          documentsDirectoryProvider: () async => targetDocsDir.path,
        );
        addTearDown(syncSvc.dispose);

        final syncRes = await syncSvc.processQueue();
        expect(syncRes.failureCount, equals(0));
        expect(syncRes.successCount, equals(targetQueue.length));
        expect(pushedTables['people']?['created_at'], isA<String>());
        expect(pushedTables['appointments']?['start_time'], isA<String>());
      },
    );

    test(
      'A2: Rejeita backup legado v1 por padrão (LegacyBackupNotAllowedException) e permite somente com allowLegacyV1=true',
      () async {
        final now = DateTime.utc(2026, 2, 1, 9, 0);
        const pwd = 'legacy_password_123';
        final legacyContainer = _buildLegacyV1BackupContainer(
          password: pwd,
          rawData: {
            'schemaVersion': 1,
            'people': [
              {
                'id': 'p_legacy_v1',
                'name': 'Irmão Legado v1',
                'status': 'revisita',
                'tags': '[]',
                'firstContactAt': now.toIso8601String(),
                'createdAt': now.toIso8601String(),
                'updatedAt': now.toIso8601String(),
                'revision': 1,
              },
            ],
          },
        );

        await expectLater(
          () => targetBackup.previewBackup(
            encryptedDataString: legacyContainer,
            password: pwd,
          ),
          throwsA(isA<LegacyBackupNotAllowedException>()),
        );

        final allowedPreview = await targetBackup.previewBackup(
          encryptedDataString: legacyContainer,
          password: pwd,
          allowLegacyV1: true,
        );
        expect(allowedPreview.peopleToAdd, equals(1));

        await targetBackup.commitRestore(allowedPreview);
        final people = await targetRepo.getAllPeople();
        expect(people.map((p) => p.name), contains('Irmão Legado v1'));
      },
    );

    test(
      'A2: Chave de backup silencioso é gravada apenas em FlutterSecureStorage e removida de app_kv_store',
      () async {
        // Semeia chave legada insegura no SQLite para validar migração/expurgo
        await sourceDb.into(sourceDb.appKvStore).insert(
          AppKvStoreCompanion.insert(
            key: 'device_silent_backup_secret',
            value: 'legacy_insecure_secret_value',
            updatedAt: drift.Value(DateTime.now()),
          ),
        );

        final ran = await sourceBackup.performSilentBackupIfNeeded(force: true);
        expect(ran, isTrue);

        // Chave NUNCA pode permanecer em app_kv_store
        final kvCheck = await (sourceDb.select(sourceDb.appKvStore)
              ..where((t) => t.key.equals('device_silent_backup_secret')))
            .getSingleOrNull();
        expect(kvCheck, isNull);

        // Deve estar protegida em FlutterSecureStorage
        const storage = FlutterSecureStorage();
        final secretInSecureStorage = await storage.read(
          key: 'device_silent_backup_secret',
        );
        expect(secretInSecureStorage, isNotNull);
        expect(secretInSecureStorage, equals('legacy_insecure_secret_value'));

        final bakFile = File(
          p.join(sourceDocsDir.path, 'backups', 'silent_backup.bak'),
        );
        expect(bakFile.existsSync(), isTrue);
      },
    );
    test('backup silencioso não registra sucesso quando diretório falha', () async {
      final unavailable = BackupService(sourceRepo,
        documentsDirectoryProvider: () async => throw const StorageUnavailableException('indisponível'));
      expect(await unavailable.performSilentBackupIfNeeded(force: true), isFalse);
      expect(await unavailable.getLastSilentBackupDate(), isNull);
      expect(await File(p.join(sourceDocsDir.path, 'backups', 'silent_backup.bak')).exists(), isFalse);
    });

    test('falha em novo backup conserva arquivo anterior e data anterior', () async {
      expect(await sourceBackup.performSilentBackupIfNeeded(force: true), isTrue);
      final file = File(p.join(sourceDocsDir.path, 'backups', 'silent_backup.bak'));
      final before = await file.readAsBytes();
      final timestamp = await sourceBackup.getLastSilentBackupDate();
      final unavailable = BackupService(sourceRepo,
        documentsDirectoryProvider: () async => throw const StorageUnavailableException('indisponível'));
      expect(await unavailable.performSilentBackupIfNeeded(force: true), isFalse);
      expect(await file.readAsBytes(), before);
      expect(await unavailable.getLastSilentBackupDate(), timestamp);
    });
  });
}
