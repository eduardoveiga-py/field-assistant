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

  group('E2E Tier 2: Boundary & Corner Cases (R1 to R5)', () {
    late AppDatabase db;
    late AppRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    // ========================================================================
    // R1: Briefing na Porta — Boundary & Corner Cases
    // ========================================================================
    group('R1: Briefing na Porta - Boundary & Corner', () {
      test('TC-R1-06: Null safety on empty person (all optional fields null) returns safe nulls', () async {
        final person = await repo.createPerson(name: 'Maria Vazia');

        final briefing = DoorstepBriefingHelper.build(
          person: person,
          linkedStudy: null,
          latestVisit: null,
        );

        expect(briefing.lessonAndPoint, isNull);
        expect(briefing.jwLibraryUri, isNull);
        expect(briefing.pendingDoubt, isNull);
        expect(briefing.spiritualGoal, isNull);
        expect(briefing.empathyNote, isNull);
      });

      test('TC-R1-07: Minimum lesson (Lesson 1) and maximum lesson (Lesson 60) for LFF book', () async {
        final personMin = await repo.createPerson(name: 'Aluno Min');
        final studyMin = await repo.createStudy(
          title: 'Estudo LFF Min',
          participantPersonIds: [personMin.id],
          publicationId: 'lff-book',
          language: 'pt',
          currentLesson: 1,
          currentParagraph: 1,
        );

        final briefingMin = DoorstepBriefingHelper.build(
          person: personMin,
          linkedStudy: studyMin,
        );
        expect(briefingMin.lessonAndPoint, equals('Lição 01, Ponto 1'));
        expect(briefingMin.jwLibraryUri.toString(), contains('lesson=1'));

        final personMax = await repo.createPerson(name: 'Aluno Max');
        final studyMax = await repo.createStudy(
          title: 'Estudo LFF Max',
          participantPersonIds: [personMax.id],
          publicationId: 'lff-book',
          language: 'pt',
          currentLesson: 60,
          currentParagraph: 10,
        );

        final briefingMax = DoorstepBriefingHelper.build(
          person: personMax,
          linkedStudy: studyMax,
        );
        expect(briefingMax.lessonAndPoint, equals('Lição 60, Ponto 10'));
        expect(briefingMax.jwLibraryUri.toString(), contains('lesson=60'));
      });

      test('TC-R1-08: Paragraph boundaries (paragraph null, paragraph 1, large paragraph 50)', () async {
        final person = await repo.createPerson(name: 'Aluno Ponto');

        // Sem parágrafo (apenas lição)
        final studyNoPara = await repo.createStudy(
          title: 'Estudo Sem Ponto',
          participantPersonIds: [person.id],
          publicationId: 'lff-book',
          currentLesson: 5,
          currentParagraph: null,
        );
        final briefingNoPara = DoorstepBriefingHelper.build(
          person: person,
          linkedStudy: studyNoPara,
        );
        expect(briefingNoPara.lessonAndPoint, equals('Lição 05'));

        // Parágrafo grande (50)
        final studyLargePara = await repo.createStudy(
          title: 'Estudo Ponto Grande',
          participantPersonIds: [person.id],
          publicationId: 'lff-book',
          currentLesson: 10,
          currentParagraph: 50,
        );
        final briefingLarge = DoorstepBriefingHelper.build(
          person: person,
          linkedStudy: studyLargePara,
        );
        expect(briefingLarge.lessonAndPoint, equals('Lição 10, Ponto 50'));
      });

      test('TC-R1-09: UTF-8, special characters, and multiline formatting in empathy and doubt fields', () async {
        const specialDoubt = 'Dúvida: Deus se importa com 🐶 pets? & Por que sofremos? 🤔\nSegunda linha com acentos: áéíóú, ç, ñ.';
        const specialEmpathy = 'Nota pessoal:\n- Filho fez cirurgia 🏥\n- Não bater na porta dos fundos!\n- "Cuidado com o cão"';

        final person = await repo.createPerson(
          name: 'João José da Conceição',
          generalNotes: specialEmpathy,
        );

        final visit = await repo.createVisit(
          personId: person.id,
          dateTime: DateTime(2026, 10, 20),
          contactType: 'revisita',
          result: 'revisita_feita',
          expressedQuestion: specialDoubt,
        );

        final briefing = DoorstepBriefingHelper.build(
          person: person,
          latestVisit: visit,
        );

        expect(briefing.pendingDoubt, equals(specialDoubt));
        expect(briefing.empathyNote, equals(specialEmpathy));
      });

      test('TC-R1-10: Libras (Sign Language) study link generates official video library URL without paragraph precision', () async {
        final person = await repo.createPerson(name: 'Surdo Amigo');
        final studyLibras = await repo.createStudy(
          title: 'Estudo em Libras',
          participantPersonIds: [person.id],
          publicationId: 'lff-book',
          language: 'bzs', // Língua Brasileira de Sinais
          currentLesson: 3,
          currentParagraph: 2,
        );

        final briefing = DoorstepBriefingHelper.build(
          person: person,
          linkedStudy: studyLibras,
        );

        expect(briefing.jwLibraryUri, isNotNull);
        expect(briefing.jwLibraryUri.toString(), contains('jw.org/bzs'));
      });
    });

    // ========================================================================
    // R2: Calculadora de Ritmo Real de Campo — Boundary & Corner Cases
    // ========================================================================
    group('R2: Calculadora de Ritmo Real de Campo - Boundary & Corner', () {
      test('TC-R2-06: Goal reached (completedHours >= goalHours) flags isGoalReached = true and 0 remaining hours', () {
        final resultExact = PioneerPaceCalculator.calculate(
          goalHours: 50.0,
          designatedWeekdays: [2, 4, 6],
          completedHours: 50.0,
          currentDate: DateTime(2026, 10, 20),
        );

        expect(resultExact.isGoalReached, isTrue);
        expect(resultExact.remainingHours, equals(0.0));
        expect(resultExact.formattedPaceText, contains('Meta atingida!'));
      });

      test('TC-R2-07: Goal exceeded (completedHours > goalHours) prevents negative remaining hours', () {
        final resultExceeded = PioneerPaceCalculator.calculate(
          goalHours: 50.0,
          designatedWeekdays: [2, 4, 6],
          completedHours: 55.5,
          currentDate: DateTime(2026, 10, 20),
        );

        expect(resultExceeded.isGoalReached, isTrue);
        expect(resultExceeded.remainingHours, equals(0.0));
        expect(resultExceeded.formattedPaceText, contains('Meta atingida!'));
      });

      test('TC-R2-08: 0 outings remaining with remaining hours handles division gracefully without NaN/Infinity', () {
        // Mês acaba hoje e faltam 5 horas mas não há saídas programadas
        final resultNoOutings = PioneerPaceCalculator.calculate(
          goalHours: 50.0,
          designatedWeekdays: [1], // Segundas
          completedHours: 45.0,
          currentDate: DateTime(2026, 10, 31), // Sábado (nenhuma segunda restante)
        );

        expect(resultNoOutings.remainingOutings, equals(0));
        expect(resultNoOutings.remainingHours, equals(5.0));
        expect(resultNoOutings.isGoalReached, isFalse);
        expect(resultNoOutings.idealPacePerOuting, equals(const Duration(hours: 5)));
        expect(resultNoOutings.formattedPaceText, contains('Faltam 5h em 0 saídas.'));
      });

      test('TC-R2-09: Last day of month boundary (single outing remaining or 0 outings)', () {
        // Outubro 31 é sábado. Se sábados estão marcados:
        final onLastDayWithOuting = PioneerPaceCalculator.calculate(
          goalHours: 50.0,
          designatedWeekdays: [6], // Sábado
          completedHours: 46.0,
          currentDate: DateTime(2026, 10, 31),
        );
        expect(onLastDayWithOuting.remainingOutings, equals(1));
        expect(onLastDayWithOuting.remainingHours, equals(4.0));
        expect(onLastDayWithOuting.idealPacePerOuting, equals(const Duration(hours: 4)));

        // Se sábado NÃO está marcado no dia 31:
        final onLastDayWithoutOuting = PioneerPaceCalculator.calculate(
          goalHours: 50.0,
          designatedWeekdays: [1, 3, 5],
          completedHours: 46.0,
          currentDate: DateTime(2026, 10, 31),
        );
        expect(onLastDayWithoutOuting.remainingOutings, equals(0));
      });

      test('TC-R2-10: Leap year February (29 days) vs regular February (28 days) month calculation', () {
        // Ano bissexto: 2028 (29 dias em Fevereiro)
        // 2028-02-01 até 2028-02-29
        final leapFeb = PioneerPaceCalculator.calculate(
          goalHours: 30.0,
          designatedWeekdays: [2], // Terças-feiras em Fev 2028: 1, 8, 15, 22, 29 (5 terças!)
          completedHours: 0.0,
          currentDate: DateTime(2028, 2, 1),
        );
        expect(leapFeb.remainingOutings, equals(5));

        // Ano não bissexto: 2027 (28 dias em Fevereiro)
        // 2027-02-01 até 2027-02-28
        final regularFeb = PioneerPaceCalculator.calculate(
          goalHours: 30.0,
          designatedWeekdays: [1], // Segundas em Fev 2027: 1, 8, 15, 22 (4 segundas)
          completedHours: 0.0,
          currentDate: DateTime(2027, 2, 1),
        );
        expect(regularFeb.remainingOutings, equals(4));
      });

      test('TC-R2-11: Empty designated weekdays list ([]) safely returns 0 outings without exceptions', () {
        final resultEmpty = PioneerPaceCalculator.calculate(
          goalHours: 30.0,
          designatedWeekdays: [],
          completedHours: 10.0,
          currentDate: DateTime(2026, 10, 15),
        );

        expect(resultEmpty.remainingOutings, equals(0));
        expect(resultEmpty.remainingHours, equals(20.0));
        expect(resultEmpty.isGoalReached, isFalse);
      });
    });

    // ========================================================================
    // R3: Destaque de Sementes Recentes — Boundary & Corner Cases
    // ========================================================================
    group('R3: Destaque de Sementes Recentes - Boundary & Corner', () {
      test('TC-R3-06: Exactly 7 days threshold (7 days 00:00:00) flags isRecentSeed = true', () async {
        final now = DateTime(2026, 10, 30, 12, 0, 0);
        final firstContact = now.subtract(const Duration(days: 7)); // Exatamente 7 dias atrás

        final person = await repo.createPerson(
          name: 'Semente Exata 7 Dias',
          firstContactAt: firstContact,
        );

        final isRecent = RecentSeedsHelper.isRecentSeed(
          person: person,
          visits: [],
          nowOverride: now,
        );

        expect(isRecent, isTrue);
      });

      test('TC-R3-07: 7 days and 1 minute / 8 days flags isRecentSeed = false', () async {
        final now = DateTime(2026, 10, 30, 12, 0, 0);
        final firstContact = now.subtract(const Duration(days: 7, minutes: 1)); // 7 dias e 1 minuto

        final person = await repo.createPerson(
          name: 'Semente Expirada',
          firstContactAt: firstContact,
        );

        final isRecent = RecentSeedsHelper.isRecentSeed(
          person: person,
          visits: [],
          nowOverride: now,
        );

        expect(isRecent, isFalse);
      });

      test('TC-R3-08: Contact attempt without contact (tentativa_sem_contato) preserves isRecentSeed = true', () async {
        final now = DateTime(2026, 10, 30, 10, 0);
        final firstContact = now.subtract(const Duration(days: 3));

        final person = await repo.createPerson(
          name: 'Tentativa Sem Ninguém em Casa',
          firstContactAt: firstContact,
        );

        final attemptVisit = await repo.createVisit(
          personId: person.id,
          dateTime: now.subtract(const Duration(days: 1)),
          contactType: 'tentativa_sem_contato',
          result: 'ninguem_atendeu',
        );

        final isRecent = RecentSeedsHelper.isRecentSeed(
          person: person,
          visits: [attemptVisit],
          nowOverride: now,
        );

        expect(isRecent, isTrue);
      });

      test('TC-R3-09: Soft-deleted person (deletedAt != null) flags isRecentSeed = false', () async {
        final now = DateTime(2026, 10, 30, 10, 0);
        final person = await repo.createPerson(
          name: 'Contato Apagado',
          firstContactAt: now.subtract(const Duration(days: 2)),
        );

        // Soft delete
        final deletedPerson = person.copyWith(deletedAt: Value(now));

        final isRecent = RecentSeedsHelper.isRecentSeed(
          person: deletedPerson,
          visits: [],
          nowOverride: now,
        );

        expect(isRecent, isFalse);
      });

      test('TC-R3-10: Clock skew / future contact date handled safely', () async {
        final now = DateTime(2026, 10, 30, 10, 0);
        final futureContact = now.add(const Duration(days: 1));

        final person = await repo.createPerson(
          name: 'Data No Futuro',
          firstContactAt: futureContact,
        );

        final isRecent = RecentSeedsHelper.isRecentSeed(
          person: person,
          visits: [],
          nowOverride: now,
        );

        expect(isRecent, isFalse);
      });
    });

    // ========================================================================
    // R4: Botão "Estudante Desmarcou Agora" — Boundary & Corner Cases
    // ========================================================================
    group('R4: Botão Estudante Desmarcou Agora - Boundary & Corner', () {
      test('TC-R4-06: Single candidate available returns 1 item without out-of-bounds error', () async {
        final cancelled = await repo.createPerson(name: 'Cancelado Único');
        final singleCandidate = await repo.createPerson(
          name: 'Única Opção',
          status: 'revisita',
        );

        final suggestions = await PlanBRecommender.getSuggestions(
          cancelledPerson: cancelled,
          allPeople: [cancelled, singleCandidate],
          allVisits: [],
        );

        expect(suggestions.length, equals(1));
        expect(suggestions.first.person.id, equals(singleCandidate.id));
      });

      test('TC-R4-07: Zero candidate pool returns empty list [] safely', () async {
        final cancelled = await repo.createPerson(name: 'Cancelado Sem Opções');

        final suggestions = await PlanBRecommender.getSuggestions(
          cancelledPerson: cancelled,
          allPeople: [cancelled],
          allVisits: [],
        );

        expect(suggestions, isEmpty);
      });

      test('TC-R4-08: Candidate with null coordinates when user has GPS places candidate at end of ranked list', () async {
        final cancelled = await repo.createPerson(name: 'Cancelado');

        final candidateWithGps = await repo.createPerson(
          name: 'Perto Com GPS',
          latitude: -23.5510,
          longitude: -46.6335,
        );

        final candidateNoGps = await repo.createPerson(
          name: 'Sem Coordenadas Cadastradas',
          latitude: null,
          longitude: null,
        );

        final suggestions = await PlanBRecommender.getSuggestions(
          cancelledPerson: cancelled,
          allPeople: [cancelled, candidateNoGps, candidateWithGps],
          allVisits: [],
          currentLat: -23.5505,
          currentLng: -46.6333,
        );

        expect(suggestions.length, equals(2));
        expect(suggestions.first.person.id, equals(candidateWithGps.id));
        expect(suggestions.last.person.id, equals(candidateNoGps.id));
      });

      test('TC-R4-09: Cancelled person is never suggested as Plan B for themselves', () async {
        final cancelled = await repo.createPerson(
          name: 'Cancelado Mesma Pessoa',
          latitude: -23.5505,
          longitude: -46.6333,
        );

        final other = await repo.createPerson(
          name: 'Outro',
          latitude: -23.5600,
          longitude: -46.6400,
        );

        final suggestions = await PlanBRecommender.getSuggestions(
          cancelledPerson: cancelled,
          allPeople: [cancelled, other],
          allVisits: [],
          currentLat: -23.5505,
          currentLng: -46.6333,
        );

        expect(suggestions.any((s) => s.person.id == cancelled.id), isFalse);
      });

      test('TC-R4-10: Soft-deleted contacts are strictly excluded from Plan B suggestions', () async {
        final cancelled = await repo.createPerson(name: 'Cancelado');
        final deletedCandidate = (await repo.createPerson(name: 'Contato Excluído')).copyWith(
          deletedAt: Value(DateTime.now()),
        );

        final activeCandidate = await repo.createPerson(name: 'Contato Ativo');

        final suggestions = await PlanBRecommender.getSuggestions(
          cancelledPerson: cancelled,
          allPeople: [cancelled, deletedCandidate, activeCandidate],
          allVisits: [],
        );

        expect(suggestions.length, equals(1));
        expect(suggestions.first.person.id, equals(activeCandidate.id));
        expect(suggestions.any((s) => s.person.id == deletedCandidate.id), isFalse);
      });
    });

    // ========================================================================
    // R5: Cronômetro Auto-Corretivo — Boundary & Corner Cases
    // ========================================================================
    group('R5: Cronômetro Auto-Corretivo - Boundary & Corner', () {
      test('TC-R5-06: Exactly 4h threshold (4h 00m 00s -> false; 4h 00m 01s -> true)', () {
        final startedAt = DateTime(2026, 10, 30, 8, 0, 0);

        // Exatamente 4h: não deve acionar
        final exact4h = startedAt.add(const Duration(hours: 4));
        final stateExact = AutoCorrectiveTimerLogic.evaluate(
          isRunning: true,
          startedAt: startedAt,
          accumulatedDuration: Duration.zero,
          nowOverride: exact4h,
        );
        expect(stateExact.shouldShowWarning, isFalse);

        // 4h e 1 segundo: DEVE acionar aviso
        final over4h = startedAt.add(const Duration(hours: 4, seconds: 1));
        final stateOver = AutoCorrectiveTimerLogic.evaluate(
          isRunning: true,
          startedAt: startedAt,
          accumulatedDuration: Duration.zero,
          nowOverride: over4h,
        );
        expect(stateOver.shouldShowWarning, isTrue);
        expect(stateOver.warningReason, equals('long_running'));
      });

      test('TC-R5-07: Stopped timer (isRunning = false) with > 4h duration does not trigger warning', () {
        final stateStopped = AutoCorrectiveTimerLogic.evaluate(
          isRunning: false,
          startedAt: DateTime(2026, 10, 30, 8, 0),
          accumulatedDuration: const Duration(hours: 6),
          nowOverride: DateTime(2026, 10, 30, 14, 0),
        );

        expect(stateStopped.shouldShowWarning, isFalse);
        expect(stateStopped.warningReason, isEmpty);
      });

      test('TC-R5-08: Zero elapsed duration handles gracefully', () {
        final now = DateTime(2026, 10, 30, 10, 0);
        final stateZero = AutoCorrectiveTimerLogic.evaluate(
          isRunning: true,
          startedAt: now,
          accumulatedDuration: Duration.zero,
          nowOverride: now,
        );

        expect(stateZero.shouldShowWarning, isFalse);
        expect(stateZero.elapsedDuration, equals(Duration.zero));
      });

      test('TC-R5-09: Multi-day forgotten timer (e.g. 48h) evaluates safely with bounded suggestions', () {
        final startedAt = DateTime(2026, 10, 28, 9, 0);
        final lastHeartbeat = DateTime(2026, 10, 28, 11, 0);
        final now48hLater = DateTime(2026, 10, 30, 9, 0); // 48h rodando

        final state = AutoCorrectiveTimerLogic.evaluate(
          isRunning: true,
          startedAt: startedAt,
          accumulatedDuration: Duration.zero,
          lastHeartbeat: lastHeartbeat,
          nowOverride: now48hLater,
        );

        expect(state.shouldShowWarning, isTrue);
        expect(state.warningReason, equals('reopened_inactive'));
        expect(state.suggestedAdjustment, equals(const Duration(hours: 2)));
        expect(state.elapsedDuration, equals(const Duration(hours: 48)));
      });

      test('TC-R5-10: Negative time jump (system clock adjustment) safely clamped to zero', () {
        final startedAt = DateTime(2026, 10, 30, 12, 0);
        final clockSkewPast = DateTime(2026, 10, 30, 11, 0); // Relógio atrasou 1h

        final state = AutoCorrectiveTimerLogic.evaluate(
          isRunning: true,
          startedAt: startedAt,
          accumulatedDuration: const Duration(minutes: 15),
          nowOverride: clockSkewPast,
        );

        expect(state.shouldShowWarning, isFalse);
        expect(state.elapsedDuration, equals(const Duration(minutes: 15)));
      });
    });
  });
}
