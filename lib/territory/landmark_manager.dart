import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../ui/providers.dart';

class TerritoryLandmark {
  final String id;
  final String name;
  final String category; // 'padaria', 'escola', 'saude', 'transporte', 'mercado', 'praca', 'religioso', 'combustivel', 'outro'
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? notes;
  final DateTime createdAt;

  TerritoryLandmark({
    required this.id,
    required this.name,
    required this.category,
    this.address,
    this.latitude,
    this.longitude,
    this.notes,
    required this.createdAt,
  });

  /// Validador de coordenadas geográficas
  static bool isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    return lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0;
  }

  /// Retorna true apenas se o ponto possuir coordenadas geográficas reais e válidas
  bool get hasValidCoordinates => isValidCoordinate(latitude, longitude);

  IconData get icon {
    switch (category.toLowerCase()) {
      case 'padaria':
      case 'comercio':
        return Icons.storefront;
      case 'escola':
      case 'colegio':
        return Icons.school;
      case 'saude':
      case 'posto_saude':
      case 'hospital':
        return Icons.local_hospital;
      case 'transporte':
      case 'onibus':
      case 'terminal':
        return Icons.directions_bus;
      case 'mercado':
      case 'supermercado':
        return Icons.shopping_cart;
      case 'praca':
      case 'parque':
        return Icons.park;
      case 'religioso':
      case 'igreja':
      case 'salao':
        return Icons.church;
      case 'combustivel':
      case 'posto':
        return Icons.local_gas_station;
      case 'outro':
      default:
        return Icons.place;
    }
  }

  Color get color {
    switch (category.toLowerCase()) {
      case 'padaria':
      case 'comercio':
        return const Color(0xFFD97706); // Âmbar
      case 'escola':
        return const Color(0xFF2563EB); // Azul
      case 'saude':
        return const Color(0xFFDC2626); // Vermelho
      case 'transporte':
        return const Color(0xFF4F46E5); // Índigo
      case 'mercado':
        return const Color(0xFF059669); // Verde
      case 'praca':
        return const Color(0xFF0D9488); // Teal
      case 'religioso':
        return const Color(0xFF7C3AED); // Roxo
      case 'combustivel':
        return const Color(0xFFEA580C); // Laranja escuro
      case 'outro':
      default:
        return const Color(0xFF475569); // Cinza
    }
  }

  String get categoryLabel {
    switch (category.toLowerCase()) {
      case 'padaria':
        return 'Padaria / Comércio';
      case 'escola':
        return 'Escola / Colégio';
      case 'saude':
        return 'Posto de Saúde / Hospital';
      case 'transporte':
        return 'Ponto de Ônibus / Terminal';
      case 'mercado':
        return 'Supermercado';
      case 'praca':
        return 'Praça / Parque';
      case 'religioso':
        return 'Salão do Reino / Igreja';
      case 'combustivel':
        return 'Posto de Combustível';
      case 'outro':
      default:
        return 'Ponto de Referência';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TerritoryLandmark.fromMap(Map<String, dynamic> map) {
    return TerritoryLandmark(
      id: map['id'] as String,
      name: map['name'] as String,
      category: map['category'] as String,
      address: map['address'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class LandmarkManager {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();
  final StreamController<List<TerritoryLandmark>> _landmarksController =
      StreamController<List<TerritoryLandmark>>.broadcast();
  Future<void>? _initFuture;

  LandmarkManager(this.db) {
    _initSeeding();
  }

  Future<void> _initSeeding() {
    _initFuture ??= _seedDefaultsIfEmpty();
    return _initFuture!;
  }

  Future<void> _seedDefaultsIfEmpty() async {
    try {
      final existing = await (db.select(db.territoryLandmarks)..limit(1)).get();
      if (existing.isEmpty) {
        final now = DateTime.now();
        await db.batch((batch) {
          batch.insertAll(db.territoryLandmarks, [
            TerritoryLandmarksCompanion.insert(
              id: _uuid.v4(),
              name: 'Padaria Central Betânia',
              category: 'padaria',
              address: const Value('Rua Principal, 50 - Betânia'),
              notes: const Value('Ponto de encontro da saída de campo no setor Betânia'),
              createdAt: now,
              updatedAt: now,
            ),
            TerritoryLandmarksCompanion.insert(
              id: _uuid.v4(),
              name: 'Posto de Saúde Lago Grande',
              category: 'saude',
              address: const Value('Av. das Águas, 300 - Lago Grande'),
              notes: const Value('Referência para as revisitas próximas à represa'),
              createdAt: now.add(const Duration(seconds: 1)),
              updatedAt: now.add(const Duration(seconds: 1)),
            ),
            TerritoryLandmarksCompanion.insert(
              id: _uuid.v4(),
              name: 'Escola Municipal Cidade',
              category: 'escola',
              address: const Value('Praça Central, s/n - Cidade'),
              notes: const Value('Referência excelente para encontrar os endereços do centro'),
              createdAt: now.add(const Duration(seconds: 2)),
              updatedAt: now.add(const Duration(seconds: 2)),
            ),
          ]);
        });
      }
      _refresh();
    } catch (_) {}
  }

  Future<void> _refresh() async {
    try {
      final list = await getLandmarks();
      if (!_landmarksController.isClosed) {
        _landmarksController.add(list);
      }
    } catch (_) {}
  }

  Future<List<TerritoryLandmark>> getLandmarks() async {
    await _initSeeding();
    try {
      final rows = await (db.select(db.territoryLandmarks)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]))
          .get();
      return rows
          .map((r) => TerritoryLandmark(
                id: r.id,
                name: r.name,
                category: r.category,
                address: r.address,
                latitude: r.latitude,
                longitude: r.longitude,
                notes: r.notes,
                createdAt: r.createdAt,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Stream<List<TerritoryLandmark>> watchLandmarks() async* {
    yield await getLandmarks();
    yield* _landmarksController.stream;
  }

  Future<TerritoryLandmark> addLandmark({
    required String name,
    required String category,
    String? address,
    double? latitude,
    double? longitude,
    String? notes,
  }) async {
    await _initSeeding();
    final id = _uuid.v4();
    final now = DateTime.now();

    final validCoords = TerritoryLandmark.isValidCoordinate(latitude, longitude);
    final cleanLat = validCoords ? latitude : null;
    final cleanLng = validCoords ? longitude : null;

    await db.into(db.territoryLandmarks).insert(
          TerritoryLandmarksCompanion.insert(
            id: id,
            name: name.trim(),
            category: category,
            address: Value(address),
            latitude: Value(cleanLat),
            longitude: Value(cleanLng),
            notes: Value(notes),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final landmark = TerritoryLandmark(
      id: id,
      name: name.trim(),
      category: category,
      address: address,
      latitude: cleanLat,
      longitude: cleanLng,
      notes: notes,
      createdAt: now,
    );

    try {
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'territory_landmarks',
          entityId: id,
          operation: 'INSERT',
          payload: jsonEncode(landmark.toMap()),
          createdAt: now,
          status: const Value('pending'),
        ),
      );
    } catch (_) {}

    await _refresh();
    return landmark;
  }

  Future<void> updateLandmark(TerritoryLandmark landmark) async {
    await _initSeeding();
    final validCoords = TerritoryLandmark.isValidCoordinate(landmark.latitude, landmark.longitude);
    final cleanLat = validCoords ? landmark.latitude : null;
    final cleanLng = validCoords ? landmark.longitude : null;
    final now = DateTime.now();

    await (db.update(db.territoryLandmarks)..where((t) => t.id.equals(landmark.id))).write(
      TerritoryLandmarksCompanion(
        name: Value(landmark.name.trim()),
        category: Value(landmark.category),
        address: Value(landmark.address),
        latitude: Value(cleanLat),
        longitude: Value(cleanLng),
        notes: Value(landmark.notes),
        updatedAt: Value(now),
      ),
    );

    try {
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'territory_landmarks',
          entityId: landmark.id,
          operation: 'UPDATE',
          payload: jsonEncode(landmark.toMap()),
          createdAt: now,
          status: const Value('pending'),
        ),
      );
    } catch (_) {}

    await _refresh();
  }

  Future<void> deleteLandmark(String id) async {
    await _initSeeding();
    final now = DateTime.now();
    await (db.update(db.territoryLandmarks)..where((t) => t.id.equals(id))).write(
      TerritoryLandmarksCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    try {
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'territory_landmarks',
          entityId: id,
          operation: 'DELETE',
          payload: jsonEncode({'id': id, 'deleted_at': now.toIso8601String()}),
          createdAt: now,
          status: const Value('pending'),
        ),
      );
    } catch (_) {}

    await _refresh();
  }
}

final landmarkManagerProvider = Provider<LandmarkManager>((ref) {
  final repo = ref.watch(repositoryProvider);
  return LandmarkManager(repo.db);
});

final landmarksStreamProvider = StreamProvider<List<TerritoryLandmark>>((ref) {
  final mgr = ref.watch(landmarkManagerProvider);
  return mgr.watchLandmarks();
});
