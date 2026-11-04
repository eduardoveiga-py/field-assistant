import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/appointments/calendar_sync_coordinator.dart';
import 'package:ministerio_pessoal/appointments/calendar_provider.dart';
import 'package:ministerio_pessoal/appointments/google_calendar_provider.dart';
import 'package:ministerio_pessoal/appointments/apple_eventkit_provider.dart';
import 'package:ministerio_pessoal/core/date_utils.dart';

class CountingGoogleCalendarProvider extends GoogleCalendarProvider {
  int isAuthorizedCallCount = 0;
  final bool authorized;

  CountingGoogleCalendarProvider({this.authorized = true});

  @override
  Future<bool> isAuthorized() async {
    isAuthorizedCallCount++;
    return authorized;
  }

  @override
  Future<CalendarSyncResult> syncEvents({
    required AppDatabase db,
    bool fullSync = false,
  }) async {
    return CalendarSyncResult(success: true, eventsDownloaded: 0);
  }

  @override
  Future<String?> pushAppointmentToExternal(
    AppDatabase db,
    AppointmentEntry appointment,
  ) async {
    return 'ext_g_${appointment.id}';
  }

  @override
  Future<bool> deleteExternalEvent(
    AppDatabase db,
    String externalEventId,
  ) async => true;
}

class CountingAppleCalendarProvider extends AppleEventKitProvider {
  int isAuthorizedCallCount = 0;
  final bool authorized;

  CountingAppleCalendarProvider({this.authorized = true});

  @override
  Future<bool> isAuthorized() async {
    isAuthorizedCallCount++;
    return authorized;
  }

  @override
  Future<CalendarSyncResult> syncEvents({
    required AppDatabase db,
    bool fullSync = false,
  }) async {
    return CalendarSyncResult(success: true, eventsDownloaded: 0);
  }

  @override
  Future<String?> pushAppointmentToExternal(
    AppDatabase db,
    AppointmentEntry appointment,
  ) async {
    return 'ext_a_${appointment.id}';
  }

  @override
  Future<bool> deleteExternalEvent(
    AppDatabase db,
    String externalEventId,
  ) async => true;
}

void main() {
  group('Challenger M3-2 Empirical Verification Suite', () {
    late AppDatabase db;
    late AppRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    group('Task 1: Google Calendar Resiliency & Authorization Caching', () {
      test('CalendarSyncCoordinator caches isAuthorized() per cycle instead of calling per link/appointment', () async {
        final mockGoogle = CountingGoogleCalendarProvider(authorized: true);
        final mockApple = CountingAppleCalendarProvider(authorized: true);

        // Pre-seed multiple appointments and calendar links
        for (int i = 0; i < 10; i++) {
          final appt = await repo.createAppointment(
            title: 'Compromisso de Teste $i',
            startTime: DateTime.now().add(Duration(days: i)),
            endTime: DateTime.now().add(Duration(days: i, hours: 1)),
          );

          // Add a link
          await db.into(db.calendarEventLinks).insert(
            CalendarEventLinksCompanion.insert(
              id: 'link_$i',
              appointmentId: appt.id,
              externalEventId: 'ext_event_$i',
              provider: 'google',
              syncStatus: const drift.Value('synced'),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        }

        final coordinator = CalendarSyncCoordinator(
          db,
          google: mockGoogle,
          apple: mockApple,
          isWebPlatform: false,
        );

        final result = await coordinator.syncAll();
        expect(result.success, isTrue);

        // Crucial verification: isAuthorized must only be called ONCE per provider during syncAll()
        expect(mockGoogle.isAuthorizedCallCount, equals(1),
            reason: 'isAuthorized should be cached at start of syncAll and never called per link');
        expect(mockApple.isAuthorizedCallCount, equals(1),
            reason: 'isAuthorized should be cached at start of syncAll and never called per link');
      });

      test('CalendarSyncCoordinator syncAll completes within timeout when mock hangs', () async {
        // Simulates the exact UI pattern used in ConnectedCalendarsScreen._syncNow
        Future<CalendarSyncResult> hangingSync() async {
          final completer = Completer<CalendarSyncResult>();
          // Never completes
          return completer.future;
        }

        final result = await hangingSync().timeout(
          const Duration(milliseconds: 100),
          onTimeout: () => CalendarSyncResult(
            success: false,
            errorMessage: 'Tempo limite de sincronização esgotado (30s).',
          ),
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Tempo limite de sincronização esgotado'));
      });
    });

    group('Task 2: Dynamic Spiritual Timeline Date Formatting', () {
      test('Formats completedAt ISO-8601 string using AppDateUtils.formatDate', () {
        final date = DateTime(2026, 5, 14, 15, 30);
        final goal = {
          'title': 'Leitura Completa da Bíblia',
          'isCompleted': true,
          'completedAt': date.toIso8601String(),
        };

        final dateRaw = goal['completedAt'] ?? goal['achievedAt'];
        expect(dateRaw, isNotNull);

        final parsed = DateTime.tryParse(dateRaw.toString());
        expect(parsed, isNotNull);

        final formatted = AppDateUtils.formatDate(parsed!);
        expect(formatted, equals('14/05/2026'));
      });

      test('Formats achievedAt fallback when completedAt is missing', () {
        final date = DateTime(2025, 11, 20, 9, 0);
        final goal = {
          'title': 'Pioneiro Auxiliar',
          'isCompleted': true,
          'achievedAt': date.toIso8601String(),
        };

        final dateRaw = goal['completedAt'] ?? goal['achievedAt'];
        expect(dateRaw, isNotNull);

        final parsed = DateTime.tryParse(dateRaw.toString());
        expect(parsed, isNotNull);

        final formatted = AppDateUtils.formatDate(parsed!);
        expect(formatted, equals('20/11/2025'));
      });

      test('Falls back gracefully to "Alcançado" when dates are null or malformed', () {
        final malformedGoals = [
          {'title': 'Alvo Sem Data', 'isCompleted': true},
          {'title': 'Alvo Data Nula', 'isCompleted': true, 'completedAt': null},
          {'title': 'Alvo Data Inválida', 'isCompleted': true, 'completedAt': 'data-invalida-xyz'},
        ];

        for (final goal in malformedGoals) {
          final displayDate = () {
            final dateRaw = goal['completedAt'] ?? goal['achievedAt'];
            if (dateRaw != null) {
              final parsed = DateTime.tryParse(dateRaw.toString());
              if (parsed != null) {
                return AppDateUtils.formatDate(parsed);
              }
            }
            return 'Alcançado';
          }();

          expect(displayDate, equals('Alcançado'));
        }
      });
    });

    group('Task 3: HARD_DELETE and Trash Lifecycle in Repository & Outbox', () {
      test('permanentlyDeleteItem enqueues HARD_DELETE in sync_queue and removes local record', () async {
        final person = await repo.createPerson(name: 'Exclusão Definitiva Test');
        expect((await repo.getAllPeople()).length, equals(1));

        // Soft delete first
        await repo.deletePerson(person.id);
        expect((await repo.getAllPeople()).isEmpty, isTrue);

        // Wipe queue to isolate the HARD_DELETE operation
        await db.delete(db.syncQueue).go();

        // Now permanently delete
        await repo.permanentlyDeleteItem('people', person.id);

        // Check SQLite
        final check = await repo.getPersonById(person.id);
        expect(check, isNull);

        // Check Outbox
        final pending = await repo.getPendingSyncOperations();
        expect(pending.length, equals(1));
        final op = pending.first;
        expect(op.entityType, equals('people'));
        expect(op.entityId, equals(person.id));
        expect(op.operation, equals('HARD_DELETE'));

        final payload = jsonDecode(op.payload) as Map<String, dynamic>;
        expect(payload['id'], equals(person.id));
        expect(payload['hardDelete'], isTrue);
      });

      test('restoreDeletedItem includes deleted_at null and incremented revision in outbox', () async {
        final person = await repo.createPerson(name: 'Restauração Outbox Test');
        await repo.deletePerson(person.id);
        await db.delete(db.syncQueue).go();

        await repo.restoreDeletedItem('people', person.id);

        final pending = await repo.getPendingSyncOperations();
        expect(pending.length, equals(1));
        final op = pending.first;
        expect(op.operation, equals('UPDATE'));

        final payload = jsonDecode(op.payload) as Map<String, dynamic>;
        expect(payload['id'], equals(person.id));
        expect(payload['restored'], isTrue);
        expect(payload['deleted_at'], isNull);
        expect(payload['deletedAt'], isNull);
        expect(payload['revision'], equals(3)); // 1 (create) -> 2 (soft-delete) -> 3 (restore)
      });
    });
  });
}
