import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/settings/app_settings_manager.dart';
import 'package:ministerio_pessoal/appointments/availability_engine.dart';
import 'package:ministerio_pessoal/dashboard/counting_rules.dart';
import 'e2e_contracts.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('E2E Tier 4: Real-World Field Ministry Scenarios', () {
    late AppDatabase db;
    late AppRepository repo;
    late AppSettingsManager settings;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
      settings = AppSettingsManager(db);
    });

    tearDown(() async {
      await db.close();
    });

    // ========================================================================
    // Scenario 1: Full Morning Field Service Workflow
    // ========================================================================
    test('TC-SCENARIO-01: Full Morning Field Service Workflow from pace setup to visit logging and timer completion', () async {
      final saturday = DateTime(2026, 10, 24, 8, 30);

      // 1. Configuração do Ritmo de Pioneiro (R2)
      await settings.setString('pioneer_goal_hours', '50.0');
      await settings.setString('pioneer_weekdays', '2,4,6'); // Terça, Quinta, Sábado

      const goalHours = 50.0;
      final designatedDays = [2, 4, 6];
      double completedHours = 38.0;

      final initialPace = PioneerPaceCalculator.calculate(
        goalHours: goalHours,
        designatedWeekdays: designatedDays,
        completedHours: completedHours,
        currentDate: saturday,
      );

      expect(initialPace.remainingHours, equals(12.0));
      expect(initialPace.isGoalReached, isFalse);

      // 2. Revisão de Sementes Recentes antes de sair (R3)
      final recentPerson = await repo.createPerson(
        name: 'Carlos Oliveira',
        firstContactAt: saturday.subtract(const Duration(days: 3)),
        status: 'interessado',
        latitude: -23.5510,
        longitude: -46.6340,
        generalNotes: 'Trabalha com marcenaria, tem 2 filhos',
      );

      final isSeed = RecentSeedsHelper.isRecentSeed(
        person: recentPerson,
        visits: [],
        nowOverride: saturday,
      );
      expect(isSeed, isTrue);
      expect(RecentSeedsHelper.getElapsedText(firstContactAt: recentPerson.firstContactAt, nowOverride: saturday), equals('há 3 dias'));

      // 3. Chegada à porta e Briefing na Porta (R1)
      final study = await repo.createStudy(
        title: 'Estudo Carlos',
        participantPersonIds: [recentPerson.id],
        publicationId: 'lff-book',
        language: 'pt',
        currentLesson: 2,
        currentParagraph: 1,
        learningGoals: 'Conhecer quem é Jeová',
      );

      final briefing = DoorstepBriefingHelper.build(
        person: recentPerson,
        linkedStudy: study,
      );

      expect(briefing.lessonAndPoint, equals('Lição 02, Ponto 1'));
      expect(briefing.jwLibraryUri, isNotNull);
      expect(briefing.spiritualGoal, equals('Conhecer quem é Jeová'));
      expect(briefing.empathyNote, equals('Trabalha com marcenaria, tem 2 filhos'));

      // 4. Execução e registro da visita no banco
      final visit = await repo.createVisit(
        personId: recentPerson.id,
        dateTime: saturday.add(const Duration(minutes: 30)),
        contactType: 'revisita',
        result: 'conversa_agradavel',
        notes: 'Carlos gostou da explicação sobre o nome de Deus',
        expressedQuestion: 'Por que muitos não usam o nome de Deus?',
        nextStep: 'Responder na Lição 2, Ponto 2',
      );
      expect(visit.id, isNotEmpty);

      // 5. Finalização da sessão de campo com cronômetro (R5 & R2)
      final sessionEnd = saturday.add(const Duration(hours: 2, minutes: 30));
      final timerState = AutoCorrectiveTimerLogic.evaluate(
        isRunning: true,
        startedAt: saturday,
        accumulatedDuration: Duration.zero,
        nowOverride: sessionEnd,
      );

      expect(timerState.shouldShowWarning, isFalse);
      expect(timerState.elapsedDuration, equals(const Duration(hours: 2, minutes: 30)));

      // Registro da atividade e atualização do ritmo
      await repo.createActivityRecord(
        date: saturday,
        durationSeconds: timerState.elapsedDuration.inSeconds,
        modality: 'campo',
      );

      completedHours += 2.5;
      final updatedPace = PioneerPaceCalculator.calculate(
        goalHours: goalHours,
        designatedWeekdays: designatedDays,
        completedHours: completedHours,
        currentDate: saturday,
      );

      expect(updatedPace.completedHours, equals(40.5));
      expect(updatedPace.remainingHours, equals(9.5));
      expect(updatedPace.idealPacePerOuting < initialPace.idealPacePerOuting, isTrue);
    });

    // ========================================================================
    // Scenario 2: Student Cancellation with Plan B and Reschedule
    // ========================================================================
    test('TC-SCENARIO-02: Student Cancellation with Plan B recommendation, doorstep briefing and conflict-free reschedule', () async {
      final saturday = DateTime(2026, 10, 24, 10, 0);

      // 1. Agendamento com o estudante original
      final studentMariana = await repo.createPerson(
        name: 'Mariana Silva',
        status: 'estudo',
      );

      final originalAppt = await repo.createAppointment(
        personId: studentMariana.id,
        title: 'Estudo Bíblico Mariana',
        startTime: saturday,
        endTime: saturday.add(const Duration(minutes: 60)),
        status: 'confirmado',
      );

      // 2. Estudante cancela o estudo às 09:55
      await (db.update(db.appointments)..where((t) => t.id.equals(originalAppt.id)))
          .write(const AppointmentsCompanion(status: Value('cancelado')));

      final cancelledAppt = await repo.getAppointmentById(originalAppt.id);
      expect(cancelledAppt!.status, equals('cancelado'));

      // 3. Acionamento do Plano B Imediato com GPS (R4)
      final planBCandidate = await repo.createPerson(
        name: 'Cláudio Santos',
        status: 'revisita',
        latitude: -23.5515,
        longitude: -46.6345,
        preferredSchedule: 'Sábado de manhã',
        nextActionNote: 'Mostrar vídeo sobre o Reino',
      );

      final suggestions = await PlanBRecommender.getSuggestions(
        cancelledPerson: studentMariana,
        allPeople: [studentMariana, planBCandidate],
        allVisits: [],
        currentLat: -23.5505,
        currentLng: -46.6335,
        targetDateTime: saturday,
      );

      expect(suggestions.isNotEmpty, isTrue);
      expect(suggestions.first.person.id, equals(planBCandidate.id));
      expect(suggestions.first.reason, contains('distância'));
      expect(suggestions.first.reason.toLowerCase(), contains('sábado'));

      // 4. Carregamento instantâneo do Briefing do Plano B (R1)
      final briefingPlanB = DoorstepBriefingHelper.build(
        person: planBCandidate,
      );
      expect(briefingPlanB.spiritualGoal, equals('Mostrar vídeo sobre o Reino'));

      // Realiza a visita substituta
      await repo.createVisit(
        personId: planBCandidate.id,
        dateTime: saturday.add(const Duration(minutes: 15)),
        contactType: 'revisita',
        result: 'conversa_agradavel',
        notes: 'Cláudio estava em casa e assistiu ao vídeo',
      );

      // 5. Reagendamento do estudo de Mariana para Terça às 15:00 sem conflitos
      final rescheduleTime = DateTime(2026, 10, 27, 15, 0);
      final allAppts = await repo.getAllAppointments();

      final availability = AvailabilityEngine.checkAvailability(
        startTime: rescheduleTime,
        durationMinutes: 60,
        existingAppointments: allAppts,
      );

      expect(availability.isAvailable, isTrue);
      expect(availability.conflictingAppointments, isEmpty);

      // Criação do novo compromisso reagendado
      final rescheduledAppt = await repo.createAppointment(
        personId: studentMariana.id,
        title: 'Estudo Mariana (Reagendado)',
        startTime: rescheduleTime,
        endTime: rescheduleTime.add(const Duration(minutes: 60)),
        status: 'confirmado',
        previousAppointmentId: originalAppt.id,
      );

      expect(rescheduledAppt.previousAppointmentId, equals(originalAppt.id));
    });

    // ========================================================================
    // Scenario 3: Forgotten Timer Recovery & Ministry Report Integrity
    // ========================================================================
    test('TC-SCENARIO-03: Forgotten Timer Recovery prevents report distortion and maintains accurate monthly dashboard metrics', () async {
      final morningStart = DateTime(2026, 10, 20, 8, 30);
      final morningLastHeartbeat = DateTime(2026, 10, 20, 11, 30); // 3h de campo
      final eveningReopen = DateTime(2026, 10, 20, 19, 30); // Reabriu 11h depois

      // 1. Cronômetro rodando e esquecido (R5)
      final timerEvaluation = AutoCorrectiveTimerLogic.evaluate(
        isRunning: true,
        startedAt: morningStart,
        accumulatedDuration: Duration.zero,
        lastHeartbeat: morningLastHeartbeat,
        nowOverride: eveningReopen,
      );

      expect(timerEvaluation.shouldShowWarning, isTrue);
      expect(timerEvaluation.warningReason, equals('reopened_inactive'));
      // Duração total inflada foi de 11h
      expect(timerEvaluation.elapsedDuration, equals(const Duration(hours: 11)));
      // Ajuste inteligente sugere o tempo real de uso ativo (3h)
      expect(timerEvaluation.suggestedAdjustment, equals(const Duration(hours: 3)));

      // 2. Usuário aceita o ajuste de 3h e persiste a atividade real
      await repo.createActivityRecord(
        date: morningStart,
        durationSeconds: timerEvaluation.suggestedAdjustment.inSeconds, // 10.800s (3 horas)
        modality: 'campo',
        notes: 'Ajustado de 11h para 3h pelo Cronômetro Auto-Corretivo',
      );

      // 3. Verificação de integridade do Relatório do Ministério (DashboardCalculator)
      final allActivities = await repo.getAllActivities();
      expect(allActivities.length, equals(1));

      final metrics = DashboardCalculator.calculate(
        studies: [],
        sessions: [],
        visits: [],
        appointments: [],
        activities: allActivities,
        periodStart: DateTime(2026, 10, 1),
        periodEnd: DateTime(2026, 10, 31, 23, 59, 59),
        nowOverride: eveningReopen,
      );

      // O relatório oficial deve conter exatamente 3 horas (10.800 segundos), NÃO 39.600 segundos (11h)
      expect(metrics.totalActivitySeconds, equals(10800));
      expect(metrics.totalActivitySeconds / 3600.0, equals(3.0));
    });

    // ========================================================================
    // Scenario 4: End-of-Month Pioneer Sprint
    // ========================================================================
    test('TC-SCENARIO-04: End-of-Month Pioneer Sprint successfully computes final push and celebrates goal completion', () async {
      // Data: 30 de Outubro de 2026 (Sexta-feira)
      final sprintDate = DateTime(2026, 10, 30);
      const double goalHours = 50.0;
      final designatedDays = [6]; // Apenas sábados (Outubro 31 é o único restante)
      double completedHours = 46.0;

      // 1. Cálculo da meta na véspera do encerramento do mês
      final sprintPace = PioneerPaceCalculator.calculate(
        goalHours: goalHours,
        designatedWeekdays: designatedDays,
        completedHours: completedHours,
        currentDate: sprintDate,
      );

      expect(sprintPace.remainingOutings, equals(1)); // Exatamente 1 saída restante (dia 31)
      expect(sprintPace.remainingHours, equals(4.0)); // Faltam 4h
      expect(sprintPace.idealPacePerOuting, equals(const Duration(hours: 4)));
      expect(sprintPace.isGoalReached, isFalse);
      expect(sprintPace.formattedPaceText, equals('Faltam 4h em 1 saídas. Seu ritmo ideal é de 4h00m por saída'));

      // 2. Última saída realizada no dia 31 (Sábado)
      final finalOutingStart = DateTime(2026, 10, 31, 8, 0);
      final finalOutingEnd = DateTime(2026, 10, 31, 12, 0); // Exatas 4 horas

      // Avaliação do cronômetro: exatamente 4h sem alerta indevido (limite respeitado)
      final timerState = AutoCorrectiveTimerLogic.evaluate(
        isRunning: true,
        startedAt: finalOutingStart,
        accumulatedDuration: Duration.zero,
        nowOverride: finalOutingEnd,
      );
      expect(timerState.shouldShowWarning, isFalse);
      expect(timerState.elapsedDuration, equals(const Duration(hours: 4)));

      // 3. Salva a atividade final no banco de dados
      await repo.createActivityRecord(
        date: finalOutingStart,
        durationSeconds: const Duration(hours: 4).inSeconds,
        modality: 'campo',
        notes: 'Última saída do mês de Outubro!',
      );

      completedHours += 4.0;
      expect(completedHours, equals(50.0));

      // 4. Verificação do estado de celebração da meta de pioneiro
      final finalPace = PioneerPaceCalculator.calculate(
        goalHours: goalHours,
        designatedWeekdays: designatedDays,
        completedHours: completedHours,
        currentDate: DateTime(2026, 10, 31),
      );

      expect(finalPace.completedHours, equals(50.0));
      expect(finalPace.remainingHours, equals(0.0));
      expect(finalPace.isGoalReached, isTrue);
      expect(finalPace.formattedPaceText, equals('Meta atingida! Parabéns pelo empenho no ministério.'));
    });
  });
}
