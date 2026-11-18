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

  group('Adversarial Stress: BibleStudyDomainConflictDetector', () {
    test('Identifica múltiplos estudos concorrentes do mesmo estudante primário (1 vs N)', () async {
      final now = DateTime.utc(2026, 11, 18, 10, 0);

      await db
          .into(db.people)
          .insert(
            PeopleCompanion.insert(
              id: 'person_multi_stud',
              name: 'Estudante Multi',
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
              title: 'Estudo João',
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
              personId: 'person_multi_stud',
              isPrimary: const drift.Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Estudo 2 pré-existente
      await db
          .into(db.bibleStudies)
          .insert(
            BibleStudiesCompanion.insert(
              id: 'study_2',
              title: 'Estudo Romanos',
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
              personId: 'person_multi_stud',
              isPrimary: const drift.Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Estudo 3 recém-chegado via sync
      await db
          .into(db.bibleStudies)
          .insert(
            BibleStudiesCompanion.insert(
              id: 'study_3',
              title: 'Estudo Hebreus',
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
              id: 'part_3',
              studyId: 'study_3',
              personId: 'person_multi_stud',
              isPrimary: const drift.Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final conflicts =
          await BibleStudyDomainConflictDetector.detectAndRecordConflicts(
            db,
            studyId: 'study_3',
            now: now,
          );

      // Deve detectar conflito com AMBOS os estudos 1 e 2
      expect(conflicts, hasLength(2));
      final conflictingIds = conflicts.map((c) => c.conflictingStudyId).toSet();
      expect(conflictingIds, containsAll(['study_1', 'study_2']));

      // Verifica persistência íntegra em app_kv_store
      final active = await BibleStudyDomainConflictDetector.getActiveConflicts(
        db,
      );
      expect(active, hasLength(2));

      // Verifica que os dados originais não foram corrompidos
      final s3 = await (db.select(
        db.bibleStudies,
      )..where((t) => t.id.equals('study_3'))).getSingle();
      expect(s3.status, equals('conflito'));
      expect(s3.title, equals('Estudo Hebreus'));
    });

    test('Comparação de nextPlannedAt com fusos horários diferentes (UTC vs Offset local)', () async {
      final utcTime = DateTime.parse('2026-11-20T14:00:00Z');
      final localEquivalent = DateTime.parse(
        '2026-11-20T11:00:00-03:00',
      ); // Mesmo instante absoluto

      await db
          .into(db.bibleStudies)
          .insert(
            BibleStudiesCompanion.insert(
              id: 'study_time_1',
              title: 'Estudo Sexta UTC',
              publicationId: 'lff-book',
              startedAt: DateTime.utc(2026, 1, 1),
              nextPlannedAt: drift.Value(utcTime),
              status: const drift.Value('ativo'),
              createdAt: DateTime.utc(2026, 1, 1),
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      await db
          .into(db.bibleStudies)
          .insert(
            BibleStudiesCompanion.insert(
              id: 'study_time_2',
              title: 'Estudo Sexta Offset',
              publicationId: 'lff-book',
              startedAt: DateTime.utc(2026, 1, 1),
              nextPlannedAt: drift.Value(localEquivalent),
              status: const drift.Value('ativo'),
              createdAt: DateTime.utc(2026, 1, 1),
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      final conflicts =
          await BibleStudyDomainConflictDetector.detectAndRecordConflicts(
            db,
            studyId: 'study_time_2',
          );

      expect(conflicts, hasLength(1));
      expect(conflicts.first.conflictingStudyId, equals('study_time_1'));
      expect(conflicts.first.reason, equals('overlapping_planned_session'));
    });

    test(
      'Estudo soft-deleted com mesmo nextPlannedAt NÃO gera conflito',
      () async {
        final planned = DateTime.utc(2026, 11, 20, 14, 0);

        await db
            .into(db.bibleStudies)
            .insert(
              BibleStudiesCompanion.insert(
                id: 'study_deleted',
                title: 'Estudo Excluído',
                publicationId: 'lff-book',
                startedAt: DateTime.utc(2026, 1, 1),
                nextPlannedAt: drift.Value(planned),
                status: const drift.Value('ativo'),
                deletedAt: drift.Value(DateTime.utc(2026, 11, 1)),
                createdAt: DateTime.utc(2026, 1, 1),
                updatedAt: DateTime.utc(2026, 1, 1),
              ),
            );

        await db
            .into(db.bibleStudies)
            .insert(
              BibleStudiesCompanion.insert(
                id: 'study_live',
                title: 'Estudo Ativo',
                publicationId: 'lff-book',
                startedAt: DateTime.utc(2026, 1, 1),
                nextPlannedAt: drift.Value(planned),
                status: const drift.Value('ativo'),
                createdAt: DateTime.utc(2026, 1, 1),
                updatedAt: DateTime.utc(2026, 1, 1),
              ),
            );

        final conflicts =
            await BibleStudyDomainConflictDetector.detectAndRecordConflicts(
              db,
              studyId: 'study_live',
            );
        expect(conflicts, isEmpty);
      },
    );

    test('Estudo com status "pausado" com mesmo nextPlannedAt GERA conflito (estudo pausado ainda é ativo)', () async {
      final planned = DateTime.utc(2026, 11, 20, 15, 0);

      await db
          .into(db.bibleStudies)
          .insert(
            BibleStudiesCompanion.insert(
              id: 'study_paused',
              title: 'Estudo Pausado Temporariamente',
              publicationId: 'lff-book',
              startedAt: DateTime.utc(2026, 1, 1),
              nextPlannedAt: drift.Value(planned),
              status: const drift.Value('pausado'),
              createdAt: DateTime.utc(2026, 1, 1),
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      await db
          .into(db.bibleStudies)
          .insert(
            BibleStudiesCompanion.insert(
              id: 'study_incoming_active',
              title: 'Estudo Novo Agendado',
              publicationId: 'lff-book',
              startedAt: DateTime.utc(2026, 1, 1),
              nextPlannedAt: drift.Value(planned),
              status: const drift.Value('ativo'),
              createdAt: DateTime.utc(2026, 1, 1),
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      final conflicts =
          await BibleStudyDomainConflictDetector.detectAndRecordConflicts(
            db,
            studyId: 'study_incoming_active',
          );
      expect(conflicts, hasLength(1));
      expect(conflicts.first.conflictingStudyId, equals('study_paused'));
    });

    test('Estudo recebido soft-deleted é ignorado com no-op seguro', () async {
      final planned = DateTime.utc(2026, 11, 20, 14, 0);

      await db
          .into(db.bibleStudies)
          .insert(
            BibleStudiesCompanion.insert(
              id: 'study_incoming_del',
              title: 'Estudo Recebido já Excluído',
              publicationId: 'lff-book',
              startedAt: DateTime.utc(2026, 1, 1),
              nextPlannedAt: drift.Value(planned),
              status: const drift.Value('ativo'),
              deletedAt: drift.Value(DateTime.utc(2026, 11, 1)),
              createdAt: DateTime.utc(2026, 1, 1),
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      final conflicts =
          await BibleStudyDomainConflictDetector.detectAndRecordConflicts(
            db,
            studyId: 'study_incoming_del',
          );
      expect(conflicts, isEmpty);
    });
  });

  group('Adversarial Stress: TaskDomainConflictDetector', () {
    test('Detecta duplicidade de tarefas ativas concorrentes para o mesmo projectId', () async {
      final now = DateTime.utc(2026, 11, 18, 12, 0);

      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              id: 'task_proj_1',
              title: 'Revisar mapas da congregação',
              projectId: const drift.Value('proj_campaign_2026'),
              status: const drift.Value('in_progress'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              id: 'task_proj_2',
              title: 'Revisar mapas da congregação',
              projectId: const drift.Value('proj_campaign_2026'),
              status: const drift.Value('todo'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final conflicts =
          await TaskDomainConflictDetector.detectAndRecordConflicts(
            db,
            taskId: 'task_proj_2',
            now: now,
          );

      expect(conflicts, hasLength(1));
      expect(conflicts.first.incomingTaskId, equals('task_proj_2'));
      expect(conflicts.first.conflictingTaskId, equals('task_proj_1'));
      expect(conflicts.first.reason, equals('duplicate_active_task'));

      final updatedTask = await (db.select(
        db.tasks,
      )..where((t) => t.id.equals('task_proj_2'))).getSingle();
      expect(updatedTask.status, equals('conflito'));
    });

    test('Detecta duplicidade de tarefas autônomas/standalone (personId e projectId nulos)', () async {
      final now = DateTime.utc(2026, 11, 18, 12, 0);

      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              id: 'task_standalone_1',
              title: 'Preparar discurso de 30 minutos',
              status: const drift.Value('todo'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              id: 'task_standalone_2',
              title: 'Preparar discurso de 30 minutos',
              status: const drift.Value('waiting'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final conflicts =
          await TaskDomainConflictDetector.detectAndRecordConflicts(
            db,
            taskId: 'task_standalone_2',
            now: now,
          );

      expect(conflicts, hasLength(1));
      expect(conflicts.first.conflictingTaskId, equals('task_standalone_1'));
    });

    test('Tarefas com títulos idênticos mas um com personId e outro com projectId NÃO conflitam', () async {
      final now = DateTime.utc(2026, 11, 18, 12, 0);

      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              id: 'task_contact_only',
              title: 'Entregar material',
              personId: const drift.Value('person_123'),
              status: const drift.Value('todo'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              id: 'task_project_only',
              title: 'Entregar material',
              projectId: const drift.Value('project_456'),
              status: const drift.Value('todo'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final conflicts =
          await TaskDomainConflictDetector.detectAndRecordConflicts(
            db,
            taskId: 'task_project_only',
          );
      expect(conflicts, isEmpty);
    });

    test('Resistência a caracteres Unicode, acentos e emojis nos títulos', () async {
      final now = DateTime.utc(2026, 11, 18, 12, 0);
      const unicodeTitle =
          '📖 Revisita: Doutor João & Família 👨‍👩‍👧‍👦 (Atenção às dúvidas!)';

      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              id: 'task_uni_1',
              title: unicodeTitle,
              personId: const drift.Value('person_target_uni'),
              status: const drift.Value('todo'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              id: 'task_uni_2',
              title: unicodeTitle,
              personId: const drift.Value('person_target_uni'),
              status: const drift.Value('todo'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final conflicts =
          await TaskDomainConflictDetector.detectAndRecordConflicts(
            db,
            taskId: 'task_uni_2',
            now: now,
          );

      expect(conflicts, hasLength(1));
      expect(conflicts.first.incomingTitle, equals(unicodeTitle));
      expect(conflicts.first.conflictingTitle, equals(unicodeTitle));

      // Verifica recuperação do KV Store
      final active = await TaskDomainConflictDetector.getActiveConflicts(db);
      expect(active, hasLength(1));
      expect(active.first.conflictingTitle, equals(unicodeTitle));
    });

    test('Corrupção de payload em app_kv_store é recuperada sem exceção não-tratada', () async {
      // Injeta JSON inválido na chave do detector
      await db
          .into(db.appKvStore)
          .insert(
            AppKvStoreCompanion.insert(
              key: '${TaskDomainConflictDetector.kvKeyPrefix}corrupt_task',
              value: '{"corrupted": true, "conflicts": "NOT_A_LIST"}',
              updatedAt: drift.Value(DateTime.now().toUtc()),
            ),
          );

      // Deve absorver graciosamente sem lançar FormatException
      final list = await TaskDomainConflictDetector.getActiveConflicts(db);
      expect(list, isEmpty);
    });
  });
}
