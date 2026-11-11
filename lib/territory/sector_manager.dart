import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/sync_timestamp.dart';
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
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  factory TerritorySector.fromEntry(TerritorySectorEntry e) {
    return TerritorySector(
      id: e.id,
      name: e.name,
      description: e.description,
      createdAt: e.createdAt,
    );
  }

  factory TerritorySector.fromMap(Map<String, dynamic> map) {
    return TerritorySector(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      createdAt:
          SyncTimestamp.parse(map['created_at'] ?? map['createdAt']) ??
          DateTime.now(),
    );
  }
}

class SectorManager {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();

  SectorManager(this.db);

  Future<List<TerritorySector>> getSectors() async {
    final rows =
        await (db.select(db.territorySectors)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .get();
    return rows.map(TerritorySector.fromEntry).toList();
  }

  Stream<List<TerritorySector>> watchSectors() {
    return (db.select(db.territorySectors)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch()
        .map((rows) => rows.map(TerritorySector.fromEntry).toList());
  }

  Future<TerritorySector> addSector(String name, {String? description}) async {
    final trimmed = name.trim();
    final now = DateTime.now();
    final cleanDesc =
        description != null && description.trim().isNotEmpty
            ? description.trim()
            : null;

    final existingActive = await (db.select(db.territorySectors)
          ..where((t) => t.name.equals(trimmed) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (existingActive != null) {
      return TerritorySector.fromEntry(existingActive);
    }

    final id = _uuid.v4();
    final entry = TerritorySectorEntry(
      id: id,
      name: trimmed,
      description: cleanDesc,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      revision: 1,
    );

    await db.transaction(() async {
      await db.into(db.territorySectors).insert(entry);
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'territory_sectors',
          entityId: id,
          operation: 'INSERT',
          payload: jsonEncode(SyncTimestamp.normalizeMapDates(entry.toJson())),
          createdAt: now,
          status: const Value('pending'),
        ),
      );
    });

    return TerritorySector.fromEntry(entry);
  }

  Future<void> updateSector(
    String id,
    String newName, {
    String? description,
    AppRepository? repo,
  }) async {
    final trimmed = newName.trim();
    final now = DateTime.now();
    final existing = await (db.select(db.territorySectors)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) return;
    final oldName = existing.name;

    final cleanDesc = description != null
        ? (description.trim().isNotEmpty ? description.trim() : null)
        : existing.description;
    final updated = existing.copyWith(
      name: trimmed,
      description: Value(cleanDesc),
      updatedAt: Value(now),
      revision: existing.revision + 1,
    );

    await db.transaction(() async {
      await db.update(db.territorySectors).replace(updated);
      final payload = SyncTimestamp.normalizeMapDates(updated.toJson());
      payload['_base'] = SyncTimestamp.normalizeMapDates(existing.toJson());
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'territory_sectors',
          entityId: id,
          operation: 'UPDATE',
          payload: jsonEncode(payload),
          createdAt: now,
          status: const Value('pending'),
        ),
      );
    });

    if (repo != null && oldName != trimmed) {
      final people = await repo.getAllPeople();
      for (final p in people) {
        String? newAddress = p.address;
        if (newAddress != null && newAddress.contains(oldName)) {
          newAddress = newAddress.replaceAll(oldName, trimmed);
          await repo.updatePerson(p.copyWith(address: Value(newAddress)));
        }
      }
    }
  }

  Future<void> deleteSector(String id) async {
    final now = DateTime.now();
    final existing = await (db.select(db.territorySectors)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) return;

    final nextRev = existing.revision + 1;
    await db.transaction(() async {
      await (db.update(db.territorySectors)..where((t) => t.id.equals(id)))
          .write(
        TerritorySectorsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          revision: Value(nextRev),
        ),
      );
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'territory_sectors',
          entityId: id,
          operation: 'DELETE',
          payload: jsonEncode({
            'id': id,
            'deleted_at': now.toUtc().toIso8601String(),
            'updated_at': now.toUtc().toIso8601String(),
            'revision': nextRev,
          }),
          createdAt: now,
          status: const Value('pending'),
        ),
      );
    });
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
