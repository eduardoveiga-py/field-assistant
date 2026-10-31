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
    final studies = await getAllStudies();
    final participants = await (db.select(db.studyParticipants)..where((tbl) => tbl.deletedAt.isNull())).get();

    // Cria mapa de personId -> estudos vinculados
    final Map<String, List<BibleStudyEntry>> personStudies = {};
    for (final p in participants) {
      final study = studies.where((s) => s.id == p.studyId).firstOrNull;
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

      final matchesDirect = name.contains(lower) ||
          phone.contains(lower) ||
          address.contains(lower) ||
          notes.contains(lower) ||
          nextAction.contains(lower) ||
          restrictions.contains(lower) ||
          tags.contains(lower) ||
          schedule.contains(lower);

      if (matchesDirect) return true;

      // Verifica estudos bíblicos vinculados (título, publicação, lição e parágrafo)
      final linked = personStudies[p.id] ?? [];
      for (final s in linked) {
        if (s.title.toLowerCase().contains(lower) ||
            s.publicationId.toLowerCase().contains(lower) ||
            (s.currentLesson != null && 'lição ${s.currentLesson}'.contains(lower)) ||
            (s.currentParagraph != null && 'parágrafo ${s.currentParagraph}'.contains(lower))) {
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

  Future<VisitEntry?> getVisitById(String id) {
    return (db.select(db.visits)..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull())).getSingleOrNull();
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

  Future<void> updateVisit(VisitEntry visit) async {
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
        payload: {
          'id': updated.id,
          'notes': updated.notes,
          'topicsDiscussed': updated.topicsDiscussed,
          'result': updated.result,
          'nextStep': updated.nextStep,
          'suggestedReturnDate': updated.suggestedReturnDate?.toIso8601String(),
          'revision': updated.revision,
        },
      );
    });
  }

  Future<void> deleteVisit(String id) async {
    final visit = await (db.select(db.visits)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
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
        payload: {'id': id, 'deletedAt': now.toIso8601String()},
      );
    });
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

  Future<BibleStudyEntry?> getPrimaryStudyForPerson(String personId) async {
    final participants = await (db.select(db.studyParticipants)
          ..where((tbl) => tbl.personId.equals(personId) & tbl.deletedAt.isNull()))
        .get();
    if (participants.isEmpty) return null;
    final primary = participants.where((p) => p.isPrimary).firstOrNull ?? participants.first;
    return (db.select(db.bibleStudies)
          ..where((tbl) => tbl.id.equals(primary.studyId) & tbl.deletedAt.isNull()))
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

  Future<void> updateStudy(BibleStudyEntry study) async {
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
        payload: {
          'id': updated.id,
          'title': updated.title,
          'status': updated.status,
          'currentLesson': updated.currentLesson,
          'currentParagraph': updated.currentParagraph,
          'nextTopic': updated.nextTopic,
          'pauseOrCloseReason': updated.pauseOrCloseReason,
          'revision': updated.revision,
        },
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
        payload: {'id': id, 'deletedAt': now.toIso8601String()},
      );
    });
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
          final parsedPara = paragraphsCovered != null
              ? (int.tryParse(paragraphsCovered) ?? int.tryParse(paragraphsCovered.split(RegExp(r'[-–,]')).last.trim()))
              : null;
          final updatedStudy = study.copyWith(
            lastSessionAt: Value(dateTime),
            currentLesson: lessonCovered != null ? Value(lessonCovered) : study.currentLesson != null ? Value(study.currentLesson) : const Value.absent(),
            currentParagraph: parsedPara != null ? Value(parsedPara) : study.currentParagraph != null ? Value(study.currentParagraph) : const Value.absent(),
            nextTopic: nextStep != null ? Value(nextStep) : study.nextTopic != null ? Value(study.nextTopic) : const Value.absent(),
            updatedAt: now,
            revision: study.revision + 1,
          );
          await db.update(db.bibleStudies).replace(updatedStudy);

          await _recordSyncOperation(
            entityType: 'bible_studies',
            entityId: study.id,
            operation: 'UPDATE',
            payload: {
              'id': updatedStudy.id,
              'currentLesson': updatedStudy.currentLesson,
              'currentParagraph': updatedStudy.currentParagraph,
              'lastSessionAt': updatedStudy.lastSessionAt?.toIso8601String(),
              'nextTopic': updatedStudy.nextTopic,
              'revision': updatedStudy.revision,
              'updatedAt': now.toIso8601String(),
            },
          );
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
          'publicationCode': entry.publicationCode,
          'lessonCovered': entry.lessonCovered,
          'paragraphsCovered': entry.paragraphsCovered,
          'sessionNotes': entry.sessionNotes,
          'pendingQuestions': entry.pendingQuestions,
          'nextStep': entry.nextStep,
          'status': entry.status,
          'participantIds': entry.participantIds,
          'revision': entry.revision,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
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

  Future<AppointmentEntry?> getAppointmentById(String id) {
    return (db.select(db.appointments)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
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

      await _recordSyncOperation(
        entityType: 'appointments',
        entityId: oldAppointment.id,
        operation: 'UPDATE',
        payload: {
          'id': oldAppointment.id,
          'status': 'reagendado',
          'revision': updatedOld.revision,
        },
      );

      await _recordSyncOperation(
        entityType: 'appointments',
        entityId: newId,
        operation: 'INSERT',
        payload: {
          'id': newAppt.id,
          'personId': newAppt.personId,
          'title': newAppt.title,
          'startTime': newAppt.startTime.toIso8601String(),
          'endTime': newAppt.endTime.toIso8601String(),
          'previousAppointmentId': oldAppointment.id,
          'status': 'confirmado',
          'revision': newAppt.revision,
        },
      );
    });

    return newAppt;
  }

  Future<void> deleteAppointment(String id) async {
    final appt = await (db.select(db.appointments)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (appt == null) return;
    final now = DateTime.now();
    final updated = appt.copyWith(
      deletedAt: Value(now),
      updatedAt: now,
      revision: appt.revision + 1,
    );
    await db.transaction(() async {
      await db.update(db.appointments).replace(updated);
      await _recordSyncOperation(
        entityType: 'appointments',
        entityId: id,
        operation: 'DELETE',
        payload: {'id': id, 'deletedAt': now.toIso8601String()},
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

  Future<void> updateActivityRecord(ActivityRecordEntry activity) async {
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
        payload: {
          'id': updated.id,
          'durationSeconds': updated.durationSeconds,
          'modality': updated.modality,
          'notes': updated.notes,
          'revision': updated.revision,
        },
      );
    });
  }

  Future<void> deleteActivityRecord(String id) async {
    final act = await (db.select(db.activityRecords)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
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
        payload: {'id': id, 'deletedAt': now.toIso8601String()},
      );
    });
  }

  // --------------------------------------------------------------------------
  // MÓDULO: RECUPERAÇÃO DE EXCLUSÕES (LIXEIRA) - SEÇÃO 8.4
  // --------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getDeletedItems() async {
    final List<Map<String, dynamic>> result = [];
    final people = await (db.select(db.people)..where((tbl) => tbl.deletedAt.isNotNull())).get();
    for (final p in people) {
      result.add({'type': 'people', 'id': p.id, 'title': p.name, 'subtitle': 'Contato', 'deletedAt': p.deletedAt});
    }
    final visits = await (db.select(db.visits)..where((tbl) => tbl.deletedAt.isNotNull())).get();
    for (final v in visits) {
      result.add({'type': 'visits', 'id': v.id, 'title': 'Visita (${v.contactType})', 'subtitle': v.topicsDiscussed ?? 'Sem assunto', 'deletedAt': v.deletedAt});
    }
    final studies = await (db.select(db.bibleStudies)..where((tbl) => tbl.deletedAt.isNotNull())).get();
    for (final s in studies) {
      result.add({'type': 'bible_studies', 'id': s.id, 'title': s.title, 'subtitle': 'Estudo Bíblico', 'deletedAt': s.deletedAt});
    }
    final appts = await (db.select(db.appointments)..where((tbl) => tbl.deletedAt.isNotNull())).get();
    for (final a in appts) {
      result.add({'type': 'appointments', 'id': a.id, 'title': a.title, 'subtitle': 'Compromisso', 'deletedAt': a.deletedAt});
    }
    final acts = await (db.select(db.activityRecords)..where((tbl) => tbl.deletedAt.isNotNull())).get();
    for (final act in acts) {
      result.add({'type': 'activity_records', 'id': act.id, 'title': 'Atividade (${act.modality})', 'subtitle': '${(act.durationSeconds / 60).round()} min', 'deletedAt': act.deletedAt});
    }
    result.sort((a, b) => (b['deletedAt'] as DateTime).compareTo(a['deletedAt'] as DateTime));
    return result;
  }

  Future<void> restoreDeletedItem(String entityType, String id) async {
    final now = DateTime.now();
    await db.transaction(() async {
      if (entityType == 'people') {
        final item = await (db.select(db.people)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (item != null) {
          await db.update(db.people).replace(item.copyWith(deletedAt: const Value(null), updatedAt: now, revision: item.revision + 1));
        }
      } else if (entityType == 'visits') {
        final item = await (db.select(db.visits)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (item != null) {
          await db.update(db.visits).replace(item.copyWith(deletedAt: const Value(null), updatedAt: now, revision: item.revision + 1));
        }
      } else if (entityType == 'bible_studies') {
        final item = await (db.select(db.bibleStudies)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (item != null) {
          await db.update(db.bibleStudies).replace(item.copyWith(deletedAt: const Value(null), updatedAt: now, revision: item.revision + 1));
        }
      } else if (entityType == 'appointments') {
        final item = await (db.select(db.appointments)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (item != null) {
          await db.update(db.appointments).replace(item.copyWith(deletedAt: const Value(null), updatedAt: now, revision: item.revision + 1));
        }
      } else if (entityType == 'activity_records') {
        final item = await (db.select(db.activityRecords)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (item != null) {
          await db.update(db.activityRecords).replace(item.copyWith(deletedAt: const Value(null), updatedAt: now, revision: item.revision + 1));
        }
      }
      await _recordSyncOperation(
        entityType: entityType,
        entityId: id,
        operation: 'UPDATE',
        payload: {'id': id, 'restored': true, 'updatedAt': now.toIso8601String()},
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
        await (db.delete(db.studyParticipants)..where((t) => t.studyId.equals(id))).go();
        await (db.delete(db.studySessions)..where((t) => t.studyId.equals(id))).go();
        await (db.delete(db.bibleStudies)..where((t) => t.id.equals(id))).go();
      } else if (entityType == 'appointments') {
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
