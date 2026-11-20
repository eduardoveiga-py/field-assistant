import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_service.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_web.dart';
import 'package:ministerio_pessoal/territory/routing/offline_routing_engine.dart';
import 'package:ministerio_pessoal/territory/tile_cache/tile_cache_service.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/contacts_map_screen.dart';

class _EmptyTestTiles implements TileCacheBackend {
  @override
  Future<Uint8List?> getTile(
    int z,
    int x,
    int y, [
    MapLayerStyle? style,
  ]) async => null;

  @override
  Future<void> saveTile(
    int z,
    int x,
    int y,
    Uint8List bytes, [
    MapLayerStyle? style,
  ]) async {}

  @override
  Future<bool> isTileCached(
    int z,
    int x,
    int y, [
    MapLayerStyle? style,
  ]) async => false;

  @override
  Future<int> getCachedTileCount([MapLayerStyle? style]) async => 0;
}

void main() {
  group('OfflineRoutingEngine Pure-Dart A* Tests', () {
    late OfflineRoutingEngine engine;

    setUp(() {
      engine = OfflineRoutingEngine.createAltoSolimoesNetwork();
    });

    test(
      'TC-ROUTING-01: Finds shortest path between SAI Centro and Betânia',
      () {
        final result = engine.findRoute(
          startId: 'SAI_CENTRO',
          goalId: 'BETANIA_CENTRO',
          mode: RoutingMode.walking,
        );

        expect(result.isSuccess, isTrue);
        expect(
          result.pathNodeIds,
          equals([
            'SAI_CENTRO',
            'SAI_SUL',
            'ESTRADA_BETANIA_1',
            'ESTRADA_BETANIA_2',
            'BETANIA_CENTRO',
          ]),
        );
        expect(result.totalDistanceMeters, greaterThan(15000));
        expect(
          result.estimatedDuration.inHours,
          greaterThanOrEqualTo(3),
        ); // ~3h 56min de caminhada
        expect(result.steps.length, equals(4));
      },
    );

    test(
      'TC-ROUTING-02: Driving mode calculates faster duration than walking',
      () {
        final walkResult = engine.findRoute(
          startId: 'SAI_CENTRO',
          goalId: 'BETANIA_CENTRO',
          mode: RoutingMode.walking,
        );
        final driveResult = engine.findRoute(
          startId: 'SAI_CENTRO',
          goalId: 'BETANIA_CENTRO',
          mode: RoutingMode.driving,
        );

        expect(walkResult.isSuccess, isTrue);
        expect(driveResult.isSuccess, isTrue);
        expect(
          walkResult.totalDistanceMeters,
          equals(driveResult.totalDistanceMeters),
        );
        expect(
          driveResult.estimatedDuration.inSeconds,
          lessThan(walkResult.estimatedDuration.inSeconds),
        );
      },
    );

    test(
      'TC-ROUTING-03: Rio Solimões direct crossing is blocked without ferry',
      () {
        // Tentar ir de SAI Sul direto para Lago Grande (aresta marcada com isWaterCrossingWithoutBridge)
        // Como não há conexão terrestre contínua sem a balsa, se permitirmos apenas conexões sem balsa:
        final simpleEngine = OfflineRoutingEngine();
        simpleEngine.addNode(const RoutingNode('N1', -3.10, -67.90));
        simpleEngine.addNode(const RoutingNode('N2', -3.30, -67.90));
        simpleEngine.addBidirectionalEdge('N1', 'N2', isWaterCrossing: true);

        final blocked = simpleEngine.findRoute(
          startId: 'N1',
          goalId: 'N2',
          allowWaterCrossingWithoutBridge: false,
        );
        expect(blocked.isSuccess, isFalse);
        expect(blocked.errorMessage, contains('restrições viárias e fluviais'));

        final allowed = simpleEngine.findRoute(
          startId: 'N1',
          goalId: 'N2',
          allowWaterCrossingWithoutBridge: true,
        );
        expect(allowed.isSuccess, isTrue);
      },
    );

    test('TC-ROUTING-04: Trans-Solimões route successfully uses authorized ferry to Lago Grande', () {
      final result = engine.findRoute(
        startId: 'SAI_CENTRO',
        goalId: 'LAGO_GRANDE',
        mode: RoutingMode.driving,
      );

      expect(result.isSuccess, isTrue);
      expect(result.pathNodeIds, contains('BALSA_PORTO_NORTE'));
      expect(result.pathNodeIds, contains('BALSA_PORTO_SUL'));
      expect(result.pathNodeIds, contains('LAGO_GRANDE'));

      // Verifica instrução de balsa
      final ferryStep = result.steps.firstWhere((s) => s.isFerryCrossing);
      expect(ferryStep.instruction, contains('balsa fluvial'));
    });

    test(
      'TC-ROUTING-05: Start equals Goal returns instant zero-distance arrival',
      () {
        final result = engine.findRoute(
          startId: 'SAI_CENTRO',
          goalId: 'SAI_CENTRO',
        );

        expect(result.isSuccess, isTrue);
        expect(result.totalDistanceMeters, equals(0.0));
        expect(result.estimatedDuration, equals(Duration.zero));
        expect(result.pathNodeIds, equals(['SAI_CENTRO']));
      },
    );

    test('TC-ROUTING-06: Non-existent start or goal returns safe error', () {
      final invalidStart = engine.findRoute(
        startId: 'NAO_EXISTE',
        goalId: 'SAI_CENTRO',
      );
      expect(invalidStart.isSuccess, isFalse);
      expect(invalidStart.errorMessage, contains('Ponto de partida'));

      final invalidGoal = engine.findRoute(
        startId: 'SAI_CENTRO',
        goalId: 'DESTINO_FANTASMA',
      );
      expect(invalidGoal.isSuccess, isFalse);
      expect(invalidGoal.errorMessage, contains('Ponto de destino'));
    });

    test(
      'TC-ROUTING-07: Haversine distance heuristic is admissible (h <= d_real)',
      () {
        final n1 = engine.nodes['SAI_CENTRO']!;
        final n2 = engine.nodes['BETANIA_CENTRO']!;
        final straightLine = OfflineRoutingEngine.haversineDistanceMeters(
          n1.latitude,
          n1.longitude,
          n2.latitude,
          n2.longitude,
        );

        final route = engine.findRoute(
          startId: 'SAI_CENTRO',
          goalId: 'BETANIA_CENTRO',
        );
        expect(route.isSuccess, isTrue);
        expect(route.totalDistanceMeters, greaterThanOrEqualTo(straightLine));
      },
    );

    test('TC-ROUTING-08: Formatted summary returns human readable metrics', () {
      final route = engine.findRoute(
        startId: 'SAI_CENTRO',
        goalId: 'BETANIA_CENTRO',
      );
      final summary = route.formattedSummary;
      expect(summary, contains('km'));
      expect(summary, contains('min'));
    });

    test(
      'TC-ROUTING-09: JSON serialization and deserialization preserves graph integrity and routing parity',
      () {
        final originalJson = engine.toJson();
        expect(originalJson['nodes'], isA<List>());
        expect(originalJson['edges'], isA<List>());
        expect((originalJson['nodes'] as List).length, equals(engine.nodes.length));

        final restoredEngine = OfflineRoutingEngine.fromJson(originalJson);
        expect(restoredEngine.nodes.length, equals(engine.nodes.length));

        final origResult = engine.findRoute(
          startId: 'SAI_CENTRO',
          goalId: 'BETANIA_CENTRO',
          mode: RoutingMode.walking,
        );
        final restoredResult = restoredEngine.findRoute(
          startId: 'SAI_CENTRO',
          goalId: 'BETANIA_CENTRO',
          mode: RoutingMode.walking,
        );

        expect(restoredResult.isSuccess, isTrue);
        expect(restoredResult.pathNodeIds, equals(origResult.pathNodeIds));
        expect(restoredResult.totalDistanceMeters, equals(origResult.totalDistanceMeters));
        expect(restoredResult.steps.length, equals(origResult.steps.length));
      },
    );

    test(
      'TC-ROUTING-10: findNearestNode snaps nearby coordinates and returns null for distant points',
      () {
        // Coordenada próxima a SAI_CENTRO (-3.1022, -67.9397) dentro de ~50 metros
        final nearSai = engine.findNearestNode(-3.1025, -67.9400, maxDistanceMeters: 5000.0);
        expect(nearSai, isNotNull);
        expect(nearSai!.id, equals('SAI_CENTRO'));

        // Coordenada distante (São Paulo, SP: -23.5505, -46.6333, ~2700 km de distância)
        final distantSp = engine.findNearestNode(-23.5505, -46.6333, maxDistanceMeters: 5000.0);
        expect(distantSp, isNull);

        // Coordenada com raio máximo restritivo menor que a distância real
        final strict = engine.findNearestNode(-3.1025, -67.9400, maxDistanceMeters: 5.0);
        expect(strict, isNull);
      },
    );

    test('TC-ROUTING-11: findNearestNode returns null when graph has zero nodes', () {
      final emptyEngine = OfflineRoutingEngine();
      expect(emptyEngine.findNearestNode(-3.1022, -67.9397), isNull);
    });

    test(
      'TC-ROUTING-12: findRouteBetweenCoordinates returns explicit failure when graph is empty',
      () {
        final emptyEngine = OfflineRoutingEngine();
        final result = emptyEngine.findRouteBetweenCoordinates(
          startLat: -3.1022,
          startLon: -67.9397,
          goalLat: -3.1700,
          goalLon: -68.0800,
        );

        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, equals('Nenhum grafo de rotas regional carregado.'));
      },
    );

    test(
      'TC-ROUTING-13: findRouteBetweenCoordinates returns explicit failure when start is distant',
      () {
        // Origem em São Paulo, destino no Alto Solimões
        final result = engine.findRouteBetweenCoordinates(
          startLat: -23.5505,
          startLon: -46.6333,
          goalLat: -3.1700,
          goalLon: -68.0800,
        );

        expect(result.isSuccess, isFalse);
        expect(
          result.errorMessage,
          equals('Ponto de origem fora da área de cobertura do grafo regional.'),
        );
      },
    );

    test(
      'TC-ROUTING-14: findRouteBetweenCoordinates returns explicit failure when goal is distant',
      () {
        // Origem no Alto Solimões, destino em Manaus / São Paulo
        final result = engine.findRouteBetweenCoordinates(
          startLat: -3.1022,
          startLon: -67.9397,
          goalLat: -23.5505,
          goalLon: -46.6333,
        );

        expect(result.isSuccess, isFalse);
        expect(
          result.errorMessage,
          equals('Ponto de destino fora da área de cobertura do grafo regional.'),
        );
      },
    );

    test(
      'TC-ROUTING-15: findRouteBetweenCoordinates succeeds when both endpoints are within snap distance',
      () {
        // Origem a ~30m de SAI Centro, Destino a ~40m de Betânia Centro
        final result = engine.findRouteBetweenCoordinates(
          startLat: -3.1025,
          startLon: -67.9400,
          goalLat: -3.1703,
          goalLon: -68.0804,
          maxSnapDistanceMeters: 500.0,
          mode: RoutingMode.walking,
        );

        expect(result.isSuccess, isTrue);
        expect(result.pathNodeIds.first, equals('SAI_CENTRO'));
        expect(result.pathNodeIds.last, equals('BETANIA_CENTRO'));
        expect(result.totalDistanceMeters, greaterThan(15000));
        expect(result.steps.isNotEmpty, isTrue);
      },
    );
  });

  group('ContactsMapScreen Offline Routing Containment Widget Tests', () {
    testWidgets(
      'Tapping Rota Offline (A*) displays honest fallback dialog with external map option and zero synthetic routes',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final originalMbTiles = MBTilesService.instance;
        final mockMbTiles = MBTilesService.custom(backend: MBTilesWeb());
        MBTilesService.setMockInstance(mockMbTiles);
        addTearDown(() {
          MBTilesService.setMockInstance(originalMbTiles);
          mockMbTiles.dispose();
        });

        TileCacheService.instance.backend = _EmptyTestTiles();

        final db = AppDatabase.forTesting(NativeDatabase.memory());

        final now = DateTime.now();
        await db.into(db.people).insert(
          PeopleCompanion.insert(
            id: 'contact_sp',
            name: 'Contato em São Paulo',
            firstContactAt: now,
            createdAt: now,
            updatedAt: now,
            latitude: const Value(-23.5505),
            longitude: const Value(-46.6333),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: const MaterialApp(
              home: ContactsMapScreen(highlightPersonId: 'contact_sp'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check if contact action button "Rota Offline (A*)" is present
        final offlineBtn = find.text('Rota Offline (A*)');
        expect(offlineBtn, findsOneWidget);

        // Tap the offline route button
        await tester.tap(offlineBtn);
        await tester.pumpAndSettle();

        // Verify that the honest fail-closed dialog appears
        expect(find.text('Roteamento Offline'), findsOneWidget);
        expect(
          find.textContaining('O roteamento offline não está disponível para esta região'),
          findsOneWidget,
        );
        expect(find.text('Abrir no Mapa Externo'), findsOneWidget);
        expect(find.text('Fechar'), findsOneWidget);

        // Verify that synthetic Alto Solimões directions are NEVER shown
        expect(find.textContaining('Av. Beira Rio'), findsNothing);
        expect(find.textContaining('Betânia'), findsNothing);
        expect(find.textContaining('balsa fluvial'), findsNothing);

        // Close dialog
        await tester.tap(find.text('Fechar'));
        await tester.pumpAndSettle();
        expect(find.text('Roteamento Offline'), findsNothing);

        // Teardown widget and flush Drift stream cancellation timers
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await db.close();
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });
}
