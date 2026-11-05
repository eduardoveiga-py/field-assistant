import '../database/app_database.dart';

/// Projeta eventos externos em itens apenas de leitura, sem gravá-los na fila
/// de compromissos locais e sem duplicar eventos já vinculados a um deles.
List<AppointmentEntry> appointmentsWithExternalEvents(
  List<AppointmentEntry> appointments,
  List<ExternalCalendarEventEntry> events,
  List<CalendarEventLinkEntry> links,
) {
  final localIds = appointments
      .where((appointment) => appointment.deletedAt == null)
      .map((appointment) => appointment.id)
      .toSet();
  final linkedEvents = links
      .where((link) => link.deletedAt == null && localIds.contains(link.appointmentId))
      .map((link) => '${link.provider}:${link.externalEventId}')
      .toSet();
  return [
    ...appointments,
    ...events
        .where((event) => event.deletedAt == null &&
            !event.isDeletedExternal &&
            event.externalStatus != 'cancelled' &&
            !linkedEvents.contains('${event.provider}:${event.externalEventId}'))
        .map((event) => AppointmentEntry(
              id: 'external-calendar:${event.id}',
              title: event.title,
              startTime: event.isAllDay
                  ? DateTime(event.startTime.year, event.startTime.month, event.startTime.day)
                  : event.startTime.toLocal(),
              endTime: event.isAllDay
                  ? DateTime(event.endTime.year, event.endTime.month, event.endTime.day)
                  : event.endTime.toLocal(),
              durationMinutes: event.endTime.difference(event.startTime).inMinutes,
              status: 'agendado',
              locationNotes: event.location,
              isProvisional: false,
              createdAt: event.createdAt,
              updatedAt: event.updatedAt,
              revision: event.revision,
            )),
  ];
}
