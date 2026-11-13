import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/repository.dart';

class DemoDataGenerator {
  static const String demoModeKvKey = 'demo_mode';

  /// Popula a base com dados 100% fictícios para teste e demonstração isolada.
  static Future<void> populateDemoData(AppRepository repository) async {
    await repository.db.into(repository.db.appKvStore).insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: demoModeKvKey,
            value: 'true',
            updatedAt: Value(DateTime.now()),
          ),
        );
    final now = DateTime.now();

    // 1. Pessoas fictícias com coordenadas e bairros
    final p1 = await repository.createPerson(
      name: 'Maria Oliveira (Demo)',
      phone: '(97) 98765-4321',
      address: 'Av. Beira Rio, 120 - Centro - Ref: Próximo ao Porto',
      latitude: -3.102200,
      longitude: -67.939700,
      status: 'estudo',
      preferredSchedule: 'Terças-feiras às 15h',
      generalNotes: 'Muito interessada na esperança da ressurreição. Família receptiva.\n[Alvo: Assistir à reunião presencial]\n[Tarefa: Ler a lição 06]',
      tags: ['estudo', 'família', 'pontual'],
      firstContactAt: now.subtract(const Duration(days: 45)),
      lastContactAt: now.subtract(const Duration(days: 3)),
      nextActionAt: now.add(const Duration(days: 4)),
      nextActionNote: 'Considerar Lição 06 do livro Seja Feliz',
    );

    final p2 = await repository.createPerson(
      name: 'Carlos Pereira (Demo)',
      phone: '(97) 91234-5678',
      address: 'Rua do Porto, 350 - Centro',
      latitude: -3.105120,
      longitude: -67.942350,
      status: 'revisita',
      preferredSchedule: 'Sábados pela manhã',
      generalNotes: 'Perguntou por que Deus permite o sofrimento.\n[Alvo: Ler a Bíblia diariamente]',
      tags: ['revisita', 'filosofia'],
      firstContactAt: now.subtract(const Duration(days: 20)),
      lastContactAt: now.subtract(const Duration(days: 7)),
      nextActionAt: now.subtract(const Duration(days: 1)),
      nextActionNote: 'Levar texto de Tiago 1:13',
    );

    final p3 = await repository.createPerson(
      name: 'Luciana Martins (Demo)',
      phone: '(97) 99887-1122',
      address: 'Travessa Santos Dumont, 85 - Vila Nova',
      latitude: -3.099500,
      longitude: -67.937200,
      status: 'estudo',
      preferredSchedule: 'Quintas-feiras às 19h30',
      generalNotes: 'Estuda em conjunto com sua filha Beatriz.\n[Tarefa: Responder perguntas do quadro da lição 05]',
      tags: ['estudo', 'grupo'],
      firstContactAt: now.subtract(const Duration(days: 60)),
      lastContactAt: now.subtract(const Duration(days: 5)),
      nextActionAt: now.add(const Duration(days: 2)),
      nextActionNote: 'Lição 04, parágrafo 3',
    );

    final p4 = await repository.createPerson(
      name: 'Beatriz Martins (Demo)',
      status: 'estudo',
      firstContactAt: now.subtract(const Duration(days: 60)),
      generalNotes: 'Participa do estudo da mãe Luciana.',
      tags: ['jovem'],
    );

    // 2. Revisitas e conversas
    await repository.createVisit(
      personId: p1.id,
      dateTime: now.subtract(const Duration(days: 10)),
      contactType: 'revisita',
      result: 'Conversa agradável sobre o Reino de Deus.',
      notes: 'Leu Mateus 6:9,10.',
      nextStep: 'Iniciar lição introdutória.',
      suggestedReturnDate: now.subtract(const Duration(days: 3)),
    );

    await repository.createVisit(
      personId: p2.id,
      dateTime: now.subtract(const Duration(days: 7)),
      contactType: 'revisita',
      result: 'Breve conversa na portaria.',
      notes: 'Deixou tratado.',
      suggestedReturnDate: now.subtract(const Duration(days: 1)),
    );

    await repository.createVisit(
      personId: p2.id,
      dateTime: now.subtract(const Duration(days: 14)),
      contactType: 'tentativa_sem_contato',
      result: 'Ninguém atendeu ao interfone.',
    );

    // 3. Estudo Bíblico 1 (Individual)
    final s1 = await repository.createStudy(
      title: 'Estudo de Maria Oliveira',
      publicationId: 'lff-book',
      language: 'pt',
      currentLesson: 5,
      currentParagraph: 4,
      participantPersonIds: [p1.id],
    );

    // Sessão do Estudo 1 com assistência registrada
    await repository.createStudySession(
      studyId: s1.id,
      dateTime: now.subtract(const Duration(days: 3)),
      lessonCovered: 5,
      paragraphsCovered: '1-4',
      sessionNotes: '[Assistência: 2]\nCompreendeu bem a diferença entre a Bíblia e outros livros.',
      participantIds: [p1.id],
      status: 'realizada',
    );

    // 4. Estudo Bíblico 2 (Compartilhado: 2 participantes, mas continua sendo 1 ÚNICO estudo!)
    final s2 = await repository.createStudy(
      title: 'Estudo em Família (Luciana e Beatriz)',
      publicationId: 'lff-book',
      language: 'pt',
      currentLesson: 4,
      currentParagraph: 2,
      participantPersonIds: [p3.id, p4.id],
      primaryParticipantId: p3.id,
    );

    // Sessão do Estudo 2 com 3 presentes (mãe, filha e vizinha)
    await repository.createStudySession(
      studyId: s2.id,
      dateTime: now.subtract(const Duration(days: 5)),
      lessonCovered: 4,
      paragraphsCovered: '1-2',
      sessionNotes: '[Assistência: 3]\nAmbas responderam às perguntas do quadro e vizinha assistiu.',
      participantIds: [p3.id, p4.id],
      status: 'realizada',
    );

    // 5. Compromissos
    await repository.createAppointment(
      personId: p1.id,
      studyId: s1.id,
      title: 'Estudo Bíblico - Maria',
      startTime: now.add(const Duration(days: 4, hours: 2)),
      endTime: now.add(const Duration(days: 4, hours: 2, minutes: 45)),
      durationMinutes: 45,
      status: 'planejado',
      locationNotes: 'Na casa da moradora',
    );

    await repository.createAppointment(
      personId: p2.id,
      title: 'Revisita - Carlos',
      startTime: now.add(const Duration(days: 1, hours: 3)),
      endTime: now.add(const Duration(days: 1, hours: 3, minutes: 20)),
      durationMinutes: 20,
      status: 'confirmado',
    );

    // 6. Atividades de Campo (Witness Work com publicações e vídeos)
    await repository.createActivityRecord(
      date: now.subtract(const Duration(days: 1)),
      durationSeconds: 7200, // 2 horas
      modality: 'campo',
      notes:
          '[Publicações: 4] [Vídeos: 2] Manhã de campo no setor residencial.',
    );

    await repository.createActivityRecord(
      date: now.subtract(const Duration(days: 3)),
      durationSeconds: 5400, // 1h 30m
      modality: 'campo',
      notes: '[Publicações: 2] [Vídeos: 1] Visitas e revisitas.',
    );
  }

  static const demoPersonNames = {
    'Maria Oliveira (Demo)',
    'Carlos Pereira (Demo)',
    'Luciana Martins (Demo)',
    'Beatriz Martins (Demo)',
    'Beatriz Martins (Demo - Filha)',
  };

  static const demoActivityNotes = {
    '[Publicações: 4] [Vídeos: 2] Manhã de campo no setor residencial.',
    '[Publicações: 2] [Vídeos: 1] Visitas e revisitas.',
  };

  static const demoStudyTitles = {
    'Estudo de Maria Oliveira',
    'Estudo em Família (Luciana e Beatriz)',
  };

  static const demoAppointmentTitles = {
    'Estudo Bíblico - Maria',
    'Revisita - Carlos',
  };

  /// Verifica se há registros de demonstração no banco.
  static Future<bool> hasDemoData(AppRepository repository) async {
    final db = repository.db;
    final people = await (db.select(db.people)
          ..where((t) => t.name.like('%(Demo%')))
        .get();
    return people.isNotEmpty;
  }

  /// Remove com segurança todos os registros de teste e demonstração do banco.
  static Future<int> clearDemoData(AppRepository repository) async {
    final db = repository.db;
    var removedCount = 0;

    await db.transaction(() async {
      final clearedEntityIds = <String>{};

      // 1. Identifica e exclui pessoas demo e registros dependentes
      final demoPeople = await (db.select(db.people)
            ..where((t) => t.name.like('%(Demo%')))
          .get();
      final demoPersonIds = demoPeople.map((p) => p.id).toSet();
      clearedEntityIds.addAll(demoPersonIds);

      if (demoPersonIds.isNotEmpty) {
        removedCount += demoPeople.length;
        final demoVisits = await (db.select(db.visits)
              ..where((t) => t.personId.isIn(demoPersonIds)))
            .get();
        clearedEntityIds.addAll(demoVisits.map((v) => v.id));
        await (db.delete(db.visits)
              ..where((t) => t.personId.isIn(demoPersonIds)))
            .go();

        final demoPersonAppts = await (db.select(db.appointments)
              ..where((t) => t.personId.isIn(demoPersonIds)))
            .get();
        clearedEntityIds.addAll(demoPersonAppts.map((a) => a.id));
        await (db.delete(db.appointments)
              ..where((t) => t.personId.isIn(demoPersonIds)))
            .go();

        final demoPersonParts = await (db.select(db.studyParticipants)
              ..where((t) => t.personId.isIn(demoPersonIds)))
            .get();
        clearedEntityIds.addAll(demoPersonParts.map((sp) => sp.id));
        await (db.delete(db.studyParticipants)
              ..where((t) => t.personId.isIn(demoPersonIds)))
            .go();

        final demoPhotos = await (db.select(db.personPhotos)
              ..where((t) => t.personId.isIn(demoPersonIds)))
            .get();
        clearedEntityIds.addAll(demoPhotos.map((ph) => ph.id));
        await (db.delete(db.personPhotos)
              ..where((t) => t.personId.isIn(demoPersonIds)))
            .go();

        final demoPubs = await (db.select(db.personPublications)
              ..where((t) => t.personId.isIn(demoPersonIds)))
            .get();
        clearedEntityIds.addAll(demoPubs.map((pb) => pb.id));
        await (db.delete(db.personPublications)
              ..where((t) => t.personId.isIn(demoPersonIds)))
            .go();

        await (db.delete(db.people)
              ..where((t) => t.id.isIn(demoPersonIds)))
            .go();
      }

      // 2. Identifica e exclui estudos demo
      final demoStudies = await (db.select(db.bibleStudies)
            ..where((t) => t.title.isIn(demoStudyTitles)))
          .get();
      final demoStudyIds = demoStudies.map((s) => s.id).toSet();
      clearedEntityIds.addAll(demoStudyIds);
      if (demoStudyIds.isNotEmpty) {
        final demoSessions = await (db.select(db.studySessions)
              ..where((t) => t.studyId.isIn(demoStudyIds)))
            .get();
        clearedEntityIds.addAll(demoSessions.map((ss) => ss.id));
        await (db.delete(db.studySessions)
              ..where((t) => t.studyId.isIn(demoStudyIds)))
            .go();

        final demoStudyParts = await (db.select(db.studyParticipants)
              ..where((t) => t.studyId.isIn(demoStudyIds)))
            .get();
        clearedEntityIds.addAll(demoStudyParts.map((sp) => sp.id));
        await (db.delete(db.studyParticipants)
              ..where((t) => t.studyId.isIn(demoStudyIds)))
            .go();

        await (db.delete(db.bibleStudies)
              ..where((t) => t.id.isIn(demoStudyIds)))
            .go();
      }

      // 3. Exclui compromissos demo restantes
      final demoTitleAppts = await (db.select(db.appointments)
            ..where((t) => t.title.isIn(demoAppointmentTitles)))
          .get();
      clearedEntityIds.addAll(demoTitleAppts.map((a) => a.id));
      await (db.delete(db.appointments)
            ..where((t) => t.title.isIn(demoAppointmentTitles)))
          .go();

      // 4. Exclui apenas relatórios de atividade exatos de demonstração
      final demoActivities = await (db.select(db.activityRecords)
            ..where((t) => t.notes.isIn(demoActivityNotes)))
          .get();
      clearedEntityIds.addAll(demoActivities.map((a) => a.id));
      await (db.delete(db.activityRecords)
            ..where((t) => t.notes.isIn(demoActivityNotes)))
          .go();

      // 5. Remove operações órfãs da sync_queue referentes aos dados demo
      if (clearedEntityIds.isNotEmpty) {
        await (db.delete(db.syncQueue)
              ..where((t) => t.entityId.isIn(clearedEntityIds)))
            .go();
      }

      // 6. Remove flag explícita demo_mode
      await (db.delete(db.appKvStore)
            ..where((t) => t.key.equals(demoModeKvKey)))
          .go();
    });

    return removedCount;
  }
}
