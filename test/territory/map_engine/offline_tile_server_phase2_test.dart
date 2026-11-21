import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ministerio_pessoal/territory/map_engine/offline_tile_server_io.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

void main() {
  setUpAll(() {
    HttpOverrides.global = null;
  });

  late Directory tempDir;
  late OfflineTileServer server;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('tile_server_p2_test_');
    server = OfflineTileServer(packagesDir: tempDir);
  });

  tearDown(() async {
    await server.stop(force: true);
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('OfflineTileServer Phase 2 — LRU Cache, SQLite Pool & Headers', () {
    test(
      'Serves MBTiles with Cache-Control header and caches in LRU',
      () async {
        final mbtilesFile = File('${tempDir.path}/test_region.mbtiles');
        final db = sql.sqlite3.open(mbtilesFile.path);
        db.execute('''
        CREATE TABLE metadata (name TEXT, value TEXT);
        CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB);
      ''');

        final rawData = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
        final sampleTile = Uint8List.fromList(gzip.encode(rawData));
        // TMS row calculation for z=10, y=500 -> (1 << 10) - 1 - 500 = 1024 - 1 - 500 = 523
        final tmsRow = (1 << 10) - 1 - 500;
        final stmt = db.prepare('INSERT INTO tiles VALUES (?, ?, ?, ?)');
        stmt.execute([10, 200, tmsRow, sampleTile]);
        stmt.close();
        db.close();

        await server.start();
        final url = '${server.baseUrl}/mbtiles/test_region/10/200/500.pbf';

        // First request: Cache Miss -> Read from SQLite & store in LRU cache
        final res1 = await http.get(Uri.parse(url));
        expect(res1.statusCode, equals(200));
        expect(
          res1.headers['cache-control'],
          equals('public, max-age=86400, immutable'),
        );
        expect(res1.headers['content-type'], equals('application/x-protobuf'));
        expect(res1.bodyBytes, equals(rawData));
        expect(server.tileCacheLength, equals(1));
        expect(server.openMbtilesDatabasesCount, equals(1));

        // Second request: Cache Hit
        final res2 = await http.get(Uri.parse(url));
        expect(res2.statusCode, equals(200));
        expect(
          res2.headers['cache-control'],
          equals('public, max-age=86400, immutable'),
        );
        expect(res2.bodyBytes, equals(rawData));
        expect(server.tileCacheLength, equals(1));
      },
    );

    test(
      'Falls back from TMS row to XYZ row when TMS is absent in MBTiles',
      () async {
        final mbtilesFile = File('${tempDir.path}/xyz_region.mbtiles');
        final db = sql.sqlite3.open(mbtilesFile.path);
        db.execute('''
        CREATE TABLE metadata (name TEXT, value TEXT);
        CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB);
      ''');

        final xyzTile = Uint8List.fromList([
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
        ]);
        // Insert with raw XYZ row y=600 instead of TMS
        final stmt = db.prepare('INSERT INTO tiles VALUES (?, ?, ?, ?)');
        stmt.execute([8, 100, 600, xyzTile]);
        stmt.close();
        db.close();

        await server.start();
        final url = '${server.baseUrl}/mbtiles/xyz_region/8/100/600.png';

        final res = await http.get(Uri.parse(url));
        expect(res.statusCode, equals(200));
        expect(
          res.headers['cache-control'],
          equals('public, max-age=86400, immutable'),
        );
        expect(res.headers['content-type'], equals('image/png'));
        expect(res.bodyBytes, equals(xyzTile));
      },
    );

    test('MBTiles connection pooling disposes cleanly on stop without file lock on Windows', () async {
      final mbtilesFile = File('${tempDir.path}/pool_region.mbtiles');
      final db = sql.sqlite3.open(mbtilesFile.path);
      db.execute('''
        CREATE TABLE metadata (name TEXT, value TEXT);
        CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB);
      ''');
      final rawData = Uint8List.fromList([1, 2, 3, 4]);
      final tileBytes = Uint8List.fromList(gzip.encode(rawData));
      final stmt = db.prepare('INSERT INTO tiles VALUES (?, ?, ?, ?)');
      stmt.execute([5, 10, 10, tileBytes]);
      stmt.close();
      db.close();

      await server.start();
      final url = '${server.baseUrl}/mbtiles/pool_region/5/10/10.pbf';

      // Perform multiple requests to exercise pool
      for (var i = 0; i < 5; i++) {
        final res = await http.get(Uri.parse(url));
        expect(res.statusCode, equals(200));
        expect(res.bodyBytes, equals(rawData));
      }
      expect(server.openMbtilesDatabasesCount, equals(1));

      // Stop server — all SQLite connections must close
      await server.stop();
      expect(server.openMbtilesDatabasesCount, equals(0));
      expect(server.tileCacheLength, equals(0));

      // Deleting the file on Windows MUST succeed without locked file exception
      expect(() => mbtilesFile.deleteSync(), returnsNormally);
    });

    test(
      'LRU cache eviction respects 256 max capacity and promotes on access',
      () async {
        final mbtilesFile = File('${tempDir.path}/lru_region.mbtiles');
        final db = sql.sqlite3.open(mbtilesFile.path);
        db.execute('''
        CREATE TABLE metadata (name TEXT, value TEXT);
        CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB);
      ''');

        // Populate 260 distinct tiles in zoom level 14
        final stmt = db.prepare('INSERT INTO tiles VALUES (?, ?, ?, ?)');
        for (var i = 0; i < 260; i++) {
          stmt.execute([
            14,
            i,
            i,
            Uint8List.fromList([i % 256, (i + 1) % 256]),
          ]);
        }
        stmt.close();
        db.close();

        await server.start();

        // Query 256 tiles: 0 to 255
        for (var i = 0; i < 256; i++) {
          final res = await http.get(
            Uri.parse('${server.baseUrl}/mbtiles/lru_region/14/$i/$i'),
          );
          expect(res.statusCode, equals(200));
        }
        expect(server.tileCacheLength, equals(256));
        expect(server.hasCachedTile('mbtiles:lru_region:14:0:0'), isTrue);

        // Access tile 0 again to promote it to most recently used
        final res0 = await http.get(
          Uri.parse('${server.baseUrl}/mbtiles/lru_region/14/0/0'),
        );
        expect(res0.statusCode, equals(200));

        // Now query tile 256 (this is entry 257) -> should evict tile 1 (the oldest unaccessed)
        final res256 = await http.get(
          Uri.parse('${server.baseUrl}/mbtiles/lru_region/14/256/256'),
        );
        expect(res256.statusCode, equals(200));
        expect(server.tileCacheLength, equals(256));

        // Tile 0 was promoted, so it must still be in cache!
        expect(server.hasCachedTile('mbtiles:lru_region:14:0:0'), isTrue);
        // Tile 1 was not promoted, so it must have been evicted!
        expect(server.hasCachedTile('mbtiles:lru_region:14:1:1'), isFalse);
        // Tile 256 must be present
        expect(server.hasCachedTile('mbtiles:lru_region:14:256:256'), isTrue);
      },
    );

    test('Invalidates tile cache on unregister and replace package', () async {
      final mbtilesFile = File('${tempDir.path}/replace_region.mbtiles');
      final db = sql.sqlite3.open(mbtilesFile.path);
      db.execute('''
        CREATE TABLE metadata (name TEXT, value TEXT);
        CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB);
      ''');
      final stmt = db.prepare('INSERT INTO tiles VALUES (?, ?, ?, ?)');
      stmt.execute([
        10,
        5,
        5,
        Uint8List.fromList([1, 2, 3]),
      ]);
      stmt.close();
      db.close();

      server.registerMbtilesPackage('pkg_a', mbtilesFile);
      await server.start();

      final res = await http.get(
        Uri.parse('${server.baseUrl}/mbtiles/pkg_a/10/5/5'),
      );
      expect(res.statusCode, equals(200));
      expect(server.tileCacheLength, equals(1));

      // Unregister clears cache
      server.unregisterMbtilesPackage('pkg_a');
      expect(server.tileCacheLength, equals(0));
    });
  });
}
