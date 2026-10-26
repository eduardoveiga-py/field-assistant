import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';

void main() {
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

      // Registra sessão realizada avançando para a lição 2
      await repository.createStudySession(
        studyId: study.id,
        dateTime: DateTime.now(),
        lessonCovered: 2,
        paragraphsCovered: '1-5',
        status: 'realizada',
        participantIds: [p1.id, p2.id],
      );

      final updatedStudy = await repository.getStudyById(study.id);
      expect(updatedStudy!.currentLesson, equals(2));
    });
  });
}
