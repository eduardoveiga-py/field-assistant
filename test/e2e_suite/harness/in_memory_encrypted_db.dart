import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/connection/local_database_encryption.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sql;

/// Handle para gerenciamento do ciclo de vida de um banco de dados criptografado temporário.
class TestEncryptedDatabaseHandle {
  final AppDatabase db;
  final AppRepository repo;
  final File dbFile;
  final Directory tempDir;
  final String hexKey;

  TestEncryptedDatabaseHandle({
    required this.db,
    required this.repo,
    required this.dbFile,
    required this.tempDir,
    required this.hexKey,
  });

  /// Executa asserções fail-closed de criptografia ChaCha20 em disco:
  /// 1. Cabeçalho SQLite plaintext ausente.
  /// 2. Texto sensível não existe em bytes claros no arquivo.
  /// 3. Abertura sem chave falha fail-closed.
  /// 4. Abertura com a chave correta confirma cifra ativa ChaCha20 e integridade OK.
  Future<void> assertChaCha20Encrypted({String? sampleSecretText}) async {
    await InMemoryEncryptedDb.assertChaCha20Encrypted(
      dbFile,
      hexKey,
      sampleSecretText: sampleSecretText,
    );
  }

  /// Fecha o banco de dados e limpa os arquivos temporários criados em disco.
  Future<void> dispose() async {
    await db.close();
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }
}

/// Fábrica e utilitário de validação para instâncias herméticas de banco de dados
/// SQLite em memória e em arquivo temporário cifrado via SQLite3MultipleCiphers (ChaCha20).
class InMemoryEncryptedDb {
  InMemoryEncryptedDb._();

  /// Cria uma instância hermética em memória de [AppDatabase], configurando
  /// `PRAGMA foreign_keys = ON;` e suprimindo avisos de bancos múltiplos concorrentes.
  static AppDatabase createInMemory({
    bool foreignKeys = true,
    void Function(sql.Database rawDb)? customSetup,
  }) {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    return AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (rawDb) {
          if (foreignKeys) {
            rawDb.execute('PRAGMA foreign_keys = ON;');
          }
          if (customSetup != null) {
            customSetup(rawDb);
          }
        },
      ),
    );
  }

  /// Verifica se a extensão SQLite3MultipleCiphers está disponível no binário atual.
  static bool isSqlite3McAvailable() {
    return LocalDatabaseEncryption.isSqlite3McAvailable();
  }

  /// Cria um banco de dados temporário cifrado em disco via ChaCha20.
  /// Retorna um [TestEncryptedDatabaseHandle] com referências para inspeção binária.
  static Future<TestEncryptedDatabaseHandle> createEncryptedFileDb({
    Directory? customTempDir,
    String? hexKey,
  }) async {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    final tempDir =
        customTempDir ??
        Directory.systemTemp.createTempSync('e2e_enc_db_test_');
    final dbFile = File(p.join(tempDir.path, 'e2e_encrypted.sqlite'));
    final key = hexKey ?? LocalDatabaseEncryption.generateHexKey();

    // Cria e inicializa o arquivo cifrado com Drift NativeDatabase
    final db = AppDatabase.forTesting(
      NativeDatabase(
        dbFile,
        setup: (rawDb) {
          LocalDatabaseEncryption.applyKeyPragma(rawDb, key);
          rawDb.execute('PRAGMA foreign_keys = ON;');
          rawDb.execute('PRAGMA cipher = chacha20;');
        },
      ),
    );

    final repo = AppRepository(db);

    return TestEncryptedDatabaseHandle(
      db: db,
      repo: repo,
      dbFile: dbFile,
      tempDir: tempDir,
      hexKey: key,
    );
  }

  /// Executa asserções fail-closed de criptografia ChaCha20 em disco:
  /// 1. Cabeçalho SQLite plaintext ausente.
  /// 2. Texto sensível não existe em bytes claros no arquivo.
  /// 3. Abertura sem chave falha fail-closed.
  /// 4. Abertura com a chave correta confirma cifra ativa ChaCha20 e integridade OK.
  static Future<void> assertChaCha20Encrypted(
    File dbFile,
    String hexKey, {
    String? sampleSecretText,
  }) async {
    expect(
      dbFile.existsSync(),
      isTrue,
      reason: 'O arquivo de banco cifrado deve existir em disco.',
    );
    expect(
      LocalDatabaseEncryption.isPlaintextSqliteFile(dbFile),
      isFalse,
      reason: 'O arquivo não deve conter cabeçalho mágico SQLite plaintext.',
    );

    // Validação de inspeção binária direta do arquivo em repouso
    final rawBytes = await dbFile.readAsBytes();
    final asciiView = latin1.decode(rawBytes, allowInvalid: true);

    expect(
      asciiView.contains('SQLite format 3'),
      isFalse,
      reason: 'Assinatura plaintext "SQLite format 3" não pode estar visível.',
    );

    if (sampleSecretText != null && sampleSecretText.isNotEmpty) {
      expect(
        asciiView.contains(sampleSecretText),
        isFalse,
        reason:
            'Dados sensíveis ("$sampleSecretText") não podem estar legíveis em texto plano no disco.',
      );
    }

    // Abertura sem chave DEVE falhar fail-closed com erro de imagem de banco corrompida/não reconhecida
    final rawNoKey = sql.sqlite3.open(dbFile.path);
    try {
      expect(
        () => rawNoKey.select('SELECT count(*) FROM sqlite_master;'),
        throwsA(isA<sql.SqliteException>()),
        reason: 'Consulta sem chave DEVE falhar com SqliteException.',
      );
    } finally {
      rawNoKey.close();
    }

    // Abertura com a chave correta DEVE ter sucesso e confirmar a cifra
    final rawAuth = sql.sqlite3.open(dbFile.path);
    try {
      LocalDatabaseEncryption.applyKeyPragma(rawAuth, hexKey);
      final cipherRows = rawAuth.select('PRAGMA cipher;');
      expect(
        cipherRows.isNotEmpty,
        isTrue,
        reason: 'PRAGMA cipher deve retornar a cifra ativa.',
      );
      final cipherName = cipherRows.first.values.first?.toString().toLowerCase();
      expect(
        cipherName,
        contains('chacha20'),
        reason: 'A cifra ativa deve ser chacha20, mas foi "$cipherName".',
      );

      final integrityRows = rawAuth.select('PRAGMA quick_check;');
      expect(
        integrityRows.isNotEmpty,
        isTrue,
        reason: 'PRAGMA quick_check deve retornar resultado.',
      );
      expect(
        integrityRows.first.values.first?.toString().toLowerCase(),
        equals('ok'),
        reason: 'A integridade do banco cifrado deve ser "ok".',
      );
    } finally {
      rawAuth.close();
    }
  }
}
