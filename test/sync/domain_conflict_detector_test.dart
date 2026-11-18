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

  group('Domain Conflict Detector — AppointmentDomainConflictDetector', () {
    test('intervalsOverlap calcula sobreposições estritas e adjacências corretamente', () {
      final t1 = DateTime.utc(2026, 11, 18, 9, 0);
      final t2 = DateTime.utc(2026, 11, 18, 10, 0);
      final t3 = DateTime.utc(2026, 11, 18, 11, 0);
      final tHalf = DateTime.utc(2026, 11, 18, 9, 30);

      // Sobreposição parcial
      expect(
        AppointmentDomainConflictDetector.intervalsOverlap(t1, t2, tHalf, t3),
        isTrue,
      );

      // Intervalos adjacentes (sem sobreposição)
      expect(
        AppointmentDomainConflictDetector.intervalsOverlap(t1, t2, t2, t3),
        isFalse,
      );

      // Intervalos disjuntos
      expect(
        AppointmentDomainConflictDetector.intervalsOverlap(t1, tHalf, t2, t3),
        isFalse,
      );
    });

    test(
      'Detecta sobreposição de compromissos ativos e persiste em app_kv_store',
      () async {
        final base = DateTime.utc(2026, 11, 18, 14, 0);

        // Compromisso pré-existente
        await db
            .into(db.appointments)
            .insert(
              AppointmentsCompanion.insert(
                id: 'apt_local_1',
                title: 'Revisita Sr. Silva',
                startTime: base,
                endTime: base.add(const Duration(hours: 1)),
                status: const drift.Value('confirmado'),
                createdAt: base,
                updatedAt: base,
              ),
            );

        // Compromisso recebido do pull com sobreposição de horário
        final incomingStart = base.add(const Duration(minutes: 30));
        await db
            .into(db.appointments)
            .insert(
              AppointmentsCompanion.insert(
                id: 'apt_incoming_2',
                title: 'Revisita Concorrente Dona Maria',
                startTime: incomingStart,
                endTime: incomingStart.add(const Duration(hours: 1)),
                status: const drift.Value('confirmado'),
                createdAt: base,
                updatedAt: base,
              ),
            );

        final conflicts =
            await AppointmentDomainConflictDetector.detectAndRecordOverlaps(
              db,
              appointmentId: 'apt_incoming_2',
              now: base,
            );

        expect(conflicts, hasLength(1));
        expect(conflicts.first.incomingAppointmentId, equals('apt_incoming_2'));
        expect(conflicts.first.conflictingAppointmentId, equals('apt_local_1'));

        // Status alterado para 'conflito' sem exclusão
        final apt2 = await (db.select(
          db.appointments,
        )..where((t) => t.id.equals('apt_incoming_2'))).getSingle();
        expect(apt2.status, equals('conflito'));

        // Auditoria no KV store
        final active =
            await AppointmentDomainConflictDetector.getActiveConflicts(db);
        expect(active, hasLength(1));

        // Limpeza consciente de conflito
        await AppointmentDomainConflictDetector.clearConflict(
          db,
          'apt_incoming_2',
        );
        final afterClear =
            await AppointmentDomainConflictDetector.getActiveConflicts(db);
        expect(afterClear, isEmpty);
      },
    );

    test(
      'Compromissos inativos (cancelado, etc.) não geram conflito',
      () async {
        final base = DateTime.utc(2026, 11, 18, 16, 0);

        await db
            .into(db.appointments)
            .insert(
              AppointmentsCompanion.insert(
                id: 'apt_cancelled',
                title: 'Compromisso Cancelado',
                startTime: base,
                endTime: base.add(const Duration(hours: 1)),
                status: const drift.Value('cancelado'),
                createdAt: base,
                updatedAt: base,
              ),
            );

        await db
            .into(db.appointments)
            .insert(
              AppointmentsCompanion.insert(
                id: 'apt_active',
                title: 'Novo Compromisso Ativo',
                startTime: base,
                endTime: base.add(const Duration(hours: 1)),
                status: const drift.Value('confirmado'),
                createdAt: base,
                updatedAt: base,
              ),
            );

        final conflicts =
            await AppointmentDomainConflictDetector.detectAndRecordOverlaps(
              db,
              appointmentId: 'apt_active',
            );
        expect(conflicts, isEmpty);
      },
    );
  });

  group('Domain Conflict Detector — BibleStudyDomainConflictDetector', () {
    test('Detecta conflito de mesmo estudante primário alocado a dois estudos ativos', () async {
      final now = DateTime.utc(2026, 11, 18, 10, 0);

      // Pessoa estudante
      await db
          .into(db.people)
          .insert(
            PeopleCompanion.insert(
              id: 'person_student_primary',
              name: 'Estudante Marcos',
              status: const drift.Value('estudante'),
              firstContactAt: now,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Estudo A
      await db
          .into(db.bibleStudies)
          .insert(
            BibleStudiesCompanion.insert(
              id: 'study_a',
              title: 'Estudo Evangelho de Mateus',
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
              id: 'sp_a',
              studyId: 'study_a',
              personId: 'person_student_primary',
              isPrimary: const drift.Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Estudo B concorrente
      await db
          .into(db.bibleStudies)
          .insert(
            BibleStudiesCompanion.insert(
              id: 'study_b',
              title: 'Estudo Seja Feliz Para Sempre',
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
              id: 'sp_b',
              studyId: 'study_b',
              personId: 'person_student_primary',
              isPrimary: const drift.Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final conflicts =
          await BibleStudyDomainConflictDetector.detectAndRecordConflicts(
            db,
            studyId: 'study_b',
            now: now,
          );

      expect(conflicts, hasLength(1));
      expect(conflicts.first.incomingStudyId, equals('study_b'));
      expect(conflicts.first.conflictingStudyId, equals('study_a'));
      expect(conflicts.first.reason, equals('duplicate_primary_student'));

      // Status marcado como 'conflito'
      final studyB = await (db.select(
        db.bibleStudies,
      )..where((t) => t.id.equals('study_b'))).getSingle();
      expect(studyB.status, equals('conflito'));

      // Resolução / limpeza
      await BibleStudyDomainConflictDetector.clearConflict(db, 'study_b');
      expect(
        await BibleStudyDomainConflictDetector.getActiveConflicts(db),
        isEmpty,
      );
    });

    test('Estudos concluídos ou encerrados não acionam conflito', () async {
      final now = DateTime.utc(2026, 11, 18, 10, 0);

      await db
          .into(db.people)
          .insert(
            PeopleCompanion.insert(
              id: 'person_student_old',
              name: 'Estudante Concluido',
              status: const drift.Value('estudante'),
              firstContactAt: now,
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db
          .into(db.bibleStudies)
          .insert(
            BibleStudiesCompanion.insert(
              id: 'study_done',
              title: 'Estudo Antigo Concluído',
              publicationId: 'lff-book',
              startedAt: now,
              status: const drift.Value('concluido'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db
          .into(db.studyParticipants)
          .insert(
            StudyParticipantsCompanion.insert(
              id: 'sp_done',
              studyId: 'study_done',
              personId: 'person_student_old',
              isPrimary: const drift.Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db
          .into(db.bibleStudies)
          .insert(
            BibleStudiesCompanion.insert(
              id: 'study_new',
              title: 'Novo Estudo Ativo',
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
              id: 'sp_new',
              studyId: 'study_new',
              personId: 'person_student_old',
              isPrimary: const drift.Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final conflicts =
          await BibleStudyDomainConflictDetector.detectAndRecordConflicts(
            db,
            studyId: 'study_new',
          );
      expect(conflicts, isEmpty);
    });
  });

  group('Domain Conflict Detector — TaskDomainConflictDetector', () {
    test(
      'Detecta duplicidade de tarefas ativas concorrentes para o mesmo contato',
      () async {
        final now = DateTime.utc(2026, 11, 18, 11, 0);

        await db
            .into(db.people)
            .insert(
              PeopleCompanion.insert(
                id: 'person_target_task',
                name: 'Ana Revisita',
                status: const drift.Value('revisita'),
                firstContactAt: now,
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.tasks)
            .insert(
              TasksCompanion.insert(
                id: 'task_existing_1',
                title: 'Entregar folheto Notícias do Reino',
                personId: const drift.Value('person_target_task'),
                status: const drift.Value('todo'),
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.tasks)
            .insert(
              TasksCompanion.insert(
                id: 'task_incoming_2',
                title: 'Entregar folheto Notícias do Reino',
                personId: const drift.Value('person_target_task'),
                status: const drift.Value('todo'),
                createdAt: now,
                updatedAt: now,
              ),
            );

        final conflicts =
            await TaskDomainConflictDetector.detectAndRecordConflicts(
              db,
              taskId: 'task_incoming_2',
              now: now,
            );

        expect(conflicts, hasLength(1));
        expect(conflicts.first.incomingTaskId, equals('task_incoming_2'));
        expect(conflicts.first.conflictingTaskId, equals('task_existing_1'));
        expect(conflicts.first.reason, equals('duplicate_active_task'));

        // Status alterado para conflito
        final t2 = await (db.select(
          db.tasks,
        )..where((t) => t.id.equals('task_incoming_2'))).getSingle();
        expect(t2.status, equals('conflito'));

        // Limpeza de conflito
        await TaskDomainConflictDetector.clearConflict(db, 'task_incoming_2');
        expect(
          await TaskDomainConflictDetector.getActiveConflicts(db),
          isEmpty,
        );
      },
    );

    test('Tarefas com títulos idênticos mas pessoas distintas não entram em conflito', () async {
      final now = DateTime.utc(2026, 11, 18, 11, 0);

      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              id: 'task_person_a',
              title: 'Levar revista A Sentinela',
              personId: const drift.Value('person_111'),
              status: const drift.Value('todo'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              id: 'task_person_b',
              title: 'Levar revista A Sentinela',
              personId: const drift.Value('person_222'),
              status: const drift.Value('todo'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final conflicts =
          await TaskDomainConflictDetector.detectAndRecordConflicts(
            db,
            taskId: 'task_person_b',
          );
      expect(conflicts, isEmpty);
    });
  });
}
