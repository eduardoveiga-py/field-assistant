import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/settings/app_settings_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Drift Schema Migration (v1 to v2)', () {
    test('TC-MIG-01: Migra com segurança banco de dados v1 para v2 sem perda de dados', () async {
      // 1. Constrói um banco em memória inicializado no estado v1 com tabelas legadas
      final sqliteDb = sql.sqlite3.openInMemory();

      // Executa criação do schema v1 manualmente
      sqliteDb.execute('''
        CREATE TABLE people (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          phone TEXT,
          address TEXT,
          status TEXT NOT NULL DEFAULT 'interessado',
          notes TEXT,
          tags TEXT NOT NULL DEFAULT '[]',
          first_contact_at INTEGER NOT NULL,
          last_contact_at INTEGER,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER,
          revision INTEGER NOT NULL DEFAULT 1
        );
      ''');

      // Cria a tabela legada de configurações app_settings_kv
      sqliteDb.execute('''
        CREATE TABLE app_settings_kv (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        );
      ''');
      sqliteDb.execute(
        "INSERT INTO app_settings_kv (key, value) VALUES ('theme_mode', 'sunMode')",
      );
      sqliteDb.execute(
        "INSERT INTO app_settings_kv (key, value) VALUES ('timer_duration', '3600')",
      );

      // Cria a tabela legada territory_landmarks com colunas antigas (sem updated_at, deleted_at, revision)
      sqliteDb.execute('''
        CREATE TABLE territory_landmarks (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          category TEXT NOT NULL,
          address TEXT,
          latitude REAL,
          longitude REAL,
          notes TEXT,
          created_at INTEGER NOT NULL
        );
      ''');
      sqliteDb.execute(
        "INSERT INTO territory_landmarks (id, name, category, address, latitude, longitude, notes, created_at) "
        "VALUES ('lm_1', 'Padaria Central', 'padaria', 'Rua Central, 100', -23.55, -46.63, 'Ponto de encontro', 1700000000000)",
      );

      // Define PRAGMA user_version = 1
      sqliteDb.execute('PRAGMA user_version = 1;');

      // 2. Instancia AppDatabase envolvendo a conexão sqlite3 existente
      final appDb = AppDatabase.forTesting(NativeDatabase.opened(sqliteDb));

      // Dispara migração abrindo o banco e realizando query
      final ver = await appDb.customSelect('PRAGMA user_version;').getSingle();
      expect(ver.read<int>('user_version'), equals(2));

      // 3. Valida migração de dados de app_settings_kv para app_kv_store
      final kvManager = AppSettingsManager(appDb);
      final theme = await kvManager.getString('theme_mode');
      final duration = await kvManager.getString('timer_duration');
      expect(theme, equals('sunMode'));
      expect(duration, equals('3600'));

      // Confirma que app_settings_kv foi limpa/dropada
      final checkOldKv = await appDb.customSelect(
        "SELECT count(*) as count FROM sqlite_master WHERE type='table' AND name='app_settings_kv'",
      ).getSingle();
      expect(checkOldKv.read<int>('count'), equals(0));

      // 4. Valida que territory_landmarks recebeu as novas colunas
      final landmarks = await (appDb.select(appDb.territoryLandmarks)
            ..where((t) => t.deletedAt.isNull()))
          .get();
      expect(landmarks.length, equals(1));
      expect(landmarks.first.name, equals('Padaria Central'));
      expect(landmarks.first.revision, equals(1));

      // 5. Valida que tabelas novas v2 existem e funcionam normalmente
      final vnCount = await (appDb.select(appDb.voiceNotes)).get();
      expect(vnCount, isEmpty);
      final pcCount = await (appDb.select(appDb.phoneContacts)).get();
      expect(pcCount, isEmpty);

      await appDb.close();
    });
  });
}
