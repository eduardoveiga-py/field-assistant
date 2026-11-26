import 'dart:convert';

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
    EmailAccounts,
    KnowledgeAreas,
    KnowledgeLinks,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? impl.constructDb());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 9;

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
      if (from < 9) {
        // Migração incremental da versão 8 para a versão 9:
        // - Adiciona EmailAccounts (metadados multi-contas sem senhas para sync E2EE)
        // - Adiciona KnowledgeAreas (P.A.R.A.) e KnowledgeLinks (Backlinks bidirecionais)
        // - Adiciona colunas de área, subpáginas, propriedades, revisão espaçada e texto PDF
        await _createTableIfNotExists(m, emailAccounts);
        await _createTableIfNotExists(m, knowledgeAreas);
        await _createTableIfNotExists(m, knowledgeLinks);
        await _migrateV9Columns(m);
        await _migrateLegacyEmailAccountsToTable();
        await _ensurePerformanceIndexes();
      }
    },
    beforeOpen: (details) async {
      await _ensureAppKvStoreUpdatedAt();
      await _ensurePerformanceIndexes();
      await _seedDefaultLanguage();
    },
  );

  Future<void> _migrateV9Columns(Migrator m) async {
    Future<void> addCols(
      String tableName,
      Future<void> Function(Set<String> cols) apply,
    ) async {
      final exists = await customSelect(
        "SELECT count(*) as count FROM sqlite_master WHERE type='table' AND name=?",
        variables: [Variable.withString(tableName)],
      ).getSingle();
      if (exists.read<int>('count') == 0) return;
      final columns = await customSelect('PRAGMA table_info($tableName)').get();
      final colNames = columns.map((c) => c.read<String>('name')).toSet();
      await apply(colNames);
    }

    await addCols('projects', (cols) async {
      if (!cols.contains('area_id')) {
        await m.addColumn(projects, projects.areaId);
      }
    });

    await addCols('knowledge_notes', (cols) async {
      if (!cols.contains('area_id')) {
        await m.addColumn(knowledgeNotes, knowledgeNotes.areaId);
      }
      if (!cols.contains('parent_note_id')) {
        await m.addColumn(knowledgeNotes, knowledgeNotes.parentNoteId);
      }
      if (!cols.contains('properties_json')) {
        await m.addColumn(knowledgeNotes, knowledgeNotes.propertiesJson);
      }
      if (!cols.contains('review_level')) {
        await m.addColumn(knowledgeNotes, knowledgeNotes.reviewLevel);
      }
      if (!cols.contains('next_review_at')) {
        await m.addColumn(knowledgeNotes, knowledgeNotes.nextReviewAt);
      }
      if (!cols.contains('last_reviewed_at')) {
        await m.addColumn(knowledgeNotes, knowledgeNotes.lastReviewedAt);
      }
    });

    await addCols('knowledge_questions', (cols) async {
      if (!cols.contains('area_id')) {
        await m.addColumn(knowledgeQuestions, knowledgeQuestions.areaId);
      }
      if (!cols.contains('review_level')) {
        await m.addColumn(knowledgeQuestions, knowledgeQuestions.reviewLevel);
      }
      if (!cols.contains('next_review_at')) {
        await m.addColumn(knowledgeQuestions, knowledgeQuestions.nextReviewAt);
      }
      if (!cols.contains('last_reviewed_at')) {
        await m.addColumn(
          knowledgeQuestions,
          knowledgeQuestions.lastReviewedAt,
        );
      }
    });

    await addCols('knowledge_documents', (cols) async {
      if (!cols.contains('area_id')) {
        await m.addColumn(knowledgeDocuments, knowledgeDocuments.areaId);
      }
      if (!cols.contains('extracted_text')) {
        await m.addColumn(knowledgeDocuments, knowledgeDocuments.extractedText);
      }
    });

    await addCols('knowledge_resources', (cols) async {
      if (!cols.contains('area_id')) {
        await m.addColumn(knowledgeResources, knowledgeResources.areaId);
      }
    });
  }

  Future<void> _migrateLegacyEmailAccountsToTable() async {
    try {
      final hasKv = await customSelect(
        "SELECT count(*) as count FROM sqlite_master WHERE type='table' AND name='app_kv_store'",
      ).getSingle();
      if (hasKv.read<int>('count') == 0) return;

      final existingCountRow = await customSelect(
        'SELECT count(*) as count FROM email_accounts',
      ).getSingle();
      if (existingCountRow.read<int>('count') > 0) return;

      final hasSyncQueueRow = await customSelect(
        "SELECT count(*) as count FROM sqlite_master WHERE type='table' AND name='sync_queue'",
      ).getSingle();
      final hasSyncQueue = hasSyncQueueRow.read<int>('count') > 0;

      final row =
          await (select(appKvStore)
                ..where((t) => t.key.equals('multi_email_accounts_registry')))
              .getSingleOrNull();
      final items = <Map<String, dynamic>>[];
      if (row != null && row.value.trim().isNotEmpty) {
        final decoded = jsonDecode(row.value);
        if (decoded is List) {
          for (final e in decoded) {
            if (e is Map) {
              items.add(Map<String, dynamic>.from(e));
            }
          }
        }
      }

      if (items.isEmpty) {
        final legacyImapEmail = await (select(
          appKvStore,
        )..where((t) => t.key.equals('jw_imap_email'))).getSingleOrNull();
        final legacyEasEmail = await (select(
          appKvStore,
        )..where((t) => t.key.equals('jw_eas_email'))).getSingleOrNull();
        final protocol = await (select(
          appKvStore,
        )..where((t) => t.key.equals('jw_mail_protocol'))).getSingleOrNull();

        if (protocol?.value == 'exchange' &&
            legacyEasEmail?.value.isNotEmpty == true) {
          final host = await (select(
            appKvStore,
          )..where((t) => t.key.equals('jw_eas_host'))).getSingleOrNull();
          items.add({
            'id': 'legacy_eas_account',
            'name': 'Exchange Principal',
            'email': legacyEasEmail!.value,
            'providerType': 'exchange',
            'incomingHost': host?.value.isNotEmpty == true
                ? host!.value
                : 'outlook.office365.com',
            'incomingPort': 443,
            'incomingProtocol': 'exchange',
            'outgoingHost': host?.value.isNotEmpty == true
                ? host!.value
                : 'outlook.office365.com',
            'outgoingPort': 443,
            'outgoingSecurity': 'ssl',
            'outgoingProtocol': 'exchange',
            'username': legacyEasEmail.value,
            'isActive': true,
          });
        } else if (legacyImapEmail?.value.isNotEmpty == true) {
          final host = await (select(
            appKvStore,
          )..where((t) => t.key.equals('jw_imap_host'))).getSingleOrNull();
          items.add({
            'id': 'legacy_imap_account',
            'name': 'JWPUB Principal',
            'email': legacyImapEmail!.value,
            'providerType': 'jwpub',
            'incomingHost': host?.value.isNotEmpty == true
                ? host!.value
                : 'mail.jw.org',
            'incomingPort': 993,
            'incomingProtocol': 'imap',
            'outgoingHost': host?.value.isNotEmpty == true
                ? host!.value
                : 'mail.jw.org',
            'outgoingPort': 587,
            'outgoingSecurity': 'starttls',
            'outgoingProtocol': 'smtp',
            'username': legacyImapEmail.value,
            'isActive': true,
          });
        }
      }

      final now = DateTime.now();
      for (final raw in items) {
        final email = (raw['email']?.toString() ?? '').trim();
        final id = (raw['id']?.toString() ?? '').trim();
        if (email.isEmpty || id.isEmpty) continue;
        final createdAt = raw['createdAt'] != null
            ? (DateTime.tryParse(raw['createdAt'].toString()) ?? now)
            : now;
        final incProto = raw['incomingProtocol']?.toString() ?? 'imap';
        final companion = EmailAccountsCompanion.insert(
          id: id,
          name: (raw['name']?.toString().trim().isNotEmpty == true)
              ? raw['name'].toString().trim()
              : email,
          email: email,
          providerType: raw['providerType']?.toString() ?? 'custom',
          incomingHost: Value(raw['incomingHost']?.toString() ?? ''),
          incomingPort: Value((raw['incomingPort'] as num?)?.toInt() ?? 993),
          incomingProtocol: Value(incProto),
          outgoingHost: Value(raw['outgoingHost']?.toString() ?? ''),
          outgoingPort: Value((raw['outgoingPort'] as num?)?.toInt() ?? 587),
          outgoingSecurity: Value(
            raw['outgoingSecurity']?.toString() ?? 'starttls',
          ),
          outgoingProtocol: Value(
            raw['outgoingProtocol']?.toString() ??
                (incProto == 'exchange' ? 'exchange' : 'smtp'),
          ),
          username: Value(raw['username']?.toString() ?? email),
          isActive: Value(raw['isActive'] as bool? ?? true),
          signatureHtml: Value(raw['signatureHtml']?.toString() ?? ''),
          createdAt: createdAt,
          updatedAt: now,
        );
        await into(emailAccounts).insertOnConflictUpdate(companion);
        if (hasSyncQueue) {
          final inserted = await (select(
            emailAccounts,
          )..where((t) => t.id.equals(id))).getSingle();
          await into(syncQueue).insertOnConflictUpdate(
            SyncQueueCompanion.insert(
              id: 'mig_email_$id',
              entityType: 'email_accounts',
              entityId: id,
              operation: 'INSERT',
              payload: jsonEncode(
                SyncTimestamp.normalizeMapDates(inserted.toJson()),
              ),
              createdAt: now,
            ),
          );
        }
      }
    } catch (e, st) {
      AppLogger.warning(
        'Falha ao migrar contas de e-mail legadas para tabela tipada email_accounts',
        e,
        st,
      );
    }
  }

  Future<void> _ensurePerformanceIndexes() async {
    final rows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('people', 'sync_queue', 'appointments', 'visits', 'projects', 'knowledge_notes', 'knowledge_links', 'email_accounts')",
    ).get();
    final existing = rows.map((r) => r.read<String>('name')).toSet();
    if (existing.contains('people')) {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_people_name ON people(name COLLATE NOCASE);',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_people_deleted_at ON people(deleted_at);',
      );
      final cols = await customSelect('PRAGMA table_info(people)').get();
      final colNames = cols.map((c) => c.read<String>('name')).toSet();
      if (colNames.contains('latitude') && colNames.contains('longitude')) {
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_people_coords ON people(latitude, longitude) WHERE latitude IS NOT NULL AND longitude IS NOT NULL;',
        );
      }
    }
    if (existing.contains('sync_queue')) {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue(status, created_at);',
      );
    }
    if (existing.contains('appointments')) {
      final cols = await customSelect('PRAGMA table_info(appointments)').get();
      final colNames = cols.map((c) => c.read<String>('name')).toSet();
      if (colNames.contains('start_time')) {
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_appointments_start_time ON appointments(start_time);',
        );
      }
      if (colNames.contains('person_id')) {
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_appointments_person_id ON appointments(person_id);',
        );
      }
    }
    if (existing.contains('visits')) {
      final cols = await customSelect('PRAGMA table_info(visits)').get();
      final colNames = cols.map((c) => c.read<String>('name')).toSet();
      if (colNames.contains('person_id')) {
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_visits_person_id ON visits(person_id);',
        );
      }
    }
    if (existing.contains('projects')) {
      final cols = await customSelect('PRAGMA table_info(projects)').get();
      final colNames = cols.map((c) => c.read<String>('name')).toSet();
      if (colNames.contains('area_id')) {
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_projects_area ON projects(area_id);',
        );
      }
    }
    if (existing.contains('knowledge_notes')) {
      final cols = await customSelect('PRAGMA table_info(knowledge_notes)')
          .get();
      final colNames = cols.map((c) => c.read<String>('name')).toSet();
      if (colNames.contains('parent_note_id')) {
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_knowledge_notes_parent ON knowledge_notes(parent_note_id);',
        );
      }
      if (colNames.contains('area_id')) {
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_knowledge_notes_area ON knowledge_notes(area_id);',
        );
      }
      if (colNames.contains('next_review_at')) {
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_knowledge_notes_next_review ON knowledge_notes(next_review_at);',
        );
      }
    }
    if (existing.contains('knowledge_links')) {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_knowledge_links_target ON knowledge_links(target_type, target_id, deleted_at);',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_knowledge_links_source ON knowledge_links(source_type, source_id, deleted_at);',
      );
    }
    if (existing.contains('email_accounts')) {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_email_accounts_email ON email_accounts(email COLLATE NOCASE);',
      );
    }
  }

  Future<void> _migratePersonPhotosFilePath(Migrator m) async {
    final tableCheck = await customSelect(
      "SELECT count(*) as count FROM sqlite_master WHERE type='table' AND name='person_photos'",
    ).getSingle();
    if (tableCheck.read<int>('count') == 0) return;
    final columns = await customSelect("PRAGMA table_info(person_photos)")
        .get();
    final colNames = columns.map((c) => c.read<String>('name')).toSet();
    if (colNames.isNotEmpty && !colNames.contains('file_path')) {
      await m.addColumn(personPhotos, personPhotos.filePath);
    }
  }

  Future<void> _migrateTicunaLegacyColumns() async {
    final ticunaColumnsByTable = <String, Map<String, String>>{
      'ticuna_words': {
        'audio_path': 'ALTER TABLE ticuna_words ADD COLUMN audio_path TEXT;',
        'audio_duration_seconds': 'ALTER TABLE ticuna_words ADD COLUMN audio_duration_seconds INTEGER;',
        'language_id': "ALTER TABLE ticuna_words ADD COLUMN language_id TEXT DEFAULT 'tca';",
      },
      'ticuna_phrases': {
        'audio_path': 'ALTER TABLE ticuna_phrases ADD COLUMN audio_path TEXT;',
        'audio_duration_seconds': 'ALTER TABLE ticuna_phrases ADD COLUMN audio_duration_seconds INTEGER;',
        'language_id': "ALTER TABLE ticuna_phrases ADD COLUMN language_id TEXT DEFAULT 'tca';",
      },
    };
    for (final entry in ticunaColumnsByTable.entries) {
      final columns = await customSelect('PRAGMA table_info(${entry.key})')
          .get();
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
      'ministry_experiences': [
        'date_time',
        'created_at',
        'updated_at',
        'deleted_at',
      ],
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
          await customStatement('UPDATE $table SET $col = ? WHERE rowid = ?', [
            replacement == null
                ? null
                : replacement.millisecondsSinceEpoch ~/ 1000,
            rid,
          ]);
        }
      }
    }
  }

  Future<void> _migrateAppKvStoreUpdatedAt(Migrator m) async {
    final columns = await customSelect("PRAGMA table_info(app_kv_store)").get();
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
        final columns = await customSelect("PRAGMA table_info(app_kv_store)")
            .get();
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
    final columns = await customSelect("PRAGMA table_info(appointments)").get();
    final colNames = columns.map((c) => c.read<String>('name')).toSet();
    if (colNames.isNotEmpty && !colNames.contains('task_id')) {
      await m.addColumn(appointments, appointments.taskId);
    }
  }

  Future<void> _migrateResearchArticlesContextColumns(Migrator m) async {
    final columns = await customSelect("PRAGMA table_info(research_articles)")
        .get();
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
    final columns = await customSelect("PRAGMA table_info(sync_queue)").get();
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
          diacritics: const Value('["ñ","á","é","í","ó","ú","ü","¡","¿"]'),
          isDefault: const Value(false),
          createdAt: now,
          updatedAt: now,
        ),
        AppLanguagesCompanion.insert(
          id: 'gub',
          name: 'Guajajara (Tenetehara)',
          code: 'gub',
          symbol: '🌿',
          diacritics: const Value('["à","è","ì","ò","ù","ỹ","\'"]'),
          isDefault: const Value(false),
          createdAt: now,
          updatedAt: now,
        ),
        AppLanguagesCompanion.insert(
          id: 'yan',
          name: 'Yanomami (Yanomamõ)',
          code: 'yan',
          symbol: '🌳',
          diacritics: const Value('["ë","ɨ","th","rh"]'),
          isDefault: const Value(false),
          createdAt: now,
          updatedAt: now,
        ),
      ];

      for (final item in catalog) {
        final existing = await (select(
          appLanguages,
        )..where((t) => t.id.equals(item.id.value))).getSingleOrNull();
        if (existing == null) {
          await into(appLanguages).insertOnConflictUpdate(item);
        }
      }
    } catch (e, st) {
      AppLogger.warning(
        'Falha ao semear idiomas padrão em app_languages',
        e,
        st,
      );
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
      AppLogger.error(
        'Erro na migração de app_settings_kv para app_kv_store',
        e,
        st,
      );
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
