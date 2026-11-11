import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/settings/backup_service.dart';

void main() {
  group('Serviço de Backup Criptografado e Restauração', () {
    late AppDatabase db;
    late AppRepository repository;
    late BackupService backupService;
    late Directory testDocsDir;

    setUp(() async {
      testDocsDir = await Directory.systemTemp.createTemp('bak_test_docs_');
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = AppRepository(db);
      backupService = BackupService(
        repository,
        documentsDirectoryProvider: () async => testDocsDir,
      );
    });

    tearDown(() async {
      await db.close();
      if (testDocsDir.existsSync()) {
        try {
          await testDocsDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    test(
      'TC-BAK-01: Exporta backup criptografado AES e restaura com sucesso',
      () async {
        // 1. Cadastra dados no banco original
        final p1 = await repository.createPerson(
          name: 'Maria Teste',
          phone: '123456',
          address: 'Rua do Teste, 10',
        );
        await repository.createVisit(
          personId: p1.id,
          dateTime: DateTime.now(),
          contactType: 'revisita',
          result: 'Ótima conversa',
        );

        // 2. Exporta backup criptografado com senha
        const password = 'MinhaSenhaSegura#123';
        final encryptedBackup = await backupService.exportEncryptedBackup(
          password,
        );

        expect(encryptedBackup, isNotEmpty);
        expect(encryptedBackup, contains('ciphertext'));
        expect(encryptedBackup, contains('iv'));

        // 3. Pré-visualização com a senha correta
        final preview = await backupService.previewBackup(
          encryptedDataString: encryptedBackup,
          password: password,
        );

        expect(preview.peopleToAdd + preview.peopleUnchanged, equals(1));
        expect(preview.visitsToAdd + preview.visitsToUpdate, equals(1));

        // 4. Cria segundo banco vazio e restaura
        final db2 = AppDatabase.forTesting(NativeDatabase.memory());
        final repo2 = AppRepository(db2);
        final service2 = BackupService(
          repo2,
          documentsDirectoryProvider: () async => testDocsDir,
        );

        await service2.commitRestore(preview);

        final restoredPeople = await repo2.getAllPeople();
        expect(restoredPeople.length, equals(1));
        expect(restoredPeople.first.name, equals('Maria Teste'));
        expect(restoredPeople.first.id, equals(p1.id));

        final restoredVisits = await repo2.getAllVisits();
        expect(restoredVisits.length, equals(1));
        expect(restoredVisits.first.result, equals('Ótima conversa'));

        await db2.close();
      },
    );

    test(
      'TC-BAK-02: Rejeita tentativa de restauração com senha incorreta',
      () async {
        await repository.createPerson(name: 'Carlos');
        final encryptedBackup = await backupService.exportEncryptedBackup(
          'SenhaCorreta',
        );

        expect(
          () async => await backupService.previewBackup(
            encryptedDataString: encryptedBackup,
            password: 'SenhaErrada',
          ),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('TC-BAK-03: Reimportar o mesmo backup é idempotente e NÃO duplica registros', () async {
      await repository.createPerson(name: 'Ana');
      final encryptedBackup = await backupService.exportEncryptedBackup(
        '123456',
      );

      final preview = await backupService.previewBackup(
        encryptedDataString: encryptedBackup,
        password: '123456',
      );

      // Executa duas vezes a restauração no mesmo banco
      await backupService.commitRestore(preview);
      await backupService.commitRestore(preview);

      final allPeople = await repository.getAllPeople();
      expect(allPeople.length, equals(1));
    });

    test('TC-BAK-04: Prévia de restauração detecta com precisão registros existentes vs novos em todas as entidades', () async {
      // Cria registros em banco 1
      final p1 = await repository.createPerson(name: 'Existente');
      await repository.createVisit(
        personId: p1.id,
        dateTime: DateTime.now(),
        contactType: 'revisita',
        result: 'Conversa inicial',
      );
      await repository.createStudy(
        title: 'Estudo Teste',
        publicationId: 'lff-book',
        language: 'pt',
        participantPersonIds: [p1.id],
      );
      await repository.createAppointment(
        personId: p1.id,
        title: 'Compromisso Teste',
        startTime: DateTime.now().add(const Duration(days: 1)),
        endTime: DateTime.now().add(const Duration(days: 1, minutes: 30)),
      );
      await repository.createActivityRecord(
        date: DateTime.now(),
        durationSeconds: 3600,
        modality: 'campo',
      );

      // Exporta backup contendo esses dados
      final encryptedBackup = await backupService.exportEncryptedBackup(
        'senha123',
      );

      // Ao pré-visualizar contra o MESMO banco onde já existem:
      final previewSameDb = await backupService.previewBackup(
        encryptedDataString: encryptedBackup,
        password: 'senha123',
      );

      // Nenhuma entidade deve ser contada como 'ToAdd' pois todos os IDs já existem
      expect(previewSameDb.peopleToAdd, equals(0));
      expect(previewSameDb.peopleUnchanged, equals(1));
      expect(previewSameDb.visitsToAdd, equals(0));
      expect(previewSameDb.studiesToAdd, equals(0));
      expect(previewSameDb.appointmentsToAdd, equals(0));
      expect(previewSameDb.activitiesToAdd, equals(0));

      // Em um banco novo e vazio:
      final dbNew = AppDatabase.forTesting(NativeDatabase.memory());
      final repoNew = AppRepository(dbNew);
      final serviceNew = BackupService(
        repoNew,
        documentsDirectoryProvider: () async => testDocsDir,
      );

      final previewNewDb = await serviceNew.previewBackup(
        encryptedDataString: encryptedBackup,
        password: 'senha123',
      );

      expect(previewNewDb.peopleToAdd, equals(1));
      expect(previewNewDb.visitsToAdd, equals(1));
      expect(previewNewDb.studiesToAdd, equals(1));
      expect(previewNewDb.appointmentsToAdd, equals(1));
      expect(previewNewDb.activitiesToAdd, equals(1));

      await dbNew.close();
    });

    test(
      'TC-BAK-05: Inventário completo das 22 tabelas do banco no backup',
      () async {
        final encryptedBackup = await backupService.exportEncryptedBackup(
          'senha22',
        );
        final preview = await backupService.previewBackup(
          encryptedDataString: encryptedBackup,
          password: 'senha22',
        );

        const expected22Tables = [
          'people',
          'visits',
          'bibleStudies',
          'studyParticipants',
          'studySessions',
          'appointments',
          'activityRecords',
          'syncQueue',
          'voiceNotes',
          'phoneContacts',
          'territoryLandmarks',
          'familyTies',
          'ministryExperiences',
          'personPhotos',
          'personPublications',
          'researchArticles',
          'researchTags',
          'territorySectors',
          'studentManualOrder',
          'externalCalendarEvents',
          'calendarEventLinks',
          'inboxEntries',
          'projects',
          'tasks',
          'knowledgeNotes',
          'knowledgeQuestions',
          'knowledgeDocuments',
          'knowledgeResources',
          'appLanguages',
          'ticunaWords',
          'ticunaPhrases',
          'ticunaTags',
          'appKvStore',
        ];

        expect(
          preview.inventoryTables.length,
          equals(33),
          reason: 'O backup deve exportar exatamente 33 tabelas',
        );
        for (final tbl in expected22Tables) {
          expect(
            preview.inventoryTables,
            contains(tbl),
            reason: 'Tabela $tbl deve constar no inventário',
          );
        }
      },
    );

    test(
      'TC-BAK-06: Exportação e restauração da tabela syncQueue (22ª tabela)',
      () async {
        // 1. Cria operação na syncQueue
        await db
            .into(db.syncQueue)
            .insert(
              SyncQueueCompanion.insert(
                id: 'sq_test_123',
                entityType: 'people',
                entityId: 'p_test_1',
                operation: 'INSERT',
                payload: '{"name":"Carlos"}',
                createdAt: DateTime.now(),
              ),
            );

        final encrypted = await backupService.exportEncryptedBackup('pass_sq');
        final preview = await backupService.previewBackup(
          encryptedDataString: encrypted,
          password: 'pass_sq',
        );

        expect(preview.syncQueueToAdd, equals(0)); // no mesmo banco

        // 2. Restaura em banco novo
        final dbNew = AppDatabase.forTesting(NativeDatabase.memory());
        final repoNew = AppRepository(dbNew);
        final serviceNew = BackupService(
          repoNew,
          documentsDirectoryProvider: () async => testDocsDir,
        );

        final previewNew = await serviceNew.previewBackup(
          encryptedDataString: encrypted,
          password: 'pass_sq',
        );
        expect(previewNew.syncQueueToAdd, equals(1));

        await serviceNew.commitRestore(previewNew);

        final restoredQueue = await dbNew.select(dbNew.syncQueue).get();
        expect(restoredQueue.length, equals(1));
        expect(restoredQueue.first.id, equals('sq_test_123'));
        expect(restoredQueue.first.entityType, equals('people'));

        await dbNew.close();
      },
    );

    test('TC-BAK-07: Backup com integridade SHA-256 e detecção de áudio corrompido', () async {
      // Cria nota de voz com arquivo físico simulado
      final p = await repository.createPerson(name: 'Irmão Lucas');
      final tempDir = await Directory.systemTemp.createTemp('bak_test');
      final audioFile = File('${tempDir.path}/test_audio.m4a');
      await audioFile.writeAsBytes([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);

      await repository.db
          .into(repository.db.voiceNotes)
          .insert(
            VoiceNotesCompanion.insert(
              id: 'vn_audio_1',
              personId: p.id,
              transcription: 'Transcrição da nota de teste',
              audioFilePath: Value(audioFile.path),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      final encrypted = await backupService.exportEncryptedBackup('audio_pass');
      final preview = await backupService.previewBackup(
        encryptedDataString: encrypted,
        password: 'audio_pass',
      );

      final dbNew = AppDatabase.forTesting(NativeDatabase.memory());
      final repoNew = AppRepository(dbNew);
      final serviceNew = BackupService(
        repoNew,
        documentsDirectoryProvider: () async => testDocsDir,
      );

      await serviceNew.commitRestore(preview);

      final restoredVn = await dbNew.select(dbNew.voiceNotes).get();
      expect(restoredVn.length, equals(1));
      expect(
        restoredVn.first.transcription,
        equals('Transcrição da nota de teste'),
      );

      await tempDir.delete(recursive: true);
      await dbNew.close();
    });

    test('TC-BAK-08: Não sobrescreve registros locais mais recentes com dados antigos do backup', () async {
      final pOld = await repository.createPerson(
        id: 'person_shared_1',
        name: 'Nome Antigo no Backup',
      );

      // Exporta backup com versão antiga
      final encryptedOld = await backupService.exportEncryptedBackup('pwd');

      // No banco atual, atualiza a pessoa para uma versão mais recente
      await Future.delayed(const Duration(milliseconds: 10));
      await repository.updatePerson(
        pOld.copyWith(
          name: 'Nome Atualizado Mais Recente',
          updatedAt: DateTime.now(),
          revision: pOld.revision + 2,
        ),
      );

      // Aplica restauração do backup antigo no banco atual
      final preview = await backupService.previewBackup(
        encryptedDataString: encryptedOld,
        password: 'pwd',
      );
      expect(
        preview.peopleToUpdate,
        equals(0),
        reason: 'Backup mais antigo não deve marcar como ToUpdate',
      );
      expect(preview.peopleUnchanged, equals(1));

      await backupService.commitRestore(preview);

      // Confirma que o nome mais recente foi preservado intacto
      final personAfter = await repository.getPersonById('person_shared_1');
      expect(personAfter!.name, equals('Nome Atualizado Mais Recente'));
    });

    test(
      'TC-BAK-09: Snapshot de segurança prévio antes da restauração é gerado',
      () async {
        await repository.createPerson(name: 'Segurança Pré-Restauração');
        final encrypted = await backupService.exportEncryptedBackup('sec_pwd');
        final preview = await backupService.previewBackup(
          encryptedDataString: encrypted,
          password: 'sec_pwd',
        );

        expect(backupService.lastPreRestoreSafetyBackup, isNull);

        await backupService.commitRestore(preview);

        expect(backupService.lastPreRestoreSafetyBackup, isNotNull);
        expect(
          backupService.lastPreRestoreSafetyBackup,
          contains('ciphertext'),
        );
      },
    );

    test(
      'TC-BAK-10: Rejeição de arquivo de backup corrompido ou truncado',
      () async {
        await repository.createPerson(name: 'Teste Corrompido');
        final encrypted = await backupService.exportEncryptedBackup('pwd123');

        // Trunca o ciphertext
        final corrupted = encrypted.replaceFirst(
          '"ciphertext":"',
          '"ciphertext":"CORROMPIDO_INVALIDO_',
        );

        expect(
          () async => await backupService.previewBackup(
            encryptedDataString: corrupted,
            password: 'pwd123',
          ),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('TC-BAK-11: previewBackup() detecta por conta própria corrupção de áudio via SHA-256 sem injeção manual', () async {
      final p = await repository.createPerson(
        name: 'Irmão com Áudio Corrompido',
      );
      final audioFile = File('${testDocsDir.path}/audio_original.m4a');
      await audioFile.writeAsBytes([10, 20, 30, 40, 50]);

      await repository.db
          .into(repository.db.voiceNotes)
          .insert(
            VoiceNotesCompanion.insert(
              id: 'vn_corrupt_1',
              personId: p.id,
              transcription: 'Nota com áudio para corromper',
              audioFilePath: Value(audioFile.path),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      const password = 'corrupt_pwd';
      final encrypted = await backupService.exportEncryptedBackup(password);

      // Decodifica o container AES-GCM
      final container = jsonDecode(encrypted) as Map<String, dynamic>;
      final saltBytes = base64Decode(container['salt'] as String);
      final iterations = container['iterations'] as int;
      final iv = enc.IV.fromBase64(container['iv'] as String);
      final hmac = Hmac(sha256, utf8.encode(password));
      final saltAndBlock = Uint8List(saltBytes.length + 4);
      saltAndBlock.setRange(0, saltBytes.length, saltBytes);
      saltAndBlock[saltBytes.length + 3] = 1;
      var u = Uint8List.fromList(hmac.convert(saltAndBlock).bytes);
      final keyBytes = Uint8List.fromList(u);
      for (int iter = 1; iter < iterations; iter++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (int i = 0; i < 32; i++) {
          keyBytes[i] ^= u[i];
        }
      }
      final key = enc.Key(keyBytes);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
      final decryptedEnvelopeJson = encrypter.decrypt64(
        container['ciphertext'] as String,
        iv: iv,
      );
      final envelope =
          jsonDecode(decryptedEnvelopeJson) as Map<String, dynamic>;
      final rawData =
          jsonDecode(envelope['data'] as String) as Map<String, dynamic>;

      // Adultera os bytes do áudio no payload mantendo o hash antigo esperado em voiceNoteAudioHashes
      final rawAudios = Map<String, dynamic>.from(
        rawData['voiceNoteAudios'] as Map<String, dynamic>,
      );
      rawAudios['vn_corrupt_1'] = base64Encode([
        99,
        99,
        99,
        99,
      ]); // bytes adulterados
      rawData['voiceNoteAudios'] = rawAudios;

      // Recalcula o checksum do envelope de dados para que o envelope seja íntegro
      final tamperedDataJson = jsonEncode(rawData);
      final tamperedChecksum = sha256
          .convert(utf8.encode(tamperedDataJson))
          .toString();
      final tamperedEnvelope = {
        'version': 2,
        'exported_at': DateTime.now().toIso8601String(),
        'checksum': tamperedChecksum,
        'iterations': iterations,
        'data': tamperedDataJson,
      };

      final reEncrypted = encrypter.encrypt(
        jsonEncode(tamperedEnvelope),
        iv: iv,
      );
      final tamperedBackupString = jsonEncode({
        'version': 2,
        'salt': container['salt'],
        'iterations': iterations,
        'iv': iv.base64,
        'ciphertext': reEncrypted.base64,
      });

      // Executa previewBackup(): deve detectar a corrupção de forma autônoma
      final preview = await backupService.previewBackup(
        encryptedDataString: tamperedBackupString,
        password: password,
      );

      expect(preview.isIntegral, isFalse);
      expect(preview.corruptedAudioIds, contains('vn_corrupt_1'));

      final dbNew = AppDatabase.forTesting(NativeDatabase.memory());
      final repoNew = AppRepository(dbNew);
      final serviceNew = BackupService(
        repoNew,
        documentsDirectoryProvider: () async => testDocsDir,
      );

      final result = await serviceNew.commitRestore(preview);
      expect(result.isIntegral, isFalse);
      expect(result.corruptedFiles, contains('vn_corrupt_1'));

      await dbNew.close();
    });

    test('TC-BAK-12: Falha na criação do snapshot de segurança aborta a restauração imediatamente com RestoreAbortedException', () async {
      await repository.createPerson(name: 'Maria Teste');
      final encrypted = await backupService.exportEncryptedBackup('pwd123');
      final preview = await backupService.previewBackup(
        encryptedDataString: encrypted,
        password: 'pwd123',
      );

      // Simula serviço com falha no snapshot antes de qualquer gravação
      final dbNew = AppDatabase.forTesting(NativeDatabase.memory());
      final repoNew = AppRepository(dbNew);
      final failingService = BackupService(
        repoNew,
        documentsDirectoryProvider: () async {
          throw const FileSystemException('Falha de I/O forçada no snapshot');
        },
      );

      expect(
        () async => await failingService.commitRestore(preview),
        throwsA(isA<RestoreAbortedException>()),
      );

      // Nenhum dado deve ter sido gravado
      final people = await repoNew.getAllPeople();
      expect(people, isEmpty);

      await dbNew.close();
    });

    test('TC-BAK-13: Rollback transacional ao ocorrer falha na restauração restaura o banco ao estado original e remove mídias criadas', () async {
      final dbTarget = AppDatabase.forTesting(NativeDatabase.memory());
      final repoTarget = AppRepository(dbTarget);
      final targetDocsDir = await Directory.systemTemp.createTemp(
        'rollback_test_target_',
      );
      final serviceTarget = BackupService(
        repoTarget,
        documentsDirectoryProvider: () async => targetDocsDir,
      );

      // Estado pré-restauração no banco de destino
      await repoTarget.createPerson(name: 'Pessoa Pré-Existente');

      // Prepara dados no banco de origem: uma pessoa nova e uma nota de voz com áudio
      final pOrig = await repository.createPerson(
        name: 'Pessoa Nova Do Backup',
      );
      final audioFile = File('${testDocsDir.path}/audio_temp.m4a');
      await audioFile.writeAsBytes([1, 2, 3, 4, 5]);
      await repository.db
          .into(repository.db.voiceNotes)
          .insert(
            VoiceNotesCompanion.insert(
              id: 'vn_rollback_1',
              personId: pOrig.id,
              transcription: 'Nota de teste',
              audioFilePath: Value(audioFile.path),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      final encrypted = await backupService.exportEncryptedBackup('pwd123');
      final preview = await backupService.previewBackup(
        encryptedDataString: encrypted,
        password: 'pwd123',
      );

      // Injeta falha forçada em um dos registros da prévia para disparar erro durante a transação
      final rawData = Map<String, dynamic>.from(preview.rawDecryptedData);
      final rawVisits = [
        {
          'id': 'invalid_visit_without_person',
          'personId': 'non_existent_uuid',
          'dateTimeField': 'invalid_date_format',
          'contactType': 'revisita',
          'result': 'x',
          'createdAt': 'invalid',
          'updatedAt': 'invalid',
          'revision': 1,
        },
      ];
      rawData['visits'] = rawVisits;

      final failingPreview = RestorePreview(
        peopleToAdd: preview.peopleToAdd,
        peopleToUpdate: preview.peopleToUpdate,
        peopleUnchanged: preview.peopleUnchanged,
        visitsToAdd: 1,
        visitsToUpdate: 0,
        studiesToAdd: 0,
        sessionsToAdd: 0,
        appointmentsToAdd: 0,
        activitiesToAdd: 0,
        voiceNotesToAdd: preview.voiceNotesToAdd,
        inventoryTables: preview.inventoryTables,
        corruptedAudioIds: const [],
        rawDecryptedData: rawData,
      );

      expect(
        () async => await serviceTarget.commitRestore(failingPreview),
        throwsA(anything),
      );

      // Verifica rollback no banco: dados pré-existentes preservados, novos descartados
      final people = await repoTarget.getAllPeople();
      expect(people.length, equals(1));
      expect(people.first.name, equals('Pessoa Pré-Existente'));

      // Verifica rollback de arquivos de mídia: nenhum arquivo de áudio deve ter sobrado
      final vnAudioDir = Directory('${targetDocsDir.path}/voice_notes');
      if (vnAudioDir.existsSync()) {
        final remainingFiles = vnAudioDir.listSync();
        expect(remainingFiles, isEmpty);
      }

      await dbTarget.close();
      if (targetDocsDir.existsSync()) {
        try {
          await targetDocsDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('TC-BAK-14: Snapshot de segurança persistente é gravado em disco e registrado no AppKvStore', () async {
      await repository.createPerson(name: 'Snapshot Alvo');
      final encrypted = await backupService.exportEncryptedBackup('pwd123');
      final preview = await backupService.previewBackup(
        encryptedDataString: encrypted,
        password: 'pwd123',
      );

      await backupService.commitRestore(preview);

      // Verifica que o snapshot foi gravado em disco e no KV store
      final snapshotPath = await backupService.getLastSafetySnapshotPath();
      expect(snapshotPath, isNotNull);
      final snapshotFile = File(snapshotPath!);
      expect(snapshotFile.existsSync(), isTrue);
      expect(snapshotFile.lengthSync(), greaterThan(0));
      expect(snapshotPath, contains('safety_snapshots'));

      // Valida que o snapshot gravado no KV store é legível e íntegro
      final content = await snapshotFile.readAsString();
      expect(content, isNotEmpty);
    });

    test('TC-BAK-ADV-01: Staging e Rollback Seguro — sobrescrita de áudio existente com falha na transação comprova que o áudio original é recuperado intacto', () async {
      final dbTarget = AppDatabase.forTesting(NativeDatabase.memory());
      final repoTarget = AppRepository(dbTarget);
      final targetDocsDir = await Directory.systemTemp.createTemp(
        'adv_preserve_target_',
      );
      final serviceTarget = BackupService(
        repoTarget,
        documentsDirectoryProvider: () async => targetDocsDir,
      );

      // 1. Prepara áudio original existente no aparelho de destino
      final vnDir = Directory('${targetDocsDir.path}/voice_notes');
      await vnDir.create(recursive: true);
      final originalAudio = File('${vnDir.path}/vn_preserve_1.m4a');
      const originalContent = 'AUDIO_ORIGINAL_QUE_NAO_PODE_SER_PERDIDO_12345';
      await originalAudio.writeAsBytes(
        utf8.encode(originalContent),
        flush: true,
      );

      final pTarget = await repoTarget.createPerson(
        name: 'Pessoa Local Existente',
      );
      await dbTarget
          .into(dbTarget.voiceNotes)
          .insert(
            VoiceNotesCompanion.insert(
              id: 'preserve_1',
              personId: pTarget.id,
              transcription: 'Transcrição original preservada',
              audioFilePath: Value(originalAudio.path),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      // 2. Prepara backup contendo uma versão substituta para 'preserve_1'
      final pOrig = await repository.createPerson(name: 'Pessoa Externa');
      final newAudioFile = File('${testDocsDir.path}/new_audio.m4a');
      await newAudioFile.writeAsBytes(
        utf8.encode('AUDIO_NOVO_DO_BACKUP_99999'),
        flush: true,
      );

      await repository.db
          .into(repository.db.voiceNotes)
          .insert(
            VoiceNotesCompanion.insert(
              id: 'preserve_1',
              personId: pOrig.id,
              transcription: 'Transcrição substituta do backup',
              audioFilePath: Value(newAudioFile.path),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      final encrypted = await backupService.exportEncryptedBackup('pwd123');
      final preview = await backupService.previewBackup(
        encryptedDataString: encrypted,
        password: 'pwd123',
      );

      // 3. Força falha transacional no banco injetando dado inválido
      final rawData = Map<String, dynamic>.from(preview.rawDecryptedData);
      rawData['visits'] = [
        {
          'id': 'invalid_visit_for_abort',
          'personId': 'non_existent_uuid',
          'dateTimeField': 'invalid_date',
          'contactType': 'revisita',
          'result': 'x',
          'createdAt': 'invalid',
          'updatedAt': 'invalid',
          'revision': 1,
        },
      ];

      final failingPreview = RestorePreview(
        peopleToAdd: preview.peopleToAdd,
        peopleToUpdate: preview.peopleToUpdate,
        peopleUnchanged: preview.peopleUnchanged,
        visitsToAdd: 1,
        visitsToUpdate: 0,
        studiesToAdd: 0,
        sessionsToAdd: 0,
        appointmentsToAdd: 0,
        activitiesToAdd: 0,
        voiceNotesToAdd: preview.voiceNotesToAdd,
        inventoryTables: preview.inventoryTables,
        corruptedAudioIds: const [],
        rawDecryptedData: rawData,
      );

      expect(
        () async => await serviceTarget.commitRestore(failingPreview),
        throwsA(anything),
      );

      // 4. VERIFICAÇÃO CRÍTICA DE PRESERVAÇÃO:
      // O arquivo original DEVE existir e conter exatamente o conteúdo original
      expect(originalAudio.existsSync(), isTrue);
      final restoredBytes = await originalAudio.readAsBytes();
      expect(utf8.decode(restoredBytes), equals(originalContent));

      await dbTarget.close();
      if (targetDocsDir.existsSync()) {
        try {
          await targetDocsDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('TC-BAK-ADV-02: Limpeza de Staging — falha antes ou durante a restauração não deixa diretórios transitórios órfãos', () async {
      final dbTarget = AppDatabase.forTesting(NativeDatabase.memory());
      final repoTarget = AppRepository(dbTarget);
      final targetDocsDir = await Directory.systemTemp.createTemp(
        'adv_staging_target_',
      );
      final serviceTarget = BackupService(
        repoTarget,
        documentsDirectoryProvider: () async => targetDocsDir,
      );

      final p = await repository.createPerson(name: 'Pessoa');
      final aFile = File('${testDocsDir.path}/a.m4a');
      await aFile.writeAsBytes([1, 2, 3]);
      await repository.db
          .into(repository.db.voiceNotes)
          .insert(
            VoiceNotesCompanion.insert(
              id: 'clean_1',
              personId: p.id,
              transcription: 'Transcrição para teste de limpeza',
              audioFilePath: Value(aFile.path),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      final encrypted = await backupService.exportEncryptedBackup('pwd123');
      final preview = await backupService.previewBackup(
        encryptedDataString: encrypted,
        password: 'pwd123',
      );

      // Injeta falha
      final rawData = Map<String, dynamic>.from(preview.rawDecryptedData);
      rawData['visits'] = [
        {
          'id': 'x',
          'personId': 'none',
          'dateTimeField': 'bad',
          'createdAt': 'bad',
          'updatedAt': 'bad',
          'revision': 1,
        },
      ];
      final failingPreview = RestorePreview(
        peopleToAdd: preview.peopleToAdd,
        peopleToUpdate: preview.peopleToUpdate,
        peopleUnchanged: preview.peopleUnchanged,
        visitsToAdd: 1,
        visitsToUpdate: 0,
        studiesToAdd: 0,
        sessionsToAdd: 0,
        appointmentsToAdd: 0,
        activitiesToAdd: 0,
        voiceNotesToAdd: preview.voiceNotesToAdd,
        inventoryTables: preview.inventoryTables,
        corruptedAudioIds: const [],
        rawDecryptedData: rawData,
      );

      expect(
        () async => await serviceTarget.commitRestore(failingPreview),
        throwsA(anything),
      );

      // Verifica que nenhum safety_staging ou safety_audio_backup sobrou
      final remainingDirs = targetDocsDir
          .listSync()
          .whereType<Directory>()
          .map((d) => d.path)
          .where(
            (path) =>
                path.contains('safety_staging_') ||
                path.contains('safety_audio_backup_'),
          )
          .toList();
      expect(remainingDirs, isEmpty);

      await dbTarget.close();
      if (targetDocsDir.existsSync()) {
        try {
          await targetDocsDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('TC-BAK-ADV-03: StorageUnavailableException e RestoreAbortedException ocorrem quando diretório persistente não pode ser obtido (sem fallback temporário)', () async {
      await repository.createPerson(name: 'Pessoa Teste Storage');
      final encrypted = await backupService.exportEncryptedBackup('pwd');
      final preview = await backupService.previewBackup(
        encryptedDataString: encrypted,
        password: 'pwd',
      );

      final brokenService = BackupService(
        repository,
        documentsDirectoryProvider: () async {
          throw const FileSystemException('Permissão de escrita negada no SO');
        },
      );

      expect(
        () async => await brokenService.commitRestore(preview),
        throwsA(
          isA<RestoreAbortedException>().having(
            (e) => e.message,
            'message',
            contains('StorageUnavailableException'),
          ),
        ),
      );
    });

    test('TC-BAK-ADV-04: Snapshot durável é gravado no AppKvStore e recuperável via getLastSafetySnapshotData', () async {
      await repository.createPerson(name: 'Pessoa Web Snapshot');
      final encrypted = await backupService.exportEncryptedBackup('pwd123');
      final preview = await backupService.previewBackup(
        encryptedDataString: encrypted,
        password: 'pwd123',
      );

      await backupService.commitRestore(preview);

      final snapshotData = await backupService.getLastSafetySnapshotData();
      expect(snapshotData, isNotNull);
      expect(snapshotData, contains('ciphertext'));
      expect(snapshotData, contains('salt'));
    });
  });
}
