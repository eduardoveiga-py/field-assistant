import 'dart:async';
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
  final StreamController<List<TerritoryLandmark>> _landmarksController = StreamController<List<TerritoryLandmark>>.broadcast();
  Future<void>? _initFuture;

  LandmarkManager(this.db) {
    _initTable();
  }

  Future<void> _initTable() {
    _initFuture ??= _doInitTable();
    return _initFuture!;
  }

  Future<void> _doInitTable() async {
    try {
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS territory_landmarks (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          category TEXT NOT NULL,
          address TEXT,
          latitude REAL,
          longitude REAL,
          notes TEXT,
          created_at TEXT NOT NULL
        );
      ''');

      // Se não houver marcos, cadastra pontos de referência iniciais úteis
      final existing = await db.customSelect('SELECT COUNT(*) AS count FROM territory_landmarks').getSingle();
      final count = existing.read<int>('count');
      if (count == 0) {
        final now = DateTime.now();
        await db.customInsert(
          'INSERT INTO territory_landmarks (id, name, category, address, latitude, longitude, notes, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          variables: [
            Variable.withString(_uuid.v4()),
            Variable.withString('Padaria Central Betânia'),
            Variable.withString('padaria'),
            Variable.withString('Rua Principal, 50 - Betânia'),
            Variable.withReal(-23.551200),
            Variable.withReal(-46.634100),
            Variable.withString('Ponto de encontro da saída de campo no setor Betânia'),
            Variable.withString(now.toIso8601String()),
          ],
        );
        await db.customInsert(
          'INSERT INTO territory_landmarks (id, name, category, address, latitude, longitude, notes, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          variables: [
            Variable.withString(_uuid.v4()),
            Variable.withString('Posto de Saúde Lago Grande'),
            Variable.withString('saude'),
            Variable.withString('Av. das Águas, 300 - Lago Grande'),
            Variable.withReal(-23.558500),
            Variable.withReal(-46.645000),
            Variable.withString('Referência para as revisitas próximas à represa'),
            Variable.withString(now.add(const Duration(seconds: 1)).toIso8601String()),
          ],
        );
        await db.customInsert(
          'INSERT INTO territory_landmarks (id, name, category, address, latitude, longitude, notes, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          variables: [
            Variable.withString(_uuid.v4()),
            Variable.withString('Escola Municipal Cidade'),
            Variable.withString('escola'),
            Variable.withString('Praça Central, s/n - Cidade'),
            Variable.withReal(-23.562000),
            Variable.withReal(-46.656000),
            Variable.withString('Referência excelente para encontrar os endereços do centro'),
            Variable.withString(now.add(const Duration(seconds: 2)).toIso8601String()),
          ],
        );
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
    await _initTable();
    try {
      final rows = await db.customSelect('SELECT * FROM territory_landmarks ORDER BY name ASC').get();
      return rows.map((r) => TerritoryLandmark.fromMap(r.data)).toList();
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
    await _initTable();
    final id = _uuid.v4();
    final now = DateTime.now();

    await db.customInsert(
      'INSERT INTO territory_landmarks (id, name, category, address, latitude, longitude, notes, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(id),
        Variable.withString(name.trim()),
        Variable.withString(category),
        Variable.withString(address ?? ''),
        Variable.withReal(latitude ?? 0.0),
        Variable.withReal(longitude ?? 0.0),
        Variable.withString(notes ?? ''),
        Variable.withString(now.toIso8601String()),
      ],
    );

    final landmark = TerritoryLandmark(
      id: id,
      name: name.trim(),
      category: category,
      address: address,
      latitude: latitude,
      longitude: longitude,
      notes: notes,
      createdAt: now,
    );
    await _refresh();
    return landmark;
  }

  Future<void> updateLandmark(TerritoryLandmark landmark) async {
    await _initTable();
    await db.customUpdate(
      'UPDATE territory_landmarks SET name = ?, category = ?, address = ?, latitude = ?, longitude = ?, notes = ? WHERE id = ?',
      variables: [
        Variable.withString(landmark.name.trim()),
        Variable.withString(landmark.category),
        Variable.withString(landmark.address ?? ''),
        Variable.withReal(landmark.latitude ?? 0.0),
        Variable.withReal(landmark.longitude ?? 0.0),
        Variable.withString(landmark.notes ?? ''),
        Variable.withString(landmark.id),
      ],
    );
    await _refresh();
  }

  Future<void> deleteLandmark(String id) async {
    await _initTable();
    await db.customUpdate(
      'DELETE FROM territory_landmarks WHERE id = ?',
      variables: [Variable.withString(id)],
    );
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
