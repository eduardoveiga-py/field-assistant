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

  group('GoogleCalendarProvider — HTTP 410 Gone Resilience Contract', () {
    test(
      'HTTP 410 deleta token expirado, executa full sync multi-página e retorna sucesso real com eventos',
      () async {
        const testAccount = 'publisher.test@gmail.com';
        const calendarId = 'primary';
        final initialExpiredTokenKey =
            'google_calendar_publisher_test_gmail_com_synctoken_$calendarId';

        // 1. Armazena token expirado pré-existente
        fakeStorage.values[initialExpiredTokenKey] = 'expired_sync_token_123';
        fakeStorage.values['google_calendar_synctoken_$calendarId'] =
            'expired_sync_token_123';

        int requestCount = 0;
        final requestedUrls = <String>[];

        final mockClient = MockClient((request) async {
          requestCount++;
          requestedUrls.add(request.url.toString());

          // Se enviar syncToken expirado, simula HTTP 410 Gone oficial da Google Calendar API
          if (request.url.queryParameters.containsKey('syncToken')) {
            return http.Response(
              jsonEncode({
                'error': {
                  'code': 410,
                  'message': 'Sync token is expired',
                  'errors': [
                    {
                      'domain': 'global',
                      'reason': 'fullSyncRequired',
                      'message': 'Sync token is expired',
                    }
                  ],
                }
              }),
              410,
              headers: {'content-type': 'application/json'},
            );
          }

          // Full sync - Página 1
          if (!request.url.queryParameters.containsKey('pageToken')) {
            return http.Response(
              jsonEncode({
                'kind': 'calendar#events',
                'nextPageToken': 'page_token_2',
                'items': [
                  {
                    'id': 'g_event_p1_1',
                    'summary': 'Estudo Bíblico Família Silva',
                    'status': 'confirmed',
                    'start': {'dateTime': '2026-11-10T10:00:00Z'},
                    'end': {'dateTime': '2026-11-10T11:00:00Z'},
                    'location': 'Rua das Flores, 123',
                  }
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          // Full sync - Página 2 (conclusão com novo nextSyncToken)
          if (request.url.queryParameters['pageToken'] == 'page_token_2') {
            return http.Response(
              jsonEncode({
                'kind': 'calendar#events',
                'nextSyncToken': 'new_valid_sync_token_789',
                'items': [
                  {
                    'id': 'g_event_p2_1',
                    'summary': 'Revisita Marcos Pereira',
                    'status': 'confirmed',
                    'start': {'dateTime': '2026-11-11T15:00:00Z'},
                    'end': {'dateTime': '2026-11-11T16:00:00Z'},
                    'location': 'Av. Central, 456',
                  }
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          return http.Response('Not found', 404);
        });

        final calendarApi = gcal.CalendarApi(mockClient);

        final provider = GoogleCalendarProvider(
          secureStorage: fakeStorage,
          calendarApi: calendarApi,
          accountName: testAccount,
        );

        // 2. Executa sync incremental
        final result = await provider.syncEvents(db: db, fullSync: false);

        // 3. Validação do resultado de sucesso com eventos reais baixados
        expect(result.success, isTrue);
        expect(result.eventsDownloaded, equals(2));
        expect(result.errorMessage, isNull);

        // 4. Verificação de requisições:
        // 1ª: chamada com syncToken expirado (retornou 410)
        // 2ª: full sync página 1
        // 3ª: full sync página 2
        expect(requestCount, equals(3));
        expect(requestedUrls[0], contains('syncToken=expired_sync_token_123'));
        expect(requestedUrls[1], contains('timeMin='));
        expect(requestedUrls[2], contains('pageToken=page_token_2'));

        // 5. Verificação da persistência do novo sync token no secure storage
        expect(
          fakeStorage.values[initialExpiredTokenKey],
          equals('new_valid_sync_token_789'),
        );

        // 6. Verificação no banco de dados SQLite Drift:
        // Ambos os eventos foram salvos com chave composta e isolamento por conta
        final savedEvents = await db.select(db.externalCalendarEvents).get();
        expect(savedEvents.length, equals(2));

        final event1 = savedEvents.firstWhere((e) => e.externalEventId == 'g_event_p1_1');
        expect(event1.title, equals('Estudo Bíblico Família Silva'));
        expect(event1.calendarId, equals('primary'));
        expect(event1.externalAccount, equals('publisher_test_gmail_com'));

        final event2 = savedEvents.firstWhere((e) => e.externalEventId == 'g_event_p2_1');
        expect(event2.title, equals('Revisita Marcos Pereira'));
        expect(event2.calendarId, equals('primary'));
        expect(event2.externalAccount, equals('publisher_test_gmail_com'));
      },
    );
  });
}
