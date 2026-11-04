import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/appointments/calendar_provider.dart';
import 'package:ministerio_pessoal/appointments/calendar_sync_coordinator.dart';
import 'package:ministerio_pessoal/appointments/google_calendar_provider.dart';
import 'package:ministerio_pessoal/database/app_database.dart';

class InMemorySecureStorage extends FlutterSecureStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      values[key] = value;
    } else {
      values.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return Map<String, String>.from(values);
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.clear();
  }

  @override
  Future<bool> containsKey({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return values.containsKey(key);
  }
}

void main() {
  late AppDatabase db;
  late InMemorySecureStorage storage;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    storage = InMemorySecureStorage();
  });

  tearDown(() async {
    await db.close();
  });

  group('CHALLENGE 1: HTTP 410 full sync loop & mid-flight pagination failures', () {
    test(
      'TC-ADV-410-01: When HTTP 410 occurs, sync token is wiped immediately, but if full sync page 2 fails with 500, syncEvents must return success: false without throwing unhandled exception',
      () async {
        const testAccount = 'elder.tester@gmail.com';
        const calendarId = 'primary';
        const expiredKey = 'google_calendar_elder_tester_gmail_com_synctoken_$calendarId';
        storage.values[expiredKey] = 'expired_sync_token_410';

        bool tokenWipedBeforePage1 = false;
        int callCount = 0;

        final mockClient = MockClient((request) async {
          callCount++;
          // 1st call: returns HTTP 410 Gone
          if (request.url.queryParameters.containsKey('syncToken')) {
            return http.Response(
              jsonEncode({
                'error': {
                  'code': 410,
                  'message': 'Sync token is expired',
                }
              }),
              410,
              headers: {'content-type': 'application/json'},
            );
          }

          // Full sync call - Page 1
          if (!request.url.queryParameters.containsKey('pageToken')) {
            // Verify that expired token was wiped BEFORE requesting page 1
            if (!storage.values.containsKey(expiredKey)) {
              tokenWipedBeforePage1 = true;
            }
            return http.Response(
              jsonEncode({
                'kind': 'calendar#events',
                'nextPageToken': 'token_for_page_2',
                'items': [
                  {
                    'id': 'evt_page1',
                    'summary': 'Visita Família Souza',
                    'status': 'confirmed',
                    'start': {'dateTime': '2026-11-20T10:00:00Z'},
                    'end': {'dateTime': '2026-11-20T11:00:00Z'},
                  }
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          // Page 2: Simulates mid-flight HTTP 500 error
          if (request.url.queryParameters['pageToken'] == 'token_for_page_2') {
            return http.Response(
              jsonEncode({
                'error': {
                  'code': 500,
                  'message': 'Internal Server Error',
                }
              }),
              500,
              headers: {'content-type': 'application/json'},
            );
          }

          return http.Response('Not found', 404);
        });

        final provider = GoogleCalendarProvider(
          secureStorage: storage,
          calendarApi: gcal.CalendarApi(mockClient),
          accountName: testAccount,
        );

        // We check what syncEvents returns.
        // ADVERSARIAL CRITERIA:
        // 1. Must NOT return success: true.
        // 2. Must NOT throw an unhandled exception (it must return CalendarSyncResult(success: false)).
        // 3. Must wipe expired token immediately.
        // 4. Must NOT write any new sync token on failure.
        Object? caughtError;
        CalendarSyncResult? result;
        try {
          result = await provider.syncEvents(db: db, fullSync: false);
        } catch (e) {
          caughtError = e;
        }

        expect(tokenWipedBeforePage1, isTrue, reason: 'Sync token must be deleted before page 1 is requested');
        expect(storage.values[expiredKey], isNull, reason: 'Sync token must remain wiped after failure');
        expect(callCount, greaterThanOrEqualTo(2));

        // Verify if provider threw an unhandled exception vs returning CalendarSyncResult
        if (caughtError != null) {
          fail('BUG FOUND: provider.syncEvents threw unhandled exception $caughtError instead of returning CalendarSyncResult(success: false)');
        }

        expect(result, isNotNull);
        expect(result!.success, isFalse, reason: 'Mid-flight pagination failure must NEVER return success: true');
        expect(result.errorMessage, isNotNull);
      },
    );

    test(
      'TC-ADV-410-02: When fullSync=true directly, mid-flight network exception must return success: false instead of throwing unhandled exception',
      () async {
        const testAccount = 'elder.tester@gmail.com';
        int callCount = 0;

        final mockClient = MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            return http.Response(
              jsonEncode({
                'kind': 'calendar#events',
                'nextPageToken': 'page_2',
                'items': [
                  {
                    'id': 'evt_p1',
                    'summary': 'Revisita Carlos',
                    'start': {'dateTime': '2026-11-20T10:00:00Z'},
                    'end': {'dateTime': '2026-11-20T11:00:00Z'},
                  }
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          throw http.ClientException('Network socket disconnected unexpectedly');
        });

        final provider = GoogleCalendarProvider(
          secureStorage: storage,
          calendarApi: gcal.CalendarApi(mockClient),
          accountName: testAccount,
        );

        Object? caughtError;
        CalendarSyncResult? result;
        try {
          result = await provider.syncEvents(db: db, fullSync: true);
        } catch (e) {
          caughtError = e;
        }

        if (caughtError != null) {
          fail('BUG FOUND: provider.syncEvents(fullSync: true) threw unhandled exception $caughtError instead of returning CalendarSyncResult(success: false)');
        }

        expect(result, isNotNull);
        expect(result!.success, isFalse, reason: 'Pagination failure mid-flight must never return success: true');
      },
    );

    test(
      'TC-ADV-410-03: Initial sync (no syncToken in storage) with mid-flight 500 error must return success: false without unhandled throw',
      () async {
        const testAccount = 'new.user@gmail.com';
        int callCount = 0;

        final mockClient = MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            return http.Response(
              jsonEncode({
                'kind': 'calendar#events',
                'nextPageToken': 'page_2',
                'items': [],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Server Error', 500);
        });

        final provider = GoogleCalendarProvider(
          secureStorage: storage,
          calendarApi: gcal.CalendarApi(mockClient),
          accountName: testAccount,
        );

        Object? caughtError;
        CalendarSyncResult? result;
        try {
          result = await provider.syncEvents(db: db, fullSync: false);
        } catch (e) {
          caughtError = e;
        }

        if (caughtError != null) {
          fail('BUG FOUND: Initial sync with no token threw unhandled exception $caughtError instead of returning CalendarSyncResult(success: false)');
        }

        expect(result, isNotNull);
        expect(result!.success, isFalse);
      },
    );

    test(
      'TC-ADV-410-04: 3-page full sync after 410 succeeds completely and saves all 15 events with new nextSyncToken',
      () async {
        const testAccount = 'elder.tester@gmail.com';
        const calendarId = 'primary';
        const expiredKey = 'google_calendar_elder_tester_gmail_com_synctoken_$calendarId';
        storage.values[expiredKey] = 'expired_sync_token_410';

        final mockClient = MockClient((request) async {
          if (request.url.queryParameters.containsKey('syncToken')) {
            return http.Response(
              jsonEncode({'error': {'code': 410, 'message': 'Sync token is expired'}}),
              410,
              headers: {'content-type': 'application/json'},
            );
          }

          if (!request.url.queryParameters.containsKey('pageToken')) {
            return http.Response(
              jsonEncode({
                'kind': 'calendar#events',
                'nextPageToken': 'token_page_2',
                'items': List.generate(5, (i) => {
                  'id': 'evt_p1_$i',
                  'summary': 'Evento P1 #$i',
                  'start': {'dateTime': '2026-11-20T10:00:00Z'},
                  'end': {'dateTime': '2026-11-20T11:00:00Z'},
                }),
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          if (request.url.queryParameters['pageToken'] == 'token_page_2') {
            return http.Response(
              jsonEncode({
                'kind': 'calendar#events',
                'nextPageToken': 'token_page_3',
                'items': List.generate(5, (i) => {
                  'id': 'evt_p2_$i',
                  'summary': 'Evento P2 #$i',
                  'start': {'dateTime': '2026-11-21T10:00:00Z'},
                  'end': {'dateTime': '2026-11-21T11:00:00Z'},
                }),
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          if (request.url.queryParameters['pageToken'] == 'token_page_3') {
            return http.Response(
              jsonEncode({
                'kind': 'calendar#events',
                'nextSyncToken': 'new_clean_sync_token_final',
                'items': List.generate(5, (i) => {
                  'id': 'evt_p3_$i',
                  'summary': 'Evento P3 #$i',
                  'start': {'dateTime': '2026-11-22T10:00:00Z'},
                  'end': {'dateTime': '2026-11-22T11:00:00Z'},
                }),
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          return http.Response('Not found', 404);
        });

        final provider = GoogleCalendarProvider(
          secureStorage: storage,
          calendarApi: gcal.CalendarApi(mockClient),
          accountName: testAccount,
        );

        final result = await provider.syncEvents(db: db, fullSync: false);

        expect(result.success, isTrue);
        expect(result.eventsDownloaded, equals(15));
        expect(storage.values[expiredKey], equals('new_clean_sync_token_final'));

        final savedEvents = await db.select(db.externalCalendarEvents).get();
        expect(savedEvents.length, equals(15));
      },
    );
  });

  group('CHALLENGE 2: Multi-Account Isolation under Rapid Switching & Concurrent Calls', () {
    test(
      'TC-ADV-ISO-01: Interleaved concurrent syncs of Account A and Account B do not corrupt storage or externalAccount keys',
      () async {
        const accountA = 'brother.a@gmail.com';
        const accountB = 'sister.b@gmail.com';

        final clientA = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'kind': 'calendar#events',
              'nextSyncToken': 'token_a_final',
              'items': [
                {
                  'id': 'evt_a',
                  'summary': 'Estudo Brother A',
                  'start': {'dateTime': '2026-11-25T10:00:00Z'},
                  'end': {'dateTime': '2026-11-25T11:00:00Z'},
                }
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final clientB = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'kind': 'calendar#events',
              'nextSyncToken': 'token_b_final',
              'items': [
                {
                  'id': 'evt_b',
                  'summary': 'Estudo Sister B',
                  'start': {'dateTime': '2026-11-25T14:00:00Z'},
                  'end': {'dateTime': '2026-11-25T15:00:00Z'},
                }
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final providerA = GoogleCalendarProvider(
          secureStorage: storage,
          calendarApi: gcal.CalendarApi(clientA),
          accountName: accountA,
        );

        final providerB = GoogleCalendarProvider(
          secureStorage: storage,
          calendarApi: gcal.CalendarApi(clientB),
          accountName: accountB,
        );

        await providerA.setSelectedCalendarId('cal_a');
        await providerB.setSelectedCalendarId('cal_b');

        // Concurrent execution
        final results = await Future.wait([
          providerA.syncEvents(db: db, fullSync: true),
          providerB.syncEvents(db: db, fullSync: true),
        ]);

        expect(results[0].success, isTrue);
        expect(results[1].success, isTrue);

        // Verify storage isolation
        expect(storage.values['google_calendar_brother_a_gmail_com_selected_id'], equals('cal_a'));
        expect(storage.values['google_calendar_sister_b_gmail_com_selected_id'], equals('cal_b'));
        expect(storage.values['google_calendar_brother_a_gmail_com_synctoken_cal_a'], equals('token_a_final'));
        expect(storage.values['google_calendar_sister_b_gmail_com_synctoken_cal_b'], equals('token_b_final'));

        // Verify DB records
        final eventsInDb = await db.select(db.externalCalendarEvents).get();
        expect(eventsInDb.length, equals(2));

        final savedA = eventsInDb.firstWhere((e) => e.externalEventId == 'evt_a');
        expect(savedA.externalAccount, equals('brother_a_gmail_com'));

        final savedB = eventsInDb.firstWhere((e) => e.externalEventId == 'evt_b');
        expect(savedB.externalAccount, equals('sister_b_gmail_com'));
      },
    );

    test(
      'TC-ADV-ISO-02: Shared external event ID across two different Google accounts is isolated by externalAccount without crashing or overwriting',
      () async {
        const accountA = 'account.alpha@gmail.com';
        const accountB = 'account.beta@gmail.com';
        const collidingId = 'shared_calendar_event_123';

        final clientA = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'kind': 'calendar#events',
              'nextSyncToken': 'token_alpha',
              'items': [
                {
                  'id': collidingId,
                  'summary': 'Evento Alpha',
                  'start': {'dateTime': '2026-11-26T09:00:00Z'},
                  'end': {'dateTime': '2026-11-26T10:00:00Z'},
                }
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final clientB = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'kind': 'calendar#events',
              'nextSyncToken': 'token_beta',
              'items': [
                {
                  'id': collidingId,
                  'summary': 'Evento Beta',
                  'start': {'dateTime': '2026-11-26T14:00:00Z'},
                  'end': {'dateTime': '2026-11-26T15:00:00Z'},
                }
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final providerA = GoogleCalendarProvider(
          secureStorage: storage,
          calendarApi: gcal.CalendarApi(clientA),
          accountName: accountA,
        );

        final providerB = GoogleCalendarProvider(
          secureStorage: storage,
          calendarApi: gcal.CalendarApi(clientB),
          accountName: accountB,
        );

        await providerA.syncEvents(db: db, fullSync: true);
        await providerB.syncEvents(db: db, fullSync: true);

        final allEvents = await db.select(db.externalCalendarEvents).get();
        // Both rows must exist and be isolated by externalAccount
        expect(allEvents.length, equals(2));

        final eventA = allEvents.firstWhere((e) => e.externalAccount == 'account_alpha_gmail_com');
        final eventB = allEvents.firstWhere((e) => e.externalAccount == 'account_beta_gmail_com');

        expect(eventA.title, equals('Evento Alpha'));
        expect(eventB.title, equals('Evento Beta'));
      },
    );
  });

  group('CHALLENGE 3: CalendarSyncCoordinator resilience to provider exceptions', () {
    test(
      'TC-ADV-COORD-01: CalendarSyncCoordinator.syncAll handles provider failure cleanly without unhandled crash',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response('Server Crash', 500);
        });

        final provider = GoogleCalendarProvider(
          secureStorage: storage,
          calendarApi: gcal.CalendarApi(mockClient),
          accountName: 'error.test@gmail.com',
        );

        final coordinator = CalendarSyncCoordinator(
          db,
          google: provider,
          isWebPlatform: true,
        );

        Object? caughtError;
        CalendarSyncResult? result;
        try {
          result = await coordinator.syncAll();
        } catch (e) {
          caughtError = e;
        }

        if (caughtError != null) {
          fail('BUG FOUND: CalendarSyncCoordinator.syncAll() threw uncaught error $caughtError instead of returning failure result');
        }

        expect(result, isNotNull);
        expect(result!.success, isFalse);
        expect(result.errorMessage, isNotNull);
      },
    );
  });
}
