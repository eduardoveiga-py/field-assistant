import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_native.dart';
import 'package:ministerio_pessoal/core/app_version.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_service.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late MBTilesNative backend;
  late MBTilesService service;
  late Uint8List validMbtilesBytes;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('mbtiles_test_');

    // Create a real minimal MBTiles SQLite file for genuine streaming tests
    final seedPath = '${tempDir.path}/seed.db';
    final seedDb = sql.sqlite3.open(seedPath);
    seedDb.execute('CREATE TABLE metadata (name TEXT, value TEXT);');
    seedDb.execute("INSERT INTO metadata VALUES ('name', 'Test Solimoes');");
    seedDb.execute(
        'CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB);');
    // Insert a tile at z=6, x=20, y=30 (which corresponds to TMS row = (1<<6)-1-30 = 33)
    final tmsY = (1 << 6) - 1 - 30;
    seedDb.execute(
      'INSERT INTO tiles VALUES (6, 20, ?, X\'89504E470D0A1A0A\');',
      [tmsY],
    );
    seedDb.close();

    validMbtilesBytes = File(seedPath).readAsBytesSync();
    File(seedPath).deleteSync();

    backend = MBTilesNative(customDir: tempDir);
    service = MBTilesService.custom(backend: backend);
    await service.init();
  });

  tearDown(() async {
    service.dispose();
    backend.dispose();
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('MBTiles Real Service & HTTP Streaming Tests', () {
    test('Default catalog starts with isInstalled=false when disk is empty', () {
      final regions = service.currentRegions;
      expect(regions, isNotEmpty);
      final solimoes = regions.firstWhere((r) => r.id == 'br_am_solimoes');
      expect(solimoes.isInstalled, isFalse);
      expect(solimoes.downloadProgress, equals(0.0));
      expect(backend.isRegionInstalled('br_am_solimoes'), isFalse);
      expect(service.resolveDownloadUrl(solimoes),
          'https://github.com/${AppVersion.githubRepo}/releases/download/v1.3.4/br_am_solimoes.mbtiles');
      expect(solimoes.sizeBytes, 264892416);
    });

    test(
        'Real HTTP streaming download saves to disk, performs atomic swap, and marks isInstalled=true',
        () async {
      final progressList = <double>[];
      final downloadedBytesList = <int>[];

      final mockClient = MockClient.streaming((request, stream) async {
        expect(request.method, equals('GET'));
        expect(request.url.toString(),
            'https://github.com/${AppVersion.githubRepo}/releases/download/v1.3.4/br_am_solimoes.mbtiles');

        // Stream the valid MBTiles bytes in 3 discrete chunks
        final chunkSize = (validMbtilesBytes.length / 3).ceil();
        final chunks = <List<int>>[];
        for (int i = 0; i < validMbtilesBytes.length; i += chunkSize) {
          final end = (i + chunkSize < validMbtilesBytes.length)
              ? i + chunkSize
              : validMbtilesBytes.length;
          chunks.add(validMbtilesBytes.sublist(i, end));
        }

        final responseStream = Stream.fromIterable(chunks);
        return http.StreamedResponse(
          responseStream,
          200,
          contentLength: validMbtilesBytes.length,
          headers: {'content-type': 'application/octet-stream'},
        );
      });

      await service.downloadRegion(
        'br_am_solimoes',
        httpClient: mockClient,
        onProgress: (p, b) {
          progressList.add(p);
          downloadedBytesList.add(b);
        },
      );

      // Verify progress notifications occurred
      expect(progressList, isNotEmpty);
      expect(progressList.last, equals(1.0));
      expect(downloadedBytesList.last, equals(validMbtilesBytes.length));

      // Verify that the temporary file (.tmp) was removed and final .mbtiles exists
      final finalFile = File('${tempDir.path}/br_am_solimoes.mbtiles');
      final tmpFile = File('${tempDir.path}/br_am_solimoes.mbtiles.tmp');
      expect(tmpFile.existsSync(), isFalse);
      expect(finalFile.existsSync(), isTrue);
      expect(finalFile.lengthSync(), equals(validMbtilesBytes.length));

      // Verify state in service
      final solimoes = service.currentRegions.firstWhere((r) => r.id == 'br_am_solimoes');
      expect(solimoes.isInstalled, isTrue);
      expect(solimoes.downloadProgress, equals(1.0));
      expect(solimoes.sizeBytes, equals(validMbtilesBytes.length));

      // Verify backend serves tile directly from the downloaded package
      final tile = await backend.getTile(6, 20, 30);
      expect(tile, isNotNull);
      expect(tile!.length, equals(8));
      expect(tile, equals([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    test('Status isInstalled persists when a new service/backend is initialized from existing disk',
        () async {
      // Place valid MBTiles file on disk
      final targetFile = File('${tempDir.path}/br_am_solimoes.mbtiles');
      targetFile.writeAsBytesSync(validMbtilesBytes, flush: true);

      // Create a fresh backend and service instance pointing to the same directory
      final freshBackend = MBTilesNative(customDir: tempDir);
      final freshService = MBTilesService.custom(backend: freshBackend);
      await freshService.init();

      final solimoes = freshService.currentRegions.firstWhere((r) => r.id == 'br_am_solimoes');
      expect(solimoes.isInstalled, isTrue);
      expect(freshBackend.isRegionInstalled('br_am_solimoes'), isTrue);
      expect(solimoes.sizeBytes, equals(validMbtilesBytes.length));

      freshService.dispose();
      freshBackend.dispose();
    });

    test('deleteRegion removes physical file and updates region status to uninstalled', () async {
      // Setup installed file
      final targetFile = File('${tempDir.path}/br_am_solimoes.mbtiles');
      targetFile.writeAsBytesSync(validMbtilesBytes, flush: true);
      await backend.reload();
      await service.init();

      expect(backend.isRegionInstalled('br_am_solimoes'), isTrue);

      // Perform deletion
      await service.deleteRegion('br_am_solimoes');

      // Verify file deleted from disk
      expect(targetFile.existsSync(), isFalse);
      expect(backend.isRegionInstalled('br_am_solimoes'), isFalse);

      final solimoes = service.currentRegions.firstWhere((r) => r.id == 'br_am_solimoes');
      expect(solimoes.isInstalled, isFalse);
      expect(solimoes.downloadProgress, equals(0.0));
    });

    test('Download failure with HTTP error throws MBTilesDownloadException and resets state', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      expect(
        () => service.downloadRegion('br_am_solimoes', httpClient: mockClient),
        throwsA(isA<MBTilesDownloadException>()),
      );

      final solimoes = service.currentRegions.firstWhere((r) => r.id == 'br_am_solimoes');
      expect(solimoes.isInstalled, isFalse);
      expect(solimoes.downloadProgress, equals(0.0));

      final tmpFile = File('${tempDir.path}/br_am_solimoes.mbtiles.tmp');
      expect(tmpFile.existsSync(), isFalse);
    });

    test('cancelDownload aborts active client and resets progress', () async {
      final completer = Completer<void>();

      final mockClient = MockClient.streaming((request, stream) async {
        final streamController = StreamController<List<int>>();
        // Send first chunk
        streamController.add([1, 2, 3]);

        // Keep open until cancelled
        completer.future.then((_) {
          if (!streamController.isClosed) {
            streamController.close();
          }
        });

        return http.StreamedResponse(
          streamController.stream,
          200,
          contentLength: 1000,
        );
      });

      final downloadFuture = service.downloadRegion('br_am_solimoes', httpClient: mockClient);

      // Wait a tick for download to start
      await Future.delayed(const Duration(milliseconds: 30));

      // Cancel the download
      service.cancelDownload('br_am_solimoes');
      completer.complete();

      try {
        await downloadFuture;
      } catch (_) {}

      final solimoes = service.currentRegions.firstWhere((r) => r.id == 'br_am_solimoes');
      expect(solimoes.isInstalled, isFalse);
      expect(solimoes.downloadProgress, equals(0.0));
    });

    test('Custom base catalog URL and per-region URL persist to disk and resolve cleanly', () async {
      await service.setBaseCatalogUrl('https://cdn.example.org/maps/');
      expect(
        service.resolveDownloadUrl(
          service.currentRegions.firstWhere((r) => r.id == 'br_am_solimoes'),
        ),
        equals('https://cdn.example.org/maps/br_am_solimoes.mbtiles'),
      );

      await service.setRegionCustomUrl(
        'br_am_solimoes',
        'https://mirror.example.org/custom/alto_solimoes.mbtiles',
      );

      final freshBackend = MBTilesNative(customDir: tempDir);
      final freshService = MBTilesService.custom(backend: freshBackend);
      await freshService.init();

      expect(freshService.customBaseUrl, equals('https://cdn.example.org/maps/'));
      expect(
        freshService.resolveDownloadUrl(
          freshService.currentRegions.firstWhere((r) => r.id == 'br_am_solimoes'),
        ),
        equals('https://mirror.example.org/custom/alto_solimoes.mbtiles'),
      );
      expect(
        freshService.resolveDownloadUrl(
          freshService.currentRegions.firstWhere((r) => r.id == 'br_am_manaus'),
        ),
        equals('https://cdn.example.org/maps/br_am_manaus.mbtiles'),
      );

      await freshService.setRegionCustomUrl('br_am_solimoes', null);
      await freshService.setBaseCatalogUrl(null);
      expect(
        freshService.resolveDownloadUrl(
          freshService.currentRegions.firstWhere((r) => r.id == 'br_am_solimoes'),
        ),
        endsWith('/releases/download/v1.3.4/br_am_solimoes.mbtiles'),
      );

      freshService.dispose();
      freshBackend.dispose();
    });

    test('importLocalMbtiles validates SQLite + tiles table and rejects invalid packages', () async {
      final externalDir = Directory.systemTemp.createTempSync('mbtiles_import_src_');
      addTearDown(() {
        if (externalDir.existsSync()) {
          try {
            externalDir.deleteSync(recursive: true);
          } catch (_) {}
        }
      });

      final validSrc = File('${externalDir.path}/meu_mapa.mbtiles')
        ..writeAsBytesSync(validMbtilesBytes, flush: true);

      final imported = await service.importLocalMbtiles(sourceFilePath: validSrc.path);
      expect(imported.isInstalled, isTrue);
      expect(imported.id, equals('local_meu_mapa'));
      expect(backend.isRegionInstalled(imported.id), isTrue);

      final tile = await service.getTile(6, 20, 30);
      expect(tile, equals([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));

      // Invalid non-SQLite file must fail validation and not install
      final invalidSrc = File('${externalDir.path}/lixo.mbtiles')
        ..writeAsStringSync('not a sqlite file', flush: true);
      await expectLater(
        () => service.importLocalMbtiles(
          regionId: 'br_am_manaus',
          sourceFilePath: invalidSrc.path,
        ),
        throwsFormatException,
      );
      expect(backend.isRegionInstalled('br_am_manaus'), isFalse);

      // SQLite database missing required "tiles" table must fail validation
      final noTilesDbPath = '${externalDir.path}/sem_tiles.mbtiles';
      final db = sql.sqlite3.open(noTilesDbPath);
      db.execute('CREATE TABLE metadata (name TEXT, value TEXT);');
      db.close();
      await expectLater(
        () => service.importLocalMbtiles(
          regionId: 'br_am_manaus',
          sourceFilePath: noTilesDbPath,
        ),
        throwsFormatException,
      );
      expect(backend.isRegionInstalled('br_am_manaus'), isFalse);

      // MBTiles 1.3 database using a SQLite VIEW for `tiles` must succeed
      final viewDbPath = '${externalDir.path}/view_tiles.mbtiles';
      final viewDb = sql.sqlite3.open(viewDbPath);
      viewDb.execute('CREATE TABLE images (tile_id TEXT, tile_data BLOB);');
      viewDb.execute(
          'CREATE TABLE map (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_id TEXT);');
      viewDb.execute(
          'CREATE VIEW tiles AS SELECT zoom_level, tile_column, tile_row, tile_data FROM map JOIN images ON map.tile_id = images.tile_id;');
      viewDb.execute(
          "INSERT INTO images VALUES ('t1', X'89504E470D0A1A0A0102');");
      viewDb.execute(
          "INSERT INTO map VALUES (8, 40, ${(1 << 8) - 1 - 50}, 't1');");
      viewDb.close();

      final importedView = await service.importLocalMbtiles(
        regionId: 'br_am_manaus',
        sourceFilePath: viewDbPath,
      );
      expect(importedView.isInstalled, isTrue);
      expect(backend.isRegionInstalled('br_am_manaus'), isTrue);
      final viewTile = await service.getTile(8, 40, 50);
      expect(
        viewTile,
        equals([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x01, 0x02]),
      );
    });

    test(
        'downloadRegion failure and updateAll preserve already-installed local .mbtiles and skip local-only packages',
        () async {
      final externalDir = Directory.systemTemp.createTempSync('mbtiles_preserve_');
      addTearDown(() {
        if (externalDir.existsSync()) {
          try {
            externalDir.deleteSync(recursive: true);
          } catch (_) {}
        }
      });

      final src = File('${externalDir.path}/solimoes.mbtiles')
        ..writeAsBytesSync(validMbtilesBytes, flush: true);
      await service.importLocalMbtiles(
        regionId: 'br_am_solimoes',
        sourceFilePath: src.path,
      );

      final customSrc = File('${externalDir.path}/custom_aldeia.mbtiles')
        ..writeAsBytesSync(validMbtilesBytes, flush: true);
      final customRegion = await service.importLocalMbtiles(
        sourceFilePath: customSrc.path,
      );
      expect(customRegion.id, equals('local_custom_aldeia'));

      final client404 = MockClient((req) async => http.Response('Not Found', 404));
      final failedNames = await service.updateAll(httpClient: client404);

      // br_am_solimoes failed 404, local_custom_aldeia was skipped cleanly
      expect(failedNames, equals(['Santo Antônio do Içá e entorno (experimental)']));

      // Installed status & physical file must remain intact on disk
      final solimoesAfter =
          service.currentRegions.firstWhere((r) => r.id == 'br_am_solimoes');
      expect(solimoesAfter.isInstalled, isTrue);
      expect(solimoesAfter.downloadProgress, equals(1.0));
      expect(backend.isRegionInstalled('br_am_solimoes'), isTrue);
    });
  });
}
