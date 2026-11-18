import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ministerio_pessoal/territory/map_engine/offline_tile_server.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = null;
  });

  late Directory tempDir;
  late OfflineTileServer server;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('tile_server_test_');
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

  group('OfflineTileServer Lifecycle & HTTP Fundamentals', () {
    test('starts on ephemeral loopback port and responds to /status', () async {
      final port = await server.start();
      expect(port, greaterThan(0));
      expect(server.isRunning, isTrue);
      expect(server.baseUrl, equals('http://127.0.0.1:$port'));

      final res = await http.get(Uri.parse('${server.baseUrl}/status'));
      expect(res.statusCode, equals(200));
      expect(res.headers['content-type'], contains('application/json'));
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      expect(json['status'], equals('ok'));
      expect(json['port'], equals(port));
    });

    test('OPTIONS preflight returns 204 with CORS headers', () async {
      await server.start();
      final request = http.Request(
        'OPTIONS',
        Uri.parse('${server.baseUrl}/tiles/1/2/3'),
      );
      final client = http.Client();
      final response = await client.send(request);

      expect(response.statusCode, equals(204));
      expect(response.headers['access-control-allow-origin'], equals('*'));
      expect(response.headers['access-control-allow-methods'], contains('GET'));
      expect(
        response.headers['access-control-allow-headers'],
        contains('Range'),
      );
      client.close();
    });

    test(
      'Rejects unsupported HTTP methods with 405 Method Not Allowed',
      () async {
        await server.start();
        final res = await http.post(
          Uri.parse('${server.baseUrl}/tiles/1/2/3'),
          body: 'data',
        );
        expect(res.statusCode, equals(405));
      },
    );

    test('Stops gracefully and reports isRunning = false', () async {
      await server.start();
      expect(server.isRunning, isTrue);

      await server.stop();
      expect(server.isRunning, isFalse);
      expect(server.port, isNull);
      expect(server.baseUrl, isNull);
    });
  });

  group('Tile Lookup Endpoint (/tiles/{z}/{x}/{y})', () {
    test('Serves PNG tile with correct Content-Type and headers', () async {
      final fakePng = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
        0x00, 0x00, 0x00, 0x0D,
      ]);

      server.setTileLookup((z, x, y) async {
        if (z == 10 && x == 500 && y == 600) {
          return fakePng;
        }
        return null;
      });

      await server.start();

      final res = await http.get(
        Uri.parse('${server.baseUrl}/tiles/10/500/600.png'),
      );
      expect(res.statusCode, equals(200));
      expect(res.headers['content-type'], equals('image/png'));
      expect(res.bodyBytes, equals(fakePng));
    });

    test('Serves gzipped PBF vector tile with application/x-protobuf and gzip encoding', () async {
      final fakePbf = Uint8List.fromList([
        0x1F, 0x8B, 0x08, 0x00, 0x00, // GZIP header
        0x01, 0x02, 0x03, 0x04,
      ]);

      server.setTileLookup((z, x, y) async {
        if (z == 14 && x == 4000 && y == 5000) {
          return fakePbf;
        }
        return null;
      });

      await server.start();

      // Desativa auto decompress no cliente HTTP para inspecionar os bytes brutos
      final client = HttpClient();
      client.autoUncompress = false;
      final req = await client.getUrl(
        Uri.parse('${server.baseUrl}/tiles/mbtiles/14/4000/5000.pbf'),
      );
      final res = await req.close();

      expect(res.statusCode, equals(200));
      expect(
        res.headers.value(HttpHeaders.contentTypeHeader),
        equals('application/x-protobuf'),
      );
      expect(
        res.headers.value(HttpHeaders.contentEncodingHeader),
        equals('gzip'),
      );

      final received = <int>[];
      await for (final chunk in res) {
        received.addAll(chunk);
      }
      expect(received, equals(fakePbf));
      client.close();
    });

    test('Returns 404 Not Found when tile is null or outside bounds', () async {
      server.setTileLookup((z, x, y) async => null);
      await server.start();

      final res = await http.get(Uri.parse('${server.baseUrl}/tiles/1/2/3'));
      expect(res.statusCode, equals(404));
    });

    test('Returns 400 Bad Request for non-integer tile coordinates', () async {
      server.setTileLookup((z, x, y) async => Uint8List(0));
      await server.start();

      final res = await http.get(
        Uri.parse('${server.baseUrl}/tiles/abc/def/ghi'),
      );
      expect(res.statusCode, equals(400));
    });
  });

  group('PMTiles Range Requests (HTTP 206 Partial Content)', () {
    late File pmtilesFile;
    late Uint8List dummyPmtilesData;

    setUp(() {
      pmtilesFile = File('${tempDir.path}/test_region.pmtiles');
      // Cria 1024 bytes com padrão determinístico: byte[i] = i % 256
      dummyPmtilesData = Uint8List.fromList(
        List.generate(1024, (i) => i % 256),
      );
      pmtilesFile.writeAsBytesSync(dummyPmtilesData);
    });

    test(
      'Serves full file with 200 OK when no Range header is supplied',
      () async {
        server.registerPmtilesPackage('test_region', pmtilesFile);
        await server.start();

        final res = await http.get(
          Uri.parse('${server.baseUrl}/pmtiles/test_region'),
        );
        expect(res.statusCode, equals(200));
        expect(res.headers['content-type'], equals('application/vnd.pmtiles'));
        expect(res.headers['accept-ranges'], equals('bytes'));
        expect(res.bodyBytes.length, equals(1024));
        expect(res.bodyBytes, equals(dummyPmtilesData));
      },
    );

    test(
      'Serves explicit byte range [0-15] with HTTP 206 Partial Content',
      () async {
        server.registerPmtilesPackage('test_region', pmtilesFile);
        await server.start();

        final res = await http.get(
          Uri.parse('${server.baseUrl}/pmtiles/test_region'),
          headers: {'Range': 'bytes=0-15'},
        );

        expect(res.statusCode, equals(206));
        expect(res.headers['content-range'], equals('bytes 0-15/1024'));
        expect(res.headers['content-length'], equals('16'));
        expect(res.headers['accept-ranges'], equals('bytes'));
        expect(res.bodyBytes, equals(dummyPmtilesData.sublist(0, 16)));
      },
    );

    test('Serves range starting from offset [500-] to end of file', () async {
      server.registerPmtilesPackage('test_region', pmtilesFile);
      await server.start();

      final res = await http.get(
        Uri.parse('${server.baseUrl}/pmtiles/test_region'),
        headers: {'Range': 'bytes=500-'},
      );

      expect(res.statusCode, equals(206));
      expect(res.headers['content-range'], equals('bytes 500-1023/1024'));
      expect(res.headers['content-length'], equals('524'));
      expect(res.bodyBytes, equals(dummyPmtilesData.sublist(500, 1024)));
    });

    test('Serves suffix range [-100] (final 100 bytes of file)', () async {
      server.registerPmtilesPackage('test_region', pmtilesFile);
      await server.start();

      final res = await http.get(
        Uri.parse('${server.baseUrl}/pmtiles/test_region'),
        headers: {'Range': 'bytes=-100'},
      );

      expect(res.statusCode, equals(206));
      expect(res.headers['content-range'], equals('bytes 924-1023/1024'));
      expect(res.headers['content-length'], equals('100'));
      expect(res.bodyBytes, equals(dummyPmtilesData.sublist(924, 1024)));
    });

    test('Returns 416 Range Not Satisfiable for out-of-bounds range', () async {
      server.registerPmtilesPackage('test_region', pmtilesFile);
      await server.start();

      final res = await http.get(
        Uri.parse('${server.baseUrl}/pmtiles/test_region'),
        headers: {'Range': 'bytes=2000-3000'},
      );

      expect(res.statusCode, equals(416));
      expect(res.headers['content-range'], equals('bytes */1024'));
    });

    test('Rejects directory traversal attempts in PMTiles route', () async {
      await server.start();

      final res = await http.get(
        Uri.parse('${server.baseUrl}/pmtiles/..%2Fsecret'),
      );
      expect(res.statusCode, anyOf(equals(400), equals(404)));
    });

    test('Returns 404 for non-existent PMTiles package', () async {
      await server.start();

      final res = await http.get(
        Uri.parse('${server.baseUrl}/pmtiles/unknown_pkg'),
      );
      expect(res.statusCode, equals(404));
    });
  });
}
