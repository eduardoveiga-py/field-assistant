import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

void _createV7SchemaWithoutV8Features(sql.Database sqliteDb) {
  sqliteDb.execute('''
    CREATE TABLE people (
      id TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      phone TEXT,
      address TEXT,
      latitude REAL,
      longitude REAL,
      sector_id TEXT,
      status TEXT NOT NULL DEFAULT 'interessado',
      preferred_schedule TEXT,
      notes TEXT,
      tags TEXT NOT NULL DEFAULT '[]',
      first_contact_at INTEGER NOT NULL,
      last_contact_at INTEGER,
      next_action_at INTEGER,
      next_action_note TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER,
      revision INTEGER NOT NULL DEFAULT 1
    );
  ''');

  sqliteDb.execute('''
    CREATE TABLE sync_queue (
      id TEXT NOT NULL PRIMARY KEY,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      operation TEXT NOT NULL,
      payload TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      attempts INTEGER NOT NULL DEFAULT 0,
      last_error TEXT,
      last_attempt_at INTEGER
    );
  ''');

  sqliteDb.execute('''
    CREATE TABLE app_kv_store (
      key TEXT NOT NULL PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at INTEGER
    );
  ''');

  sqliteDb.execute('''
    CREATE TABLE app_languages (
      id TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      code TEXT NOT NULL,
      symbol TEXT NOT NULL,
      diacritics TEXT NOT NULL DEFAULT '[]',
      is_default INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER,
      revision INTEGER NOT NULL DEFAULT 1
    );
  ''');

  // Tabelas com schema Drift v7 (colunas INTEGER contendo timestamps ISO TEXT legados)
  sqliteDb.execute('''
    CREATE TABLE person_photos (
      id TEXT NOT NULL PRIMARY KEY,
      person_id TEXT NOT NULL,
      photo_type TEXT NOT NULL,
      image_data TEXT NOT NULL DEFAULT '',
      caption TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER,
      deleted_at INTEGER,
      revision INTEGER NOT NULL DEFAULT 1
    );
  ''');

  sqliteDb.execute('''
    CREATE TABLE family_ties (
      id TEXT NOT NULL PRIMARY KEY,
      person_id TEXT NOT NULL,
      related_person_id TEXT,
      related_person_name TEXT NOT NULL,
      relationship_type TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER,
      deleted_at INTEGER,
      revision INTEGER NOT NULL DEFAULT 1
    );
  ''');

  sqliteDb.execute('''
    CREATE TABLE ministry_experiences (
      id TEXT NOT NULL PRIMARY KEY,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      media_urls TEXT NOT NULL DEFAULT '[]',
      tags TEXT NOT NULL DEFAULT '[]',
      date_time INTEGER NOT NULL,
      location_or_modality TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER,
      revision INTEGER NOT NULL DEFAULT 1
    );
  ''');

  sqliteDb.execute('''
    CREATE TABLE person_publications (
      id TEXT NOT NULL PRIMARY KEY,
      person_id TEXT NOT NULL,
      publication_title TEXT NOT NULL,
      item_type TEXT NOT NULL,
      status TEXT NOT NULL,
      date TEXT NOT NULL,
      notes TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER,
      deleted_at INTEGER,
      revision INTEGER NOT NULL DEFAULT 1
    );
  ''');

  sqliteDb.execute('''
    CREATE TABLE research_articles (
      id TEXT NOT NULL PRIMARY KEY,
      title TEXT NOT NULL,
      summary TEXT NOT NULL,
      content TEXT NOT NULL,
      tags TEXT NOT NULL DEFAULT '[]',
      objective TEXT,
      status TEXT NOT NULL DEFAULT 'rascunho',
      conclusion TEXT,
      project_id TEXT,
      main_question_id TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER,
      revision INTEGER NOT NULL DEFAULT 1
    );
  ''');

  sqliteDb.execute('''
    CREATE TABLE research_tags (
      id TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER,
      deleted_at INTEGER,
      revision INTEGER NOT NULL DEFAULT 1
    );
  ''');

  sqliteDb.execute('''
    CREATE TABLE territory_sectors (
      id TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER,
      deleted_at INTEGER,
      revision INTEGER NOT NULL DEFAULT 1
    );
  ''');

  sqliteDb.execute('''
    CREATE TABLE student_manual_order (
      study_id TEXT NOT NULL PRIMARY KEY,
      manual_index INTEGER NOT NULL,
      updated_at INTEGER,
      deleted_at INTEGER,
      revision INTEGER NOT NULL DEFAULT 1
    );
  ''');

  // Tabelas Ticuna legadas sem audio_path, audio_duration_seconds e language_id
  sqliteDb.execute('''
    CREATE TABLE ticuna_words (
      id TEXT PRIMARY KEY,
      word TEXT NOT NULL,
      translation TEXT NOT NULL,
      phonetics TEXT,
      grammatical_class TEXT,
      example_sentence TEXT,
      example_translation TEXT,
      notes TEXT,
      tags TEXT NOT NULL DEFAULT '[]',
      is_favorite INTEGER NOT NULL DEFAULT 0,
      review_level INTEGER NOT NULL DEFAULT 0,
      review_count INTEGER NOT NULL DEFAULT 0,
      last_reviewed_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''');

  sqliteDb.execute('''
    CREATE TABLE ticuna_phrases (
      id TEXT PRIMARY KEY,
      phrase TEXT NOT NULL,
      translation TEXT NOT NULL,
      category TEXT,
      phonetics TEXT,
      notes TEXT,
      tags TEXT NOT NULL DEFAULT '[]',
      is_favorite INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Drift Schema Migration v7 -> v8 (A3, A7, A9)', () {
    test(
      'Normaliza datas TEXT ISO para unix-seconds, adiciona file_path em person_photos, migra tabelas Ticuna e cria índices',
      () async {
        final sqliteDb = sql.sqlite3.openInMemory();
        _createV7SchemaWithoutV8Features(sqliteDb);

        // Insere dados legados v7 com datas ISO TEXT e sem colunas v8
        sqliteDb.execute(
          "INSERT INTO person_photos (id, person_id, photo_type, image_data, created_at, updated_at) "
          "VALUES ('ph_legacy_1', 'p_1', 'person', 'data:image/jpeg;base64,AA==', '2026-10-15T14:30:00.000Z', '2026-10-16T10:00:00.000Z')",
        );
        sqliteDb.execute(
          "INSERT INTO family_ties (id, person_id, related_person_id, related_person_name, relationship_type, created_at, updated_at) "
          "VALUES ('ft_legacy_1', 'p_1', 'p_2', 'Maria Irmã', 'irmã', '2026-09-01T08:00:00.000Z', '2026-09-02T09:00:00.000Z')",
        );
        sqliteDb.execute(
          "INSERT INTO ministry_experiences (id, title, content, date_time, created_at, updated_at) "
          "VALUES ('exp_legacy_1', 'Exp Legada', 'Conteúdo', '2026-08-20T11:15:00.000Z', '2026-08-20T11:15:00.000Z', '2026-08-21T12:00:00.000Z')",
        );
        sqliteDb.execute(
          "INSERT INTO ticuna_words (id, word, translation, created_at, updated_at) "
          "VALUES ('tw_legacy_1', 'Tupana', 'Deus', '2026-08-01T10:00:00.000Z', '2026-08-01T10:00:00.000Z')",
        );
        sqliteDb.execute(
          "INSERT INTO ticuna_phrases (id, phrase, translation, created_at, updated_at) "
          "VALUES ('tp_legacy_1', 'Tamaü', 'Bom dia', '2026-08-01T10:00:00.000Z', '2026-08-01T10:00:00.000Z')",
        );

        sqliteDb.execute('PRAGMA user_version = 7;');

        final appDb = AppDatabase.forTesting(NativeDatabase.opened(sqliteDb));
        addTearDown(appDb.close);

        // Dispara migração v7 -> v8
        final verRow = await appDb.customSelect('PRAGMA user_version;').getSingle();
        expect(verRow.read<int>('user_version'), equals(8));

        // 1. Valida adição de person_photos.file_path e leitura tipada Drift de datas migradas
        final photosCols = await appDb.customSelect('PRAGMA table_info(person_photos)').get();
        expect(photosCols.map((c) => c.read<String>('name')), contains('file_path'));

        final photos = await appDb.select(appDb.personPhotos).get();
        expect(photos.length, equals(1));
        expect(photos.first.id, equals('ph_legacy_1'));
        expect(photos.first.createdAt.toUtc().year, equals(2026));
        expect(photos.first.createdAt.toUtc().month, equals(10));
        expect(photos.first.filePath, isNull);

        // 2. Valida normalização TEXT -> unix-seconds nas demais tabelas Drift
        final ties = await appDb.select(appDb.familyTies).get();
        expect(ties.single.createdAt.toUtc().year, equals(2026));
        expect(ties.single.createdAt.toUtc().month, equals(9));

        final exps = await appDb.select(appDb.ministryExperiences).get();
        expect(exps.single.dateTimeField.toUtc().year, equals(2026));
        expect(exps.single.dateTimeField.toUtc().month, equals(8));

        final photoStorageTypes = await appDb.customSelect(
          "SELECT typeof(created_at) AS t_created, typeof(updated_at) AS t_updated FROM person_photos WHERE id = 'ph_legacy_1'",
        ).getSingle();
        expect(photoStorageTypes.read<String>('t_created'), equals('integer'));
        expect(photoStorageTypes.read<String>('t_updated'), equals('integer'));

        // 3. Valida colunas Ticuna migradas, criação de ticuna_tags e preservação dos registros
        final wordCols = (await appDb.customSelect('PRAGMA table_info(ticuna_words)').get())
            .map((c) => c.read<String>('name'))
            .toSet();
        expect(wordCols, containsAll(['audio_path', 'audio_duration_seconds', 'language_id']));

        final phraseCols = (await appDb.customSelect('PRAGMA table_info(ticuna_phrases)').get())
            .map((c) => c.read<String>('name'))
            .toSet();
        expect(phraseCols, containsAll(['audio_path', 'audio_duration_seconds', 'language_id']));

        final ticunaTagsTable = await appDb.customSelect(
          "SELECT count(*) AS c FROM sqlite_master WHERE type='table' AND name='ticuna_tags'",
        ).getSingle();
        expect(ticunaTagsTable.read<int>('c'), equals(1));

        final legacyWord = await appDb.customSelect(
          "SELECT language_id FROM ticuna_words WHERE id = 'tw_legacy_1'",
        ).getSingle();
        expect(legacyWord.read<String>('language_id'), equals('tca'));

        // 4. Valida índices de performance criados na v8
        final indexes = (await appDb.customSelect(
          "SELECT name FROM sqlite_master WHERE type='index'",
        ).get())
            .map((r) => r.read<String>('name'))
            .toSet();
        expect(
          indexes,
          containsAll([
            'idx_people_name',
            'idx_people_deleted_at',
            'idx_sync_queue_status',
          ]),
        );
      },
    );

    test(
      'Propaga falha estrutural durante migração sem silenciar erro (fail-loud)',
      () async {
        final sqliteDb = sql.sqlite3.openInMemory();
        // Simula conflito estrutural: VIEW chamada ticuna_words impede criação da tabela na v8
        sqliteDb.execute("CREATE VIEW ticuna_words AS SELECT 'w1' AS id;");
        sqliteDb.execute('PRAGMA user_version = 7;');

        final appDb = AppDatabase.forTesting(NativeDatabase.opened(sqliteDb));
        await expectLater(
          () => appDb.customSelect('SELECT 1').get(),
          throwsA(isA<Exception>()),
        );
        await appDb.close();
      },
    );
  });
}
