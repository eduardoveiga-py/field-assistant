import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/dashboard/counting_rules.dart';

void main() {
  group('Regras Estritas de Contagem do Dashboard', () {
    final now = DateTime(2026, 10, 26, 10, 0);
    final periodStart = DateTime(2026, 10, 1);
    final periodEnd = DateTime(2026, 10, 31, 23, 59, 59);

    test('TC-COUNT-01: Estudo com múltiplos participantes conta como EXATAMENTE 1 estudo ativo', () {
      final studies = [
        BibleStudyEntry(
          id: 'study-1',
          title: 'Estudo em Família Silva',
          ownerId: 'user-1',
          startedAt: now.subtract(const Duration(days: 30)),
          status: 'ativo',
          publicationId: 'lff-book',
          language: 'pt',
          frequency: 'semanal',
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
      ];

      final metrics = DashboardCalculator.calculate(
        studies: studies,
        sessions: [],
        visits: [],
        appointments: [],
        activities: [],
        periodStart: periodStart,
        periodEnd: periodEnd,
        nowOverride: now,
      );

      expect(metrics.activeStudiesCount, equals(1));
    });

    test('TC-COUNT-02: Sessão realizada conta como 1 sessão, independente do número de participantes presentes', () {
      final sessions = [
        StudySessionEntry(
          id: 'session-1',
          studyId: 'study-1',
          dateTimeField: DateTime(2026, 10, 15, 14, 0),
          status: 'realizada',
          participantIds: '["person-1", "person-2", "person-3", "person-4"]',
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
      ];

      final metrics = DashboardCalculator.calculate(
        studies: [],
        sessions: sessions,
        visits: [],
        appointments: [],
        activities: [],
        periodStart: periodStart,
        periodEnd: periodEnd,
        nowOverride: now,
      );

      expect(metrics.heldSessionsCount, equals(1));
      expect(metrics.uniqueParticipantsCount, equals(4));
    });

    test('TC-COUNT-03: Sessões canceladas ou não realizadas NÃO contam como sessões realizadas', () {
      final sessions = [
        StudySessionEntry(
          id: 'session-1',
          studyId: 'study-1',
          dateTimeField: DateTime(2026, 10, 10, 14, 0),
          status: 'realizada',
          participantIds: '["p1"]',
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
        StudySessionEntry(
          id: 'session-2',
          studyId: 'study-1',
          dateTimeField: DateTime(2026, 10, 17, 14, 0),
          status: 'cancelada',
          participantIds: '["p1"]',
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
        StudySessionEntry(
          id: 'session-3',
          studyId: 'study-1',
          dateTimeField: DateTime(2026, 10, 24, 14, 0),
          status: 'nao_realizada',
          participantIds: '["p1"]',
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
      ];

      final metrics = DashboardCalculator.calculate(
        studies: [],
        sessions: sessions,
        visits: [],
        appointments: [],
        activities: [],
        periodStart: periodStart,
        periodEnd: periodEnd,
        nowOverride: now,
      );

      expect(metrics.heldSessionsCount, equals(1));
    });

    test('TC-COUNT-04: Revisita agendada para o futuro NÃO conta como revisita realizada', () {
      final visits = [
        VisitEntry(
          id: 'visit-1',
          personId: 'p1',
          dateTimeField: DateTime(2026, 10, 5, 10, 0),
          contactType: 'revisita',
          result: 'Conversa realizada com sucesso',
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
      ];

      final futureAppointments = [
        AppointmentEntry(
          id: 'appt-1',
          personId: 'p1',
          title: 'Revisita Futura',
          startTime: now.add(const Duration(days: 3)),
          endTime: now.add(const Duration(days: 3, minutes: 30)),
          durationMinutes: 30,
          status: 'planejado',
          isProvisional: false,
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
      ];

      final metrics = DashboardCalculator.calculate(
        studies: [],
        sessions: [],
        visits: visits,
        appointments: futureAppointments,
        activities: [],
        periodStart: periodStart,
        periodEnd: periodEnd,
        nowOverride: now,
      );

      expect(metrics.heldVisitsCount, equals(1));
      expect(metrics.scheduledVisitsCount, equals(1));
    });

    test(
      'TC-COUNT-05: Tentativa sem contato NÃO conta como conversa realizada',
      () {
        final visits = [
          VisitEntry(
            id: 'visit-1',
            personId: 'p1',
            dateTimeField: DateTime(2026, 10, 8, 10, 0),
            contactType: 'tentativa_sem_contato',
            result: 'Ninguém atendeu',
            createdAt: now,
            updatedAt: now,
            revision: 1,
          ),
          VisitEntry(
            id: 'visit-2',
            personId: 'p1',
            dateTimeField: DateTime(2026, 10, 12, 10, 0),
            contactType: 'revisita',
            result: 'Atendeu e conversou',
            createdAt: now,
            updatedAt: now,
            revision: 1,
          ),
        ];

        final metrics = DashboardCalculator.calculate(
          studies: [],
          sessions: [],
          visits: visits,
          appointments: [],
          activities: [],
          periodStart: periodStart,
          periodEnd: periodEnd,
          nowOverride: now,
        );

        expect(metrics.heldVisitsCount, equals(1));
      },
    );

    test('TC-COUNT-06: Contagem de Ações Pendentes e Contatos sem Contato Recente (> 30 dias)', () {
      final people = [
        PersonEntry(
          id: 'p-pending-action',
          name: 'João Ação Pendente',
          firstContactAt: now.subtract(const Duration(days: 40)),
          status: 'interessado',
          tags: '[]',
          nextActionAt: now.subtract(
            const Duration(hours: 2),
          ), // Ação vencida há 2 horas
          lastContactAt: now.subtract(const Duration(days: 5)),
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
        PersonEntry(
          id: 'p-no-recent-contact',
          name: 'Maria Sem Contato Recente',
          firstContactAt: now.subtract(const Duration(days: 60)),
          status: 'revisita',
          tags: '[]',
          lastContactAt: now.subtract(
            const Duration(days: 35),
          ), // 35 dias sem contato
          nextActionAt: now.add(const Duration(days: 5)),
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
        PersonEntry(
          id: 'p-up-to-date',
          name: 'Pedro Em Dia',
          firstContactAt: now.subtract(const Duration(days: 10)),
          status: 'revisita',
          tags: '[]',
          lastContactAt: now.subtract(const Duration(days: 3)), // 3 dias atrás
          nextActionAt: now.add(const Duration(days: 2)),
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
      ];

      final metrics = DashboardCalculator.calculate(
        studies: [],
        sessions: [],
        visits: [],
        appointments: [],
        activities: [],
        people: people,
        periodStart: periodStart,
        periodEnd: periodEnd,
        nowOverride: now,
      );

      expect(metrics.pendingNextActionCount, equals(1));
      expect(metrics.noRecentContactCount, equals(1));
    });

    test('TC-COUNT-07: Contagem de assistência em sessões de estudo com notas [Assistência: X]', () {
      final sessions = [
        StudySessionEntry(
          id: 'sess-1',
          studyId: 'study-1',
          dateTimeField: DateTime(2026, 10, 5, 14, 0),
          status: 'realizada',
          sessionNotes: '[Assistência: 3]\nConsiderado Lição 02',
          participantIds: '["p1"]',
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
        StudySessionEntry(
          id: 'sess-2',
          studyId: 'study-2',
          dateTimeField: DateTime(2026, 10, 12, 14, 0),
          status: 'realizada',
          sessionNotes: '[Assistência: 5]\nFamília inteira presente',
          participantIds: '["p2"]',
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
      ];

      final metrics = DashboardCalculator.calculate(
        studies: [],
        sessions: sessions,
        visits: [],
        appointments: [],
        activities: [],
        periodStart: periodStart,
        periodEnd: periodEnd,
        nowOverride: now,
      );

      // Total de assistência: 3 + 5 = 8
      expect(metrics.totalStudyAttendance, equals(8));
      // Média por estudo: 8 / 2 = 4.0
      expect(metrics.averageAttendancePerStudy, equals(4.0));
    });

    test('TC-COUNT-08: Sessões canceladas NÃO somam na assistência nem na média de estudos', () {
      final sessions = [
        StudySessionEntry(
          id: 'sess-1',
          studyId: 'study-1',
          dateTimeField: DateTime(2026, 10, 5, 14, 0),
          status: 'realizada',
          sessionNotes: '[Assistência: 4]',
          participantIds: '["p1"]',
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
        StudySessionEntry(
          id: 'sess-cancelled',
          studyId: 'study-1',
          dateTimeField: DateTime(2026, 10, 12, 14, 0),
          status: 'cancelada',
          sessionNotes: '[Assistência: 10]', // Não deve ser computado!
          participantIds: '["p1"]',
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
      ];

      final metrics = DashboardCalculator.calculate(
        studies: [],
        sessions: sessions,
        visits: [],
        appointments: [],
        activities: [],
        periodStart: periodStart,
        periodEnd: periodEnd,
        nowOverride: now,
      );

      expect(metrics.heldSessionsCount, equals(1));
      expect(metrics.totalStudyAttendance, equals(4));
      expect(metrics.averageAttendancePerStudy, equals(4.0));
    });

    test('TC-COUNT-09: Fallback de assistência quando não especificada usa participantes ou padrão 1', () {
      final sessions = [
        StudySessionEntry(
          id: 'sess-no-tag',
          studyId: 'study-1',
          dateTimeField: DateTime(2026, 10, 5, 14, 0),
          status: 'realizada',
          sessionNotes: 'Sessão sem tag de assistência',
          participantIds: '["p1", "p2"]', // 2 participantes cadastrados
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
      ];

      final metrics = DashboardCalculator.calculate(
        studies: [],
        sessions: sessions,
        visits: [],
        appointments: [],
        activities: [],
        periodStart: periodStart,
        periodEnd: periodEnd,
        nowOverride: now,
      );

      expect(metrics.totalStudyAttendance, equals(2));
      expect(metrics.averageAttendancePerStudy, equals(2.0));
    });

    test('TC-COUNT-10: Contagem de publicações e vídeos do relatório de ministério', () {
      final activities = [
        ActivityRecordEntry(
          id: 'act-1',
          date: DateTime(2026, 10, 10),
          durationSeconds: 7200,
          modality: 'campo',
          notes: '[Publicações: 3] [Vídeos: 2] Manhã de pregação',
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
      ];

      final visits = [
        VisitEntry(
          id: 'vis-1',
          personId: 'p1',
          dateTimeField: DateTime(2026, 10, 11),
          contactType: 'revisita',
          result: 'Boa conversa',
          scriptureOrPub: 'Brochura Seja Feliz',
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
      ];

      final metrics = DashboardCalculator.calculate(
        studies: [],
        sessions: [],
        visits: visits,
        appointments: [],
        activities: activities,
        periodStart: periodStart,
        periodEnd: periodEnd,
        nowOverride: now,
      );

      expect(
        metrics.totalPlacements,
        equals(4),
      ); // 3 de atividades + 1 de visita
      expect(metrics.totalVideos, equals(2));
    });

    test('TC-COUNT-11: Estudo bíblico avançado (ex: Lição 20) cadastrado no primeiro uso do app conta nas estatísticas do mês sem exigir sessões prévias', () {
      final studies = [
        BibleStudyEntry(
          id: 'study-advanced',
          title: 'Estudo Carlos - Lição 20',
          ownerId: 'user-1',
          startedAt: DateTime(2026, 8, 1), // começou há 2 meses
          status: 'ativo',
          publicationId: 'lff-book',
          currentLesson: 20,
          currentParagraph: 3,
          language: 'pt',
          frequency: 'semanal',
          createdAt: now, // cadastrado agora no primeiro uso do app
          updatedAt: now,
          revision: 1,
        ),
      ];

      final metrics = DashboardCalculator.calculate(
        studies: studies,
        sessions: [], // nenhuma sessão gravada no app ainda
        visits: [],
        appointments: [],
        activities: [],
        periodStart: periodStart,
        periodEnd: periodEnd,
        nowOverride: now,
      );

      // Deve contar como estudo ativo no mês
      expect(metrics.activeStudiesCount, equals(1));
    });

    test('TC-COUNT-12: Estudo bíblico com data de início futura (após o fim do período) NÃO conta como ativo no período', () {
      final studies = [
        BibleStudyEntry(
          id: 'study-future',
          title: 'Estudo Planejado para Próximo Mês',
          ownerId: 'user-1',
          startedAt: DateTime(2026, 11, 15), // início em novembro
          status: 'ativo',
          publicationId: 'lff-book',
          currentLesson: 1,
          currentParagraph: 1,
          language: 'pt',
          frequency: 'semanal',
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
      ];

      final metrics = DashboardCalculator.calculate(
        studies: studies,
        sessions: [],
        visits: [],
        appointments: [],
        activities: [],
        periodStart: periodStart, // outubro
        periodEnd: periodEnd, // 31 de outubro
        nowOverride: now,
      );

      // Não deve contar em outubro, pois só se inicia em novembro
      expect(metrics.activeStudiesCount, equals(0));
    });

    test('TC-COUNT-13: Estudo avançado (Lição >= 34) conta no funil da Parte 3 sem necessitar histórico prévio de 34 sessões registradas', () {
      final studies = [
        BibleStudyEntry(
          id: 'study-part3',
          title: 'Estudo Avançado Mariana',
          ownerId: 'user-1',
          startedAt: DateTime(2026, 5, 1),
          status: 'ativo',
          publicationId: 'lff-book',
          currentLesson: 35, // Seção 3 do livro Seja Feliz Para Sempre!
          currentParagraph: 2,
          language: 'pt',
          frequency: 'semanal',
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
      ];

      final metrics = DashboardCalculator.calculate(
        studies: studies,
        sessions: [],
        visits: [],
        appointments: [],
        activities: [],
        periodStart: periodStart,
        periodEnd: periodEnd,
        nowOverride: now,
      );

      expect(metrics.funnelReachedPart3Count, equals(1));
    });

    test('TC-COUNT-14: Contato prévio (revisita) cadastrado com lastContactAt recente não entra em noRecentContactCount', () {
      final people = [
        PersonEntry(
          id: 'person-recent-onboarded',
          name: 'Dona Neide (Revisita Antiga)',
          status: 'revisita',
          tags: '[]',
          firstContactAt: DateTime(2025, 1, 10), // primeiro contato há 1 ano
          lastContactAt: now.subtract(
            const Duration(days: 10),
          ), // última visita há 10 dias
          createdAt: now, // cadastrada hoje no app
          updatedAt: now,
          revision: 1,
        ),
        PersonEntry(
          id: 'person-forgotten',
          name: 'Seu Jorge',
          status: 'revisita',
          tags: '[]',
          firstContactAt: DateTime(2025, 1, 10),
          lastContactAt: now.subtract(
            const Duration(days: 45),
          ), // sem visita há mais de 30 dias
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
      ];

      final metrics = DashboardCalculator.calculate(
        studies: [],
        sessions: [],
        visits: [],
        appointments: [],
        activities: [],
        people: people,
        periodStart: periodStart,
        periodEnd: periodEnd,
        nowOverride: now,
      );

      // Apenas Seu Jorge deve contar em noRecentContactCount (> 30 dias)
      expect(metrics.noRecentContactCount, equals(1));
    });

    test('TC-COUNT-15: Atenção de inatividade respeita lastSessionAt fornecido e evita falso alarme no primeiro dia para estudos recém-cadastrados', () {
      final p1 = PersonEntry(
        id: 'p-joao',
        name: 'João',
        status: 'estudante',
        tags: '[]',
        firstContactAt: now,
        nextActionAt: now.add(const Duration(days: 7)),
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );
      final p2 = PersonEntry(
        id: 'p-ana',
        name: 'Ana',
        status: 'estudante',
        tags: '[]',
        firstContactAt: now,
        nextActionAt: now.add(const Duration(days: 7)),
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );
      final p3 = PersonEntry(
        id: 'p-pedro',
        name: 'Pedro',
        status: 'estudante',
        tags: '[]',
        firstContactAt: now,
        nextActionAt: now.add(const Duration(days: 7)),
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );

      final newlyOnboardedStudy = BibleStudyEntry(
        id: 'study-new-app-first-day',
        title: 'Estudo João Onboarded',
        ownerId: 'user-1',
        startedAt: DateTime(2026, 6, 1), // começou há 4 meses
        status: 'ativo',
        publicationId: 'lff-book',
        currentLesson: 12,
        currentParagraph: 1,
        language: 'pt',
        frequency: 'semanal',
        createdAt: now, // cadastrado hoje no app!
        updatedAt: now,
        revision: 1,
      );

      final studyWithRecentSession = BibleStudyEntry(
        id: 'study-recent-last-session',
        title: 'Estudo Ana',
        ownerId: 'user-1',
        startedAt: DateTime(2026, 6, 1),
        lastSessionAt: now.subtract(
          const Duration(days: 7),
        ), // última sessão há 7 dias
        status: 'ativo',
        publicationId: 'lff-book',
        currentLesson: 15,
        currentParagraph: 2,
        language: 'pt',
        frequency: 'semanal',
        createdAt: now.subtract(const Duration(days: 60)),
        updatedAt: now,
        revision: 1,
      );

      final oldAbandonedStudy = BibleStudyEntry(
        id: 'study-abandoned',
        title: 'Estudo Abandonado Pedro',
        ownerId: 'user-1',
        startedAt: DateTime(2026, 1, 1),
        lastSessionAt: now.subtract(
          const Duration(days: 40),
        ), // sem sessão há 40 dias
        status: 'ativo',
        publicationId: 'lff-book',
        currentLesson: 5,
        currentParagraph: 1,
        language: 'pt',
        frequency: 'semanal',
        createdAt: now.subtract(const Duration(days: 100)),
        updatedAt: now,
        revision: 1,
      );

      final participants = [
        StudyParticipantEntry(
          id: 'sp-1',
          studyId: newlyOnboardedStudy.id,
          personId: p1.id,
          isPrimary: true,
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
        StudyParticipantEntry(
          id: 'sp-2',
          studyId: studyWithRecentSession.id,
          personId: p2.id,
          isPrimary: true,
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
        StudyParticipantEntry(
          id: 'sp-3',
          studyId: oldAbandonedStudy.id,
          personId: p3.id,
          isPrimary: true,
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
      ];

      final attentionItems = DashboardCalculator.getAttentionItems(
        people: [p1, p2, p3],
        studies: [
          newlyOnboardedStudy,
          studyWithRecentSession,
          oldAbandonedStudy,
        ],
        participants: participants,
        appointments: [],
        nowOverride: now,
      );

      // newlyOnboardedStudy NÃO deve gerar alerta falso de inatividade porque foi criado hoje (primeiro uso do app)
      expect(
        attentionItems.any(
          (item) =>
              item.personName == 'João' && item.category == 'inactive_study',
        ),
        isFalse,
      );

      // studyWithRecentSession NÃO deve gerar alerta de inatividade pois teve sessão há 7 dias
      expect(
        attentionItems.any(
          (item) =>
              item.personName == 'Ana' && item.category == 'inactive_study',
        ),
        isFalse,
      );

      // oldAbandonedStudy DEVE gerar alerta de inatividade (> 14 dias sem sessão)
      expect(
        attentionItems.any(
          (item) =>
              item.personName == 'Pedro' && item.category == 'inactive_study',
        ),
        isTrue,
      );
    });

    test('TC-COUNT-16: Revisita onboardada com lastContactAt no período conta em heldVisitsCount sem duplicar se já existir visita', () {
      final p1 = PersonEntry(
        id: 'p-revisita-onboarded',
        name: 'Carlos Oliveira',
        status: 'revisita',
        tags: '[]',
        firstContactAt: DateTime(2026, 5, 10),
        lastContactAt: DateTime(2026, 10, 20), // no período de outubro
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );

      final p2 = PersonEntry(
        id: 'p-revisita-com-visita-gravada',
        name: 'Maria Visita',
        status: 'revisita',
        tags: '[]',
        firstContactAt: DateTime(2026, 5, 10),
        lastContactAt: DateTime(2026, 10, 22),
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );

      final loggedVisit = VisitEntry(
        id: 'v-1',
        personId: p2.id,
        dateTimeField: DateTime(2026, 10, 22, 15, 0),
        contactType: 'revisita',
        result: 'Conversa bíblica',
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );

      final metrics = DashboardCalculator.calculate(
        studies: [],
        sessions: [],
        visits: [loggedVisit],
        appointments: [],
        activities: [],
        people: [p1, p2],
        periodStart: periodStart, // 2026-10-01
        periodEnd: periodEnd, // 2026-10-31
        nowOverride: now,
      );

      // Deve contar 1 visita da tabela visits (p2) + 1 revisita onboardada sem linha avulsa (p1) = 2 revisitas
      expect(metrics.heldVisitsCount, equals(2));
    });

    test('TC-COUNT-17: Estudo bíblico com lastSessionAt no período conta em heldSessionsCount e assistência mesmo sem linha em sessions', () {
      final study = BibleStudyEntry(
        id: 'study-hist-session',
        title: 'Estudo Mateus Histórico',
        ownerId: 'u1',
        startedAt: DateTime(2026, 6, 1),
        lastSessionAt: DateTime(2026, 10, 18, 14, 0), // sessão em outubro
        status: 'ativo',
        publicationId: 'lff-book',
        currentLesson: 16,
        currentParagraph: 2,
        language: 'pt',
        frequency: 'semanal',
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );

      final part = StudyParticipantEntry(
        id: 'sp-mateus',
        studyId: study.id,
        personId: 'p-mateus',
        isPrimary: true,
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );

      final metrics = DashboardCalculator.calculate(
        studies: [study],
        sessions: [], // nenhuma linha em sessions
        visits: [],
        appointments: [],
        activities: [],
        participants: [part],
        periodStart: periodStart,
        periodEnd: periodEnd,
        nowOverride: now,
      );

      expect(metrics.activeStudiesCount, equals(1));
      expect(metrics.heldSessionsCount, equals(1));
      expect(metrics.totalStudyAttendance, equals(1));
      expect(metrics.averageAttendancePerStudy, equals(1.0));
    });

    test('TC-COUNT-18: Estudo pausado que teve sessão no mês corrente conta em activeStudiesCount para o relatório do mês', () {
      final study = BibleStudyEntry(
        id: 'study-paused-with-session',
        title: 'Estudo Pausado com Sessão em Outubro',
        ownerId: 'u1',
        startedAt: DateTime(2026, 4, 1),
        lastSessionAt: DateTime(
          2026,
          10,
          5,
          10,
          0,
        ), // sessão no início de outubro
        status: 'pausado', // pausado depois
        publicationId: 'lff-book',
        currentLesson: 12,
        currentParagraph: 1,
        language: 'pt',
        frequency: 'semanal',
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );

      final metrics = DashboardCalculator.calculate(
        studies: [study],
        sessions: [],
        visits: [],
        appointments: [],
        activities: [],
        periodStart: periodStart,
        periodEnd: periodEnd,
        nowOverride: now,
      );

      // Segundo regras teocráticas, como teve sessão no mês, conta nos estudos dirigidos no mês
      expect(metrics.activeStudiesCount, equals(1));
      expect(metrics.heldSessionsCount, equals(1));
    });

    test('TC-COUNT-19: Estudante com estudo ativo cuja última sessão foi recente não entra em noRecentContactCount', () {
      final student = PersonEntry(
        id: 'p-active-student',
        name: 'Lucas Estudante',
        status: 'estudo',
        tags: '[]',
        firstContactAt: DateTime(2026, 1, 10),
        lastContactAt: null, // não preenchido em people
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );

      final study = BibleStudyEntry(
        id: 'study-lucas',
        title: 'Estudo Lucas',
        ownerId: 'u1',
        startedAt: DateTime(2026, 1, 10),
        lastSessionAt: now.subtract(
          const Duration(days: 8),
        ), // sessão há 8 dias
        status: 'ativo',
        publicationId: 'lff-book',
        currentLesson: 22,
        currentParagraph: 3,
        language: 'pt',
        frequency: 'semanal',
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );

      final part = StudyParticipantEntry(
        id: 'sp-lucas',
        studyId: study.id,
        personId: student.id,
        isPrimary: true,
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );

      final metrics = DashboardCalculator.calculate(
        studies: [study],
        sessions: [],
        visits: [],
        appointments: [],
        activities: [],
        people: [student],
        participants: [part],
        periodStart: periodStart,
        periodEnd: periodEnd,
        nowOverride: now,
      );

      // Não deve contar como sem contato recente (> 30 dias) pois teve sessão há 8 dias
      expect(metrics.noRecentContactCount, equals(0));
    });

    test('TC-COUNT-20: Contato com compromisso futuro na agenda NÃO é sinalizado com no_next_action em getAttentionItems', () {
      final person = PersonEntry(
        id: 'p-scheduled',
        name: 'Gabriel Agendado',
        status: 'interessado',
        tags: '[]',
        firstContactAt: now,
        nextActionAt: null, // sem nota em person
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );

      final futureAppt = AppointmentEntry(
        id: 'appt-gabriel',
        personId: person.id,
        title: 'Revisita Gabriel',
        startTime: now.add(
          const Duration(days: 2),
        ), // compromisso daqui a 2 dias
        endTime: now.add(const Duration(days: 2, hours: 1)),
        durationMinutes: 60,
        status: 'confirmado',
        isProvisional: false,
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );

      final attentionItems = DashboardCalculator.getAttentionItems(
        people: [person],
        studies: [],
        participants: [],
        appointments: [futureAppt],
        nowOverride: now,
      );

      // Não deve conter item na categoria no_next_action pois há compromisso confirmado na agenda
      expect(
        attentionItems.any(
          (item) =>
              item.personId == person.id && item.category == 'no_next_action',
        ),
        isFalse,
      );
    });
  });
}
