import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/experiences/experience_manager.dart';
import 'package:ministerio_pessoal/family/family_ties_manager.dart';
import 'package:ministerio_pessoal/media/person_photos_manager.dart';
import 'package:ministerio_pessoal/publications/person_publications_manager.dart';
import 'package:ministerio_pessoal/research/research_manager.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:ministerio_pessoal/territory/sector_manager.dart';

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

    test('Exclusão de estudo bíblico enfileira soft-delete do estudo, participantes e sessões', () async {
      final p1 = await repo.createPerson(name: 'Estudante A');
      final study = await repo.createStudy(
        title: 'Estudo Esperança',
        publicationId: 'lff-book',
        participantPersonIds: [p1.id],
      );

      // Cria sessão de estudo
      final session = await repo.createStudySession(
        studyId: study.id,
        dateTime: DateTime.now(),
        publicationCode: 'lff',
        lessonCovered: 1,
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
      final sessionDeletes = queueItems.where(
        (q) => q.entityType == 'study_sessions' && q.entityId == session.id && q.operation == 'DELETE',
      );

      expect(studyDeletes.length, equals(1));
      expect(participantDeletes.length, equals(1));
      expect(sessionDeletes.length, equals(1));
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

    test('ResearchManager: criação, atualização e exclusão de tags e artigos enfileiram na sync_queue', () async {
      final mgr = ResearchManager(db);

      // 1. Tag
      final tag = await mgr.addTag('Profecia');
      var queue = await db.select(db.syncQueue).get();
      expect(queue.any((q) => q.entityType == 'research_tags' && q.entityId == tag.id && q.operation == 'INSERT'), isTrue);

      await mgr.updateTag(tag.id, 'Profecias Messiânicas');
      queue = await db.select(db.syncQueue).get();
      expect(queue.any((q) => q.entityType == 'research_tags' && q.entityId == tag.id && q.operation == 'UPDATE'), isTrue);

      await mgr.deleteTag(tag.id);
      queue = await db.select(db.syncQueue).get();
      expect(queue.any((q) => q.entityType == 'research_tags' && q.entityId == tag.id && q.operation == 'DELETE'), isTrue);

      // 2. Artigo
      final article = await mgr.addArticle(
        title: 'Origem da Bíblia',
        summary: 'Resumo histórico',
        content: 'Conteúdo teocrático',
      );
      queue = await db.select(db.syncQueue).get();
      expect(queue.any((q) => q.entityType == 'research_articles' && q.entityId == article.id && q.operation == 'INSERT'), isTrue);

      await mgr.updateArticle(ResearchArticleItem(
        id: article.id,
        title: 'Origem dos Escritos',
        summary: article.summary,
        content: article.content,
        tags: article.tags,
        attachments: article.attachments,
        createdAt: article.createdAt,
        updatedAt: DateTime.now(),
      ));
      queue = await db.select(db.syncQueue).get();
      expect(queue.any((q) => q.entityType == 'research_articles' && q.entityId == article.id && q.operation == 'UPDATE'), isTrue);

      await mgr.deleteArticle(article.id);
      queue = await db.select(db.syncQueue).get();
      expect(queue.any((q) => q.entityType == 'research_articles' && q.entityId == article.id && q.operation == 'DELETE'), isTrue);
    });

    test('SectorManager, FamilyTies, Experiences e Publications enfileiram na sync_queue', () async {
      // 1. Sector
      final sectorMgr = SectorManager(db);
      final sector = await sectorMgr.addSector('Setor Norte');
      var queue = await db.select(db.syncQueue).get();
      expect(queue.any((q) => q.entityType == 'territory_sectors' && q.entityId == sector.id && q.operation == 'INSERT'), isTrue);

      await sectorMgr.updateSector(sector.id, 'Setor Norte Expandido');
      queue = await db.select(db.syncQueue).get();
      expect(queue.any((q) => q.entityType == 'territory_sectors' && q.entityId == sector.id && q.operation == 'UPDATE'), isTrue);

      await sectorMgr.deleteSector(sector.id);
      queue = await db.select(db.syncQueue).get();
      expect(queue.any((q) => q.entityType == 'territory_sectors' && q.entityId == sector.id && q.operation == 'DELETE'), isTrue);

      // 2. Family Ties
      final tiesMgr = FamilyTiesManager(db);
      final tie = await tiesMgr.addFamilyTie(
        personId: 'p1',
        personName: 'Pessoa 1',
        relatedPersonId: 'p2',
        relatedPersonName: 'Irmão João',
        relationshipType: 'irmão',
      );
      queue = await db.select(db.syncQueue).get();
      expect(queue.any((q) => q.entityType == 'family_ties' && q.entityId == tie.id && q.operation == 'INSERT'), isTrue);

      // 3. Experiences
      final expMgr = ExperienceManager(db);
      final exp = await expMgr.addExperience(
        title: 'Conversa no Parque',
        content: 'Boa acolhida',
      );
      queue = await db.select(db.syncQueue).get();
      expect(queue.any((q) => q.entityType == 'ministry_experiences' && q.entityId == exp.id && q.operation == 'INSERT'), isTrue);

      // 4. Publications
      final pubMgr = PersonPublicationsManager(db);
      final pub = await pubMgr.addPlacedPublication(
        personId: 'p1',
        title: 'Revista A Sentinela',
      );
      queue = await db.select(db.syncQueue).get();
      expect(queue.any((q) => q.entityType == 'person_publications' && q.entityId == pub.id && q.operation == 'INSERT'), isTrue);

      // 5. Photos
      final photoMgr = PersonPhotosManager(db);
      final photo = await photoMgr.addPhoto(
        personId: 'p1',
        photoType: 'person',
        imageData: 'base64_data',
      );
      queue = await db.select(db.syncQueue).get();
      expect(queue.any((q) => q.entityType == 'person_photos' && q.entityId == photo.id && q.operation == 'INSERT'), isTrue);
    });

    test('SupabaseSyncService.syncTables cobre todas as 17 entidades do app para pull completo no segundo dispositivo', () {
      const expectedTables = [
        'people',
        'visits',
        'bible_studies',
        'study_participants',
        'study_sessions',
        'appointments',
        'activity_records',
        'voice_notes',
        'phone_contacts',
        'territory_landmarks',
        'family_ties',
        'ministry_experiences',
        'person_photos',
        'person_publications',
        'research_articles',
        'research_tags',
        'territory_sectors',
      ];

      for (final table in expectedTables) {
        expect(SupabaseSyncService.syncTables.contains(table), isTrue,
            reason: 'Tabela $table deve estar em SupabaseSyncService.syncTables');
        expect(SupabaseSyncService.mapEntityToRemoteTable(table), equals(table));
      }
    });
  });
}
