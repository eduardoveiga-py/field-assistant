import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;

/// Modo de deslocamento para o motor de roteamento offline A*.
enum RoutingMode {
  /// Caminhada a pé (velocidade padrão de 1.25 m/s = 4.5 km/h).
  /// Permite trilhas de pedestres e escadarias; bloqueado em rodovias sem calçada.
  walking(1.25),

  /// Condução de veículo automotor (velocidade base de 8.33 m/s = 30 km/h em vias urbanas).
  /// Bloqueado em trilhas de pedestres exclusivas; sujeito a penalidade de manobra (U-turn).
  driving(8.33);

  final double defaultSpeedMps;
  const RoutingMode(this.defaultSpeedMps);
}

/// Vértice geográfico (nó) do grafo de roteamento.
class RoutingNode {
  final String id;
  final double latitude;
  final double longitude;
  final String? name;
  final Map<String, dynamic> tags;

  const RoutingNode(
    this.id,
    this.latitude,
    this.longitude, {
    this.name,
    this.tags = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'latitude': latitude,
    'longitude': longitude,
    if (name != null) 'name': name,
    'tags': tags,
  };

  factory RoutingNode.fromJson(Map<String, dynamic> json) => RoutingNode(
    json['id'] as String,
    (json['latitude'] as num).toDouble(),
    (json['longitude'] as num).toDouble(),
    name: json['name'] as String?,
    tags: Map<String, dynamic>.from(json['tags'] as Map? ?? {}),
  );
}

/// Aresta direcionada conectando dois nós geográficos.
class RoutingEdge {
  final String fromId;
  final String toId;
  final double distanceMeters;
  final bool isWaterCrossingWithoutBridge;
  final bool isFerry;
  final double? speedMps;
  final bool isOneWay;
  final bool pedestrianAccessible;
  final bool vehicleAccessible;
  final String? streetName;

  const RoutingEdge({
    required this.fromId,
    required this.toId,
    required this.distanceMeters,
    this.isWaterCrossingWithoutBridge = false,
    this.isFerry = false,
    this.speedMps,
    this.isOneWay = false,
    this.pedestrianAccessible = true,
    this.vehicleAccessible = true,
    this.streetName,
  });

  Map<String, dynamic> toJson() => {
    'fromId': fromId,
    'toId': toId,
    'distanceMeters': distanceMeters,
    if (isWaterCrossingWithoutBridge) 'isWaterCrossingWithoutBridge': true,
    if (isFerry) 'isFerry': true,
    if (speedMps != null) 'speedMps': speedMps,
    if (isOneWay) 'isOneWay': true,
    'pedestrianAccessible': pedestrianAccessible,
    'vehicleAccessible': vehicleAccessible,
    if (streetName != null) 'streetName': streetName,
  };

  factory RoutingEdge.fromJson(Map<String, dynamic> json) => RoutingEdge(
    fromId: json['fromId'] as String,
    toId: json['toId'] as String,
    distanceMeters: (json['distanceMeters'] as num).toDouble(),
    isWaterCrossingWithoutBridge:
        json['isWaterCrossingWithoutBridge'] as bool? ?? false,
    isFerry: json['isFerry'] as bool? ?? false,
    speedMps: (json['speedMps'] as num?)?.toDouble(),
    isOneWay: json['isOneWay'] as bool? ?? false,
    pedestrianAccessible: json['pedestrianAccessible'] as bool? ?? true,
    vehicleAccessible: json['vehicleAccessible'] as bool? ?? true,
    streetName: json['streetName'] as String?,
  );

  /// Velocidade efetiva da aresta para o modo informado (m/s).
  double effectiveSpeedMps(RoutingMode mode) {
    if (isFerry) {
      return 4.0; // Velocidade média de balsa fluvial amazônica (~14 km/h)
    }
    if (mode == RoutingMode.walking) {
      // Caminhante anda a pé (~1.25 m/s = 4.5 km/h), independentemente do limite de velocidade de veículos da via
      return mode.defaultSpeedMps;
    }
    // Para condução automotiva (driving), usa a velocidade da via ou a padrão urbana
    if (speedMps != null && speedMps! > 0) {
      return speedMps!;
    }
    return mode.defaultSpeedMps;
  }
}

/// Instrução de manobra em um trecho da rota calculada.
class RoutingStep {
  final String instruction;
  final double distanceMeters;
  final Duration estimatedDuration;
  final String fromNodeId;
  final String toNodeId;
  final bool isFerryCrossing;

  const RoutingStep({
    required this.instruction,
    required this.distanceMeters,
    required this.estimatedDuration,
    required this.fromNodeId,
    required this.toNodeId,
    this.isFerryCrossing = false,
  });
}

/// Resultado completo de uma busca de rota via A*.
class RoutingResult {
  final bool isSuccess;
  final List<RoutingNode> pathNodes;
  final List<String> pathNodeIds;
  final double totalDistanceMeters;
  final Duration estimatedDuration;
  final List<RoutingStep> steps;
  final String? errorMessage;

  const RoutingResult._({
    required this.isSuccess,
    required this.pathNodes,
    required this.pathNodeIds,
    required this.totalDistanceMeters,
    required this.estimatedDuration,
    required this.steps,
    this.errorMessage,
  });

  factory RoutingResult.success({
    required List<RoutingNode> pathNodes,
    required double totalDistanceMeters,
    required Duration estimatedDuration,
    required List<RoutingStep> steps,
  }) {
    return RoutingResult._(
      isSuccess: true,
      pathNodes: pathNodes,
      pathNodeIds: pathNodes.map((n) => n.id).toList(),
      totalDistanceMeters: totalDistanceMeters,
      estimatedDuration: estimatedDuration,
      steps: steps,
    );
  }

  factory RoutingResult.failure(String message) {
    return RoutingResult._(
      isSuccess: false,
      pathNodes: const [],
      pathNodeIds: const [],
      totalDistanceMeters: 0.0,
      estimatedDuration: Duration.zero,
      steps: const [],
      errorMessage: message,
    );
  }

  /// Retorna resumo textual humanizado da rota.
  String get formattedSummary {
    if (!isSuccess) return errorMessage ?? 'Rota não encontrada';
    final distKm = totalDistanceMeters / 1000.0;
    final minutes = estimatedDuration.inMinutes;
    final hours = estimatedDuration.inHours;

    final timeStr = hours > 0 ? '${hours}h ${minutes % 60}min' : '$minutes min';

    if (distKm < 1.0) {
      return '${totalDistanceMeters.round()} m ($timeStr)';
    }
    return '${distKm.toStringAsFixed(1)} km ($timeStr)';
  }
}

/// Motor de Roteamento Offline em Grafo Baseado em Pure Dart A* (FA-ROUTING-01).
///
/// Implementa pathfinding 100% offline, sem requisições de rede ou dependências C++ nativas.
/// Inclui:
/// 1. Perfis de Caminhada (Walking) e Condução (Driving).
/// 2. Heurística admissível de Haversine dividida pela velocidade máxima possível.
/// 3. Restrição de barreira fluvial do Rio Solimões (impedância infinita sem balsa).
/// 4. Penalidade de manobra para reversões de sentido em becos sem saída (turnaround).
/// 5. Rede regional pré-carregada do Alto Solimões (Santo Antônio do Içá, Betânia, Lago Grande).
class OfflineRoutingEngine {
  final Map<String, RoutingNode> _nodes = {};
  final Map<String, List<RoutingEdge>> _adjacency = {};

  OfflineRoutingEngine();

  /// Vértices cadastrados no grafo.
  Map<String, RoutingNode> get nodes => Map.unmodifiable(_nodes);

  /// Arestas adjacentes mapeadas por ID de origem.
  Map<String, List<RoutingEdge>> get adjacency => Map.unmodifiable(_adjacency);

  /// Adiciona um vértice ao grafo.
  void addNode(RoutingNode node) {
    _nodes[node.id] = node;
    _adjacency.putIfAbsent(node.id, () => []);
  }

  /// Adiciona uma aresta direcionada ao grafo.
  void addEdge(RoutingEdge edge) {
    if (!_nodes.containsKey(edge.fromId) || !_nodes.containsKey(edge.toId)) {
      throw ArgumentError(
        'Nós de origem (${edge.fromId}) e destino (${edge.toId}) devem ser adicionados antes da aresta.',
      );
    }
    _adjacency.putIfAbsent(edge.fromId, () => []).add(edge);
  }

  /// Adiciona uma aresta bidirecional entre dois vértices, calculando a distância Haversine
  /// caso não seja fornecida explicitamente.
  void addBidirectionalEdge(
    String idA,
    String idB, {
    double? distanceMeters,
    bool isWaterCrossing = false,
    bool isFerry = false,
    double? speedMps,
    bool pedestrianAccessible = true,
    bool vehicleAccessible = true,
    String? streetName,
  }) {
    final nodeA = _nodes[idA];
    final nodeB = _nodes[idB];
    if (nodeA == null || nodeB == null) {
      throw ArgumentError('Nós $idA e $idB devem existir no grafo.');
    }

    final dist =
        distanceMeters ??
        haversineDistanceMeters(
          nodeA.latitude,
          nodeA.longitude,
          nodeB.latitude,
          nodeB.longitude,
        );

    addEdge(
      RoutingEdge(
        fromId: idA,
        toId: idB,
        distanceMeters: dist,
        isWaterCrossingWithoutBridge: isWaterCrossing,
        isFerry: isFerry,
        speedMps: speedMps,
        pedestrianAccessible: pedestrianAccessible,
        vehicleAccessible: vehicleAccessible,
        streetName: streetName,
      ),
    );

    addEdge(
      RoutingEdge(
        fromId: idB,
        toId: idA,
        distanceMeters: dist,
        isWaterCrossingWithoutBridge: isWaterCrossing,
        isFerry: isFerry,
        speedMps: speedMps,
        pedestrianAccessible: pedestrianAccessible,
        vehicleAccessible: vehicleAccessible,
        streetName: streetName,
      ),
    );
  }

  /// Exporta o grafo completo em formato Map serializável.
  Map<String, dynamic> toJson() => {
    'nodes': _nodes.values.map((n) => n.toJson()).toList(),
    'edges': _adjacency.values.expand((edges) => edges).map((e) => e.toJson()).toList(),
  };

  /// Carrega nós e arestas a partir de estrutura JSON serializada.
  void loadFromJson(Map<String, dynamic> json) {
    if (json['nodes'] is List) {
      for (final raw in json['nodes'] as List) {
        if (raw is Map<String, dynamic>) {
          addNode(RoutingNode.fromJson(raw));
        } else if (raw is Map) {
          addNode(RoutingNode.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }
    if (json['edges'] is List) {
      for (final raw in json['edges'] as List) {
        if (raw is Map<String, dynamic>) {
          addEdge(RoutingEdge.fromJson(raw));
        } else if (raw is Map) {
          addEdge(RoutingEdge.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }
  }

  /// Construtor de fábrica para inicializar grafo a partir de JSON.
  factory OfflineRoutingEngine.fromJson(Map<String, dynamic> json) {
    final engine = OfflineRoutingEngine();
    engine.loadFromJson(json);
    return engine;
  }

  /// Executa o algoritmo A* para encontrar a rota ótima entre [startId] e [goalId].
  RoutingResult findRoute({
    required String startId,
    required String goalId,
    RoutingMode mode = RoutingMode.walking,
    bool allowWaterCrossingWithoutBridge = false,
  }) {
    final startNode = _nodes[startId];
    final goalNode = _nodes[goalId];

    if (startNode == null) {
      return RoutingResult.failure(
        'Ponto de partida "$startId" não encontrado no grafo.',
      );
    }
    if (goalNode == null) {
      return RoutingResult.failure(
        'Ponto de destino "$goalId" não encontrado no grafo.',
      );
    }

    // Caso trivial: origem é igual ao destino
    if (startId == goalId) {
      return RoutingResult.success(
        pathNodes: [startNode],
        totalDistanceMeters: 0.0,
        estimatedDuration: Duration.zero,
        steps: const [],
      );
    }

    // Velocidade máxima permitida para garantir heurística estritamente admissível
    final double maxProfileSpeedMps = mode == RoutingMode.walking
        ? 2.5
        : 33.33; // ~120 km/h

    // A* Data Structures
    final openSet = <String>{startId};
    final cameFromNode = <String, String>{};
    final cameFromEdge = <String, RoutingEdge>{};

    // gScore: menor custo conhecido do início até n (em segundos)
    final gScore = <String, double>{startId: 0.0};
    // distanceAccumulator: distância percorrida em metros
    final distanceSoFar = <String, double>{startId: 0.0};

    // fScore: gScore + heurística estimada até o destino
    final fScore = <String, double>{
      startId: _heuristicSeconds(startNode, goalNode, maxProfileSpeedMps),
    };

    while (openSet.isNotEmpty) {
      // Extrai nó com menor fScore
      String current = openSet.first;
      double lowestF = fScore[current] ?? double.infinity;
      for (final n in openSet) {
        final score = fScore[n] ?? double.infinity;
        if (score < lowestF) {
          lowestF = score;
          current = n;
        }
      }

      // Destino alcançado: reconstrói trajeto
      if (current == goalId) {
        return _reconstructPath(
          goalId: goalId,
          startId: startId,
          cameFromNode: cameFromNode,
          cameFromEdge: cameFromEdge,
          totalDistanceMeters: distanceSoFar[goalId] ?? 0.0,
          totalDurationSeconds: gScore[goalId] ?? 0.0,
          mode: mode,
        );
      }

      openSet.remove(current);
      final currentEdges = _adjacency[current] ?? <RoutingEdge>[];

      for (final edge in currentEdges) {
        // Validação de acessibilidade por modo
        if (mode == RoutingMode.walking && !edge.pedestrianAccessible) continue;
        if (mode == RoutingMode.driving && !edge.vehicleAccessible) continue;

        // Validação de barreira fluvial amazônica (Rio Solimões)
        if (edge.isWaterCrossingWithoutBridge &&
            !allowWaterCrossingWithoutBridge) {
          continue; // Impedância infinita
        }

        // Custo base de tempo para atravessar a aresta (segundos)
        final speed = edge.effectiveSpeedMps(mode);
        var edgeDurationSeconds = edge.distanceMeters / speed;

        // Penalidade de manobra em marcha ré / turnaround (U-Turn 180°)
        if (cameFromEdge.containsKey(current)) {
          final prevEdge = cameFromEdge[current]!;
          if (prevEdge.fromId == edge.toId) {
            // Reversão direta no mesmo eixo viário
            final turnaroundPenalty = calculateTurnaroundPenalty(
              mode: mode,
              previousNodeId: prevEdge.fromId,
              currentNodeId: current,
              nextNodeId: edge.toId,
            );
            edgeDurationSeconds += turnaroundPenalty;
          }
        }

        final tentativeG =
            (gScore[current] ?? double.infinity) + edgeDurationSeconds;
        final neighborId = edge.toId;

        if (tentativeG < (gScore[neighborId] ?? double.infinity)) {
          cameFromNode[neighborId] = current;
          cameFromEdge[neighborId] = edge;
          gScore[neighborId] = tentativeG;
          distanceSoFar[neighborId] =
              (distanceSoFar[current] ?? 0.0) + edge.distanceMeters;

          final neighborNode = _nodes[neighborId]!;
          final h = _heuristicSeconds(
            neighborNode,
            goalNode,
            maxProfileSpeedMps,
          );
          fScore[neighborId] = tentativeG + h;
          openSet.add(neighborId);
        }
      }
    }

    return RoutingResult.failure(
      'Não foi possível encontrar rota viável entre "$startId" e "$goalId" considerando as restrições viárias e fluviais.',
    );
  }

  /// Heurística A* admissível em tempo (segundos).
  double _heuristicSeconds(
    RoutingNode from,
    RoutingNode to,
    double maxSpeedMps,
  ) {
    final dist = haversineDistanceMeters(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
    return dist / maxSpeedMps;
  }

  /// Reconstrói a lista de nós, etapas e métricas a partir dos mapas de rastreamento A*.
  RoutingResult _reconstructPath({
    required String goalId,
    required String startId,
    required Map<String, String> cameFromNode,
    required Map<String, RoutingEdge> cameFromEdge,
    required double totalDistanceMeters,
    required double totalDurationSeconds,
    required RoutingMode mode,
  }) {
    final pathNodeIds = <String>[goalId];
    final edgesInOrder = <RoutingEdge>[];

    var curr = goalId;
    while (cameFromNode.containsKey(curr)) {
      final prev = cameFromNode[curr]!;
      edgesInOrder.insert(0, cameFromEdge[curr]!);
      pathNodeIds.insert(0, prev);
      curr = prev;
    }

    final pathNodes = pathNodeIds.map((id) => _nodes[id]!).toList();
    final steps = <RoutingStep>[];

    for (final edge in edgesInOrder) {
      final fromNode = _nodes[edge.fromId]!;
      final toNode = _nodes[edge.toId]!;
      final speed = edge.effectiveSpeedMps(mode);
      final stepSeconds = (edge.distanceMeters / speed).round();

      String instruction;
      if (edge.isFerry) {
        instruction =
            'Embarcar na balsa fluvial em ${fromNode.name ?? fromNode.id} com destino a ${toNode.name ?? toNode.id}';
      } else if (edge.streetName != null && edge.streetName!.isNotEmpty) {
        instruction =
            'Siga por ${edge.streetName} até ${toNode.name ?? toNode.id}';
      } else {
        instruction =
            'Siga de ${fromNode.name ?? fromNode.id} até ${toNode.name ?? toNode.id}';
      }

      steps.add(
        RoutingStep(
          instruction: instruction,
          distanceMeters: edge.distanceMeters,
          estimatedDuration: Duration(seconds: stepSeconds),
          fromNodeId: edge.fromId,
          toNodeId: edge.toId,
          isFerryCrossing: edge.isFerry,
        ),
      );
    }

    return RoutingResult.success(
      pathNodes: pathNodes,
      totalDistanceMeters: totalDistanceMeters,
      estimatedDuration: Duration(seconds: totalDurationSeconds.round()),
      steps: steps,
    );
  }

  /// Calcula a penalidade de turnaround (180° reversão no mesmo eixo) para o modo especificado.
  static double calculateTurnaroundPenalty({
    required RoutingMode mode,
    required String previousNodeId,
    String? currentNodeId,
    required String nextNodeId,
  }) {
    if (previousNodeId == nextNodeId &&
        (currentNodeId == null || previousNodeId != currentNodeId)) {
      return mode == RoutingMode.walking ? 60.0 : 120.0;
    }
    return 0.0;
  }

  /// Calcula a distância ortodrômica em metros entre dois pontos geográficos pela fórmula de Haversine.
  static double haversineDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusMeters = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  /// Localiza o nó mais próximo a uma coordenada geográfica, respeitando um raio máximo de aproximação.
  /// Retorna `null` se `_nodes.isEmpty` ou se nenhum nó estiver dentro de [maxDistanceMeters].
  RoutingNode? findNearestNode(
    double latitude,
    double longitude, {
    double maxDistanceMeters = 5000.0,
  }) {
    if (_nodes.isEmpty) return null;
    RoutingNode? nearest;
    double minDistance = double.infinity;
    for (final node in _nodes.values) {
      final dist = haversineDistanceMeters(
        latitude,
        longitude,
        node.latitude,
        node.longitude,
      );
      if (dist < minDistance) {
        minDistance = dist;
        nearest = node;
      }
    }
    if (minDistance <= maxDistanceMeters) {
      return nearest;
    }
    return null;
  }

  /// Calcula a rota ótima entre coordenadas geográficas arbitrárias com aproximação delimitada (snapping).
  ///
  /// Falha com segurança caso o grafo esteja vazio ou caso os pontos de origem ou destino
  /// estejam fora do raio de cobertura [maxSnapDistanceMeters] dos nós da malha regional.
  RoutingResult findRouteBetweenCoordinates({
    required double startLat,
    required double startLon,
    required double goalLat,
    required double goalLon,
    double maxSnapDistanceMeters = 5000.0,
    RoutingMode mode = RoutingMode.walking,
  }) {
    if (_nodes.isEmpty) {
      return RoutingResult.failure('Nenhum grafo de rotas regional carregado.');
    }

    final startNode = findNearestNode(
      startLat,
      startLon,
      maxDistanceMeters: maxSnapDistanceMeters,
    );
    if (startNode == null) {
      return RoutingResult.failure(
        'Ponto de origem fora da área de cobertura do grafo regional.',
      );
    }

    final goalNode = findNearestNode(
      goalLat,
      goalLon,
      maxDistanceMeters: maxSnapDistanceMeters,
    );
    if (goalNode == null) {
      return RoutingResult.failure(
        'Ponto de destino fora da área de cobertura do grafo regional.',
      );
    }

    return findRoute(startId: startNode.id, goalId: goalNode.id, mode: mode);
  }

  /// Rede sintética demonstrativa do Alto Solimões pré-configurada para testes automatizados.
  ///
  /// ATENÇÃO: Esta malha contém dados sintéticos/demonstrativos estritamente destinados a testes
  /// de unidade e não deve ser exposta na interface de produção nem apresentada a usuários finais
  /// como uma rota real navegável.
  @visibleForTesting
  factory OfflineRoutingEngine.createAltoSolimoesNetwork() {
    final engine = OfflineRoutingEngine();

    // 1. Nós terrestres da margem Norte
    engine.addNode(
      const RoutingNode(
        'SAI_CENTRO',
        -3.1022,
        -67.9397,
        name: 'Santo Antônio do Içá (Centro)',
      ),
    );
    engine.addNode(
      const RoutingNode(
        'SAI_PORTO',
        -3.1090,
        -67.9380,
        name: 'Porto Fluvial de Santo Antônio do Içá',
      ),
    );
    engine.addNode(
      const RoutingNode(
        'SAI_SUL',
        -3.1150,
        -67.9450,
        name: 'Setor Sul de Santo Antônio do Içá',
      ),
    );
    engine.addNode(
      const RoutingNode(
        'BALSA_PORTO_NORTE',
        -3.1120,
        -67.9360,
        name: 'Terminal de Balsa (Margem Norte)',
      ),
    );
    engine.addNode(
      const RoutingNode(
        'ESTRADA_BETANIA_1',
        -3.1300,
        -67.9800,
        name: 'Estrada de Betânia (Km 5)',
      ),
    );
    engine.addNode(
      const RoutingNode(
        'ESTRADA_BETANIA_2',
        -3.1500,
        -68.0300,
        name: 'Estrada de Betânia (Km 12)',
      ),
    );
    engine.addNode(
      const RoutingNode(
        'BETANIA_CENTRO',
        -3.1700,
        -68.0800,
        name: 'Aldeia Indígena Ticuna de Betânia',
      ),
    );

    // 2. Nós da margem Sul (trans-Solimões)
    engine.addNode(
      const RoutingNode(
        'BALSA_PORTO_SUL',
        -3.2200,
        -67.9200,
        name: 'Terminal de Balsa (Margem Sul)',
      ),
    );
    engine.addNode(
      const RoutingNode(
        'LAGO_GRANDE',
        -3.2500,
        -67.8500,
        name: 'Comunidade Ribeirinha de Lago Grande',
      ),
    );

    // 3. Conexões terrestres regulares da margem Norte
    engine.addBidirectionalEdge(
      'SAI_CENTRO',
      'SAI_PORTO',
      streetName: 'Av. Beira Rio',
      speedMps: 8.33,
    );
    engine.addBidirectionalEdge(
      'SAI_PORTO',
      'BALSA_PORTO_NORTE',
      streetName: 'Acesso à Balsa Norte',
      speedMps: 8.33,
    );
    engine.addBidirectionalEdge(
      'SAI_CENTRO',
      'SAI_SUL',
      streetName: 'Rua Principal',
      speedMps: 8.33,
    );
    engine.addBidirectionalEdge(
      'SAI_SUL',
      'ESTRADA_BETANIA_1',
      streetName: 'Ramal de Betânia',
      speedMps: 11.11, // ~40 km/h
    );
    engine.addBidirectionalEdge(
      'ESTRADA_BETANIA_1',
      'ESTRADA_BETANIA_2',
      streetName: 'Ramal de Betânia',
      speedMps: 11.11,
    );
    engine.addBidirectionalEdge(
      'ESTRADA_BETANIA_2',
      'BETANIA_CENTRO',
      streetName: 'Acesso à Comunidade Betânia',
      speedMps: 8.33,
    );

    // 4. Conexões da margem Sul
    engine.addBidirectionalEdge(
      'BALSA_PORTO_SUL',
      'LAGO_GRANDE',
      streetName: 'Estrada da Margem Sul',
      speedMps: 8.33,
    );

    // 5. Travessia fluvial regular autorizada (Balsa / Ferry)
    engine.addBidirectionalEdge(
      'BALSA_PORTO_NORTE',
      'BALSA_PORTO_SUL',
      isFerry: true,
      pedestrianAccessible: false,
      streetName: 'Travessia Fluvial Rio Solimões (Balsa)',
    );

    // 6. Aresta fluvial sem ponte (travessia a vau ou nado proibida / impedância infinita)
    engine.addBidirectionalEdge(
      'SAI_SUL',
      'LAGO_GRANDE',
      isWaterCrossing: true,
      streetName: 'Leito do Rio Solimões (Sem Travessia Regular)',
    );

    return engine;
  }
}
