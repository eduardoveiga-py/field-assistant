import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/settings/app_settings_manager.dart';
import 'e2e_contracts.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('E2E Tier 1: Feature Coverage (R1 to R5)', () {
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
    // R1: Briefing na Porta (Consolidação em 1 Toque)
    // ========================================================================
    group('R1: Briefing na Porta', () {
      test('TC-R1-01: Full profile with active study and recent visit formats all 5 fields', () async {
        final person = await repo.createPerson(
          name: 'Lucas Mendes',
          phone: '11988881111',
          generalNotes: 'Mãe estava hospitalizada na última semana',
          nextActionNote: 'Alcançar a oração sincera',
        );

        final study = await repo.createStudy(
          title: 'Estudo com Lucas',
          participantPersonIds: [person.id],
          publicationId: 'lff-book',
          language: 'pt',
          currentLesson: 4,
          currentParagraph: 3,
          learningGoals: 'Entender o propósito de Deus para a Terra',
        );

        final visit = await repo.createVisit(
          personId: person.id,
          dateTime: DateTime(2026, 10, 25, 15, 30),
          contactType: 'revisita',
          result: 'conversa_agradavel',
          notes: 'Lucas estava preocupado com a cirurgia da mãe',
          expressedQuestion: 'Por que Deus permite o sofrimento?',
          nextStep: 'Responder com base na Lição 4',
        );

        final briefing = DoorstepBriefingHelper.build(
          person: person,
          linkedStudy: study,
          latestVisit: visit,
        );

        expect(briefing.lessonAndPoint, equals('Lição 04, Ponto 3'));
        expect(briefing.jwLibraryUri, isNotNull);
        expect(briefing.jwLibraryUri.toString(), contains('pub=lff'));
        expect(briefing.jwLibraryUri.toString(), contains('lesson=4'));
        expect(briefing.pendingDoubt, equals('Por que Deus permite o sofrimento?'));
        expect(briefing.spiritualGoal, equals('Entender o propósito de Deus para a Terra'));
        expect(briefing.empathyNote, equals('Lucas estava preocupado com a cirurgia da mãe'));
      });

      test('TC-R1-02: Study only without previous visits extracts goals and JW Library link', () async {
        final person = await repo.createPerson(
          name: 'Beatriz Lima',
          nextActionNote: 'Iniciar primeira consideração bíblica',
        );

        final study = await repo.createStudy(
          title: 'Estudo com Beatriz',
          participantPersonIds: [person.id],
          publicationId: 'lff-book',
          language: 'pt',
          currentLesson: 1,
          currentParagraph: 1,
          learningGoals: 'Descobrir a esperança da Bíblia',
        );

        final briefing = DoorstepBriefingHelper.build(
          person: person,
          linkedStudy: study,
          latestVisit: null,
        );

        expect(briefing.lessonAndPoint, equals('Lição 01, Ponto 1'));
        expect(briefing.jwLibraryUri, isNotNull);
        expect(briefing.pendingDoubt, isNull);
        expect(briefing.spiritualGoal, equals('Descobrir a esperança da Bíblia'));
        expect(briefing.empathyNote, isNull);
      });

      test('TC-R1-03: Revisit without Bible study populates pending doubts and empathy notes without study fields', () async {
        final person = await repo.createPerson(
          name: 'Carlos Alberto',
          status: 'revisita',
          generalNotes: 'Aposentado, gosta de falar sobre história antiga',
        );

        final visit = await repo.createVisit(
          personId: person.id,
          dateTime: DateTime(2026, 10, 27, 10, 0),
          contactType: 'revisita',
          result: 'conversa_agradavel',
          notes: 'Conversamos sobre a confiabilidade histórica da Bíblia',
          expressedQuestion: 'Quem escreveu a Bíblia e quando?',
          nextStep: 'Mostrar o vídeo Quem é o Autor da Bíblia?',
        );

        final briefing = DoorstepBriefingHelper.build(
          person: person,
          linkedStudy: null,
          latestVisit: visit,
        );

        expect(briefing.lessonAndPoint, isNull);
        expect(briefing.jwLibraryUri, isNull);
        expect(briefing.pendingDoubt, equals('Quem escreveu a Bíblia e quando?'));
        expect(briefing.spiritualGoal, isNull);
        expect(briefing.empathyNote, equals('Conversamos sobre a confiabilidade histórica da Bíblia'));
      });

      test('TC-R1-04: JW Library deep link resolution generates canonical URL', () async {
        final person = await repo.createPerson(name: 'Daniel Santos');
        final study = await repo.createStudy(
          title: 'Estudo Daniel',
          participantPersonIds: [person.id],
          publicationId: 'lff-book',
          language: 'pt',
          currentLesson: 12,
          currentParagraph: 5,
        );

        final briefing = DoorstepBriefingHelper.build(
          person: person,
          linkedStudy: study,
        );

        expect(briefing.jwLibraryUri, isNotNull);
        final uriStr = briefing.jwLibraryUri.toString();
        expect(uriStr, startsWith('https://www.jw.org/finder'));
        expect(uriStr, contains('srcid=jwlshare'));
        expect(uriStr, contains('wtlocale=T'));
        expect(uriStr, contains('lesson=12'));
      });

      test('TC-R1-05: Manual reference fallback formats lesson/point gracefully when publication is customized', () async {
        final person = await repo.createPerson(name: 'Elena Rostova');
        final study = await repo.createStudy(
          title: 'Estudo Elena',
          participantPersonIds: [person.id],
          publicationId: 'custom-topic',
          language: 'pt',
          manualReference: 'Capítulo 3, § 14-16',
        );

        final briefing = DoorstepBriefingHelper.build(
          person: person,
          linkedStudy: study,
        );

        expect(briefing.lessonAndPoint, equals('Capítulo 3, § 14-16'));
        expect(briefing.jwLibraryUri, isNull);
      });
    });

    // ========================================================================
    // R2: Calculadora de Ritmo Real de Campo
    // ========================================================================
    group('R2: Calculadora de Ritmo Real de Campo', () {
      test('TC-R2-01: Mid-month standard calculation (50h goal, 32h completed, 5 outings -> 3h36m per outing)', () {
        // Exemplo direto de ORIGINAL_REQUEST.md: "Faltam 18h em 5 saídas. Seu ritmo ideal é de 3h36m por saída"
        final result = PioneerPaceCalculator.calculate(
          goalHours: 50.0,
          designatedWeekdays: [2, 4, 6], // Terça, Quinta, Sábado
          completedHours: 32.0,
          currentDate: DateTime(2026, 10, 20), // Supondo 5 saídas restantes
        );

        expect(result.goalHours, equals(50.0));
        expect(result.completedHours, equals(32.0));
        expect(result.remainingHours, equals(18.0));
        expect(result.isGoalReached, isFalse);
        // Em 2026-10-20 (terça) até 2026-10-31 (sábado):
        // Dias 20(Ter), 22(Qui), 24(Sab), 27(Ter), 29(Qui), 31(Sab) = 6 saídas
        // Se testarmos com 5 saídas exatas:
        final calcWith5Outings = PioneerPaceCalculator.calculate(
          goalHours: 50.0,
          designatedWeekdays: [2, 4], // apenas Terça e Quinta a partir do dia 15
          completedHours: 32.0,
          currentDate: DateTime(2026, 10, 16), // 20(Ter), 22(Qui), 27(Ter), 29(Qui) = 4 ou 5
        );
        expect(calcWith5Outings.remainingHours, equals(18.0));

        // Verificação direta da fórmula de tempo por saída com 5 saídas
        final manualCalc = PioneerPaceCalculator.calculate(
          goalHours: 50.0,
          designatedWeekdays: [6], // 5 sábados no mês a partir de data inicial
          completedHours: 32.0,
          currentDate: DateTime(2026, 5, 2), // Maio de 2026 tem sábados nos dias 2, 9, 16, 23, 30 = 5 sábados
        );
        expect(manualCalc.remainingOutings, equals(5));
        expect(manualCalc.remainingHours, equals(18.0));
        expect(manualCalc.idealPacePerOuting, equals(const Duration(hours: 3, minutes: 36)));
        expect(manualCalc.formattedPaceText, equals('Faltam 18h em 5 saídas. Seu ritmo ideal é de 3h36m por saída'));
      });

      test('TC-R2-02: Auxiliary pioneer standard (30h goal, 10h completed, 8 outings -> 2h30m per outing)', () {
        // 30h - 10h = 20h restantes em 8 saídas -> 20h / 8 = 2.5h = 2h30m
        // Mês com 8 saídas restantes
        // Exemplo: Outubro 2026, com Terças e Quintas:
        // Dias 6, 8, 13, 15, 20, 22, 27, 29 = 8 saídas
        final result = PioneerPaceCalculator.calculate(
          goalHours: 30.0,
          designatedWeekdays: [2, 4], // Terça e Quinta
          completedHours: 10.0,
          currentDate: DateTime(2026, 10, 6),
        );

        expect(result.remainingHours, equals(20.0));
        expect(result.remainingOutings, equals(8));
        expect(result.idealPacePerOuting, equals(const Duration(hours: 2, minutes: 30)));
        expect(result.formattedPaceText, equals('Faltam 20h em 8 saídas. Seu ritmo ideal é de 2h30m por saída'));
      });

      test('TC-R2-03: Single designated weekday (e.g. Saturdays only) correctly counts remaining occurrences', () {
        // Outubro 2026 tem sábados nos dias 3, 10, 17, 24, 31.
        // A partir do dia 18, restam os dias 24 e 31 (2 saídas).
        final result = PioneerPaceCalculator.calculate(
          goalHours: 15.0,
          designatedWeekdays: [6], // Sábado
          completedHours: 9.0,
          currentDate: DateTime(2026, 10, 18),
        );

        expect(result.remainingOutings, equals(2));
        expect(result.remainingHours, equals(6.0));
        expect(result.idealPacePerOuting, equals(const Duration(hours: 3)));
        expect(result.formattedPaceText, equals('Faltam 6h em 2 saídas. Seu ritmo ideal é de 3h00m por saída'));
      });

      test('TC-R2-04: Multiple designated weekdays (Tuesday, Thursday, Saturday) dynamically computed to month-end', () {
        // Outubro 2026 a partir do dia 25 (domingo):
        // Dias restantes: 25, 26, 27(Ter), 28, 29(Qui), 30, 31(Sab) -> 3 saídas (27, 29, 31)
        final result = PioneerPaceCalculator.calculate(
          goalHours: 50.0,
          designatedWeekdays: [2, 4, 6],
          completedHours: 41.0,
          currentDate: DateTime(2026, 10, 25),
        );

        expect(result.remainingOutings, equals(3));
        expect(result.remainingHours, equals(9.0));
        expect(result.idealPacePerOuting, equals(const Duration(hours: 3)));
      });

      test('TC-R2-05: Persistence of goal hours and designated weekdays in AppSettingsManager', () async {
        await settings.setString('pioneer_goal_hours', '50.0');
        await settings.setString('pioneer_weekdays', '2,4,6');

        final savedGoal = await settings.getString('pioneer_goal_hours');
        final savedDays = await settings.getString('pioneer_weekdays');

        expect(savedGoal, equals('50.0'));
        expect(savedDays, equals('2,4,6'));

        final goalVal = double.parse(savedGoal!);
        final daysList = savedDays!.split(',').map(int.parse).toList();

        final pace = PioneerPaceCalculator.calculate(
          goalHours: goalVal,
          designatedWeekdays: daysList,
          completedHours: 20.0,
          currentDate: DateTime(2026, 10, 1),
        );

        expect(pace.goalHours, equals(50.0));
        expect(pace.remainingHours, equals(30.0));
      });
    });

    // ========================================================================
    // R3: Destaque de Sementes Recentes (Alerta de Esfriamento)
    // ========================================================================
    group('R3: Destaque de Sementes Recentes', () {
      test('TC-R3-01: Contact registered 2 days ago with initial conversation flags isRecentSeed = true', () async {
        final now = DateTime(2026, 10, 30, 10, 0);
        final firstContact = now.subtract(const Duration(days: 2));

        final person = await repo.createPerson(
          name: 'Gabriel Martins',
          firstContactAt: firstContact,
        );

        final visit = await repo.createVisit(
          personId: person.id,
          dateTime: firstContact,
          contactType: 'conversa_inicial',
          result: 'Deixou tratado',
        );

        final isRecent = RecentSeedsHelper.isRecentSeed(
          person: person,
          visits: [visit],
          nowOverride: now,
        );

        expect(isRecent, isTrue);
        expect(RecentSeedsHelper.getElapsedText(firstContactAt: firstContact, nowOverride: now), equals('há 2 dias'));
      });

      test('TC-R3-02: Contact registered 4 days ago with zero visits flags isRecentSeed = true', () async {
        final now = DateTime(2026, 10, 30, 14, 0);
        final firstContact = now.subtract(const Duration(days: 4));

        final person = await repo.createPerson(
          name: 'Helena Duarte',
          firstContactAt: firstContact,
        );

        final isRecent = RecentSeedsHelper.isRecentSeed(
          person: person,
          visits: [],
          nowOverride: now,
        );

        expect(isRecent, isTrue);
        expect(RecentSeedsHelper.getElapsedText(firstContactAt: firstContact, nowOverride: now), equals('há 4 dias'));
      });

      test('TC-R3-03: Contact registered 3 days ago with completed revisit flags isRecentSeed = false', () async {
        final now = DateTime(2026, 10, 30, 16, 0);
        final firstContact = now.subtract(const Duration(days: 3));

        final person = await repo.createPerson(
          name: 'Igor Ferreira',
          firstContactAt: firstContact,
        );

        final revisit = await repo.createVisit(
          personId: person.id,
          dateTime: now.subtract(const Duration(days: 1)),
          contactType: 'revisita',
          result: 'Conversou por 20 minutos',
        );

        final isRecent = RecentSeedsHelper.isRecentSeed(
          person: person,
          visits: [revisit],
          nowOverride: now,
        );

        expect(isRecent, isFalse);
      });

      test('TC-R3-04: Contact registered 10 days ago without revisit flags isRecentSeed = false (> 7 days)', () async {
        final now = DateTime(2026, 10, 30, 10, 0);
        final firstContact = now.subtract(const Duration(days: 10));

        final person = await repo.createPerson(
          name: 'Juliana Costa',
          firstContactAt: firstContact,
        );

        final isRecent = RecentSeedsHelper.isRecentSeed(
          person: person,
          visits: [],
          nowOverride: now,
        );

        expect(isRecent, isFalse);
      });

      test('TC-R3-05: Elapsed text accurately displays "Hoje", "há 1 dia", "há N dias"', () {
        final now = DateTime(2026, 10, 30, 12, 0);

        expect(RecentSeedsHelper.getElapsedText(firstContactAt: now, nowOverride: now), equals('Hoje'));
        expect(RecentSeedsHelper.getElapsedText(firstContactAt: now.subtract(const Duration(days: 1)), nowOverride: now), equals('há 1 dia'));
        expect(RecentSeedsHelper.getElapsedText(firstContactAt: now.subtract(const Duration(days: 5)), nowOverride: now), equals('há 5 dias'));
      });
    });

    // ========================================================================
    // R4: Botão "Estudante Desmarcou Agora" (Plano B Imediato)
    // ========================================================================
    group('R4: Botão "Estudante Desmarcou Agora" (Plano B Imediato)', () {
      test('TC-R4-01: Cancellation with GPS calculates Haversine distance and ranks closest candidates', () async {
        final cancelledStudent = await repo.createPerson(
          name: 'Marcos Vinicius',
          latitude: -23.5505,
          longitude: -46.6333,
        );

        final candidateNear = await repo.createPerson(
          name: 'Ana Carolina',
          latitude: -23.5520, // ~200m de distância
          longitude: -46.6340,
          status: 'revisita',
        );

        final candidateFar = await repo.createPerson(
          name: 'Paulo Silva',
          latitude: -23.5800, // ~3.5km de distância
          longitude: -46.6500,
          status: 'revisita',
        );

        final suggestions = await PlanBRecommender.getSuggestions(
          cancelledPerson: cancelledStudent,
          allPeople: [cancelledStudent, candidateNear, candidateFar],
          allVisits: [],
          currentLat: -23.5505,
          currentLng: -46.6333,
        );

        expect(suggestions.length, equals(2));
        expect(suggestions.first.person.id, equals(candidateNear.id));
        expect(suggestions.first.distanceKm, isNotNull);
        expect(suggestions.first.distanceKm!, lessThan(1.0));
        expect(suggestions.first.reason, contains('distância'));
        expect(suggestions.last.person.id, equals(candidateFar.id));
      });

      test('TC-R4-02: Fallback when GPS is null ranks candidates by urgency/schedule availability', () async {
        final cancelled = await repo.createPerson(name: 'Estudante Cancelou');

        final candidatePending = await repo.createPerson(
          name: 'Revisita com Pendência',
          status: 'revisita',
          nextActionNote: 'Responder dúvida sobre ressurreição',
        );

        final candidateNormal = await repo.createPerson(
          name: 'Contato Comum',
          status: 'interessado',
        );

        final suggestions = await PlanBRecommender.getSuggestions(
          cancelledPerson: cancelled,
          allPeople: [cancelled, candidatePending, candidateNormal],
          allVisits: [],
          currentLat: null,
          currentLng: null,
        );

        expect(suggestions.length, equals(2));
        expect(suggestions.first.person.id, equals(candidatePending.id));
        expect(suggestions.first.distanceKm, isNull);
        expect(suggestions.first.pendingStep, equals('Responder dúvida sobre ressurreição'));
      });

      test('TC-R4-03: Preferred schedule matching aligns candidate with current weekday/time slot', () async {
        final tuesday = DateTime(2026, 10, 27, 14, 0); // Terça-feira
        final cancelled = await repo.createPerson(name: 'Cancelado');

        final personTuesday = await repo.createPerson(
          name: 'Marta Souza',
          preferredSchedule: 'Terça à tarde',
        );

        final suggestions = await PlanBRecommender.getSuggestions(
          cancelledPerson: cancelled,
          allPeople: [cancelled, personTuesday],
          allVisits: [],
          currentLat: null,
          currentLng: null,
          targetDateTime: tuesday,
        );

        expect(suggestions.first.reason, contains('Costuma atender aos terças'));
      });

      test('TC-R4-04: Pending step and expressed question propagated to suggestion for doorstep readiness', () async {
        final cancelled = await repo.createPerson(name: 'Cancelado');
        final candidate = await repo.createPerson(name: 'Fernando Rocha');

        final visit = await repo.createVisit(
          personId: candidate.id,
          dateTime: DateTime(2026, 10, 20),
          contactType: 'revisita',
          result: 'conversa_agradavel',
          expressedQuestion: 'Qual a esperança para os que já morreram?',
          nextStep: 'Ler João 5:28, 29',
        );

        final suggestions = await PlanBRecommender.getSuggestions(
          cancelledPerson: cancelled,
          allPeople: [cancelled, candidate],
          allVisits: [visit],
        );

        expect(suggestions.first.pendingStep, equals('Ler João 5:28, 29'));
      });

      test('TC-R4-05: Database integration updates appointment status to cancelado and queries suggestions', () async {
        final student = await repo.createPerson(name: 'Estudante Marcos');
        final appt = await repo.createAppointment(
          personId: student.id,
          title: 'Estudo com Marcos',
          startTime: DateTime(2026, 10, 30, 15, 0),
          endTime: DateTime(2026, 10, 30, 16, 0),
          status: 'confirmado',
        );

        // Cancelamento no banco
        await (db.update(db.appointments)..where((t) => t.id.equals(appt.id)))
            .write(const AppointmentsCompanion(status: Value('cancelado')));

        final updatedAppt = (await repo.getAllAppointments()).firstWhere((a) => a.id == appt.id);
        expect(updatedAppt.status, equals('cancelado'));

        // Chamada ao Plano B
        final backupContact = await repo.createPerson(
          name: 'Revisita Próxima',
          status: 'revisita',
        );

        final suggestions = await PlanBRecommender.getSuggestions(
          cancelledPerson: student,
          allPeople: await repo.getAllPeople(),
          allVisits: await repo.getAllVisits(),
        );

        expect(suggestions.any((s) => s.person.id == backupContact.id), isTrue);
      });
    });

    // ========================================================================
    // R5: Cronômetro Auto-Corretivo
    // ========================================================================
    group('R5: Cronômetro Auto-Corretivo', () {
      test('TC-R5-01: Normal running session (< 4 hours) shows no warning', () {
        final now = DateTime(2026, 10, 30, 11, 30);
        final startedAt = DateTime(2026, 10, 30, 10, 0); // 1h30 rodando

        final state = AutoCorrectiveTimerLogic.evaluate(
          isRunning: true,
          startedAt: startedAt,
          accumulatedDuration: Duration.zero,
          lastHeartbeat: now.subtract(const Duration(minutes: 5)),
          nowOverride: now,
        );

        expect(state.shouldShowWarning, isFalse);
        expect(state.warningReason, isEmpty);
        expect(state.elapsedDuration, equals(const Duration(hours: 1, minutes: 30)));
      });

      test('TC-R5-02: Long-running session (> 4 hours continuous) triggers warningReason = long_running', () {
        final now = DateTime(2026, 10, 30, 15, 30);
        final startedAt = DateTime(2026, 10, 30, 10, 0); // 5h30 rodando

        final state = AutoCorrectiveTimerLogic.evaluate(
          isRunning: true,
          startedAt: startedAt,
          accumulatedDuration: Duration.zero,
          lastHeartbeat: now.subtract(const Duration(minutes: 1)),
          nowOverride: now,
        );

        expect(state.shouldShowWarning, isTrue);
        expect(state.warningReason, equals('long_running'));
        expect(state.elapsedDuration, equals(const Duration(hours: 5, minutes: 30)));
      });

      test('TC-R5-03: Reopening app after inactive period with running timer triggers warningReason = reopened_inactive', () {
        final startedAt = DateTime(2026, 10, 30, 9, 0);
        final lastHeartbeat = DateTime(2026, 10, 30, 11, 0); // Fechou o app às 11:00 (2h de campo)
        final reloadedNow = DateTime(2026, 10, 30, 16, 0); // Reabriu 5h depois (às 16:00)

        final state = AutoCorrectiveTimerLogic.evaluate(
          isRunning: true,
          startedAt: startedAt,
          accumulatedDuration: Duration.zero,
          lastHeartbeat: lastHeartbeat,
          nowOverride: reloadedNow,
        );

        expect(state.shouldShowWarning, isTrue);
        expect(state.warningReason, equals('reopened_inactive'));
        expect(state.suggestedAdjustment, equals(const Duration(hours: 2)));
      });

      test('TC-R5-04: Suggested adjustment allows trimming excess forgotten duration back to last active heartbeat', () {
        final startedAt = DateTime(2026, 10, 30, 8, 30);
        final lastHeartbeat = DateTime(2026, 10, 30, 11, 15); // 2h45 de campo ativo
        final reloadedNow = DateTime(2026, 10, 30, 18, 00); // 9h30 no total

        final state = AutoCorrectiveTimerLogic.evaluate(
          isRunning: true,
          startedAt: startedAt,
          accumulatedDuration: Duration.zero,
          lastHeartbeat: lastHeartbeat,
          nowOverride: reloadedNow,
        );

        expect(state.shouldShowWarning, isTrue);
        expect(state.suggestedAdjustment, equals(const Duration(hours: 2, minutes: 45)));
      });

      test('TC-R5-05: Timer state persistence and recovery via AppSettingsManager', () async {
        final startTime = DateTime(2026, 10, 30, 9, 0);
        await settings.setString('timer_is_running', 'true');
        await settings.setString('timer_started_at', startTime.toIso8601String());
        await settings.setString('timer_accumulated_seconds', '1800'); // 30 min prévios

        final isRunning = (await settings.getString('timer_is_running')) == 'true';
        final savedStart = DateTime.parse((await settings.getString('timer_started_at'))!);
        final accumulated = Duration(seconds: int.parse((await settings.getString('timer_accumulated_seconds'))!));

        expect(isRunning, isTrue);
        expect(savedStart, equals(startTime));
        expect(accumulated, equals(const Duration(minutes: 30)));
      });
    });
  });
}
