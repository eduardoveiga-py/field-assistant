import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'app_database.dart';

class AppRepository {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();

  AppRepository(this.db);

  // --------------------------------------------------------------------------
  // TRANSAÇÃO AUXILIAR: MUTAÇÃO + ENFILEIRAMENTO DE SINCRONIZAÇÃO
  // --------------------------------------------------------------------------
  Future<void> _recordSyncOperation({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: _uuid.v4(),
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            payload: jsonEncode(payload),
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
          ..orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]))
        .watch();
  }

  Future<List<PersonEntry>> getAllPeople() {
    return (db.select(db.people)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]))
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

    final all = await getAllPeople();
    return all.where((p) {
      final name = p.name.toLowerCase();
      final phone = (p.phone ?? '').toLowerCase();
      final address = (p.address ?? '').toLowerCase();
      final notes = (p.generalNotes ?? '').toLowerCase();
      final tags = p.tags.toLowerCase();
      return name.contains(lower) ||
          phone.contains(lower) ||
          address.contains(lower) ||
          notes.contains(lower) ||
          tags.contains(lower);
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
        payload: {'id': id, 'deletedAt': now.toIso8601String()},
      );
    });
  }

  // --------------------------------------------------------------------------
  // MÓDULO: REVISITAS E HISTÓRICO DE ENCONTROS
  // --------------------------------------------------------------------------
  Stream<List<VisitEntry>> watchVisitsForPerson(String personId) {
    return (db.select(db.visits)
          ..where((tbl) => tbl.personId.equals(personId) & tbl.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.dateTimeField, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<VisitEntry>> getVisitsForPerson(String personId) {
    return (db.select(db.visits)
          ..where((tbl) => tbl.personId.equals(personId) & tbl.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.dateTimeField, mode: OrderingMode.desc)]))
        .get();
  }

  Future<List<VisitEntry>> getAllVisits() {
    return (db.select(db.visits)..where((tbl) => tbl.deletedAt.isNull())).get();
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
          nextActionAt: suggestedReturnDate != null ? Value(suggestedReturnDate) : person.nextActionAt != null ? Value(person.nextActionAt) : const Value.absent(),
          nextActionNote: nextStep != null ? Value(nextStep) : person.nextActionNote != null ? Value(person.nextActionNote) : const Value.absent(),
          updatedAt: now,
          revision: person.revision + 1,
        );
        await db.update(db.people).replace(updatePersonData);
      }

      await _recordSyncOperation(
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

  // --------------------------------------------------------------------------
  // MÓDULO: ESTUDOS BÍBLICOS, PARTICIPANTES E SESSÕES
  // --------------------------------------------------------------------------
  Stream<List<BibleStudyEntry>> watchAllStudies() {
    return (db.select(db.bibleStudies)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<BibleStudyEntry>> getAllStudies() {
    return (db.select(db.bibleStudies)..where((tbl) => tbl.deletedAt.isNull())).get();
  }

  Future<BibleStudyEntry?> getStudyById(String id) {
    return (db.select(db.bibleStudies)
          ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull()))
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
      pauseOrCloseReason: null,
      lastSessionAt: null,
      nextPlannedAt: null,
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
        final isPrimary = (personId == primaryParticipantId) ||
            (primaryParticipantId == null && personId == participantPersonIds.first);

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
      }

      await _recordSyncOperation(
        entityType: 'bible_studies',
        entityId: studyId,
        operation: 'INSERT',
        payload: {
          'id': entry.id,
          'title': entry.title,
          'status': entry.status,
          'publicationId': entry.publicationId,
          'language': entry.language,
          'currentLesson': entry.currentLesson,
          'currentParagraph': entry.currentParagraph,
          'frequency': entry.frequency,
          'revision': entry.revision,
        },
      );
    });

    return entry;
  }

  Future<List<StudyParticipantEntry>> getParticipantsForStudy(String studyId) {
    return (db.select(db.studyParticipants)
          ..where((tbl) => tbl.studyId.equals(studyId) & tbl.deletedAt.isNull()))
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
          final updatedStudy = study.copyWith(
            lastSessionAt: Value(dateTime),
            currentLesson: lessonCovered != null ? Value(lessonCovered) : study.currentLesson != null ? Value(study.currentLesson) : const Value.absent(),
            nextTopic: nextStep != null ? Value(nextStep) : study.nextTopic != null ? Value(study.nextTopic) : const Value.absent(),
            updatedAt: now,
            revision: study.revision + 1,
          );
          await db.update(db.bibleStudies).replace(updatedStudy);
        }
      }

      await _recordSyncOperation(
        entityType: 'study_sessions',
        entityId: sessionId,
        operation: 'INSERT',
        payload: {
          'id': entry.id,
          'studyId': entry.studyId,
          'dateTimeField': entry.dateTimeField.toIso8601String(),
          'lessonCovered': entry.lessonCovered,
          'paragraphsCovered': entry.paragraphsCovered,
          'status': entry.status,
          'participantIds': entry.participantIds,
          'revision': entry.revision,
        },
      );
    });

    return entry;
  }

  Stream<List<StudySessionEntry>> watchSessionsForStudy(String studyId) {
    return (db.select(db.studySessions)
          ..where((tbl) => tbl.studyId.equals(studyId) & tbl.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.dateTimeField, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<StudySessionEntry>> getAllSessions() {
    return (db.select(db.studySessions)..where((tbl) => tbl.deletedAt.isNull())).get();
  }

  // --------------------------------------------------------------------------
  // MÓDULO: AGENDAMENTOS E COMPROMISSOS
  // --------------------------------------------------------------------------
  Stream<List<AppointmentEntry>> watchAppointments() {
    return (db.select(db.appointments)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.startTime, mode: OrderingMode.asc)]))
        .watch();
  }

  Future<List<AppointmentEntry>> getAllAppointments() {
    return (db.select(db.appointments)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.startTime, mode: OrderingMode.asc)]))
        .get();
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
        payload: {
          'id': entry.id,
          'personId': entry.personId,
          'studyId': entry.studyId,
          'title': entry.title,
          'startTime': entry.startTime.toIso8601String(),
          'endTime': entry.endTime.toIso8601String(),
          'durationMinutes': entry.durationMinutes,
          'status': entry.status,
          'isProvisional': entry.isProvisional,
          'revision': entry.revision,
        },
      );
    });

    return entry;
  }

  Future<void> updateAppointment(AppointmentEntry appointment) async {
    final now = DateTime.now();
    final updated = appointment.copyWith(
      updatedAt: now,
      revision: appointment.revision + 1,
    );

    await db.transaction(() async {
      await db.update(db.appointments).replace(updated);
      await _recordSyncOperation(
        entityType: 'appointments',
        entityId: updated.id,
        operation: 'UPDATE',
        payload: {
          'id': updated.id,
          'title': updated.title,
          'startTime': updated.startTime.toIso8601String(),
          'endTime': updated.endTime.toIso8601String(),
          'status': updated.status,
          'revision': updated.revision,
        },
      );
    });
  }

  // --------------------------------------------------------------------------
  // MÓDULO: ATIVIDADES PESSOAIS
  // --------------------------------------------------------------------------
  Stream<List<ActivityRecordEntry>> watchActivities() {
    return (db.select(db.activityRecords)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<ActivityRecordEntry>> getAllActivities() {
    return (db.select(db.activityRecords)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
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

  // --------------------------------------------------------------------------
  // MÓDULO: FILA DE SINCRONIZAÇÃO
  // --------------------------------------------------------------------------
  Future<List<SyncQueueEntry>> getPendingSyncOperations() {
    return (db.select(db.syncQueue)
          ..where((tbl) => tbl.status.equals('pending') | tbl.status.equals('in_progress'))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
        .get();
  }

  Future<void> markSyncOperationSuccess(String id) async {
    await (db.update(db.syncQueue)..where((tbl) => tbl.id.equals(id))).write(
      const SyncQueueCompanion(status: Value('synced')),
    );
  }

  Future<void> markSyncOperationFailed(String id, String error) async {
    final op = await (db.select(db.syncQueue)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (op != null) {
      await (db.update(db.syncQueue)..where((tbl) => tbl.id.equals(id))).write(
        SyncQueueCompanion(
          status: const Value('failed'),
          attempts: Value(op.attempts + 1),
          lastError: Value(error),
        ),
      );
    }
  }
}
