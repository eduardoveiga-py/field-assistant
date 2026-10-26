import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

QueryExecutor constructDb({bool inMemory = false}) {
  if (inMemory) {
    return LazyDatabase(() async {
      final wasm = await WasmDatabase.open(
        databaseName: 'ministerio_pessoal_test',
        sqlite3Uri: Uri.parse('sqlite3.wasm'),
        driftWorkerUri: Uri.parse('drift_worker.js'),
        initializeDatabase: () => Uint8List(0),
      );
      return wasm.resolvedExecutor;
    });
  }
  return LazyDatabase(() async {
    final wasm = await WasmDatabase.open(
      databaseName: 'ministerio_pessoal',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return wasm.resolvedExecutor;
  });
}
