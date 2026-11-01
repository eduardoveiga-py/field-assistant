import 'package:device_calendar/device_calendar.dart' as dev_cal;
import 'package:drift/drift.dart' as drift;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'calendar_provider.dart';

class AppleEventKitProvider implements CalendarProvider {
  final dev_cal.DeviceCalendarPlugin _deviceCalendarPlugin;
  final FlutterSecureStorage _secureStorage;
  final Uuid _uuid = const Uuid();

  static const String _keySelectedCalendarId = 'apple_eventkit_selected_id';

  AppleEventKitProvider({
    dev_cal.DeviceCalendarPlugin? deviceCalendarPlugin,
    FlutterSecureStorage? secureStorage,
  }) : _deviceCalendarPlugin =
           deviceCalendarPlugin ?? dev_cal.DeviceCalendarPlugin(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  @override
  CalendarProviderType get providerType => CalendarProviderType.appleEventKit;

  @override
  Future<bool> isAuthorized() async {
    try {
      final permissions = await _deviceCalendarPlugin.hasPermissions();
      return permissions.isSuccess && (permissions.data ?? false);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestAuthorization() async {
    try {
      final res = await _deviceCalendarPlugin.requestPermissions();
      return res.isSuccess && (res.data ?? false);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> getConnectedAccountName() async {
    final calendars = await getAvailableCalendars();
    final selectedId = await getSelectedCalendarId();
    if (selectedId != null) {
      final selected = calendars.where((c) => c.id == selectedId).firstOrNull;
      if (selected != null) return selected.accountName ?? selected.name;
    }
    return calendars.isNotEmpty
        ? calendars.first.accountName ?? 'Apple Calendars'
        : null;
  }

  @override
  Future<List<ExternalCalendarItem>> getAvailableCalendars() async {
    try {
      final authorized = await isAuthorized();
      if (!authorized) return [];

      final result = await _deviceCalendarPlugin.retrieveCalendars();
      if (!result.isSuccess || result.data == null) return [];

      return result.data!.map((c) {
        return ExternalCalendarItem(
          id: c.id ?? '',
          name: c.name ?? 'Calendário Apple',
          accountName: c.accountName,
          isReadOnly: c.isReadOnly ?? false,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<String?> getSelectedCalendarId() async {
    return await _secureStorage.read(key: _keySelectedCalendarId);
  }

  @override
  Future<void> setSelectedCalendarId(String calendarId) async {
    await _secureStorage.write(key: _keySelectedCalendarId, value: calendarId);
  }

  @override
  Future<void> disconnect() async {
    await _secureStorage.delete(key: _keySelectedCalendarId);
  }

  @override
  Future<CalendarSyncResult> syncEvents({
    required AppDatabase db,
    bool fullSync = false,
  }) async {
    try {
      final authorized = await isAuthorized();
      if (!authorized) {
        return CalendarSyncResult(
          success: false,
          errorMessage: 'Permissão para acessar o Calendário do dispositivo não concedida.',
        );
      }

      final calendarId = await getSelectedCalendarId();
      if (calendarId == null || calendarId.isEmpty) {
        return CalendarSyncResult(
          success: false,
          errorMessage: 'Nenhum calendário selecionado para sincronização.',
        );
      }

      final startDate = DateTime.now().subtract(const Duration(days: 60));
      final endDate = DateTime.now().add(const Duration(days: 180));

      final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
        calendarId,
        dev_cal.RetrieveEventsParams(startDate: startDate, endDate: endDate),
      );

      if (!eventsResult.isSuccess || eventsResult.data == null) {
        return CalendarSyncResult(
          success: false,
          errorMessage: eventsResult.errors
              .map((e) => e.errorMessage)
              .join(', '),
        );
      }

      int downloaded = 0;
      final events = eventsResult.data!;
      final now = DateTime.now();

      final activeExtIds = <String>{};
      for (final ev in events) {
        final evId = ev.eventId;
        if (evId == null) continue;
        activeExtIds.add(evId);

        final startDt = ev.start?.toLocal() ?? now;
        final endDt =
            ev.end?.toLocal() ?? startDt.add(const Duration(minutes: 30));

        final existing =
            await (db.select(db.externalCalendarEvents)..where(
                  (t) =>
                      t.provider.equals('apple_eventkit') &
                      t.externalEventId.equals(evId),
                ))
                .getSingleOrNull();

        if (existing == null) {
          await db
              .into(db.externalCalendarEvents)
              .insert(
                ExternalCalendarEventsCompanion.insert(
                  id: _uuid.v4(),
                  provider: 'apple_eventkit',
                  calendarId: calendarId,
                  externalEventId: evId,
                  title: ev.title ?? 'Evento do Calendário',
                  location: drift.Value(ev.location),
                  description: drift.Value(ev.description),
                  startTime: startDt,
                  endTime: endDt,
                  isAllDay: drift.Value(ev.allDay ?? false),
                  lastSyncedAt: drift.Value(now),
                  isDeletedExternal: const drift.Value(false),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          downloaded++;
        } else {
          await (db.update(
            db.externalCalendarEvents,
          )..where((t) => t.id.equals(existing.id))).write(
            ExternalCalendarEventsCompanion(
              title: drift.Value(ev.title ?? existing.title),
              location: drift.Value(ev.location),
              description: drift.Value(ev.description),
              startTime: drift.Value(startDt),
              endTime: drift.Value(endDt),
              isAllDay: drift.Value(ev.allDay ?? false),
              isDeletedExternal: const drift.Value(false),
              lastSyncedAt: drift.Value(now),
              updatedAt: drift.Value(now),
            ),
          );
          downloaded++;
        }
      }

      // Reconciliação de exclusões no Apple Calendar:
      // Eventos que estavam no banco local dentro da janela consultada mas não retornaram do EventKit foram excluídos externamente
      final storedEventsInWindow =
          await (db.select(db.externalCalendarEvents)..where(
                (t) =>
                    t.provider.equals('apple_eventkit') &
                    t.calendarId.equals(calendarId) &
                    t.isDeletedExternal.equals(false) &
                    t.startTime.isBiggerOrEqualValue(startDate) &
                    t.endTime.isSmallerOrEqualValue(endDate),
              ))
              .get();

      for (final stored in storedEventsInWindow) {
        if (!activeExtIds.contains(stored.externalEventId)) {
          await (db.update(
            db.externalCalendarEvents,
          )..where((t) => t.id.equals(stored.id))).write(
            ExternalCalendarEventsCompanion(
              isDeletedExternal: const drift.Value(true),
              externalStatus: const drift.Value('cancelled'),
              updatedAt: drift.Value(now),
            ),
          );
        }
      }

      return CalendarSyncResult(success: true, eventsDownloaded: downloaded);
    } catch (e) {
      return CalendarSyncResult(
        success: false,
        errorMessage: 'Erro ao sincronizar com Calendário Apple: $e',
      );
    }
  }

  @override
  Future<String?> pushAppointmentToExternal(
    AppDatabase db,
    AppointmentEntry appointment,
  ) async {
    try {
      if (!await isAuthorized()) return null;
      final calendarId = await getSelectedCalendarId();
      if (calendarId == null) return null;

      final calendars = await getAvailableCalendars();
      final selectedCal = calendars
          .where((c) => c.id == calendarId)
          .firstOrNull;
      if (selectedCal != null && selectedCal.isReadOnly) {
        return null;
      }

      final link =
          await (db.select(db.calendarEventLinks)..where(
                (t) =>
                    t.appointmentId.equals(appointment.id) &
                    t.provider.equals('apple_eventkit') &
                    t.deletedAt.isNull(),
              ))
              .getSingleOrNull();

      final devEvent = dev_cal.Event(
        calendarId,
        eventId: (link?.externalEventId.isNotEmpty == true)
            ? link!.externalEventId
            : null,
        title: appointment.title,
        description: 'Compromisso Field Assistant Ministerial',
        location: appointment.locationNotes,
        start: tz.TZDateTime.from(appointment.startTime, tz.local),
        end: tz.TZDateTime.from(appointment.endTime, tz.local),
      );

      final result = await _deviceCalendarPlugin.createOrUpdateEvent(devEvent);
      if (result != null && result.isSuccess && result.data != null) {
        final externalId = result.data!;
        final now = DateTime.now();

        if (link != null) {
          await (db.update(
            db.calendarEventLinks,
          )..where((t) => t.id.equals(link.id))).write(
            CalendarEventLinksCompanion(
              externalEventId: drift.Value(externalId),
              localRevisionAtSync: drift.Value(appointment.revision),
              syncStatus: const drift.Value('synced'),
              updatedAt: drift.Value(now),
            ),
          );
        } else {
          await db
              .into(db.calendarEventLinks)
              .insert(
                CalendarEventLinksCompanion.insert(
                  id: _uuid.v4(),
                  appointmentId: appointment.id,
                  externalEventId: externalId,
                  provider: 'apple_eventkit',
                  syncStatus: const drift.Value('synced'),
                  localRevisionAtSync: drift.Value(appointment.revision),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }
        return externalId;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> deleteExternalEvent(
    AppDatabase db,
    String externalEventId,
  ) async {
    try {
      final calendarId = await getSelectedCalendarId();
      if (calendarId == null) return false;

      final res = await _deviceCalendarPlugin.deleteEvent(
        calendarId,
        externalEventId,
      );
      if (res.isSuccess && (res.data ?? false)) {
        final now = DateTime.now();
        await (db.update(db.calendarEventLinks)..where(
              (t) =>
                  t.externalEventId.equals(externalEventId) &
                  t.provider.equals('apple_eventkit'),
            ))
            .write(
              CalendarEventLinksCompanion(
                deletedAt: drift.Value(now),
                syncStatus: const drift.Value('synced'),
                updatedAt: drift.Value(now),
              ),
            );
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
