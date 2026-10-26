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
  });
}
