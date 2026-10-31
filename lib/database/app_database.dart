import 'package:drift/drift.dart';
import 'tables.dart';
import 'connection/connection.dart' as impl;

part 'app_database.g.dart';

@DriftDatabase(tables: [
  People,
  Visits,
  BibleStudies,
  StudyParticipants,
  StudySessions,
  Appointments,
  ActivityRecords,
  SyncQueue,
  VoiceNotes,
  PhoneContacts,
  TerritoryLandmarks,
  AppKvStore,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? impl.constructDb());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // Migração incremental da versão 1 para a versão 2:
        // Cria tabelas tipadas com segurança se ainda não existirem
        await _createTableIfNotExists(m, voiceNotes);
        await _createTableIfNotExists(m, phoneContacts);
        await _createTableIfNotExists(m, territoryLandmarks);
        await _createTableIfNotExists(m, appKvStore);

        // Assegura integridade das colunas em bases migradas de versões antigas
        await _migrateLandmarksColumns();

        // Migra dados de pares chave-valor legados para a tabela tipada app_kv_store
        await _migrateLegacyKvStore();
      }
    },
  );

  Future<void> _migrateLandmarksColumns() async {
    try {
      final columns = await customSelect("PRAGMA table_info(territory_landmarks)").get();
      final colNames = columns.map((c) => c.read<String>('name')).toSet();
      if (!colNames.contains('updated_at')) {
        await customStatement("ALTER TABLE territory_landmarks ADD COLUMN updated_at INTEGER;");
        await customStatement("UPDATE territory_landmarks SET updated_at = created_at WHERE updated_at IS NULL;");
      }
      if (!colNames.contains('deleted_at')) {
        await customStatement("ALTER TABLE territory_landmarks ADD COLUMN deleted_at INTEGER;");
      }
      if (!colNames.contains('revision')) {
        await customStatement("ALTER TABLE territory_landmarks ADD COLUMN revision INTEGER NOT NULL DEFAULT 1;");
        await customStatement("UPDATE territory_landmarks SET revision = 1 WHERE revision IS NULL;");
      }
    } catch (_) {}
  }

  Future<void> _migrateLegacyKvStore() async {
    try {
      final kvLegacyCheck = await customSelect(
        "SELECT count(*) as count FROM sqlite_master WHERE type='table' AND name='app_settings_kv'",
      ).getSingle();
      if (kvLegacyCheck.read<int>('count') > 0) {
        final legacyRows = await customSelect("SELECT key, value FROM app_settings_kv").get();
        for (final row in legacyRows) {
          final k = row.read<String>('key');
          final v = row.read<String>('value');
          await into(appKvStore).insertOnConflictUpdate(
            AppKvStoreCompanion.insert(
              key: k,
              value: v,
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
        await customStatement("DROP TABLE IF EXISTS app_settings_kv");
      }
    } catch (_) {}
  }

  Future<void> _createTableIfNotExists(Migrator m, TableInfo table) async {
    final tableName = table.actualTableName;
    final row = await customSelect(
      "SELECT count(*) as count FROM sqlite_master WHERE type='table' AND name=?",
      variables: [Variable.withString(tableName)],
    ).getSingle();
    final count = row.read<int>('count');
    if (count == 0) {
      await m.createTable(table);
    }
  }
}
