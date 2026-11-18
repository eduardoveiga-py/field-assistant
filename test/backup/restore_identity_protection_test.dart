import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/settings/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('FA-BAK-01: Restore consciente de conta e proteção de identidade/sync', () {
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
      srcDir = await Directory.systemTemp.createTemp('bak_id_src_');
      dstDir = await Directory.systemTemp.createTemp('bak_id_dst_');

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

    test('exportação omite chaves protegidas e restore preserva owner, checkpoints, cursores, PIN e não reinjeta sync_queue antiga', () async {
      // Origem: Conta A + preferências legítimas + chaves protegidas
      await srcRepo.createPerson(name: 'Pessoa do Backup');
      for (final kv in {
        'automatic_sync_owner_id': 'account-A-uid',
        'e2ee_checkpoint_v1_abc': '{"revision":1,"digest":"${'a' * 64}"}',
        'e2ee_last_server_seq_account-A-uid': '5',
        'last_synced_at_people': '2026-01-01T00:00:00Z',
        'app_pin_hash': 'attacker_pin_hash',
        'demo_mode': 'true',
        'ui_theme_preference': 'sun',
      }.entries) {
        await srcDb.into(srcDb.appKvStore).insertOnConflictUpdate(
          AppKvStoreCompanion.insert(key: kv.key, value: kv.value),
        );
      }

      const pwd = 'StrongPassword#2026';
      final exported = await srcBackup.exportEncryptedBackup(pwd, iterations: 1000);

      // Destino: Conta B já configurada com seus próprios cursores/checkpoints/PIN
      for (final kv in {
        'automatic_sync_owner_id': 'account-B-uid',
        'e2ee_checkpoint_v1_abc': '{"revision":9,"digest":"${'b' * 64}"}',
        'e2ee_last_server_seq_account-B-uid': '42',
        'last_synced_at_people': '2026-11-17T00:00:00Z',
        'app_pin_hash': 'account_B_pin_hash',
      }.entries) {
        await dstDb.into(dstDb.appKvStore).insertOnConflictUpdate(
          AppKvStoreCompanion.insert(key: kv.key, value: kv.value),
        );
      }

      // Simula também um backup antigo (pré-FA-BAK-01) contendo chaves protegidas e sync_queue antiga no rawDecryptedData
      final preview = await dstBackup.previewBackup(
        encryptedDataString: exported,
        password: pwd,
      );
      final tamperedData = Map<String, dynamic>.from(preview.rawDecryptedData);
      tamperedData['appKvStore'] = [
        ...(tamperedData['appKvStore'] as List),
        {'key': 'automatic_sync_owner_id', 'value': 'account-A-uid'},
        {'key': 'e2ee_checkpoint_v1_abc', 'value': '{"revision":1,"digest":"${'a' * 64}"}'},
        {'key': 'last_synced_at_people', 'value': '2020-01-01T00:00:00Z'},
        {'key': 'app_pin_hash', 'value': 'overwritten_pin'},
        {'key': 'demo_mode', 'value': 'true'},
      ];
      tamperedData['syncQueue'] = [
        {
          'id': 'stale_queue_op_999',
          'entityType': 'people',
          'entityId': 'ghost_person',
          'operation': 'DELETE',
          'payload': jsonEncode({'id': 'ghost_person'}),
          'status': 'pending',
          'attempts': 0,
          'createdAt': DateTime.utc(2025, 1, 1).toIso8601String(),
        },
      ];

      final legacyPreview = RestorePreview(
        peopleToAdd: preview.peopleToAdd,
        peopleToUpdate: preview.peopleToUpdate,
        peopleUnchanged: preview.peopleUnchanged,
        visitsToAdd: preview.visitsToAdd,
        visitsToUpdate: preview.visitsToUpdate,
        studiesToAdd: preview.studiesToAdd,
        sessionsToAdd: preview.sessionsToAdd,
        appointmentsToAdd: preview.appointmentsToAdd,
        activitiesToAdd: preview.activitiesToAdd,
        rawDecryptedData: tamperedData,
      );

      final result = await dstBackup.commitRestore(legacyPreview);
      expect(result.isIntegral, isTrue);

      Future<String?> kvVal(String key) async {
        final r = await (dstDb.select(
          dstDb.appKvStore,
        )..where((t) => t.key.equals(key))).getSingleOrNull();
        return r?.value;
      }

      // Identidade, segurança e estado de sync da Conta B permanecem 100% intactos!
      expect(await kvVal('automatic_sync_owner_id'), 'account-B-uid');
      expect(
        await kvVal('e2ee_checkpoint_v1_abc'),
        '{"revision":9,"digest":"${'b' * 64}"}',
      );
      expect(await kvVal('last_synced_at_people'), '2026-11-17T00:00:00Z');
      expect(await kvVal('app_pin_hash'), 'account_B_pin_hash');
      expect(await kvVal('demo_mode'), isNull);

      // Preferência não sensível e dados de domínio foram restaurados normalmente
      expect(await kvVal('ui_theme_preference'), 'sun');
      expect((await dstRepo.getAllPeople()).map((p) => p.name), contains('Pessoa do Backup'));

      // Operação obsoleta da syncQueue do backup NÃO foi reinjetada!
      final staleOp = await (dstDb.select(
        dstDb.syncQueue,
      )..where((t) => t.id.equals('stale_queue_op_999'))).getSingleOrNull();
      expect(staleOp, isNull);
    });
  });
}
