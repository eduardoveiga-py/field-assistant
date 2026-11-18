import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/sync/domain_conflict_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('FA-SYNC-02 & P1-03: BibleStudyDomainConflictDetector Tests', () {
    test('Detecta conflito quando mesmo estudante primário é associado a dois estudos ativos', () async {
      final now = DateTime.utc(2026, 11, 18, 10, 0);

      // Cria pessoa
      await db
          .into(db.people)
          .insert(
            PeopleCompanion.insert(
              id: 'person_student_1',
              name: 'Lucas Estudante',
              status: const drift.Value('estudante'),
              firstContactAt: now,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Estudo 1 pré-existente
      await db
          .into(db.bibleStudies)
          .insert(
            BibleStudiesCompanion.insert(
              id: 'study_1',
              title: 'Estudo em Lucas',
              publicationId: 'lff-book',
              startedAt: now,
              status: const drift.Value('ativo'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db
          .into(db.studyParticipants)
          .insert(
            StudyParticipantsCompanion.insert(
              id: 'part_1',
              studyId: 'study_1',
              personId: 'person_student_1',
              isPrimary: const drift.Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Estudo 2 recebido no pull com mesmo participante primário
      await db
          .into(db.bibleStudies)
          .insert(
            BibleStudiesCompanion.insert(
              id: 'study_2',
              title: 'Estudo Concorrente em João',
              publicationId: 'lff-book',
              startedAt: now,
              status: const drift.Value('ativo'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db
          .into(db.studyParticipants)
          .insert(
            StudyParticipantsCompanion.insert(
              id: 'part_2',
              studyId: 'study_2',
              personId: 'person_student_1',
              isPrimary: const drift.Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final conflicts =
          await BibleStudyDomainConflictDetector.detectAndRecordConflicts(
            db,
            studyId: 'study_2',
            now: now,
          );

      expect(conflicts, hasLength(1));
      expect(conflicts.first.incomingStudyId, equals('study_2'));
      expect(conflicts.first.conflictingStudyId, equals('study_1'));
      expect(conflicts.first.reason, equals('duplicate_primary_student'));
      expect(conflicts.first.studentPersonId, equals('person_student_1'));

      // Verifica status = conflito no banco sem exclusão do estudo
      final updatedStudy2 = await (db.select(
        db.bibleStudies,
      )..where((t) => t.id.equals('study_2'))).getSingle();
      expect(updatedStudy2.status, equals('conflito'));

      // Verifica registro em app_kv_store
      final active = await BibleStudyDomainConflictDetector.getActiveConflicts(
        db,
      );
      expect(active, hasLength(1));
      expect(active.first.conflictingStudyId, equals('study_1'));

      // Limpeza de conflito
      await BibleStudyDomainConflictDetector.clearConflict(db, 'study_2');
      final activeAfterClear =
          await BibleStudyDomainConflictDetector.getActiveConflicts(db);
      expect(activeAfterClear, isEmpty);
    });

    test('Detecta conflito de sobreposição de sessão planejada (nextPlannedAt idêntico)', () async {
      final planned = DateTime.utc(2026, 11, 20, 14, 0);

      await db
          .into(db.bibleStudies)
          .insert(
            BibleStudiesCompanion.insert(
              id: 'study_alpha',
              title: 'Estudo Alfa',
              publicationId: 'lff-book',
              startedAt: DateTime.utc(2026, 1, 1),
              nextPlannedAt: drift.Value(planned),
              status: const drift.Value('ativo'),
              createdAt: DateTime.utc(2026, 1, 1),
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      await db
          .into(db.bibleStudies)
          .insert(
            BibleStudiesCompanion.insert(
              id: 'study_beta',
              title: 'Estudo Beta',
              publicationId: 'lff-brochure',
              startedAt: DateTime.utc(2026, 1, 2),
              nextPlannedAt: drift.Value(planned),
              status: const drift.Value('ativo'),
              createdAt: DateTime.utc(2026, 1, 2),
              updatedAt: DateTime.utc(2026, 1, 2),
            ),
          );

      final conflicts =
          await BibleStudyDomainConflictDetector.detectAndRecordConflicts(
            db,
            studyId: 'study_beta',
          );

      expect(conflicts, hasLength(1));
      expect(conflicts.first.conflictingStudyId, equals('study_alpha'));
      expect(conflicts.first.reason, equals('overlapping_planned_session'));
    });
  });

  group('FA-SYNC-02 & P1-03: TaskDomainConflictDetector Tests', () {
    test(
      'Detecta duplicidade de tarefas ativas com mesmo título e mesmo personId',
      () async {
        final now = DateTime.utc(2026, 11, 18, 12, 0);

        await db
            .into(db.tasks)
            .insert(
              TasksCompanion.insert(
                id: 'task_orig',
                title: 'Revisitar para entregar folheto',
                personId: const drift.Value('person_target_1'),
                status: const drift.Value('todo'),
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.tasks)
            .insert(
              TasksCompanion.insert(
                id: 'task_sync',
                title: 'Revisitar para entregar folheto',
                personId: const drift.Value('person_target_1'),
                status: const drift.Value('todo'),
                createdAt: now,
                updatedAt: now,
              ),
            );

        final conflicts =
            await TaskDomainConflictDetector.detectAndRecordConflicts(
              db,
              taskId: 'task_sync',
              now: now,
            );

        expect(conflicts, hasLength(1));
        expect(conflicts.first.incomingTaskId, equals('task_sync'));
        expect(conflicts.first.conflictingTaskId, equals('task_orig'));
        expect(conflicts.first.reason, equals('duplicate_active_task'));

        final updatedTask = await (db.select(
          db.tasks,
        )..where((t) => t.id.equals('task_sync'))).getSingle();
        expect(updatedTask.status, equals('conflito'));

        final active = await TaskDomainConflictDetector.getActiveConflicts(db);
        expect(active, hasLength(1));

        await TaskDomainConflictDetector.clearConflict(db, 'task_sync');
        expect(
          await TaskDomainConflictDetector.getActiveConflicts(db),
          isEmpty,
        );
      },
    );

    test('Tarefas com status inativo (completed, cancelled, archived) não geram conflito', () async {
      final now = DateTime.utc(2026, 11, 18, 12, 0);

      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              id: 'task_done',
              title: 'Ler capítulo semanal',
              status: const drift.Value('completed'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              id: 'task_new',
              title: 'Ler capítulo semanal',
              status: const drift.Value('todo'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final conflicts =
          await TaskDomainConflictDetector.detectAndRecordConflicts(
            db,
            taskId: 'task_new',
            now: now,
          );

      expect(conflicts, isEmpty);
    });
  });
}
