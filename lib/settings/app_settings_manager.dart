import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../ui/providers.dart';

class AppSettingsManager {
  final AppDatabase db;
  Future<void>? _initFuture;
  final Map<String, String> _memoryCache = {};

  AppSettingsManager(this.db) {
    _initStore();
  }

  Future<void> _initStore() async {
    _initFuture ??= () async {
      try {
        final rows = await db.select(db.appKvStore).get();
        for (final r in rows) {
          _memoryCache[r.key] = r.value;
        }
      } catch (_) {}
    }();
    return _initFuture!;
  }

  Future<String?> getString(String key) async {
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }
    await _initStore();
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }
    try {
      final entry = await (db.select(db.appKvStore)..where((t) => t.key.equals(key))).getSingleOrNull();
      if (entry == null) return null;
      _memoryCache[key] = entry.value;
      return entry.value;
    } catch (_) {
      return null;
    }
  }

  Future<void> setString(String key, String value) async {
    _memoryCache[key] = value;
    unawaited(() async {
      try {
        await _initStore();
        await db.into(db.appKvStore).insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: key,
            value: value,
            updatedAt: Value(DateTime.now()),
          ),
        );
      } catch (_) {}
    }());
  }

  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    unawaited(() async {
      try {
        await _initStore();
        await (db.delete(db.appKvStore)..where((t) => t.key.equals(key))).go();
      } catch (_) {}
    }());
  }
}

final appSettingsManagerProvider = Provider<AppSettingsManager>((ref) {
  final db = ref.watch(databaseProvider);
  return AppSettingsManager(db);
});
