import 'package:drift/drift.dart';

import '../core/app_logger.dart';
import '../core/sync_timestamp.dart';
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
    AppLanguages,
    InboxEntries,
    Projects,
    Tasks,
    KnowledgeNotes,
    KnowledgeQuestions,
    KnowledgeDocuments,
    KnowledgeResources,
    TicunaWords,
    TicunaPhrases,
    TicunaTags,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? impl.constructDb());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _ensurePerformanceIndexes();
      await _seedDefaultLanguage();
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
      if (from < 4) {
        // Migração incremental da versão 3 para a versão 4:
        // Adiciona a coluna pending_resolution em calendar_event_links
        await _createTableIfNotExists(m, calendarEventLinks);
        await _migrateCalendarEventLinksPendingResolution(m);
      }
      if (from < 5) {
        // Migração incremental da versão 4 para a versão 5 (Regra 11):
        // Adiciona a tabela AppLanguages com Ticuna como padrão e coluna last_attempt_at em SyncQueue
        await _createTableIfNotExists(m, syncQueue);
        await _createTableIfNotExists(m, appLanguages);
        await _migrateSyncQueueLastAttemptAt(m);
        await _seedDefaultLanguage();
      }
      if (from < 6) {
        // Migração incremental da versão 5 para a versão 6:
        // Módulos Integrados: Inbox Universal, Tarefas & Projetos, Base de Conhecimento
        await _createTableIfNotExists(m, inboxEntries);
        await _createTableIfNotExists(m, projects);
        await _createTableIfNotExists(m, tasks);
        await _createTableIfNotExists(m, knowledgeNotes);
        await _createTableIfNotExists(m, knowledgeQuestions);
        await _createTableIfNotExists(m, knowledgeDocuments);
        await _createTableIfNotExists(m, knowledgeResources);

        await _migrateAppointmentsTaskId(m);
        await _migrateResearchArticlesContextColumns(m);
      }
      if (from < 7) {
        // Migração incremental da versão 6 para a versão 7:
        // Garante que a coluna updated_at exista na tabela app_kv_store
        await _createTableIfNotExists(m, appKvStore);
        await _migrateAppKvStoreUpdatedAt(m);
      }
      if (from < 8) {
        // Migração incremental da versão 7 para a versão 8 (A3, A7, A9):
        // - Registra tabelas Ticuna no schema Drift e garante colunas legadas
        // - Adiciona file_path em person_photos
        // - Converte timestamps ISO TEXT gravados por managers legados para unix-seconds (INTEGER Drift)
        // - Cria índices de busca de contatos e fila de sync
        await _createTableIfNotExists(m, ticunaWords);
        await _createTableIfNotExists(m, ticunaPhrases);
        await _createTableIfNotExists(m, ticunaTags);
        await _migrateTicunaLegacyColumns();
        await _migratePersonPhotosFilePath(m);
        await _normalizeLegacyTextTimestamps();
        await _ensurePerformanceIndexes();
      }
    },
    beforeOpen: (details) async {
      await _ensureAppKvStoreUpdatedAt();
      await _ensurePerformanceIndexes();
      await _seedDefaultLanguage();
    },
  );

  Future<void> _ensurePerformanceIndexes() async {
    final rows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('people', 'sync_queue')",
    ).get();
    final existing = rows.map((r) => r.read<String>('name')).toSet();
    if (existing.contains('people')) {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_people_name ON people(name COLLATE NOCASE);',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_people_deleted_at ON people(deleted_at);',
      );
    }
    if (existing.contains('sync_queue')) {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue(status, created_at);',
      );
    }
  }

  Future<void> _migratePersonPhotosFilePath(Migrator m) async {
    final tableCheck = await customSelect(
      "SELECT count(*) as count FROM sqlite_master WHERE type='table' AND name='person_photos'",
    ).getSingle();
    if (tableCheck.read<int>('count') == 0) return;
    final columns = await customSelect(
      "PRAGMA table_info(person_photos)",
    ).get();
    final colNames = columns.map((c) => c.read<String>('name')).toSet();
    if (colNames.isNotEmpty && !colNames.contains('file_path')) {
      await m.addColumn(personPhotos, personPhotos.filePath);
    }
  }

  Future<void> _migrateTicunaLegacyColumns() async {
    final ticunaColumnsByTable = <String, Map<String, String>>{
      'ticuna_words': {
        'audio_path': 'ALTER TABLE ticuna_words ADD COLUMN audio_path TEXT;',
        'audio_duration_seconds':
            'ALTER TABLE ticuna_words ADD COLUMN audio_duration_seconds INTEGER;',
        'language_id':
            "ALTER TABLE ticuna_words ADD COLUMN language_id TEXT DEFAULT 'tca';",
      },
      'ticuna_phrases': {
        'audio_path': 'ALTER TABLE ticuna_phrases ADD COLUMN audio_path TEXT;',
        'audio_duration_seconds':
            'ALTER TABLE ticuna_phrases ADD COLUMN audio_duration_seconds INTEGER;',
        'language_id':
            "ALTER TABLE ticuna_phrases ADD COLUMN language_id TEXT DEFAULT 'tca';",
      },
    };
    for (final entry in ticunaColumnsByTable.entries) {
      final columns = await customSelect('PRAGMA table_info(${entry.key})').get();
      final colNames = columns.map((c) => c.read<String>('name')).toSet();
      if (colNames.isEmpty) continue;
      for (final colEntry in entry.value.entries) {
        if (!colNames.contains(colEntry.key)) {
          await customStatement(colEntry.value);
        }
      }
    }
  }

  Future<void> _normalizeLegacyTextTimestamps() async {
    const tableColumns = <String, List<String>>{
      'family_ties': ['created_at', 'updated_at', 'deleted_at'],
      'ministry_experiences': ['date_time', 'created_at', 'updated_at', 'deleted_at'],
      'person_photos': ['created_at', 'updated_at', 'deleted_at'],
      'person_publications': ['created_at', 'updated_at', 'deleted_at'],
      'research_articles': ['created_at', 'updated_at', 'deleted_at'],
      'research_tags': ['created_at', 'updated_at', 'deleted_at'],
      'territory_sectors': ['created_at', 'updated_at', 'deleted_at'],
      'student_manual_order': ['updated_at', 'deleted_at'],
    };
    const requiredCols = {'created_at', 'updated_at', 'date_time'};

    for (final entry in tableColumns.entries) {
      final table = entry.key;
      final exists = await customSelect(
        "SELECT count(*) as count FROM sqlite_master WHERE type='table' AND name=?",
        variables: [Variable.withString(table)],
      ).getSingle();
      if (exists.read<int>('count') == 0) continue;

      final info = await customSelect('PRAGMA table_info($table)').get();
      final existingCols = info.map((c) => c.read<String>('name')).toSet();

      for (final col in entry.value) {
        if (!existingCols.contains(col)) continue;
        final textRows = await customSelect(
          "SELECT rowid AS _rid, $col AS _val FROM $table WHERE typeof($col) = 'text'",
        ).get();
        for (final row in textRows) {
          final rid = row.read<int>('_rid');
          final rawVal = row.data['_val']?.toString() ?? '';
          final parsed = SyncTimestamp.parse(rawVal);
          final replacement =
              parsed ?? (requiredCols.contains(col) ? DateTime.now() : null);
          await customStatement(
            'UPDATE $table SET $col = ? WHERE rowid = ?',
            [
              replacement == null ? null : replacement.millisecondsSinceEpoch ~/ 1000,
              rid,
            ],
          );
        }
      }
    }
  }

  Future<void> _migrateAppKvStoreUpdatedAt(Migrator m) async {
    final columns = await customSelect(
      "PRAGMA table_info(app_kv_store)",
    ).get();
    final colNames = columns.map((c) => c.read<String>('name')).toSet();
    if (colNames.isNotEmpty && !colNames.contains('updated_at')) {
      await m.addColumn(appKvStore, appKvStore.updatedAt);
    }
  }

  Future<void> _ensureAppKvStoreUpdatedAt() async {
    try {
      final tableCheck = await customSelect(
        "SELECT count(*) as count FROM sqlite_master WHERE type='table' AND name='app_kv_store'",
      ).getSingle();
      if (tableCheck.read<int>('count') > 0) {
        final columns = await customSelect(
          "PRAGMA table_info(app_kv_store)",
        ).get();
        final colNames = columns.map((c) => c.read<String>('name')).toSet();
        if (!colNames.contains('updated_at')) {
          await customStatement(
            "ALTER TABLE app_kv_store ADD COLUMN updated_at INTEGER;",
          );
        }
      }
    } catch (e, st) {
      AppLogger.error('Falha ao garantir updated_at em app_kv_store', e, st);
      rethrow;
    }
  }

  Future<void> _migrateAppointmentsTaskId(Migrator m) async {
    final columns = await customSelect(
      "PRAGMA table_info(appointments)",
    ).get();
    final colNames = columns.map((c) => c.read<String>('name')).toSet();
    if (colNames.isNotEmpty && !colNames.contains('task_id')) {
      await m.addColumn(appointments, appointments.taskId);
    }
  }

  Future<void> _migrateResearchArticlesContextColumns(Migrator m) async {
    final columns = await customSelect(
      "PRAGMA table_info(research_articles)",
    ).get();
    final colNames = columns.map((c) => c.read<String>('name')).toSet();
    if (colNames.isNotEmpty) {
      if (!colNames.contains('objective')) {
        await m.addColumn(researchArticles, researchArticles.objective);
      }
      if (!colNames.contains('status')) {
        await m.addColumn(researchArticles, researchArticles.status);
      }
      if (!colNames.contains('conclusion')) {
        await m.addColumn(researchArticles, researchArticles.conclusion);
      }
      if (!colNames.contains('project_id')) {
        await m.addColumn(researchArticles, researchArticles.projectId);
      }
      if (!colNames.contains('main_question_id')) {
        await m.addColumn(researchArticles, researchArticles.mainQuestionId);
      }
    }
  }

  Future<void> _migrateCalendarEventLinksPendingResolution(Migrator m) async {
    // Verifica se a coluna já existe para suportar bancos criados parcialmente.
    // NÃO silencia erros inesperados — propaga para abortar a migração.
    final columns = await customSelect(
      "PRAGMA table_info(calendar_event_links)",
    ).get();
    final colNames = columns.map((c) => c.read<String>('name')).toSet();
    if (!colNames.contains('pending_resolution')) {
      await m.addColumn(
        calendarEventLinks,
        calendarEventLinks.pendingResolution,
      );
    }
  }

  Future<void> _migrateSyncQueueLastAttemptAt(Migrator m) async {
    final columns = await customSelect(
      "PRAGMA table_info(sync_queue)",
    ).get();
    final colNames = columns.map((c) => c.read<String>('name')).toSet();
    if (colNames.isNotEmpty && !colNames.contains('last_attempt_at')) {
      await m.addColumn(syncQueue, syncQueue.lastAttemptAt);
    }
  }

  Future<void> _seedDefaultLanguage() async {
    try {
      final tableCheck = await customSelect(
        "SELECT count(*) AS count FROM sqlite_master WHERE type='table' AND name='app_languages'",
      ).getSingle();
      if (tableCheck.read<int>('count') == 0) return;

      final now = DateTime.now();
      final catalog = [
        AppLanguagesCompanion.insert(
          id: 'tca',
          name: 'Ticuna (Magüta)',
          code: 'tca',
          symbol: '🏹',
          diacritics: const Value(
            '["ĩ","ü̃","ü̃́","ũ","ã́","ẽ","Ĩ","Ü̃","Ü̃́","Ũ","Ã́","Ẽ"]',
          ),
          isDefault: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
        AppLanguagesCompanion.insert(
          id: 'por',
          name: 'Português',
          code: 'por',
          symbol: '🇧🇷',
          diacritics: const Value('[]'),
          isDefault: const Value(false),
          createdAt: now,
          updatedAt: now,
        ),
        AppLanguagesCompanion.insert(
          id: 'spa',
          name: 'Español',
          code: 'spa',
          symbol: '🇪🇸',
          diacritics: const Value(
            '["ñ","á","é","í","ó","ú","ü","¡","¿"]',
          ),
          isDefault: const Value(false),
          createdAt: now,
          updatedAt: now,
        ),
        AppLanguagesCompanion.insert(
          id: 'gub',
          name: 'Guajajara (Tenetehara)',
          code: 'gub',
          symbol: '🌿',
          diacritics: const Value(
            '["à","è","ì","ò","ù","ỹ","\'"]',
          ),
          isDefault: const Value(false),
          createdAt: now,
          updatedAt: now,
        ),
        AppLanguagesCompanion.insert(
          id: 'yan',
          name: 'Yanomami (Yanomamõ)',
          code: 'yan',
          symbol: '🌳',
          diacritics: const Value(
            '["ë","ɨ","th","rh"]',
          ),
          isDefault: const Value(false),
          createdAt: now,
          updatedAt: now,
        ),
      ];

      for (final item in catalog) {
        final existing = await (select(appLanguages)
              ..where((t) => t.id.equals(item.id.value)))
            .getSingleOrNull();
        if (existing == null) {
          await into(appLanguages).insertOnConflictUpdate(item);
        }
      }
    } catch (e, st) {
      AppLogger.warning('Falha ao semear idiomas padrão em app_languages', e, st);
    }
  }

  Future<void> _migrateLandmarksColumns() async {
    try {
      final columns = await customSelect(
        "PRAGMA table_info(territory_landmarks)",
      ).get();
      final colNames = columns.map((c) => c.read<String>('name')).toSet();
      if (colNames.isEmpty) return;
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
    } catch (e, st) {
      AppLogger.error('Erro na migração de colunas territory_landmarks', e, st);
      rethrow;
    }
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
      } catch (e, st) {
        AppLogger.error('Erro na migração de colunas da tabela $tbl', e, st);
        rethrow;
      }
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
    } catch (e, st) {
      AppLogger.error('Erro na migração de app_settings_kv para app_kv_store', e, st);
      rethrow;
    }
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
