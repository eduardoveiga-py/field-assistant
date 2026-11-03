import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:device_calendar/device_calendar.dart' as dev_cal;
import 'package:timezone/data/latest_all.dart' as tz_data;

import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/appointments/apple_eventkit_provider.dart';
import 'package:ministerio_pessoal/appointments/google_calendar_provider.dart';
import 'package:ministerio_pessoal/appointments/calendar_sync_coordinator.dart';
import 'package:ministerio_pessoal/appointments/calendar_provider.dart';
import 'package:ministerio_pessoal/ui/screens/connected_calendars_screen.dart';
import 'package:ministerio_pessoal/ui/providers.dart';

/// Plugin espião que rastreia rigorosamente qualquer invocação nativa
class TrackingDeviceCalendarPlugin implements dev_cal.DeviceCalendarPlugin {
  final List<String> calls = [];
  bool hasPermissionsReturnValue = true;
  bool requestPermissionsReturnValue = true;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation.memberName.toString());
    return super.noSuchMethod(invocation);
  }

  @override
  Future<dev_cal.Result<bool>> hasPermissions() async {
    calls.add('hasPermissions');
    final res = dev_cal.Result<bool>();
    res.data = hasPermissionsReturnValue;
    return res;
  }

  @override
  Future<dev_cal.Result<bool>> requestPermissions() async {
    calls.add('requestPermissions');
    final res = dev_cal.Result<bool>();
    res.data = requestPermissionsReturnValue;
    return res;
  }

  @override
  Future<dev_cal.Result<UnmodifiableListView<dev_cal.Calendar>>>
  retrieveCalendars() async {
    calls.add('retrieveCalendars');
    final res = dev_cal.Result<UnmodifiableListView<dev_cal.Calendar>>();
    res.data = UnmodifiableListView<dev_cal.Calendar>([]);
    return res;
  }

  @override
  Future<dev_cal.Result<UnmodifiableListView<dev_cal.Event>>> retrieveEvents(
    String? calendarId,
    dev_cal.RetrieveEventsParams? retrieveEventsParams,
  ) async {
    calls.add('retrieveEvents');
    final res = dev_cal.Result<UnmodifiableListView<dev_cal.Event>>();
    res.data = UnmodifiableListView<dev_cal.Event>([]);
    return res;
  }

  @override
  Future<dev_cal.Result<String>?> createOrUpdateEvent(
    dev_cal.Event? event,
  ) async {
    calls.add('createOrUpdateEvent');
    final res = dev_cal.Result<String>();
    res.data = 'created_ev_1';
    return res;
  }

  @override
  Future<dev_cal.Result<bool>> deleteEvent(
    String? calendarId,
    String? eventId,
  ) async {
    calls.add('deleteEvent');
    final res = dev_cal.Result<bool>();
    res.data = true;
    return res;
  }
}

class TrackingGoogleCalendarProvider extends GoogleCalendarProvider {
  bool requestAuthCalled = false;
  bool requestAuthResult = true;
  Exception? throwOnRequestAuth;
  bool authorized = false;

  TrackingGoogleCalendarProvider({
    this.requestAuthResult = true,
    this.authorized = false,
  });

  @override
  Future<bool> isAuthorized() async => authorized;

  @override
  Future<bool> requestAuthorization() async {
    requestAuthCalled = true;
    if (throwOnRequestAuth != null) {
      throw throwOnRequestAuth!;
    }
    authorized = requestAuthResult;
    return requestAuthResult;
  }

  @override
  Future<String?> getConnectedAccountName() async {
    return authorized ? 'user@fieldassistant.app' : null;
  }

  @override
  Future<List<ExternalCalendarItem>> getAvailableCalendars() async {
    return authorized
        ? [
            ExternalCalendarItem(
              id: 'primary',
              name: 'Principal',
              accountName: 'user@fieldassistant.app',
            ),
          ]
        : [];
  }

  @override
  Future<String?> getSelectedCalendarId() async => 'primary';

  @override
  Future<CalendarSyncResult> syncEvents({
    required AppDatabase db,
    bool fullSync = false,
  }) async {
    return CalendarSyncResult(
      success: true,
      eventsDownloaded: 0,
      eventsUploaded: 0,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  group('AppleEventKitProvider - Web Platform Isolation', () {
    late TrackingDeviceCalendarPlugin trackingPlugin;
    late AppleEventKitProvider webAppleProvider;
    late AppDatabase db;

    setUp(() {
      trackingPlugin = TrackingDeviceCalendarPlugin();
      webAppleProvider = AppleEventKitProvider(
        deviceCalendarPlugin: trackingPlugin,
        isWebPlatform: true,
      );
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Na Web: isAuthorized retorna false imediatamente sem invocar device_calendar', () async {
      final auth = await webAppleProvider.isAuthorized();
      expect(auth, isFalse);
      expect(trackingPlugin.calls, isEmpty);
    });

    test(
      'Na Web: requestAuthorization retorna false sem invocar device_calendar',
      () async {
        final auth = await webAppleProvider.requestAuthorization();
        expect(auth, isFalse);
        expect(trackingPlugin.calls, isEmpty);
      },
    );

    test('Na Web: getAvailableCalendars retorna lista vazia sem invocar device_calendar', () async {
      final cals = await webAppleProvider.getAvailableCalendars();
      expect(cals, isEmpty);
      expect(trackingPlugin.calls, isEmpty);
    });

    test('Na Web: syncEvents retorna erro explicativo sem invocar device_calendar', () async {
      final res = await webAppleProvider.syncEvents(db: db);
      expect(res.success, isFalse);
      expect(
        res.errorMessage,
        contains(
          'Apple Calendar / Calendário nativo não é suportado no ambiente Web',
        ),
      );
      expect(trackingPlugin.calls, isEmpty);
    });

    test('Na Web: pushAppointmentToExternal retorna null sem invocar device_calendar', () async {
      final appt = AppointmentEntry(
        id: 'appt_1',
        title: 'Estudo Bíblico',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        durationMinutes: 60,
        status: 'scheduled',
        isProvisional: false,
        revision: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final res = await webAppleProvider.pushAppointmentToExternal(db, appt);
      expect(res, isNull);
      expect(trackingPlugin.calls, isEmpty);
    });

    test(
      'Na Web: deleteExternalEvent retorna false sem invocar device_calendar',
      () async {
        final res = await webAppleProvider.deleteExternalEvent(db, 'ext_ev_1');
        expect(res, isFalse);
        expect(trackingPlugin.calls, isEmpty);
      },
    );
  });

  group('AppleEventKitProvider - Preservação Completa da Implementação iOS', () {
    late TrackingDeviceCalendarPlugin trackingPlugin;
    late AppleEventKitProvider iosAppleProvider;
    late AppDatabase db;

    setUp(() {
      trackingPlugin = TrackingDeviceCalendarPlugin();
      iosAppleProvider = AppleEventKitProvider(
        deviceCalendarPlugin: trackingPlugin,
        isWebPlatform: false, // Simula ambiente nativo iOS
      );
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'No iOS: isAuthorized consulta as permissões nativas via device_calendar',
      () async {
        trackingPlugin.hasPermissionsReturnValue = true;
        final auth = await iosAppleProvider.isAuthorized();
        expect(auth, isTrue);
        expect(trackingPlugin.calls, contains('hasPermissions'));
      },
    );

    test('No iOS: requestAuthorization solicita permissões nativas via device_calendar', () async {
      trackingPlugin.requestPermissionsReturnValue = true;
      final auth = await iosAppleProvider.requestAuthorization();
      expect(auth, isTrue);
      expect(trackingPlugin.calls, contains('requestPermissions'));
    });
  });

  group(
    'CalendarSyncCoordinator - Estratégia de Provedores por Plataforma',
    () {
      late AppDatabase db;
      late TrackingDeviceCalendarPlugin trackingPlugin;

      setUp(() {
        db = AppDatabase.forTesting(NativeDatabase.memory());
        trackingPlugin = TrackingDeviceCalendarPlugin();
      });

      tearDown(() async {
        await db.close();
      });

      test(
        'Na Web: allProviders contém exclusivamente o GoogleCalendarProvider',
        () {
          final coordinator = CalendarSyncCoordinator(
            db,
            apple: AppleEventKitProvider(
              deviceCalendarPlugin: trackingPlugin,
              isWebPlatform: true,
            ),
            isWebPlatform: true,
          );

          expect(coordinator.allProviders.length, equals(1));
          expect(
            coordinator.allProviders.first.providerType,
            equals(CalendarProviderType.google),
          );
        },
      );

      test(
        'No iOS: allProviders contém tanto Google quanto Apple EventKit',
        () {
          final coordinator = CalendarSyncCoordinator(
            db,
            apple: AppleEventKitProvider(
              deviceCalendarPlugin: trackingPlugin,
              isWebPlatform: false,
            ),
            isWebPlatform: false,
          );

          expect(coordinator.allProviders.length, equals(2));
          expect(
            coordinator.allProviders.map((p) => p.providerType),
            containsAll([
              CalendarProviderType.google,
              CalendarProviderType.appleEventKit,
            ]),
          );
        },
      );

      test('Na Web: syncAll sincroniza Google sem nenhuma consulta ao plugin Apple nativo', () async {
        final mockGoogle = TrackingGoogleCalendarProvider(authorized: true);
        final coordinator = CalendarSyncCoordinator(
          db,
          google: mockGoogle,
          apple: AppleEventKitProvider(
            deviceCalendarPlugin: trackingPlugin,
            isWebPlatform: true,
          ),
          isWebPlatform: true,
        );

        final result = await coordinator.syncAll();
        expect(result.success, isTrue);
        expect(trackingPlugin.calls, isEmpty);
      });
    },
  );

  group('ConnectedCalendarsScreen - Renderização e Interação Web', () {
    late AppDatabase db;
    late TrackingDeviceCalendarPlugin trackingPlugin;
    late TrackingGoogleCalendarProvider trackingGoogle;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      trackingPlugin = TrackingDeviceCalendarPlugin();
      trackingGoogle = TrackingGoogleCalendarProvider(
        authorized: false,
        requestAuthResult: true,
      );
    });

    tearDown(() async {
      await db.close();
    });

    Widget createTestWidget({required CalendarSyncCoordinator coordinator}) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          calendarSyncCoordinatorProvider.overrideWithValue(coordinator),
        ],
        child: const MaterialApp(home: ConnectedCalendarsScreen()),
      );
    }

    testWidgets(
      'Inicialização da tela não faz nenhuma chamada ao device_calendar',
      (tester) async {
        final coordinator = CalendarSyncCoordinator(
          db,
          google: trackingGoogle,
          apple: AppleEventKitProvider(
            deviceCalendarPlugin: trackingPlugin,
            isWebPlatform: true,
          ),
          isWebPlatform: true,
        );

        await tester.pumpWidget(createTestWidget(coordinator: coordinator));
        await tester.pumpAndSettle();

        // Confirma que nenhuma chamada ocorreu durante o initState/loadState
        expect(trackingPlugin.calls, isEmpty);

        // Confirma que a tela renderizou os cards
        expect(find.text('Google Calendar'), findsOneWidget);
        expect(find.text('Apple Calendar / Dispositivo'), findsOneWidget);
      },
    );

    testWidgets(
      'Ao clicar em Conectar Google: alcança OAuth sem tocar no device_calendar',
      (tester) async {
        final coordinator = CalendarSyncCoordinator(
          db,
          google: trackingGoogle,
          apple: AppleEventKitProvider(
            deviceCalendarPlugin: trackingPlugin,
            isWebPlatform: true,
          ),
          isWebPlatform: true,
        );

        await tester.pumpWidget(createTestWidget(coordinator: coordinator));
        await tester.pumpAndSettle();

        // Clica no botão "Conectar" do Google Calendar
        final connectButton = find.widgetWithText(ElevatedButton, 'Conectar');
        expect(connectButton, findsOneWidget);

        await tester.tap(connectButton);
        await tester.pumpAndSettle();

        // Verifica que o método requestAuthorization do Google foi invocado
        expect(trackingGoogle.requestAuthCalled, isTrue);

        // Confirma que NENHUMA chamada a device_calendar ocorreu durante o clique ou após
        expect(trackingPlugin.calls, isEmpty);

        // Confirma feedback de sucesso exibido
        expect(
          find.text('Conta Google conectada com sucesso!'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Ao falhar autorização do Google: exibe SnackBar informativa sem chamar device_calendar',
      (tester) async {
        trackingGoogle = TrackingGoogleCalendarProvider(
          authorized: false,
          requestAuthResult: false,
        );
        final coordinator = CalendarSyncCoordinator(
          db,
          google: trackingGoogle,
          apple: AppleEventKitProvider(
            deviceCalendarPlugin: trackingPlugin,
            isWebPlatform: true,
          ),
          isWebPlatform: true,
        );

        await tester.pumpWidget(createTestWidget(coordinator: coordinator));
        await tester.pumpAndSettle();

        final connectButton = find.widgetWithText(ElevatedButton, 'Conectar');
        await tester.tap(connectButton);
        await tester.pumpAndSettle();

        expect(trackingGoogle.requestAuthCalled, isTrue);
        expect(trackingPlugin.calls, isEmpty);

        // Feedback visual informativo para o usuário
        expect(
          find.text(
            'Não foi possível conectar ao Google Calendar. Verifique a autenticação e tente novamente.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Ao ocorrer exceção no OAuth: trata erro e exibe SnackBar sem quebrar o app',
      (tester) async {
        trackingGoogle =
            TrackingGoogleCalendarProvider(
                authorized: false,
                requestAuthResult: false,
              )
              ..throwOnRequestAuth = Exception(
                'Simulação de falha de rede/popup fechado',
              );

        final coordinator = CalendarSyncCoordinator(
          db,
          google: trackingGoogle,
          apple: AppleEventKitProvider(
            deviceCalendarPlugin: trackingPlugin,
            isWebPlatform: true,
          ),
          isWebPlatform: true,
        );

        await tester.pumpWidget(createTestWidget(coordinator: coordinator));
        await tester.pumpAndSettle();

        final connectButton = find.widgetWithText(ElevatedButton, 'Conectar');
        await tester.tap(connectButton);
        await tester.pumpAndSettle();

        expect(trackingGoogle.requestAuthCalled, isTrue);
        expect(trackingPlugin.calls, isEmpty);

        expect(
          find.textContaining('Erro ao conectar ao Google Agenda'),
          findsOneWidget,
        );
      },
    );
  });
}
