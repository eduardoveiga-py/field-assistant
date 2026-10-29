import 'package:drift/drift.dart';

import 'unsupported.dart'
    if (dart.library.js_interop) 'connection_web.dart'
    if (dart.library.io) 'native.dart' as impl;

export 'unsupported.dart'
    if (dart.library.js_interop) 'connection_web.dart'
    if (dart.library.io) 'native.dart';

abstract class AppDatabaseConnection {
  static QueryExecutor connect({bool inMemory = false}) =>
      impl.constructDb(inMemory: inMemory);
}
