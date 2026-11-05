import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/appointments/external_events_for_display.dart';
import 'package:ministerio_pessoal/database/app_database.dart';

void main() {
  final date = DateTime(2026, 11, 5, 10);
  ExternalCalendarEventEntry event(String id, {bool deleted = false, bool allDay = false}) =>
      ExternalCalendarEventEntry(
        id: id, provider: 'google', calendarId: 'primary', externalEventId: id,
        title: 'Evento $id', startTime: date, endTime: date.add(const Duration(hours: 1)),
        isAllDay: allDay, isDeletedExternal: deleted, createdAt: date,
        updatedAt: date, revision: 0,
      );
  final local = AppointmentEntry(
    id: 'local', title: 'Local', startTime: date,
    endTime: date.add(const Duration(hours: 1)), durationMinutes: 60,
    status: 'agendado', isProvisional: false, createdAt: date, updatedAt: date, revision: 0,
  );
  final link = CalendarEventLinkEntry(
    id: 'link', appointmentId: 'local', externalEventId: 'linked', provider: 'google',
    syncStatus: 'synced', localRevisionAtSync: 0, createdAt: date, updatedAt: date, revision: 0,
  );

  test('Exibe eventos externos, sem duplicar vínculos ou cancelados', () {
    final result = appointmentsWithExternalEvents(
      [local], [event('linked'), event('new'), event('deleted', deleted: true)], [link],
    );
    expect(result.map((entry) => entry.title), ['Local', 'Evento new']);
    expect(result.last.id, 'external-calendar:new');
  });

  test('Preserva o dia de eventos de dia inteiro', () {
    final result = appointmentsWithExternalEvents([], [event('day', allDay: true)], []);
    expect(result.single.startTime, DateTime(2026, 11, 5));
  });
}
