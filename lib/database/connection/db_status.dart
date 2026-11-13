import 'package:flutter/foundation.dart';

/// Sinalizador global de falha fatal de persistência local (ex.: WebAssembly/IndexedDB indisponíveis na Web).
final ValueNotifier<String?> dbFatalPersistenceError = ValueNotifier<String?>(
  null,
);
