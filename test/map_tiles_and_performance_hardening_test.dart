import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ministerio_pessoal/territory/tile_cache/tile_cache_interface.dart';
import 'package:ministerio_pessoal/territory/tile_cache/tile_cache_native.dart';
import 'package:ministerio_pessoal/territory/tile_cache/tile_cache_service.dart';

class _MockTileCacheBackend implements TileCacheBackend {
  final Map<String, Uint8List> storage = {};
  int getTileCalls = 0;

  @override
  Future<Uint8List?> getTile(int z, int x, int y) async {
    getTileCalls++;
    return storage['$z/$x/$y'];
  }

  @override
  Future<void> saveTile(int z, int x, int y, Uint8List bytes) async {
    storage['$z/$x/$y'] = bytes;
  }

  @override
  Future<bool> isTileCached(int z, int x, int y) async {
    return storage.containsKey('$z/$x/$y');
  }

  @override
  Future<int> getCachedTileCount() async {
    return storage.length;
  }
}

void main() {
  group('TileCacheService L1 In-Memory LRU & Fallback', () {
    late _MockTileCacheBackend mockBackend;

    setUp(() {
      mockBackend = _MockTileCacheBackend();
      TileCacheService.instance.backend = mockBackend;
    });

    tearDown(() {
      TileCacheService.instance.clearMemoryCache();
    });

    test('Synchronous L1 memory cache hit returns immediately without backend call', () async {
      final sample = Uint8List.fromList([10, 20, 30, 40]);
      await TileCacheService.instance.saveTile(15, 100, 200, sample);

      // getMemoryCachedTile retorna síncrono da RAM
      final memBytes = TileCacheService.instance.getMemoryCachedTile(
        15,
        100,
        200,
      );
      expect(memBytes, equals(sample));

      // getTileBytes usa a memória sem consultar o backend
      final callsBefore = mockBackend.getTileCalls;
      final retrieved = await TileCacheService.instance.getTileBytes(
        15,
        100,
        200,
      );
      expect(retrieved, equals(sample));
      expect(mockBackend.getTileCalls, equals(callsBefore));
    });

    test('In-flight deduplication shares single future for concurrent tile requests', () async {
      final sample = Uint8List.fromList([1, 2, 3]);
      mockBackend.storage['15/50/60'] = sample;

      // Dispara 5 requisições paralelas para o mesmo bloco
      final futures = List.generate(
        5,
        (_) => TileCacheService.instance.getTileBytes(15, 50, 60),
      );
      final results = await Future.wait(futures);

      for (final res in results) {
        expect(res, equals(sample));
      }
      // O backend foi chamado exatamente 1 vez por causa da deduplicação
      expect(mockBackend.getTileCalls, equals(1));
    });

    test('Parent fallback overzoom calculates correct quadrant for zoom transitions', () async {
      // Bloco pai no nível 14 em (x: 10, y: 20)
      final parentBytes = Uint8List.fromList([100, 101, 102]);
      await TileCacheService.instance.saveTile(14, 10, 20, parentBytes);

      // Bloco filho no nível 15 correspondente a (x: 20, y: 40) -> quadrant (0, 0)
      final fallback00 = TileCacheService.instance.getFallbackTile(15, 20, 40);
      expect(fallback00, isNotNull);
      expect(fallback00!.bytes, equals(parentBytes));
      expect(fallback00.quadrantX, equals(0));
      expect(fallback00.quadrantY, equals(0));

      // Bloco filho (x: 21, y: 40) -> quadrant (1, 0)
      final fallback10 = TileCacheService.instance.getFallbackTile(15, 21, 40);
      expect(fallback10, isNotNull);
      expect(fallback10!.quadrantX, equals(1));
      expect(fallback10.quadrantY, equals(0));

      // Bloco filho (x: 20, y: 41) -> quadrant (0, 1)
      final fallback01 = TileCacheService.instance.getFallbackTile(15, 20, 41);
      expect(fallback01, isNotNull);
      expect(fallback01!.quadrantX, equals(0));
      expect(fallback01.quadrantY, equals(1));

      // Bloco filho (x: 21, y: 41) -> quadrant (1, 1)
      final fallback11 = TileCacheService.instance.getFallbackTile(15, 21, 41);
      expect(fallback11, isNotNull);
      expect(fallback11!.quadrantX, equals(1));
      expect(fallback11.quadrantY, equals(1));
    });

    test(
      'getFallbackTileAsync finds ancestor tile on disk if not in RAM',
      () async {
        final parentBytes = Uint8List.fromList([77, 88, 99]);
        // Simula que o bloco pai está gravado apenas no disco (storage do backend) e não na RAM
        mockBackend.storage['14/10/20'] = parentBytes;

        // getMemoryCachedTile retorna null
        expect(
          TileCacheService.instance.getMemoryCachedTile(14, 10, 20),
          isNull,
        );
        expect(TileCacheService.instance.getFallbackTile(15, 20, 40), isNull);

        // getFallbackTileAsync encontra o bloco pai no disco e retorna o fallback correto
        final fallback = await TileCacheService.instance.getFallbackTileAsync(
          15,
          20,
          40,
        );
        expect(fallback, isNotNull);
        expect(fallback!.bytes, equals(parentBytes));
        expect(fallback.quadrantX, equals(0));
        expect(fallback.quadrantY, equals(0));
      },
    );
  });

  group('TileCacheNative Concurrency & Negative Cache', () {
    test(
      'Negative cache suppresses repeated network hammering on failed tile',
      () async {
        int requestCount = 0;
        final mockClient = MockClient((request) async {
          requestCount++;
          return http.Response('Not Found', 404);
        });

        final tempDir = Directory.systemTemp.createTempSync('osm_test_neg_');
        addTearDown(() {
          if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        });

        final native = TileCacheNative(
          customDir: tempDir,
          httpClient: mockClient,
        );

        final firstResult = await native.getTile(15, 1, 1);
        expect(firstResult, isNull);
        expect(requestCount, equals(1));

        // Segunda chamada imediata para a mesma coordenada DEVE ser bloqueada pelo cache negativo
        final secondResult = await native.getTile(15, 1, 1);
        expect(secondResult, isNull);
        expect(requestCount, equals(1)); // Não fez segunda requisição HTTP!

        native.dispose();
      },
    );

    test(
      'TileCacheNative throttles concurrency and respects cancellation',
      () async {
        int activeRequests = 0;
        int maxConcurrentSeen = 0;
        final mockClient = MockClient((request) async {
          activeRequests++;
          if (activeRequests > maxConcurrentSeen) {
            maxConcurrentSeen = activeRequests;
          }
          await Future.delayed(const Duration(milliseconds: 30));
          activeRequests--;
          return http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200);
        });

        final tempDir = Directory.systemTemp.createTempSync(
          'osm_test_throttle_',
        );
        addTearDown(() {
          try {
            if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
          } catch (_) {}
        });

        final native = TileCacheNative(
          customDir: tempDir,
          httpClient: mockClient,
        );

        // Dispara 8 downloads simultâneos
        final futures = List.generate(8, (i) => native.getTile(15, i, 1));

        // Cancela requisições que ainda estão na fila (ex: índice 6 e 7)
        native.cancelTile(15, 6, 1);
        native.cancelTile(15, 7, 1);

        final results = await Future.wait(futures);

        // Máximo de concorrência ativa nunca deve exceder 4
        expect(maxConcurrentSeen, lessThanOrEqualTo(4));
        // As canceladas retornaram null sem esperar download
        expect(results[6], isNull);
        expect(results[7], isNull);

        await native.flushWrites();
        native.dispose();
      },
    );

    test(
      'cancelZoomExcept purges downloads from abandoned zoom levels',
      () async {
        final mockClient = MockClient((request) async {
          await Future.delayed(const Duration(milliseconds: 50));
          return http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200);
        });

        final tempDir = Directory.systemTemp.createTempSync('osm_test_zoom_');
        addTearDown(() {
          try {
            if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
          } catch (_) {}
        });

        final native = TileCacheNative(
          customDir: tempDir,
          httpClient: mockClient,
        );

        // Enfileira 6 requisições para o zoom 13
        final futuresZ13 = List.generate(6, (i) => native.getTile(13, i, 1));

        // Usuário muda para o zoom 14 imediatamente: cancela zoom 13
        native.cancelZoomExcept(14);

        // Dispara zoom 14
        final futureZ14 = native.getTile(14, 0, 0);

        final res14 = await futureZ14;
        expect(res14, isNotNull);

        final results13 = await Future.wait(futuresZ13);
        // Pelo menos as tarefas que estavam na fila de z=13 retornaram null canceladas
        expect(results13.contains(null), isTrue);

        await native.flushWrites();
        native.dispose();
      },
    );
  });

  group('CachedTileWidget UI Rendering & Fallback', () {
    testWidgets(
      'Renders sleek cartographic placeholder without repetitive offline text',
      (tester) async {
        final mockBackend = _MockTileCacheBackend();
        TileCacheService.instance.backend = mockBackend;
        addTearDown(TileCacheService.instance.clearMemoryCache);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CachedTileWidget(
                z: 15,
                x: 100,
                y: 200,
                size: 256.0,
                isDark: true,
              ),
            ),
          ),
        );

        // Não deve haver dezenas de textos "Mapa Offline" poluindo cada bloco
        expect(find.text('Mapa Offline'), findsNothing);
        expect(find.byType(CachedTileWidget), findsOneWidget);
        // Deve ter RepaintBoundary para performance
        expect(
          find.descendant(
            of: find.byType(CachedTileWidget),
            matching: find.byType(RepaintBoundary),
          ),
          findsAtLeast(1),
        );
      },
    );

    testWidgets('Renders image memory when tile is cached in L1 memory', (
      tester,
    ) async {
      final mockBackend = _MockTileCacheBackend();
      TileCacheService.instance.backend = mockBackend;
      addTearDown(TileCacheService.instance.clearMemoryCache);

      // 1x1 transparent PNG
      final validPng = Uint8List.fromList([
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
        0,
        0,
        0,
        13,
        73,
        72,
        68,
        82,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        1,
        8,
        6,
        0,
        0,
        0,
        31,
        21,
        196,
        137,
        0,
        0,
        0,
        10,
        73,
        68,
        65,
        84,
        120,
        156,
        99,
        0,
        1,
        0,
        0,
        5,
        0,
        1,
        13,
        10,
        45,
        180,
        0,
        0,
        0,
        0,
        73,
        69,
        78,
        68,
        174,
        66,
        96,
        130,
      ]);

      await TileCacheService.instance.saveTile(15, 300, 400, validPng);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CachedTileWidget(
              z: 15,
              x: 300,
              y: 400,
              size: 256.0,
              isDark: false,
            ),
          ),
        ),
      );

      // Bloco encontrado na memória L1 renderiza Image imediatamente
      expect(find.byType(Image), findsOneWidget);
    });
  });
}
