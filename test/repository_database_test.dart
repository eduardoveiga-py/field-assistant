import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/database/connection/connection.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Repositório Drift e Transações Locais', () {
    late AppDatabase db;
    late AppRepository repository;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = AppRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Criação de pessoa insere atomicamente no banco e na fila de sincronização', () async {
      final person = await repository.createPerson(
        name: 'Roberto Dias',
        phone: '98888-7777',
        tags: ['pontual', 'revisita'],
      );

      expect(person.id, isNotEmpty);
      expect(person.name, equals('Roberto Dias'));
      expect(person.revision, equals(1));

      // Verifica fila de sincronização
      final pendingOps = await repository.getPendingSyncOperations();
      expect(pendingOps.length, equals(1));
      expect(pendingOps.first.entityType, equals('people'));
      expect(pendingOps.first.entityId, equals(person.id));
      expect(pendingOps.first.operation, equals('INSERT'));
    });

    test('Busca offline por nome, telefone, endereço, notas e tags', () async {
      await repository.createPerson(
        name: 'Marcos Souza',
        phone: '11999990000',
        address: 'Rua das Palmeiras, 45',
        generalNotes: 'Gosta de conversar sobre profecias',
        tags: ['profecia'],
      );
      await repository.createPerson(
        name: 'Clara Silveira',
        phone: '11888880000',
        address: 'Alameda Santos, 100',
        tags: ['jovem'],
      );

      // Busca por nome
      final byName = await repository.searchPeople('Marcos');
      expect(byName.length, equals(1));
      expect(byName.first.name, contains('Marcos'));

      // Busca por telefone
      final byPhone = await repository.searchPeople('99999');
      expect(byPhone.length, equals(1));

      // Busca por anotações
      final byNotes = await repository.searchPeople('profecias');
      expect(byNotes.length, equals(1));

      // Busca por tags
      final byTag = await repository.searchPeople('jovem');
      expect(byTag.length, equals(1));
      expect(byTag.first.name, contains('Clara'));
    });

    test('Exclusão lógica preserva histórico e enfileira deleção sincronizada', () async {
      final p = await repository.createPerson(name: 'Lucas');
      expect((await repository.getAllPeople()).length, equals(1));

      await repository.deletePerson(p.id);

      // Não aparece mais na listagem ativa
      expect((await repository.getAllPeople()).length, equals(0));

      // Fila possui INSERT e DELETE
      final pendingOps = await repository.getPendingSyncOperations();
      expect(pendingOps.length, equals(2));
      expect(pendingOps.last.operation, equals('DELETE'));
    });

    test('Estudo com múltiplos participantes associa ambos e avança lição após sessão', () async {
      final p1 = await repository.createPerson(name: 'Mãe');
      final p2 = await repository.createPerson(name: 'Filho');

      final study = await repository.createStudy(
        title: 'Estudo em Família',
        publicationId: 'lff-book',
        language: 'pt',
        currentLesson: 1,
        participantPersonIds: [p1.id, p2.id],
      );

      final participants = await repository.getParticipantsForStudy(study.id);
      expect(participants.length, equals(2));

      // Registra sessão realizada avançando para a lição 2 e parágrafos 1-5 com contagem de assistência
      await repository.createStudySession(
        studyId: study.id,
        dateTime: DateTime.now(),
        lessonCovered: 2,
        paragraphsCovered: '1-5',
        sessionNotes: '[Assistência: 4] Família inteira participou',
        status: 'realizada',
        participantIds: [p1.id, p2.id],
      );

      final updatedStudy = await repository.getStudyById(study.id);
      expect(updatedStudy!.currentLesson, equals(2));
      expect(updatedStudy.currentParagraph, equals(5));

      // Verifica enfileiramento na fila de sincronização para estudo e sessão
      final pending = await repository.getPendingSyncOperations();
      final studyUpdate = pending.where((op) => op.entityType == 'bible_studies' && op.operation == 'UPDATE').toList();
      final sessionInsert = pending.where((op) => op.entityType == 'study_sessions' && op.operation == 'INSERT').toList();

      expect(studyUpdate.isNotEmpty, isTrue);
      expect(sessionInsert.isNotEmpty, isTrue);
      expect(sessionInsert.first.payload.contains('[Assistência: 4]'), isTrue);

      // Testa busca global de pessoas por lição e título do estudo bíblico
      final searchByLesson = await repository.searchPeople('Lição 2');
      expect(searchByLesson.any((p) => p.id == p1.id), isTrue);

      final searchByStudyTitle = await repository.searchPeople('Família');
      expect(searchByStudyTitle.any((p) => p.id == p2.id), isTrue);
    });

    test('Reagendamento de compromisso marca o anterior como reagendado e vincula o novo via previousAppointmentId', () async {
      final person = await repository.createPerson(name: 'Davi');
      final originalStart = DateTime(2026, 10, 26, 15, 0);
      final originalEnd = originalStart.add(const Duration(minutes: 30));

      final originalAppt = await repository.createAppointment(
        personId: person.id,
        title: 'Revisita Davi',
        startTime: originalStart,
        endTime: originalEnd,
        durationMinutes: 30,
      );

      final newStart = DateTime(2026, 10, 27, 10, 0);
      final newEnd = newStart.add(const Duration(minutes: 45));
      final newAppt = await repository.rescheduleAppointment(
        oldAppointment: originalAppt,
        newStartTime: newStart,
        newEndTime: newEnd,
        durationMinutes: 45,
      );

      expect(newAppt.previousAppointmentId, equals(originalAppt.id));
      expect(newAppt.startTime, equals(newStart));
      expect(newAppt.durationMinutes, equals(45));

      final updatedOldAppt = await repository.getAppointmentById(originalAppt.id);
      expect(updatedOldAppt!.status, equals('reagendado'));

      // Verifica fila de sincronização: UPDATE para o antigo e INSERT para o novo
      final pendingOps = await repository.getPendingSyncOperations();
      expect(pendingOps.any((op) => op.entityId == originalAppt.id && op.operation == 'UPDATE'), isTrue);
      expect(pendingOps.any((op) => op.entityId == newAppt.id && op.operation == 'INSERT'), isTrue);
    });

    test('Atualização de visita altera anotações, incrementa revisão e enfileira UPDATE', () async {
      final person = await repository.createPerson(name: 'Beatriz');
      final visit = await repository.createVisit(
        personId: person.id,
        dateTime: DateTime(2026, 10, 20, 10, 0),
        contactType: 'conversa_inicial',
        result: 'Mostrou interesse',
      );

      expect(visit.revision, equals(1));

      final visitToUpdate = visit.copyWith(
        notes: const Value('Anotações complementares pós-visita'),
        topicsDiscussed: const Value('Reino de Deus'),
        nextStep: const Value('Levar brochura Viva Para Sempre'),
      );
      await repository.updateVisit(visitToUpdate);

      final updatedVisit = (await repository.getVisitById(visit.id))!;
      expect(updatedVisit.notes, equals('Anotações complementares pós-visita'));
      expect(updatedVisit.topicsDiscussed, equals('Reino de Deus'));
      expect(updatedVisit.nextStep, equals('Levar brochura Viva Para Sempre'));
      expect(updatedVisit.revision, equals(2));

      final pendingOps = await repository.getPendingSyncOperations();
      expect(pendingOps.any((op) => op.entityId == visit.id && op.operation == 'UPDATE'), isTrue);
    });

    test('Lixeira permite listar itens excluídos, restaurá-los ou excluí-los definitivamente', () async {
      final person = await repository.createPerson(name: 'Item Lixeira');
      await repository.deletePerson(person.id);

      // Listar itens na lixeira
      final deletedItems = await repository.getDeletedItems();
      expect(deletedItems.any((item) => item['id'] == person.id && item['type'] == 'people'), isTrue);

      // Restaurar item
      await repository.restoreDeletedItem('people', person.id);
      final activePeople = await repository.getAllPeople();
      expect(activePeople.any((p) => p.id == person.id), isTrue);

      // Deletar novamente e excluir definitivamente
      await repository.deletePerson(person.id);
      await repository.permanentlyDeleteItem('people', person.id);

      final deletedAfterPerm = await repository.getDeletedItems();
      expect(deletedAfterPerm.any((item) => item['id'] == person.id), isFalse);
    });

    test('Inicialização via AppDatabaseConnection.connect(inMemory: true) persiste e lê dados', () async {
      final defaultDb = AppDatabase(AppDatabaseConnection.connect(inMemory: true));
      final defaultRepo = AppRepository(defaultDb);
      final p = await defaultRepo.createPerson(name: 'Teste Construtor Padrao');
      expect(p.name, equals('Teste Construtor Padrao'));
      final fetched = await defaultRepo.getPersonById(p.id);
      expect(fetched?.name, equals('Teste Construtor Padrao'));
      await defaultDb.close();
    });
  });
}
