import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/sync_timestamp.dart';
import '../database/app_database.dart';
import '../ui/providers.dart';

class PersonPublicationItem {
  final String id;
  final String personId;
  final String publicationTitle;
  final String itemType; // 'entregue' ou 'pedido'
  final String status; // 'entregue', 'a_pedir', 'conseguido'
  final DateTime date;
  final String? notes;
  final DateTime createdAt;

  PersonPublicationItem({
    required this.id,
    required this.personId,
    required this.publicationTitle,
    required this.itemType,
    required this.status,
    required this.date,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'person_id': personId,
    'publication_title': publicationTitle,
    'item_type': itemType,
    'status': status,
    'date': date.toIso8601String().substring(0, 10),
    'notes': notes,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  factory PersonPublicationItem.fromEntry(PersonPublicationEntry e) =>
      PersonPublicationItem(
        id: e.id,
        personId: e.personId,
        publicationTitle: e.publicationTitle,
        itemType: e.itemType,
        status: e.status,
        date: SyncTimestamp.parse(e.date) ?? e.createdAt,
        notes: e.notes,
        createdAt: e.createdAt,
      );

  factory PersonPublicationItem.fromMap(Map<String, dynamic> map) =>
      PersonPublicationItem(
        id: map['id'] as String,
        personId: (map['person_id'] ?? map['personId']) as String,
        publicationTitle:
            (map['publication_title'] ?? map['publicationTitle']) as String,
        itemType: (map['item_type'] ?? map['itemType']) as String,
        status: map['status'] as String,
        date: SyncTimestamp.parse(map['date']) ?? DateTime.now(),
        notes: map['notes'] as String?,
        createdAt:
            SyncTimestamp.parse(map['created_at'] ?? map['createdAt']) ??
            DateTime.now(),
      );
}

class PersonPublicationsManager {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();

  PersonPublicationsManager(this.db);

  Future<List<PersonPublicationItem>> getAllPublications() async {
    final rows =
        await (db.select(db.personPublications)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.date)]))
            .get();
    return rows.map(PersonPublicationItem.fromEntry).toList();
  }

  Future<List<PersonPublicationItem>> getPublicationsForPerson(
    String personId,
  ) async {
    final rows =
        await (db.select(db.personPublications)
              ..where(
                (t) => t.personId.equals(personId) & t.deletedAt.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.date)]))
            .get();
    return rows.map(PersonPublicationItem.fromEntry).toList();
  }

  Stream<List<PersonPublicationItem>> watchAllPublications() {
    return (db.select(db.personPublications)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch()
        .map((rows) => rows.map(PersonPublicationItem.fromEntry).toList());
  }

  Future<PersonPublicationItem> addDeliveredPublication({
    required String personId,
    required String title,
    DateTime? date,
    String? notes,
  }) => addPlacedPublication(
    personId: personId,
    title: title,
    date: date,
    notes: notes,
  );

  Future<PersonPublicationItem> addPlacedPublication({
    required String personId,
    required String title,
    DateTime? date,
    String? notes,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final d = date ?? now;
    final cleanNotes =
        notes != null && notes.trim().isNotEmpty ? notes.trim() : null;

    final entry = PersonPublicationEntry(
      id: id,
      personId: personId,
      publicationTitle: title.trim(),
      itemType: 'entregue',
      status: 'entregue',
      date: d.toIso8601String().substring(0, 10),
      notes: cleanNotes,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      revision: 1,
    );

    await db.transaction(() async {
      await db.into(db.personPublications).insert(entry);
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'person_publications',
          entityId: id,
          operation: 'INSERT',
          payload: jsonEncode(SyncTimestamp.normalizeMapDates(entry.toJson())),
          createdAt: now,
          status: const Value('pending'),
        ),
      );
    });

    return PersonPublicationItem.fromEntry(entry);
  }

  Future<PersonPublicationItem> addStudentRequest({
    required String personId,
    required String title,
    String? notes,
    DateTime? targetDate,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final d = targetDate ?? now;
    final cleanNotes =
        notes != null && notes.trim().isNotEmpty ? notes.trim() : null;

    final entry = PersonPublicationEntry(
      id: id,
      personId: personId,
      publicationTitle: title.trim(),
      itemType: 'pedido',
      status: 'a_pedir',
      date: d.toIso8601String().substring(0, 10),
      notes: cleanNotes,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      revision: 1,
    );

    await db.transaction(() async {
      await db.into(db.personPublications).insert(entry);
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'person_publications',
          entityId: id,
          operation: 'INSERT',
          payload: jsonEncode(SyncTimestamp.normalizeMapDates(entry.toJson())),
          createdAt: now,
          status: const Value('pending'),
        ),
      );
    });

    return PersonPublicationItem.fromEntry(entry);
  }

  Future<void> updatePublicationStatus({
    required String id,
    required String newStatus,
    String? notes,
  }) async {
    final now = DateTime.now();
    final existing = await (db.select(db.personPublications)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) return;

    final updated = existing.copyWith(
      status: newStatus,
      notes: notes != null ? Value(notes) : Value(existing.notes),
      updatedAt: Value(now),
      revision: existing.revision + 1,
    );

    await db.transaction(() async {
      await db.update(db.personPublications).replace(updated);
      final payload = SyncTimestamp.normalizeMapDates(updated.toJson());
      payload['_base'] = SyncTimestamp.normalizeMapDates(existing.toJson());
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'person_publications',
          entityId: id,
          operation: 'UPDATE',
          payload: jsonEncode(payload),
          createdAt: now,
          status: const Value('pending'),
        ),
      );
    });
  }

  Future<void> deletePublication(String id) async {
    final now = DateTime.now();
    final existing = await (db.select(db.personPublications)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) return;

    final nextRev = existing.revision + 1;
    await db.transaction(() async {
      await (db.update(db.personPublications)..where((t) => t.id.equals(id)))
          .write(
        PersonPublicationsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          revision: Value(nextRev),
        ),
      );
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'person_publications',
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

final personPublicationsManagerProvider = Provider<PersonPublicationsManager>((
  ref,
) {
  final repo = ref.watch(repositoryProvider);
  return PersonPublicationsManager(repo.db);
});

final personPublicationsStreamProvider =
    StreamProvider<List<PersonPublicationItem>>((ref) {
      final mgr = ref.watch(personPublicationsManagerProvider);
      return mgr.watchAllPublications();
    });
