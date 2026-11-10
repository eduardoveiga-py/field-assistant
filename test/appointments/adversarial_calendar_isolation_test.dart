import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:device_calendar/device_calendar.dart' as dev_cal;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/appointments/calendar_sync_coordinator.dart';
import 'package:ministerio_pessoal/appointments/google_calendar_provider.dart';
import 'package:ministerio_pessoal/appointments/apple_eventkit_provider.dart';
import 'package:ministerio_pessoal/appointments/calendar_provider.dart';

/// An adversarial implementation of DeviceCalendarPlugin that explodes with StateError
/// if ANY method is called. Used to strictly guarantee that no native calls occur on unsupported platforms.
class ExplodingDeviceCalendarPlugin implements dev_cal.DeviceCalendarPlugin {
  int invocationCount = 0;
  final List<String> recordedCalls = [];

  void _recordAndExplode(String methodName) {
    invocationCount++;
    recordedCalls.add(methodName);
    throw StateError('ADVERSARIAL FAILURE: DeviceCalendarPlugin.$methodName was invoked on an unsupported platform!');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final memberName = invocation.memberName.toString();
    _recordAndExplode(memberName);
    return super.noSuchMethod(invocation);
  }

  @override
  Future<dev_cal.Result<bool>> hasPermissions() async {
    _recordAndExplode('hasPermissions');
    return dev_cal.Result<bool>();
  }

  @override
  Future<dev_cal.Result<bool>> requestPermissions() async {
    _recordAndExplode('requestPermissions');
    return dev_cal.Result<bool>();
  }

  @override
  Future<dev_cal.Result<UnmodifiableListView<dev_cal.Calendar>>> retrieveCalendars() async {
    _recordAndExplode('retrieveCalendars');
    return dev_cal.Result<UnmodifiableListView<dev_cal.Calendar>>();
  }

  @override
  Future<dev_cal.Result<UnmodifiableListView<dev_cal.Event>>> retrieveEvents(
    String? calendarId,
    dev_cal.RetrieveEventsParams? retrieveEventsParams,
  ) async {
    _recordAndExplode('retrieveEvents');
    return dev_cal.Result<UnmodifiableListView<dev_cal.Event>>();
  }

  @override
  Future<dev_cal.Result<String>?> createOrUpdateEvent(dev_cal.Event? event) async {
    _recordAndExplode('createOrUpdateEvent');
    return null;
  }

  @override
  Future<dev_cal.Result<bool>> deleteEvent(String? calendarId, String? eventId) async {
    _recordAndExplode('deleteEvent');
    return dev_cal.Result<bool>();
  }
}

/// Controllable mock Google calendar provider
class ControllableGoogleCalendarProvider extends GoogleCalendarProvider {
  bool authorized;
  int syncEventsCallCount = 0;
  int pushCount = 0;
  int deleteCount = 0;
  bool shouldFailSync;

  ControllableGoogleCalendarProvider({
    this.authorized = true,
    this.shouldFailSync = false,
  });

  @override
  Future<bool> isAuthorized() async => authorized;

  @override
  Future<CalendarSyncResult> syncEvents({
    required AppDatabase db,
    bool fullSync = false,
  }) async {
    syncEventsCallCount++;
    if (shouldFailSync) {
      return CalendarSyncResult(
        success: false,
        errorMessage: 'Simulated Google API failure',
      );
    }
    return CalendarSyncResult(
      success: true,
      eventsDownloaded: 2,
      eventsUploaded: 1,
    );
  }

  @override
  Future<String?> pushAppointmentToExternal(
    AppDatabase db,
    AppointmentEntry appointment,
  ) async {
    pushCount++;
    return 'gcal_push_${appointment.id}';
  }

  @override
  Future<bool> deleteExternalEvent(AppDatabase db, String externalEventId) async {
    deleteCount++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  group('Adversarial Calendar Isolation Suite', () {
    late AppDatabase db;
    late AppRepository repo;
    late ExplodingDeviceCalendarPlugin explodingPlugin;
    late AppleEventKitProvider appleProvider;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
      FlutterSecureStorage.setMockInitialValues({
        'apple_eventkit_selected_id': 'pre_existing_id',
      });
      explodingPlugin = ExplodingDeviceCalendarPlugin();
      appleProvider = AppleEventKitProvider(deviceCalendarPlugin: explodingPlugin);
    });

    tearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await db.close();
    });

    final unsupportedPlatforms = [
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.android,
      TargetPlatform.fuchsia,
    ];

    for (final platform in unsupportedPlatforms) {
      test('AppleEventKitProvider strictly never invokes DeviceCalendarPlugin on $platform', () async {
        debugDefaultTargetPlatformOverride = platform;

        // 1. Capability check
        expect(appleProvider.isSupportedOnCurrentPlatform, isFalse,
            reason: '$platform should not be reported as supported for Apple EventKit');

        // 2. isAuthorized
        final isAuth = await appleProvider.isAuthorized();
        expect(isAuth, isFalse);

        // 3. requestAuthorization
        final reqAuth = await appleProvider.requestAuthorization();
        expect(reqAuth, isFalse);

        // 4. getConnectedAccountName
        final accName = await appleProvider.getConnectedAccountName();
        expect(accName, isNull);

        // 5. getAvailableCalendars
        final cals = await appleProvider.getAvailableCalendars();
        expect(cals, isEmpty);

        // 6. getSelectedCalendarId
        final selId = await appleProvider.getSelectedCalendarId();
        expect(selId, isNull);

        // 7. setSelectedCalendarId
        await appleProvider.setSelectedCalendarId('test_cal');

        // 8. disconnect
        await appleProvider.disconnect();

        // 9. syncEvents (incremental)
        final syncResultInc = await appleProvider.syncEvents(db: db, fullSync: false);
        expect(syncResultInc.success, isFalse);
        expect(syncResultInc.errorMessage, contains('não suportado'));

        // 10. syncEvents (full)
        final syncResultFull = await appleProvider.syncEvents(db: db, fullSync: true);
        expect(syncResultFull.success, isFalse);
        expect(syncResultFull.errorMessage, contains('não suportado'));

        // 11. pushAppointmentToExternal
        final appt = await repo.createAppointment(
          title: 'Adversarial Test Appt',
          startTime: DateTime(2026, 11, 10, 14, 0),
          endTime: DateTime(2026, 11, 10, 15, 0),
        );
        final pushResult = await appleProvider.pushAppointmentToExternal(db, appt);
        expect(pushResult, isNull);

        // 12. deleteExternalEvent
        final deleteResult = await appleProvider.deleteExternalEvent(db, 'ext_test_id');
        expect(deleteResult, isFalse);

        // CRITICAL ASSERTION: The plugin was NEVER invoked!
        expect(explodingPlugin.invocationCount, equals(0),
            reason: 'DeviceCalendarPlugin was invoked ${explodingPlugin.invocationCount} time(s) on $platform: ${explodingPlugin.recordedCalls}');
      });
    }

    test('CalendarSyncCoordinator.syncAll() across simulated desktop platforms cleanly skips unsupported Apple provider', () async {
      for (final desktopPlatform in [TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.macOS]) {
        debugDefaultTargetPlatformOverride = desktopPlatform;

        final googleMock = ControllableGoogleCalendarProvider(authorized: true);
        final exploding = ExplodingDeviceCalendarPlugin();
        final apple = AppleEventKitProvider(deviceCalendarPlugin: exploding);

        final coordinator = CalendarSyncCoordinator(
          db,
          google: googleMock,
          apple: apple,
        );

        final result = await coordinator.syncAll();

        expect(result.success, isTrue, reason: 'Sync failed on $desktopPlatform');
        expect(result.errorMessage, isNull);
        expect(result.eventsDownloaded, equals(2));
        expect(result.eventsUploaded, equals(1));
        expect(googleMock.syncEventsCallCount, equals(1));

        // Exploding plugin must have received zero calls
        expect(exploding.invocationCount, equals(0),
            reason: 'Plugin was touched during coordinator.syncAll on $desktopPlatform');
      }
    });

    test('CalendarSyncCoordinator.syncAll(providers: {appleEventKit}) on desktop cleanly skips without error', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      final googleMock = ControllableGoogleCalendarProvider(authorized: true);
      final exploding = ExplodingDeviceCalendarPlugin();
      final apple = AppleEventKitProvider(deviceCalendarPlugin: exploding);

      final coordinator = CalendarSyncCoordinator(
        db,
        google: googleMock,
        apple: apple,
      );

      final result = await coordinator.syncAll(
        providers: {CalendarProviderType.appleEventKit},
      );

      expect(result.success, isTrue);
      expect(result.eventsDownloaded, equals(0));
      expect(result.eventsUploaded, equals(0));
      expect(exploding.invocationCount, equals(0));
    });

    test('CalendarSyncCoordinator outbox and appointment operations safely skip Apple provider on desktop', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final googleMock = ControllableGoogleCalendarProvider(authorized: true);
      final exploding = ExplodingDeviceCalendarPlugin();
      final apple = AppleEventKitProvider(deviceCalendarPlugin: exploding);

      final coordinator = CalendarSyncCoordinator(
        db,
        google: googleMock,
        apple: apple,
      );

      // Create an appointment
      final appt = await repo.createAppointment(
        title: 'Ministério Desktop',
        startTime: DateTime(2026, 11, 10, 9, 0),
        endTime: DateTime(2026, 11, 10, 10, 0),
      );

      // 1. pushLocalAppointment
      await coordinator.pushLocalAppointment(appt);
      expect(googleMock.pushCount, equals(1));
      expect(exploding.invocationCount, equals(0));

      // Insert pre-existing apple link to test handleLocalAppointmentDeleted
      await db.into(db.calendarEventLinks).insert(
        CalendarEventLinksCompanion.insert(
          id: 'apple_link_1',
          appointmentId: appt.id,
          externalEventId: 'apple_ext_ev_1',
          provider: 'apple_eventkit',
          syncStatus: const drift.Value('synced'),
          localRevisionAtSync: const drift.Value(1),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // 2. handleLocalAppointmentDeleted
      await coordinator.handleLocalAppointmentDeleted(appt.id);
      expect(exploding.invocationCount, equals(0));

      // 3. resolveConflictKeepLocal on an Apple conflict
      final conflictItem = CalendarConflictItem(
        link: CalendarEventLinkEntry(
          id: 'apple_link_2',
          appointmentId: appt.id,
          externalEventId: 'apple_ext_ev_2',
          provider: 'apple_eventkit',
          syncStatus: 'conflict',
          localRevisionAtSync: 1,
          revision: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        localAppointment: appt,
      );

      await coordinator.resolveConflictKeepLocal(conflictItem);
      expect(exploding.invocationCount, equals(0));
    });

    test('Stress test: Concurrent syncAll() invocations do not duplicate or leak native calls', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final googleMock = ControllableGoogleCalendarProvider(authorized: true);
      final exploding = ExplodingDeviceCalendarPlugin();
      final apple = AppleEventKitProvider(deviceCalendarPlugin: exploding);

      final coordinator = CalendarSyncCoordinator(
        db,
        google: googleMock,
        apple: apple,
      );

      // Launch 10 concurrent syncAll calls
      final futures = List.generate(10, (_) => coordinator.syncAll());
      final results = await Future.wait(futures);

      for (final res in results) {
        expect(res.success, isTrue);
      }
      expect(googleMock.syncEventsCallCount, equals(1),
          reason: 'Concurrent syncAll should share active future');
      expect(exploding.invocationCount, equals(0));
    });

    test('GoogleCalendarProvider correctly fulfills CalendarProvider contract with isSupportedOnCurrentPlatform == true', () {
      final googleProvider = GoogleCalendarProvider();

      // Verify polymorphism
      expect(googleProvider, isA<CalendarProvider>());
      expect(googleProvider.providerType, equals(CalendarProviderType.google));

      // Verify true across all desktop and mobile platforms
      final allPlatforms = [
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.fuchsia,
      ];

      for (final p in allPlatforms) {
        debugDefaultTargetPlatformOverride = p;
        expect(googleProvider.isSupportedOnCurrentPlatform, isTrue,
            reason: 'GoogleCalendarProvider must support $p');
      }
    });
  });
}
