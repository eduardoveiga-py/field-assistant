import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';
import 'base_repository.dart';

/// Domínio responsável por estudos bíblicos, participantes e sessões de estudo.
mixin StudiesDomainMixin on BaseRepository {
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

  @override
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
    final studyId = id ?? uuid.v4();
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

      // Adiciona participantes associados (M:N) e enfileira na sync_queue para garantir atomicidade
      for (final personId in participantPersonIds) {
        final partId = uuid.v4();
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

        await recordSyncOperation(
          entityType: 'study_participants',
          entityId: partId,
          operation: 'INSERT',
          payload: {
            'id': partEntry.id,
            'studyId': partEntry.studyId,
            'personId': partEntry.personId,
            'isPrimary': partEntry.isPrimary,
            'createdAt': partEntry.createdAt.toIso8601String(),
            'updatedAt': partEntry.updatedAt.toIso8601String(),
            'revision': partEntry.revision,
          },
        );
      }

      await recordSyncOperation(
        entityType: 'bible_studies',
        entityId: studyId,
        operation: 'INSERT',
        payload: {
          'id': entry.id,
          'title': entry.title,
          'status': entry.status,
          'startedAt': entry.startedAt.toIso8601String(),
          'lastSessionAt': entry.lastSessionAt?.toIso8601String(),
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
    final existing = await getStudyById(study.id);
    final now = DateTime.now();
    final updated = study.copyWith(
      updatedAt: now,
      revision: study.revision + 1,
    );
    await db.transaction(() async {
      await db.update(db.bibleStudies).replace(updated);
      await recordSyncOperation(
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
      await recordSyncOperation(
        entityType: 'bible_studies',
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

  Future<List<StudyParticipantEntry>> getParticipantsForStudy(String studyId) {
    return (db.select(
      db.studyParticipants,
    )..where((tbl) => tbl.studyId.equals(studyId) & tbl.deletedAt.isNull()))
        .get();
  }

  Stream<List<StudyParticipantEntry>> watchAllStudyParticipants() {
    return (db.select(db.studyParticipants)
          ..where((tbl) => tbl.deletedAt.isNull()))
        .watch();
  }

  Future<List<StudyParticipantEntry>> getAllStudyParticipants() {
    return (db.select(db.studyParticipants)
          ..where((tbl) => tbl.deletedAt.isNull()))
        .get();
  }

  Future<Map<String, List<StudyParticipantEntry>>> getParticipantsForStudies(
    List<String> studyIds,
  ) async {
    if (studyIds.isEmpty) return {};
    final entries = await (db.select(db.studyParticipants)
          ..where((tbl) => tbl.studyId.isIn(studyIds) & tbl.deletedAt.isNull()))
        .get();
    final map = <String, List<StudyParticipantEntry>>{};
    for (final p in entries) {
      map.putIfAbsent(p.studyId, () => []).add(p);
    }
    return map;
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
    final sessionId = id ?? uuid.v4();
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

          await recordSyncOperation(
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

      await recordSyncOperation(
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
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.dateTimeField,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch();
  }

  Stream<List<StudySessionEntry>> watchAllSessions() {
    return (db.select(db.studySessions)
          ..where((tbl) => tbl.deletedAt.isNull())
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

  Future<void> deleteSession(String sessionId) async {
    final now = DateTime.now();
    await (db.update(db.studySessions)..where((tbl) => tbl.id.equals(sessionId)))
        .write(StudySessionsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ));
    await recordSyncOperation(
      entityType: 'study_sessions',
      entityId: sessionId,
      operation: 'DELETE',
      payload: {'id': sessionId, 'deletedAt': now.toIso8601String()},
    );
  }
}
