import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';

void main() {
  late AppDatabase db;
  late AppRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = AppRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Verificação da Fila de Sincronização Automática (Offline-First sync_queue)', () {
    test('Criação de estudo bíblico enfileira estudo e todos os participantes em sync_queue', () async {
      // 1. Cria 2 pessoas
      final p1 = await repo.createPerson(name: 'Estudante 1');
      final p2 = await repo.createPerson(name: 'Estudante 2');

      // 2. Cria estudo com ambos
      final study = await repo.createStudy(
        title: 'Estudo das Escrituras',
        publicationId: 'lff-book',
        participantPersonIds: [p1.id, p2.id],
      );

      // 3. Consulta sync_queue
      final queueItems = await db.select(db.syncQueue).get();
      final studyInserts = queueItems.where(
        (q) => q.entityType == 'bible_studies' && q.entityId == study.id && q.operation == 'INSERT',
      );
      final participantInserts = queueItems.where(
        (q) => q.entityType == 'study_participants' && q.operation == 'INSERT',
      );

      expect(studyInserts.length, equals(1));
      expect(participantInserts.length, equals(2));
    });

    test('Exclusão de estudo bíblico enfileira soft-delete do estudo e de seus participantes', () async {
      final p1 = await repo.createPerson(name: 'Estudante A');
      final study = await repo.createStudy(
        title: 'Estudo Esperança',
        publicationId: 'lff-book',
        participantPersonIds: [p1.id],
      );

      // Deleta estudo
      await repo.deleteStudy(study.id);

      final queueItems = await db.select(db.syncQueue).get();
      final studyDeletes = queueItems.where(
        (q) => q.entityType == 'bible_studies' && q.entityId == study.id && q.operation == 'DELETE',
      );
      final participantDeletes = queueItems.where(
        (q) => q.entityType == 'study_participants' && q.operation == 'DELETE',
      );

      expect(studyDeletes.length, equals(1));
      expect(participantDeletes.length, equals(1));
    });

    test('Exclusão de pessoa enfileira soft-delete da pessoa e dos vínculos de participante', () async {
      final person = await repo.createPerson(name: 'Maria Santos');
      final study = await repo.createStudy(
        title: 'Estudo Fé Viva',
        publicationId: 'lff-book',
        participantPersonIds: [person.id],
      );
      expect(study.id, isNotEmpty);

      // Deleta a pessoa
      await repo.deletePerson(person.id);

      final queueItems = await db.select(db.syncQueue).get();
      final personDeletes = queueItems.where(
        (q) => q.entityType == 'people' && q.entityId == person.id && q.operation == 'DELETE',
      );
      final participantDeletes = queueItems.where(
        (q) => q.entityType == 'study_participants' && q.operation == 'DELETE',
      );

      expect(personDeletes.length, equals(1));
      expect(participantDeletes.length, equals(1));
    });

    test('Criação, atualização e exclusão de compromissos geram fila e marcam vínculos', () async {
      final person = await repo.createPerson(name: 'Carlos Agendado');
      final start = DateTime.now().add(const Duration(days: 1));
      final end = start.add(const Duration(minutes: 45));

      final appt = await repo.createAppointment(
        personId: person.id,
        title: 'Revisita Semanal',
        startTime: start,
        endTime: end,
      );

      // 1. Criação
      var queue = await db.select(db.syncQueue).get();
      expect(
        queue.any((q) => q.entityType == 'appointments' && q.entityId == appt.id && q.operation == 'INSERT'),
        isTrue,
      );

      // 2. Atualização
      await repo.updateAppointment(appt.copyWith(status: 'confirmado'));
      queue = await db.select(db.syncQueue).get();
      expect(
        queue.any((q) => q.entityType == 'appointments' && q.entityId == appt.id && q.operation == 'UPDATE'),
        isTrue,
      );

      // 3. Exclusão
      await repo.deleteAppointment(appt.id);
      queue = await db.select(db.syncQueue).get();
      expect(
        queue.any((q) => q.entityType == 'appointments' && q.entityId == appt.id && q.operation == 'DELETE'),
        isTrue,
      );
    });
  });
}
