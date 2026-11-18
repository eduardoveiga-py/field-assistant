import 'package:flutter/foundation.dart';

/// Estados explícitos da segurança e criptografia do banco de dados local SQLite (FA-SEC-06 / FAES M1).
enum LocalDatabaseEncryptionState {
  /// O banco está devidamente cifrado e ativo com SQLite3MultipleCiphers.
  encrypted,

  /// O banco em disco é texto claro (plaintext) e requer migração atômica para SQLite3MC.
  migrationRequired,

  /// Criptografia indisponível no ambiente (ex.: ausência de SQLite3MC no binário ou falha no Keychain).
  encryptionUnavailable,

  /// Falha durante a migração criptográfica; o banco foi revertido com segurança ou travado fail-closed.
  migrationFailed,

  /// Estado inconsistente ou interrupção prévia detectada (.pre_enc.bak); recuperação necessária.
  recoveryRequired,
}

/// Gerenciador observável do estado de criptografia do banco de dados local.
class LocalDbEncryptionStatus {
  LocalDbEncryptionStatus._();

  static final ValueNotifier<LocalDatabaseEncryptionState> notifier =
      ValueNotifier<LocalDatabaseEncryptionState>(
        LocalDatabaseEncryptionState.encrypted,
      );

  /// Retorna o estado atual da criptografia do banco de dados.
  static LocalDatabaseEncryptionState get current => notifier.value;

  /// Atualiza o estado da criptografia e notifica ouvintes registrados.
  static void set(LocalDatabaseEncryptionState state) {
    notifier.value = state;
  }

  /// Reseta o estado para o valor inicial (útil para testes unitários).
  @visibleForTesting
  static void reset() {
    notifier.value = LocalDatabaseEncryptionState.encrypted;
  }
}

/// Notificador global direto de estado (compatibilidade com ValueListenableBuilder).
final ValueNotifier<LocalDatabaseEncryptionState> localDbEncryptionState =
    LocalDbEncryptionStatus.notifier;
