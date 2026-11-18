import 'package:flutter/foundation.dart';

export 'local_db_encryption_state.dart';

/// Sinalizador global de falha fatal de persistência local (ex.: WebAssembly/IndexedDB indisponíveis na Web
/// ou bloqueio fail-closed por falta de criptografia nativa no Desktop/Mobile).
final ValueNotifier<String?> dbFatalPersistenceError = ValueNotifier<String?>(
  null,
);
