import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_logger.dart';
import '../database/app_database.dart';
import '../ui/providers.dart';

enum AppSettingsStatus { initializing, ready, persisting, error }

/// Gerenciador de configurações persistentes com inicialização aguardável,
/// fila serializada de gravações (FIFO), cache em memória e garantia de integridade contra condições de corrida.
class AppSettingsManager {
  final AppDatabase db;
  Future<void>? _initFuture;
  bool _isInitComplete = false;
  AppSettingsStatus _status = AppSettingsStatus.initializing;
  final Map<String, String> _memoryCache = {};
  final Set<String> _dirtyKeys = {};
  Future<void> _writeQueue = Future.value();
  String? _lastError;
  final List<void Function(Map<String, String>)> _listeners = [];

  AppSettingsManager(this.db) {
    init();
  }

  bool get isInitialized => _isInitComplete;
  AppSettingsStatus get status => _status;
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
      } catch (e, st) {
        AppLogger.warning('Falha em listener de AppSettingsManager', e, st);
      }
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
        _status = AppSettingsStatus.ready;
        _notifyListeners();
      } catch (e) {
        _lastError = e.toString();
        _isInitComplete = true;
        _status = AppSettingsStatus.error;
        _notifyListeners();
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
    _status = AppSettingsStatus.persisting;
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
        _status = AppSettingsStatus.ready;
      } catch (e) {
        _lastError = e.toString();
        _status = AppSettingsStatus.error;
        _notifyListeners();
        rethrow;
      }
    }

    final task = _writeQueue.then((_) => writeOp(), onError: (_) => writeOp());
    _writeQueue = task.catchError((Object e, StackTrace st) {
      AppLogger.debug('Erro na fila de escrita de configuração ($key): $e', st);
    });
    return task;
  }

  /// Remove configuração de forma serializada aguardando confirmação no SQLite.
  Future<void> remove(String key) async {
    _dirtyKeys.add(key);
    _memoryCache.remove(key);
    _status = AppSettingsStatus.persisting;
    _notifyListeners();

    Future<void> deleteOp() async {
      try {
        await init();
        await (db.delete(db.appKvStore)..where((t) => t.key.equals(key))).go();
        _lastError = null;
        _status = AppSettingsStatus.ready;
      } catch (e) {
        _lastError = e.toString();
        _status = AppSettingsStatus.error;
        _notifyListeners();
        rethrow;
      }
    }

    final task = _writeQueue.then(
      (_) => deleteOp(),
      onError: (_) => deleteOp(),
    );
    _writeQueue = task.catchError((Object e, StackTrace st) {
      AppLogger.debug('Erro na fila de remoção de configuração ($key): $e', st);
    });
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
          .catchError((Object e, StackTrace st) {
            AppLogger.warning('Falha ao inicializar AppSettingsNotifier', e, st);
          });
    }

    return Map<String, String>.from(manager._memoryCache);
  }

  AppSettingsStatus get status =>
      _manager?.status ?? AppSettingsStatus.initializing;
  String? get lastError => _manager?.lastError;

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

/// AsyncNotifier para clientes que necessitam de AsyncValue explícito para tratamento de carregamento e erro
class AsyncAppSettingsNotifier extends AsyncNotifier<Map<String, String>> {
  @override
  Future<Map<String, String>> build() async {
    final manager = ref.watch(appSettingsManagerProvider);
    await manager.init();
    return manager.getAllSettings();
  }

  Future<void> setString(String key, String value) async {
    final manager = ref.read(appSettingsManagerProvider);
    state = const AsyncLoading();
    try {
      await manager.setString(key, value);
      state = AsyncData(await manager.getAllSettings());
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> remove(String key) async {
    final manager = ref.read(appSettingsManagerProvider);
    state = const AsyncLoading();
    try {
      await manager.remove(key);
      state = AsyncData(await manager.getAllSettings());
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final asyncAppSettingsNotifierProvider =
    AsyncNotifierProvider<AsyncAppSettingsNotifier, Map<String, String>>(
      AsyncAppSettingsNotifier.new,
    );
