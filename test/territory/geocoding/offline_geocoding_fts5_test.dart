import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/territory/geocoding/offline_geocoding_service.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File searchDbFile;
  late AppDatabase appDb;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fts5_search_test_');
    searchDbFile = File('${tempDir.path}/am_solimoes.search.db');

    // Cria tabela virtual SQLite FTS5 conforme especificação
    final db = sql.sqlite3.open(searchDbFile.path);
    db.execute('''
      CREATE VIRTUAL TABLE osm_places_fts USING fts5(
        name,
        category,
        subtitle,
        lat UNINDEXED,
        lng UNINDEXED,
        tokenize='unicode61 remove_diacritics 2'
      );
    ''');

    final stmt = db.prepare(
      'INSERT INTO osm_places_fts (name, category, subtitle, lat, lng) VALUES (?, ?, ?, ?, ?);',
    );
    // Ruas, comunidades e POIs com acentos em Português e nomes amazônicos/indígenas
    stmt.execute([
      'Rua São Sebastião',
      'street',
      'Bairro da Esperança',
      '-3.1020',
      '-60.0200',
    ]);
    stmt.execute([
      'Comunidade Boa Esperança',
      'place',
      'Alto Solimões',
      '-3.5000',
      '-68.0000',
    ]);
    stmt.execute([
      'Aldeia São Jerônimo Ticuna',
      'place',
      'Terra Indígena Éware',
      '-3.7000',
      '-69.1000',
    ]);
    stmt.execute([
      'Farmácia Coração de Jesus',
      'poi',
      'Centro Comercial',
      '-3.1100',
      '-60.0300',
    ]);
    stmt.close();
    db.close();

    appDb = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await appDb.close();
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('Offline FTS5 Geocoding Service (Phase 3)', () {
    test(
      'Accent-insensitive search matches Português and indigenous names',
      () async {
        // 1. Busca sem acento para encontrar "Rua São Sebastião"
        final resSemAcento = await OfflineGeocodingService.searchOffline(
          query: 'Sao Sebastiao',
          db: appDb,
          packagesDir: tempDir,
        );
        expect(resSemAcento, isNotEmpty);
        expect(resSemAcento.first.title, equals('Rua São Sebastião'));
        expect(resSemAcento.first.type, equals(LocalResultType.street));
        expect(resSemAcento.first.origin, equals('am_solimoes.search.db'));
        expect(resSemAcento.first.latitude, equals(-3.1020));
        expect(resSemAcento.first.longitude, equals(-60.0200));

        // 2. Busca com acento idêntico
        final resComAcento = await OfflineGeocodingService.searchOffline(
          query: 'São Sebastião',
          db: appDb,
          packagesDir: tempDir,
        );
        expect(resComAcento, isNotEmpty);
        expect(resComAcento.first.title, equals('Rua São Sebastião'));

        // 3. Busca por POI sem acento "Farmacia" e "Coracao"
        final resPoi = await OfflineGeocodingService.searchOffline(
          query: 'farmacia coracao',
          db: appDb,
          packagesDir: tempDir,
        );
        expect(resPoi, isNotEmpty);
        expect(resPoi.first.title, equals('Farmácia Coração de Jesus'));
        expect(resPoi.first.type, equals(LocalResultType.poi));

        // 4. Busca por comunidade indígena "Jeronimo Ticuna"
        final resComunidade = await OfflineGeocodingService.searchOffline(
          query: 'Jeronimo Ticuna',
          db: appDb,
          packagesDir: tempDir,
        );
        expect(resComunidade, isNotEmpty);
        expect(resComunidade.first.title, equals('Aldeia São Jerônimo Ticuna'));
        expect(resComunidade.first.type, equals(LocalResultType.place));
      },
    );

    test(
      'Merges and deduplicates local app DB records with OSM search.db',
      () async {
        final now = DateTime.now().toUtc();
        // Insere contato local no app DB
        await appDb
            .into(appDb.people)
            .insert(
              PeopleCompanion.insert(
                id: 'p-local-1',
                name: 'Sebastião Silva',
                address: const Value('Rua das Acácias, 10'),
                latitude: const Value(-3.1000),
                longitude: const Value(-60.0100),
                firstContactAt: now,
                createdAt: now,
                updatedAt: now,
              ),
            );

        // Busca por "Sebastiao" deve trazer tanto o contato local quanto a rua do OSM
        final merged = await OfflineGeocodingService.searchOffline(
          query: 'Sebastiao',
          db: appDb,
          packagesDir: tempDir,
        );

        expect(merged.length, greaterThanOrEqualTo(2));
        final localContact = merged.firstWhere(
          (r) => r.type == LocalResultType.contact,
        );
        expect(localContact.title, equals('Sebastião Silva'));
        expect(localContact.origin, equals('local'));

        final osmStreet = merged.firstWhere(
          (r) => r.type == LocalResultType.street,
        );
        expect(osmStreet.title, equals('Rua São Sebastião'));
        expect(osmStreet.origin, equals('am_solimoes.search.db'));
      },
    );

    test(
      'Gracefully degrades when no search.db or when search.db is corrupt',
      () async {
        // Cria diretório vazio sem .search.db
        final emptyDir = Directory.systemTemp.createTempSync('empty_search_');
        try {
          final resEmpty = await OfflineGeocodingService.searchOffline(
            query: 'Sebastiao',
            db: appDb,
            packagesDir: emptyDir,
          );
          expect(resEmpty, isEmpty);

          // Cria arquivo corrupto
          final corruptFile = File('${emptyDir.path}/corrupt.search.db');
          corruptFile.writeAsStringSync('NÃO É UM BANCO SQLITE VÁLIDO');

          // Não deve lançar exceção e não deve quebrar
          final resCorrupt = await OfflineGeocodingService.searchOffline(
            query: 'Sebastiao',
            db: appDb,
            packagesDir: emptyDir,
          );
          expect(resCorrupt, isEmpty);
        } finally {
          if (emptyDir.existsSync()) {
            try {
              emptyDir.deleteSync(recursive: true);
            } catch (_) {}
          }
        }
      },
    );

    test(
      'Clean SQLite descriptor closing allows file deletion on Windows',
      () async {
        final singleDir = Directory.systemTemp.createTempSync('lock_check_');
        final singleDbFile = File('${singleDir.path}/quick.search.db');
        final db = sql.sqlite3.open(singleDbFile.path);
        db.execute('''
        CREATE VIRTUAL TABLE osm_places_fts USING fts5(
          name, category, subtitle, lat UNINDEXED, lng UNINDEXED
        );
      ''');
        db.execute(
          "INSERT INTO osm_places_fts VALUES ('Rua Teste', 'street', 'Centro', '0', '0');",
        );
        db.close();

        // Executa busca
        final results = await OfflineGeocodingService.searchOffline(
          query: 'Teste',
          db: null,
          packagesDir: singleDir,
        );
        expect(results.length, equals(1));

        // Deletar o arquivo e pasta no Windows DEVE funcionar sem erro de arquivo aberto
        expect(() => singleDbFile.deleteSync(), returnsNormally);
        expect(() => singleDir.deleteSync(recursive: true), returnsNormally);
      },
    );
  });
}
