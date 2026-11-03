import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:device_calendar/device_calendar.dart' as dev_cal;
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'calendar_provider.dart';

class AppleEventKitProvider implements CalendarProvider {
  final dev_cal.DeviceCalendarPlugin? _injectedPlugin;
  dev_cal.DeviceCalendarPlugin? _pluginInstance;
  final FlutterSecureStorage _secureStorage;
  final Uuid _uuid = const Uuid();
  final bool _isWebPlatform;

  dev_cal.DeviceCalendarPlugin get _deviceCalendarPlugin {
    if (_isWebPlatform) {
      throw UnsupportedError(
        'DeviceCalendarPlugin não pode ser acessado na plataforma Web.',
      );
    }
    return _injectedPlugin ??
        (_pluginInstance ??= dev_cal.DeviceCalendarPlugin());
  }

  static const String _keySelectedCalendarId = 'apple_eventkit_selected_id';

  /// Gera um fingerprint determinístico normalizado das propriedades do evento externo.
  /// Compatível com as capacidades reais do EventKit sem simular ETags do Google.
  static String computeEventFingerprint({
    required String externalEventId,
    required String calendarId,
    required String title,
    String? location,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
    bool isAllDay = false,
    bool isCancelled = false,
    String? recurrenceRule,
  }) {
    final normalized = [
      externalEventId.trim(),
      calendarId.trim(),
      title.trim(),
      (location ?? '').trim(),
      (description ?? '').trim(),
      startTime.toUtc().toIso8601String(),
      endTime.toUtc().toIso8601String(),
      isAllDay.toString(),
      isCancelled.toString(),
      (recurrenceRule ?? '').trim(),
    ].join('|');
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  AppleEventKitProvider({
    dev_cal.DeviceCalendarPlugin? deviceCalendarPlugin,
    FlutterSecureStorage? secureStorage,
    bool? isWebPlatform,
  }) : _injectedPlugin = deviceCalendarPlugin,
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _isWebPlatform = isWebPlatform ?? kIsWeb;

  @override
  CalendarProviderType get providerType => CalendarProviderType.appleEventKit;

  @override
  Future<bool> isAuthorized() async {
    if (_isWebPlatform) return false;
    try {
      final permissions = await _deviceCalendarPlugin.hasPermissions();
      return permissions.isSuccess && (permissions.data ?? false);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestAuthorization() async {
    if (_isWebPlatform) return false;
    try {
      final res = await _deviceCalendarPlugin.requestPermissions();
      return res.isSuccess && (res.data ?? false);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> getConnectedAccountName() async {
    if (_isWebPlatform) return null;
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
    if (_isWebPlatform) return [];
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
    if (_isWebPlatform) return null;
    return await _secureStorage.read(key: _keySelectedCalendarId);
  }

  @override
  Future<void> setSelectedCalendarId(String calendarId) async {
    if (_isWebPlatform) return;
    await _secureStorage.write(key: _keySelectedCalendarId, value: calendarId);
  }

  @override
  Future<void> disconnect() async {
    if (_isWebPlatform) return;
    await _secureStorage.delete(key: _keySelectedCalendarId);
  }

  @override
  Future<CalendarSyncResult> syncEvents({
    required AppDatabase db,
    bool fullSync = false,
  }) async {
    if (_isWebPlatform) {
      return CalendarSyncResult(
        success: false,
        errorMessage: 'Apple Calendar / Calendário nativo não é suportado no ambiente Web.',
      );
    }
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

        final recurrenceRuleStr = ev.recurrenceRule != null
            ? '${ev.recurrenceRule!.recurrenceFrequency}_${ev.recurrenceRule!.interval}_${ev.recurrenceRule!.totalOccurrences}_${ev.recurrenceRule!.endDate?.toIso8601String()}'
            : null;

        final fingerprint = computeEventFingerprint(
          externalEventId: evId,
          calendarId: calendarId,
          title: ev.title ?? 'Evento do Calendário',
          location: ev.location,
          description: ev.description,
          startTime: startDt,
          endTime: endDt,
          isAllDay: ev.allDay ?? false,
          recurrenceRule: recurrenceRuleStr,
        );

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
                  etag: drift.Value(fingerprint),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          downloaded++;
        } else {
          // Pula evento inalterado quando fingerprint coincide e não foi cancelado
          if (existing.etag == fingerprint && !existing.isDeletedExternal) {
            continue;
          }

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
              etag: drift.Value(fingerprint),
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

      // Proteção contra exclusão falsa em massa e consultas parciais truncadas:
      // 1. Se a consulta retornou 0 eventos mas existiam registros armazenados na janela.
      // 2. Se a consulta retornou uma fração anormalmente reduzida (>25% de ausência súbita quando há 4 ou mais eventos).
      final missingCount = storedEventsInWindow
          .where((s) => !activeExtIds.contains(s.externalEventId))
          .length;
      final isMassDeletionAnomaly =
          events.isEmpty && storedEventsInWindow.isNotEmpty;
      final isPartialTruncationAnomaly =
          storedEventsInWindow.length >= 4 &&
          (missingCount / storedEventsInWindow.length) > 0.25;

      if (!isMassDeletionAnomaly && !isPartialTruncationAnomaly) {
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
    if (_isWebPlatform) return null;
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

        final fingerprint = computeEventFingerprint(
          externalEventId: externalId,
          calendarId: calendarId,
          title: appointment.title,
          location: appointment.locationNotes,
          description: 'Compromisso Field Assistant Ministerial',
          startTime: appointment.startTime,
          endTime: appointment.endTime,
        );

        if (link != null) {
          await (db.update(
            db.calendarEventLinks,
          )..where((t) => t.id.equals(link.id))).write(
            CalendarEventLinksCompanion(
              externalEventId: drift.Value(externalId),
              localRevisionAtSync: drift.Value(appointment.revision),
              externalETagAtSync: drift.Value(fingerprint),
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
                  externalETagAtSync: drift.Value(fingerprint),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }

        // Atualiza ou insere na tabela ExternalCalendarEvents para manter o etag em sincronia imediata
        final existingExt =
            await (db.select(db.externalCalendarEvents)..where(
                  (t) =>
                      t.provider.equals('apple_eventkit') &
                      t.externalEventId.equals(externalId),
                ))
                .getSingleOrNull();

        if (existingExt != null) {
          await (db.update(
            db.externalCalendarEvents,
          )..where((t) => t.id.equals(existingExt.id))).write(
            ExternalCalendarEventsCompanion(
              title: drift.Value(appointment.title),
              location: drift.Value(appointment.locationNotes),
              startTime: drift.Value(appointment.startTime),
              endTime: drift.Value(appointment.endTime),
              etag: drift.Value(fingerprint),
              lastSyncedAt: drift.Value(now),
              updatedAt: drift.Value(now),
            ),
          );
        } else {
          await db
              .into(db.externalCalendarEvents)
              .insert(
                ExternalCalendarEventsCompanion.insert(
                  id: _uuid.v4(),
                  provider: 'apple_eventkit',
                  calendarId: calendarId,
                  externalEventId: externalId,
                  title: appointment.title,
                  location: drift.Value(appointment.locationNotes),
                  startTime: appointment.startTime,
                  endTime: appointment.endTime,
                  etag: drift.Value(fingerprint),
                  lastSyncedAt: drift.Value(now),
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
    if (_isWebPlatform) return false;
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
