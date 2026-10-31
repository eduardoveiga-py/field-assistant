import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/settings/app_settings_manager.dart';
import 'package:ministerio_pessoal/core/feature_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature Toggle Data Preservation Contract', () {
    late AppDatabase db;
    late AppRepository repo;
    late AppSettingsManager settings;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
      settings = AppSettingsManager(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Desativar recursos NUNCA apaga dados, relacionamentos ou históricos no SQLite', () async {
      // 1. Cadastra entidades em todos os módulos
      final person = await repo.createPerson(
        name: 'Carlos Oliveira',
        phone: '11999998888',
        address: 'Rua das Palmeiras, 120',
        status: 'estudo',
      );

      final study = await repo.createStudy(
        title: 'Estudo de Carlos',
        publicationId: 'lff-book',
        language: 'pt',
        currentLesson: 5,
        currentParagraph: 2,
        participantPersonIds: [person.id],
        primaryParticipantId: person.id,
      );

      final session = await repo.createStudySession(
        studyId: study.id,
        dateTime: DateTime.now(),
        publicationCode: 'lff-book',
        lessonCovered: 5,
        paragraphsCovered: '1-3',
        sessionNotes: 'Excelente conversa',
        status: 'realizada',
        participantIds: [person.id],
      );

      final appt = await repo.createAppointment(
        personId: person.id,
        studyId: study.id,
        title: 'Estudo Semanal com Carlos',
        startTime: DateTime.now().add(const Duration(days: 7)),
        endTime: DateTime.now().add(const Duration(days: 7, hours: 1)),
        durationMinutes: 60,
        status: 'agendado',
      );

      await db.into(db.researchArticles).insert(
        ResearchArticlesCompanion.insert(
          id: 'art_teste_1',
          title: 'Artigo sobre Paciência',
          summary: 'Como desenvolver paciência cristã',
          content: 'Conteúdo detalhado do artigo',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          revision: const Value(1),
        ),
      );

      await db.into(db.familyTies).insert(
        FamilyTiesCompanion.insert(
          id: 'ft_teste_1',
          personId: person.id,
          relatedPersonId: Value(person.id),
          relatedPersonName: 'Esposa de Carlos',
          relationshipType: 'esposa',
          createdAt: DateTime.now(),
          revision: const Value(1),
        ),
      );


      // Confirma que os registros existem
      expect((await repo.getAllPeople()).length, equals(1));
      expect((await repo.getAllStudies()).length, equals(1));
      expect((await repo.getAllSessions()).length, equals(1));
      expect((await repo.getAllAppointments()).length, equals(1));
      expect((await db.select(db.researchArticles).get()).length, equals(1));
      expect((await db.select(db.familyTies).get()).length, equals(1));

      // 2. Simula o usuário desativando múltiplos módulos nas configurações
      await settings.setString('feature_${AppFeature.studies.id}_enabled', 'false');
      await settings.setString('feature_${AppFeature.agenda.id}_enabled', 'false');
      await settings.setString('feature_${AppFeature.notesResearch.id}_enabled', 'false');

      // 3. Regra Fundamental: NENHUM dado de estudos, agenda ou pesquisas pode ser deletado do banco
      final studiesAfterDisable = await repo.getAllStudies();
      final sessionsAfterDisable = await repo.getAllSessions();
      final apptsAfterDisable = await repo.getAllAppointments();
      final articlesAfterDisable = await db.select(db.researchArticles).get();
      final familyTiesAfterDisable = await db.select(db.familyTies).get();
      final personAfterDisable = await repo.getPersonById(person.id);

      expect(studiesAfterDisable.length, equals(1), reason: 'Estudos bíblicos devem permanecer intactos');
      expect(studiesAfterDisable.first.id, equals(study.id));
      expect(sessionsAfterDisable.length, equals(1), reason: 'Sessões de estudo não podem ser excluídas');
      expect(sessionsAfterDisable.first.id, equals(session.id));
      expect(apptsAfterDisable.length, equals(1), reason: 'Compromissos agendados devem permanecer intactos');
      expect(apptsAfterDisable.first.id, equals(appt.id));
      expect(articlesAfterDisable.length, equals(1), reason: 'Artigos de pesquisa devem permanecer intactos');
      expect(familyTiesAfterDisable.length, equals(1), reason: 'Vínculos familiares devem permanecer intactos');
      expect(personAfterDisable, isNotNull);
      expect(personAfterDisable!.status, equals('estudo'), reason: 'Status da pessoa deve permanecer inalterado');

      // 4. Reativação: Ao reativar as features, tudo volta a estar disponível perfeitamente
      await settings.setString('feature_${AppFeature.studies.id}_enabled', 'true');
      await settings.setString('feature_${AppFeature.agenda.id}_enabled', 'true');
      await settings.setString('feature_${AppFeature.notesResearch.id}_enabled', 'true');

      final studiesAfterReenable = await repo.getAllStudies();
      expect(studiesAfterReenable.length, equals(1));
      expect(studiesAfterReenable.first.currentLesson, equals(5));
      expect(studiesAfterReenable.first.currentParagraph, equals(3));
    });

  });
}
