import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/contacts/doorstep_briefing_helper.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/ui/widgets/doorstep_briefing_card.dart';

void main() {
  final testDate = DateTime(2026, 11, 4, 15, 30);
  final earlierDate = DateTime(2026, 10, 20, 10, 0);

  PersonEntry makePerson({DateTime? lastContactAt}) {
    return PersonEntry(
      id: 'person-1',
      name: 'João Silva',
      status: 'ativo',
      tags: '[]',
      firstContactAt: earlierDate,
      lastContactAt: lastContactAt,
      createdAt: earlierDate,
      updatedAt: earlierDate,
      revision: 1,
    );
  }

  VisitEntry makeVisit({DateTime? dateTime}) {
    return VisitEntry(
      id: 'visit-1',
      personId: 'person-1',
      contactType: 'revisita',
      result: 'atendido',
      dateTimeField: dateTime ?? testDate,
      createdAt: testDate,
      updatedAt: testDate,
      revision: 1,
    );
  }

  group('DoorstepBriefing - Data da Última Visita', () {
    test('Usa dateTimeField da latestVisit quando disponível', () {
      final person = makePerson(lastContactAt: earlierDate);
      final visit = makeVisit(dateTime: testDate);
      final data = DoorstepBriefingHelper.build(
        person: person,
        latestVisit: visit,
      );

      expect(data.lastVisitDate, testDate);
      expect(data.hasLastVisitDate, isTrue);
    });

    test('Fallback para person.lastContactAt quando latestVisit for nulo', () {
      final person = makePerson(lastContactAt: testDate);
      final data = DoorstepBriefingHelper.build(
        person: person,
        latestVisit: null,
      );

      expect(data.lastVisitDate, testDate);
      expect(data.hasLastVisitDate, isTrue);
    });

    test('Retorna lastVisitDate nulo quando person e visit não possuem data', () {
      final person = makePerson(lastContactAt: null);
      final data = DoorstepBriefingHelper.build(
        person: person,
        latestVisit: null,
      );

      expect(data.lastVisitDate, isNull);
      expect(data.hasLastVisitDate, isFalse);
      expect(data.hasAnyData, isFalse);
    });

    test('hasLastVisitDate é verdadeiro e hasAnyData é falso quando apenas lastVisitDate existe', () {
      final data = DoorstepBriefingData(lastVisitDate: testDate);
      expect(data.hasLastVisitDate, isTrue);
      expect(data.hasAnyData, isFalse);
      expect(data.hasLessonOrTopic, isFalse);
    });
    test('Seleciona a data mais recente quando person.lastContactAt for posterior a latestVisit.dateTimeField', () {
      final person = makePerson(lastContactAt: testDate);
      final visit = makeVisit(dateTime: earlierDate);
      final data = DoorstepBriefingHelper.build(
        person: person,
        latestVisit: visit,
      );

      expect(data.lastVisitDate, testDate);
      expect(data.hasLastVisitDate, isTrue);
    });
  });

  group('DoorstepBriefingCard - Renderização da Data da Última Visita', () {
    testWidgets('Exibe última visita no cabeçalho quando briefing possui dados completos', (tester) async {
      final data = DoorstepBriefingData(
        lessonAndPoint: 'Lição 04, Ponto 2',
        lastVisitDate: DateTime(2026, 11, 4),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DoorstepBriefingCard(data: data),
          ),
        ),
      );

      expect(find.text('Briefing na Porta'), findsOneWidget);
      expect(find.textContaining('Última visita: 04/11/2026'), findsOneWidget);
    });

    testWidgets('Exibe última visita no card mesmo sem lição ou notas registradas', (tester) async {
      final data = DoorstepBriefingData(
        lastVisitDate: DateTime(2026, 11, 4),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DoorstepBriefingCard(data: data),
          ),
        ),
      );

      expect(find.textContaining('Última visita: 04/11/2026'), findsOneWidget);
      expect(find.textContaining('Histórico anterior registrado'), findsOneWidget);
    });
  });
}
