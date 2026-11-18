import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/connection/local_database_encryption.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sql;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group(
    'FA-SEC-06: SQLite3MultipleCiphers em repouso, migração e rollback',
    () {
      late Directory tempDir;

      setUp(() async {
        FlutterSecureStorage.setMockInitialValues({});
        tempDir = await Directory.systemTemp.createTemp('fa_sec06_sqlite3mc_');
      });

      tearDown(() async {
        if (await tempDir.exists()) {
          try {
            await tempDir.delete(recursive: true);
          } catch (_) {}
        }
      });

      test('binário sqlite3 carregado via build hook suporta sqlite3mc', () {
        expect(LocalDatabaseEncryption.isSqlite3McAvailable(), isTrue);
      });

      test('migra banco plaintext WAL/SHM para cifrado sem perda de dados e oculta texto claro em disco', () async {
        final dbFile = File(p.join(tempDir.path, 'ministerio_pessoal.sqlite'));

        // 1. Cria banco Drift em texto claro no modo WAL (simulando instalação anterior).
        final plainDb = AppDatabase.forTesting(
          NativeDatabase(
            dbFile,
            setup: (raw) {
              raw.execute('PRAGMA foreign_keys = ON;');
              raw.execute('PRAGMA journal_mode = WAL;');
            },
          ),
        );
        final plainRepo = AppRepository(plainDb);
        await plainRepo.createPerson(
          name: 'Maria Confidencial',
          address: 'Rua Secreta 123',
        );
        await plainDb.close();

        expect(LocalDatabaseEncryption.isPlaintextSqliteFile(dbFile), isTrue);

        // 2. Gera chave segura e executa migração não-destrutiva.
        final hexKey = await LocalDatabaseEncryption.getOrCreateHexKey();
        expect(hexKey.length, 64);

        final migrationResult =
            await LocalDatabaseEncryption.prepareEncryptedDatabaseFile(
              dbFile,
              hexKey: hexKey,
            );
        expect(migrationResult.encryptionActive, isTrue);
        expect(migrationResult.migratedFromPlaintext, isTrue);

        // 3. Prova em bytes no disco que cabeçalho e dados sensíveis não estão em texto claro.
        expect(LocalDatabaseEncryption.isPlaintextSqliteFile(dbFile), isFalse);
        final rawBytes = await dbFile.readAsBytes();
        final asciiView = latin1.decode(rawBytes, allowInvalid: true);
        expect(asciiView.contains('SQLite format 3'), isFalse);
        expect(asciiView.contains('Maria Confidencial'), isFalse);
        expect(asciiView.contains('Rua Secreta 123'), isFalse);
        expect(File('${dbFile.path}.pre_enc.bak').existsSync(), isFalse);
        expect(File('${dbFile.path}.enc.tmp').existsSync(), isFalse);

        // 4. Abrir sem chave ou com chave errada deve falhar fail-closed.
        final noKeyDb = sql.sqlite3.open(dbFile.path);
        try {
          expect(
            () => noKeyDb.select('SELECT * FROM people;'),
            throwsA(isA<sql.SqliteException>()),
          );
        } finally {
          noKeyDb.close();
        }

        final wrongKeyDb = sql.sqlite3.open(dbFile.path);
        try {
          LocalDatabaseEncryption.applyKeyPragma(
            wrongKeyDb,
            LocalDatabaseEncryption.generateHexKey(),
          );
          expect(
            () => wrongKeyDb.select('SELECT * FROM people;'),
            throwsA(isA<sql.SqliteException>()),
          );
        } finally {
          wrongKeyDb.close();
        }

        // 5. Reabrir via Drift com a chave correta preserva 100% dos registros e schemaVersion.
        final encDb = AppDatabase.forTesting(
          NativeDatabase(
            dbFile,
            setup: (raw) {
              LocalDatabaseEncryption.applyKeyPragma(raw, hexKey);
              raw.execute('PRAGMA foreign_keys = ON;');
              raw.execute('PRAGMA journal_mode = WAL;');
            },
          ),
        );
        final encRepo = AppRepository(encDb);
        final people = await encRepo.getAllPeople();
        expect(people.length, 1);
        expect(people.first.name, 'Maria Confidencial');
        expect(people.first.address, 'Rua Secreta 123');
        await encDb.close();

        // 6. Segunda chamada é idempotente (não remigra).
        final secondPass =
            await LocalDatabaseEncryption.prepareEncryptedDatabaseFile(
              dbFile,
              hexKey: hexKey,
            );
        expect(secondPass.encryptionActive, isTrue);
        expect(secondPass.migratedFromPlaintext, isFalse);
      });

      test(
        'rollback automático preserva banco original intacto se o swap falhar',
        () async {
          final dbFile = File(p.join(tempDir.path, 'rollback_test.sqlite'));
          final plainDb = AppDatabase.forTesting(NativeDatabase(dbFile));
          final plainRepo = AppRepository(plainDb);
          await plainRepo.createPerson(name: 'João Preservado');
          await plainDb.close();

          final hexKey = LocalDatabaseEncryption.generateHexKey();
          await expectLater(
            () => LocalDatabaseEncryption.prepareEncryptedDatabaseFile(
              dbFile,
              hexKey: hexKey,
              simulateFailureAfterBackupForTest: true,
            ),
            throwsA(isA<FileSystemException>()),
          );

          // Banco original restaurado intacto em texto claro e sem arquivos residuais.
          expect(dbFile.existsSync(), isTrue);
          expect(LocalDatabaseEncryption.isPlaintextSqliteFile(dbFile), isTrue);
          expect(File('${dbFile.path}.pre_enc.bak').existsSync(), isFalse);
          expect(File('${dbFile.path}.enc.tmp').existsSync(), isFalse);

          final reopened = AppDatabase.forTesting(NativeDatabase(dbFile));
          final people = await AppRepository(reopened).getAllPeople();
          expect(people.map((e) => e.name), contains('João Preservado'));
          await reopened.close();
        },
      );

      test(
        'recoverInterruptedMigration restaura .pre_enc.bak e limpa .enc.tmp',
        () async {
          final dbFile = File(p.join(tempDir.path, 'interrupted.sqlite'));
          final backupFile = File('${dbFile.path}.pre_enc.bak');
          final tmpFile = File('${dbFile.path}.enc.tmp');

          final seed = AppDatabase.forTesting(NativeDatabase(backupFile));
          await AppRepository(seed).createPerson(name: 'Recuperado de Crash');
          await seed.close();
          await tmpFile.writeAsString('partial-encrypted-garbage');

          LocalDatabaseEncryption.recoverInterruptedMigration(dbFile);

          expect(dbFile.existsSync(), isTrue);
          expect(backupFile.existsSync(), isFalse);
          expect(tmpFile.existsSync(), isFalse);

          final recovered = AppDatabase.forTesting(NativeDatabase(dbFile));
          final people = await AppRepository(recovered).getAllPeople();
          expect(people.map((e) => e.name), contains('Recuperado de Crash'));
          await recovered.close();
        },
      );

      test('FA-SEC-08: SupabaseSyncService não possui credenciais hardcoded e inicializa offline-first sem env/runtime', () async {
        FlutterSecureStorage.setMockInitialValues({});
        await SupabaseSyncService.initialize(
          storage: const FlutterSecureStorage(),
        );
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final sync = SupabaseSyncService(db: db, repository: AppRepository(db));
        expect(sync.supabaseUrl, isEmpty);
        expect(sync.supabaseAnonKey, isEmpty);
        sync.dispose();
        await db.close();
      });
    },
  );
}
