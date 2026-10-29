import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/repository.dart';
import '../ui/providers.dart';

class TerritorySector {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;

  TerritorySector({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TerritorySector.fromMap(Map<String, dynamic> map) {
    return TerritorySector(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class SectorManager {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();
  final StreamController<List<TerritorySector>> _sectorsController = StreamController<List<TerritorySector>>.broadcast();
  Future<void>? _initFuture;

  SectorManager(this.db) {
    _initTable();
  }

  Future<void> _initTable() {
    _initFuture ??= _doInitTable();
    return _initFuture!;
  }

  Future<void> _doInitTable() async {
    try {
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS territory_sectors (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          description TEXT,
          created_at TEXT NOT NULL
        );
      ''');

      // Verifica se há setores cadastrados; se vazio, cadastra os setores padrão pedidos: Betânia, Lago Grande, Cidade
      final existing = await db.customSelect('SELECT COUNT(*) AS count FROM territory_sectors').getSingle();
      final count = existing.read<int>('count');
      if (count == 0) {
        final now = DateTime.now();
        await db.customInsert(
          'INSERT INTO territory_sectors (id, name, description, created_at) VALUES (?, ?, ?, ?)',
          variables: [
            Variable.withString(_uuid.v4()),
            Variable.withString('Betânia'),
            Variable.withString('Setor residencial Betânia'),
            Variable.withString(now.toIso8601String()),
          ],
        );
        await db.customInsert(
          'INSERT INTO territory_sectors (id, name, description, created_at) VALUES (?, ?, ?, ?)',
          variables: [
            Variable.withString(_uuid.v4()),
            Variable.withString('Lago Grande'),
            Variable.withString('Região do Lago Grande'),
            Variable.withString(now.add(const Duration(seconds: 1)).toIso8601String()),
          ],
        );
        await db.customInsert(
          'INSERT INTO territory_sectors (id, name, description, created_at) VALUES (?, ?, ?, ?)',
          variables: [
            Variable.withString(_uuid.v4()),
            Variable.withString('Cidade'),
            Variable.withString('Centro urbano e área comercial'),
            Variable.withString(now.add(const Duration(seconds: 2)).toIso8601String()),
          ],
        );
      }
      _refresh();
    } catch (_) {
      // Fallback gracioso
    }
  }

  Future<void> _refresh() async {
    try {
      final list = await getSectors();
      if (!_sectorsController.isClosed) {
        _sectorsController.add(list);
      }
    } catch (_) {}
  }

  Future<List<TerritorySector>> getSectors() async {
    await _initTable();
    try {
      final rows = await db.customSelect('SELECT * FROM territory_sectors ORDER BY name ASC').get();
      return rows.map((r) => TerritorySector.fromMap(r.data)).toList();
    } catch (_) {
      // Setores default de segurança caso haja exceção
      final now = DateTime.now();
      return [
        TerritorySector(id: '1', name: 'Betânia', description: 'Setor residencial Betânia', createdAt: now),
        TerritorySector(id: '2', name: 'Lago Grande', description: 'Região do Lago Grande', createdAt: now),
        TerritorySector(id: '3', name: 'Cidade', description: 'Centro urbano e área comercial', createdAt: now),
      ];
    }
  }

  Stream<List<TerritorySector>> watchSectors() async* {
    yield await getSectors();
    yield* _sectorsController.stream;
  }

  Future<TerritorySector> addSector(String name, {String? description}) async {
    await _initTable();
    final trimmed = name.trim();
    final id = _uuid.v4();
    final now = DateTime.now();

    await db.customInsert(
      'INSERT OR REPLACE INTO territory_sectors (id, name, description, created_at) VALUES (?, ?, ?, ?)',
      variables: [
        Variable.withString(id),
        Variable.withString(trimmed),
        Variable.withString(description ?? ''),
        Variable.withString(now.toIso8601String()),
      ],
    );

    final sector = TerritorySector(id: id, name: trimmed, description: description, createdAt: now);
    await _refresh();
    return sector;
  }

  Future<void> updateSector(String id, String newName, {String? description, AppRepository? repo}) async {
    await _initTable();
    final trimmed = newName.trim();

    // Obtém o nome antigo para atualizar contatos associados
    final existingRow = await db.customSelect('SELECT name FROM territory_sectors WHERE id = ?', variables: [Variable.withString(id)]).getSingleOrNull();
    final oldName = existingRow?.read<String>('name');

    await db.customUpdate(
      'UPDATE territory_sectors SET name = ?, description = ? WHERE id = ?',
      variables: [
        Variable.withString(trimmed),
        Variable.withString(description ?? ''),
        Variable.withString(id),
      ],
    );

    // Se fornecido o repositório e o nome mudou, atualiza referências nos contatos
    if (repo != null && oldName != null && oldName != trimmed) {
      final people = await repo.getAllPeople();
      for (final p in people) {
        bool changed = false;
        String? newAddress = p.address;
        if (newAddress != null && newAddress.contains(oldName)) {
          newAddress = newAddress.replaceAll(oldName, trimmed);
          changed = true;
        }
        if (changed) {
          await repo.updatePerson(p.copyWith(address: Value(newAddress)));
        }
      }
    }

    await _refresh();
  }

  Future<void> deleteSector(String id) async {
    await _initTable();
    await db.customUpdate(
      'DELETE FROM territory_sectors WHERE id = ?',
      variables: [Variable.withString(id)],
    );
    await _refresh();
  }
}

final sectorManagerProvider = Provider<SectorManager>((ref) {
  final repo = ref.watch(repositoryProvider);
  return SectorManager(repo.db);
});

final sectorsStreamProvider = StreamProvider<List<TerritorySector>>((ref) {
  final mgr = ref.watch(sectorManagerProvider);
  return mgr.watchSectors();
});
