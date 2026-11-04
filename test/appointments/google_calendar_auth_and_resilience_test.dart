import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/appointments/google_calendar_provider.dart';

void main() {
  group('LoggingHygiene — Strict Privacy & No Secret Leakage', () {
    test('maskEmail mascara endereços de email preservando domínio e formato', () {
      expect(LoggingHygiene.maskEmail(null), equals('(sem email)'));
      expect(LoggingHygiene.maskEmail(''), equals('(sem email)'));
      expect(LoggingHygiene.maskEmail('invalid-email'), equals('***'));
      expect(LoggingHygiene.maskEmail('a@domain.com'), equals('a*@domain.com'));
      expect(LoggingHygiene.maskEmail('jo@domain.com'), equals('j*@domain.com'));
      expect(
        LoggingHygiene.maskEmail('publisher.test@gmail.com'),
        equals('p***t@gmail.com'),
      );
    });

    test('sanitizeErrorMessage remove Bearer tokens, senhas, chaves e emails brutos', () {
      const rawErrorWithBearer =
          'Error 401: Authorization failed for Bearer ya29.a0AfH6_SECRET_TOKEN_HERE and token=abc';
      final sanitizedBearer = LoggingHygiene.sanitizeErrorMessage(rawErrorWithBearer);
      expect(sanitizedBearer, contains('Bearer [REDACTED]'));
      expect(sanitizedBearer, isNot(contains('ya29.a0AfH6_SECRET_TOKEN_HERE')));

      const rawErrorWithEmail =
          'Exception contacting Google for publisher.sync@example.org: timeout';
      final sanitizedEmail = LoggingHygiene.sanitizeErrorMessage(rawErrorWithEmail);
      expect(sanitizedEmail, contains('p***c@example.org'));
      expect(sanitizedEmail, isNot(contains('publisher.sync@example.org')));

      const rawErrorWithQuerySecret =
          'Request failed: https://oauth2.googleapis.com/token?client_secret=super_secret_key&access_token=sensitive_token';
      final sanitizedSecrets = LoggingHygiene.sanitizeErrorMessage(rawErrorWithQuerySecret);
      expect(sanitizedSecrets, contains('client_secret=[REDACTED]'));
      expect(sanitizedSecrets, contains('access_token=[REDACTED]'));
      expect(sanitizedSecrets, isNot(contains('super_secret_key')));
      expect(sanitizedSecrets, isNot(contains('sensitive_token')));
    });
  });

  group('GoogleAuthFailureReason — Classification and User Friendly Messages', () {
    test('Classifica corretamente mensagens de erro conhecidas e fornece mensagens acionáveis', () {
      expect(
        GoogleAuthFailureReason.popupBlocked.userFriendlyMessage,
        contains('bloqueada pelo navegador'),
      );
      expect(
        GoogleAuthFailureReason.clientConfigurationError.userFriendlyMessage,
        contains('Client ID ausente ou origem Web não autorizada'),
      );
      expect(
        GoogleAuthFailureReason.userCancelled.userFriendlyMessage,
        contains('cancelada pelo usuário'),
      );
      expect(
        GoogleAuthFailureReason.scopeDenied.userFriendlyMessage,
        contains('Permissão de acesso à agenda negada'),
      );
      expect(
        GoogleAuthFailureReason.calendarApiDisabled.userFriendlyMessage,
        contains('Google Calendar API não está habilitada'),
      );
      expect(
        GoogleAuthFailureReason.networkError.userFriendlyMessage,
        contains('Falha de conexão'),
      );
    });
  });

  group('GoogleCalendarProvider — Resilience & Fail-Closed Behaviors', () {
    test('getAvailableCalendars nunca retorna fallback artificial em caso de falha da API', () async {
      final failingClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 403,
              'message': 'The project has not enabled the Google Calendar API',
            }
          }),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final provider = GoogleCalendarProvider(
        calendarApi: gcal.CalendarApi(failingClient),
        accountName: 'test.publisher@gmail.com',
      );

      final calendars = await provider.getAvailableCalendars();

      // NUNCA deve retornar [ExternalCalendarItem(id: 'primary', name: 'Principal')]
      expect(calendars, isEmpty);
      expect(provider.lastAuthErrorMessage, contains('Erro ao listar calendários'));
    });

    test('getAvailableCalendars identifica accessRole reader/freeBusyReader como isReadOnly: true', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'kind': 'calendar#calendarList',
            'items': [
              {
                'id': 'primary',
                'summary': 'Agenda Pessoal',
                'accessRole': 'owner',
              },
              {
                'id': 'holidays_br',
                'summary': 'Feriados no Brasil',
                'accessRole': 'reader',
              },
              {
                'id': 'busy_schedule',
                'summary': 'Disponibilidade Pública',
                'accessRole': 'freeBusyReader',
              },
              {
                'id': 'field_ministry',
                'summary': 'Ministério de Campo Compartilhado',
                'accessRole': 'writer',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final provider = GoogleCalendarProvider(
        calendarApi: gcal.CalendarApi(mockClient),
        accountName: 'test.publisher@gmail.com',
      );

      final calendars = await provider.getAvailableCalendars();

      expect(calendars.length, equals(4));

      final primary = calendars.firstWhere((c) => c.id == 'primary');
      expect(primary.isReadOnly, isFalse);

      final holidays = calendars.firstWhere((c) => c.id == 'holidays_br');
      expect(holidays.isReadOnly, isTrue);

      final busy = calendars.firstWhere((c) => c.id == 'busy_schedule');
      expect(busy.isReadOnly, isTrue);

      final ministry = calendars.firstWhere((c) => c.id == 'field_ministry');
      expect(ministry.isReadOnly, isFalse);
    });
  });
}
