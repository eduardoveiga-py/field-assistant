import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
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
      expect(ver.read<int>('user_version'), equals(4));

      // 3. Valida migração de dados de app_settings_kv para app_kv_store
      final kvManager = AppSettingsManager(appDb);
      final theme = await kvManager.getString('theme_mode');
      final duration = await kvManager.getString('timer_duration');
      expect(theme, equals('sunMode'));
      expect(duration, equals('3600'));

      // Confirma que app_settings_kv foi limpa/dropada
      final checkOldKv = await appDb
          .customSelect(
            "SELECT count(*) as count FROM sqlite_master WHERE type='table' AND name='app_settings_kv'",
          )
          .getSingle();
      expect(checkOldKv.read<int>('count'), equals(0));

      // 4. Valida que territory_landmarks recebeu as novas colunas
      final landmarks = await (appDb.select(
        appDb.territoryLandmarks,
      )..where((t) => t.deletedAt.isNull())).get();
      expect(landmarks.length, equals(1));
      expect(landmarks.first.name, equals('Padaria Central'));
      expect(landmarks.first.revision, equals(1));

      // 5. Valida que tabelas novas v2 e v3 existem e funcionam normalmente
      final vnCount = await (appDb.select(appDb.voiceNotes)).get();
      expect(vnCount, isEmpty);
      final pcCount = await (appDb.select(appDb.phoneContacts)).get();
      expect(pcCount, isEmpty);
      final expCount = await (appDb.select(appDb.ministryExperiences)).get();
      expect(expCount, isEmpty);
      final calCount = await (appDb.select(appDb.externalCalendarEvents)).get();
      expect(calCount, isEmpty);

      await appDb.close();
    });

    test('TC-MIG-02: Migração incremental v2 para v3 com preservação total de tabelas customizadas', () async {
      final sqliteDb = sql.sqlite3.openInMemory();

      // Inicializa schema v2 mínimo
      sqliteDb.execute('PRAGMA user_version = 2;');
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
      sqliteDb.execute('''
        CREATE TABLE app_kv_store (
          key TEXT NOT NULL PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at INTEGER
        );
      ''');

      // Cria tabelas customizadas legadas (versão raw SQL anterior à tipagem v3)
      sqliteDb.execute('''
        CREATE TABLE ministry_experiences (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          media_urls TEXT NOT NULL DEFAULT '[]',
          tags TEXT NOT NULL DEFAULT '[]',
          date_time INTEGER NOT NULL,
          location_or_modality TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');
      sqliteDb.execute('''
        INSERT INTO ministry_experiences (id, title, content, media_urls, tags, date_time, location_or_modality, created_at, updated_at)
        VALUES ('exp_1', 'Conversa sobre Esperança', 'Excelente conversa no ponto de ônibus', '[]', '[]', 1700000000000, 'Metrô', 1700000000000, 1700000000000);
      ''');

      sqliteDb.execute('''
        CREATE TABLE research_articles (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          summary TEXT NOT NULL,
          content TEXT NOT NULL,
          tags TEXT NOT NULL DEFAULT '[]',
          attachments TEXT NOT NULL DEFAULT '[]',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');
      sqliteDb.execute('''
        INSERT INTO research_articles (id, title, summary, content, tags, attachments, created_at, updated_at)
        VALUES ('art_1', 'Por que Deus permite o sofrimento?', 'Resumo bíblico', 'Conteúdo detalhado com textos', '[]', '[]', 1700000000000, 1700000000000);
      ''');

      // Instancia AppDatabase que aplicará a migração incremental para v3
      final appDb = AppDatabase.forTesting(NativeDatabase.opened(sqliteDb));

      // Dispara a migração
      final ver = await appDb.customSelect('PRAGMA user_version;').getSingle();
      expect(ver.read<int>('user_version'), equals(4));

      // Verifica 100% de preservação dos dados legados de ministry_experiences
      final experiences = await appDb.select(appDb.ministryExperiences).get();
      expect(experiences.length, equals(1));
      expect(experiences.first.id, equals('exp_1'));
      expect(experiences.first.title, equals('Conversa sobre Esperança'));
      expect(
        experiences.first.revision,
        equals(1),
      ); // Coluna adicionada dinamicamente

      // Verifica 100% de preservação de research_articles
      final articles = await appDb.select(appDb.researchArticles).get();
      expect(articles.length, equals(1));
      expect(articles.first.id, equals('art_1'));
      expect(
        articles.first.title,
        equals('Por que Deus permite o sofrimento?'),
      );

      // Verifica que as tabelas de calendário foram criadas
      final calEvents = await appDb.select(appDb.externalCalendarEvents).get();
      expect(calEvents, isEmpty);
      final calLinks = await appDb.select(appDb.calendarEventLinks).get();
      expect(calLinks, isEmpty);

      await appDb.close();
    });

    test('TC-MIG-03: Migração completa e verificação exaustiva de TODAS as 8 tabelas legadas v2 para v3 com reabertura', () async {
      final sqliteDb = sql.sqlite3.openInMemory();

      // 1. Schema v2 inicial
      sqliteDb.execute('PRAGMA user_version = 2;');
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
      sqliteDb.execute(
        "INSERT INTO people (id, name, first_contact_at, created_at, updated_at) VALUES ('p_1', 'João Silva', 1700000000000, 1700000000000, 1700000000000);",
      );

      // 1. family_ties
      sqliteDb.execute('''
        CREATE TABLE family_ties (
          id TEXT PRIMARY KEY,
          person_id TEXT NOT NULL,
          related_person_id TEXT,
          related_person_name TEXT NOT NULL,
          relationship_type TEXT NOT NULL,
          created_at INTEGER NOT NULL
        );
      ''');
      sqliteDb.execute(
        "INSERT INTO family_ties (id, person_id, related_person_name, relationship_type, created_at) VALUES ('ft_1', 'p_1', 'Maria Silva', 'esposa', 1700000000000);",
      );

      // 2. ministry_experiences
      sqliteDb.execute('''
        CREATE TABLE ministry_experiences (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          media_urls TEXT NOT NULL DEFAULT '[]',
          tags TEXT NOT NULL DEFAULT '[]',
          date_time INTEGER NOT NULL,
          location_or_modality TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');
      sqliteDb.execute(
        "INSERT INTO ministry_experiences (id, title, content, date_time, created_at, updated_at) VALUES ('exp_1', 'Experiência Marcante', 'Conversa na praça', 1700000000000, 1700000000000, 1700000000000);",
      );

      // 3. person_photos
      sqliteDb.execute('''
        CREATE TABLE person_photos (
          id TEXT PRIMARY KEY,
          person_id TEXT NOT NULL,
          photo_type TEXT NOT NULL,
          image_data TEXT NOT NULL,
          created_at INTEGER NOT NULL
        );
      ''');
      sqliteDb.execute(
        "INSERT INTO person_photos (id, person_id, photo_type, image_data, created_at) VALUES ('photo_1', 'p_1', 'fachada', 'base64_data_teste', 1700000000000);",
      );

      // 4. person_publications
      sqliteDb.execute('''
        CREATE TABLE person_publications (
          id TEXT PRIMARY KEY,
          person_id TEXT NOT NULL,
          publication_title TEXT NOT NULL,
          item_type TEXT NOT NULL,
          status TEXT NOT NULL,
          date TEXT NOT NULL,
          notes TEXT,
          created_at INTEGER NOT NULL
        );
      ''');
      sqliteDb.execute(
        "INSERT INTO person_publications (id, person_id, publication_title, item_type, status, date, created_at) VALUES ('pub_1', 'p_1', 'A Sentinela', 'revista', 'entregue', '2026-10-01', 1700000000000);",
      );

      // 5. research_articles
      sqliteDb.execute('''
        CREATE TABLE research_articles (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          summary TEXT NOT NULL,
          content TEXT NOT NULL,
          tags TEXT NOT NULL DEFAULT '[]',
          attachments TEXT NOT NULL DEFAULT '[]',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');
      sqliteDb.execute(
        "INSERT INTO research_articles (id, title, summary, content, created_at, updated_at) VALUES ('art_1', 'Artigo de Pesquisa', 'Resumo', 'Conteúdo da pesquisa', 1700000000000, 1700000000000);",
      );

      // 6. research_tags
      sqliteDb.execute('''
        CREATE TABLE research_tags (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          created_at INTEGER NOT NULL
        );
      ''');
      sqliteDb.execute(
        "INSERT INTO research_tags (id, name, created_at) VALUES ('tag_1', 'Doutrina', 1700000000000);",
      );

      // 7. territory_sectors
      sqliteDb.execute('''
        CREATE TABLE territory_sectors (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          created_at INTEGER NOT NULL
        );
      ''');
      sqliteDb.execute(
        "INSERT INTO territory_sectors (id, name, description, created_at) VALUES ('sec_1', 'Vila Nova', 'Setor comercial', 1700000000000);",
      );

      // 8. student_manual_order
      sqliteDb.execute('''
        CREATE TABLE student_manual_order (
          study_id TEXT PRIMARY KEY,
          manual_index INTEGER NOT NULL
        );
      ''');
      sqliteDb.execute(
        "INSERT INTO student_manual_order (study_id, manual_index) VALUES ('study_1', 4);",
      );

      // 2. Executa a migração abrindo o banco com AppDatabase
      var appDb = AppDatabase.forTesting(
        NativeDatabase.opened(sqliteDb, closeUnderlyingOnClose: false),
      );

      final ver = await appDb.customSelect('PRAGMA user_version;').getSingle();
      expect(ver.read<int>('user_version'), equals(4));

      // 3. Validação individual exaustiva de cada uma das 8 tabelas:
      // Tabela 1: family_ties
      final ftList = await appDb.select(appDb.familyTies).get();
      expect(ftList.length, equals(1));
      expect(ftList.first.id, equals('ft_1'));
      expect(ftList.first.personId, equals('p_1'));
      expect(ftList.first.relatedPersonName, equals('Maria Silva'));
      expect(ftList.first.relationshipType, equals('esposa'));
      expect(ftList.first.revision, equals(1));

      // Tabela 2: ministry_experiences
      final expList = await appDb.select(appDb.ministryExperiences).get();
      expect(expList.length, equals(1));
      expect(expList.first.id, equals('exp_1'));
      expect(expList.first.title, equals('Experiência Marcante'));
      expect(expList.first.revision, equals(1));

      // Tabela 3: person_photos
      final photoList = await appDb.select(appDb.personPhotos).get();
      expect(photoList.length, equals(1));
      expect(photoList.first.id, equals('photo_1'));
      expect(photoList.first.photoType, equals('fachada'));
      expect(photoList.first.imageData, equals('base64_data_teste'));
      expect(photoList.first.revision, equals(1));

      // Tabela 4: person_publications
      final pubList = await appDb.select(appDb.personPublications).get();
      expect(pubList.length, equals(1));
      expect(pubList.first.id, equals('pub_1'));
      expect(pubList.first.publicationTitle, equals('A Sentinela'));
      expect(pubList.first.status, equals('entregue'));
      expect(pubList.first.revision, equals(1));

      // Tabela 5: research_articles
      final artList = await appDb.select(appDb.researchArticles).get();
      expect(artList.length, equals(1));
      expect(artList.first.id, equals('art_1'));
      expect(artList.first.title, equals('Artigo de Pesquisa'));
      expect(artList.first.revision, equals(1));

      // Tabela 6: research_tags
      final tagList = await appDb.select(appDb.researchTags).get();
      expect(tagList.length, equals(1));
      expect(tagList.first.id, equals('tag_1'));
      expect(tagList.first.name, equals('Doutrina'));
      expect(tagList.first.revision, equals(1));

      // Tabela 7: territory_sectors
      final secList = await appDb.select(appDb.territorySectors).get();
      expect(secList.length, equals(1));
      expect(secList.first.id, equals('sec_1'));
      expect(secList.first.name, equals('Vila Nova'));
      expect(secList.first.revision, equals(1));

      // Tabela 8: student_manual_order
      final smoList = await appDb.select(appDb.studentManualOrder).get();
      expect(smoList.length, equals(1));
      expect(smoList.first.studyId, equals('study_1'));
      expect(smoList.first.manualIndex, equals(4));
      expect(smoList.first.revision, equals(1));

      // 4. Reabertura do banco após migração: confirma durabilidade e ausência de repetição destrutiva
      await appDb.close();
      final appDbReopened = AppDatabase.forTesting(
        NativeDatabase.opened(sqliteDb, closeUnderlyingOnClose: false),
      );
      final verReopened = await appDbReopened
          .customSelect('PRAGMA user_version;')
          .getSingle();
      expect(verReopened.read<int>('user_version'), equals(4));
      expect(
        (await appDbReopened.select(appDbReopened.familyTies).get()).length,
        equals(1),
      );
      expect(
        (await appDbReopened.select(appDbReopened.studentManualOrder).get())
            .first
            .manualIndex,
        equals(4),
      );
      await appDbReopened.close();
      sqliteDb.close();
    });

    test('TC-MIG-04: Migração incremental v3 para v4 com pending_resolution em calendar_event_links', () async {
      final sqliteDb = sql.sqlite3.openInMemory();

      // Inicializa schema v3 com calendar_event_links sem a coluna pending_resolution
      sqliteDb.execute('PRAGMA user_version = 3;');
      sqliteDb.execute('''
        CREATE TABLE calendar_event_links (
          id TEXT NOT NULL PRIMARY KEY,
          appointment_id TEXT NOT NULL,
          external_event_id TEXT NOT NULL,
          provider TEXT NOT NULL,
          sync_status TEXT NOT NULL DEFAULT 'synced',
          last_error TEXT,
          local_revision_at_sync INTEGER NOT NULL DEFAULT 1,
          external_etag_at_sync TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER,
          revision INTEGER NOT NULL DEFAULT 1
        );
      ''');
      sqliteDb.execute('''
        INSERT INTO calendar_event_links (id, appointment_id, external_event_id, provider, sync_status, created_at, updated_at)
        VALUES ('link_v3', 'appt_1', 'ext_1', 'google', 'conflict', 1700000000000, 1700000000000);
      ''');

      // Instancia AppDatabase que aplicará a migração v3 -> v4
      final appDb = AppDatabase.forTesting(NativeDatabase.opened(sqliteDb));

      final ver = await appDb.customSelect('PRAGMA user_version;').getSingle();
      expect(ver.read<int>('user_version'), equals(4));

      // Verifica que os dados foram preservados e a coluna pending_resolution existe e é acessível
      final link = await (appDb.select(
        appDb.calendarEventLinks,
      )..where((t) => t.id.equals('link_v3'))).getSingle();
      expect(link.id, equals('link_v3'));
      expect(link.syncStatus, equals('conflict'));
      expect(link.pendingResolution, isNull);

      // Testa escrita na nova coluna
      await (appDb.update(
        appDb.calendarEventLinks,
      )..where((t) => t.id.equals('link_v3'))).write(
        const CalendarEventLinksCompanion(
          pendingResolution: Value('keep_local'),
        ),
      );

      final updated = await (appDb.select(
        appDb.calendarEventLinks,
      )..where((t) => t.id.equals('link_v3'))).getSingle();
      expect(updated.pendingResolution, equals('keep_local'));

      await appDb.close();
    });
  });
}
