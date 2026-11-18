import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/settings/backup_service.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('FA-BAK-01: Testes adversariais de Backup/Restore', () {
    late AppDatabase srcDb;
    late AppRepository srcRepo;
    late BackupService srcBackup;
    late Directory srcDir;

    late AppDatabase dstDb;
    late AppRepository dstRepo;
    late BackupService dstBackup;
    late Directory dstDir;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      srcDir = await Directory.systemTemp.createTemp('fa_bak_adv_src_');
      dstDir = await Directory.systemTemp.createTemp('fa_bak_adv_dst_');

      srcDb = AppDatabase.forTesting(NativeDatabase.memory());
      srcRepo = AppRepository(srcDb);
      srcBackup = BackupService(
        srcRepo,
        documentsDirectoryProvider: () async => srcDir,
      );

      dstDb = AppDatabase.forTesting(NativeDatabase.memory());
      dstRepo = AppRepository(dstDb);
      dstBackup = BackupService(
        dstRepo,
        documentsDirectoryProvider: () async => dstDir,
      );
    });

    tearDown(() async {
      await srcDb.close();
      await dstDb.close();
      if (await srcDir.exists()) await srcDir.delete(recursive: true);
      if (await dstDir.exists()) await dstDir.delete(recursive: true);
    });

    test('rejeita senha incorreta em backup v2 e v3', () async {
      await srcRepo.createPerson(name: 'Pessoa Teste');
      final exported = await srcBackup.exportEncryptedBackup(
        'SenhaCorreta#2026',
        iterations: 1000,
      );

      await expectLater(
        () => dstBackup.previewBackup(
          encryptedDataString: exported,
          password: 'SenhaErrada#2026',
        ),
        throwsFormatException,
      );
    });

    test(
      'rejeita arquivo de backup corrompido (bit flip no ciphertext GCM)',
      () async {
        await srcRepo.createPerson(name: 'Pessoa Integridade');
        final exported = await srcBackup.exportEncryptedBackup(
          'SenhaForte#2026',
          iterations: 1000,
        );
        final map = jsonDecode(exported) as Map<String, dynamic>;
        final cipherBytes = base64Decode(map['ciphertext'] as String);
        cipherBytes[cipherBytes.length ~/ 2] ^= 0xFF;
        map['ciphertext'] = base64Encode(cipherBytes);

        await expectLater(
          () => dstBackup.previewBackup(
            encryptedDataString: jsonEncode(map),
            password: 'SenhaForte#2026',
          ),
          throwsFormatException,
        );
      },
    );

    test('rejeita arquivo truncado e JSON malformado', () async {
      await srcRepo.createPerson(name: 'Pessoa Truncada');
      final exported = await srcBackup.exportEncryptedBackup(
        'SenhaForte#2026',
        iterations: 1000,
      );
      final truncated = exported.substring(0, exported.length ~/ 2);

      await expectLater(
        () => dstBackup.previewBackup(
          encryptedDataString: truncated,
          password: 'SenhaForte#2026',
        ),
        throwsFormatException,
      );
    });

    test(
      'detecta mídia ausente no export e áudio adulterado na pré-visualização',
      () async {
        final now = DateTime.now().toUtc();
        final person = await srcRepo.createPerson(name: 'Pessoa com Áudio');
        // Nota de voz apontando para arquivo ausente em disco
        await srcDb
            .into(srcDb.voiceNotes)
            .insert(
              VoiceNotesCompanion.insert(
                id: 'vn_missing_file',
                personId: person.id,
                transcription: 'Nota sem arquivo físico',
                audioFilePath: drift.Value(
                  p.join(srcDir.path, 'nao_existe.m4a'),
                ),
                audioDurationSeconds: const drift.Value(12),
                createdAt: now,
                updatedAt: now,
              ),
            );
        // Nota de voz com arquivo real presente
        final audioFile = File(p.join(srcDir.path, 'present.m4a'));
        await audioFile.writeAsBytes([1, 2, 3, 4, 5, 6, 7, 8], flush: true);
        await srcDb
            .into(srcDb.voiceNotes)
            .insert(
              VoiceNotesCompanion.insert(
                id: 'vn_present_file',
                personId: person.id,
                transcription: 'Nota com áudio íntegro',
                audioFilePath: drift.Value(audioFile.path),
                audioDurationSeconds: const drift.Value(8),
                createdAt: now,
                updatedAt: now,
              ),
            );

        final exported = await srcBackup.exportEncryptedBackup(
          'SenhaMidia#2026',
          iterations: 1000,
        );
        final preview = await dstBackup.previewBackup(
          encryptedDataString: exported,
          password: 'SenhaMidia#2026',
        );
        expect(preview.isIntegral, isTrue);

        final result = await dstBackup.commitRestore(preview);
        // O arquivo ausente no export é reportado sem derrubar o restore dos demais registros.
        expect(result.missingFiles, isNotEmpty);
        final restoredNotes = await dstDb.select(dstDb.voiceNotes).get();
        expect(restoredNotes.length, 2);

        // Agora simula adulteração de hash de áudio no payload descriptografado
        final tampered = Map<String, dynamic>.from(preview.rawDecryptedData);
        tampered['voiceNoteAudios'] = {
          'vn_present_file': base64Encode([9, 9, 9, 9]),
        };
        tampered['voiceNoteAudioHashes'] = {'vn_present_file': '0' * 64};
        final tamperedPreview = RestorePreview(
          peopleToAdd: 0,
          peopleToUpdate: 0,
          peopleUnchanged: 0,
          visitsToAdd: 0,
          visitsToUpdate: 0,
          studiesToAdd: 0,
          sessionsToAdd: 0,
          appointmentsToAdd: 0,
          activitiesToAdd: 0,
          rawDecryptedData: tampered,
        );
        final tamperedRes = await dstBackup.commitRestore(tamperedPreview);
        expect(tamperedRes.corruptedFiles, isNotEmpty);
      },
    );

    test('rollback preserva dados locais intactos quando commitRestore falha por erro interno', () async {
      // Estado pré-existente no destino que NÃO pode ser perdido.
      await dstRepo.createPerson(name: 'Pessoa Existente Intacta');
      await dstDb
          .into(dstDb.appKvStore)
          .insertOnConflictUpdate(
            AppKvStoreCompanion.insert(
              key: 'automatic_sync_owner_id',
              value: 'account-B-owner',
            ),
          );

      // Simula preview com registro malformado que provocará falha na transação SQLite.
      final brokenPreview = RestorePreview(
        peopleToAdd: 1,
        peopleToUpdate: 0,
        peopleUnchanged: 0,
        visitsToAdd: 0,
        visitsToUpdate: 0,
        studiesToAdd: 0,
        sessionsToAdd: 0,
        appointmentsToAdd: 0,
        activitiesToAdd: 0,
        rawDecryptedData: {
          'people': [
            {'id': null, 'name': null}, // Viola schema obrigatório
          ],
        },
      );

      await expectLater(
        () => dstBackup.commitRestore(brokenPreview),
        throwsA(anything),
      );

      // Dados existentes e identidade da conta permanecem 100% preservados após rollback.
      final peopleAfter = await dstRepo.getAllPeople();
      expect(
        peopleAfter.map((e) => e.name),
        contains('Pessoa Existente Intacta'),
      );
      final ownerAfter =
          await (dstDb.select(dstDb.appKvStore)
                ..where((t) => t.key.equals('automatic_sync_owner_id')))
              .getSingleOrNull();
      expect(ownerAfter?.value, 'account-B-owner');
    });

    test('aborta restauração se armazenamento seguro para snapshot pré-restore falhar', () async {
      await srcRepo.createPerson(name: 'Origem');
      final exported = await srcBackup.exportEncryptedBackup(
        'SenhaSnap#2026',
        iterations: 1000,
      );
      final preview = await srcBackup.previewBackup(
        encryptedDataString: exported,
        password: 'SenhaSnap#2026',
      );

      final failingBackup = BackupService(
        dstRepo,
        documentsDirectoryProvider: () async =>
            throw const FileSystemException('Disco indisponível'),
      );
      await dstRepo.createPerson(name: 'Destino Protegido');

      await expectLater(
        () => failingBackup.commitRestore(preview),
        throwsA(isA<RestoreAbortedException>()),
      );
      final stillThere = await dstRepo.getAllPeople();
      expect(stillThere.map((e) => e.name), equals(['Destino Protegido']));
    });
  });
}
