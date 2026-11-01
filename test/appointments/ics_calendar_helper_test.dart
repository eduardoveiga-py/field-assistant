import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/appointments/ics_calendar_helper.dart';
import 'package:ministerio_pessoal/database/app_database.dart';

void main() {
  group('IcsCalendarHelper RFC 5545 Strict Parser', () {
    test('Rejeita eventos sem DTSTART (não inclui no resultado e nunca usa DateTime.now())', () {
      const icsMissingDtStart = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Test//Test Calendar//PT
BEGIN:VEVENT
UID:event_without_start_1
SUMMARY:Revisita com Maria
LOCATION:Rua Central
END:VEVENT
END:VCALENDAR
''';

      final events = IcsCalendarHelper.parseIcsEvents(icsMissingDtStart);
      expect(
        events,
        isEmpty,
        reason: 'Evento sem DTSTART deve ser estritamente descartado segundo RFC 5545',
      );
    });

    test('parseIcsDateTime retorna null para formato inválido (nunca inventa datas fictícias)', () {
      expect(IcsCalendarHelper.parseIcsDateTime('data_invalida'), isNull);
      expect(IcsCalendarHelper.parseIcsDateTime('20261399'), isNull);
      expect(IcsCalendarHelper.parseIcsDateTime(''), isNull);
      expect(IcsCalendarHelper.parseIcsDateTime('123'), isNull);
    });

    test('Interpreta corretamente data UTC (sufixo Z)', () {
      const icsUtc = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:event_utc_1@territorio.app
SUMMARY:Assembleia de Circuito
DTSTART:20261105T143000Z
DTEND:20261105T163000Z
END:VEVENT
END:VCALENDAR
''';

      final events = IcsCalendarHelper.parseIcsEvents(icsUtc);
      expect(events.length, equals(1));
      final ev = events.first;
      expect(ev.summary, equals('Assembleia de Circuito'));
      expect(ev.rawUid, equals('event_utc_1@territorio.app'));
      expect(ev.apptId, equals('event_utc_1'));
      expect(ev.durationMinutes, equals(120));
      expect(ev.isAllDay, isFalse);
    });

    test('Interpreta corretamente evento de dia inteiro (YYYYMMDD)', () {
      const icsAllDay = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:event_allday_1
SUMMARY:Celebração da Morte de Cristo
DTSTART:20260402
DTEND:20260403
STATUS:CONFIRMED
END:VEVENT
END:VCALENDAR
''';

      final events = IcsCalendarHelper.parseIcsEvents(icsAllDay);
      expect(events.length, equals(1));
      final ev = events.first;
      expect(ev.summary, equals('Celebração da Morte de Cristo'));
      expect(ev.isAllDay, isTrue);
      expect(ev.durationMinutes, equals(1440));
      expect(ev.status, equals('confirmado'));
    });

    test('Extrai e decodifica caracteres escapados em SUMMARY e LOCATION', () {
      const icsEscaped = r'''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:escaped_1
SUMMARY:Revisita\, com Maria e José
LOCATION:Rua A\, 100\; Apto 4

DTSTART:20261010T100000
DTEND:20261010T103000
STATUS:CANCELLED
END:VEVENT
END:VCALENDAR
''';

      final events = IcsCalendarHelper.parseIcsEvents(icsEscaped);
      expect(events.length, equals(1));
      final ev = events.first;
      expect(ev.summary, equals('Revisita, com Maria e José'));
      expect(ev.location, equals('Rua A, 100; Apto 4'));
      expect(ev.status, equals('cancelado'));
    });

    test('Gera arquivo .ics no padrão RFC 5545 com VEVENT e PRODID', () {
      final appts = [
        AppointmentEntry(
          id: 'appt_101',
          title: 'Estudo Bíblico com João',
          startTime: DateTime(2026, 11, 10, 10, 0),
          endTime: DateTime(2026, 11, 10, 11, 0),
          durationMinutes: 60,
          status: 'agendado',
          isProvisional: false,
          locationNotes: 'Rua das Flores, 45',
          createdAt: DateTime.now(),

          updatedAt: DateTime.now(),
          revision: 1,
        ),
      ];

      final ics = IcsCalendarHelper.generateIcsCalendar(appts);

      expect(ics, contains('BEGIN:VCALENDAR'));
      expect(
        ics,
        contains('PRODID:-//Território Ministério Pessoal//Agenda//PT'),
      );
      expect(ics, contains('VERSION:2.0'));
      expect(ics, contains('BEGIN:VEVENT'));
      expect(ics, contains('UID:appt_101@territorio.app'));
      expect(ics, contains('SUMMARY:Estudo Bíblico com João'));
      expect(ics, contains('LOCATION:Rua das Flores, 45'));
      expect(ics, contains('END:VEVENT'));
      expect(ics, contains('END:VCALENDAR'));
    });
  });
}
