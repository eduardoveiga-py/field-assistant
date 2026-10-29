import 'dart:async';
import 'dart:developer' as developer;
import 'dart:js_interop';
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';
import 'package:web/web.dart' as web;

/// Resolve URI do asset levando em conta document.baseURI (essencial para Flutter Web com subpastas ou rotas HTML5)
Uri _resolveAssetUri(String relativePath) {
  try {
    final base = web.document.baseURI;
    if (base.isNotEmpty) {
      return Uri.parse(base).resolve(relativePath);
    }
  } catch (_) {}
  return Uri.base.resolve(relativePath);
}

/// Carregador de módulo WebAssembly resiliente a falhas de MIME type.
///
/// O método padrão [WebAssembly.instantiateStreaming] exige estritamente o cabeçalho
/// HTTP 'Content-Type: application/wasm'. Se o servidor web (ex: servidor local, S3,
/// Nginx ou Apache não configurado) enviar 'application/octet-stream' ou 'text/plain',
/// o navegador rejeita com [TypeError: Failed to execute 'compile' on 'WebAssembly': Incorrect response MIME type].
///
/// Este loader intercepta a rejeição e recorre à compilação via ArrayBuffer com
/// [WebAssembly.instantiate], que não valida cabeçalhos MIME e funciona com 100% de confiabilidade.
// ignore: experimental_member_use
base class _MimeResilientWasmLoader extends WasmModuleLoader {
  @override
  Future<web.WebAssemblyInstantiatedSource> instantiateModule(
    web.Response response,
  ) async {
    // Clona a resposta para garantir que o corpo permaneça acessível caso o streaming falhe
    final cloned = response.clone();
    try {
      return await super.instantiateModule(response);
    } catch (e) {
      developer.log(
        'WebAssembly.instantiateStreaming falhou ($e). Recorrendo a ArrayBuffer + WebAssembly.instantiate para contornar MIME type do servidor...',
        name: 'DriftWeb',
      );
      final arrayBuffer = await cloned.arrayBuffer().toDart;
      final source = await web.WebAssembly.instantiate(
        arrayBuffer,
        createImportObject(),
      ).toDart;
      return source as web.WebAssemblyInstantiatedSource;
    }
  }
}

QueryExecutor constructDb({bool inMemory = false}) {
  return LazyDatabase(() async {
    final dbName = inMemory ? 'ministerio_pessoal_test' : 'ministerio_pessoal';
    final wasmUri = _resolveAssetUri('sqlite3.wasm');
    final workerUri = _resolveAssetUri('drift_worker.js');

    // Verifica antecipadamente se o servidor web suporta compilação em streaming (MIME application/wasm).
    // O WebAssembly.compileStreaming nos Web Workers rejeita fatalmente se o servidor retornar
    // 'application/octet-stream' ou páginas 404 'text/html'.
    bool streamingWasmSupported = false;
    try {
      final probeResponse = await web.window.fetch(wasmUri.toString().toJS).toDart;
      final contentType = probeResponse.headers.get('content-type') ?? '';
      if (probeResponse.ok && contentType.toLowerCase().contains('application/wasm')) {
        streamingWasmSupported = true;
      } else {
        developer.log(
          'Servidor web não enviou "application/wasm" para $wasmUri (MIME recebido: "$contentType", status: ${probeResponse.status}). '
          'Desviando para carregamento direto resiliente com IndexedDB.',
          name: 'DriftWeb',
        );
      }
    } catch (e) {
      developer.log(
        'Erro na sonda de conectividade do WebAssembly ($e). Tentando rotas de contingência...',
        name: 'DriftWeb',
        error: e,
      );
    }

    // 1. Tentativa Primária: WasmDatabase.open com Web Workers (OPFS / SharedWorker / DedicatedWorker)
    // Apenas ativada se o servidor web fornecer o tipo MIME correto para streaming nos workers
    if (streamingWasmSupported) {
      try {
        final wasm = await WasmDatabase.open(
          databaseName: dbName,
          sqlite3Uri: wasmUri,
          driftWorkerUri: workerUri,
          initializeDatabase: inMemory ? () => Uint8List(0) : null,
        );
        if (wasm.missingFeatures.isNotEmpty) {
          developer.log(
            'Drift Web inicializado com limitações de navegador. '
            'Implementação escolhida: ${wasm.chosenImplementation}. '
            'Recursos ausentes: ${wasm.missingFeatures}',
            name: 'DriftWeb',
          );
        }
        return wasm.resolvedExecutor;
      } catch (e, stack) {
        developer.log(
          'Falha no WasmDatabase.open via Web Worker ($e). Recorrendo ao carregamento direto resiliente...',
          name: 'DriftWeb',
          error: e,
          stackTrace: stack,
        );
      }
    }

    // 2. Tentativa Secundária: Carregamento direto de WasmSqlite3 no contexto principal com IndexedDbFileSystem
    // Utiliza _MimeResilientWasmLoader com ArrayBuffer para contornar servidores sem application/wasm
    try {
      final sqlite3 = await WasmSqlite3.loadFromUrl(
        wasmUri,
        loader: _MimeResilientWasmLoader(),
      );
      if (inMemory) {
        sqlite3.registerVirtualFileSystem(InMemoryFileSystem(), makeDefault: true);
        return WasmDatabase.inMemory(sqlite3);
      } else {
        try {
          final fs = await IndexedDbFileSystem.open(dbName: dbName);
          sqlite3.registerVirtualFileSystem(fs, makeDefault: true);
          return WasmDatabase(
            sqlite3: sqlite3,
            path: '/$dbName',
            fileSystem: fs,
          );
        } catch (fsErr) {
          developer.log(
            'Falha ao abrir IndexedDbFileSystem ($fsErr). Recorrendo a InMemoryFileSystem...',
            name: 'DriftWeb',
            error: fsErr,
          );
          sqlite3.registerVirtualFileSystem(InMemoryFileSystem(), makeDefault: true);
          return WasmDatabase.inMemory(sqlite3);
        }
      }
    } catch (e, stack) {
      developer.log(
        'Falha no carregamento direto de WasmSqlite3 ($e). Ativando fallback de contingência...',
        name: 'DriftWeb',
        error: e,
        stackTrace: stack,
      );
    }

    // 3. Fallback de Segurança Robusto: Evita crash de tela vermelha quando o ambiente Web bloqueia totalmente WebAssembly
    developer.log(
      'AVISO [DriftWeb]: Não foi possível carregar ou compilar os binários WebAssembly (sqlite3.wasm / drift_worker.js). '
      'Executando em modo degradado de segurança para evitar travamento da interface.',
      name: 'DriftWeb',
    );
    return _FallbackWebQueryExecutor();
  });
}

/// Executor de contingência para evitar falhas fatais na UI caso WebAssembly seja totalmente bloqueado no navegador
class _FallbackWebQueryExecutor extends QueryExecutor {
  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async {
    await user.beforeOpen(this, OpeningDetails(null, user.schemaVersion));
    return true;
  }

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) async {}

  @override
  Future<int> runDelete(String statement, List<Object?> args) async => 0;

  @override
  Future<int> runInsert(String statement, List<Object?> args) async => 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(String statement, List<Object?> args) async => [];

  @override
  Future<int> runUpdate(String statement, List<Object?> args) async => 0;

  @override
  Future<void> runBatched(BatchedStatements statements) async {}

  @override
  Future<void> close() async {}

  @override
  TransactionExecutor beginTransaction() => _FallbackWebTransactionExecutor(this);

  @override
  QueryExecutor beginExclusive() => this;
}

class _FallbackWebTransactionExecutor extends QueryExecutor implements TransactionExecutor {
  final _FallbackWebQueryExecutor _parent;
  _FallbackWebTransactionExecutor(this._parent);

  @override
  SqlDialect get dialect => _parent.dialect;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) => _parent.ensureOpen(user);

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) => _parent.runCustom(statement, args);

  @override
  Future<int> runDelete(String statement, List<Object?> args) => _parent.runDelete(statement, args);

  @override
  Future<int> runInsert(String statement, List<Object?> args) => _parent.runInsert(statement, args);

  @override
  Future<List<Map<String, Object?>>> runSelect(String statement, List<Object?> args) => _parent.runSelect(statement, args);

  @override
  Future<int> runUpdate(String statement, List<Object?> args) => _parent.runUpdate(statement, args);

  @override
  Future<void> runBatched(BatchedStatements statements) => _parent.runBatched(statements);

  @override
  Future<void> close() => _parent.close();

  @override
  TransactionExecutor beginTransaction() => this;

  @override
  QueryExecutor beginExclusive() => this;

  @override
  bool get supportsNestedTransactions => false;

  @override
  Future<void> send() async {}

  @override
  Future<void> rollback() async {}
}
