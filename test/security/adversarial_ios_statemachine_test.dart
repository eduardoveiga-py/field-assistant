import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/connection/db_status.dart';
import 'package:ministerio_pessoal/database/connection/local_database_encryption.dart';
import 'package:ministerio_pessoal/database/connection/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sql;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group(
    'Adversarial Verification: iOS Protection & Entitlements Consistency',
    () {
      test('ios/Runner/Runner.entitlements contains NSFileProtectionCompleteUntilFirstUserAuthentication', () {
        final entitlementsFile = File('ios/Runner/Runner.entitlements');
        expect(
          entitlementsFile.existsSync(),
          isTrue,
          reason: 'Runner.entitlements must exist',
        );

        final content = entitlementsFile.readAsStringSync();
        expect(
          content.contains(
            '<key>com.apple.developer.default-data-protection</key>',
          ),
          isTrue,
          reason: 'default-data-protection key must be present in entitlements',
        );
        expect(
          content.contains(
            '<string>NSFileProtectionCompleteUntilFirstUserAuthentication</string>',
          ),
          isTrue,
          reason: 'Protection class must be NSFileProtectionCompleteUntilFirstUserAuthentication',
        );

        // Verify no remaining NSFileProtectionComplete without UntilFirstUserAuthentication
        final forbiddenRegex = RegExp(
          r'<string>NSFileProtectionComplete<\/string>',
        );
        expect(
          forbiddenRegex.hasMatch(content),
          isFalse,
          reason:
              'Runner.entitlements must not contain NSFileProtectionComplete',
        );
      });

      test('ios/Runner/AppDelegate.swift applies FileProtectionType.completeUntilFirstUserAuthentication', () {
        final appDelegateFile = File('ios/Runner/AppDelegate.swift');
        expect(
          appDelegateFile.existsSync(),
          isTrue,
          reason: 'AppDelegate.swift must exist',
        );

        final content = appDelegateFile.readAsStringSync();
        expect(
          content.contains(
            'FileProtectionType.completeUntilFirstUserAuthentication',
          ),
          isTrue,
          reason: 'AppDelegate.swift must use FileProtectionType.completeUntilFirstUserAuthentication',
        );

        // Check that FileProtectionType.complete (without UntilFirstUserAuthentication) is not used
        final forbiddenRegex = RegExp(
          r'FileProtectionType\.complete(?!UntilFirstUserAuthentication)',
        );
        expect(
          forbiddenRegex.hasMatch(content),
          isFalse,
          reason: 'AppDelegate.swift must not use FileProtectionType.complete',
        );
      });
    },
  );

  group(
    'Adversarial Verification: Keychain & Keystore Configuration Invariants',
    () {
      test('Default iOS and Android secure storage parameters match security invariants', () async {
        FlutterSecureStorage.setMockInitialValues({});
        LocalDatabaseEncryption.resetSimulationFlags();

        // Retrieve key and verify it generates 64-hex key
        final key = await LocalDatabaseEncryption.getOrCreateHexKey();
        expect(key.length, 64);
        expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(key), isTrue);

        // Inspect source code of local_database_encryption.dart for immutable option parameters
        final sourceFile = File(
          'lib/database/connection/local_database_encryption.dart',
        );
        final source = sourceFile.readAsStringSync();

        expect(
          source.contains(
            'accessibility: KeychainAccessibility.first_unlock_this_device',
          ),
          isTrue,
          reason: 'IOSOptions must specify first_unlock_this_device',
        );
        expect(
          source.contains('synchronizable: false'),
          isTrue,
          reason: 'IOSOptions must specify synchronizable: false to prevent key iCloud exfiltration',
        );
        expect(
          source.contains('resetOnError: false'),
          isTrue,
          reason: 'AndroidOptions must specify resetOnError: false to prevent silent key wipe',
        );
      });
    },
  );

  group(
    'Adversarial Verification: 5-State Machine Operational Reachability',
    () {
      late Directory tempDir;

      setUp(() async {
        FlutterSecureStorage.setMockInitialValues({});
        LocalDatabaseEncryption.resetSimulationFlags();
        LocalDbEncryptionStatus.reset();
        dbFatalPersistenceError.value = null;
        tempDir = await Directory.systemTemp.createTemp('faes_adv_m1_');
      });

      tearDown(() async {
        LocalDatabaseEncryption.resetSimulationFlags();
        LocalDbEncryptionStatus.reset();
        dbFatalPersistenceError.value = null;
        if (await tempDir.exists()) {
          try {
            await tempDir.delete(recursive: true);
          } catch (_) {}
        }
      });

      test(
        'State 1: encrypted is observed upon successful creation and query',
        () async {
          final dbFile = File(p.join(tempDir.path, 'state_encrypted.sqlite'));
          final executor = constructDb(dbFile: dbFile);
          final db = AppDatabase(executor);

          expect(
            LocalDbEncryptionStatus.current,
            LocalDatabaseEncryptionState.encrypted,
          );

          final result = await db.customSelect('SELECT 42 AS val;').getSingle();
          expect(result.data['val'], 42);

          expect(
            LocalDbEncryptionStatus.current,
            LocalDatabaseEncryptionState.encrypted,
          );
          expect(dbFatalPersistenceError.value, isNull);

          await db.close();
        },
      );

      test(
        'State 2: migrationRequired is observed during plaintext migration',
        () async {
          final dbFile = File(
            p.join(tempDir.path, 'state_migration_req.sqlite'),
          );

          // Create plaintext database
          final plainDb = sql.sqlite3.open(dbFile.path);
          plainDb.execute(
            'CREATE TABLE t1 (id INTEGER PRIMARY KEY, note TEXT);',
          );
          plainDb.execute("INSERT INTO t1 VALUES (1, 'plain_data');");
          plainDb.close();

          expect(LocalDatabaseEncryption.isPlaintextSqliteFile(dbFile), isTrue);

          final observedStates = <LocalDatabaseEncryptionState>[];
          void listener() {
            observedStates.add(LocalDbEncryptionStatus.current);
          }

          LocalDbEncryptionStatus.notifier.addListener(listener);

          final hexKey = await LocalDatabaseEncryption.getOrCreateHexKey();
          final res =
              await LocalDatabaseEncryption.prepareEncryptedDatabaseFile(
                dbFile,
                hexKey: hexKey,
              );

          LocalDbEncryptionStatus.notifier.removeListener(listener);

          expect(res.encryptionActive, isTrue);
          expect(res.migratedFromPlaintext, isTrue);
          expect(
            observedStates.contains(
              LocalDatabaseEncryptionState.migrationRequired,
            ),
            isTrue,
            reason: 'migrationRequired must be observed when migrating plaintext database',
          );
          expect(
            LocalDbEncryptionStatus.current,
            LocalDatabaseEncryptionState.encrypted,
          );
        },
      );

      test('State 3: encryptionUnavailable is observed when cipher missing or key storage fails', () async {
        final dbFile = File(p.join(tempDir.path, 'state_unavailable.sqlite'));

        // Subcase A: Missing SQLite3MC cipher
        LocalDatabaseEncryption.simulateMissingCipherForTest = true;
        final executorA = constructDb(dbFile: dbFile);
        final dbA = AppDatabase(executorA);

        await expectLater(
          dbA.customSelect('SELECT 1;').get(),
          throwsA(isA<SecurityException>()),
        );
        expect(
          LocalDbEncryptionStatus.current,
          LocalDatabaseEncryptionState.encryptionUnavailable,
        );
        expect(dbFatalPersistenceError.value, isNotNull);
        await dbA.close();

        // Subcase B: Key storage failure
        LocalDatabaseEncryption.resetSimulationFlags();
        LocalDbEncryptionStatus.reset();
        dbFatalPersistenceError.value = null;
        LocalDatabaseEncryption.simulateKeyStorageFailureForTest = true;

        final executorB = constructDb(dbFile: dbFile);
        final dbB = AppDatabase(executorB);

        await expectLater(
          dbB.customSelect('SELECT 1;').get(),
          throwsA(isA<SecurityException>()),
        );
        expect(
          LocalDbEncryptionStatus.current,
          LocalDatabaseEncryptionState.encryptionUnavailable,
        );
        await dbB.close();
      });

      test('State 4: migrationFailed is observed when migration process aborts mid-flight', () async {
        final dbFile = File(
          p.join(tempDir.path, 'state_migration_fail.sqlite'),
        );

        final plainDb = sql.sqlite3.open(dbFile.path);
        plainDb.execute('CREATE TABLE secrets (id INT, val TEXT);');
        plainDb.execute("INSERT INTO secrets VALUES (1, 'dont_lose_me');");
        plainDb.close();

        LocalDatabaseEncryption.simulateMigrationFailureForTest = true;

        final executor = constructDb(dbFile: dbFile);
        final db = AppDatabase(executor);

        await expectLater(
          db.customSelect('SELECT 1;').get(),
          throwsA(isA<SecurityException>()),
        );
        expect(
          LocalDbEncryptionStatus.current,
          LocalDatabaseEncryptionState.migrationFailed,
        );
        expect(dbFatalPersistenceError.value, isNotNull);

        // Original plaintext file must remain preserved
        expect(dbFile.existsSync(), isTrue);
        expect(LocalDatabaseEncryption.isPlaintextSqliteFile(dbFile), isTrue);

        await db.close();
      });

      test('State 5: recoveryRequired is observed when pending recovery backup (.pre_enc.bak) is detected', () async {
        final dbFile = File(p.join(tempDir.path, 'state_recovery_req.sqlite'));
        final bakFile = File('${dbFile.path}.pre_enc.bak');

        // Create a valid plaintext sqlite database for the backup
        final initDb = sql.sqlite3.open(bakFile.path);
        initDb.execute('CREATE TABLE backup_data (id INT, item TEXT);');
        initDb.execute("INSERT INTO backup_data VALUES (1, 'saved_item');");
        initDb.close();

        expect(bakFile.existsSync(), isTrue);
        expect(LocalDatabaseEncryption.hasPendingRecovery(dbFile), isTrue);

        final observedStates = <LocalDatabaseEncryptionState>[];
        void listener() {
          observedStates.add(LocalDbEncryptionStatus.current);
        }

        LocalDbEncryptionStatus.notifier.addListener(listener);

        final hexKey = await LocalDatabaseEncryption.getOrCreateHexKey();
        final res = await LocalDatabaseEncryption.prepareEncryptedDatabaseFile(
          dbFile,
          hexKey: hexKey,
        );

        LocalDbEncryptionStatus.notifier.removeListener(listener);

        expect(
          observedStates.contains(
            LocalDatabaseEncryptionState.recoveryRequired,
          ),
          isTrue,
          reason: 'recoveryRequired must be observed during prepareEncryptedDatabaseFile when backup exists',
        );
        expect(res.encryptionActive, isTrue);
        expect(res.migratedFromPlaintext, isTrue);
        expect(
          LocalDbEncryptionStatus.current,
          LocalDatabaseEncryptionState.encrypted,
        );

        // Verify that the restored and encrypted data can be read
        final verifyDb = sql.sqlite3.open(dbFile.path);
        try {
          LocalDatabaseEncryption.applyKeyPragma(verifyDb, hexKey);
          final rows = verifyDb.select('SELECT item FROM backup_data;');
          expect(rows.first['item'], 'saved_item');
        } finally {
          verifyDb.close();
        }
      });
    },
  );

  group('Adversarial Verification: Fail-Closed Query Executor Hardening', () {
    test(
      'Unavailable query executor rejects all operations without side effects',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('faes_adv_hard_');
        final dbFile = File(
          p.join(tempDir.path, 'hardened_fail_closed.sqlite'),
        );

        LocalDatabaseEncryption.simulateMissingCipherForTest = true;
        final executor = constructDb(dbFile: dbFile);

        // Verify ensureOpen fails
        await expectLater(
          executor.ensureOpen(AppDatabase(executor)),
          throwsA(isA<SecurityException>()),
        );

        // Verify custom statements fail
        await expectLater(
          executor.runCustom('CREATE TABLE test(id INT);'),
          throwsA(isA<SecurityException>()),
        );

        // Verify select fails
        await expectLater(
          executor.runSelect('SELECT 1;', []),
          throwsA(isA<SecurityException>()),
        );

        // Verify update fails
        await expectLater(
          executor.runUpdate('UPDATE test SET id = 1;', []),
          throwsA(isA<SecurityException>()),
        );

        // Verify insert fails
        await expectLater(
          executor.runInsert('INSERT INTO test(id) VALUES(1);', []),
          throwsA(isA<SecurityException>()),
        );

        // Verify delete fails
        await expectLater(
          executor.runDelete('DELETE FROM test;', []),
          throwsA(isA<SecurityException>()),
        );

        // Verify transaction executor and statements within transaction fail
        final transaction = executor.beginTransaction();
        await expectLater(
          transaction.runSelect('SELECT 1;', []),
          throwsA(isA<SecurityException>()),
        );
        await expectLater(
          transaction.runInsert('INSERT INTO test(id) VALUES(1);', []),
          throwsA(isA<SecurityException>()),
        );

        final db = AppDatabase(executor);
        await expectLater(
          db.transaction(() async {
            await db.customSelect('SELECT 1;').get();
          }),
          throwsA(isA<SecurityException>()),
        );

        // Crucial: Disk file MUST NEVER be created
        expect(dbFile.existsSync(), isFalse);

        await tempDir.delete(recursive: true);
      },
    );
  });
}
