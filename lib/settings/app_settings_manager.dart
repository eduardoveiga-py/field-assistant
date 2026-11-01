import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../ui/providers.dart';

/// Gerenciador de configurações persistentes com inicialização aguardável,
/// fila serializada de gravações (FIFO), cache em memória e garantia de integridade contra condições de corrida.
class AppSettingsManager {
  final AppDatabase db;
  Future<void>? _initFuture;
  bool _isInitComplete = false;
  final Map<String, String> _memoryCache = {};
  final Set<String> _dirtyKeys = {};
  Future<void> _writeQueue = Future.value();
  String? _lastError;
  final List<void Function(Map<String, String>)> _listeners = [];

  AppSettingsManager(this.db) {
    init();
  }

  bool get isInitialized => _isInitComplete;
  String? get lastError => _lastError;

  void addListener(void Function(Map<String, String>) listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function(Map<String, String>) listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    final snapshot = Map<String, String>.unmodifiable(_memoryCache);
    for (final listener in List.of(_listeners)) {
      try {
        listener(snapshot);
      } catch (_) {}
    }
  }

  /// Inicialização explícita e compartilhada.
  /// Múltiplas chamadas simultâneas compartilham a mesma operação assíncrona.
  Future<void> init() {
    _initFuture ??= () async {
      try {
        final rows = await db.select(db.appKvStore).get();
        for (final r in rows) {
          // Se a chave já foi modificada em memória durante a inicialização,
          // preserva o valor mais recente da memória em vez de sobrescrever com dado obsoleto do banco.
          if (!_dirtyKeys.contains(r.key)) {
            _memoryCache[r.key] = r.value;
          }
        }
        _isInitComplete = true;
        _notifyListeners();
      } catch (e) {
        _lastError = e.toString();
        _isInitComplete = true;
      }
    }();
    return _initFuture!;
  }

  /// Lê valor do cache após garantir a inicialização completa do armazenamento.
  Future<String?> getString(String key) async {
    await init();
    return _memoryCache[key];
  }

  /// Acesso síncrono somente ao cache em memória.
  String? getCachedString(String key) {
    return _memoryCache[key];
  }

  /// Grava configuração com ordenação determinística e fila serializada (FIFO).
  /// Atualiza o cache de imediato e aguarda a confirmação de persistência no SQLite.
  Future<void> setString(String key, String value) async {
    // 1. Marca chave como modificada para proteger contra corridas de inicialização
    _dirtyKeys.add(key);
    _memoryCache[key] = value;
    _notifyListeners();

    // 2. Enfileira gravação determinística na fila serializada
    Future<void> writeOp() async {
      try {
        await init();
        await db
            .into(db.appKvStore)
            .insertOnConflictUpdate(
              AppKvStoreCompanion.insert(
                key: key,
                value: value,
                updatedAt: Value(DateTime.now()),
              ),
            );
        _lastError = null;
      } catch (e) {
        _lastError = e.toString();
        rethrow;
      }
    }

    final task = _writeQueue.then((_) => writeOp(), onError: (_) => writeOp());
    _writeQueue = task.catchError((_) {});
    return task;
  }

  /// Remove configuração de forma serializada aguardando confirmação no SQLite.
  Future<void> remove(String key) async {
    _dirtyKeys.add(key);
    _memoryCache.remove(key);
    _notifyListeners();

    Future<void> deleteOp() async {
      try {
        await init();
        await (db.delete(db.appKvStore)..where((t) => t.key.equals(key))).go();
        _lastError = null;
      } catch (e) {
        _lastError = e.toString();
        rethrow;
      }
    }

    final task = _writeQueue.then(
      (_) => deleteOp(),
      onError: (_) => deleteOp(),
    );
    _writeQueue = task.catchError((_) {});
    return task;
  }

  /// Retorna snapshot imutável de todas as configurações persistidas.
  Future<Map<String, String>> getAllSettings() async {
    await init();
    return Map<String, String>.unmodifiable(_memoryCache);
  }

  /// Aguarda a conclusão de todas as operações pendentes na fila serializada de escrita.
  Future<void> flush() async {
    await _writeQueue;
  }
}

final appSettingsManagerProvider = Provider<AppSettingsManager>((ref) {
  final db = ref.watch(databaseProvider);
  return AppSettingsManager(db);
});

class AppSettingsNotifier extends Notifier<Map<String, String>> {
  AppSettingsManager? _manager;
  void Function(Map<String, String>)? _listener;

  @override
  Map<String, String> build() {
    final manager = ref.watch(appSettingsManagerProvider);
    _manager = manager;

    _listener = (updatedMap) {
      state = Map<String, String>.from(updatedMap);
    };
    manager.addListener(_listener!);

    ref.onDispose(() {
      if (_listener != null && _manager != null) {
        _manager!.removeListener(_listener!);
      }
    });

    // Se o banco ainda não terminou de carregar, aguarda a inicialização e atualiza o estado
    if (!manager.isInitialized) {
      manager
          .init()
          .then((_) {
            state = Map<String, String>.from(manager._memoryCache);
          })
          .catchError((_) {});
    }

    return Map<String, String>.from(manager._memoryCache);
  }

  Future<void> setString(String key, String value) async {
    final manager = ref.read(appSettingsManagerProvider);
    await manager.setString(key, value);
    state = Map<String, String>.from(manager._memoryCache);
  }

  Future<void> remove(String key) async {
    final manager = ref.read(appSettingsManagerProvider);
    await manager.remove(key);
    state = Map<String, String>.from(manager._memoryCache);
  }

  String? get(String key) => state[key];
}

final appSettingsNotifierProvider =
    NotifierProvider<AppSettingsNotifier, Map<String, String>>(
      AppSettingsNotifier.new,
    );
