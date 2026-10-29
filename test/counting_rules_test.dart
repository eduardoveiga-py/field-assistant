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

    test('TC-COUNT-05: Tentativa sem contato NÃO conta como conversa realizada', () {
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
    });

    test('TC-COUNT-06: Contagem de Ações Pendentes e Contatos sem Contato Recente (> 30 dias)', () {
      final people = [
        PersonEntry(
          id: 'p-pending-action',
          name: 'João Ação Pendente',
          firstContactAt: now.subtract(const Duration(days: 40)),
          status: 'interessado',
          tags: '[]',
          nextActionAt: now.subtract(const Duration(hours: 2)), // Ação vencida há 2 horas
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
          lastContactAt: now.subtract(const Duration(days: 35)), // 35 dias sem contato
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

      expect(metrics.totalPlacements, equals(4)); // 3 de atividades + 1 de visita
      expect(metrics.totalVideos, equals(2));
    });
  });
}
