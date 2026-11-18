import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/territory/map_engine/offline_tile_server.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_native.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

void main() {
  setUpAll(() {
    HttpOverrides.global = null;
  });

  late Directory tempDir;
  late OfflineTileServer server;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('mbtiles_vector_test_');
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

  group('MBTiles Vector Validation and Server Endpoints', () {
    test(
      'Validates MBTiles file containing gzipped vector tiles (MVT/PBF)',
      () async {
        final mbtilesFile = File('${tempDir.path}/vector_test.mbtiles');
        final db = sql.sqlite3.open(mbtilesFile.path);

        db.execute('''
        CREATE TABLE metadata (name TEXT, value TEXT);
        CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB);
      ''');

        // Injeta tile vetorial com assinatura gzip (0x1f, 0x8b)
        final vectorBytes = Uint8List.fromList([
          0x1F,
          0x8B,
          0x08,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x02,
          0x03,
          0x4B,
          0xCE,
          0xCF,
          0x07,
          0x00,
        ]);

        final stmt = db.prepare('INSERT INTO tiles VALUES (?, ?, ?, ?)');
        stmt.execute([12, 200, 300, vectorBytes]);
        stmt.close();
        db.close();

        final native = MBTilesNative(customDir: tempDir);

        // Deve passar na validação sem lançar FormatException
        await expectLater(
          native.importRegionFile(
            regionId: 'vector_test',
            sourceFilePath: mbtilesFile.path,
          ),
          completes,
        );
      },
    );

    test(
      'Serves vector tile via /mbtiles/:regionId/:z/:x/:y.pbf endpoint',
      () async {
        final mbtilesFile = File('${tempDir.path}/city_tiles.mbtiles');
        final db = sql.sqlite3.open(mbtilesFile.path);

        db.execute('''
        CREATE TABLE metadata (name TEXT, value TEXT);
        CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB);
      ''');

        final vectorBytes = Uint8List.fromList([
          0x1F,
          0x8B,
          0x08,
          0x00,
          0x01,
          0x02,
          0x03,
          0x04,
        ]);

        // No padrão TMS: tmsY = (1 << z) - 1 - y
        // Para z=10, x=100, y=200: tmsY = 1024 - 1 - 200 = 823
        final tmsY = (1 << 10) - 1 - 200;

        final stmt = db.prepare('INSERT INTO tiles VALUES (?, ?, ?, ?)');
        stmt.execute([10, 100, tmsY, vectorBytes]);
        stmt.close();
        db.close();

        server.registerMbtilesPackage('city_tiles', mbtilesFile);
        final port = await server.start();

        final client = HttpClient();
        client.autoUncompress = false;
        final req = await client.getUrl(
          Uri.parse('http://127.0.0.1:$port/mbtiles/city_tiles/10/100/200.pbf'),
        );
        final res = await req.close();

        expect(res.statusCode, equals(200));
        expect(
          res.headers.value(HttpHeaders.contentTypeHeader),
          contains('application/x-protobuf'),
        );
        expect(
          res.headers.value(HttpHeaders.contentEncodingHeader),
          contains('gzip'),
        );
        final received = <int>[];
        await for (final chunk in res) {
          received.addAll(chunk);
        }
        expect(received, equals(vectorBytes));
        client.close();
      },
    );

    test(
      'Serves vector tile via /pmtiles/:regionId/:z/:x/:y.pbf endpoint',
      () async {
        final pmtilesFile = File('${tempDir.path}/test_region.pmtiles');
        final fakeTile = Uint8List.fromList([
          0x1F,
          0x8B,
          0x08,
          0x09,
          0x08,
          0x07,
        ]);

        // Cria cabeçalho PMTiles v3 mínimo
        final header = Uint8List(127);
        header[0] = 0x50;
        header[1] = 0x4D;
        header[2] = 3;

        pmtilesFile.writeAsBytesSync([...header, ...fakeTile]);

        server.registerPmtilesPackage('test_region', pmtilesFile);

        // Inicia servidor
        final port = await server.start();

        // Também configura tileLookup como fallback para coordenadas não indexadas
        server.setTileLookup((z, x, y) async {
          if (z == 14 && x == 2000 && y == 3000) return fakeTile;
          return null;
        });

        final client = HttpClient();
        client.autoUncompress = false;
        final req = await client.getUrl(
          Uri.parse(
            'http://127.0.0.1:$port/pmtiles/test_region/14/2000/3000.pbf',
          ),
        );
        final res = await req.close();

        expect(res.statusCode, equals(200));
        expect(
          res.headers.value(HttpHeaders.contentTypeHeader),
          contains('application/x-protobuf'),
        );
        final received = <int>[];
        await for (final chunk in res) {
          received.addAll(chunk);
        }
        expect(received, equals(fakeTile));
        client.close();
      },
    );
  });
}
