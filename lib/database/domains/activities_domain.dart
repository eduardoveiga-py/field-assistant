import 'package:drift/drift.dart';

import '../app_database.dart';
import 'base_repository.dart';

/// Domínio responsável pelo registro de atividades pessoais no ministério de campo.
mixin ActivitiesDomainMixin on BaseRepository {
  Stream<List<ActivityRecordEntry>> watchActivities() {
    return (db.select(db.activityRecords)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<List<ActivityRecordEntry>> getAllActivities() {
    return (db.select(db.activityRecords)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Future<ActivityRecordEntry> createActivityRecord({
    String? id,
    required DateTime date,
    required int durationSeconds,
    required String modality,
    String? notes,
  }) async {
    final activityId = id ?? uuid.v4();
    final now = DateTime.now();

    final entry = ActivityRecordEntry(
      id: activityId,
      date: date,
      durationSeconds: durationSeconds,
      modality: modality,
      notes: notes,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      revision: 1,
    );

    await db.transaction(() async {
      await db.into(db.activityRecords).insert(entry);
      await recordSyncOperation(
        entityType: 'activity_records',
        entityId: activityId,
        operation: 'INSERT',
        payload: {
          'id': entry.id,
          'date': entry.date.toIso8601String(),
          'durationSeconds': entry.durationSeconds,
          'modality': entry.modality,
          'notes': entry.notes,
          'revision': entry.revision,
        },
      );
    });

    return entry;
  }

  Future<void> updateActivityRecord(ActivityRecordEntry activity) async {
    final existing = await (db.select(
      db.activityRecords,
    )..where((tbl) => tbl.id.equals(activity.id))).getSingleOrNull();
    final now = DateTime.now();
    final updated = activity.copyWith(
      updatedAt: now,
      revision: activity.revision + 1,
    );
    await db.transaction(() async {
      await db.update(db.activityRecords).replace(updated);
      await recordSyncOperation(
        entityType: 'activity_records',
        entityId: updated.id,
        operation: 'UPDATE',
        payload: {
          'id': updated.id,
          'durationSeconds': updated.durationSeconds,
          'modality': updated.modality,
          'notes': updated.notes,
          'revision': updated.revision,
        },
        baseData: existing?.toJson(),
      );
    });
  }

  Future<void> deleteActivityRecord(String id) async {
    final act = await (db.select(
      db.activityRecords,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (act == null) return;
    final now = DateTime.now();
    final updated = act.copyWith(
      deletedAt: Value(now),
      updatedAt: now,
      revision: act.revision + 1,
    );
    await db.transaction(() async {
      await db.update(db.activityRecords).replace(updated);
      await recordSyncOperation(
        entityType: 'activity_records',
        entityId: id,
        operation: 'DELETE',
        payload: {
          'id': id,
          'deletedAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'revision': updated.revision,
        },
      );
    });
  }
}
