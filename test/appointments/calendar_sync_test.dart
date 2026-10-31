import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/appointments/calendar_sync_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CalendarSyncCoordinator & Conflict Resolution Contract', () {
    late AppDatabase db;
    late CalendarSyncCoordinator coordinator;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      coordinator = CalendarSyncCoordinator(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('resolveConflictKeepExternal atualiza compromisso local com dados externos preservando integridade', () async {
      final now = DateTime.now();

      // 1. Cria compromisso local
      await db.into(db.appointments).insert(
        AppointmentsCompanion.insert(
          id: 'appt_sync_1',
          title: 'Visita Local Antiga',
          startTime: DateTime(2026, 11, 10, 14, 0),
          endTime: DateTime(2026, 11, 10, 14, 30),
          durationMinutes: const drift.Value(30),
          status: const drift.Value('agendado'),
          createdAt: now,
          updatedAt: now,
          revision: const drift.Value(1),
        ),
      );

      // 2. Cria evento externo modificado (por exemplo, no Google Agenda / Apple Calendar)
      await db.into(db.externalCalendarEvents).insert(
        ExternalCalendarEventsCompanion.insert(
          id: 'ext_event_1',
          provider: 'google',
          calendarId: 'primary',
          externalEventId: 'google_ev_123',
          title: 'Visita Atualizada no Google Calendar',
          startTime: DateTime(2026, 11, 10, 15, 0),
          endTime: DateTime(2026, 11, 10, 16, 0),
          createdAt: now,
          updatedAt: now,
          revision: const drift.Value(2),
        ),
      );

      // 3. Cria link com status 'conflict'
      await db.into(db.calendarEventLinks).insert(
        CalendarEventLinksCompanion.insert(
          id: 'link_1',
          appointmentId: 'appt_sync_1',
          externalEventId: 'google_ev_123',
          provider: 'google',
          syncStatus: const drift.Value('conflict'),
          createdAt: now,
          updatedAt: now,
          revision: const drift.Value(1),
        ),
      );

      // Obtém conflitos pendentes
      final conflicts = await coordinator.getPendingConflicts();
      expect(conflicts.length, equals(1));
      final conflict = conflicts.first;
      expect(conflict.localAppointment.title, equals('Visita Local Antiga'));
      expect(conflict.externalEvent?.title, equals('Visita Atualizada no Google Calendar'));

      // 4. Resolve mantendo a versão externa
      await coordinator.resolveConflictKeepExternal(conflict);

      // 5. Verifica se o compromisso local foi atualizado com título e horários externos
      final updatedAppt = await (db.select(db.appointments)..where((t) => t.id.equals('appt_sync_1'))).getSingle();
      expect(updatedAppt.title, equals('Visita Atualizada no Google Calendar'));
      expect(updatedAppt.startTime, equals(DateTime(2026, 11, 10, 15, 0)));
      expect(updatedAppt.endTime, equals(DateTime(2026, 11, 10, 16, 0)));
      expect(updatedAppt.durationMinutes, equals(60));
      expect(updatedAppt.revision, equals(2));

      // Verifica se o link foi alterado para 'synced'
      final updatedLink = await (db.select(db.calendarEventLinks)..where((t) => t.id.equals('link_1'))).getSingle();
      expect(updatedLink.syncStatus, equals('synced'));

      // Verifica que não há mais conflitos pendentes
      final remainingConflicts = await coordinator.getPendingConflicts();
      expect(remainingConflicts, isEmpty);
    });

    test('resolveConflictKeepLocal marca link como synced preservando dados locais', () async {
      final now = DateTime.now();

      await db.into(db.appointments).insert(
        AppointmentsCompanion.insert(
          id: 'appt_local_only',
          title: 'Compromisso Definido pelo Publicador',
          startTime: DateTime(2026, 11, 12, 10, 0),
          endTime: DateTime(2026, 11, 12, 11, 0),
          durationMinutes: const drift.Value(60),
          status: const drift.Value('confirmado'),
          createdAt: now,
          updatedAt: now,
          revision: const drift.Value(2),
        ),
      );

      await db.into(db.calendarEventLinks).insert(
        CalendarEventLinksCompanion.insert(
          id: 'link_local',
          appointmentId: 'appt_local_only',
          externalEventId: 'ext_event_local',
          provider: 'google',
          syncStatus: const drift.Value('conflict'),
          createdAt: now,
          updatedAt: now,
          revision: const drift.Value(1),
        ),
      );

      final conflicts = await coordinator.getPendingConflicts();
      expect(conflicts.length, equals(1));

      // Resolve mantendo a versão local
      await coordinator.resolveConflictKeepLocal(conflicts.first);

      final link = await (db.select(db.calendarEventLinks)..where((t) => t.id.equals('link_local'))).getSingle();
      expect(link.syncStatus, equals('synced'));

      final appt = await (db.select(db.appointments)..where((t) => t.id.equals('appt_local_only'))).getSingle();
      expect(appt.title, equals('Compromisso Definido pelo Publicador'));
    });
  });
}
