import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/territory/tile_cache/tile_cache_interface.dart';
import 'package:ministerio_pessoal/territory/tile_cache/tile_cache_native.dart';
import 'package:ministerio_pessoal/territory/tile_cache/tile_cache_web.dart';

void main() {
  group('Tile Cache - Watermark & Block Detection', () {
    test('isBlockedTile detects CARTO watermarks (2049, 2513), OSM block (6725) and text', () {
      final nativeBackend = TileCacheNative();
      final webBackend = TileCacheWeb();

      // CARTO light watermark (2049 bytes)
      expect(nativeBackend.isBlockedTile(Uint8List(2049)), isTrue);
      expect(webBackend.isBlockedTile(Uint8List(2049)), isTrue);

      // Empty byte array (corrupted / empty payload)
      expect(nativeBackend.isBlockedTile(Uint8List(0)), isTrue);
      expect(webBackend.isBlockedTile(Uint8List(0)), isTrue);

      // CARTO dark watermark (2513 bytes)
      expect(nativeBackend.isBlockedTile(Uint8List(2513)), isTrue);
      expect(webBackend.isBlockedTile(Uint8List(2513)), isTrue);

      // OSM standard blocked tile (6725 bytes)
      expect(nativeBackend.isBlockedTile(Uint8List(6725)), isTrue);
      expect(webBackend.isBlockedTile(Uint8List(6725)), isTrue);

      // OSM HTML block message
      final htmlBlock = Uint8List.fromList('Access blocked due to tile usage policy osm.wiki/Blocked'.codeUnits);
      expect(nativeBackend.isBlockedTile(htmlBlock), isTrue);
      expect(webBackend.isBlockedTile(htmlBlock), isTrue);

      // Normal valid tiles are NOT blocked
      final validTile = Uint8List.fromList(List.generate(3500, (i) => i % 256));
      expect(nativeBackend.isBlockedTile(validTile), isFalse);
      expect(webBackend.isBlockedTile(validTile), isFalse);
    });
  });

  group('TileCacheNative - Disk Cache & Watermark Rejection', () {
    test('saveTile rejects 2049 and 2513 bytes watermarked tiles from writing to disk', () async {
      final tempDir = await Directory.systemTemp.createTemp('tile_test_save_');
      try {
        final backend = TileCacheNative(customDir: tempDir);

        // Tentativa de salvar marca d'água CARTO clara (2049 bytes)
        await backend.saveTile(10, 1, 1, Uint8List(2049));
        expect(await backend.isTileCached(10, 1, 1), isFalse);

        // Tentativa de salvar marca d'água CARTO escura (2513 bytes)
        await backend.saveTile(10, 1, 2, Uint8List(2513));
        expect(await backend.isTileCached(10, 1, 2), isFalse);

        // Salvar tile legítimo
        final cleanBytes = Uint8List.fromList(List.generate(1200, (i) => i % 256));
        await backend.saveTile(10, 1, 3, cleanBytes);
        expect(await backend.isTileCached(10, 1, 3), isTrue);
        expect(await backend.getCachedTileCount(), 1);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('getTile auto-deletes existing cached watermarked tiles from disk', () async {
      final tempDir = await Directory.systemTemp.createTemp('tile_test_autodel_');
      try {
        final backend = TileCacheNative(customDir: tempDir);
        final file2049 = File('${tempDir.path}/15/10/20.png');
        await file2049.parent.create(recursive: true);
        await file2049.writeAsBytes(Uint8List(2049), flush: true);
        expect(await file2049.exists(), isTrue);

        // Ao ler tile corrompido em cache, deve expurgar o arquivo localmente
        final res2049 = await backend.getTile(15, 10, 20);
        expect(res2049, isNull);
        expect(await file2049.exists(), isFalse);

        // Repete o teste para marca d'água de 2513 bytes
        final file2513 = File('${tempDir.path}/15/10/21.png');
        await file2513.writeAsBytes(Uint8List(2513), flush: true);
        expect(await file2513.exists(), isTrue);

        final res2513 = await backend.getTile(15, 10, 21);
        expect(res2513, isNull);
        expect(await file2513.exists(), isFalse);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('getTile returns clean cached tile immediately without network call', () async {
      final tempDir = await Directory.systemTemp.createTemp('tile_test_hit_');
      try {
        final backend = TileCacheNative(customDir: tempDir);
        final cleanBytes = Uint8List.fromList(List.generate(2000, (i) => (i * 3) % 256));
        await backend.saveTile(12, 5, 8, cleanBytes);

        final cached = await backend.getTile(12, 5, 8);
        expect(cached, isNotNull);
        expect(cached, cleanBytes);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('isTileCached returns false and auto-deletes watermarked, blocked and 0-byte tiles', () async {
      final tempDir = await Directory.systemTemp.createTemp('tile_test_istilecached_');
      try {
        final backend = TileCacheNative(customDir: tempDir);

        // Cria tiles corrompidos no disco
        final f0 = File('${tempDir.path}/10/1/0.png')..createSync(recursive: true);
        f0.writeAsBytesSync(Uint8List(0));

        final f2049 = File('${tempDir.path}/10/1/1.png')..createSync(recursive: true);
        f2049.writeAsBytesSync(Uint8List(2049));

        final f2513 = File('${tempDir.path}/10/1/2.png')..createSync(recursive: true);
        f2513.writeAsBytesSync(Uint8List(2513));

        final f6725 = File('${tempDir.path}/10/1/3.png')..createSync(recursive: true);
        f6725.writeAsBytesSync(Uint8List(6725));

        // Tile legítimo
        final fClean = File('${tempDir.path}/10/1/4.png')..createSync(recursive: true);
        fClean.writeAsBytesSync(Uint8List.fromList([1, 2, 3, 4]));

        // isTileCached deve retornar false para os corrompidos e apagá-los
        expect(await backend.isTileCached(10, 1, 0), isFalse);
        expect(f0.existsSync(), isFalse);

        expect(await backend.isTileCached(10, 1, 1), isFalse);
        expect(f2049.existsSync(), isFalse);

        expect(await backend.isTileCached(10, 1, 2), isFalse);
        expect(f2513.existsSync(), isFalse);

        expect(await backend.isTileCached(10, 1, 3), isFalse);
        expect(f6725.existsSync(), isFalse);

        // Tile limpo deve retornar true e permanecer no disco
        expect(await backend.isTileCached(10, 1, 4), isTrue);
        expect(fClean.existsSync(), isTrue);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('getCachedTileCount filters out and cleans up corrupt/watermarked tiles', () async {
      final tempDir = await Directory.systemTemp.createTemp('tile_test_count_');
      try {
        final backend = TileCacheNative(customDir: tempDir);

        // 3 tiles com marcas d'água / corrompidos
        final wm1 = File('${tempDir.path}/1/0/0.png')..createSync(recursive: true);
        wm1.writeAsBytesSync(Uint8List(2049));
        final wm2 = File('${tempDir.path}/1/0/1.png')..createSync(recursive: true);
        wm2.writeAsBytesSync(Uint8List(2513));
        final emptyFile = File('${tempDir.path}/1/0/2.png')..createSync(recursive: true);
        emptyFile.writeAsBytesSync(Uint8List(0));

        // 2 tiles válidos
        final clean1 = File('${tempDir.path}/1/1/0.png')..createSync(recursive: true);
        clean1.writeAsBytesSync(Uint8List.fromList([10, 20, 30]));
        final clean2 = File('${tempDir.path}/1/1/1.png')..createSync(recursive: true);
        clean2.writeAsBytesSync(Uint8List.fromList([40, 50, 60]));

        // Contagem deve considerar apenas os 2 válidos e expurgar os outros 3
        final count = await backend.getCachedTileCount();
        expect(count, equals(2));

        expect(wm1.existsSync(), isFalse);
        expect(wm2.existsSync(), isFalse);
        expect(emptyFile.existsSync(), isFalse);
        expect(clean1.existsSync(), isTrue);
        expect(clean2.existsSync(), isTrue);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('TileCacheNative - HTTP Provedores e Fallback', () {
    test('getTile utiliza OpenStreetMap oficial como provedor primário', () async {
      final tempDir = await Directory.systemTemp.createTemp('tile_test_osm_');
      try {
        final requestedUrls = <String>[];
        final mockClient = MockClient((request) async {
          requestedUrls.add(request.url.toString());
          expect(request.headers['User-Agent'], contains('MinisterioPessoal'));
          if (request.url.host == 'tile.openstreetmap.org') {
            return http.Response.bytes(
              Uint8List.fromList(List.generate(1500, (i) => 42)),
              200,
              headers: {'content-type': 'image/png'},
            );
          }
          return http.Response('Not Found', 404);
        });

        final backend = TileCacheNative(customDir: tempDir, httpClient: mockClient);
        final bytes = await backend.getTile(12, 50, 60);

        expect(bytes, isNotNull);
        expect(bytes!.length, 1500);
        expect(requestedUrls, ['https://tile.openstreetmap.org/12/50/60.png']);
        expect(await backend.isTileCached(12, 50, 60), isTrue);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('getTile realiza fallback transparente para OpenStreetMap France quando primário falha', () async {
      final tempDir = await Directory.systemTemp.createTemp('tile_test_fb_');
      try {
        final requestedUrls = <String>[];
        final mockClient = MockClient((request) async {
          requestedUrls.add(request.url.toString());
          if (request.url.host == 'tile.openstreetmap.org') {
            return http.Response('OSM Temporarily Busy', 503);
          }
          if (request.url.host == 'a.tile.openstreetmap.fr') {
            return http.Response.bytes(
              Uint8List.fromList(List.generate(1800, (i) => 99)),
              200,
              headers: {'content-type': 'image/png'},
            );
          }
          return http.Response('Not Found', 404);
        });

        final backend = TileCacheNative(customDir: tempDir, httpClient: mockClient);
        final bytes = await backend.getTile(14, 25, 30);

        expect(bytes, isNotNull);
        expect(bytes!.length, 1800);
        expect(requestedUrls, [
          'https://tile.openstreetmap.org/14/25/30.png',
          'https://a.tile.openstreetmap.fr/osmfr/14/25/30.png',
        ]);
        expect(await backend.isTileCached(14, 25, 30), isTrue);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('getTile rejeita resposta com etag contendo "wm-" ou tamanho de marca d água e aciona fallback', () async {
      final tempDir = await Directory.systemTemp.createTemp('tile_test_wm_');
      try {
        final requestedUrls = <String>[];
        final mockClient = MockClient((request) async {
          requestedUrls.add(request.url.toString());
          if (request.url.host == 'tile.openstreetmap.org') {
            // Provedor primário retorna 200 OK mas com marca d'água CARTO (2049 bytes ou etag wm-)
            return http.Response.bytes(
              Uint8List(2049),
              200,
              headers: {'etag': 'W/"wm-bad-tile"', 'content-type': 'image/png'},
            );
          }
          if (request.url.host == 'a.tile.openstreetmap.fr') {
            return http.Response.bytes(
              Uint8List.fromList(List.generate(1700, (i) => 88)),
              200,
              headers: {'content-type': 'image/png'},
            );
          }
          return http.Response('Not Found', 404);
        });

        final backend = TileCacheNative(customDir: tempDir, httpClient: mockClient);
        final bytes = await backend.getTile(16, 12, 14);

        expect(bytes, isNotNull);
        expect(bytes!.length, 1700); // Veio limpo do fallback
        expect(requestedUrls, [
          'https://tile.openstreetmap.org/16/12/14.png',
          'https://a.tile.openstreetmap.fr/osmfr/16/12/14.png',
        ]);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('TileCacheNative respeita estritamente o limite de 2 conexões simultâneas da política OSM', () async {
      TileCacheNative.resetQueue();
      expect(TileCacheNative.activeDownloads, 0);

      final completers = [Completer<void>(), Completer<void>(), Completer<void>()];
      int concurrentCalls = 0;
      int maxConcurrentObserved = 0;

      final mockClient = MockClient((request) async {
        concurrentCalls++;
        if (concurrentCalls > maxConcurrentObserved) {
          maxConcurrentObserved = concurrentCalls;
        }
        if (request.url.path.contains('/0/')) {
          await completers[0].future;
        } else if (request.url.path.contains('/1/')) {
          await completers[1].future;
        } else if (request.url.path.contains('/2/')) {
          await completers[2].future;
        }
        concurrentCalls--;
        return http.Response.bytes(Uint8List.fromList(List.filled(1200, 1)), 200);
      });

      final tempDir = await Directory.systemTemp.createTemp('tile_test_conc_');
      try {
        final backend = TileCacheNative(customDir: tempDir, httpClient: mockClient);

        final f1 = backend.getTile(8, 0, 0);
        final f2 = backend.getTile(8, 1, 0);
        final f3 = backend.getTile(8, 2, 0);

        await Future.delayed(const Duration(milliseconds: 50));

        // Máximo de 2 downloads ativos ao mesmo tempo
        expect(TileCacheNative.activeDownloads, 2);
        expect(maxConcurrentObserved, 2);

        // Libera o primeiro download
        completers[0].complete();
        await Future.delayed(const Duration(milliseconds: 50));

        // Libera os demais
        completers[1].complete();
        completers[2].complete();

        await Future.wait([f1, f2, f3]);
        expect(TileCacheNative.activeDownloads, 0);
        expect(maxConcurrentObserved, 2);
      } finally {
        TileCacheNative.resetQueue();
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('TileCacheWeb - Testes da Camada Web', () {
    test('TileCacheWeb detecta marca d água, rejeita salvamento e efetua fallback', () async {
      TileCacheWeb.clearCache();
      final web = TileCacheWeb();

      await web.saveTile(5, 5, 5, Uint8List(2049));
      expect(await web.isTileCached(5, 5, 5), isFalse);

      await web.saveTile(5, 5, 6, Uint8List(2513));
      expect(await web.isTileCached(5, 5, 6), isFalse);

      final requestedUrls = <String>[];
      final mockClient = MockClient((request) async {
        requestedUrls.add(request.url.toString());
        if (request.url.host == 'tile.openstreetmap.org') {
          return http.Response('OSM Busy', 500);
        }
        return http.Response.bytes(
          Uint8List.fromList(List.generate(1400, (i) => 5)),
          200,
          headers: {'content-type': 'image/png'},
        );
      });

      final webWithClient = TileCacheWeb(httpClient: mockClient);
      final bytes = await webWithClient.getTile(7, 3, 4);

      expect(bytes, isNotNull);
      expect(bytes!.length, 1400);
      expect(requestedUrls, [
        'https://tile.openstreetmap.org/7/3/4.png',
        'https://a.tile.openstreetmap.fr/osmfr/7/3/4.png',
      ]);
      expect(await webWithClient.isTileCached(7, 3, 4), isTrue);
    });

    test('TileCacheWeb isTileCached and getCachedTileCount filter out invalid/empty/watermarked tiles', () async {
      TileCacheWeb.clearCache();
      final web = TileCacheWeb();

      // Salva tile válido
      await web.saveTile(1, 1, 1, Uint8List.fromList([1, 2, 3]));
      expect(await web.isTileCached(1, 1, 1), isTrue);

      // Tenta salvar tile vazio (0 bytes) ou marca d'água
      await web.saveTile(1, 1, 2, Uint8List(0));
      expect(await web.isTileCached(1, 1, 2), isFalse);

      await web.saveTile(1, 1, 3, Uint8List(2049));
      expect(await web.isTileCached(1, 1, 3), isFalse);

      // Contagem deve ter apenas o único tile válido
      expect(await web.getCachedTileCount(), equals(1));
    });

    test('TileCacheNative activeDownloads does not underflow below 0', () {
      TileCacheNative.resetQueue();
      expect(TileCacheNative.activeDownloads, 0);

      // Múltiplos releases sem acquire prévio não devem negativar o contador
      TileCacheNative.resetQueue();
      expect(TileCacheNative.activeDownloads, 0);
    });

    test('TileCacheNative and TileCacheWeb isolate cache entries by MapLayerStyle', () async {
      final tempDir = await Directory.systemTemp.createTemp('tile_test_style_iso_');
      try {
        final native = TileCacheNative(customDir: tempDir);
        final osmBytes = Uint8List.fromList([1, 1, 1]);
        final satBytes = Uint8List.fromList([2, 2, 2]);

        await native.saveTile(10, 5, 5, osmBytes, MapLayerStyle.standard);
        await native.saveTile(10, 5, 5, satBytes, MapLayerStyle.satellite);

        final readOsm = await native.getTile(10, 5, 5, MapLayerStyle.standard);
        final readSat = await native.getTile(10, 5, 5, MapLayerStyle.satellite);

        expect(readOsm, equals(osmBytes));
        expect(readSat, equals(satBytes));
        expect(await native.getCachedTileCount(MapLayerStyle.standard), equals(1));
        expect(await native.getCachedTileCount(MapLayerStyle.satellite), equals(1));
        expect(await native.getCachedTileCount(), equals(2));

        // Web isolation
        TileCacheWeb.clearCache();
        final web = TileCacheWeb();
        await web.saveTile(10, 5, 5, osmBytes, MapLayerStyle.standard);
        await web.saveTile(10, 5, 5, satBytes, MapLayerStyle.satellite);

        final webOsm = await web.getTile(10, 5, 5, MapLayerStyle.standard);
        final webSat = await web.getTile(10, 5, 5, MapLayerStyle.satellite);

        expect(webOsm, equals(osmBytes));
        expect(webSat, equals(satBytes));
        expect(await web.getCachedTileCount(MapLayerStyle.standard), equals(1));
        expect(await web.getCachedTileCount(MapLayerStyle.satellite), equals(1));
        expect(await web.getCachedTileCount(), equals(2));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
