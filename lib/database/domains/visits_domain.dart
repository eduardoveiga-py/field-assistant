import 'package:drift/drift.dart';

import '../app_database.dart';
import 'base_repository.dart';

/// Domínio responsável por revisitas e histórico de encontros ministeriais.
mixin VisitsDomainMixin on BaseRepository {
  Stream<List<VisitEntry>> watchVisitsForPerson(String personId) {
    return (db.select(db.visits)
          ..where(
            (tbl) => tbl.personId.equals(personId) & tbl.deletedAt.isNull(),
          )
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.dateTimeField,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  Stream<List<VisitEntry>> watchAllVisits() {
    return (db.select(db.visits)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.dateTimeField,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  Future<List<VisitEntry>> getVisitsForPerson(String personId) {
    return (db.select(db.visits)
          ..where(
            (tbl) => tbl.personId.equals(personId) & tbl.deletedAt.isNull(),
          )
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.dateTimeField,
              mode: OrderingMode.desc,
            ),
          ]))
        .get();
  }

  Future<List<VisitEntry>> getAllVisits() {
    return (db.select(db.visits)..where((tbl) => tbl.deletedAt.isNull())).get();
  }

  Future<VisitEntry?> getVisitById(String id) {
    return (db.select(db.visits)
          ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<VisitEntry> createVisit({
    String? id,
    required String personId,
    required DateTime dateTime,
    required String contactType,
    required String result,
    String? notes,
    String? topicsDiscussed,
    String? scriptureOrPub,
    String? expressedQuestion,
    String? nextStep,
    DateTime? suggestedReturnDate,
    String? appointmentId,
  }) async {
    final visitId = id ?? uuid.v4();
    final now = DateTime.now();

    final entry = VisitEntry(
      id: visitId,
      personId: personId,
      dateTimeField: dateTime,
      contactType: contactType,
      result: result,
      notes: notes,
      topicsDiscussed: topicsDiscussed,
      scriptureOrPub: scriptureOrPub,
      expressedQuestion: expressedQuestion,
      nextStep: nextStep,
      suggestedReturnDate: suggestedReturnDate,
      appointmentId: appointmentId,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      revision: 1,
    );

    await db.transaction(() async {
      await db.into(db.visits).insert(entry);

      // Atualiza metadados da pessoa sem apagar históricos prévios
      final person = await getPersonById(personId);
      if (person != null) {
        final updatePersonData = person.copyWith(
          lastContactAt: Value(dateTime),
          nextActionAt: suggestedReturnDate != null
              ? Value(suggestedReturnDate)
              : person.nextActionAt != null
              ? Value(person.nextActionAt)
              : const Value.absent(),
          nextActionNote: nextStep != null
              ? Value(nextStep)
              : person.nextActionNote != null
              ? Value(person.nextActionNote)
              : const Value.absent(),
          updatedAt: now,
          revision: person.revision + 1,
        );
        await db.update(db.people).replace(updatePersonData);
        await recordSyncOperation(
          entityType: 'people',
          entityId: person.id,
          operation: 'UPDATE',
          payload: {
            'id': updatePersonData.id,
            'name': updatePersonData.name,
            'phone': updatePersonData.phone,
            'firstContactAt': updatePersonData.firstContactAt.toIso8601String(),
            'lastContactAt': updatePersonData.lastContactAt?.toIso8601String(),
            'nextActionAt': updatePersonData.nextActionAt?.toIso8601String(),
            'nextActionNote': updatePersonData.nextActionNote,
            'status': updatePersonData.status,
            'tags': updatePersonData.tags,
            'generalNotes': updatePersonData.generalNotes,
            'revision': updatePersonData.revision,
            'updatedAt': now.toIso8601String(),
          },
          baseData: person.toJson(),
        );
      }

      await recordSyncOperation(
        entityType: 'visits',
        entityId: visitId,
        operation: 'INSERT',
        payload: {
          'id': entry.id,
          'personId': entry.personId,
          'dateTimeField': entry.dateTimeField.toIso8601String(),
          'contactType': entry.contactType,
          'result': entry.result,
          'notes': entry.notes,
          'topicsDiscussed': entry.topicsDiscussed,
          'scriptureOrPub': entry.scriptureOrPub,
          'expressedQuestion': entry.expressedQuestion,
          'nextStep': entry.nextStep,
          'suggestedReturnDate': entry.suggestedReturnDate?.toIso8601String(),
          'appointmentId': entry.appointmentId,
          'revision': entry.revision,
        },
      );
    });

    return entry;
  }

  Future<void> updateVisit(VisitEntry visit) async {
    final existing = await (db.select(
      db.visits,
    )..where((tbl) => tbl.id.equals(visit.id))).getSingleOrNull();
    final now = DateTime.now();
    final updated = visit.copyWith(
      updatedAt: now,
      revision: visit.revision + 1,
    );
    await db.transaction(() async {
      await db.update(db.visits).replace(updated);
      await recordSyncOperation(
        entityType: 'visits',
        entityId: updated.id,
        operation: 'UPDATE',
        payload: {
          'id': updated.id,
          'notes': updated.notes,
          'topicsDiscussed': updated.topicsDiscussed,
          'result': updated.result,
          'nextStep': updated.nextStep,
          'suggestedReturnDate': updated.suggestedReturnDate?.toIso8601String(),
          'revision': updated.revision,
        },
        baseData: existing?.toJson(),
      );
    });
  }

  Future<void> deleteVisit(String id) async {
    final visit = await (db.select(
      db.visits,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (visit == null) return;
    final now = DateTime.now();
    final updated = visit.copyWith(
      deletedAt: Value(now),
      updatedAt: now,
      revision: visit.revision + 1,
    );
    await db.transaction(() async {
      await db.update(db.visits).replace(updated);
      await recordSyncOperation(
        entityType: 'visits',
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
