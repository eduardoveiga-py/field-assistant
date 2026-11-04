import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Adversarial Verification — Milestone 3 (Fase 3)', () {
    late AppDatabase db;
    late AppRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    group('Task 1: Domain exports and mixin composition', () {
      test('AppRepository satisfies BaseRepository and domain mixins', () {
        expect(repo, isA<BaseRepository>());
        expect(repo, isA<PeopleDomainMixin>());
        expect(repo, isA<VisitsDomainMixin>());
        expect(repo, isA<StudiesDomainMixin>());
        expect(repo, isA<AppointmentsDomainMixin>());
        expect(repo, isA<ActivitiesDomainMixin>());
        expect(repo, isA<TrashDomainMixin>());
        expect(repo, isA<SyncQueueDomainMixin>());
      });
    });

    group('Task 2: searchPeople query optimization & adversarial edge cases', () {
      test('Empty and whitespace-only queries return all active people', () async {
        await repo.createPerson(name: 'Ana Silva');
        await repo.createPerson(name: 'Carlos Bento');

        final emptyRes = await repo.searchPeople('');
        expect(emptyRes.length, equals(2));

        final spacesRes = await repo.searchPeople('   \t\n  ');
        expect(spacesRes.length, equals(2));
      });

      test('Case insensitivity for uppercase, lowercase, and mixed case', () async {
        final p = await repo.createPerson(
          name: 'Guilherme Santos',
          address: 'Rua Bela Vista 123',
          generalNotes: 'Interesse em Livro de Daniel',
        );

        final r1 = await repo.searchPeople('guilherme');
        expect(r1.map((e) => e.id), contains(p.id));

        final r2 = await repo.searchPeople('GUILHERME');
        expect(r2.map((e) => e.id), contains(p.id));

        final r3 = await repo.searchPeople('gUiLhErMe');
        expect(r3.map((e) => e.id), contains(p.id));

        final r4 = await repo.searchPeople('BELA VISTA');
        expect(r4.map((e) => e.id), contains(p.id));

        final r5 = await repo.searchPeople('DANIEL');
        expect(r5.map((e) => e.id), contains(p.id));
      });

      test('Special characters and SQL injection resistance', () async {
        final p = await repo.createPerson(
          name: "Patrick O'Connor",
          generalNotes: 'Estudante 100% dedicado [grupo especial]',
          tags: ['especial_tag', 'target%symbol'],
        );

        // Single quote
        final rQuote = await repo.searchPeople("O'Connor");
        expect(rQuote.map((e) => e.id), contains(p.id));

        // SQL injection attacks
        final rInj1 = await repo.searchPeople("' OR '1'='1");
        // Parameterized queries mean this searches for literal string "' OR '1'='1" and does not dump all rows
        expect(rInj1.isEmpty, isTrue);

        final rInj2 = await repo.searchPeople("'; DROP TABLE people;--");
        expect(rInj2.isEmpty, isTrue);
        // Verify table still exists and is healthy
        final alivePeople = await repo.getAllPeople();
        expect(alivePeople.length, equals(1));

        // Percent sign (SQL LIKE wildcard)
        final rPerc = await repo.searchPeople('%');
        expect(rPerc.map((e) => e.id), contains(p.id));

        // Regex / syntax characters
        final rRegex = await repo.searchPeople('[grupo');
        expect(rRegex.map((e) => e.id), contains(p.id));

        final rBackslash = await repo.searchPeople(r'foo\bar');
        expect(rBackslash.isEmpty, isTrue);

        // Huge query string
        final hugeQuery = 'A' * 5000;
        final rHuge = await repo.searchPeople(hugeQuery);
        expect(rHuge.isEmpty, isTrue);

        // Huge integer string exceeding 64-bit int
        final hugeNum = '9999999999999999999999999999999999999999';
        final rHugeNum = await repo.searchPeople(hugeNum);
        expect(rHugeNum.isEmpty, isTrue);
      });

      test('Participants matching by study title, publicationId, lesson and paragraph', () async {
        final p1 = await repo.createPerson(name: 'Beatriz Almeida');
        final p2 = await repo.createPerson(name: 'Claudio Duarte');
        final other = await repo.createPerson(name: 'Zuleica Xavier');

        final study = await repo.createStudy(
          title: 'Vivendo Para Sempre',
          publicationId: 'lff-manual',
          currentLesson: 14,
          currentParagraph: 3,
          participantPersonIds: [p1.id, p2.id],
        );
        expect(study.id, isNotEmpty);

        // Match by study title
        final rTitle = await repo.searchPeople('Vivendo');
        expect(rTitle.map((e) => e.id), containsAll([p1.id, p2.id]));
        expect(rTitle.map((e) => e.id), isNot(contains(other.id)));

        // Match by publicationId
        final rPub = await repo.searchPeople('lff-manual');
        expect(rPub.map((e) => e.id), containsAll([p1.id, p2.id]));

        // Match by lesson number in text (e.g. "Lição 14")
        final rLesson = await repo.searchPeople('Lição 14');
        expect(rLesson.map((e) => e.id), containsAll([p1.id, p2.id]));

        // Match by paragraph number
        final rPara = await repo.searchPeople('3');
        expect(rPara.map((e) => e.id), containsAll([p1.id, p2.id]));

        // Results should be ordered by person name ascending
        expect(rTitle.first.name, equals('Beatriz Almeida'));
        expect(rTitle.last.name, equals('Claudio Duarte'));
      });

      test('Soft-deleted records are never returned in searchPeople', () async {
        final p1 = await repo.createPerson(name: 'Estudante Deletado');
        final p2 = await repo.createPerson(name: 'Estudante Ativo');

        final study = await repo.createStudy(
          title: 'Estudo Teste Exclusao',
          publicationId: 'pub-exclusao',
          participantPersonIds: [p1.id, p2.id],
        );

        // Delete person p1
        await repo.deletePerson(p1.id);

        // Search by name of deleted person
        final rDeletedName = await repo.searchPeople('Estudante Deletado');
        expect(rDeletedName.isEmpty, isTrue);

        // Search by study title: only active person p2 should be returned
        final rStudyTitle = await repo.searchPeople('Exclusao');
        expect(rStudyTitle.length, equals(1));
        expect(rStudyTitle.first.id, equals(p2.id));

        // Delete the study: now searching by study title should return 0 people
        await repo.deleteStudy(study.id);
        final rAfterStudyDeleted = await repo.searchPeople('Exclusao');
        expect(rAfterStudyDeleted.isEmpty, isTrue);

        // Active person p2 can still be found by their own name
        final rActive = await repo.searchPeople('Estudante Ativo');
        expect(rActive.length, equals(1));
        expect(rActive.first.id, equals(p2.id));
      });

      test('Participant soft-deleted in studyParticipants is excluded from search', () async {
        final p = await repo.createPerson(name: 'Participante Desvinculado');
        final study = await repo.createStudy(
          title: 'Estudo Desvinculacao',
          publicationId: 'pub-desv',
          participantPersonIds: [p.id],
        );

        // Verify participant is initially found
        final rBefore = await repo.searchPeople('Desvinculacao');
        expect(rBefore.length, equals(1));

        // Soft-delete the participant entry
        final parts = await repo.getParticipantsForStudy(study.id);
        expect(parts.length, equals(1));
        await (db.update(db.studyParticipants)..where((t) => t.id.equals(parts.first.id)))
            .write(StudyParticipantsCompanion(deletedAt: Value(DateTime.now())));

        // Now search by study title should not return the participant
        final rAfter = await repo.searchPeople('Desvinculacao');
        expect(rAfter.isEmpty, isTrue);
      });
    });

    group('Task 3: createStudy transaction atomicity and sync queue operations', () {
      test('createStudy with multiple participants inserts all into db and sync_queue atomically', () async {
        final p1 = await repo.createPerson(name: 'Pessoa Alpha');
        final p2 = await repo.createPerson(name: 'Pessoa Beta');
        final p3 = await repo.createPerson(name: 'Pessoa Gamma');

        // Clear sync queue from createPerson
        await db.delete(db.syncQueue).go();

        final study = await repo.createStudy(
          title: 'Estudo Triplo',
          publicationId: 'lff-triplo',
          participantPersonIds: [p1.id, p2.id, p3.id],
          primaryParticipantId: p2.id,
        );

        // 1. Verify study table
        final studyInDb = await repo.getStudyById(study.id);
        expect(studyInDb, isNotNull);
        expect(studyInDb!.title, equals('Estudo Triplo'));

        // 2. Verify studyParticipants table
        final participants = await repo.getParticipantsForStudy(study.id);
        expect(participants.length, equals(3));
        final betaPart = participants.firstWhere((pt) => pt.personId == p2.id);
        expect(betaPart.isPrimary, isTrue);
        final alphaPart = participants.firstWhere((pt) => pt.personId == p1.id);
        expect(alphaPart.isPrimary, isFalse);

        // 3. Verify sync_queue operations
        final pendingOps = await repo.getPendingSyncOperations();
        expect(pendingOps.length, equals(4)); // 3 participants + 1 study

        final studyOps = pendingOps.where((op) => op.entityType == 'bible_studies').toList();
        expect(studyOps.length, equals(1));
        expect(studyOps.first.entityId, equals(study.id));
        expect(studyOps.first.operation, equals('INSERT'));

        final partOps = pendingOps.where((op) => op.entityType == 'study_participants').toList();
        expect(partOps.length, equals(3));
        for (final pop in partOps) {
          expect(pop.operation, equals('INSERT'));
          final payload = jsonDecode(pop.payload) as Map<String, dynamic>;
          expect(payload['studyId'], equals(study.id));
          expect([p1.id, p2.id, p3.id], contains(payload['personId']));
          expect(payload['revision'], equals(1));
          expect(payload['createdAt'], isNotNull);
        }
      });

      test('createStudy with 0 participants records only the study in sync_queue', () async {
        await db.delete(db.syncQueue).go();

        final study = await repo.createStudy(
          title: 'Estudo Solitário',
          publicationId: 'lff-solo',
          participantPersonIds: [],
        );

        final pendingOps = await repo.getPendingSyncOperations();
        expect(pendingOps.length, equals(1));
        expect(pendingOps.first.entityType, equals('bible_studies'));
        expect(pendingOps.first.entityId, equals(study.id));
      });
    });

    group('Trash and Outbox Hardening', () {
      test('restoreDeletedItem restores visit, study, appointment, and activity with proper outbox payload', () async {
        final person = await repo.createPerson(name: 'Titular');
        final visit = await repo.createVisit(
          personId: person.id,
          dateTime: DateTime.now(),
          contactType: 'revisita',
          result: 'bom',
        );
        final study = await repo.createStudy(
          title: 'Estudo Trash',
          publicationId: 'lff',
          participantPersonIds: [person.id],
        );
        final appt = await repo.createAppointment(
          title: 'Compromisso Trash',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(minutes: 30)),
        );
        final act = await repo.createActivityRecord(
          date: DateTime.now(),
          durationSeconds: 3600,
          modality: 'campo',
        );

        // Delete all
        await repo.deleteVisit(visit.id);
        await repo.deleteStudy(study.id);
        await repo.deleteAppointment(appt.id);
        await repo.deleteActivityRecord(act.id);

        // Clear queue
        await db.delete(db.syncQueue).go();

        // Restore each
        await repo.restoreDeletedItem('visits', visit.id);
        await repo.restoreDeletedItem('bible_studies', study.id);
        await repo.restoreDeletedItem('appointments', appt.id);
        await repo.restoreDeletedItem('activity_records', act.id);

        final pendingOps = await repo.getPendingSyncOperations();
        expect(pendingOps.length, equals(4));

        for (final op in pendingOps) {
          expect(op.operation, equals('UPDATE'));
          final payload = jsonDecode(op.payload) as Map<String, dynamic>;
          expect(payload['restored'], isTrue);
          expect(payload['deleted_at'], isNull);
          expect(payload['deletedAt'], isNull);
          expect(payload['revision'], equals(3)); // 1 -> 2 (delete) -> 3 (restore)
        }
      });

      test('permanentlyDeleteItem wipes relations and records HARD_DELETE', () async {
        final p = await repo.createPerson(name: 'Aluno Perm');
        final study = await repo.createStudy(
          title: 'Estudo Permanente',
          publicationId: 'lff',
          participantPersonIds: [p.id],
        );
        await repo.createStudySession(
          studyId: study.id,
          dateTime: DateTime.now(),
          lessonCovered: 1,
        );

        await db.delete(db.syncQueue).go();

        // Permanently delete study
        await repo.permanentlyDeleteItem('bible_studies', study.id);

        // Verify study, participants and sessions are wiped from SQLite
        expect(await repo.getStudyById(study.id), isNull);
        expect(await repo.getParticipantsForStudy(study.id), isEmpty);
        final sessions = await (db.select(db.studySessions)..where((t) => t.studyId.equals(study.id))).get();
        expect(sessions, isEmpty);

        // Verify HARD_DELETE in syncQueue
        final pendingOps = await repo.getPendingSyncOperations();
        expect(pendingOps.length, equals(1));
        expect(pendingOps.first.operation, equals('HARD_DELETE'));
        expect(pendingOps.first.entityType, equals('bible_studies'));
        expect(pendingOps.first.entityId, equals(study.id));
      });

      test('requeueFailedSyncOperations resets status to pending and caps attempts at 4', () async {
        // Insert failed ops
        await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: 'failed-1',
            entityType: 'people',
            entityId: 'p1',
            operation: 'INSERT',
            payload: '{}',
            createdAt: DateTime.now(),
            status: const Value('failed'),
            attempts: const Value(5),
            lastError: const Value('SocketException: Connection refused'),
          ),
        );
        await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: 'failed-2',
            entityType: 'visits',
            entityId: 'v1',
            operation: 'INSERT',
            payload: '{}',
            createdAt: DateTime.now(),
            status: const Value('failed'),
            attempts: const Value(8),
            lastError: const Value('TimeoutException'),
          ),
        );
        await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: 'failed-low',
            entityType: 'people',
            entityId: 'p2',
            operation: 'INSERT',
            payload: '{}',
            createdAt: DateTime.now(),
            status: const Value('failed'),
            attempts: const Value(2),
            lastError: const Value('Minor error'),
          ),
        );

        // Requeue all failed (attempts >= 5)
        final count = await repo.requeueFailedSyncOperations();
        expect(count, equals(2));

        final op1 = await (db.select(db.syncQueue)..where((t) => t.id.equals('failed-1'))).getSingle();
        expect(op1.status, equals('pending'));
        expect(op1.attempts, equals(4));
        expect(op1.lastError, contains('SocketException'));

        final op2 = await (db.select(db.syncQueue)..where((t) => t.id.equals('failed-2'))).getSingle();
        expect(op2.status, equals('pending'));
        expect(op2.attempts, equals(4));

        final opLow = await (db.select(db.syncQueue)..where((t) => t.id.equals('failed-low'))).getSingle();
        expect(opLow.status, equals('failed'));
        expect(opLow.attempts, equals(2));
      });
    });
  });
}
