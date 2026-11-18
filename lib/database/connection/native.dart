import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/app_logger.dart';
import '../../core/ios_storage_security.dart';
import 'db_status.dart';
import 'local_database_encryption.dart';

QueryExecutor constructDb({bool inMemory = false, File? dbFile}) {
  if (inMemory) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA foreign_keys = ON;');
      },
    );
  }
  return LazyDatabase(() async {
    final file =
        dbFile ??
        File(
          p.join(
            (await getApplicationDocumentsDirectory()).path,
            'ministerio_pessoal.sqlite',
          ),
        );

    String? dbHexKey;
    var encryptionActive = false;
    try {
      final candidateKey = await LocalDatabaseEncryption.getOrCreateHexKey();
      final result = await LocalDatabaseEncryption.prepareEncryptedDatabaseFile(
        file,
        hexKey: candidateKey,
      );
      encryptionActive = result.encryptionActive;
      if (encryptionActive) {
        dbHexKey = candidateKey;
        LocalDbEncryptionStatus.set(LocalDatabaseEncryptionState.encrypted);
      } else {
        throw const SecurityException(
          'A criptografia do banco de dados não pôde ser ativada.',
        );
      }
    } catch (e, st) {
      AppLogger.error(
        'Falha ao preparar criptografia SQLite local: operação bloqueada (fail-closed).',
        e,
        st,
      );

      final LocalDatabaseEncryptionState failureState;
      if (LocalDatabaseEncryption.hasPendingRecovery(file)) {
        failureState = LocalDatabaseEncryptionState.recoveryRequired;
      } else if (file.existsSync() &&
          LocalDatabaseEncryption.isPlaintextSqliteFile(file)) {
        failureState = LocalDatabaseEncryptionState.migrationFailed;
      } else if (e is SecurityException ||
          !LocalDatabaseEncryption.isSqlite3McAvailable()) {
        failureState = LocalDatabaseEncryptionState.encryptionUnavailable;
      } else {
        failureState = LocalDatabaseEncryptionState.migrationFailed;
      }

      LocalDbEncryptionStatus.set(failureState);

      final errorMsg =
          'Falha crítica de segurança ao inicializar banco de dados criptografado: $e';
      dbFatalPersistenceError.value = errorMsg;

      return _SafeNativeUnavailableQueryExecutor(errorMsg);
    }

    await IosStorageSecurity.protectSensitiveStorage();

    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        if (encryptionActive && dbHexKey != null) {
          LocalDatabaseEncryption.applyKeyPragma(rawDb, dbHexKey);
        } else {
          throw const SecurityException(
            'Tentativa de abrir banco nativo sem chave de criptografia ativa.',
          );
        }
        rawDb.execute('PRAGMA foreign_keys = ON;');
        rawDb.execute('PRAGMA journal_mode = WAL;');
        rawDb.execute('PRAGMA synchronous = NORMAL;');
        rawDb.execute('PRAGMA busy_timeout = 5000;');
      },
    );
  });
}

/// Executor de segurança estrita para Desktop e Mobile nativo (FA-SEC-06 / FAES M1).
/// Impede que qualquer consulta ou comando seja executado quando a criptografia
/// SQLite3MC não estiver ativa ou tiver sofrido falha de migração.
class _SafeNativeUnavailableQueryExecutor extends QueryExecutor {
  final String message;

  _SafeNativeUnavailableQueryExecutor([
    this.message = 'Acesso ao banco de dados bloqueado: falha de segurança na criptografia local (fail-closed).',
  ]);

  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async {
    dbFatalPersistenceError.value ??= message;
    throw SecurityException(message);
  }

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) async {
    final lower = statement.trim().toLowerCase();
    if (lower.startsWith('pragma')) {
      return;
    }
    throw SecurityException(message);
  }

  @override
  Future<int> runDelete(String statement, List<Object?> args) async {
    throw SecurityException(message);
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) async {
    throw SecurityException(message);
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) async {
    final lower = statement.trim().toLowerCase();
    if (lower.contains('sqlite_master') ||
        lower.contains('pragma_table_info') ||
        lower.startsWith('pragma')) {
      return [];
    }
    throw SecurityException(message);
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) async {
    throw SecurityException(message);
  }

  @override
  Future<void> runBatched(BatchedStatements statements) async {
    throw SecurityException(message);
  }

  @override
  Future<void> close() async {}

  @override
  TransactionExecutor beginTransaction() =>
      _SafeNativeUnavailableTransactionExecutor(this);

  @override
  QueryExecutor beginExclusive() => this;
}

class _SafeNativeUnavailableTransactionExecutor extends QueryExecutor
    implements TransactionExecutor {
  final _SafeNativeUnavailableQueryExecutor _parent;

  _SafeNativeUnavailableTransactionExecutor(this._parent);

  @override
  SqlDialect get dialect => _parent.dialect;

  @override
  TransactionExecutor beginTransaction() => this;

  @override
  QueryExecutor beginExclusive() => this;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) => _parent.ensureOpen(user);

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) =>
      _parent.runCustom(statement, args);

  @override
  Future<int> runDelete(String statement, List<Object?> args) =>
      _parent.runDelete(statement, args);

  @override
  Future<int> runInsert(String statement, List<Object?> args) =>
      _parent.runInsert(statement, args);

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) => _parent.runSelect(statement, args);

  @override
  Future<int> runUpdate(String statement, List<Object?> args) =>
      _parent.runUpdate(statement, args);

  @override
  Future<void> runBatched(BatchedStatements statements) =>
      _parent.runBatched(statements);

  @override
  Future<void> close() => _parent.close();

  @override
  bool get supportsNestedTransactions => false;

  @override
  Future<void> rollback() async {}

  @override
  Future<void> send() async {}
}
