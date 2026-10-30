import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/publications/lff_book_catalog.dart';
import 'package:ministerio_pessoal/publications/periodicals_catalog.dart';
import 'package:ministerio_pessoal/dashboard/student_priority_engine.dart';
import 'package:ministerio_pessoal/dashboard/counting_rules.dart';
import 'package:ministerio_pessoal/territory/geolocation_helper.dart';
import 'package:ministerio_pessoal/settings/backup_service.dart';

void main() {
  group('Catálogo Completo do Livro Seja Feliz Para Sempre! (lff)', () {
    test('getAllStudyUnits retorna 71 unidades estruturadas (60 lições, 4 revisões e 7 apêndices)', () {
      final units = LffBookCatalog.getAllStudyUnits();
      expect(units.length, equals(71));

      final lessonsUnits = units.where((u) => u.category.contains('Lições do Livro')).toList();
      final reviewUnits = units.where((u) => u.category.contains('Revisões')).toList();
      final endnoteUnits = units.where((u) => u.category.contains('Entenda Melhor')).toList();

      expect(lessonsUnits.length, equals(60));
      expect(reviewUnits.length, equals(4));
      expect(endnoteUnits.length, equals(7));
    });

    test('Possui exatamente 60 lições e 4 seções principais', () {
      expect(LffBookCatalog.lessons.length, equals(60));
      expect(LffBookCatalog.sections.length, equals(4));

      // Seção 1: Lições 1 a 12
      final l1 = LffBookCatalog.getLesson(1);
      expect(l1, isNotNull);
      expect(l1!.title, contains('Bíblia pode ajudar'));
      expect(l1.section, equals(1));
      expect(l1.pointTitles.length, equals(3)); // Lições 1 a 3 possuem 3 pontos

      final l5 = LffBookCatalog.getLesson(5);
      expect(l5, isNotNull);
      expect(l5!.pointTitles.length, equals(6)); // Lições 4 a 60 possuem 6 pontos

      // Seção 4: Lições 48 a 60
      final l60 = LffBookCatalog.getLesson(60);
      expect(l60, isNotNull);
      expect(l60!.title, contains('amizade com Jeová'));
      expect(l60.section, equals(4));
      expect(l60.pointTitles.length, equals(6));
    });

    test('Cálculo de progresso percentual (0.0% a 100.0%)', () {
      final p0 = LffBookCatalog.calculateProgressPercentage(lesson: 1, point: 0);
      expect(p0, closeTo(0.0, 0.5));

      final pMid = LffBookCatalog.calculateProgressPercentage(lesson: 30, point: 3);
      expect(pMid, greaterThan(45.0));
      expect(pMid, lessThan(55.0));

      final p100 = LffBookCatalog.calculateProgressPercentage(lesson: 60, point: 6);
      expect(p100, equals(100.0));
    });

    test('getNextProgression calcula avanço de ponto e lição subsequente', () {
      // Ponto 2 avança para Ponto 3
      final next1 = LffBookCatalog.getNextProgression(currentLesson: 5, currentPoint: 2);
      expect(next1.nextLesson, equals(5));
      expect(next1.nextPoint, equals(3));
      expect(next1.label, contains('Lição 5, Ponto 3'));

      // Último ponto da lição 5 (ponto 6) avança para lição 6, ponto 1
      final next2 = LffBookCatalog.getNextProgression(currentLesson: 5, currentPoint: 6);
      expect(next2.nextLesson, equals(6));
      expect(next2.nextPoint, equals(1));
      expect(next2.label, contains('Lição 6, Ponto 1'));

      // Fim do livro
      final nextEnd = LffBookCatalog.getNextProgression(currentLesson: 60, currentPoint: 6);
      expect(nextEnd.label.toLowerCase(), contains('concluído'));
    });
  });

  group('Motor de Prioridade e Interesse Espiritual (StudentPriorityEngine)', () {
    test('Estudante com frequência 2x/semana e avanço rápido pontua mais que estudante esporádico', () {
      final now = DateTime(2026, 10, 15);

      final personFast = PersonEntry(
        id: 'p-fast',
        name: 'Carlos Oliveira',
        firstContactAt: now.subtract(const Duration(days: 30)),
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now,
        status: 'estudo',
        tags: '[]',
        revision: 1,
      );

      final personSlow = PersonEntry(
        id: 'p-slow',
        name: 'Roberto Santos',
        firstContactAt: now.subtract(const Duration(days: 90)),
        createdAt: now.subtract(const Duration(days: 90)),
        updatedAt: now,
        status: 'estudo',
        tags: '[]',
        revision: 1,
      );

      final studyFast = BibleStudyEntry(
        id: 's-fast',
        title: 'Estudo Carlos',
        ownerId: 'user1',
        startedAt: now.subtract(const Duration(days: 30)),
        status: 'ativo',
        publicationId: 'lff-book',
        language: 'pt',
        frequency: 'duas_vezes_semana',
        currentLesson: 12,
        currentParagraph: 3,
        lastSessionAt: now.subtract(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now,
        revision: 1,
      );

      final studySlow = BibleStudyEntry(
        id: 's-slow',
        title: 'Estudo Roberto',
        ownerId: 'user1',
        startedAt: now.subtract(const Duration(days: 90)),
        status: 'ativo',
        publicationId: 'lff-book',
        language: 'pt',
        frequency: 'semanal',
        currentLesson: 2,
        currentParagraph: 1,
        lastSessionAt: now.subtract(const Duration(days: 25)),
        createdAt: now.subtract(const Duration(days: 90)),
        updatedAt: now,
        revision: 1,
      );

      final parts = [
        StudyParticipantEntry(id: 'part-1', studyId: 's-fast', personId: 'p-fast', isPrimary: true, createdAt: now, updatedAt: now, revision: 1),
        StudyParticipantEntry(id: 'part-2', studyId: 's-slow', personId: 'p-slow', isPrimary: true, createdAt: now, updatedAt: now, revision: 1),
      ];

      final sessions = [
        StudySessionEntry(id: 'sess-1', studyId: 's-fast', dateTimeField: now.subtract(const Duration(days: 5)), status: 'realizada', participantIds: '[]', createdAt: now, updatedAt: now, revision: 1),
        StudySessionEntry(id: 'sess-2', studyId: 's-fast', dateTimeField: now.subtract(const Duration(days: 2)), status: 'realizada', participantIds: '[]', createdAt: now, updatedAt: now, revision: 1),
        StudySessionEntry(id: 'sess-3', studyId: 's-slow', dateTimeField: now.subtract(const Duration(days: 25)), status: 'cancelada', participantIds: '[]', createdAt: now, updatedAt: now, revision: 1),
      ];

      final prioritized = StudentPriorityEngine.calculatePriorities(
        studies: [studyFast, studySlow],
        participants: parts,
        people: [personFast, personSlow],
        sessions: sessions,
        nowOverride: now,
      );

      expect(prioritized.length, equals(2));
      expect(prioritized.first.study.id, equals('s-fast'));
      expect(prioritized.first.internalScore, greaterThan(prioritized.last.internalScore));
      expect(prioritized.first.priorityTier, anyOf(equals('Muito Alta'), equals('Alta')));
      expect(prioritized.first.frequency, equals('duas_vezes_semana'));
    });

    test('Reordenação manual (applyManualReorder) sobrescreve a ordem calculada automaticamente', () {
      final now = DateTime(2026, 10, 15);
      final personA = PersonEntry(id: 'p-a', name: 'Ana', firstContactAt: now, createdAt: now, updatedAt: now, status: 'estudo', tags: '[]', revision: 1);
      final personB = PersonEntry(id: 'p-b', name: 'Bruno', firstContactAt: now, createdAt: now, updatedAt: now, status: 'estudo', tags: '[]', revision: 1);
      final studyA = BibleStudyEntry(id: 's-a', title: 'Ana', ownerId: 'u', startedAt: now, status: 'ativo', publicationId: 'lff-book', language: 'pt', frequency: 'semanal', currentLesson: 10, createdAt: now, updatedAt: now, revision: 1);
      final studyB = BibleStudyEntry(id: 's-b', title: 'Bruno', ownerId: 'u', startedAt: now, status: 'ativo', publicationId: 'lff-book', language: 'pt', frequency: 'semanal', currentLesson: 2, createdAt: now, updatedAt: now, revision: 1);

      final parts = [
        StudyParticipantEntry(id: 'pt-1', studyId: 's-a', personId: 'p-a', isPrimary: true, createdAt: now, updatedAt: now, revision: 1),
        StudyParticipantEntry(id: 'pt-2', studyId: 's-b', personId: 'p-b', isPrimary: true, createdAt: now, updatedAt: now, revision: 1),
      ];

      final Map<String, int> manualMap = {};
      var items = StudentPriorityEngine.calculatePriorities(
        studies: [studyA, studyB],
        participants: parts,
        people: [personA, personB],
        sessions: const [],
        manualOrderMap: manualMap,
        nowOverride: now,
      );

      expect(items.first.study.id, equals('s-a'));

      // Move o segundo para o primeiro lugar
      StudentPriorityEngine.applyManualReorder(
        items: items,
        oldIndex: 1,
        newIndex: 0,
        manualOrderMap: manualMap,
      );

      final reordered = StudentPriorityEngine.calculatePriorities(
        studies: [studyA, studyB],
        participants: parts,
        people: [personA, personB],
        sessions: const [],
        manualOrderMap: manualMap,
        nowOverride: now,
      );

      expect(reordered.first.study.id, equals('s-b'));
      expect(reordered.first.manualRank, equals(1));
    });

    test('Sessões falhas ou canceladas penalizam pontuação interna em relação a sessões realizadas', () {
      final now = DateTime(2026, 10, 20);
      final person1 = PersonEntry(id: 'p-1', name: 'Estudante A', firstContactAt: now, createdAt: now, updatedAt: now, status: 'estudo', tags: '[]', revision: 1);
      final person2 = PersonEntry(id: 'p-2', name: 'Estudante B', firstContactAt: now, createdAt: now, updatedAt: now, status: 'estudo', tags: '[]', revision: 1);

      final study1 = BibleStudyEntry(id: 's-1', title: 'Estudo A', ownerId: 'u', startedAt: now, status: 'ativo', publicationId: 'lff-book', language: 'pt', frequency: 'semanal', currentLesson: 5, createdAt: now, updatedAt: now, revision: 1);
      final study2 = BibleStudyEntry(id: 's-2', title: 'Estudo B', ownerId: 'u', startedAt: now, status: 'ativo', publicationId: 'lff-book', language: 'pt', frequency: 'semanal', currentLesson: 5, createdAt: now, updatedAt: now, revision: 1);

      final parts = [
        StudyParticipantEntry(id: 'pt-1', studyId: 's-1', personId: 'p-1', isPrimary: true, createdAt: now, updatedAt: now, revision: 1),
        StudyParticipantEntry(id: 'pt-2', studyId: 's-2', personId: 'p-2', isPrimary: true, createdAt: now, updatedAt: now, revision: 1),
      ];

      final sessions = [
        StudySessionEntry(id: 'sess-ok-1', studyId: 's-1', dateTimeField: now.subtract(const Duration(days: 7)), status: 'realizada', participantIds: '[]', createdAt: now, updatedAt: now, revision: 1),
        StudySessionEntry(id: 'sess-ok-2', studyId: 's-1', dateTimeField: now.subtract(const Duration(days: 1)), status: 'realizada', participantIds: '[]', createdAt: now, updatedAt: now, revision: 1),
        StudySessionEntry(id: 'sess-fail-1', studyId: 's-2', dateTimeField: now.subtract(const Duration(days: 7)), status: 'cancelada', participantIds: '[]', createdAt: now, updatedAt: now, revision: 1),
        StudySessionEntry(id: 'sess-fail-2', studyId: 's-2', dateTimeField: now.subtract(const Duration(days: 1)), status: 'cancelada', participantIds: '[]', createdAt: now, updatedAt: now, revision: 1),
      ];

      final results = StudentPriorityEngine.calculatePriorities(
        studies: [study1, study2],
        participants: parts,
        people: [person1, person2],
        sessions: sessions,
        nowOverride: now,
      );

      final itemA = results.firstWhere((i) => i.study.id == 's-1');
      final itemB = results.firstWhere((i) => i.study.id == 's-2');

      expect(itemA.internalScore, greaterThan(itemB.internalScore));
      expect(results.first.study.id, equals('s-1'));
    });
  });

  group('Persistência Estatística Histórica e Encerramento de Revisitas', () {
    late AppDatabase db;
    late AppRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Visitas realizadas em um mês não são perdidas quando a pessoa é repassada ou encerrada', () async {
      final p = await repo.createPerson(name: 'Maria Silva', status: 'revisita');

      // Registra 2 visitas no mês de outubro
      await repo.createVisit(
        personId: p.id,
        dateTime: DateTime(2026, 10, 2, 10, 0),
        contactType: 'revisita',
        result: 'Conversa bíblica',
      );
      await repo.createVisit(
        personId: p.id,
        dateTime: DateTime(2026, 10, 5, 10, 0),
        contactType: 'revisita',
        result: 'Deixada revista',
      );

      // Marca a revisita como repassada (revisita_passada) posteriormente
      await repo.updatePerson(p.copyWith(status: 'revisita_passada'));

      final allVisits = await repo.getAllVisits();
      final allPeople = await repo.getAllPeople();

      final metrics = DashboardCalculator.calculate(
        visits: allVisits,
        studies: [],
        sessions: [],
        appointments: [],
        activities: [],
        people: allPeople,
        periodStart: DateTime(2026, 10, 1),
        periodEnd: DateTime(2026, 10, 31, 23, 59, 59),
      );

      // As visitas continuam contabilizadas nas estatísticas de outubro!
      expect(metrics.heldVisitsCount, equals(2));
    });

    test('Encerramento de revisita com motivo contabiliza em endedVisitsByReason', () async {
      await repo.createPerson(
        name: 'José Souza',
        status: 'revisita_encerrada',
        contactRestrictions: '{"endReason":"Mudou-se de território"}',
      );
      await repo.createPerson(
        name: 'Lucas Ferreira',
        status: 'revisita_encerrada',
        contactRestrictions: '{"endReason":"Falta de interesse / tempo"}',
      );

      final allPeople = await repo.getAllPeople();

      final metrics = DashboardCalculator.calculate(
        visits: [],
        studies: [],
        sessions: [],
        appointments: [],
        activities: [],
        people: allPeople,
        periodStart: DateTime(2026, 10, 1),
        periodEnd: DateTime(2026, 10, 31, 23, 59, 59),
      );

      expect(metrics.endedVisitsCount, equals(2));
      expect(metrics.endedVisitsByReason['Mudou-se de território'], equals(1));
      expect(metrics.endedVisitsByReason['Falta de interesse / tempo'], equals(1));
    });

    test('Cadastro de Evento Teocrático insere compromisso no calendário oficial', () async {
      final start = DateTime(2026, 11, 14, 9, 0);
      final end = DateTime(2026, 11, 14, 16, 30);

      final appt = await repo.createAppointment(
        title: '[Evento Teocrático] Assembleia de Circuito: Entre no Descanso de Deus',
        startTime: start,
        endTime: end,
        durationMinutes: 450,
        locationNotes: 'Salão de Assembleias',
        status: 'confirmado',
      );

      expect(appt.id, isNotEmpty);
      expect(appt.title, contains('[Evento Teocrático] Assembleia'));
      expect(appt.status, equals('confirmado'));

      final all = await repo.getAllAppointments();
      expect(all.length, equals(1));
      expect(all.first.locationNotes, equals('Salão de Assembleias'));
    });
  });

  group('Geolocalização e Proximidade (GeolocationHelper)', () {
    test('calculateHaversineDistanceKm calcula distâncias com precisão e detecta limiar de 1.2km', () {
      // Mesmas coordenadas -> 0.0 km
      final dZero = GeolocationHelper.calculateHaversineDistanceKm(-23.5505, -46.6333, -23.5505, -46.6333);
      expect(dZero, closeTo(0.0, 0.001));

      // Coordenadas próximas (~500m) em São Paulo
      final dNear = GeolocationHelper.calculateHaversineDistanceKm(-23.5505, -46.6333, -23.5550, -46.6333);
      expect(dNear, greaterThan(0.4));
      expect(dNear, lessThan(0.6));
      expect(dNear, lessThan(1.2)); // Dentro do raio de 1.2km para alerta de proximidade

      // Coordenadas distantes (São Paulo até Rio de Janeiro ~360km)
      final dFar = GeolocationHelper.calculateHaversineDistanceKm(-23.5505, -46.6333, -22.9068, -43.1729);
      expect(dFar, greaterThan(350.0));
      expect(dFar, lessThan(380.0));
      expect(dFar, greaterThan(1.2));
    });
  });

  group('Backup Automático Silencioso (BackupService)', () {
    late AppDatabase db;
    late AppRepository repo;
    late BackupService backupService;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
      backupService = BackupService(repo);
    });

    tearDown(() async {
      await db.close();
    });

    test('performSilentBackupIfNeeded executa backup inicial e respeita intervalo de 24h', () async {
      // 1. Antes de qualquer backup, a data é nula
      final initialDate = await backupService.getLastSilentBackupDate();
      expect(initialDate, isNull);

      // 2. Primeiro backup executa com sucesso
      final didRun1 = await backupService.performSilentBackupIfNeeded();
      expect(didRun1, isTrue);

      final dateAfter1 = await backupService.getLastSilentBackupDate();
      expect(dateAfter1, isNotNull);
      expect(DateTime.now().difference(dateAfter1!).inSeconds, lessThan(10));

      // 3. Execução subsequente antes de 24h não deve reexecutar
      final didRun2 = await backupService.performSilentBackupIfNeeded();
      expect(didRun2, isFalse);

      // 4. Execução com force: true executa mesmo antes de 24h
      final didRunForce = await backupService.performSilentBackupIfNeeded(force: true);
      expect(didRunForce, isTrue);
    });
  });

  group('Catálogo Oficial de Folhetos e Publicações Atualizadas', () {
    test('Folhetos contém os 9 novos folhetos oficiais e itens especiais', () {
      final folhetos = PeriodicalsCatalog.folhetos;
      expect(folhetos.length, equals(12));

      // Verifica os 9 novos folhetos
      final titles = folhetos.map((f) => f.title).toList();
      expect(titles, contains('Folheto: Futuro'));
      expect(titles, contains('Folheto: Família'));
      expect(titles, contains('Folheto: Deus'));
      expect(titles, contains('Folheto: Oração'));
      expect(titles, contains('Folheto: Jesus'));
      expect(titles, contains('Folheto: Reino de Deus'));
      expect(titles, contains('Folheto: Sofrimento'));
      expect(titles, contains('Folheto: Morte'));
      expect(titles, contains('Folheto: Religião'));

      // Verifica os temas dos novos folhetos
      final futuro = folhetos.firstWhere((f) => f.title == 'Folheto: Futuro');
      expect(futuro.coverTheme, equals('Como você vê o futuro?'));

      final familia = folhetos.firstWhere((f) => f.title == 'Folheto: Família');
      expect(familia.coverTheme, equals('O que pode ajudar sua família a ser feliz?'));

      // Não possui os códigos antigos T-30 a T-37
      expect(titles.any((t) => t.contains('T-30')), isFalse);
      expect(titles.any((t) => t.contains('T-37')), isFalse);
    });

    test('Brochura Escute a Deus e Viva para Sempre possui contagens reais variadas de parágrafos', () {
      expect(ListenToGodCatalog.lessons.length, equals(14));
      final paragraphs = ListenToGodCatalog.lessons.map((l) => l.paragraphs).toList();

      // Não são todos padronizados em 4
      expect(paragraphs.toSet().length, greaterThan(1));
      expect(paragraphs, contains(5));
      expect(paragraphs, contains(6));
      expect(paragraphs, contains(7));
    });

    test('LffBookCatalog possui 3 pontos para Lições 1 a 3 e 6 pontos para Lições 4 a 60', () {
      for (int i = 1; i <= 3; i++) {
        expect(LffBookCatalog.getLesson(i)!.pointTitles.length, equals(3), reason: 'Lição $i deve ter 3 pontos');
      }
      for (int i = 4; i <= 60; i++) {
        expect(LffBookCatalog.getLesson(i)!.pointTitles.length, equals(6), reason: 'Lição $i deve ter 6 pontos');
      }
    });
  });

  group('Composição e Decomposição de Endereço com Bairro e Setor', () {
    test('Decompõe endereço unificado com Bairro e Ref corretamente', () {
      const rawAddr = 'Rua das Flores, 120 - Bairro: Betânia - Ref: Próximo à padaria';
      final parts = rawAddr.split(' - ');
      String street = '';
      String neighborhood = '';
      String reference = '';

      for (final p in parts) {
        final t = p.trim();
        if (t.toLowerCase().startsWith('bairro:')) {
          neighborhood = t.substring(7).trim();
        } else if (t.toLowerCase().startsWith('ref:')) {
          reference = t.substring(4).trim();
        } else {
          street = t;
        }
      }

      expect(street, equals('Rua das Flores, 120'));
      expect(neighborhood, equals('Betânia'));
      expect(reference, equals('Próximo à padaria'));

      // Recomposição
      final addrParts = <String>[];
      if (street.isNotEmpty) addrParts.add(street);
      if (neighborhood.isNotEmpty) addrParts.add('Bairro: $neighborhood');
      if (reference.isNotEmpty) addrParts.add('Ref: $reference');
      final reconstructed = addrParts.join(' - ');

      expect(reconstructed, equals(rawAddr));
    });
  });
}

