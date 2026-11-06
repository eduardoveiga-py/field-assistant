import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/appointments/brazil_holidays.dart';
import 'package:ministerio_pessoal/contacts/doorstep_briefing_helper.dart';
import 'package:ministerio_pessoal/database/app_database.dart';

void main() {
  group('BrazilHolidays', () {
    test('Páscoa 2026 cai em 5 de abril (algoritmo gregoriano)', () {
      expect(BrazilHolidays.easterSunday(2026), DateTime(2026, 4, 5));
    });

    test('Páscoa 2025 cai em 20 de abril', () {
      expect(BrazilHolidays.easterSunday(2025), DateTime(2025, 4, 20));
    });

    test('feriados fixos nacionais estão presentes', () {
      final holidays = BrazilHolidays.forYear(2026);
      bool has(String name, DateTime date) => holidays.any(
        (h) => h.name == name && h.date == date,
      );
      expect(has('Confraternização Universal', DateTime(2026, 1, 1)), isTrue);
      expect(has('Tiradentes', DateTime(2026, 4, 21)), isTrue);
      expect(has('Dia do Trabalho', DateTime(2026, 5, 1)), isTrue);
      expect(has('Independência do Brasil', DateTime(2026, 9, 7)), isTrue);
      expect(has('Nossa Senhora Aparecida', DateTime(2026, 10, 12)), isTrue);
      expect(has('Finados', DateTime(2026, 11, 2)), isTrue);
      expect(has('Proclamação da República', DateTime(2026, 11, 15)), isTrue);
      expect(has('Natal', DateTime(2026, 12, 25)), isTrue);
    });

    test('feriados móveis são derivados da Páscoa', () {
      final holidays = BrazilHolidays.forYear(2026);
      final easter = DateTime(2026, 4, 5);
      bool has(String name, DateTime date) => holidays.any(
        (h) => h.name == name && h.date == date,
      );
      expect(has('Sexta-feira Santa', easter.subtract(const Duration(days: 2))), isTrue);
      expect(has('Páscoa', easter), isTrue);
      expect(has('Corpus Christi', easter.add(const Duration(days: 60))), isTrue);
      expect(
        has('Terça-feira de Carnaval', easter.subtract(const Duration(days: 47))),
        isTrue,
      );
    });

    test('onDay retorna feriado no dia e vazio em dia comum', () {
      expect(BrazilHolidays.onDay(DateTime(2026, 12, 25)).single.name, 'Natal');
      expect(BrazilHolidays.onDay(DateTime(2026, 12, 24)), isEmpty);
    });

    test('inRange respeita o intervalo inclusivo', () {
      final range = BrazilHolidays.inRange(
        DateTime(2026, 12, 20),
        DateTime(2026, 12, 31),
      );
      expect(range.map((h) => h.name), contains('Natal'));
      expect(range.any((h) => h.name == 'Confraternização Universal'), isFalse);
    });
  });

  group('DoorstepBriefingData.lastVisitDate', () {
    PersonEntry _person() {
      final now = DateTime(2026, 10, 30, 10, 0);
      return PersonEntry(
        id: 'p-1',
        name: 'Nome Teste',
        firstContactAt: now,
        status: 'interessado',
        preferredSchedule: null,
        generalNotes: null,
        contactRestrictions: null,
        tags: '[]',
        lastContactAt: null,
        nextActionAt: null,
        nextActionNote: null,
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );
    }

    VisitEntry _visit(DateTime date) {
      final now = DateTime(2026, 10, 30, 10, 0);
      return VisitEntry(
        id: 'v-1',
        personId: 'p-1',
        dateTimeField: date,
        contactType: 'visita',
        result: 'realizada',
        notes: null,
        topicsDiscussed: null,
        scriptureOrPub: null,
        expressedQuestion: null,
        nextStep: null,
        suggestedReturnDate: null,
        appointmentId: null,
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );
    }

    test('build preenche lastVisitDate a partir da última visita', () {
      final visitDate = DateTime(2026, 9, 15, 16, 30);
      final data = DoorstepBriefingHelper.build(
        person: _person(),
        linkedStudy: null,
        latestVisit: _visit(visitDate),
        latestVoiceNote: null,
      );
      expect(data.lastVisitDate, visitDate);
      expect(data.hasLastVisitDate, isTrue);
    });

    test('build sem visita deixa lastVisitDate nulo', () {
      final data = DoorstepBriefingHelper.build(
        person: _person(),
        linkedStudy: null,
        latestVisit: null,
        latestVoiceNote: null,
      );
      expect(data.lastVisitDate, isNull);
      expect(data.hasLastVisitDate, isFalse);
    });
  });
}
