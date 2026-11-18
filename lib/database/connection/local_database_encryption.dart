import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import '../../core/app_logger.dart';
import '../../core/ios_storage_security.dart';

/// Resultado da preparação/migração criptográfica do banco SQLite local (FA-SEC-06).
class LocalDatabaseEncryptionResult {
  final bool encryptionActive;
  final bool migratedFromPlaintext;
  final String? cipherName;

  const LocalDatabaseEncryptionResult({
    required this.encryptionActive,
    required this.migratedFromPlaintext,
    this.cipherName,
  });
}

/// Gerencia a chave local de 256 bits em armazenamento seguro (Keychain/Keystore)
/// e executa abertura/migração segura e não-destrutiva de bancos SQLite plaintext
/// para SQLite3MultipleCiphers (`sqlite3mc`) preservando WAL/SHM e com rollback
/// automático em caso de falha (FA-SEC-06 / ADR-014 / ADR-015).
class LocalDatabaseEncryption {
  static const String secureKeyName = 'fa_local_sqlite_db_key_v1';

  static const List<int> _sqlitePlaintextMagic = <int>[
    0x53,
    0x51,
    0x4c,
    0x69,
    0x74,
    0x65,
    0x20,
    0x66,
    0x6f,
    0x72,
    0x6d,
    0x61,
    0x74,
    0x20,
    0x33,
    0x00,
  ];

  static final RegExp _hex64Pattern = RegExp(r'^[0-9a-fA-F]{64}$');

  /// Gera uma chave aleatória de 256 bits (64 caracteres hexadecimais).
  static String generateHexKey() {
    final rnd = Random.secure();
    final buf = StringBuffer();
    for (int i = 0; i < 32; i++) {
      buf.write(rnd.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buf.toString();
  }

  /// Verifica se o cabeçalho de 16 bytes corresponde a um arquivo SQLite em texto claro.
  static bool isPlaintextSqliteFile(File file) {
    if (!file.existsSync()) return false;
    final len = file.lengthSync();
    if (len < 16) return false;
    final raf = file.openSync(mode: FileMode.read);
    try {
      final header = raf.readSync(16);
      if (header.length < 16) return false;
      for (int i = 0; i < 16; i++) {
        if (header[i] != _sqlitePlaintextMagic[i]) return false;
      }
      return true;
    } finally {
      raf.closeSync();
    }
  }

  /// Verifica em runtime se a biblioteca nativa carregada suporta SQLite3MultipleCiphers.
  static bool isSqlite3McAvailable() {
    final probe = sql.sqlite3.openInMemory();
    try {
      final rows = probe.select('PRAGMA cipher;');
      return rows.isNotEmpty &&
          (rows.first.values.first?.toString().trim().isNotEmpty ?? false);
    } catch (_) {
      return false;
    } finally {
      probe.close();
    }
  }

  /// Obtém ou cria a chave de 256 bits no `FlutterSecureStorage` (Keychain/Keystore).
  static Future<String> getOrCreateHexKey({
    FlutterSecureStorage? storage,
  }) async {
    final secure = storage ?? const FlutterSecureStorage();
    final existing = (await secure.read(key: secureKeyName))?.trim();
    if (existing != null && _hex64Pattern.hasMatch(existing)) {
      return existing.toLowerCase();
    }
    final fresh = generateHexKey();
    await secure.write(key: secureKeyName, value: fresh);
    return fresh;
  }

  /// Aplica `PRAGMA key` de 256 bits em uma conexão SQLite3MultipleCiphers.
  static void applyKeyPragma(sql.Database rawDb, String hexKey) {
    if (!_hex64Pattern.hasMatch(hexKey)) {
      throw ArgumentError(
        'Chave SQLite inválida: esperados 64 caracteres hexadecimais.',
      );
    }
    rawDb.execute("PRAGMA key = \"x'${hexKey.toLowerCase()}'\";");
  }

  /// Recupera um estado interrompido de migração anterior caso o processo tenha
  /// encerrado no meio da troca atômica do arquivo.
  static void recoverInterruptedMigration(File dbFile) {
    final backupFile = File('${dbFile.path}.pre_enc.bak');
    final tmpEncFile = File('${dbFile.path}.enc.tmp');

    if (!dbFile.existsSync() && backupFile.existsSync()) {
      backupFile.renameSync(dbFile.path);
      AppLogger.warning(
        'Migração SQLite interrompida recuperada restaurando backup pré-criptografia.',
      );
    }
    for (final residual in [
      tmpEncFile,
      File('${tmpEncFile.path}-wal'),
      File('${tmpEncFile.path}-shm'),
    ]) {
      if (residual.existsSync()) {
        try {
          residual.deleteSync();
        } catch (e, st) {
          AppLogger.debug(
            'Falha ao limpar arquivo residual ${residual.path}: $e',
            st,
          );
        }
      }
    }
  }

  /// Prepara o arquivo do banco para abertura cifrada:
  /// - Recupera qualquer migração anterior interrompida.
  /// - Se o banco ainda estiver em texto claro, faz checkpoint WAL (`TRUNCATE`),
  ///   migra uma cópia `.enc.tmp` com `PRAGMA rekey`, valida `PRAGMA integrity_check`
  ///   e cabeçalho cifrado, realiza swap atômico preservando `.pre_enc.bak` para
  ///   rollback em caso de falha e só remove `.pre_enc.bak` após validação final.
  static Future<LocalDatabaseEncryptionResult> prepareEncryptedDatabaseFile(
    File dbFile, {
    required String hexKey,
    @visibleForTesting bool simulateFailureAfterBackupForTest = false,
  }) async {
    if (!_hex64Pattern.hasMatch(hexKey)) {
      throw ArgumentError(
        'Chave SQLite inválida: esperados 64 caracteres hexadecimais.',
      );
    }

    recoverInterruptedMigration(dbFile);

    if (!isSqlite3McAvailable()) {
      AppLogger.warning(
        'SQLite3MultipleCiphers indisponível no binário SQLite atual; mantendo abertura padrão.',
      );
      return const LocalDatabaseEncryptionResult(
        encryptionActive: false,
        migratedFromPlaintext: false,
      );
    }

    String? cipherName;
    final probe = sql.sqlite3.openInMemory();
    try {
      final rows = probe.select('PRAGMA cipher;');
      if (rows.isNotEmpty) {
        cipherName = rows.first.values.first?.toString();
      }
    } finally {
      probe.close();
    }

    // Banco novo ou vazio: será criado já cifrado pelo setup do Drift.
    if (!dbFile.existsSync() || dbFile.lengthSync() == 0) {
      return LocalDatabaseEncryptionResult(
        encryptionActive: true,
        migratedFromPlaintext: false,
        cipherName: cipherName,
      );
    }

    // Já cifrado: valida abertura com a chave fornecida.
    if (!isPlaintextSqliteFile(dbFile)) {
      final verify = sql.sqlite3.open(dbFile.path);
      try {
        applyKeyPragma(verify, hexKey);
        verify.select('SELECT count(*) FROM sqlite_master;');
      } finally {
        verify.close();
      }
      return LocalDatabaseEncryptionResult(
        encryptionActive: true,
        migratedFromPlaintext: false,
        cipherName: cipherName,
      );
    }

    // Migração não-destrutiva de banco plaintext existente (preservando WAL/SHM e rollback).
    final backupFile = File('${dbFile.path}.pre_enc.bak');
    final tmpEncFile = File('${dbFile.path}.enc.tmp');
    final walFile = File('${dbFile.path}-wal');
    final shmFile = File('${dbFile.path}-shm');

    // 1. Checkpoint completo do WAL no banco original antes de copiar.
    final plainDb = sql.sqlite3.open(dbFile.path);
    try {
      final cp = plainDb.select('PRAGMA wal_checkpoint(TRUNCATE);');
      if (cp.isNotEmpty) {
        final busy = cp.first.values.first;
        if (busy is int && busy != 0) {
          throw StateError(
            'Checkpoint WAL bloqueado (busy=$busy) antes da criptografia do banco local.',
          );
        }
      }
      final qc = plainDb.select('PRAGMA quick_check;');
      if (qc.isEmpty ||
          qc.first.values.first?.toString().toLowerCase() != 'ok') {
        throw StateError(
          'Falha no quick_check do banco plaintext antes da migração.',
        );
      }
    } finally {
      plainDb.close();
    }

    // 2. Cria cópia temporária e cifra APENAS a cópia (original permanece intocado).
    if (tmpEncFile.existsSync()) tmpEncFile.deleteSync();
    dbFile.copySync(tmpEncFile.path);

    try {
      final rekeyDb = sql.sqlite3.open(tmpEncFile.path);
      try {
        rekeyDb.execute("PRAGMA rekey = \"x'${hexKey.toLowerCase()}'\";");
      } finally {
        rekeyDb.close();
      }

      // 3. Valida integridade e prova que o cabeçalho não está mais em texto claro.
      if (isPlaintextSqliteFile(tmpEncFile)) {
        throw StateError(
          'Falha na migração SQLite: arquivo temporário ainda possui cabeçalho plaintext.',
        );
      }
      final checkEnc = sql.sqlite3.open(tmpEncFile.path);
      try {
        applyKeyPragma(checkEnc, hexKey);
        final ic = checkEnc.select('PRAGMA integrity_check;');
        if (ic.isEmpty ||
            ic.first.values.first?.toString().toLowerCase() != 'ok') {
          throw StateError(
            'Falha em PRAGMA integrity_check após criptografar cópia do banco local.',
          );
        }
      } finally {
        checkEnc.close();
      }

      // 4. Troca atômica com backup de segurança (.pre_enc.bak) e rollback automático.
      if (backupFile.existsSync()) {
        backupFile.deleteSync();
      }
      dbFile.renameSync(backupFile.path);
      try {
        if (simulateFailureAfterBackupForTest) {
          throw const FileSystemException(
            'Falha simulada após mover banco para backup.',
          );
        }
        for (final sidecar in [walFile, shmFile]) {
          if (sidecar.existsSync()) sidecar.deleteSync();
        }
        tmpEncFile.renameSync(dbFile.path);

        // 5. Validação final no destino definitivo antes de descartar o backup.
        final finalCheck = sql.sqlite3.open(dbFile.path);
        try {
          applyKeyPragma(finalCheck, hexKey);
          final ic = finalCheck.select('PRAGMA integrity_check;');
          if (ic.isEmpty ||
              ic.first.values.first?.toString().toLowerCase() != 'ok') {
            throw StateError('Falha na validação pós-swap do banco cifrado.');
          }
        } finally {
          finalCheck.close();
        }
      } catch (e) {
        // Rollback completo: restaura o banco plaintext original intacto.
        if (dbFile.existsSync()) {
          try {
            dbFile.deleteSync();
          } catch (_) {}
        }
        if (backupFile.existsSync() && !dbFile.existsSync()) {
          backupFile.renameSync(dbFile.path);
        }
        rethrow;
      }

      // 6. Remove backup plaintext somente após banco cifrado estar validado.
      if (backupFile.existsSync()) {
        try {
          backupFile.deleteSync();
        } catch (e, st) {
          AppLogger.warning(
            'Não foi possível remover backup pré-criptografia imediatamente',
            e,
            st,
          );
        }
      }

      // 7. Reaplica NSFileProtectionComplete + isExcludedFromBackup no iOS.
      await IosStorageSecurity.protectSensitiveStorage();

      AppLogger.info(
        'Banco SQLite local migrado com sucesso para SQLite3MultipleCiphers ($cipherName).',
      );
      return LocalDatabaseEncryptionResult(
        encryptionActive: true,
        migratedFromPlaintext: true,
        cipherName: cipherName,
      );
    } finally {
      for (final residual in [
        tmpEncFile,
        File('${tmpEncFile.path}-wal'),
        File('${tmpEncFile.path}-shm'),
      ]) {
        if (residual.existsSync()) {
          try {
            residual.deleteSync();
          } catch (_) {}
        }
      }
    }
  }
}
