import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/connection/db_status.dart';
import 'package:ministerio_pessoal/database/connection/local_database_encryption.dart';
import 'package:ministerio_pessoal/database/connection/native.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('FAES M1: Fail-Closed Local Database & 5-State Machine Tests', () {
    late Directory tempDir;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      LocalDatabaseEncryption.resetSimulationFlags();
      LocalDbEncryptionStatus.reset();
      dbFatalPersistenceError.value = null;
      tempDir = await Directory.systemTemp.createTemp('faes_m1_fail_closed_');
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

    test('Cenário 1: Se o binário não possuir SQLite3MC, constructDb falha fechado (fail-closed) sem criar banco plaintext', () async {
      final targetFile = File(p.join(tempDir.path, 'no_cipher.sqlite'));
      expect(targetFile.existsSync(), isFalse);

      LocalDatabaseEncryption.simulateMissingCipherForTest = true;

      final executor = constructDb(dbFile: targetFile);
      final db = AppDatabase(executor);

      // Qualquer tentativa de consulta deve falhar com SecurityException
      await expectLater(
        db.customSelect('SELECT 1;').get(),
        throwsA(isA<SecurityException>()),
      );

      // Invariante de Segurança: Nenhum arquivo de banco não-cifrado foi criado no disco
      expect(targetFile.existsSync(), isFalse);

      // Estado do banco deve ser encryptionUnavailable
      expect(
        LocalDbEncryptionStatus.current,
        equals(LocalDatabaseEncryptionState.encryptionUnavailable),
      );
      expect(
        localDbEncryptionState.value,
        equals(LocalDatabaseEncryptionState.encryptionUnavailable),
      );

      // Erro fatal de persistência deve ter sido sinalizado
      expect(dbFatalPersistenceError.value, isNotNull);
      expect(
        dbFatalPersistenceError.value,
        contains('SQLite3MultipleCiphers is not available'),
      );

      await db.close();
    });

    test('Cenário 2: Se a recuperação ou geração da chave falhar em instalação virgem, constructDb falha fechado sem criar arquivo em disco', () async {
      final targetFile = File(p.join(tempDir.path, 'key_failure_new.sqlite'));
      expect(targetFile.existsSync(), isFalse);

      LocalDatabaseEncryption.simulateKeyStorageFailureForTest = true;

      final executor = constructDb(dbFile: targetFile);
      final db = AppDatabase(executor);

      await expectLater(
        db.customSelect('SELECT 1;').get(),
        throwsA(isA<SecurityException>()),
      );

      // Invariante de Segurança: Zero bytes criados no disco
      expect(targetFile.existsSync(), isFalse);

      expect(
        LocalDbEncryptionStatus.current,
        equals(LocalDatabaseEncryptionState.encryptionUnavailable),
      );
      expect(dbFatalPersistenceError.value, isNotNull);

      await db.close();
    });

    test('Cenário 3: Se banco plaintext existir e a migração sofrer falha, rollback preserva arquivo e acesso é bloqueado fail-closed', () async {
      final targetFile = File(
        p.join(tempDir.path, 'plaintext_migration_fail.sqlite'),
      );

      // 1. Cria banco plaintext simulando versão antiga com dados sensíveis
      final initialDb = AppDatabase.forTesting(
        NativeDatabase(
          targetFile,
          setup: (raw) {
            raw.execute('PRAGMA foreign_keys = ON;');
            raw.execute('PRAGMA journal_mode = WAL;');
          },
        ),
      );
      final repo = AppRepository(initialDb);
      await repo.createPerson(
        name: 'Irmão Protegido',
        address: 'Avenida Segura 777',
      );
      await initialDb.close();

      expect(targetFile.existsSync(), isTrue);
      expect(LocalDatabaseEncryption.isPlaintextSqliteFile(targetFile), isTrue);

      // 2. Simula falha catastrófica durante a migração
      LocalDatabaseEncryption.simulateMigrationFailureForTest = true;

      final executor = constructDb(dbFile: targetFile);
      final db = AppDatabase(executor);

      // 3. Acesso ao banco deve ser estritamente bloqueado (sem fallback silencioso para plaintext)
      await expectLater(
        db.customSelect('SELECT count(*) FROM people;').get(),
        throwsA(isA<SecurityException>()),
      );

      // 4. Estado deve ser migrationFailed
      expect(
        LocalDbEncryptionStatus.current,
        equals(LocalDatabaseEncryptionState.migrationFailed),
      );
      expect(dbFatalPersistenceError.value, isNotNull);

      // 5. Invariante: O arquivo plaintext original foi mantido intacto pelo rollback
      expect(targetFile.existsSync(), isTrue);
      expect(LocalDatabaseEncryption.isPlaintextSqliteFile(targetFile), isTrue);

      // 6. Arquivo temporário e backup foram limpos
      expect(File('${targetFile.path}.enc.tmp').existsSync(), isFalse);

      await db.close();
    });

    test('Cenário 4: Banco novo com SQLite3MC ativo inicializa cifrado com sucesso (estado encrypted)', () async {
      final targetFile = File(p.join(tempDir.path, 'fresh_encrypted.sqlite'));
      expect(targetFile.existsSync(), isFalse);

      final executor = constructDb(dbFile: targetFile);
      final db = AppDatabase(executor);
      final repo = AppRepository(db);

      await repo.createPerson(
        name: 'Novo Convertido',
        address: 'Rua da Paz 100',
      );

      // Verifica que o banco foi criado e não está em texto claro
      expect(targetFile.existsSync(), isTrue);
      expect(
        LocalDatabaseEncryption.isPlaintextSqliteFile(targetFile),
        isFalse,
      );

      // Estado deve ser encrypted
      expect(
        LocalDbEncryptionStatus.current,
        equals(LocalDatabaseEncryptionState.encrypted),
      );
      expect(dbFatalPersistenceError.value, isNull);

      final people = await repo.getAllPeople();
      expect(people.length, 1);
      expect(people.first.name, 'Novo Convertido');

      await db.close();
    });

    test('Cenário 5: Transições de estado da máquina de 5 estados e notificação de ouvintes', () async {
      final observedStates = <LocalDatabaseEncryptionState>[];
      void listener() {
        observedStates.add(localDbEncryptionState.value);
      }

      localDbEncryptionState.addListener(listener);

      // 1. Estado inicial
      expect(
        LocalDbEncryptionStatus.current,
        equals(LocalDatabaseEncryptionState.encrypted),
      );

      // 2. Transição manual/programática de teste
      LocalDbEncryptionStatus.set(
        LocalDatabaseEncryptionState.migrationRequired,
      );
      expect(
        LocalDbEncryptionStatus.current,
        equals(LocalDatabaseEncryptionState.migrationRequired),
      );

      LocalDbEncryptionStatus.set(
        LocalDatabaseEncryptionState.encryptionUnavailable,
      );
      expect(
        LocalDbEncryptionStatus.current,
        equals(LocalDatabaseEncryptionState.encryptionUnavailable),
      );

      LocalDbEncryptionStatus.set(LocalDatabaseEncryptionState.migrationFailed);
      expect(
        LocalDbEncryptionStatus.current,
        equals(LocalDatabaseEncryptionState.migrationFailed),
      );

      LocalDbEncryptionStatus.set(
        LocalDatabaseEncryptionState.recoveryRequired,
      );
      expect(
        LocalDbEncryptionStatus.current,
        equals(LocalDatabaseEncryptionState.recoveryRequired),
      );

      LocalDbEncryptionStatus.set(LocalDatabaseEncryptionState.encrypted);
      expect(
        LocalDbEncryptionStatus.current,
        equals(LocalDatabaseEncryptionState.encrypted),
      );

      expect(observedStates, [
        LocalDatabaseEncryptionState.migrationRequired,
        LocalDatabaseEncryptionState.encryptionUnavailable,
        LocalDatabaseEncryptionState.migrationFailed,
        LocalDatabaseEncryptionState.recoveryRequired,
        LocalDatabaseEncryptionState.encrypted,
      ]);

      localDbEncryptionState.removeListener(listener);
    });

    test('Cenário 6: hasPendingRecovery detecta .pre_enc.bak e recoverInterruptedMigration recupera arquivo original', () async {
      final targetFile = File(p.join(tempDir.path, 'recovery_test.sqlite'));
      final backupFile = File('${targetFile.path}.pre_enc.bak');
      final tmpEncFile = File('${targetFile.path}.enc.tmp');

      // Cria backup simulando interrupção de migração
      await backupFile.writeAsString('backup-content-plaintext');
      await tmpEncFile.writeAsString('corrupted-tmp-content');

      expect(targetFile.existsSync(), isFalse);
      expect(LocalDatabaseEncryption.hasPendingRecovery(targetFile), isTrue);

      // Executa recuperação
      LocalDatabaseEncryption.recoverInterruptedMigration(targetFile);

      expect(targetFile.existsSync(), isTrue);
      expect(await targetFile.readAsString(), 'backup-content-plaintext');
      expect(backupFile.existsSync(), isFalse);
      expect(tmpEncFile.existsSync(), isFalse);
    });
  });
}
