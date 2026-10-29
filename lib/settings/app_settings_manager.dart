import 'dart:async';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../ui/providers.dart';

class AppSettingsManager {
  final AppDatabase db;
  Future<void>? _initFuture;

  AppSettingsManager(this.db) {
    _initTable();
  }

  Future<void> _initTable() async {
    _initFuture ??= () async {
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS app_settings_kv (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        );
      ''');
    }();
    return _initFuture!;
  }

  Future<String?> getString(String key) async {
    await _initTable();
    final results = await db.customSelect(
      'SELECT value FROM app_settings_kv WHERE key = ? LIMIT 1;',
      variables: [Variable.withString(key)],
    ).get();

    if (results.isEmpty) return null;
    return results.first.read<String>('value');
  }

  Future<void> setString(String key, String value) async {
    await _initTable();
    await db.customStatement(
      'INSERT OR REPLACE INTO app_settings_kv (key, value) VALUES (?, ?);',
      [key, value],
    );
  }

  Future<void> remove(String key) async {
    await _initTable();
    await db.customStatement(
      'DELETE FROM app_settings_kv WHERE key = ?;',
      [key],
    );
  }
}

final appSettingsManagerProvider = Provider<AppSettingsManager>((ref) {
  final db = ref.watch(databaseProvider);
  return AppSettingsManager(db);
});
