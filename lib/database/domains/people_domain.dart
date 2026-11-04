import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';
import 'base_repository.dart';

/// Domínio responsável por pessoas/contatos no ministério de campo.
mixin PeopleDomainMixin on BaseRepository {
  Stream<List<PersonEntry>> watchAllPeople() {
    return (db.select(db.people)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  Future<List<PersonEntry>> getAllPeople() {
    return (db.select(db.people)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
          ]))
        .get();
  }

  @override
  Future<PersonEntry?> getPersonById(String id) {
    return (db.select(db.people)
          ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<List<PersonEntry>> searchPeople(String query) async {
    final lower = query.trim().toLowerCase();
    if (lower.isEmpty) return getAllPeople();

    // 1. Localiza IDs de pessoas associadas a estudos que coincidem com a busca
    final numMatch = RegExp(r'\d+').firstMatch(lower);
    final lessonOrParaVal =
        numMatch != null ? int.tryParse(numMatch.group(0)!) : null;

    final matchingStudies = await (db.select(db.bibleStudies)
          ..where((tbl) {
            var pred = tbl.deletedAt.isNull() &
                (tbl.title.lower().like('%$lower%') |
                    tbl.publicationId.lower().like('%$lower%'));
            if (lessonOrParaVal != null) {
              pred = pred |
                  (tbl.deletedAt.isNull() &
                      (tbl.currentLesson.equals(lessonOrParaVal) |
                          tbl.currentParagraph.equals(lessonOrParaVal)));
            }
            return pred;
          }))
        .get();

    final matchingStudyIds = matchingStudies.map((s) => s.id).toList();
    List<String> personIdsFromStudies = [];
    if (matchingStudyIds.isNotEmpty) {
      final parts = await (db.select(db.studyParticipants)
            ..where((tbl) =>
                tbl.studyId.isIn(matchingStudyIds) & tbl.deletedAt.isNull()))
          .get();
      personIdsFromStudies = parts.map((p) => p.personId).toList();
    }

    // 2. Busca indexada e filtrada no SQLite
    return (db.select(db.people)
          ..where((tbl) =>
              tbl.deletedAt.isNull() &
              (tbl.name.lower().like('%$lower%') |
                  tbl.phone.lower().like('%$lower%') |
                  tbl.address.lower().like('%$lower%') |
                  tbl.generalNotes.lower().like('%$lower%') |
                  tbl.nextActionNote.lower().like('%$lower%') |
                  tbl.contactRestrictions.lower().like('%$lower%') |
                  tbl.tags.lower().like('%$lower%') |
                  tbl.preferredSchedule.lower().like('%$lower%') |
                  (personIdsFromStudies.isNotEmpty
                      ? tbl.id.isIn(personIdsFromStudies)
                      : const Constant(false))))
          ..orderBy([
            (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
          ]))
        .get();
  }

  Future<PersonEntry> createPerson({
    String? id,
    required String name,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
    DateTime? firstContactAt,
    String status = 'interessado',
    String? preferredSchedule,
    String? generalNotes,
    String? contactRestrictions,
    List<String> tags = const [],
    DateTime? lastContactAt,
    DateTime? nextActionAt,
    String? nextActionNote,
  }) async {
    final personId = id ?? uuid.v4();
    final now = DateTime.now();

    final entry = PersonEntry(
      id: personId,
      name: name.trim(),
      phone: phone?.trim(),
      address: address?.trim(),
      latitude: latitude,
      longitude: longitude,
      firstContactAt: firstContactAt ?? now,
      status: status,
      preferredSchedule: preferredSchedule,
      generalNotes: generalNotes,
      contactRestrictions: contactRestrictions,
      tags: jsonEncode(tags),
      lastContactAt: lastContactAt,
      nextActionAt: nextActionAt,
      nextActionNote: nextActionNote,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      revision: 1,
    );

    await db.transaction(() async {
      await db.into(db.people).insert(entry);
      await recordSyncOperation(
        entityType: 'people',
        entityId: personId,
        operation: 'INSERT',
        payload: {
          'id': entry.id,
          'name': entry.name,
          'phone': entry.phone,
          'address': entry.address,
          'latitude': entry.latitude,
          'longitude': entry.longitude,
          'firstContactAt': entry.firstContactAt.toIso8601String(),
          'status': entry.status,
          'preferredSchedule': entry.preferredSchedule,
          'generalNotes': entry.generalNotes,
          'contactRestrictions': entry.contactRestrictions,
          'tags': entry.tags,
          'lastContactAt': entry.lastContactAt?.toIso8601String(),
          'nextActionAt': entry.nextActionAt?.toIso8601String(),
          'nextActionNote': entry.nextActionNote,
          'revision': entry.revision,
        },
      );
    });

    return entry;
  }

  Future<void> updatePerson(PersonEntry person) async {
    final existing = await getPersonById(person.id);
    final now = DateTime.now();
    final updated = person.copyWith(
      updatedAt: now,
      revision: person.revision + 1,
    );

    await db.transaction(() async {
      await db.update(db.people).replace(updated);
      await recordSyncOperation(
        entityType: 'people',
        entityId: updated.id,
        operation: 'UPDATE',
        payload: {
          'id': updated.id,
          'name': updated.name,
          'phone': updated.phone,
          'address': updated.address,
          'latitude': updated.latitude,
          'longitude': updated.longitude,
          'status': updated.status,
          'preferredSchedule': updated.preferredSchedule,
          'generalNotes': updated.generalNotes,
          'contactRestrictions': updated.contactRestrictions,
          'tags': updated.tags,
          'lastContactAt': updated.lastContactAt?.toIso8601String(),
          'nextActionAt': updated.nextActionAt?.toIso8601String(),
          'nextActionNote': updated.nextActionNote,
          'revision': updated.revision,
        },
        baseData: existing?.toJson(),
      );
    });
  }

  Future<void> deletePerson(String id) async {
    final person = await getPersonById(id);
    if (person == null) return;
    final now = DateTime.now();
    final updated = person.copyWith(
      deletedAt: Value(now),
      updatedAt: now,
      revision: person.revision + 1,
    );

    await db.transaction(() async {
      await db.update(db.people).replace(updated);
      await recordSyncOperation(
        entityType: 'people',
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
