import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/app_logger.dart';
import '../../core/ios_storage_security.dart';
import 'local_database_encryption.dart';

QueryExecutor constructDb({bool inMemory = false}) {
  if (inMemory) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA foreign_keys = ON;');
      },
    );
  }
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'ministerio_pessoal.sqlite'));

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
      }
    } catch (e, st) {
      AppLogger.error(
        'Falha ao preparar criptografia SQLite local; preservando integridade do banco existente.',
        e,
        st,
      );
      // Fail-safe: se o arquivo em disco ainda estiver em texto claro porque
      // a migração sofreu rollback, abre em modo compatível sem perder dados;
      // se o arquivo já estiver cifrado, propaga o erro fail-closed.
      if (file.existsSync() &&
          file.lengthSync() >= 16 &&
          !LocalDatabaseEncryption.isPlaintextSqliteFile(file)) {
        rethrow;
      }
    }

    await IosStorageSecurity.protectSensitiveStorage();

    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        if (encryptionActive && dbHexKey != null) {
          LocalDatabaseEncryption.applyKeyPragma(rawDb, dbHexKey);
        }
        rawDb.execute('PRAGMA foreign_keys = ON;');
        rawDb.execute('PRAGMA journal_mode = WAL;');
        rawDb.execute('PRAGMA synchronous = NORMAL;');
        rawDb.execute('PRAGMA busy_timeout = 5000;');
      },
    );
  });
}
