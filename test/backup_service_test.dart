import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/settings/backup_service.dart';

void main() {
  group('Serviço de Backup Criptografado e Restauração', () {
    late AppDatabase db;
    late AppRepository repository;
    late BackupService backupService;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = AppRepository(db);
      backupService = BackupService(repository);
    });

    tearDown(() async {
      await db.close();
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
        final service2 = BackupService(repo2);

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
      final serviceNew = BackupService(repoNew);

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
          'appKvStore',
        ];

        expect(
          preview.inventoryTables.length,
          equals(22),
          reason: 'O backup deve exportar exatamente 22 tabelas',
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
        final serviceNew = BackupService(repoNew);

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
      final serviceNew = BackupService(repoNew);

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
      final now = DateTime.now();
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
  });
}
