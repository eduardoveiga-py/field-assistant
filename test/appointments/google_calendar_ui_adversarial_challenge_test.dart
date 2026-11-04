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

/// Provedor mock configurável especificamente para testes adversariais e de estresse.
class AdversarialMockGoogleProvider extends GoogleCalendarProvider {
  final List<ExternalCalendarItem> calendars;
  bool authorized;
  GoogleAuthFailureReason failureReason;
  Exception? throwOnAuth;
  Completer<bool>? requestAuthCompleter;
  String? selectedCalendarId;

  int requestAuthCallCount = 0;
  int setSelectedCalendarIdCallCount = 0;
  final List<String> selectedCalendarIdHistory = [];

  AdversarialMockGoogleProvider({
    this.calendars = const [],
    this.authorized = false,
    this.failureReason = GoogleAuthFailureReason.none,
    this.throwOnAuth,
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
    setSelectedCalendarIdCallCount++;
    selectedCalendarId = calendarId;
    selectedCalendarIdHistory.add(calendarId);
  }

  @override
  GoogleAuthFailureReason get lastAuthFailureReason => failureReason;

  @override
  Future<bool> requestAuthorization() async {
    requestAuthCallCount++;
    if (throwOnAuth != null) {
      throw throwOnAuth!;
    }
    if (requestAuthCompleter != null) {
      final res = await requestAuthCompleter!.future;
      if (res) {
        authorized = true;
      }
      return res;
    }
    final success = failureReason == GoogleAuthFailureReason.none;
    if (success) {
      authorized = true;
    }
    return success;
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

  group('Adversarial Challenge 1: Concorrência e Double-Click em "Conectar"', () {
    testWidgets(
      'Rapid double-clicks consecutivos no botão "Conectar" invocam requestAuthorization exatamente uma vez',
      (tester) async {
        final completer = Completer<bool>();
        final mockProvider = AdversarialMockGoogleProvider(
          authorized: false,
          requestAuthCompleter: completer,
        );

        await tester.pumpWidget(buildScreen(googleProvider: mockProvider));
        await tester.pumpAndSettle();

        final connectFinder = find.widgetWithText(ElevatedButton, 'Conectar');
        expect(connectFinder, findsOneWidget);

        // Primeiro clique
        await tester.tap(connectFinder);
        // Segundo clique imediato (simulando usuário impaciente ou double-click acidental)
        await tester.tap(connectFinder, warnIfMissed: false);
        // Terceiro clique imediato
        await tester.tap(connectFinder, warnIfMissed: false);

        await tester.pump(); // Dispara o frame inicial de transição de estado

        // Verifica que o estado de "Conectando..." é exibido e requestAuthorization foi disparado apenas uma vez
        expect(mockProvider.requestAuthCallCount, equals(1));
        expect(find.text('Conectando...'), findsNWidgets(2));

        // Tenta novo tap no botão enquanto está desabilitado
        final connectingButton = find.widgetWithText(ElevatedButton, 'Conectando...');
        expect(connectingButton, findsOneWidget);
        await tester.tap(connectingButton, warnIfMissed: false);
        expect(mockProvider.requestAuthCallCount, equals(1));

        // Libera o Future pendente
        completer.complete(true);
        await tester.pumpAndSettle();

        // O contador final de invocações permanece estritamente 1
        expect(mockProvider.requestAuthCallCount, equals(1));
        expect(find.text('Conta Google conectada com sucesso!'), findsOneWidget);
      },
    );

    testWidgets(
      'Após falha na primeira tentativa, botão é reabilitado permitindo nova tentativa sem deadlock',
      (tester) async {
        var completer1 = Completer<bool>();
        final mockProvider = AdversarialMockGoogleProvider(
          authorized: false,
          requestAuthCompleter: completer1,
          failureReason: GoogleAuthFailureReason.popupBlocked,
        );

        await tester.pumpWidget(buildScreen(googleProvider: mockProvider));
        await tester.pumpAndSettle();

        // 1ª tentativa
        final connectFinder = find.widgetWithText(ElevatedButton, 'Conectar');
        await tester.tap(connectFinder);
        await tester.pump();

        expect(mockProvider.requestAuthCallCount, equals(1));
        completer1.complete(false);
        await tester.pumpAndSettle();

        // SnackBar de erro de pop-up bloqueado é exibido
        expect(
          find.text(
            'Janela de login bloqueada pelo navegador. Permita pop-ups para este site e tente novamente.',
          ),
          findsOneWidget,
        );

        // Verifica que o botão voltou para "Conectar" e está reabilitado
        final reenabledBtn = find.widgetWithText(ElevatedButton, 'Conectar');
        expect(reenabledBtn, findsOneWidget);

        // Prepara 2ª tentativa (sucesso)
        final completer2 = Completer<bool>();
        mockProvider.requestAuthCompleter = completer2;
        mockProvider.failureReason = GoogleAuthFailureReason.none;

        await tester.tap(reenabledBtn);
        await tester.pump();

        expect(mockProvider.requestAuthCallCount, equals(2));
        completer2.complete(true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Conta Google conectada com sucesso!'), findsOneWidget);
        await tester.pumpAndSettle();
      },
    );
  });

  group('Adversarial Challenge 2: Matriz Completa de Propagação de Erros na UI', () {
    testWidgets(
      'Propagação correta: scopeDenied exibe SnackBar com cor laranja e texto explicativo',
      (tester) async {
        final mockProvider = AdversarialMockGoogleProvider(
          authorized: false,
          failureReason: GoogleAuthFailureReason.scopeDenied,
        );

        await tester.pumpWidget(buildScreen(googleProvider: mockProvider));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ElevatedButton, 'Conectar'));
        await tester.pumpAndSettle();

        final snackBarFinder = find.byType(SnackBar);
        expect(snackBarFinder, findsOneWidget);

        final snackBar = tester.widget<SnackBar>(snackBarFinder);
        expect(snackBar.backgroundColor, equals(Colors.orange));
        expect(
          find.text(
            'Permissão de acesso à agenda negada. Conceda permissão aos eventos para sincronizar.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Propagação correta: userCancelled exibe SnackBar com cor blueGrey e texto amigável',
      (tester) async {
        final mockProvider = AdversarialMockGoogleProvider(
          authorized: false,
          failureReason: GoogleAuthFailureReason.userCancelled,
        );

        await tester.pumpWidget(buildScreen(googleProvider: mockProvider));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ElevatedButton, 'Conectar'));
        await tester.pumpAndSettle();

        final snackBarFinder = find.byType(SnackBar);
        expect(snackBarFinder, findsOneWidget);

        final snackBar = tester.widget<SnackBar>(snackBarFinder);
        expect(snackBar.backgroundColor, equals(Colors.blueGrey));
        expect(
          find.text('Conexão com Google Calendar cancelada pelo usuário.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Propagação correta: networkError exibe SnackBar com cor vermelha',
      (tester) async {
        final mockProvider = AdversarialMockGoogleProvider(
          authorized: false,
          failureReason: GoogleAuthFailureReason.networkError,
        );

        await tester.pumpWidget(buildScreen(googleProvider: mockProvider));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ElevatedButton, 'Conectar'));
        await tester.pumpAndSettle();

        final snackBarFinder = find.byType(SnackBar);
        expect(snackBarFinder, findsOneWidget);

        final snackBar = tester.widget<SnackBar>(snackBarFinder);
        expect(snackBar.backgroundColor, equals(Colors.red));
        expect(
          find.text(
            'Falha de conexão com os servidores do Google. Verifique sua conexão com a internet.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Propagação correta: calendarApiDisabled exibe SnackBar com cor vermelha',
      (tester) async {
        final mockProvider = AdversarialMockGoogleProvider(
          authorized: false,
          failureReason: GoogleAuthFailureReason.calendarApiDisabled,
        );

        await tester.pumpWidget(buildScreen(googleProvider: mockProvider));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ElevatedButton, 'Conectar'));
        await tester.pumpAndSettle();

        final snackBarFinder = find.byType(SnackBar);
        expect(snackBarFinder, findsOneWidget);

        final snackBar = tester.widget<SnackBar>(snackBarFinder);
        expect(snackBar.backgroundColor, equals(Colors.red));
        expect(
          find.text(
            'A Google Calendar API não está habilitada no projeto Google Cloud. Habilite-a no console GCP.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Exceção inesperada durante requestAuthorization é capturada, sanitizada e reseta estado sem travar a UI',
      (tester) async {
        final mockProvider = AdversarialMockGoogleProvider(
          authorized: false,
          throwOnAuth: Exception('Uncaught SocketException: host unreachable Bearer ya29.secretToken12345'),
        );

        await tester.pumpWidget(buildScreen(googleProvider: mockProvider));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ElevatedButton, 'Conectar'));
        await tester.pumpAndSettle();

        // O token sensível DEVE ser redigido da mensagem exibida ao usuário
        expect(find.textContaining('Bearer [REDACTED]'), findsOneWidget);
        expect(find.textContaining('secretToken12345'), findsNothing);

        // O estado _isConnectingGoogle foi devidamente resetado pelo bloco finally
        expect(find.text('Conectando...'), findsNothing);
        expect(find.widgetWithText(ElevatedButton, 'Conectar'), findsOneWidget);
      },
    );
  });

  group('Adversarial Challenge 3: Proteção Estrita Contra Calendários Somente-Leitura', () {
    testWidgets(
      'Se o calendário persistido anteriormente no secure storage for somente-leitura, ele é automaticamente substituído por um calendário de escrita',
      (tester) async {
        final mockProvider = AdversarialMockGoogleProvider(
          authorized: true,
          selectedCalendarId: 'holidays_br', // Configurado previamente como read-only
          calendars: [
            ExternalCalendarItem(
              id: 'holidays_br',
              name: 'Feriados no Brasil (Leitura)',
              isReadOnly: true,
              accountName: 'publisher.test@gmail.com',
            ),
            ExternalCalendarItem(
              id: 'ministry_work',
              name: 'Ministério de Campo (Escrita)',
              isReadOnly: false,
              accountName: 'publisher.test@gmail.com',
            ),
            ExternalCalendarItem(
              id: 'personal_work',
              name: 'Agenda Pessoal (Escrita)',
              isReadOnly: false,
              accountName: 'publisher.test@gmail.com',
            ),
          ],
        );

        await tester.pumpWidget(buildScreen(googleProvider: mockProvider));
        await tester.pumpAndSettle();

        // Ao carregar a tela (_loadState), o sistema detecta que holidays_br é read-only
        // e invoca setSelectedCalendarId com o primeiro calendário gravável ('ministry_work')
        expect(mockProvider.selectedCalendarId, equals('ministry_work'));
        expect(mockProvider.setSelectedCalendarIdCallCount, equals(1));
        expect(mockProvider.selectedCalendarIdHistory, contains('ministry_work'));
        expect(mockProvider.selectedCalendarIdHistory, isNot(contains('holidays_br')));

        // O dropdown deve exibir 'ministry_work' selecionado
        final dropdownFinder = find.byType(DropdownButtonFormField<String>);
        expect(dropdownFinder, findsOneWidget);

        final innerDropdown = tester.widget<DropdownButton<String>>(
          find.descendant(
            of: dropdownFinder,
            matching: find.byType(DropdownButton<String>),
          ),
        );
        expect(innerDropdown.value, equals('ministry_work'));

        // Itens do dropdown não devem conter 'holidays_br'
        final items = innerDropdown.items ?? [];
        expect(items.any((item) => item.value == 'holidays_br'), isFalse);
        expect(items.length, equals(2));
      },
    );

    testWidgets(
      'Quando todos os calendários são somente-leitura, selectedCalendarId é anulado e o dropdown é ocultado',
      (tester) async {
        final mockProvider = AdversarialMockGoogleProvider(
          authorized: true,
          selectedCalendarId: 'readonly_1',
          calendars: [
            ExternalCalendarItem(
              id: 'readonly_1',
              name: 'Somente Leitura 1',
              isReadOnly: true,
              accountName: 'publisher.test@gmail.com',
            ),
            ExternalCalendarItem(
              id: 'readonly_2',
              name: 'Somente Leitura 2',
              isReadOnly: true,
              accountName: 'publisher.test@gmail.com',
            ),
          ],
        );

        await tester.pumpWidget(buildScreen(googleProvider: mockProvider));
        await tester.pumpAndSettle();

        // Dropdown deve sumir e aviso em itálico deve ser mostrado
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        expect(
          find.text('Nenhum calendário com permissão de escrita disponível.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Ao alterar a seleção do dropdown, apenas IDs graváveis podem ser persistidos',
      (tester) async {
        final mockProvider = AdversarialMockGoogleProvider(
          authorized: true,
          selectedCalendarId: 'cal_a',
          calendars: [
            ExternalCalendarItem(
              id: 'cal_a',
              name: 'Calendário A (Escrita)',
              isReadOnly: false,
              accountName: 'publisher.test@gmail.com',
            ),
            ExternalCalendarItem(
              id: 'cal_b',
              name: 'Calendário B (Escrita)',
              isReadOnly: false,
              accountName: 'publisher.test@gmail.com',
            ),
            ExternalCalendarItem(
              id: 'cal_c_ro',
              name: 'Calendário C (Leitura)',
              isReadOnly: true,
              accountName: 'publisher.test@gmail.com',
            ),
          ],
        );

        await tester.pumpWidget(buildScreen(googleProvider: mockProvider));
        await tester.pumpAndSettle();

        // Abre o dropdown
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();

        // Toca no item "Calendário B (Escrita)"
        final itemB = find.text('Calendário B (Escrita)').last;
        await tester.tap(itemB);
        await tester.pumpAndSettle();

        // Verifica que o novo ID gravável foi persistido
        expect(mockProvider.selectedCalendarId, equals('cal_b'));
        expect(mockProvider.selectedCalendarIdHistory, contains('cal_b'));
      },
    );
  });
}
