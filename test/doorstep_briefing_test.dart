import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/contacts/doorstep_briefing_helper.dart';
import 'package:ministerio_pessoal/core/app_theme.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/ui/widgets/doorstep_briefing_card.dart';

PersonEntry _createPerson({
  String id = 'p-1',
  String name = 'Nome Teste',
  DateTime? firstContactAt,
  String status = 'interessado',
  String? preferredSchedule,
  String? generalNotes,
  String? contactRestrictions,
  String tags = '[]',
  DateTime? lastContactAt,
  DateTime? nextActionAt,
  String? nextActionNote,
  DateTime? createdAt,
  DateTime? updatedAt,
  int revision = 1,
}) {
  final now = DateTime(2026, 10, 30, 10, 0);
  return PersonEntry(
    id: id,
    name: name,
    firstContactAt: firstContactAt ?? now,
    status: status,
    preferredSchedule: preferredSchedule,
    generalNotes: generalNotes,
    contactRestrictions: contactRestrictions,
    tags: tags,
    lastContactAt: lastContactAt,
    nextActionAt: nextActionAt,
    nextActionNote: nextActionNote,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    revision: revision,
  );
}

BibleStudyEntry _createStudy({
  String id = 's-1',
  String title = 'Estudo de Teste',
  String ownerId = 'local_user',
  DateTime? startedAt,
  String status = 'ativo',
  String publicationId = 'lff-book',
  String language = 'pt',
  int? currentLesson,
  int? currentParagraph,
  String? manualReference,
  String frequency = 'semanal',
  String? learningGoals,
  String? pendingDoubts,
  String? nextTopic,
  DateTime? createdAt,
  DateTime? updatedAt,
  int revision = 1,
}) {
  final now = DateTime(2026, 10, 30, 10, 0);
  return BibleStudyEntry(
    id: id,
    title: title,
    ownerId: ownerId,
    startedAt: startedAt ?? now,
    status: status,
    publicationId: publicationId,
    language: language,
    currentLesson: currentLesson,
    currentParagraph: currentParagraph,
    manualReference: manualReference,
    frequency: frequency,
    learningGoals: learningGoals,
    pendingDoubts: pendingDoubts,
    nextTopic: nextTopic,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    revision: revision,
  );
}

VisitEntry _createVisit({
  String id = 'v-1',
  String personId = 'p-1',
  DateTime? dateTimeField,
  String contactType = 'revisita',
  String result = 'revisita_feita',
  String? notes,
  String? topicsDiscussed,
  String? scriptureOrPub,
  String? expressedQuestion,
  String? nextStep,
  DateTime? suggestedReturnDate,
  String? appointmentId,
  DateTime? createdAt,
  DateTime? updatedAt,
  int revision = 1,
}) {
  final now = DateTime(2026, 10, 30, 10, 0);
  return VisitEntry(
    id: id,
    personId: personId,
    dateTimeField: dateTimeField ?? now,
    contactType: contactType,
    result: result,
    notes: notes,
    topicsDiscussed: topicsDiscussed,
    scriptureOrPub: scriptureOrPub,
    expressedQuestion: expressedQuestion,
    nextStep: nextStep,
    suggestedReturnDate: suggestedReturnDate,
    appointmentId: appointmentId,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    revision: revision,
  );
}

void main() {
  group('DoorstepBriefingHelper - Onde Parou (Lição, Ponto e JW Library Link)', () {
    test('TC-01: Estudo com lição 4 e parágrafo 3 (lff-book)', () {
      final person = _createPerson();
      final study = _createStudy(
        publicationId: 'lff-book',
        language: 'pt',
        currentLesson: 4,
        currentParagraph: 3,
      );

      final briefing = DoorstepBriefingHelper.build(
        person: person,
        linkedStudy: study,
      );

      expect(briefing.lessonAndPoint, equals('Lição 04, Ponto 3'));
      expect(briefing.jwLibraryUri, isNotNull);
      expect(briefing.jwLibraryUri.toString(), contains('pub=lff&lesson=4'));
      expect(briefing.hasLessonOrTopic, isTrue);
      expect(briefing.hasJwLibraryLink, isTrue);
    });

    test('TC-02: Estudo com lição 12 e parágrafo null', () {
      final person = _createPerson();
      final study = _createStudy(
        publicationId: 'lff-book',
        language: 'pt',
        currentLesson: 12,
        currentParagraph: null,
      );

      final briefing = DoorstepBriefingHelper.build(
        person: person,
        linkedStudy: study,
      );

      expect(briefing.lessonAndPoint, equals('Lição 12'));
      expect(briefing.jwLibraryUri, isNotNull);
      expect(briefing.jwLibraryUri.toString(), contains('pub=lff&lesson=12'));
    });

    test('TC-03: Estudo com apenas parágrafo 5', () {
      final person = _createPerson();
      final study = _createStudy(
        currentLesson: null,
        currentParagraph: 5,
      );

      final briefing = DoorstepBriefingHelper.build(
        person: person,
        linkedStudy: study,
      );

      expect(briefing.lessonAndPoint, equals('Ponto 5'));
    });

    test('TC-04: Estudo com manualReference', () {
      final person = _createPerson();
      final study = _createStudy(
        currentLesson: null,
        currentParagraph: null,
        manualReference: 'Sentinela 02/2026',
      );

      final briefing = DoorstepBriefingHelper.build(
        person: person,
        linkedStudy: study,
      );

      expect(briefing.lessonAndPoint, equals('Sentinela 02/2026'));
    });

    test('TC-05: Estudo com apenas title: "Estudo Bíblico"', () {
      final person = _createPerson();
      final study = _createStudy(
        title: 'Estudo Bíblico',
        currentLesson: null,
        currentParagraph: null,
        manualReference: null,
      );

      final briefing = DoorstepBriefingHelper.build(
        person: person,
        linkedStudy: study,
      );

      expect(briefing.lessonAndPoint, equals('Estudo Bíblico'));
    });

    test('TC-06: Sem estudo; última visita com scriptureOrPub e topicsDiscussed', () {
      final person = _createPerson();
      final visit = _createVisit(
        scriptureOrPub: 'Sl 37:11',
        topicsDiscussed: 'Futuro',
      );

      final briefing = DoorstepBriefingHelper.build(
        person: person,
        latestVisit: visit,
      );

      expect(briefing.lessonAndPoint, equals('Sl 37:11 — Futuro'));
      expect(briefing.jwLibraryUri, isNull);
    });

    test('TC-07: Sem estudo; última visita com apenas scriptureOrPub', () {
      final person = _createPerson();
      final visit = _createVisit(
        scriptureOrPub: 'Sl 37:11',
        topicsDiscussed: null,
      );

      final briefing = DoorstepBriefingHelper.build(
        person: person,
        latestVisit: visit,
      );

      expect(briefing.lessonAndPoint, equals('Sl 37:11'));
      expect(briefing.jwLibraryUri, isNull);
    });

    test('TC-08: Sem estudo; última visita com apenas topicsDiscussed', () {
      final person = _createPerson();
      final visit = _createVisit(
        scriptureOrPub: null,
        topicsDiscussed: 'Futuro',
      );

      final briefing = DoorstepBriefingHelper.build(
        person: person,
        latestVisit: visit,
      );

      expect(briefing.lessonAndPoint, equals('Futuro'));
      expect(briefing.jwLibraryUri, isNull);
    });

    test('TC-09: Sem estudo e sem visita', () {
      final person = _createPerson();

      final briefing = DoorstepBriefingHelper.build(
        person: person,
      );

      expect(briefing.lessonAndPoint, isNull);
      expect(briefing.jwLibraryUri, isNull);
    });
  });

  group('DoorstepBriefingHelper - Pendências da Última Visita (Precedência)', () {
    test('TC-10: latestVisit.expressedQuestion tem primeira prioridade', () {
      final person = _createPerson(nextActionNote: 'Ação da pessoa');
      final study = _createStudy(pendingDoubts: 'Dúvida do estudo');
      final visit = _createVisit(
        expressedQuestion: 'Por que sofremos?',
        nextStep: 'Voltar quinta',
        notes: 'Nota da visita',
      );

      final briefing = DoorstepBriefingHelper.build(
        person: person,
        linkedStudy: study,
        latestVisit: visit,
      );

      expect(briefing.pendingDoubt, equals('Por que sofremos?'));
    });

    test('TC-11: expressedQuestion nulo, fallback para latestVisit.nextStep', () {
      final person = _createPerson(nextActionNote: 'Ação da pessoa');
      final study = _createStudy(pendingDoubts: 'Dúvida do estudo');
      final visit = _createVisit(
        expressedQuestion: null,
        nextStep: 'Voltar quinta',
        notes: 'Nota da visita',
      );

      final briefing = DoorstepBriefingHelper.build(
        person: person,
        linkedStudy: study,
        latestVisit: visit,
      );

      expect(briefing.pendingDoubt, equals('Voltar quinta'));
    });

    test('TC-12: Questão e próximo passo nulos, fallback para study.pendingDoubts', () {
      final person = _createPerson(nextActionNote: 'Ação da pessoa');
      final study = _createStudy(pendingDoubts: 'Dúvida sobre trindade');
      final visit = _createVisit(
        expressedQuestion: null,
        nextStep: null,
        notes: 'Nota da visita',
      );

      final briefing = DoorstepBriefingHelper.build(
        person: person,
        linkedStudy: study,
        latestVisit: visit,
      );

      expect(briefing.pendingDoubt, equals('Dúvida sobre trindade'));
    });

    test('TC-12b: Questão, próximo passo e dúvidas nulos, fallback para study.nextTopic', () {
      final person = _createPerson();
      final study = _createStudy(
        pendingDoubts: null,
        nextTopic: 'Ressurreição',
      );
      final visit = _createVisit(
        expressedQuestion: null,
        nextStep: null,
        notes: null,
      );

      final briefing = DoorstepBriefingHelper.build(
        person: person,
        linkedStudy: study,
        latestVisit: visit,
      );

      expect(briefing.pendingDoubt, equals('Ressurreição'));
    });

    test('TC-12c: Sem pendências de estudo nem pergunta/próximo passo, fallback para visit.notes', () {
      final person = _createPerson(nextActionNote: 'Ação da pessoa');
      final visit = _createVisit(
        expressedQuestion: null,
        nextStep: null,
        notes: 'Pediu para falar sobre oração',
      );

      final briefing = DoorstepBriefingHelper.build(
        person: person,
        latestVisit: visit,
      );

      expect(briefing.pendingDoubt, equals('Pediu para falar sobre oração'));
    });

    test('TC-13: Sem visitas, mas linkedStudy.pendingDoubts preenchido', () {
      final person = _createPerson();
      final study = _createStudy(pendingDoubts: 'Dúvida sobre trindade');

      final briefing = DoorstepBriefingHelper.build(
        person: person,
        linkedStudy: study,
      );

      expect(briefing.pendingDoubt, equals('Dúvida sobre trindade'));
    });

    test('TC-14: Sem visitas e sem estudo, fallback para person.nextActionNote', () {
      final person = _createPerson(nextActionNote: 'Levar revista');

      final briefing = DoorstepBriefingHelper.build(
        person: person,
      );

      expect(briefing.pendingDoubt, equals('Levar revista'));
    });

    test('TC-15: Todos os campos de pendência nulos ou vazios', () {
      final person = _createPerson(nextActionNote: '   ');
      final study = _createStudy(pendingDoubts: '   ', nextTopic: '   ');
      final visit = _createVisit(
        expressedQuestion: '   ',
        nextStep: '   ',
        notes: '   ',
      );

      final briefing = DoorstepBriefingHelper.build(
        person: person,
        linkedStudy: study,
        latestVisit: visit,
      );

      expect(briefing.pendingDoubt, isNull);
    });
  });

  group('DoorstepBriefingHelper - Alvo Espiritual', () {
    test('TC-16: contactRestrictions com 2 alvos; 1º concluído e 2º ativo', () {
      final person = _createPerson(
        contactRestrictions: jsonEncode([
          {'id': 't-1', 'title': 'Alvo 1 Concluído', 'isCompleted': true},
          {'id': 't-2', 'title': 'Ler o Salmo 37 até terça', 'isCompleted': false},
        ]),
      );

      final briefing = DoorstepBriefingHelper.build(person: person);

      expect(briefing.spiritualGoal, equals('Ler o Salmo 37 até terça'));
    });

    test('TC-17: contactRestrictions com todos concluídos, fallback para study.learningGoals', () {
      final person = _createPerson(
        contactRestrictions: jsonEncode([
          {'id': 't-1', 'title': 'Alvo Concluído', 'isCompleted': true},
        ]),
      );
      final study = _createStudy(learningGoals: 'Ler João');

      final briefing = DoorstepBriefingHelper.build(
        person: person,
        linkedStudy: study,
      );

      expect(briefing.spiritualGoal, equals('Ler João'));
    });

    test('TC-18: contactRestrictions com texto puro legado', () {
      final person = _createPerson(
        contactRestrictions: 'Assistir reunião',
      );

      final briefing = DoorstepBriefingHelper.build(person: person);

      expect(briefing.spiritualGoal, equals('Assistir reunião'));
    });

    test('TC-19: contactRestrictions vazio/nulo, fallback para study.learningGoals', () {
      final person = _createPerson(contactRestrictions: null);
      final study = _createStudy(learningGoals: 'Fazer oração');

      final briefing = DoorstepBriefingHelper.build(
        person: person,
        linkedStudy: study,
      );

      expect(briefing.spiritualGoal, equals('Fazer oração'));
    });

    test('TC-20: Sem alvos e sem estudo', () {
      final person = _createPerson(contactRestrictions: null);

      final briefing = DoorstepBriefingHelper.build(person: person);

      expect(briefing.spiritualGoal, isNull);
    });
  });

  group('DoorstepBriefingHelper - Toque de Empatia (Observações Pessoais)', () {
    test('TC-21: generalNotes JSON com 2 notas com datas; seleciona nota mais recente', () {
      final person = _createPerson(
        generalNotes: jsonEncode([
          {'id': 'n-1', 'text': 'Nota antiga', 'createdAt': '2026-10-20T10:00:00Z'},
          {'id': 'n-2', 'text': 'Mãe internada com pneumonia', 'createdAt': '2026-10-28T10:00:00Z'},
        ]),
      );

      final briefing = DoorstepBriefingHelper.build(person: person);

      expect(briefing.empathyNote, equals('Mãe internada com pneumonia'));
    });

    test('TC-22: generalNotes texto puro legado', () {
      final person = _createPerson(
        generalNotes: 'Mãe esteve doente semana passada',
      );

      final briefing = DoorstepBriefingHelper.build(person: person);

      expect(briefing.empathyNote, equals('Mãe esteve doente semana passada'));
    });

    test('TC-23: generalNotes vazio ou nulo ou array vazio []', () {
      final p1 = _createPerson(generalNotes: '[]');
      final p2 = _createPerson(generalNotes: null);
      final p3 = _createPerson(generalNotes: '   ');

      expect(DoorstepBriefingHelper.build(person: p1).empathyNote, isNull);
      expect(DoorstepBriefingHelper.build(person: p2).empathyNote, isNull);
      expect(DoorstepBriefingHelper.build(person: p3).empathyNote, isNull);
    });

    test('TC-24: generalNotes contendo notas com texto em branco ou nulo', () {
      final person = _createPerson(
        generalNotes: jsonEncode([
          {'id': 'n-1', 'text': '   ', 'createdAt': '2026-10-29T10:00:00Z'},
          {'id': 'n-2', 'text': 'Família viajou para o interior', 'createdAt': '2026-10-28T10:00:00Z'},
        ]),
      );

      final briefing = DoorstepBriefingHelper.build(person: person);

      expect(briefing.empathyNote, equals('Família viajou para o interior'));
    });
  });

  group('DoorstepBriefingHelper - Casos de Borda e Resiliência', () {
    test('TC-25: PersonEntry mínimo, sem estudo, sem visita', () {
      final person = _createPerson();

      final briefing = DoorstepBriefingHelper.build(person: person);

      expect(briefing.lessonAndPoint, isNull);
      expect(briefing.jwLibraryUri, isNull);
      expect(briefing.pendingDoubt, isNull);
      expect(briefing.spiritualGoal, isNull);
      expect(briefing.empathyNote, isNull);
      expect(briefing.hasAnyData, isFalse);
    });

    test('TC-26: Strings com espaços em branco em todos os campos', () {
      final person = _createPerson(
        contactRestrictions: '   ',
        generalNotes: '   ',
        nextActionNote: '   ',
      );
      final study = _createStudy(
        manualReference: '   ',
        pendingDoubts: '   ',
        learningGoals: '   ',
        currentLesson: null,
        currentParagraph: null,
        title: '   ',
      );
      final visit = _createVisit(
        scriptureOrPub: '   ',
        topicsDiscussed: '   ',
        expressedQuestion: '   ',
        nextStep: '   ',
        notes: '   ',
      );

      final briefing = DoorstepBriefingHelper.build(
        person: person,
        linkedStudy: study,
        latestVisit: visit,
      );

      expect(briefing.pendingDoubt, isNull);
      expect(briefing.spiritualGoal, isNull);
      expect(briefing.empathyNote, isNull);
    });

    test('TC-27: JSON corrompido em contactRestrictions e generalNotes tratado com segurança', () {
      final person = _createPerson(
        contactRestrictions: '{corrupted json',
        generalNotes: '{bad json',
      );

      final briefing = DoorstepBriefingHelper.build(person: person);

      expect(briefing.spiritualGoal, equals('{corrupted json'));
      expect(briefing.empathyNote, equals('{bad json'));
    });

    test('TC-28: Igualdade (==) e hashCode de DoorstepBriefingData', () {
      final d1 = DoorstepBriefingData(
        lessonAndPoint: 'Lição 04',
        jwLibraryUri: Uri.parse('https://www.jw.org/finder?srcid=jwlshare&wtlocale=T&pub=lff&lesson=4'),
        pendingDoubt: 'Dúvida',
        spiritualGoal: 'Alvo',
        empathyNote: 'Nota',
        publicationTitle: 'Livro LFF',
      );

      final d2 = DoorstepBriefingData(
        lessonAndPoint: 'Lição 04',
        jwLibraryUri: Uri.parse('https://www.jw.org/finder?srcid=jwlshare&wtlocale=T&pub=lff&lesson=4'),
        pendingDoubt: 'Dúvida',
        spiritualGoal: 'Alvo',
        empathyNote: 'Nota',
        publicationTitle: 'Livro LFF',
      );

      expect(d1, equals(d2));
      expect(d1.hashCode, equals(d2.hashCode));
      expect(d1.toString(), contains('Lição 04'));
    });
  });

  group('DoorstepBriefingCard - Testes de Widget', () {
    testWidgets('TC-W1: Renderização completa com todos os campos e disparo de callbacks', (tester) async {
      var tappedOpen = 0;

      final data = DoorstepBriefingData(
        lessonAndPoint: 'Lição 04, Ponto 3',
        publicationTitle: 'Seja Feliz para Sempre!',
        jwLibraryUri: Uri.parse('https://www.jw.org/finder?srcid=jwlshare&wtlocale=T&pub=lff&lesson=4'),
        pendingDoubt: 'Por que Deus permite o sofrimento?',
        spiritualGoal: 'Baixar o app JW Library',
        empathyNote: 'Mãe internada com pneumonia',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DoorstepBriefingCard(
                data: data,
                onOpenJwLibrary: () => tappedOpen++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Briefing na Porta'), findsOneWidget);
      expect(find.text('30s'), findsOneWidget);
      expect(find.text('Lição 04, Ponto 3'), findsOneWidget);
      expect(find.text('Seja Feliz para Sempre!'), findsOneWidget);
      expect(find.text('Por que Deus permite o sofrimento?'), findsOneWidget);
      expect(find.text('Baixar o app JW Library'), findsOneWidget);
      expect(find.text('Mãe internada com pneumonia'), findsOneWidget);

      final btn = find.widgetWithText(ElevatedButton, 'Abrir no JW Library');
      expect(btn, findsOneWidget);

      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(tappedOpen, equals(1));
    });

    testWidgets('TC-W1b: Disparo do callback alternativo onLaunchJwLibrary', (tester) async {
      Uri? launchedUri;

      final data = DoorstepBriefingData(
        lessonAndPoint: 'Lição 04, Ponto 3',
        jwLibraryUri: Uri.parse('https://www.jw.org/finder?srcid=jwlshare&wtlocale=T&pub=lff&lesson=4'),
        pendingDoubt: 'Dúvida',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DoorstepBriefingCard(
                data: data,
                onLaunchJwLibrary: (uri) => launchedUri = uri,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final btn = find.widgetWithText(ElevatedButton, 'Abrir no JW Library');
      expect(btn, findsOneWidget);

      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(launchedUri, isNotNull);
      expect(launchedUri.toString(), contains('pub=lff&lesson=4'));
    });

    testWidgets('TC-W2: Texto longo de 500 caracteres em dúvidas e notas não causa overflow', (tester) async {
      final longDoubt = 'D' * 500;
      final longNote = 'N' * 500;

      final data = DoorstepBriefingData(
        lessonAndPoint: 'Lição 02',
        pendingDoubt: longDoubt,
        spiritualGoal: 'Alvo Normal',
        empathyNote: longNote,
      );

      tester.view.physicalSize = const Size(414, 896); // iPhone XR
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DoorstepBriefingCard(data: data),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('TC-W3: Renderização em Alto Contraste (sunModeTheme) preserva alvo de toque >= 48dp', (tester) async {
      final data = DoorstepBriefingData(
        lessonAndPoint: 'Lição 05',
        jwLibraryUri: Uri.parse('https://www.jw.org/finder?srcid=jwlshare&wtlocale=T&pub=lff&lesson=5'),
        pendingDoubt: 'Dúvida rápida',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.sunModeTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DoorstepBriefingCard(data: data),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.byType(Card);
      expect(cardFinder, findsOneWidget);

      final buttonFinder = find.byType(ElevatedButton);
      expect(buttonFinder, findsOneWidget);

      final size = tester.getSize(buttonFinder);
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('TC-W4: Ocultação do botão JW Library quando não há link nem callback', (tester) async {
      final data = const DoorstepBriefingData(
        lessonAndPoint: 'Sl 37:11 — Futuro',
        pendingDoubt: 'Conversar na sexta',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DoorstepBriefingCard(data: data),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Abrir no JW Library'), findsNothing);
    });

    testWidgets('TC-W5: Degradação graciosa com campos nulos/vazios exibindo placeholders', (tester) async {
      final data = const DoorstepBriefingData(
        lessonAndPoint: 'Lição 01',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DoorstepBriefingCard(data: data),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sem pendências registradas da última visita'), findsOneWidget);
      expect(find.text('Nenhum alvo espiritual ativo cadastrado'), findsOneWidget);
      expect(find.text('Nenhuma observação pessoal recente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TC-W6: Estado vazio total (!data.hasAnyData) renderiza empty state card', (tester) async {
      final data = const DoorstepBriefingData();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DoorstepBriefingCard(data: data),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Briefing na Porta (30s)'), findsOneWidget);
      expect(find.textContaining('Primeiro contato sem histórico registrado'), findsOneWidget);
      expect(find.text('ONDE PAROU'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TC-W7: Modo noturno (ThemeData.dark()) renderiza sem overflow', (tester) async {
      final data = DoorstepBriefingData(
        lessonAndPoint: 'Lição 03, Ponto 1',
        pendingDoubt: 'Dúvida sobre oração',
        spiritualGoal: 'Orar todos os dias',
        empathyNote: 'Família em recuperação de gripe',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: DoorstepBriefingCard(data: data),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Briefing na Porta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TC-W8: Escalonamento de fontes (Accessibility 1.5x) renderiza sem overflow', (tester) async {
      final data = DoorstepBriefingData(
        lessonAndPoint: 'Lição 04, Ponto 2',
        pendingDoubt: 'Pergunta sobre o Reino de Deus',
        spiritualGoal: 'Assistir a uma reunião',
        empathyNote: 'Trabalha em turno noturno',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: DoorstepBriefingCard(data: data),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Briefing na Porta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
