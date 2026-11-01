import 'package:drift/drift.dart';

import 'tables.dart';
import 'connection/connection.dart' as impl;

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
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
    FamilyTies,
    MinistryExperiences,
    PersonPhotos,
    PersonPublications,
    ResearchArticles,
    ResearchTags,
    TerritorySectors,
    StudentManualOrder,
    ExternalCalendarEvents,
    CalendarEventLinks,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? impl.constructDb());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // Migração incremental da versão 1 para a versão 2:
        await _createTableIfNotExists(m, voiceNotes);
        await _createTableIfNotExists(m, phoneContacts);
        await _createTableIfNotExists(m, territoryLandmarks);
        await _createTableIfNotExists(m, appKvStore);

        await _migrateLandmarksColumns();
        await _migrateLegacyKvStore();
      }
      if (from < 3) {
        // Migração incremental da versão 2 para a versão 3:
        // Migra as 8 tabelas criadas fora do Drift para tabelas formais tipadas
        // e cria as tabelas de integração externa de calendário
        await _createTableIfNotExists(m, familyTies);
        await _createTableIfNotExists(m, ministryExperiences);
        await _createTableIfNotExists(m, personPhotos);
        await _createTableIfNotExists(m, personPublications);
        await _createTableIfNotExists(m, researchArticles);
        await _createTableIfNotExists(m, researchTags);
        await _createTableIfNotExists(m, territorySectors);
        await _createTableIfNotExists(m, studentManualOrder);
        await _createTableIfNotExists(m, externalCalendarEvents);
        await _createTableIfNotExists(m, calendarEventLinks);

        await _migrateCustomTablesColumns();
      }
    },
  );

  Future<void> _migrateLandmarksColumns() async {
    try {
      final columns = await customSelect(
        "PRAGMA table_info(territory_landmarks)",
      ).get();
      final colNames = columns.map((c) => c.read<String>('name')).toSet();
      if (!colNames.contains('updated_at')) {
        await customStatement(
          "ALTER TABLE territory_landmarks ADD COLUMN updated_at INTEGER;",
        );
        await customStatement(
          "UPDATE territory_landmarks SET updated_at = created_at WHERE updated_at IS NULL;",
        );
      }
      if (!colNames.contains('deleted_at')) {
        await customStatement(
          "ALTER TABLE territory_landmarks ADD COLUMN deleted_at INTEGER;",
        );
      }
      if (!colNames.contains('revision')) {
        await customStatement(
          "ALTER TABLE territory_landmarks ADD COLUMN revision INTEGER NOT NULL DEFAULT 1;",
        );
        await customStatement(
          "UPDATE territory_landmarks SET revision = 1 WHERE revision IS NULL;",
        );
      }
    } catch (_) {}
  }

  Future<void> _migrateCustomTablesColumns() async {
    final tables = [
      'family_ties',
      'ministry_experiences',
      'person_photos',
      'person_publications',
      'research_articles',
      'research_tags',
      'territory_sectors',
      'student_manual_order',
    ];

    for (final tbl in tables) {
      try {
        final tableExists = await customSelect(
          "SELECT count(*) as count FROM sqlite_master WHERE type='table' AND name=?",
          variables: [Variable.withString(tbl)],
        ).getSingle();
        if (tableExists.read<int>('count') == 0) continue;

        final columns = await customSelect("PRAGMA table_info($tbl)").get();
        final colNames = columns.map((c) => c.read<String>('name')).toSet();

        if (!colNames.contains('updated_at')) {
          await customStatement(
            "ALTER TABLE $tbl ADD COLUMN updated_at INTEGER;",
          );
          if (colNames.contains('created_at')) {
            await customStatement(
              "UPDATE $tbl SET updated_at = created_at WHERE updated_at IS NULL;",
            );
          }
        }
        if (!colNames.contains('deleted_at')) {
          await customStatement(
            "ALTER TABLE $tbl ADD COLUMN deleted_at INTEGER;",
          );
        }
        if (!colNames.contains('revision')) {
          await customStatement(
            "ALTER TABLE $tbl ADD COLUMN revision INTEGER NOT NULL DEFAULT 1;",
          );
          await customStatement(
            "UPDATE $tbl SET revision = 1 WHERE revision IS NULL;",
          );
        }
      } catch (_) {}
    }
  }

  Future<void> _migrateLegacyKvStore() async {
    try {
      final kvLegacyCheck = await customSelect(
        "SELECT count(*) as count FROM sqlite_master WHERE type='table' AND name='app_settings_kv'",
      ).getSingle();
      if (kvLegacyCheck.read<int>('count') > 0) {
        final legacyRows = await customSelect(
          "SELECT key, value FROM app_settings_kv",
        ).get();
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
