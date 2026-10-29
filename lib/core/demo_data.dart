import '../database/repository.dart';

class DemoDataGenerator {
  /// Popula a base com dados 100% fictícios para teste e demonstração isolada.
  static Future<void> populateDemoData(AppRepository repository) async {
    final now = DateTime.now();

    // 1. Pessoas fictícias com coordenadas e bairros
    final p1 = await repository.createPerson(
      name: 'Maria Oliveira (Demo)',
      phone: '(11) 98765-4321',
      address: 'Rua das Flores, 120 - Bairro Centro - Ref: Apto 42',
      latitude: -23.550520,
      longitude: -46.633308,
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
      phone: '(11) 91234-5678',
      address: 'Av. Paulista, 1500 - Bairro Bela Vista',
      latitude: -23.561684,
      longitude: -46.655981,
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
      phone: '(11) 99887-1122',
      address: 'Rua Bela Cintra, 450 - Bairro Consolação',
      latitude: -23.554210,
      longitude: -46.662150,
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
      name: 'Beatriz Martins (Demo - Filha)',
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
      notes: '[Publicações: 4] [Vídeos: 2] Manhã de campo no setor residencial.',
    );

    await repository.createActivityRecord(
      date: now.subtract(const Duration(days: 3)),
      durationSeconds: 5400, // 1h 30m
      modality: 'campo',
      notes: '[Publicações: 2] [Vídeos: 1] Visitas e revisitas.',
    );
  }
}
