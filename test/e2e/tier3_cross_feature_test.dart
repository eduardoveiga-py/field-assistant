import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'e2e_contracts.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('E2E Tier 3: Cross-Feature Combinations', () {
    late AppDatabase db;
    late AppRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('TC-XF-01 [R4 + R3]: Cancelled study triggers Plan B which prioritizes unvisited Recent Seeds located within walking distance', () async {
      final now = DateTime(2026, 10, 30, 10, 0);

      // Estudante que desmarcou
      final cancelledStudent = await repo.createPerson(
        name: 'Bruno Costa',
        latitude: -23.5500,
        longitude: -46.6330,
      );

      // Candidato 1: Semente recente (2 dias atrás, sem revisita) a 200m
      final recentSeedNear = await repo.createPerson(
        name: 'Semente Recente Próxima',
        firstContactAt: now.subtract(const Duration(days: 2)),
        latitude: -23.5515,
        longitude: -46.6335,
        status: 'interessado',
      );

      // Candidato 2: Contato antigo com revisita já feita a 4km
      final oldContactFar = await repo.createPerson(
        name: 'Contato Antigo Distante',
        firstContactAt: now.subtract(const Duration(days: 25)),
        latitude: -23.5850,
        longitude: -46.6600,
        status: 'revisita',
      );

      final oldRevisit = await repo.createVisit(
        personId: oldContactFar.id,
        dateTime: now.subtract(const Duration(days: 5)),
        contactType: 'revisita',
        result: 'revisita_feita',
      );

      final allVisits = [oldRevisit];

      // Aciona o Plano B passando a localização atual
      final suggestions = await PlanBRecommender.getSuggestions(
        cancelledPerson: cancelledStudent,
        allPeople: [cancelledStudent, recentSeedNear, oldContactFar],
        allVisits: allVisits,
        currentLat: -23.5500,
        currentLng: -46.6330,
        targetDateTime: now,
      );

      expect(suggestions.isNotEmpty, isTrue);
      // A primeira sugestão deve ser a semente recente por proximidade
      final topSuggestion = suggestions.first;
      expect(topSuggestion.person.id, equals(recentSeedNear.id));
      expect(topSuggestion.distanceKm, isNotNull);
      expect(topSuggestion.distanceKm!, lessThan(0.5));

      // Validação cruzada com o helper de Sementes Recentes (R3)
      final isSeed = RecentSeedsHelper.isRecentSeed(
        person: topSuggestion.person,
        visits: allVisits,
        nowOverride: now,
      );
      expect(isSeed, isTrue);
      expect(
        RecentSeedsHelper.getElapsedText(firstContactAt: topSuggestion.person.firstContactAt, nowOverride: now),
        equals('há 2 dias'),
      );
    });

    test('TC-XF-02 [R5 + R2]: Auto-corrective timer trims a 7-hour forgotten session to 2 hours, persists to ActivityRecords, and recalculates real-time pioneer pace', () async {
      final currentDate = DateTime(2026, 10, 20); // 20 de Outubro de 2026
      const double goalHours = 50.0;
      final designatedWeekdays = [2, 4, 6]; // Terça, Quinta, Sábado
      double completedHours = 20.0;

      // Ritmo antes da saída:
      final paceBefore = PioneerPaceCalculator.calculate(
        goalHours: goalHours,
        designatedWeekdays: designatedWeekdays,
        completedHours: completedHours,
        currentDate: currentDate,
      );
      expect(paceBefore.remainingHours, equals(30.0));

      // Cenário de cronômetro esquecido:
      // Começou às 08:00, último uso ativo do app às 10:00 (2h de campo), reaberto às 15:00 (7h depois)
      final sessionStart = DateTime(2026, 10, 20, 8, 0);
      final lastActiveHeartbeat = DateTime(2026, 10, 20, 10, 0);
      final reopenedTime = DateTime(2026, 10, 20, 15, 0);

      final timerState = AutoCorrectiveTimerLogic.evaluate(
        isRunning: true,
        startedAt: sessionStart,
        accumulatedDuration: Duration.zero,
        lastHeartbeat: lastActiveHeartbeat,
        nowOverride: reopenedTime,
      );

      // Verificação do alerta do cronômetro auto-corretivo (R5)
      expect(timerState.shouldShowWarning, isTrue);
      expect(timerState.warningReason, equals('reopened_inactive'));
      expect(timerState.suggestedAdjustment, equals(const Duration(hours: 2)));

      // Usuário aceita o ajuste sugerido de 2h e salva no banco de atividades
      final adjustedHours = timerState.suggestedAdjustment.inMinutes / 60.0;
      await repo.createActivityRecord(
        date: sessionStart,
        durationSeconds: timerState.suggestedAdjustment.inSeconds,
        modality: 'campo',
        notes: 'Sessão ajustada pelo cronômetro auto-corretivo (7h -> 2h)',
      );

      // Soma atividades persistidas no banco
      final activities = await repo.getAllActivities();
      expect(activities.length, equals(1));
      expect(activities.first.durationSeconds, equals(7200));

      // Atualiza o total de horas concluídas
      completedHours += adjustedHours;
      expect(completedHours, equals(22.0));

      // Recalcula o ritmo de campo em tempo real (R2)
      final paceAfter = PioneerPaceCalculator.calculate(
        goalHours: goalHours,
        designatedWeekdays: designatedWeekdays,
        completedHours: completedHours,
        currentDate: currentDate,
      );

      expect(paceAfter.completedHours, equals(22.0));
      expect(paceAfter.remainingHours, equals(28.0));
      expect(paceAfter.isGoalReached, isFalse);
      expect(paceAfter.idealPacePerOuting < paceBefore.idealPacePerOuting, isTrue);
    });

    test('TC-XF-03 [R4 + R1]: Plan B recommendation selection seamlessly prepares the Doorstep Briefing card for the recommended contact', () async {
      final now = DateTime(2026, 10, 30, 15, 0);

      // Estudante cancelado
      final student = await repo.createPerson(name: 'Estudante Ausente');

      // Contato de Plano B
      final planBPerson = await repo.createPerson(
        name: 'Sofia Ramos',
        status: 'estudo',
        latitude: -23.5510,
        longitude: -46.6335,
        nextActionNote: 'Alcançar a oração em família',
      );

      final planBStudy = await repo.createStudy(
        title: 'Estudo com Sofia',
        participantPersonIds: [planBPerson.id],
        publicationId: 'lff-book',
        language: 'pt',
        currentLesson: 5,
        currentParagraph: 2,
        learningGoals: 'Compreender o poder da oração',
      );

      final planBVisit = await repo.createVisit(
        personId: planBPerson.id,
        dateTime: now.subtract(const Duration(days: 3)),
        contactType: 'estudo',
        result: 'progresso_bom',
        notes: 'Sofia comentou que o marido está mostrando interesse',
        expressedQuestion: 'Como orar a Deus de coração?',
        nextStep: 'Considerar a Lição 5, Ponto 2',
      );

      // 1. Aciona Plano B (R4)
      final suggestions = await PlanBRecommender.getSuggestions(
        cancelledPerson: student,
        allPeople: [student, planBPerson],
        allVisits: [planBVisit],
        currentLat: -23.5505,
        currentLng: -46.6330,
      );

      expect(suggestions.isNotEmpty, isTrue);
      final selectedCandidate = suggestions.first;
      expect(selectedCandidate.person.id, equals(planBPerson.id));

      // 2. Transição direta para o Briefing na Porta (R1)
      final briefing = DoorstepBriefingHelper.build(
        person: selectedCandidate.person,
        linkedStudy: planBStudy,
        latestVisit: planBVisit,
      );

      expect(briefing.lessonAndPoint, equals('Lição 05, Ponto 2'));
      expect(briefing.jwLibraryUri, isNotNull);
      expect(briefing.jwLibraryUri.toString(), contains('lesson=5'));
      expect(briefing.pendingDoubt, equals('Como orar a Deus de coração?'));
      expect(briefing.spiritualGoal, equals('Compreender o poder da oração'));
      expect(briefing.empathyNote, equals('Sofia comentou que o marido está mostrando interesse'));
    });

    test('TC-XF-04 [R1 + R3]: Visiting a Recent Seed displays both the cooling warning badge and initial contact briefing notes', () async {
      final now = DateTime(2026, 10, 30, 9, 30);
      final initialDate = now.subtract(const Duration(days: 4));

      // Semente recente encontrada há 4 dias
      final recentPerson = await repo.createPerson(
        name: 'Matheus Lima',
        firstContactAt: initialDate,
        status: 'interessado',
        generalNotes: 'Mora com os avós, gosta de profecias bíblicas',
        nextActionNote: 'Levar a revista Despertai! sobre futuro',
      );

      final initialVisit = await repo.createVisit(
        personId: recentPerson.id,
        dateTime: initialDate,
        contactType: 'conversa_inicial',
        result: 'aceitou_revista',
        notes: 'Primeira conversa receptiva na feira livre',
        expressedQuestion: 'O que a Bíblia diz sobre o futuro da Terra?',
      );

      // Verificação R3: É semente recente ativa?
      final isSeed = RecentSeedsHelper.isRecentSeed(
        person: recentPerson,
        visits: [initialVisit],
        nowOverride: now,
      );
      expect(isSeed, isTrue);
      expect(
        RecentSeedsHelper.getElapsedText(firstContactAt: recentPerson.firstContactAt, nowOverride: now),
        equals('há 4 dias'),
      );

      // Verificação R1: Briefing na Porta consolida as anotações do primeiro contato
      final briefing = DoorstepBriefingHelper.build(
        person: recentPerson,
        latestVisit: initialVisit,
      );

      expect(briefing.lessonAndPoint, isNull);
      expect(briefing.pendingDoubt, equals('O que a Bíblia diz sobre o futuro da Terra?'));
      expect(briefing.spiritualGoal, equals('Levar a revista Despertai! sobre futuro'));
      expect(briefing.empathyNote, equals('Primeira conversa receptiva na feira livre'));
    });

    test('TC-XF-05 [R2 + R5]: Live timer session completes and updates cumulative hours, driving monthly pioneer goal to completion', () async {
      // Pioneiro Auxiliar: meta de 30h
      const double goalHours = 30.0;
      final designatedWeekdays = [6]; // Sábados
      double completedHours = 27.0;

      // Ritmo no dia 24 de Outubro com 2 sábados restantes (dias 24 e 31)
      final paceBefore = PioneerPaceCalculator.calculate(
        goalHours: goalHours,
        designatedWeekdays: designatedWeekdays,
        completedHours: completedHours,
        currentDate: DateTime(2026, 10, 24),
      );

      expect(paceBefore.remainingHours, equals(3.0));
      expect(paceBefore.remainingOutings, equals(2));
      expect(paceBefore.idealPacePerOuting, equals(const Duration(hours: 1, minutes: 30)));
      expect(paceBefore.isGoalReached, isFalse);

      // Pioneiro faz uma saída normal de 3 horas
      final startedAt = DateTime(2026, 10, 24, 8, 30);
      final endedAt = DateTime(2026, 10, 24, 11, 30); // 3h de campo
      final sessionDuration = endedAt.difference(startedAt);

      // Avaliação do cronômetro: normal (<4h) sem alertas de esquecimento (R5)
      final timerState = AutoCorrectiveTimerLogic.evaluate(
        isRunning: true,
        startedAt: startedAt,
        accumulatedDuration: Duration.zero,
        nowOverride: endedAt,
      );
      expect(timerState.shouldShowWarning, isFalse);
      expect(timerState.elapsedDuration, equals(const Duration(hours: 3)));

      // Registra a atividade no banco
      await repo.createActivityRecord(
        date: startedAt,
        durationSeconds: sessionDuration.inSeconds,
        modality: 'campo',
      );

      completedHours += (sessionDuration.inMinutes / 60.0);
      expect(completedHours, equals(30.0));

      // Recalcula o ritmo de campo (R2)
      final paceAfter = PioneerPaceCalculator.calculate(
        goalHours: goalHours,
        designatedWeekdays: designatedWeekdays,
        completedHours: completedHours,
        currentDate: DateTime(2026, 10, 24),
      );

      expect(paceAfter.completedHours, equals(30.0));
      expect(paceAfter.remainingHours, equals(0.0));
      expect(paceAfter.isGoalReached, isTrue);
      expect(paceAfter.formattedPaceText, contains('Meta atingida! Parabéns pelo empenho no ministério.'));
    });
  });
}
