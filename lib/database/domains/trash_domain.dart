import 'package:drift/drift.dart';

import 'base_repository.dart';

/// Domínio responsável pela recuperação de exclusões (lixeira) e descarte definitivo.
mixin TrashDomainMixin on BaseRepository {
  Future<List<Map<String, dynamic>>> getDeletedItems() async {
    final List<Map<String, dynamic>> result = [];
    final people = await (db.select(
      db.people,
    )..where((tbl) => tbl.deletedAt.isNotNull())).get();
    for (final p in people) {
      result.add({
        'type': 'people',
        'id': p.id,
        'title': p.name,
        'subtitle': 'Contato',
        'deletedAt': p.deletedAt,
      });
    }
    final visits = await (db.select(
      db.visits,
    )..where((tbl) => tbl.deletedAt.isNotNull())).get();
    for (final v in visits) {
      result.add({
        'type': 'visits',
        'id': v.id,
        'title': 'Visita (${v.contactType})',
        'subtitle': v.topicsDiscussed ?? 'Sem assunto',
        'deletedAt': v.deletedAt,
      });
    }
    final studies = await (db.select(
      db.bibleStudies,
    )..where((tbl) => tbl.deletedAt.isNotNull())).get();
    for (final s in studies) {
      result.add({
        'type': 'bible_studies',
        'id': s.id,
        'title': s.title,
        'subtitle': 'Estudo Bíblico',
        'deletedAt': s.deletedAt,
      });
    }
    final appts = await (db.select(
      db.appointments,
    )..where((tbl) => tbl.deletedAt.isNotNull())).get();
    for (final a in appts) {
      result.add({
        'type': 'appointments',
        'id': a.id,
        'title': a.title,
        'subtitle': 'Compromisso',
        'deletedAt': a.deletedAt,
      });
    }
    final acts = await (db.select(
      db.activityRecords,
    )..where((tbl) => tbl.deletedAt.isNotNull())).get();
    for (final act in acts) {
      result.add({
        'type': 'activity_records',
        'id': act.id,
        'title': 'Atividade (${act.modality})',
        'subtitle': '${(act.durationSeconds / 60).round()} min',
        'deletedAt': act.deletedAt,
      });
    }
    result.sort(
      (a, b) =>
          (b['deletedAt'] as DateTime).compareTo(a['deletedAt'] as DateTime),
    );
    return result;
  }

  Future<void> restoreDeletedItem(String entityType, String id) async {
    final now = DateTime.now();
    await db.transaction(() async {
      int restoredRevision = 1;
      if (entityType == 'people') {
        final item = await (db.select(
          db.people,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (item != null) {
          restoredRevision = item.revision + 1;
          await db
              .update(db.people)
              .replace(
                item.copyWith(
                  deletedAt: const Value(null),
                  updatedAt: now,
                  revision: restoredRevision,
                ),
              );
        }
      } else if (entityType == 'visits') {
        final item = await (db.select(
          db.visits,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (item != null) {
          restoredRevision = item.revision + 1;
          await db
              .update(db.visits)
              .replace(
                item.copyWith(
                  deletedAt: const Value(null),
                  updatedAt: now,
                  revision: restoredRevision,
                ),
              );
        }
      } else if (entityType == 'bible_studies') {
        final item = await (db.select(
          db.bibleStudies,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (item != null) {
          restoredRevision = item.revision + 1;
          await db
              .update(db.bibleStudies)
              .replace(
                item.copyWith(
                  deletedAt: const Value(null),
                  updatedAt: now,
                  revision: restoredRevision,
                ),
              );
        }
      } else if (entityType == 'appointments') {
        final item = await (db.select(
          db.appointments,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (item != null) {
          restoredRevision = item.revision + 1;
          await db
              .update(db.appointments)
              .replace(
                item.copyWith(
                  deletedAt: const Value(null),
                  updatedAt: now,
                  revision: restoredRevision,
                ),
              );
        }
      } else if (entityType == 'activity_records') {
        final item = await (db.select(
          db.activityRecords,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (item != null) {
          restoredRevision = item.revision + 1;
          await db
              .update(db.activityRecords)
              .replace(
                item.copyWith(
                  deletedAt: const Value(null),
                  updatedAt: now,
                  revision: restoredRevision,
                ),
              );
        }
      }
      await recordSyncOperation(
        entityType: entityType,
        entityId: id,
        operation: 'UPDATE',
        payload: {
          'id': id,
          'restored': true,
          'deleted_at': null,
          'deletedAt': null,
          'updatedAt': now.toIso8601String(),
          'revision': restoredRevision,
        },
      );
    });
  }

  Future<void> permanentlyDeleteItem(String entityType, String id) async {
    await db.transaction(() async {
      if (entityType == 'people') {
        await (db.delete(db.people)..where((t) => t.id.equals(id))).go();
      } else if (entityType == 'visits') {
        await (db.delete(db.visits)..where((t) => t.id.equals(id))).go();
      } else if (entityType == 'bible_studies') {
        await (db.delete(
          db.studyParticipants,
        )..where((t) => t.studyId.equals(id))).go();
        await (db.delete(
          db.studySessions,
        )..where((t) => t.studyId.equals(id))).go();
        await (db.delete(db.bibleStudies)..where((t) => t.id.equals(id))).go();
      } else if (entityType == 'appointments') {
        await (db.delete(db.appointments)..where((t) => t.id.equals(id))).go();
      } else if (entityType == 'activity_records') {
        await (db.delete(
          db.activityRecords,
        )..where((t) => t.id.equals(id))).go();
      }
      await recordSyncOperation(
        entityType: entityType,
        entityId: id,
        operation: 'HARD_DELETE',
        payload: {'id': id, 'hardDelete': true},
      );
    });
  }
}
