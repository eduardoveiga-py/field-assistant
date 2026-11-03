import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/appointments/ics_calendar_helper.dart';

void main() {
  group('Sincronização e Parser de Calendário Oficial iCal (.ics)', () {
    test(
      'TC-ICAL-01: Faz o parse de datas UTC, Locais e All-Day com sucesso',
      () {
        final utcDate = IcsCalendarHelper.parseIcsDateTime('20261027T143000Z');
        expect(utcDate, isNotNull);
        expect(utcDate!.year, equals(2026));
        expect(utcDate.month, equals(10));
        expect(utcDate.day, equals(27));

        final localDate = IcsCalendarHelper.parseIcsDateTime('20261027T103000');
        expect(localDate, isNotNull);
        expect(localDate!.hour, equals(10));
        expect(localDate.minute, equals(30));

        final allDayDate = IcsCalendarHelper.parseIcsDateTime('20261027');
        expect(allDayDate, isNotNull);
        expect(allDayDate!.year, equals(2026));
        expect(allDayDate.month, equals(10));
        expect(allDayDate.day, equals(27));

        final invalidDate = IcsCalendarHelper.parseIcsDateTime('invalid');
        expect(invalidDate, isNull);
      },
    );

    test(
      'TC-ICAL-02: Tolera parâmetros de fuso horário (TZID) no DTSTART e DTEND',
      () {
        const ics = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Google Inc//Google Calendar 70.9054//EN
BEGIN:VEVENT
UID:google-event-12345@google.com
DTSTART;TZID=America/Sao_Paulo:20261027T090000
DTEND;TZID=America/Sao_Paulo:20261027T100000
SUMMARY:Estudo Bíblico com Marcos
LOCATION:Rua das Palmeiras, 100
STATUS:CONFIRMED
END:VEVENT
END:VCALENDAR
''';

        final events = IcsCalendarHelper.parseIcsEvents(ics);
        expect(events.length, equals(1));
        final ev = events.first;
        expect(ev.summary, equals('Estudo Bíblico com Marcos'));
        expect(ev.location, equals('Rua das Palmeiras, 100'));
        expect(ev.startTime.hour, equals(9));
        expect(ev.startTime.minute, equals(0));
        expect(ev.endTime.hour, equals(10));
        expect(ev.durationMinutes, equals(60));
        expect(ev.status, equals('confirmado'));
        expect(ev.rawUid, equals('google-event-12345@google.com'));
        expect(ev.apptId, isNull);
      },
    );

    test('TC-ICAL-03: Extrai ID interno de eventos criados no app (@territorio.app)', () {
      const ics = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:appt-uuid-999@territorio.app
DTSTART:20261027T140000Z
DTEND:20261027T144500Z
SUMMARY:Revisita Dona Ana
STATUS:CANCELLED
END:VEVENT
END:VCALENDAR
''';

      final events = IcsCalendarHelper.parseIcsEvents(ics);
      expect(events.length, equals(1));
      final ev = events.first;
      expect(ev.apptId, equals('appt-uuid-999'));
      expect(ev.status, equals('cancelado'));
      expect(ev.durationMinutes, equals(45));
    });

    test(
      'TC-ICAL-04: Exporta compromissos para formato iCalendar válido RFC 5545',
      () {
        final appts = [
          AppointmentEntry(
            id: 'test-1',
            title: 'Saída de Campo Sábado',
            startTime: DateTime.utc(2026, 10, 31, 9, 0),
            endTime: DateTime.utc(2026, 10, 31, 11, 0),
            durationMinutes: 120,
            status: 'confirmado',
            locationNotes: 'Salão do Reino Betânia',
            isProvisional: false,
            createdAt: DateTime.utc(2026, 10, 26, 12, 0),
            updatedAt: DateTime.utc(2026, 10, 26, 12, 0),
            revision: 1,
          ),
        ];

        final ics = IcsCalendarHelper.generateIcsCalendar(appts);
        expect(ics, contains('BEGIN:VCALENDAR'));
        expect(ics, contains('VERSION:2.0'));
        expect(ics, contains('BEGIN:VEVENT'));
        expect(ics, contains('UID:test-1@territorio.app'));
        expect(ics, contains('SUMMARY:Saída de Campo Sábado'));
        expect(ics, contains('LOCATION:Salão do Reino Betânia'));
        expect(ics, contains('STATUS:CONFIRMED'));
        expect(ics, contains('END:VEVENT'));
        expect(ics, contains('END:VCALENDAR'));
      },
    );

    test('TC-ICAL-05: importIcsEventsToRepository cria novos compromissos a partir de .ics', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = AppRepository(db);

      const ics = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Test//EN
BEGIN:VEVENT
UID:event-101@google.com
DTSTART:20261105T100000Z
DTEND:20261105T110000Z
SUMMARY:Revisita com Carlos
LOCATION:Rua B, 200
STATUS:CONFIRMED
END:VEVENT
END:VCALENDAR
''';

      final res = await IcsCalendarHelper.importIcsEventsToRepository(
        repo: repo,
        rawIcs: ics,
      );

      expect(res.created, equals(1));
      expect(res.updated, equals(0));

      final all = await db.select(db.appointments).get();
      expect(all.length, equals(1));
      expect(all.first.title, equals('Revisita com Carlos'));
      expect(all.first.locationNotes, equals('Rua B, 200'));

      await db.close();
    });

    test('TC-ICAL-06: importIcsEventsToRepository atualiza compromisso existente com mesmo título e horário', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = AppRepository(db);

      final existing = await repo.createAppointment(
        title: 'Estudo Bíblico Família Silva',
        startTime: DateTime.utc(2026, 11, 6, 14, 0),
        endTime: DateTime.utc(2026, 11, 6, 15, 0),
        durationMinutes: 60,
        status: 'confirmado',
      );

      const ics = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Test//EN
BEGIN:VEVENT
UID:silva-updated@google.com
DTSTART:20261106T140000Z
DTEND:20261106T153000Z
SUMMARY:Estudo Bíblico Família Silva
LOCATION:Casa da Família Silva - Sala
STATUS:CONFIRMED
END:VEVENT
END:VCALENDAR
''';

      final res = await IcsCalendarHelper.importIcsEventsToRepository(
        repo: repo,
        rawIcs: ics,
      );

      expect(res.created, equals(0));
      expect(res.updated, equals(1));

      final all = await db.select(db.appointments).get();
      expect(all.length, equals(1));
      expect(all.first.id, equals(existing.id));
      expect(all.first.locationNotes, equals('Casa da Família Silva - Sala'));

      await db.close();
    });
  });
}
