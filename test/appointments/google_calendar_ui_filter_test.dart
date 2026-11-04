import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/appointments/apple_eventkit_provider.dart';
import 'package:ministerio_pessoal/appointments/calendar_provider.dart';
import 'package:ministerio_pessoal/appointments/calendar_sync_coordinator.dart';
import 'package:ministerio_pessoal/appointments/google_calendar_provider.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/connected_calendars_screen.dart';

class MockGoogleCalendarProvider extends GoogleCalendarProvider {
  final List<ExternalCalendarItem> calendars;
  final bool authorized;
  final GoogleAuthFailureReason failureReason;
  Completer<bool>? requestAuthCompleter;
  String? selectedCalendarId;

  MockGoogleCalendarProvider({
    this.calendars = const [],
    this.authorized = true,
    this.failureReason = GoogleAuthFailureReason.none,
    this.requestAuthCompleter,
    this.selectedCalendarId,
  });

  @override
  Future<bool> isAuthorized() async => authorized;

  @override
  Future<String?> getConnectedAccountName() async =>
      authorized ? 'publisher.test@gmail.com' : null;

  @override
  Future<List<ExternalCalendarItem>> getAvailableCalendars() async => calendars;

  @override
  Future<String?> getSelectedCalendarId() async => selectedCalendarId;

  @override
  Future<void> setSelectedCalendarId(String calendarId) async {
    selectedCalendarId = calendarId;
  }

  @override
  GoogleAuthFailureReason get lastAuthFailureReason => failureReason;

  @override
  Future<bool> requestAuthorization() async {
    if (requestAuthCompleter != null) {
      return requestAuthCompleter!.future;
    }
    return failureReason == GoogleAuthFailureReason.none;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildScreen({required GoogleCalendarProvider googleProvider}) {
    final coordinator = CalendarSyncCoordinator(
      db,
      google: googleProvider,
      apple: AppleEventKitProvider(isWebPlatform: true),
      isWebPlatform: true,
    );

    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        calendarSyncCoordinatorProvider.overrideWithValue(coordinator),
      ],
      child: const MaterialApp(home: ConnectedCalendarsScreen()),
    );
  }

  group('ConnectedCalendarsScreen — UI Filter & State Feedback Contracts', () {
    testWidgets(
      'Filtra calendários somente-leitura (isReadOnly: true) do dropdown de destino de escrita',
      (tester) async {
        final mockProvider = MockGoogleCalendarProvider(
          authorized: true,
          calendars: [
            ExternalCalendarItem(
              id: 'primary',
              name: 'Agenda Principal (Escrita)',
              isReadOnly: false,
              accountName: 'publisher.test@gmail.com',
            ),
            ExternalCalendarItem(
              id: 'holidays_br',
              name: 'Feriados no Brasil (Leitura)',
              isReadOnly: true,
              accountName: 'publisher.test@gmail.com',
            ),
            ExternalCalendarItem(
              id: 'field_ministry',
              name: 'Ministério de Campo (Escrita)',
              isReadOnly: false,
              accountName: 'publisher.test@gmail.com',
            ),
          ],
        );

        await tester.pumpWidget(buildScreen(googleProvider: mockProvider));
        await tester.pumpAndSettle();

        // Abre o dropdown
        final dropdownFinder = find.byType(DropdownButtonFormField<String>);
        expect(dropdownFinder, findsOneWidget);

        final innerDropdown = tester.widget<DropdownButton<String>>(
          find.descendant(
            of: dropdownFinder,
            matching: find.byType(DropdownButton<String>),
          ),
        );
        final items = innerDropdown.items ?? [];

        // Devem existir apenas os 2 calendários com isReadOnly == false
        expect(items.length, equals(2));
        expect(
          items.any((item) => item.value == 'primary'),
          isTrue,
        );
        expect(
          items.any((item) => item.value == 'field_ministry'),
          isTrue,
        );
        expect(
          items.any((item) => item.value == 'holidays_br'),
          isFalse,
        );
      },
    );

    testWidgets(
      'Exibe mensagem informativa quando todos os calendários retornados são somente-leitura',
      (tester) async {
        final mockProvider = MockGoogleCalendarProvider(
          authorized: true,
          calendars: [
            ExternalCalendarItem(
              id: 'holidays_br',
              name: 'Feriados no Brasil',
              isReadOnly: true,
              accountName: 'publisher.test@gmail.com',
            ),
            ExternalCalendarItem(
              id: 'subscribed_cal',
              name: 'Agenda Assinada',
              isReadOnly: true,
              accountName: 'publisher.test@gmail.com',
            ),
          ],
        );

        await tester.pumpWidget(buildScreen(googleProvider: mockProvider));
        await tester.pumpAndSettle();

        expect(
          find.text('Nenhum calendário com permissão de escrita disponível.'),
          findsOneWidget,
        );
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      },
    );

    testWidgets(
      'Exibe estado Conectando... com spinner e desabilita botão durante o fluxo de conexão',
      (tester) async {
        final completer = Completer<bool>();
        final mockProvider = MockGoogleCalendarProvider(
          authorized: false,
          requestAuthCompleter: completer,
        );

        await tester.pumpWidget(buildScreen(googleProvider: mockProvider));
        await tester.pumpAndSettle();

        final connectBtnFinder = find.widgetWithText(ElevatedButton, 'Conectar');
        expect(connectBtnFinder, findsOneWidget);

        // Dispara clique
        await tester.tap(connectBtnFinder);
        await tester.pump(); // Inicia animação / estado

        // Verifica que o botão exibe "Conectando..." e CircularProgressIndicator
        expect(find.widgetWithText(ElevatedButton, 'Conectando...'), findsOneWidget);
        expect(find.text('Conectando...'), findsNWidgets(2));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Verifica que o botão está desabilitado
        final elevatedBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Conectando...'),
        );
        expect(elevatedBtn.onPressed, isNull);

        // Conclui o completer
        completer.complete(true);
        await tester.pumpAndSettle();

        // Após concluir, volta ao normal
        expect(find.text('Conectando...'), findsNothing);
      },
    );

    testWidgets(
      'Exibe SnackBar com mensagem acionável específica ao ocorrer popupBlocked',
      (tester) async {
        final mockProvider = MockGoogleCalendarProvider(
          authorized: false,
          failureReason: GoogleAuthFailureReason.popupBlocked,
        );

        await tester.pumpWidget(buildScreen(googleProvider: mockProvider));
        await tester.pumpAndSettle();

        final connectBtn = find.widgetWithText(ElevatedButton, 'Conectar');
        await tester.tap(connectBtn);
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Janela de login bloqueada pelo navegador. Permita pop-ups para este site e tente novamente.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Exibe SnackBar com mensagem acionável ao ocorrer clientConfigurationError',
      (tester) async {
        final mockProvider = MockGoogleCalendarProvider(
          authorized: false,
          failureReason: GoogleAuthFailureReason.clientConfigurationError,
        );

        await tester.pumpWidget(buildScreen(googleProvider: mockProvider));
        await tester.pumpAndSettle();

        final connectBtn = find.widgetWithText(ElevatedButton, 'Conectar');
        await tester.tap(connectBtn);
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Configuração do Google Cloud inválida: Client ID ausente ou origem Web não autorizada no console do Google Cloud.',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
