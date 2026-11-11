import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/sync_timestamp.dart';
import '../database/app_database.dart';
import '../ui/providers.dart';

class FamilyTieItem {
  final String id;
  final String personId;
  final String? relatedPersonId;
  final String relatedPersonName;
  final String relationshipType;
  final DateTime createdAt;

  FamilyTieItem({
    required this.id,
    required this.personId,
    this.relatedPersonId,
    required this.relatedPersonName,
    required this.relationshipType,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'person_id': personId,
    'related_person_id': relatedPersonId,
    'related_person_name': relatedPersonName,
    'relationship_type': relationshipType,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  factory FamilyTieItem.fromEntry(FamilyTieEntry e) => FamilyTieItem(
    id: e.id,
    personId: e.personId,
    relatedPersonId: e.relatedPersonId,
    relatedPersonName: e.relatedPersonName,
    relationshipType: e.relationshipType,
    createdAt: e.createdAt,
  );

  factory FamilyTieItem.fromMap(Map<String, dynamic> map) => FamilyTieItem(
    id: map['id'] as String,
    personId: (map['person_id'] ?? map['personId']) as String,
    relatedPersonId: (map['related_person_id'] ?? map['relatedPersonId']) as String?,
    relatedPersonName:
        (map['related_person_name'] ?? map['relatedPersonName']) as String,
    relationshipType:
        (map['relationship_type'] ?? map['relationshipType']) as String,
    createdAt:
        SyncTimestamp.parse(map['created_at'] ?? map['createdAt']) ??
        DateTime.now(),
  );
}

class FamilyTiesManager {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();

  FamilyTiesManager(this.db);

  Future<List<FamilyTieItem>> getAllTies() async {
    final rows = await (db.select(db.familyTies)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    return rows.map(FamilyTieItem.fromEntry).toList();
  }

  Stream<List<FamilyTieItem>> watchAllTies() {
    return (db.select(db.familyTies)..where((t) => t.deletedAt.isNull()))
        .watch()
        .map((rows) => rows.map(FamilyTieItem.fromEntry).toList());
  }

  Future<List<FamilyTieItem>> getTiesForPerson(String personId) async {
    final rows =
        await (db.select(db.familyTies)
              ..where((t) => t.personId.equals(personId) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.relationshipType)]))
            .get();
    return rows.map(FamilyTieItem.fromEntry).toList();
  }

  static String getReciprocalRelationship(String relationship) {
    final lower = relationship.trim().toLowerCase();
    switch (lower) {
      case 'esposa':
      case 'mulher':
        return 'Marido';
      case 'marido':
      case 'esposo':
        return 'Esposa';
      case 'cônjuge':
      case 'conjuge':
        return 'Cônjuge';
      case 'pai':
      case 'mãe':
      case 'mae':
        return 'Filho(a)';
      case 'filho':
      case 'filha':
      case 'filho(a)':
        return 'Pai/Mãe';
      case 'irmão':
      case 'irmao':
      case 'irmã':
      case 'irma':
      case 'irmão(ã)':
        return 'Irmão(ã)';
      case 'padrasto':
      case 'madrasta':
        return 'Enteado(a)';
      case 'enteado':
      case 'enteada':
      case 'enteado(a)':
        return 'Padrasto/Madrasta';
      case 'avô':
      case 'avo':
      case 'avó':
        return 'Neto(a)';
      case 'neto':
      case 'neta':
      case 'neto(a)':
        return 'Avô/Avó';
      case 'sogro':
      case 'sogra':
        return 'Genro/Nora';
      case 'genro':
      case 'nora':
        return 'Sogro(a)';
      case 'parente':
        return 'Parente';
      default:
        return 'Familiar';
    }
  }

  Future<FamilyTieItem> addFamilyTie({
    required String personId,
    required String personName,
    String? relatedPersonId,
    required String relatedPersonName,
    required String relationshipType,
  }) async {
    final now = DateTime.now();
    final tieId = _uuid.v4();
    final cleanRelatedId =
        relatedPersonId != null && relatedPersonId.isNotEmpty
            ? relatedPersonId
            : null;

    final entry = FamilyTieEntry(
      id: tieId,
      personId: personId,
      relatedPersonId: cleanRelatedId,
      relatedPersonName: relatedPersonName.trim(),
      relationshipType: relationshipType.trim(),
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      revision: 1,
    );

    await db.transaction(() async {
      await db.into(db.familyTies).insert(entry);
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'family_ties',
          entityId: tieId,
          operation: 'INSERT',
          payload: jsonEncode(SyncTimestamp.normalizeMapDates(entry.toJson())),
          createdAt: now,
          status: const Value('pending'),
        ),
      );

      // VÍNCULO RECÍPROCO AUTOMÁTICO
      if (cleanRelatedId != null && cleanRelatedId != personId) {
        final reciprocalType = getReciprocalRelationship(relationshipType);
        final existingReciprocal =
            await (db.select(db.familyTies)..where(
                  (t) =>
                      t.personId.equals(cleanRelatedId) &
                      t.relatedPersonId.equals(personId) &
                      t.deletedAt.isNull(),
                ))
                .getSingleOrNull();

        if (existingReciprocal != null) {
          final updatedRec = existingReciprocal.copyWith(
            relationshipType: reciprocalType,
            relatedPersonName: personName.trim(),
            updatedAt: Value(now),
            revision: existingReciprocal.revision + 1,
          );
          await db.update(db.familyTies).replace(updatedRec);
          final payload = SyncTimestamp.normalizeMapDates(updatedRec.toJson());
          payload['_base'] = SyncTimestamp.normalizeMapDates(
            existingReciprocal.toJson(),
          );
          await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: _uuid.v4(),
              entityType: 'family_ties',
              entityId: updatedRec.id,
              operation: 'UPDATE',
              payload: jsonEncode(payload),
              createdAt: now,
              status: const Value('pending'),
            ),
          );
        } else {
          final recId = _uuid.v4();
          final recEntry = FamilyTieEntry(
            id: recId,
            personId: cleanRelatedId,
            relatedPersonId: personId,
            relatedPersonName: personName.trim(),
            relationshipType: reciprocalType,
            createdAt: now,
            updatedAt: now,
            deletedAt: null,
            revision: 1,
          );
          await db.into(db.familyTies).insert(recEntry);
          await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: _uuid.v4(),
              entityType: 'family_ties',
              entityId: recId,
              operation: 'INSERT',
              payload: jsonEncode(
                SyncTimestamp.normalizeMapDates(recEntry.toJson()),
              ),
              createdAt: now,
              status: const Value('pending'),
            ),
          );
        }
      }
    });

    return FamilyTieItem.fromEntry(entry);
  }

  Future<void> updateFamilyTie({
    required String id,
    required String newRelationshipType,
    String? newRelatedPersonName,
  }) async {
    final now = DateTime.now();
    final existing = await (db.select(db.familyTies)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) return;

    final updated = existing.copyWith(
      relationshipType: newRelationshipType.trim(),
      relatedPersonName:
          newRelatedPersonName?.trim() ?? existing.relatedPersonName,
      updatedAt: Value(now),
      revision: existing.revision + 1,
    );

    await db.transaction(() async {
      await db.update(db.familyTies).replace(updated);
      final payload = SyncTimestamp.normalizeMapDates(updated.toJson());
      payload['_base'] = SyncTimestamp.normalizeMapDates(existing.toJson());
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'family_ties',
          entityId: id,
          operation: 'UPDATE',
          payload: jsonEncode(payload),
          createdAt: now,
          status: const Value('pending'),
        ),
      );

      if (existing.relatedPersonId != null &&
          existing.relatedPersonId!.isNotEmpty) {
        final reciprocalType = getReciprocalRelationship(newRelationshipType);
        final rec = await (db.select(db.familyTies)..where(
              (t) =>
                  t.personId.equals(existing.relatedPersonId!) &
                  t.relatedPersonId.equals(existing.personId) &
                  t.deletedAt.isNull(),
            ))
            .getSingleOrNull();
        if (rec != null) {
          final updatedRec = rec.copyWith(
            relationshipType: reciprocalType,
            updatedAt: Value(now),
            revision: rec.revision + 1,
          );
          await db.update(db.familyTies).replace(updatedRec);
          final recPayload = SyncTimestamp.normalizeMapDates(updatedRec.toJson());
          recPayload['_base'] = SyncTimestamp.normalizeMapDates(rec.toJson());
          await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: _uuid.v4(),
              entityType: 'family_ties',
              entityId: rec.id,
              operation: 'UPDATE',
              payload: jsonEncode(recPayload),
              createdAt: now,
              status: const Value('pending'),
            ),
          );
        }
      }
    });
  }

  Future<void> deleteFamilyTie(
    String id, {
    bool deleteReciprocal = true,
  }) async {
    final now = DateTime.now();
    final existing = await (db.select(db.familyTies)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) return;

    await db.transaction(() async {
      final nextRev = existing.revision + 1;
      await (db.update(db.familyTies)..where((t) => t.id.equals(id))).write(
        FamilyTiesCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          revision: Value(nextRev),
        ),
      );
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'family_ties',
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

      if (deleteReciprocal &&
          existing.relatedPersonId != null &&
          existing.relatedPersonId!.isNotEmpty) {
        final rec = await (db.select(db.familyTies)..where(
              (t) =>
                  t.personId.equals(existing.relatedPersonId!) &
                  t.relatedPersonId.equals(existing.personId) &
                  t.deletedAt.isNull(),
            ))
            .getSingleOrNull();
        if (rec != null) {
          final recNextRev = rec.revision + 1;
          await (db.update(db.familyTies)..where((t) => t.id.equals(rec.id)))
              .write(
            FamilyTiesCompanion(
              deletedAt: Value(now),
              updatedAt: Value(now),
              revision: Value(recNextRev),
            ),
          );
          await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: _uuid.v4(),
              entityType: 'family_ties',
              entityId: rec.id,
              operation: 'DELETE',
              payload: jsonEncode({
                'id': rec.id,
                'deleted_at': now.toUtc().toIso8601String(),
                'updated_at': now.toUtc().toIso8601String(),
                'revision': recNextRev,
              }),
              createdAt: now,
              status: const Value('pending'),
            ),
          );
        }
      }
    });
  }
}

final familyTiesManagerProvider = Provider<FamilyTiesManager>((ref) {
  final repo = ref.watch(repositoryProvider);
  return FamilyTiesManager(repo.db);
});

final familyTiesStreamProvider = StreamProvider<List<FamilyTieItem>>((ref) {
  final mgr = ref.watch(familyTiesManagerProvider);
  return mgr.watchAllTies();
});
