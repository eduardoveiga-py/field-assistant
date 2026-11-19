import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/territory/routing/offline_routing_engine.dart';

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

    test('TC-ROUTING-09: JSON serialization and deserialization preserves graph integrity and routing parity', () {
      final originalJson = engine.toJson();
      expect(originalJson['nodes'], isA<List>());
      expect(originalJson['edges'], isA<List>());
      expect(
        (originalJson['nodes'] as List).length,
        equals(engine.nodes.length),
      );

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
      expect(
        restoredResult.totalDistanceMeters,
        equals(origResult.totalDistanceMeters),
      );
      expect(restoredResult.steps.length, equals(origResult.steps.length));
    });
  });
}
