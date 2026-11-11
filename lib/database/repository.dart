import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../core/app_logger.dart';
import '../core/sync_timestamp.dart';
import 'app_database.dart';

class AppRepository {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();

  AppRepository(this.db);

  // --------------------------------------------------------------------------
  // TRANSAÇÃO AUXILIAR: MUTAÇÃO + ENFILEIRAMENTO DE SINCRONIZAÇÃO
  // --------------------------------------------------------------------------
  Map<String, dynamic> _fullSyncJson(Map<String, dynamic> raw) {
    return SyncTimestamp.normalizeMapDates(raw);
  }

  Future<void> _recordSyncOperation({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
    Map<String, dynamic>? baseData,
  }) async {
    final finalPayload = _fullSyncJson(payload);
    if (baseData != null) {
      finalPayload['_base'] = _fullSyncJson(baseData);
    }
    await db
        .into(db.syncQueue)
        .insert(
          SyncQueueCompanion.insert(
            id: _uuid.v4(),
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            payload: jsonEncode(finalPayload),
            createdAt: DateTime.now(),
            status: const Value('pending'),
          ),
        );
  }

  // --------------------------------------------------------------------------
  // MÓDULO: PESSOAS
  // --------------------------------------------------------------------------
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

  Future<PersonEntry?> getPersonById(String id) {
    return (db.select(db.people)
          ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<List<PersonEntry>> searchPeople(String query) async {
    final lower = query.trim().toLowerCase();
    if (lower.isEmpty) return getAllPeople();

    // Caminho SQL indexado (A7) para queries ASCII: evita carregar estudos e fazer O(P*S) em memória.
    if (!RegExp(r'[^\x00-\x7F]').hasMatch(lower)) {
      final like = '%$lower%';
      return db.customSelect(
        '''
        SELECT p.* FROM people p
        WHERE p.deleted_at IS NULL AND (
          lower(p.name) LIKE ?1 OR
          lower(coalesce(p.phone, '')) LIKE ?1 OR
          lower(coalesce(p.address, '')) LIKE ?1 OR
          lower(coalesce(p.general_notes, '')) LIKE ?1 OR
          lower(coalesce(p.next_action_note, '')) LIKE ?1 OR
          lower(coalesce(p.contact_restrictions, '')) LIKE ?1 OR
          lower(p.tags) LIKE ?1 OR
          lower(coalesce(p.preferred_schedule, '')) LIKE ?1 OR
          EXISTS (
            SELECT 1 FROM study_participants sp
            JOIN bible_studies bs ON bs.id = sp.study_id AND bs.deleted_at IS NULL
            WHERE sp.person_id = p.id AND sp.deleted_at IS NULL AND (
              lower(bs.title) LIKE ?1 OR
              lower(bs.publication_id) LIKE ?1
            )
          )
        )
        ORDER BY p.name COLLATE NOCASE ASC
        ''',
        variables: [Variable.withString(like)],
        readsFrom: {db.people, db.studyParticipants, db.bibleStudies},
      ).asyncMap(db.people.mapFromRow).get();
    }

    // Fallback com suporte completo a diacríticos/acentos em O(P + S)
    final all = await getAllPeople();
    final studies = await getAllStudies();
    final participants = await (db.select(
      db.studyParticipants,
    )..where((tbl) => tbl.deletedAt.isNull())).get();

    final studiesById = {for (final s in studies) s.id: s};
    final Map<String, List<BibleStudyEntry>> personStudies = {};
    for (final p in participants) {
      final study = studiesById[p.studyId];
      if (study != null) {
        personStudies.putIfAbsent(p.personId, () => []).add(study);
      }
    }

    return all.where((p) {
      final name = p.name.toLowerCase();
      final phone = (p.phone ?? '').toLowerCase();
      final address = (p.address ?? '').toLowerCase();
      final notes = (p.generalNotes ?? '').toLowerCase();
      final nextAction = (p.nextActionNote ?? '').toLowerCase();
      final restrictions = (p.contactRestrictions ?? '').toLowerCase();
      final tags = p.tags.toLowerCase();
      final schedule = (p.preferredSchedule ?? '').toLowerCase();

      final matchesDirect =
          name.contains(lower) ||
          phone.contains(lower) ||
          address.contains(lower) ||
          notes.contains(lower) ||
          nextAction.contains(lower) ||
          restrictions.contains(lower) ||
          tags.contains(lower) ||
          schedule.contains(lower);

      if (matchesDirect) return true;

      final linked = personStudies[p.id] ?? [];
      for (final s in linked) {
        if (s.title.toLowerCase().contains(lower) ||
            s.publicationId.toLowerCase().contains(lower) ||
            (s.currentLesson != null &&
                'lição ${s.currentLesson}'.contains(lower)) ||
            (s.currentParagraph != null &&
                'parágrafo ${s.currentParagraph}'.contains(lower))) {
          return true;
        }
      }

      return false;
    }).toList();
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
    final personId = id ?? _uuid.v4();
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
      await _recordSyncOperation(
        entityType: 'people',
        entityId: personId,
        operation: 'INSERT',
        payload: entry.toJson(),
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
      await _recordSyncOperation(
        entityType: 'people',
        entityId: updated.id,
        operation: 'UPDATE',
        payload: updated.toJson(),
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
      await _recordSyncOperation(
        entityType: 'people',
        entityId: id,
        operation: 'DELETE',
        payload: updated.toJson(),
        baseData: person.toJson(),
      );

      final participants = await (db.select(
        db.studyParticipants,
      )..where((t) => t.personId.equals(id) & t.deletedAt.isNull())).get();
      for (final p in participants) {
        final updatedP = p.copyWith(
          deletedAt: Value(now),
          updatedAt: now,
          revision: p.revision + 1,
        );
        await db.update(db.studyParticipants).replace(updatedP);
        await _recordSyncOperation(
          entityType: 'study_participants',
          entityId: p.id,
          operation: 'DELETE',
          payload: updatedP.toJson(),
          baseData: p.toJson(),
        );
      }
    });
  }

  // --------------------------------------------------------------------------
  // MÓDULO: REVISITAS E HISTÓRICO DE ENCONTROS
  // --------------------------------------------------------------------------
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
    final visitId = id ?? _uuid.v4();
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
        await _recordSyncOperation(
          entityType: 'people',
          entityId: person.id,
          operation: 'UPDATE',
          payload: updatePersonData.toJson(),
          baseData: person.toJson(),
        );
      }

      await _recordSyncOperation(
        entityType: 'visits',
        entityId: visitId,
        operation: 'INSERT',
        payload: entry.toJson(),
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
      await _recordSyncOperation(
        entityType: 'visits',
        entityId: updated.id,
        operation: 'UPDATE',
        payload: updated.toJson(),
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
      await _recordSyncOperation(
        entityType: 'visits',
        entityId: id,
        operation: 'DELETE',
        payload: updated.toJson(),
        baseData: visit.toJson(),
      );
    });
  }

  // --------------------------------------------------------------------------
  // MÓDULO: ESTUDOS BÍBLICOS, PARTICIPANTES E SESSÕES
  // --------------------------------------------------------------------------
  Stream<List<BibleStudyEntry>> watchAllStudies() {
    return (db.select(db.bibleStudies)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<List<BibleStudyEntry>> getAllStudies() {
    return (db.select(
      db.bibleStudies,
    )..where((tbl) => tbl.deletedAt.isNull())).get();
  }

  Future<BibleStudyEntry?> getStudyById(String id) {
    return (db.select(db.bibleStudies)
          ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<BibleStudyEntry?> getPrimaryStudyForPerson(String personId) async {
    final participants =
        await (db.select(db.studyParticipants)..where(
              (tbl) => tbl.personId.equals(personId) & tbl.deletedAt.isNull(),
            ))
            .get();
    if (participants.isEmpty) return null;
    final primary =
        participants.where((p) => p.isPrimary).firstOrNull ??
        participants.first;
    return (db.select(db.bibleStudies)..where(
          (tbl) => tbl.id.equals(primary.studyId) & tbl.deletedAt.isNull(),
        ))
        .getSingleOrNull();
  }

  Future<BibleStudyEntry> createStudy({
    String? id,
    required String title,
    String ownerId = 'local_user',
    DateTime? startedAt,
    String status = 'ativo',
    required String publicationId,
    String language = 'pt',
    int? currentLesson,
    int? currentParagraph,
    String? manualReference,
    String frequency = 'semanal',
    String? learningGoals,
    String? pendingDoubts,
    String? nextTopic,
    String? pauseOrCloseReason,
    DateTime? lastSessionAt,
    DateTime? nextPlannedAt,
    required List<String> participantPersonIds,
    String? primaryParticipantId,
  }) async {
    final studyId = id ?? _uuid.v4();
    final now = DateTime.now();

    final entry = BibleStudyEntry(
      id: studyId,
      title: title.trim(),
      ownerId: ownerId,
      startedAt: startedAt ?? now,
      status: status,
      publicationId: publicationId,
      language: language,
      currentLesson: currentLesson,
      currentParagraph: currentParagraph,
      manualReference: manualReference,
      frequency: frequency,
      learningGoals: learningGoals,
      pendingDoubts: pendingDoubts,
      nextTopic: nextTopic,
      pauseOrCloseReason: pauseOrCloseReason,
      lastSessionAt: lastSessionAt,
      nextPlannedAt: nextPlannedAt,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      revision: 1,
    );

    await db.transaction(() async {
      await db.into(db.bibleStudies).insert(entry);

      // Adiciona participantes associados (M:N)
      for (final personId in participantPersonIds) {
        final partId = _uuid.v4();
        final isPrimary =
            (personId == primaryParticipantId) ||
            (primaryParticipantId == null &&
                personId == participantPersonIds.first);

        final partEntry = StudyParticipantEntry(
          id: partId,
          studyId: studyId,
          personId: personId,
          isPrimary: isPrimary,
          createdAt: now,
          updatedAt: now,
          deletedAt: null,
          revision: 1,
        );
        await db.into(db.studyParticipants).insert(partEntry);
        await _recordSyncOperation(
          entityType: 'study_participants',
          entityId: partId,
          operation: 'INSERT',
          payload: partEntry.toJson(),
        );
      }

      await _recordSyncOperation(
        entityType: 'bible_studies',
        entityId: studyId,
        operation: 'INSERT',
        payload: entry.toJson(),
      );
    });

    return entry;
  }

  Future<void> updateStudy(BibleStudyEntry study) async {
    final existing = await getStudyById(study.id);
    final now = DateTime.now();
    final updated = study.copyWith(
      updatedAt: now,
      revision: study.revision + 1,
    );
    await db.transaction(() async {
      await db.update(db.bibleStudies).replace(updated);
      await _recordSyncOperation(
        entityType: 'bible_studies',
        entityId: updated.id,
        operation: 'UPDATE',
        payload: updated.toJson(),
        baseData: existing?.toJson(),
      );
    });
  }

  Future<void> deleteStudy(String id) async {
    final study = await getStudyById(id);
    if (study == null) return;
    final now = DateTime.now();
    final updated = study.copyWith(
      deletedAt: Value(now),
      updatedAt: now,
      revision: study.revision + 1,
    );
    await db.transaction(() async {
      await db.update(db.bibleStudies).replace(updated);
      await _recordSyncOperation(
        entityType: 'bible_studies',
        entityId: id,
        operation: 'DELETE',
        payload: updated.toJson(),
        baseData: study.toJson(),
      );

      final participants = await (db.select(
        db.studyParticipants,
      )..where((t) => t.studyId.equals(id) & t.deletedAt.isNull())).get();
      for (final p in participants) {
        final updatedP = p.copyWith(
          deletedAt: Value(now),
          updatedAt: now,
          revision: p.revision + 1,
        );
        await db.update(db.studyParticipants).replace(updatedP);
        await _recordSyncOperation(
          entityType: 'study_participants',
          entityId: p.id,
          operation: 'DELETE',
          payload: updatedP.toJson(),
          baseData: p.toJson(),
        );
      }

      final sessions = await (db.select(
        db.studySessions,
      )..where((t) => t.studyId.equals(id) & t.deletedAt.isNull())).get();
      for (final s in sessions) {
        final updatedS = s.copyWith(
          deletedAt: Value(now),
          updatedAt: now,
          revision: s.revision + 1,
        );
        await db.update(db.studySessions).replace(updatedS);
        await _recordSyncOperation(
          entityType: 'study_sessions',
          entityId: s.id,
          operation: 'DELETE',
          payload: updatedS.toJson(),
          baseData: s.toJson(),
        );
      }
    });
  }

  Future<List<StudyParticipantEntry>> getParticipantsForStudy(String studyId) {
    return (db.select(
          db.studyParticipants,
        )..where((tbl) => tbl.studyId.equals(studyId) & tbl.deletedAt.isNull()))
        .get();
  }

  Future<StudySessionEntry> createStudySession({
    String? id,
    required String studyId,
    required DateTime dateTime,
    String? publicationCode,
    int? lessonCovered,
    String? paragraphsCovered,
    String? sessionNotes,
    String? pendingQuestions,
    String? nextStep,
    String status = 'realizada',
    List<String> participantIds = const [],
  }) async {
    final sessionId = id ?? _uuid.v4();
    final now = DateTime.now();

    final entry = StudySessionEntry(
      id: sessionId,
      studyId: studyId,
      dateTimeField: dateTime,
      publicationCode: publicationCode,
      lessonCovered: lessonCovered,
      paragraphsCovered: paragraphsCovered,
      sessionNotes: sessionNotes,
      pendingQuestions: pendingQuestions,
      nextStep: nextStep,
      status: status,
      participantIds: jsonEncode(participantIds),
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      revision: 1,
    );

    await db.transaction(() async {
      await db.into(db.studySessions).insert(entry);

      if (status == 'realizada') {
        final study = await getStudyById(studyId);
        if (study != null) {
          final parsedPara = paragraphsCovered != null
              ? (int.tryParse(paragraphsCovered) ??
                    int.tryParse(
                      paragraphsCovered.split(RegExp(r'[-–,]')).last.trim(),
                    ))
              : null;
          final updatedStudy = study.copyWith(
            lastSessionAt: Value(dateTime),
            currentLesson: lessonCovered != null
                ? Value(lessonCovered)
                : study.currentLesson != null
                ? Value(study.currentLesson)
                : const Value.absent(),
            currentParagraph: parsedPara != null
                ? Value(parsedPara)
                : study.currentParagraph != null
                ? Value(study.currentParagraph)
                : const Value.absent(),
            nextTopic: nextStep != null
                ? Value(nextStep)
                : study.nextTopic != null
                ? Value(study.nextTopic)
                : const Value.absent(),
            updatedAt: now,
            revision: study.revision + 1,
          );
          await db.update(db.bibleStudies).replace(updatedStudy);

          await _recordSyncOperation(
            entityType: 'bible_studies',
            entityId: study.id,
            operation: 'UPDATE',
            payload: updatedStudy.toJson(),
            baseData: study.toJson(),
          );
        }
      }

      await _recordSyncOperation(
        entityType: 'study_sessions',
        entityId: sessionId,
        operation: 'INSERT',
        payload: entry.toJson(),
      );
    });

    return entry;
  }

  Stream<List<StudySessionEntry>> watchSessionsForStudy(String studyId) {
    return (db.select(db.studySessions)
          ..where((tbl) => tbl.studyId.equals(studyId) & tbl.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.dateTimeField,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  Future<List<StudySessionEntry>> getAllSessions() {
    return (db.select(
      db.studySessions,
    )..where((tbl) => tbl.deletedAt.isNull())).get();
  }

  Future<void> updateStudySession(StudySessionEntry session) async {
    final existing = await (db.select(
      db.studySessions,
    )..where((tbl) => tbl.id.equals(session.id))).getSingleOrNull();
    final now = DateTime.now();
    final updated = session.copyWith(
      updatedAt: now,
      revision: session.revision + 1,
    );
    await db.transaction(() async {
      await db.update(db.studySessions).replace(updated);
      await _recordSyncOperation(
        entityType: 'study_sessions',
        entityId: updated.id,
        operation: 'UPDATE',
        payload: updated.toJson(),
        baseData: existing?.toJson(),
      );
    });
  }

  Future<void> deleteStudySession(String id) async {
    final session = await (db.select(
      db.studySessions,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (session == null) return;
    final now = DateTime.now();
    final updated = session.copyWith(
      deletedAt: Value(now),
      updatedAt: now,
      revision: session.revision + 1,
    );
    await db.transaction(() async {
      await db.update(db.studySessions).replace(updated);
      await _recordSyncOperation(
        entityType: 'study_sessions',
        entityId: id,
        operation: 'DELETE',
        payload: updated.toJson(),
        baseData: session.toJson(),
      );
    });
  }

  // --------------------------------------------------------------------------
  // MÓDULO: AGENDAMENTOS E COMPROMISSOS
  // --------------------------------------------------------------------------
  Stream<List<AppointmentEntry>> watchAppointments() {
    return (db.select(db.appointments)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.startTime, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  Future<List<AppointmentEntry>> getAllAppointments() {
    return (db.select(db.appointments)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.startTime, mode: OrderingMode.asc),
          ]))
        .get();
  }

  Future<AppointmentEntry?> getAppointmentById(String id) {
    return (db.select(
      db.appointments,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<AppointmentEntry> createAppointment({
    String? id,
    String? personId,
    String? studyId,
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    int durationMinutes = 30,
    String status = 'planejado',
    String? previousAppointmentId,
    String? locationNotes,
    int? reminderMinutesBefore = 60,
    int? secondReminderMinutesBefore,
    bool isProvisional = false,
  }) async {
    final apptId = id ?? _uuid.v4();
    final now = DateTime.now();

    final entry = AppointmentEntry(
      id: apptId,
      personId: personId,
      studyId: studyId,
      title: title,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: durationMinutes,
      status: status,
      previousAppointmentId: previousAppointmentId,
      locationNotes: locationNotes,
      reminderMinutesBefore: reminderMinutesBefore,
      secondReminderMinutesBefore: secondReminderMinutesBefore,
      isProvisional: isProvisional,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      revision: 1,
    );

    await db.transaction(() async {
      await db.into(db.appointments).insert(entry);
      await _recordSyncOperation(
        entityType: 'appointments',
        entityId: apptId,
        operation: 'INSERT',
        payload: entry.toJson(),
      );
    });

    return entry;
  }

  Future<void> updateAppointment(AppointmentEntry appointment) async {
    final existing = await (db.select(
      db.appointments,
    )..where((tbl) => tbl.id.equals(appointment.id))).getSingleOrNull();
    final now = DateTime.now();
    final updated = appointment.copyWith(
      updatedAt: now,
      revision: appointment.revision + 1,
    );

    await db.transaction(() async {
      await db.update(db.appointments).replace(updated);

      // Atualiza Outbox: marca vínculos existentes como pendentes de envio aos calendários externos
      await (db.update(db.calendarEventLinks)..where(
            (tbl) =>
                tbl.appointmentId.equals(updated.id) & tbl.deletedAt.isNull(),
          ))
          .write(
            CalendarEventLinksCompanion(
              syncStatus: const Value('pending_upload'),
              updatedAt: Value(now),
            ),
          );

      await _recordSyncOperation(
        entityType: 'appointments',
        entityId: updated.id,
        operation: 'UPDATE',
        payload: updated.toJson(),
        baseData: existing?.toJson(),
      );
    });
  }

  /// Reagenda um compromisso preservando o histórico do anterior e associando o novo (Seção 5.4)
  Future<AppointmentEntry> rescheduleAppointment({
    required AppointmentEntry oldAppointment,
    required DateTime newStartTime,
    required DateTime newEndTime,
    int? durationMinutes,
    String? locationNotes,
  }) async {
    final now = DateTime.now();
    final newId = _uuid.v4();
    final dur = durationMinutes ?? oldAppointment.durationMinutes;

    final updatedOld = oldAppointment.copyWith(
      status: 'reagendado',
      updatedAt: now,
      revision: oldAppointment.revision + 1,
    );

    final newAppt = AppointmentEntry(
      id: newId,
      personId: oldAppointment.personId,
      studyId: oldAppointment.studyId,
      title: oldAppointment.title,
      startTime: newStartTime,
      endTime: newEndTime,
      durationMinutes: dur,
      status: 'confirmado',
      previousAppointmentId: oldAppointment.id,
      locationNotes: locationNotes ?? oldAppointment.locationNotes,
      reminderMinutesBefore: oldAppointment.reminderMinutesBefore,
      secondReminderMinutesBefore: oldAppointment.secondReminderMinutesBefore,
      isProvisional: false,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      revision: 1,
    );

    await db.transaction(() async {
      await db.update(db.appointments).replace(updatedOld);
      await db.into(db.appointments).insert(newAppt);

      // Marca vínculos do compromisso antigo para atualização externa
      await (db.update(db.calendarEventLinks)..where(
            (tbl) =>
                tbl.appointmentId.equals(oldAppointment.id) &
                tbl.deletedAt.isNull(),
          ))
          .write(
            CalendarEventLinksCompanion(
              syncStatus: const Value('pending_upload'),
              updatedAt: Value(now),
            ),
          );

      await _recordSyncOperation(
        entityType: 'appointments',
        entityId: oldAppointment.id,
        operation: 'UPDATE',
        payload: updatedOld.toJson(),
        baseData: oldAppointment.toJson(),
      );

      await _recordSyncOperation(
        entityType: 'appointments',
        entityId: newId,
        operation: 'INSERT',
        payload: newAppt.toJson(),
      );
    });

    return newAppt;
  }

  Future<void> deleteAppointment(String id) async {
    final appt = await (db.select(
      db.appointments,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (appt == null) return;
    final now = DateTime.now();
    final updated = appt.copyWith(
      deletedAt: Value(now),
      updatedAt: now,
      revision: appt.revision + 1,
    );
    await db.transaction(() async {
      await db.update(db.appointments).replace(updated);

      // Marca vínculos externos com pending_upload e soft delete para propagação da remoção
      await (db.update(db.calendarEventLinks)..where(
            (tbl) => tbl.appointmentId.equals(id) & tbl.deletedAt.isNull(),
          ))
          .write(
            CalendarEventLinksCompanion(
              syncStatus: const Value('pending_upload'),
              deletedAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await _recordSyncOperation(
        entityType: 'appointments',
        entityId: id,
        operation: 'DELETE',
        payload: updated.toJson(),
        baseData: appt.toJson(),
      );
    });
  }

  // --------------------------------------------------------------------------
  // MÓDULO: ATIVIDADES PESSOAIS
  // --------------------------------------------------------------------------
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
    final activityId = id ?? _uuid.v4();
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
      await _recordSyncOperation(
        entityType: 'activity_records',
        entityId: activityId,
        operation: 'INSERT',
        payload: entry.toJson(),
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
      await _recordSyncOperation(
        entityType: 'activity_records',
        entityId: updated.id,
        operation: 'UPDATE',
        payload: updated.toJson(),
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
      await _recordSyncOperation(
        entityType: 'activity_records',
        entityId: id,
        operation: 'DELETE',
        payload: updated.toJson(),
        baseData: act.toJson(),
      );
    });
  }

  // --------------------------------------------------------------------------
  // MÓDULO: RECUPERAÇÃO DE EXCLUSÕES (LIXEIRA) - SEÇÃO 8.4
  // --------------------------------------------------------------------------
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
      Map<String, dynamic>? restoredJson;
      Map<String, dynamic>? baseJson;
      if (entityType == 'people') {
        final item = await (db.select(
          db.people,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (item != null) {
          baseJson = item.toJson();
          final updated = item.copyWith(
            deletedAt: const Value(null),
            updatedAt: now,
            revision: item.revision + 1,
          );
          await db.update(db.people).replace(updated);
          restoredJson = updated.toJson();
        }
      } else if (entityType == 'visits') {
        final item = await (db.select(
          db.visits,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (item != null) {
          baseJson = item.toJson();
          final updated = item.copyWith(
            deletedAt: const Value(null),
            updatedAt: now,
            revision: item.revision + 1,
          );
          await db.update(db.visits).replace(updated);
          restoredJson = updated.toJson();
        }
      } else if (entityType == 'bible_studies') {
        final item = await (db.select(
          db.bibleStudies,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (item != null) {
          baseJson = item.toJson();
          final updated = item.copyWith(
            deletedAt: const Value(null),
            updatedAt: now,
            revision: item.revision + 1,
          );
          await db.update(db.bibleStudies).replace(updated);
          restoredJson = updated.toJson();
        }
      } else if (entityType == 'appointments') {
        final item = await (db.select(
          db.appointments,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (item != null) {
          baseJson = item.toJson();
          final updated = item.copyWith(
            deletedAt: const Value(null),
            updatedAt: now,
            revision: item.revision + 1,
          );
          await db.update(db.appointments).replace(updated);
          restoredJson = updated.toJson();
        }
      } else if (entityType == 'activity_records') {
        final item = await (db.select(
          db.activityRecords,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (item != null) {
          baseJson = item.toJson();
          final updated = item.copyWith(
            deletedAt: const Value(null),
            updatedAt: now,
            revision: item.revision + 1,
          );
          await db.update(db.activityRecords).replace(updated);
          restoredJson = updated.toJson();
        }
      }
      await _recordSyncOperation(
        entityType: entityType,
        entityId: id,
        operation: 'UPDATE',
        payload: restoredJson ??
            {
              'id': id,
              'deletedAt': null,
              'updatedAt': now.toUtc().toIso8601String(),
            },
        baseData: baseJson,
      );
    });
  }

  Future<void> permanentlyDeleteItem(String entityType, String id) async {
    await db.transaction(() async {
      if (entityType == 'people') {
        // Exclui em cascata todas as entidades filhas para respeitar integridade de chaves estrangeiras
        await (db.delete(db.visits)..where((t) => t.personId.equals(id))).go();
        await (db.delete(db.studyParticipants)..where((t) => t.personId.equals(id))).go();
        await (db.delete(db.appointments)..where((t) => t.personId.equals(id))).go();
        await (db.delete(db.familyTies)..where((t) => t.personId.equals(id) | t.relatedPersonId.equals(id))).go();
        await (db.delete(db.personPhotos)..where((t) => t.personId.equals(id))).go();
        await (db.delete(db.personPublications)..where((t) => t.personId.equals(id))).go();
        await (db.delete(db.voiceNotes)..where((t) => t.personId.equals(id))).go();
        await (db.delete(db.people)..where((t) => t.id.equals(id))).go();
      } else if (entityType == 'visits') {
        await (db.delete(db.voiceNotes)..where((t) => t.visitId.equals(id))).go();
        await (db.delete(db.visits)..where((t) => t.id.equals(id))).go();
      } else if (entityType == 'bible_studies') {
        await (db.delete(db.studyParticipants)..where((t) => t.studyId.equals(id))).go();
        await (db.delete(db.studySessions)..where((t) => t.studyId.equals(id))).go();
        await (db.delete(db.voiceNotes)..where((t) => t.studyId.equals(id))).go();
        await (db.delete(db.appointments)..where((t) => t.studyId.equals(id))).go();
        await (db.delete(db.bibleStudies)..where((t) => t.id.equals(id))).go();
      } else if (entityType == 'appointments') {
        await (db.delete(db.calendarEventLinks)..where((t) => t.appointmentId.equals(id))).go();
        await (db.delete(db.appointments)..where((t) => t.id.equals(id))).go();
      } else if (entityType == 'activity_records') {
        await (db.delete(db.activityRecords)..where((t) => t.id.equals(id))).go();
      }
      await _recordSyncOperation(
        entityType: entityType,
        entityId: id,
        operation: 'HARD_DELETE',
        payload: {'id': id, 'hardDelete': true},
      );
    });
  }

  // --------------------------------------------------------------------------
  // MÓDULO: FILA DE SINCRONIZAÇÃO
  // --------------------------------------------------------------------------
  static const int maxSyncAttempts = 5;

  static Duration backoffFor(int attempts) {
    final seconds = pow(2, attempts).clamp(1, 300).toInt();
    return Duration(seconds: seconds);
  }

  Future<List<SyncQueueEntry>> getPendingSyncOperations({
    bool respectBackoff = false,
  }) async {
    final rows = await (db.select(db.syncQueue)
          ..where(
            (tbl) =>
                tbl.status.equals('pending') | tbl.status.equals('in_progress'),
          )
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc),
          ]))
        .get();
    if (!respectBackoff) return rows;
    final now = DateTime.now();
    return rows.where((op) {
      if (op.attempts <= 0) return true;
      final lastAttempt = op.lastAttemptAt ?? op.createdAt;
      return now.difference(lastAttempt) >= backoffFor(op.attempts);
    }).toList();
  }

  Future<List<SyncQueueEntry>> getFailedSyncOperations() {
    return (db.select(db.syncQueue)
          ..where((tbl) => tbl.status.equals('failed'))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Future<List<SyncQueueEntry>> getConflictSyncOperations() {
    return (db.select(db.syncQueue)
          ..where((tbl) => tbl.status.equals('conflict'))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Future<List<SyncQueueEntry>> getUnresolvedSyncOperations() {
    return (db.select(db.syncQueue)
          ..where((tbl) => tbl.status.isIn(['pending', 'in_progress', 'failed', 'conflict']))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Stream<({int pending, int failed, int conflict})> watchSyncQueueCounts() {
    return (db.select(db.syncQueue)
          ..where((tbl) => tbl.status.isIn(['pending', 'in_progress', 'failed', 'conflict'])))
        .watch()
        .map((rows) {
      int pending = 0;
      int failed = 0;
      int conflict = 0;
      for (final row in rows) {
        if (row.status == 'failed') {
          failed++;
        } else if (row.status == 'conflict') {
          conflict++;
        } else {
          pending++;
        }
      }
      return (pending: pending, failed: failed, conflict: conflict);
    });
  }

  /// Expulga operações antigas já sincronizadas para prevenir inchaço do SQLite e backup
  Future<int> pruneOldSyncedOperations({
    Duration maxAge = const Duration(days: 30),
  }) async {
    final cutoff = DateTime.now().subtract(maxAge);
    return (db.delete(db.syncQueue)
          ..where((tbl) =>
              tbl.status.equals('synced') & tbl.createdAt.isSmallerThanValue(cutoff)))
        .go();
  }

  Future<void> markSyncOperationSuccess(String id) async {
    await (db.update(db.syncQueue)..where((tbl) => tbl.id.equals(id))).write(
      const SyncQueueCompanion(status: Value('synced')),
    );
  }

  Future<void> markSyncOperationFailed(
    String id,
    String error, {
    bool forceFailed = false,
  }) async {
    final op = await (db.select(
      db.syncQueue,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (op != null) {
      final nextAttempts = op.attempts + 1;
      await (db.update(db.syncQueue)..where((tbl) => tbl.id.equals(id))).write(
        SyncQueueCompanion(
          status: Value(
            (forceFailed || nextAttempts >= maxSyncAttempts) ? 'failed' : 'pending',
          ),
          attempts: Value(nextAttempts),
          lastError: Value(error),
          lastAttemptAt: Value(DateTime.now()),
        ),
      );
    }
  }

  Future<void> markSyncOperationConflict(
    String id,
    String error, {
    Map<String, dynamic>? remoteData,
    List<Map<String, dynamic>>? conflicts,
  }) async {
    final op = await (db.select(
      db.syncQueue,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (op == null) return;

    String updatedPayload = op.payload;
    if (remoteData != null || conflicts != null) {
      try {
        final decoded = jsonDecode(op.payload);
        if (decoded is Map<String, dynamic>) {
          if (remoteData != null) decoded['_remote'] = remoteData;
          if (conflicts != null) decoded['_conflicts'] = conflicts;
          updatedPayload = jsonEncode(decoded);
        }
      } catch (e, st) {
        AppLogger.warning(
          'Falha ao anexar metadados de conflito no payload de $id',
          e,
          st,
        );
      }
    }

    await (db.update(db.syncQueue)..where((tbl) => tbl.id.equals(id))).write(
      SyncQueueCompanion(
        status: const Value('conflict'),
        attempts: Value(op.attempts + 1),
        lastError: Value(error),
        lastAttemptAt: Value(DateTime.now()),
        payload: Value(updatedPayload),
      ),
    );
  }

  Future<int> retrySyncOperation(String id) async {
    return (db.update(db.syncQueue)..where((tbl) => tbl.id.equals(id))).write(
      const SyncQueueCompanion(
        status: Value('pending'),
        attempts: Value(0),
        lastError: Value(null),
        lastAttemptAt: Value(null),
      ),
    );
  }

  Future<void> resolveSyncConflictKeepLocal(String id) async {
    final op = await (db.select(db.syncQueue)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (op == null) return;
    Map<String, dynamic> decoded = {};
    try {
      final raw = jsonDecode(op.payload);
      if (raw is Map<String, dynamic>) {
        decoded = Map<String, dynamic>.from(raw);
      }
    } catch (e, st) {
      AppLogger.warning(
        'Falha ao decodificar payload ao manter versão local de $id',
        e,
        st,
      );
    }

    final now = DateTime.now().toUtc();
    final remoteRev = (decoded['_remote'] is Map)
        ? ((decoded['_remote']['revision'] as num?)?.toInt() ?? 1)
        : 1;
    final currentRev = (decoded['revision'] as num?)?.toInt() ?? 1;
    final nextRev = (remoteRev >= currentRev ? remoteRev : currentRev) + 1;
    decoded['revision'] = nextRev;
    decoded['updatedAt'] = now.toIso8601String();
    if (decoded['_remote'] is Map) {
      decoded['_base'] = Map<String, dynamic>.from(decoded['_remote'] as Map);
    }
    decoded.remove('_remote');
    decoded.remove('_conflicts');

    await db.transaction(() async {
      await _updateLocalEntityRevisionOnResolve(
        entityType: op.entityType,
        entityId: op.entityId,
        revision: nextRev,
        updatedAt: now,
      );
      await (db.update(db.syncQueue)..where((tbl) => tbl.id.equals(id))).write(
        SyncQueueCompanion(
          status: const Value('pending'),
          attempts: const Value(0),
          lastError: const Value(null),
          lastAttemptAt: const Value(null),
          payload: Value(jsonEncode(decoded)),
        ),
      );
    });
  }

  static const Set<String> _revisionedTables = {
    'people',
    'visits',
    'bible_studies',
    'study_participants',
    'study_sessions',
    'appointments',
    'activity_records',
    'voice_notes',
    'phone_contacts',
    'territory_landmarks',
    'family_ties',
    'ministry_experiences',
    'person_photos',
    'person_publications',
    'research_articles',
    'research_tags',
    'territory_sectors',
    'student_manual_order',
    'external_calendar_events',
    'calendar_event_links',
    'inbox_entries',
    'projects',
    'tasks',
    'knowledge_notes',
    'knowledge_questions',
    'knowledge_documents',
    'knowledge_resources',
  };

  Future<void> _updateLocalEntityRevisionOnResolve({
    required String entityType,
    required String entityId,
    required int revision,
    required DateTime updatedAt,
  }) async {
    final normalized = entityType.toLowerCase();
    final tableName = switch (normalized) {
      'person' => 'people',
      'visit' => 'visits',
      'biblestudy' || 'biblestudies' => 'bible_studies',
      'studyparticipant' || 'studyparticipants' || 'biblestudyparticipants' || 'bible_study_participants' => 'study_participants',
      'studysession' || 'studysessions' || 'biblestudysessions' || 'bible_study_sessions' => 'study_sessions',
      'appointment' => 'appointments',
      'activityrecord' || 'activityrecords' => 'activity_records',
      'voicenote' || 'voicenotes' => 'voice_notes',
      'phonecontact' || 'phonecontacts' => 'phone_contacts',
      'territorylandmark' || 'territorylandmarks' => 'territory_landmarks',
      'familytie' || 'familyties' => 'family_ties',
      'ministryexperience' || 'ministryexperiences' => 'ministry_experiences',
      'personphoto' || 'personphotos' => 'person_photos',
      'personpublication' || 'personpublications' => 'person_publications',
      'researcharticle' || 'researcharticles' => 'research_articles',
      'researchtag' || 'researchtags' => 'research_tags',
      'territorysector' || 'territorysectors' => 'territory_sectors',
      _ => normalized,
    };
    if (!_revisionedTables.contains(tableName)) return;
    final unixSeconds = updatedAt.millisecondsSinceEpoch ~/ 1000;
    await db.customUpdate(
      'UPDATE $tableName SET revision = ?, updated_at = ? WHERE id = ?',
      variables: [
        Variable.withInt(revision),
        Variable.withInt(unixSeconds),
        Variable.withString(entityId),
      ],
    );
  }

  /// Reinicia todas as operações com falha definitiva ('failed' - dead letter) para nova tentativa
  Future<int> retryAllFailedOperations() async {
    return (db.update(db.syncQueue)..where((tbl) => tbl.status.equals('failed'))).write(
      const SyncQueueCompanion(
        status: Value('pending'),
        attempts: Value(0),
        lastError: Value(null),
        lastAttemptAt: Value(null),
      ),
    );
  }

  /// Limpa todos os dados locais do aplicativo (util para zerar banco de teste).
  Future<void> clearAllLocalData() async {
    await db.transaction(() async {
      await db.delete(db.people).go();
      await db.delete(db.visits).go();
      await db.delete(db.bibleStudies).go();
      await db.delete(db.studyParticipants).go();
      await db.delete(db.studySessions).go();
      await db.delete(db.appointments).go();
      await db.delete(db.activityRecords).go();
      await db.delete(db.voiceNotes).go();
      await db.delete(db.phoneContacts).go();
      await db.delete(db.territoryLandmarks).go();
      await db.delete(db.familyTies).go();
      await db.delete(db.ministryExperiences).go();
      await db.delete(db.personPhotos).go();
      await db.delete(db.personPublications).go();
      await db.delete(db.researchArticles).go();
      await db.delete(db.researchTags).go();
      await db.delete(db.territorySectors).go();
      await db.delete(db.syncQueue).go();
      await db.delete(db.externalCalendarEvents).go();
      await db.delete(db.appLanguages).go();
    });
  }

  // --------------------------------------------------------------------------
  // MÓDULO: IDIOMAS (FASE 2 / REGRA 11)
  // --------------------------------------------------------------------------
  Future<List<AppLanguageEntry>> getAllLanguages() {
    return (db.select(db.appLanguages)
          ..orderBy([
            (t) => OrderingTerm(expression: t.isDefault, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
          ]))
        .get();
  }

  Stream<List<AppLanguageEntry>> watchAllLanguages() {
    return (db.select(db.appLanguages)
          ..orderBy([
            (t) => OrderingTerm(expression: t.isDefault, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  Future<AppLanguageEntry?> getLanguageById(String id) {
    return (db.select(db.appLanguages)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> createLanguage({
    required String id,
    required String name,
    required String code,
    required String symbol,
    String? diacritics,
    bool isDefault = false,
  }) {
    final now = DateTime.now();
    return db.into(db.appLanguages).insert(
      AppLanguagesCompanion.insert(
        id: id,
        name: name,
        code: code,
        symbol: symbol,
        diacritics: diacritics != null ? Value(diacritics) : const Value.absent(),
        isDefault: Value(isDefault),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> createLanguageCompanion(AppLanguagesCompanion companion) {
    return db.into(db.appLanguages).insert(companion);
  }

  Future<void> deleteLanguage(String id) async {
    await (db.delete(db.appLanguages)..where((tbl) => tbl.id.equals(id))).go();
  }
}