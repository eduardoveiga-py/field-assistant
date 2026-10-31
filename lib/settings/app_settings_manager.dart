import 'dart:async';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../ui/providers.dart';

class AppSettingsManager {
  final AppDatabase db;
  Future<void>? _initFuture;
  final Map<String, String> _memoryCache = {};

  AppSettingsManager(this.db) {
    _initTable();
  }

  Future<void> _initTable() async {
    _initFuture ??= () async {
      try {
        await db.customStatement('''
          CREATE TABLE IF NOT EXISTS app_settings_kv (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          );
        ''');
        final rows = await db.customSelect('SELECT key, value FROM app_settings_kv').get();
        for (final r in rows) {
          final k = r.read<String>('key');
          final v = r.read<String>('value');
          _memoryCache[k] = v;
        }
      } catch (_) {}
    }();
    return _initFuture!;
  }

  Future<String?> getString(String key) async {
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }
    await _initTable();
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }
    try {
      final results = await db.customSelect(
        'SELECT value FROM app_settings_kv WHERE key = ? LIMIT 1;',
        variables: [Variable.withString(key)],
      ).get();

      if (results.isEmpty) return null;
      final val = results.first.read<String>('value');
      _memoryCache[key] = val;
      return val;
    } catch (_) {
      return null;
    }
  }

  Future<void> setString(String key, String value) async {
    _memoryCache[key] = value;
    unawaited(() async {
      try {
        await _initTable();
        await db.customInsert(
          'INSERT OR REPLACE INTO app_settings_kv (key, value) VALUES (?, ?);',
          variables: [Variable.withString(key), Variable.withString(value)],
        );
      } catch (_) {}
    }());
  }

  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    unawaited(() async {
      try {
        await _initTable();
        await db.customUpdate(
          'DELETE FROM app_settings_kv WHERE key = ?;',
          variables: [Variable.withString(key)],
        );
      } catch (_) {}
    }());
  }
}

final appSettingsManagerProvider = Provider<AppSettingsManager>((ref) {
  final db = ref.watch(databaseProvider);
  return AppSettingsManager(db);
});
