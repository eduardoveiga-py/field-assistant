import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../database/app_database.dart';
import '../ui/providers.dart';
import 'calendar_provider.dart';
import 'google_calendar_provider.dart';
import 'apple_eventkit_provider.dart';

enum SyncCoordinationStatus {
  idle,
  syncing,
  success,
  conflict,
  error,
}

class CalendarConflictItem {
  final CalendarEventLinkEntry link;
  final AppointmentEntry localAppointment;
  final ExternalCalendarEventEntry? externalEvent;

  CalendarConflictItem({
    required this.link,
    required this.localAppointment,
    this.externalEvent,
  });
}

class CalendarSyncCoordinator {
  final AppDatabase db;
  final GoogleCalendarProvider googleProvider;
  final AppleEventKitProvider appleProvider;

  CalendarSyncCoordinator(
    this.db, {
    GoogleCalendarProvider? google,
    AppleEventKitProvider? apple,
  })  : googleProvider = google ?? GoogleCalendarProvider(),
        appleProvider = apple ?? AppleEventKitProvider();

  List<CalendarProvider> get allProviders => [googleProvider, appleProvider];

  /// Sincroniza todos os provedores autorizados
  Future<CalendarSyncResult> syncAll({bool fullSync = false}) async {
    int totalDownloaded = 0;
    int totalUploaded = 0;
    int totalConflicts = 0;
    final errors = <String>[];

    for (final provider in allProviders) {
      final authorized = await provider.isAuthorized();
      if (!authorized) continue;

      final res = await provider.syncEvents(db: db, fullSync: fullSync);
      totalDownloaded += res.eventsDownloaded;
      totalUploaded += res.eventsUploaded;
      totalConflicts += res.conflictsFound;
      if (!res.success && res.errorMessage != null) {
        errors.add('${provider.providerType.displayName}: ${res.errorMessage}');
      }
    }

    // Após sincronizar os eventos externos, verifica se há compromissos locais criados/editados pendentes de envio
    final pendingLinks = await (db.select(db.calendarEventLinks)
          ..where((t) => t.syncStatus.equals('pending_upload') & t.deletedAt.isNull()))
        .get();

    for (final link in pendingLinks) {
      final appt = await (db.select(db.appointments)..where((t) => t.id.equals(link.appointmentId))).getSingleOrNull();
      if (appt == null) continue;

      if (link.provider == 'google') {
        if (await googleProvider.isAuthorized()) {
          await googleProvider.pushAppointmentToExternal(db, appt);
          totalUploaded++;
        }
      } else if (link.provider == 'apple_eventkit') {
        if (await appleProvider.isAuthorized()) {
          await appleProvider.pushAppointmentToExternal(db, appt);
          totalUploaded++;
        }
      }
    }

    return CalendarSyncResult(
      success: errors.isEmpty,
      eventsDownloaded: totalDownloaded,
      eventsUploaded: totalUploaded,
      conflictsFound: totalConflicts,
      errorMessage: errors.isNotEmpty ? errors.join('; ') : null,
    );
  }

  /// Propaga criação ou alteração de um compromisso local para os calendários externos conectados
  Future<void> pushLocalAppointment(AppointmentEntry appointment) async {
    for (final provider in allProviders) {
      if (await provider.isAuthorized()) {
        await provider.pushAppointmentToExternal(db, appointment);
      }
    }
  }

  /// Trata exclusão lógica de compromisso: propaga ao calendário externo e marca tombstone no vínculo
  Future<void> handleLocalAppointmentDeleted(String appointmentId) async {
    final links = await (db.select(db.calendarEventLinks)
          ..where((t) => t.appointmentId.equals(appointmentId) & t.deletedAt.isNull()))
        .get();

    for (final link in links) {
      if (link.provider == 'google') {
        await googleProvider.deleteExternalEvent(db, link.externalEventId);
      } else if (link.provider == 'apple_eventkit') {
        await appleProvider.deleteExternalEvent(db, link.externalEventId);
      }
    }
  }

  /// Retorna lista de conflitos pendentes de resolução manual
  Future<List<CalendarConflictItem>> getPendingConflicts() async {
    final conflictLinks = await (db.select(db.calendarEventLinks)
          ..where((t) => t.syncStatus.equals('conflict') & t.deletedAt.isNull()))
        .get();

    final result = <CalendarConflictItem>[];
    for (final link in conflictLinks) {
      final appt = await (db.select(db.appointments)..where((t) => t.id.equals(link.appointmentId))).getSingleOrNull();
      if (appt == null) continue;

      final extEvent = await (db.select(db.externalCalendarEvents)
            ..where((t) => t.externalEventId.equals(link.externalEventId) & t.provider.equals(link.provider)))
          .getSingleOrNull();

      result.add(CalendarConflictItem(
        link: link,
        localAppointment: appt,
        externalEvent: extEvent,
      ));
    }
    return result;
  }

  /// Resolução: Manter versão local (sobrescreve evento externo)
  Future<void> resolveConflictKeepLocal(CalendarConflictItem conflict) async {
    if (conflict.link.provider == 'google') {
      await googleProvider.pushAppointmentToExternal(db, conflict.localAppointment);
    } else if (conflict.link.provider == 'apple_eventkit') {
      await appleProvider.pushAppointmentToExternal(db, conflict.localAppointment);
    }

    final now = DateTime.now();
    await (db.update(db.calendarEventLinks)..where((t) => t.id.equals(conflict.link.id))).write(
      CalendarEventLinksCompanion(
        syncStatus: const drift.Value('synced'),
        updatedAt: drift.Value(now),
      ),
    );
  }

  /// Resolução: Manter versão externa (atualiza compromisso local preservando vínculos pastorais)
  Future<void> resolveConflictKeepExternal(CalendarConflictItem conflict) async {
    if (conflict.externalEvent == null) return;
    final ext = conflict.externalEvent!;
    final now = DateTime.now();

    await (db.update(db.appointments)..where((t) => t.id.equals(conflict.localAppointment.id))).write(
      AppointmentsCompanion(
        title: drift.Value(ext.title),
        startTime: drift.Value(ext.startTime),
        endTime: drift.Value(ext.endTime),
        durationMinutes: drift.Value(ext.endTime.difference(ext.startTime).inMinutes),
        locationNotes: ext.location != null ? drift.Value(ext.location) : const drift.Value.absent(),
        revision: drift.Value(conflict.localAppointment.revision + 1),
        updatedAt: drift.Value(now),
      ),
    );

    await (db.update(db.calendarEventLinks)..where((t) => t.id.equals(conflict.link.id))).write(
      CalendarEventLinksCompanion(
        syncStatus: const drift.Value('synced'),
        localRevisionAtSync: drift.Value(conflict.localAppointment.revision + 1),
        externalETagAtSync: drift.Value(ext.etag),
        updatedAt: drift.Value(now),
      ),
    );
  }
}

final calendarSyncCoordinatorProvider = Provider<CalendarSyncCoordinator>((ref) {
  final db = ref.watch(databaseProvider);
  return CalendarSyncCoordinator(db);
});
