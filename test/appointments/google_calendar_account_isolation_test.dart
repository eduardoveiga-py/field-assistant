import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/appointments/google_calendar_provider.dart';
import 'package:ministerio_pessoal/database/app_database.dart';

class FakeSecureStorage extends FlutterSecureStorage {
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
  late FakeSecureStorage fakeStorage;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    fakeStorage = FakeSecureStorage();
  });

  tearDown(() async {
    await db.close();
  });

  group('GoogleCalendarProvider — Multi-Account Isolation Contract', () {
    test(
      'Tokens e selected_id são isolados por conta e não colidem no secure storage',
      () async {
        const accountA = 'user.alpha@gmail.com';
        const accountB = 'user.beta@gmail.com';

        final clientA = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'kind': 'calendar#events',
              'nextSyncToken': 'sync_token_alpha_1',
              'items': [
                {
                  'id': 'evt_alpha_1',
                  'summary': 'Estudo Bíblico Alpha',
                  'status': 'confirmed',
                  'start': {'dateTime': '2026-11-20T10:00:00Z'},
                  'end': {'dateTime': '2026-11-20T11:00:00Z'},
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
              'nextSyncToken': 'sync_token_beta_1',
              'items': [
                {
                  'id': 'evt_beta_1',
                  'summary': 'Estudo Bíblico Beta',
                  'status': 'confirmed',
                  'start': {'dateTime': '2026-11-20T14:00:00Z'},
                  'end': {'dateTime': '2026-11-20T15:00:00Z'},
                }
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final providerA = GoogleCalendarProvider(
          secureStorage: fakeStorage,
          calendarApi: gcal.CalendarApi(clientA),
          accountName: accountA,
        );

        final providerB = GoogleCalendarProvider(
          secureStorage: fakeStorage,
          calendarApi: gcal.CalendarApi(clientB),
          accountName: accountB,
        );

        // Seleciona calendários diferentes para cada conta
        await providerA.setSelectedCalendarId('cal_alpha');
        await providerB.setSelectedCalendarId('cal_beta');

        expect(await providerA.getSelectedCalendarId(), equals('cal_alpha'));
        expect(await providerB.getSelectedCalendarId(), equals('cal_beta'));

        // Sincroniza conta A
        final resA = await providerA.syncEvents(db: db, fullSync: true);
        expect(resA.success, isTrue);

        // Sincroniza conta B
        final resB = await providerB.syncEvents(db: db, fullSync: true);
        expect(resB.success, isTrue);

        // Verifica chaves no secure storage
        expect(
          fakeStorage.values['google_calendar_user_alpha_gmail_com_selected_id'],
          equals('cal_alpha'),
        );
        expect(
          fakeStorage.values['google_calendar_user_beta_gmail_com_selected_id'],
          equals('cal_beta'),
        );
        expect(
          fakeStorage.values['google_calendar_user_alpha_gmail_com_synctoken_cal_alpha'],
          equals('sync_token_alpha_1'),
        );
        expect(
          fakeStorage.values['google_calendar_user_beta_gmail_com_synctoken_cal_beta'],
          equals('sync_token_beta_1'),
        );

        // Verifica que no banco Drift ambos os eventos existem associados à sua respectiva externalAccount
        final eventsInDb = await db.select(db.externalCalendarEvents).get();
        expect(eventsInDb.length, equals(2));

        final evtA = eventsInDb.firstWhere((e) => e.externalEventId == 'evt_alpha_1');
        expect(evtA.externalAccount, equals('user_alpha_gmail_com'));
        expect(evtA.calendarId, equals('cal_alpha'));

        final evtB = eventsInDb.firstWhere((e) => e.externalEventId == 'evt_beta_1');
        expect(evtB.externalAccount, equals('user_beta_gmail_com'));
        expect(evtB.calendarId, equals('cal_beta'));
      },
    );

    test(
      'Disconnect purga tokens da conta correspondente mas preserva tokens de outras contas e compromissos locais',
      () async {
        const accountA = 'user.alpha@gmail.com';
        const accountB = 'user.beta@gmail.com';

        // Preenche tokens no storage
        fakeStorage.values['google_calendar_user_alpha_gmail_com_selected_id'] = 'cal_alpha';
        fakeStorage.values['google_calendar_user_alpha_gmail_com_synctoken_cal_alpha'] = 'token_a';
        fakeStorage.values['google_calendar_user_beta_gmail_com_selected_id'] = 'cal_beta';
        fakeStorage.values['google_calendar_user_beta_gmail_com_synctoken_cal_beta'] = 'token_b';

        final providerA = GoogleCalendarProvider(
          secureStorage: fakeStorage,
          accountName: accountA,
        );
        final providerB = GoogleCalendarProvider(
          secureStorage: fakeStorage,
          accountName: accountB,
        );

        // Desconecta conta A
        await providerA.disconnect();

        // Conta A deve ter seus tokens removidos
        expect(
          fakeStorage.values['google_calendar_user_alpha_gmail_com_selected_id'],
          isNull,
        );
        expect(
          fakeStorage.values['google_calendar_user_alpha_gmail_com_synctoken_cal_alpha'],
          isNull,
        );

        // Conta B permanece intocada
        expect(await providerB.getSelectedCalendarId(), equals('cal_beta'));
        expect(
          fakeStorage.values['google_calendar_user_beta_gmail_com_selected_id'],
          equals('cal_beta'),
        );
        expect(
          fakeStorage.values['google_calendar_user_beta_gmail_com_synctoken_cal_beta'],
          equals('token_b'),
        );
      },
    );
  });
}
