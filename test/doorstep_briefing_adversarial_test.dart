import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/contacts/doorstep_briefing_helper.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/ui/widgets/doorstep_briefing_card.dart';

PersonEntry _mockPerson({
  String id = 'adv-p-1',
  String name = 'Morador Teste',
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

BibleStudyEntry _mockStudy({
  String id = 'adv-s-1',
  String title = 'Estudo Teste',
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

VisitEntry _mockVisit({
  String id = 'adv-v-1',
  String personId = 'adv-p-1',
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
  group('ADV-01: Fuzzing de Strings Extremas e Unicode Complexo', () {
    test('Unicode, zero-width, emojis complexos e RTL markers', () {
      const complexUnicode = '👨‍👩‍👧‍👦 🏳️‍🌈 \u200B\u200C\u200D\uFEFF \u202ETexto RTL Invertido\u202C ﷽';
      final person = _mockPerson(
        generalNotes: jsonEncode([
          {'text': 'Empatia: $complexUnicode', 'createdAt': '2026-10-30T10:00:00Z'}
        ]),
        contactRestrictions: jsonEncode([
          {'title': 'Alvo: $complexUnicode', 'isCompleted': false}
        ]),
        nextActionNote: 'Ação: $complexUnicode',
      );
      final visit = _mockVisit(
        expressedQuestion: 'Dúvida: $complexUnicode',
        scriptureOrPub: 'Salmo 37:11 $complexUnicode',
      );

      final result = DoorstepBriefingHelper.build(
        person: person,
        latestVisit: visit,
      );

      expect(result.pendingDoubt, contains(complexUnicode));
      expect(result.spiritualGoal, contains(complexUnicode));
      expect(result.empathyNote, contains(complexUnicode));
      expect(result.lessonAndPoint, contains(complexUnicode));
      expect(result.hasAnyData, isTrue);
    });

    test('Massive String (50.000 caracteres) em todos os campos', () {
      final hugeString = 'X' * 50000;
      final person = _mockPerson(
        generalNotes: jsonEncode([
          {'text': hugeString, 'createdAt': '2026-10-30T12:00:00Z'}
        ]),
        contactRestrictions: jsonEncode([
          {'title': hugeString, 'isCompleted': false}
        ]),
      );
      final visit = _mockVisit(
        expressedQuestion: hugeString,
        scriptureOrPub: hugeString,
      );

      final stopwatch = Stopwatch()..start();
      final result = DoorstepBriefingHelper.build(
        person: person,
        latestVisit: visit,
      );
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      expect(result.pendingDoubt!.length, equals(50000));
      expect(result.spiritualGoal!.length, equals(50000));
      expect(result.empathyNote!.length, equals(50000));
    });

    test('Whitespace padrão puro (tabs, newlines, NBSP, espaços)', () {
      const standardWhitespace = '  \t\r\n \u00A0  ';
      final person = _mockPerson(
        generalNotes: jsonEncode([
          {'text': standardWhitespace, 'createdAt': '2026-10-30T10:00:00Z'}
        ]),
        contactRestrictions: jsonEncode([
          {'title': standardWhitespace, 'isCompleted': false}
        ]),
        nextActionNote: standardWhitespace,
      );
      final visit = _mockVisit(
        expressedQuestion: standardWhitespace,
        nextStep: standardWhitespace,
        notes: standardWhitespace,
        scriptureOrPub: standardWhitespace,
        topicsDiscussed: standardWhitespace,
      );

      final result = DoorstepBriefingHelper.build(
        person: person,
        latestVisit: visit,
      );

      expect(result.hasLessonOrTopic, isFalse);
      expect(result.hasPendingDoubt, isFalse);
      expect(result.hasSpiritualGoal, isFalse);
      expect(result.hasEmpathyNote, isFalse);
      expect(result.hasAnyData, isFalse);
    });

    test('Comportamento com caracteres invisíveis de formatação (zero-width space U+200B)', () {
      const zwString = '\u200B';
      final visit = _mockVisit(
        scriptureOrPub: zwString,
        topicsDiscussed: zwString,
      );

      final result = DoorstepBriefingHelper.build(
        person: _mockPerson(),
        latestVisit: visit,
      );

      // Dart trim() padrão não remove U+200B (categoria Cf - Format), mantendo-o como caractere de formatação
      expect(result.hasLessonOrTopic, isTrue);
      expect(result.lessonAndPoint, equals('\u200B — \u200B'));
    });
  });

  group('ADV-02: Corrupção Estrutural de JSON em parseNotes e parseTargets', () {
    test('JSON com tipos primitivos inesperados: int, bool, null literal', () {
      expect(DoorstepBriefingHelper.parseNotes('12345'), isNotEmpty);
      expect(DoorstepBriefingHelper.parseNotes('true'), isNotEmpty);
      expect(DoorstepBriefingHelper.parseTargets('999'), isNotEmpty);
      expect(DoorstepBriefingHelper.parseTargets('false'), isNotEmpty);
    });

    test('JSON lista contendo elementos heterogêneos inválidos (primitivos misturados com mapas)', () {
      const mixedJson = '[1, "string", true, null, [], {"text": "Nota Real", "createdAt": "2026-10-30T15:00:00Z"}]';
      final notes = DoorstepBriefingHelper.parseNotes(mixedJson);
      expect(notes.length, equals(1));
      expect(notes.first['text'], equals('Nota Real'));

      const mixedTargets = '[null, 42, {"title": "Alvo Válido", "isCompleted": false}]';
      final targets = DoorstepBriefingHelper.parseTargets(mixedTargets);
      expect(targets.length, equals(1));
      expect(targets.first['title'], equals('Alvo Válido'));
    });

    test('Valores não-string em text e title (ex: inteiros, booleanos)', () {
      final person = _mockPerson(
        generalNotes: jsonEncode([
          {'text': 123456, 'createdAt': '2026-10-30T10:00:00Z'}
        ]),
        contactRestrictions: jsonEncode([
          {'title': 987654, 'isCompleted': false}
        ]),
      );

      final result = DoorstepBriefingHelper.build(person: person);
      expect(result.empathyNote, equals('123456'));
      expect(result.spiritualGoal, equals('987654'));
    });

    test('JSON truncado no meio de uma chave ou valor', () {
      const truncated = '[{"text": "Incompleto...';
      final notes = DoorstepBriefingHelper.parseNotes(truncated);
      // Não deve lançar FormatException, deve tratar como texto legado
      expect(notes.length, equals(1));
      expect(notes.first['text'], equals(truncated));
    });

    test('Ordenação com datas corrompidas ou mistas em generalNotes', () {
      final person = _mockPerson(
        generalNotes: jsonEncode([
          {'text': 'Sem data'},
          {'text': 'Data inválida', 'createdAt': 'invalid-date-string'},
          {'text': 'Nota antiga', 'createdAt': '2025-01-01T00:00:00Z'},
          {'text': 'Nota recente', 'createdAt': '2026-10-25T00:00:00Z'},
          {'text': 'Nota novíssima', 'createdAt': '2026-10-30T00:00:00Z'},
        ]),
      );

      final result = DoorstepBriefingHelper.build(person: person);
      expect(result.empathyNote, equals('Nota novíssima'));
    });

    test('Benchmark de desempenho de ordenação com volumes realistas (50 e 100 notas)', () {
      final hundredNotes = List.generate(
        100,
        (i) => {
          'id': 'n-$i',
          'text': 'Observação $i',
          'createdAt': DateTime(2025, 1, 1).add(Duration(days: i)).toIso8601String(),
        },
      );
      final person = _mockPerson(generalNotes: jsonEncode(hundredNotes));

      final stopwatch = Stopwatch()..start();
      final result = DoorstepBriefingHelper.build(person: person);
      stopwatch.stop();

      // Para 100 notas, deve executar com folga dentro de 2000ms mesmo sob carga paralela de CPU
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
      expect(result.empathyNote, equals('Observação 99'));
    });
  });

  group('ADV-03: Casos Limítrofes de Lição, Publicação e Deep Link', () {
    test('Lição e Parágrafo com valores numéricos incomuns (0, negativos, gigantes)', () {
      final studyZero = _mockStudy(
        currentLesson: 0,
        currentParagraph: 0,
      );
      final resZero = DoorstepBriefingHelper.build(person: _mockPerson(), linkedStudy: studyZero);
      expect(resZero.lessonAndPoint, equals('Lição 00, Ponto 0'));

      final studyHuge = _mockStudy(
        currentLesson: 9999,
        currentParagraph: 99999,
      );
      final resHuge = DoorstepBriefingHelper.build(person: _mockPerson(), linkedStudy: studyHuge);
      expect(resHuge.lessonAndPoint, equals('Lição 9999, Ponto 99999'));

      final studyNeg = _mockStudy(
        currentLesson: -5,
        currentParagraph: -1,
      );
      final resNeg = DoorstepBriefingHelper.build(person: _mockPerson(), linkedStudy: studyNeg);
      expect(resNeg.lessonAndPoint, equals('Lição -5, Ponto -1'));
    });

    test('Publicação inexistente no catálogo (não causa crash, fallback gracioso)', () {
      final study = _mockStudy(
        publicationId: 'non-existent-pub-xyz-999',
        title: 'Brochura Customizada',
        currentLesson: 3,
        currentParagraph: 2,
      );

      final result = DoorstepBriefingHelper.build(
        person: _mockPerson(),
        linkedStudy: study,
      );

      expect(result.lessonAndPoint, equals('Lição 03, Ponto 2'));
      expect(result.publicationTitle, equals('Brochura Customizada'));
    });

    test('Título com apenas espaços e fallback para título do catálogo', () {
      final study = _mockStudy(
        publicationId: 'lff-book',
        title: '   ',
        currentLesson: null,
        currentParagraph: null,
        manualReference: null,
      );

      final result = DoorstepBriefingHelper.build(
        person: _mockPerson(),
        linkedStudy: study,
      );

      expect(result.lessonAndPoint, isNotNull);
      expect(result.lessonAndPoint, isNot(equals('   ')));
    });
  });

  group('ADV-04: Resiliência de Layout e Acessibilidade do Widget (DoorstepBriefingCard)', () {
    testWidgets('Texto ultra-longo (10.000 chars sem quebras) não quebra renderização', (tester) async {
      final hugeWord = 'Inquebrável' * 1000;
      final data = DoorstepBriefingData(
        lessonAndPoint: hugeWord,
        pendingDoubt: hugeWord,
        spiritualGoal: hugeWord,
        empathyNote: hugeWord,
        jwLibraryUri: Uri.parse('https://www.jw.org'),
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

      expect(tester.takeException(), isNull);
      expect(find.byType(DoorstepBriefingCard), findsOneWidget);
    });

    testWidgets('Escalonamento Extremo de Fonte (TextScaler 3.0x - Baixa Visão Severa)', (tester) async {
      final data = DoorstepBriefingData(
        lessonAndPoint: 'Lição 05, Ponto 4',
        pendingDoubt: 'Como explicar a criação para colegas de trabalho?',
        spiritualGoal: 'Comentar com as próprias palavras',
        empathyNote: 'Filho iniciou o ano letivo na nova escola',
        jwLibraryUri: Uri.parse('https://www.jw.org'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(3.0),
              ),
              child: SingleChildScrollView(
                child: DoorstepBriefingCard(data: data),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Briefing na Porta'), findsOneWidget);
      expect(find.text('30s'), findsOneWidget);
    });

    testWidgets('Largura Extremamente Estreita (240dp - Telas compactas/Smartwatches)', (tester) async {
      final data = DoorstepBriefingData(
        lessonAndPoint: 'Lição 10',
        pendingDoubt: 'Dúvida curta',
        spiritualGoal: 'Alvo curto',
        empathyNote: 'Nota curta',
        jwLibraryUri: Uri.parse('https://www.jw.org'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 240,
              child: SingleChildScrollView(
                child: DoorstepBriefingCard(data: data),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(DoorstepBriefingCard), findsOneWidget);
    });

    testWidgets('Disparo rápido consecutivo (20 cliques rápidos no botão JW Library)', (tester) async {
      int tapCount = 0;
      final data = DoorstepBriefingData(
        lessonAndPoint: 'Lição 01',
        jwLibraryUri: Uri.parse('https://www.jw.org'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DoorstepBriefingCard(
              data: data,
              onOpenJwLibrary: () => tapCount++,
            ),
          ),
        ),
      );

      final button = find.widgetWithText(ElevatedButton, 'Abrir no JW Library');
      expect(button, findsOneWidget);

      for (int i = 0; i < 20; i++) {
        await tester.tap(button);
      }
      await tester.pump();

      expect(tapCount, equals(20));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Modo Sol Intenso com ThemeData Customizado', (tester) async {
      final sunTheme = ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        cardTheme: const CardThemeData(
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Color(0xFF000000), width: 2.5),
          ),
        ),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF000000),
        ),
      );

      final data = DoorstepBriefingData(
        lessonAndPoint: 'Lição 08',
        pendingDoubt: 'Dúvida teste',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: sunTheme,
          home: Scaffold(
            body: DoorstepBriefingCard(data: data),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(DoorstepBriefingCard), findsOneWidget);
    });
  });

  group('ADV-05: Reatividade de Streams Rápidas (StreamBuilder Lifecycle)', () {
    testWidgets('Stream de visitas com rajada de 30 emissões consecutivas', (tester) async {
      final controller = StreamController<List<VisitEntry>>.broadcast();
      final person = _mockPerson();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamBuilder<List<VisitEntry>>(
              stream: controller.stream,
              builder: (context, snapshot) {
                final latestVisit = (snapshot.data ?? []).firstOrNull;
                final data = DoorstepBriefingHelper.build(
                  person: person,
                  latestVisit: latestVisit,
                );
                return DoorstepBriefingCard(data: data);
              },
            ),
          ),
        ),
      );

      // Estado inicial vazio
      expect(find.textContaining('Primeiro contato sem histórico registrado'), findsOneWidget);

      // Rajada de 30 emissões rápidas
      for (int i = 1; i <= 30; i++) {
        final visit = _mockVisit(
          id: 'v-$i',
          expressedQuestion: 'Pergunta $i emitida em rajada',
        );
        controller.add([visit]);
        await tester.pump();
      }

      // Deve refletir a última emissão
      expect(find.text('Pergunta 30 emitida em rajada'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await controller.close();
    });
  });
}
