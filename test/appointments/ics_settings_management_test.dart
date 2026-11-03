import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/appointments/calendar_provider.dart';
import 'package:ministerio_pessoal/appointments/calendar_sync_coordinator.dart';
import 'package:ministerio_pessoal/appointments/ics_management_sheet.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/settings/backup_service.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/settings_screen.dart';
import 'package:ministerio_pessoal/ui/screens/connected_calendars_screen.dart';
import 'package:ministerio_pessoal/ui/screens/appointments_screen.dart';

class _FakeBackupService extends BackupService {
  _FakeBackupService(super.repository);

  @override
  Future<bool> performSilentBackupIfNeeded({bool force = false}) async {
    return false;
  }
}

class _MockCalendarSyncCoordinator extends CalendarSyncCoordinator {
  int syncAllCalls = 0;
  _MockCalendarSyncCoordinator(super.db);

  @override
  Future<CalendarSyncResult> syncAll({bool fullSync = false}) async {
    syncAllCalls++;
    return CalendarSyncResult(
      success: true,
      eventsDownloaded: 0,
      eventsUploaded: 0,
      conflictsFound: 0,
    );
  }
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;
  late AppRepository repository;
  late _FakeBackupService fakeBackupService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = AppRepository(db);
    fakeBackupService = _FakeBackupService(repository);
  });

  tearDown(() async {
    await db.close();
  });

  Widget createWidgetForTesting(
    Widget child, {
    CalendarSyncCoordinator? coordinator,
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repository),
        backupServiceProvider.overrideWithValue(fakeBackupService),
        if (coordinator != null)
          calendarSyncCoordinatorProvider.overrideWithValue(coordinator),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  group('Gerenciamento de Arquivo iCalendar (.ics) em Configurações', () {
    testWidgets(
      'TC-ICS-SET-01: SettingsScreen exibe o ListTile de Importar / Exportar Calendário (.ics)',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createWidgetForTesting(const SettingsScreen()));
        await tester.pumpAndSettle();

        final tileFinder = find.byKey(
          const ValueKey('settings_ics_import_export_tile'),
        );
        expect(tileFinder, findsOneWidget);
        expect(
          find.text('Importar / Exportar Calendário (.ics)'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Importação e exportação de compromissos via arquivo iCalendar.',
          ),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'TC-ICS-SET-02: Tocar no ListTile em Configurações abre o modal com as opções de .ics',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createWidgetForTesting(const SettingsScreen()));
        await tester.pumpAndSettle();

        final tileFinder = find.byKey(
          const ValueKey('settings_ics_import_export_tile'),
        );
        await tester.scrollUntilVisible(tileFinder, 50);
        await tester.tap(tileFinder);
        await tester.pumpAndSettle();

        // Verifica título do modal
        expect(
          find.text('Importar / Exportar Calendário (.ics)'),
          findsAtLeast(1),
        );

        // Verifica cartões e botões
        expect(find.text('Google Agenda (Google Calendar)'), findsOneWidget);
        expect(
          find.text('Exportar todos para Google Agenda (.ics)'),
          findsOneWidget,
        );
        expect(find.text('Selecionar Arquivo .ics'), findsOneWidget);
        expect(find.text('Colar da Área de Transferência'), findsAtLeast(1));
        expect(find.text('Colar Texto .ics'), findsOneWidget);

        expect(
          find.text('Apple Calendar / iCloud (iPhone / iPad)'),
          findsOneWidget,
        );
        expect(
          find.text('Exportar para Apple Calendar (.ics)'),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'TC-ICS-SET-03: ConnectedCalendarsScreen oferece botão de gerenciar arquivo .ics',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createWidgetForTesting(const ConnectedCalendarsScreen()),
        );
        await tester.pumpAndSettle();

        final icsButton = find.text(
          'Importar / Exportar Arquivo .ics (iCalendar)',
        );
        expect(icsButton, findsOneWidget);

        await tester.scrollUntilVisible(icsButton, 50);
        await tester.tap(icsButton);
        await tester.pumpAndSettle();

        expect(
          find.text('Exportar todos para Google Agenda (.ics)'),
          findsOneWidget,
        );
        expect(
          find.text('Exportar para Apple Calendar (.ics)'),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'TC-ICS-SET-04: AppointmentsScreen não exibe mais o banner de configuração de arquivo .ics',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createWidgetForTesting(const AppointmentsScreen()),
        );
        await tester.pumpAndSettle();

        // Banner anterior de configuração de .ics não deve mais existir na tela de Agenda
        expect(
          find.text('Sincronizar com Google Agenda & Apple (.ics)'),
          findsNothing,
        );
        expect(find.text('Configurar / Importar'), findsNothing);

        // A tela deve estar limpa e focada no calendário e nos controles
        expect(find.text('Agenda do Ministério'), findsOneWidget);
        expect(find.text('Mês'), findsOneWidget);
        expect(find.text('Semana'), findsOneWidget);
        expect(find.text('Dia'), findsOneWidget);
        expect(find.text('Lista'), findsOneWidget);

        // Botão da AppBar para sincronizar contas conectadas permanece acessível
        expect(find.byIcon(Icons.sync), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'TC-ICS-SET-05: AppLifecycleState.resumed dispara sincronização automática na Agenda',
      (tester) async {
        final mockCoordinator = _MockCalendarSyncCoordinator(db);

        await tester.pumpWidget(
          createWidgetForTesting(
            const AppointmentsScreen(),
            coordinator: mockCoordinator,
          ),
        );
        await tester.pumpAndSettle();

        // Ao inicializar AppointmentsScreen, initState dispara a sincronização inicial
        expect(mockCoordinator.syncAllCalls, equals(1));

        // Simula minimização e retorno ao app (resumed)
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        // Sincronização deve ter sido disparada novamente
        expect(mockCoordinator.syncAllCalls, equals(2));

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'TC-ICS-SET-06: showPasteIcsDialog importa texto VCALENDAR com sucesso para o banco Drift',
      (tester) async {
        await tester.pumpWidget(
          createWidgetForTesting(
            Consumer(
              builder: (ctx, ref, _) => ElevatedButton(
                onPressed: () => showPasteIcsDialog(ctx, ref),
                child: const Text('Abrir Dialog'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Abrir Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Colar Conteúdo .ics / iCal'), findsOneWidget);

        const sampleIcs = '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Test//EN
BEGIN:VEVENT
UID:manual-paste-1@google.com
DTSTART:20261110T090000Z
DTEND:20261110T100000Z
SUMMARY:Visita Pastoral Ana
LOCATION:Rua das Flores 123
STATUS:CONFIRMED
END:VEVENT
END:VCALENDAR''';

        await tester.enterText(find.byType(TextField), sampleIcs);
        await tester.pump();

        await tester.tap(find.text('Importar'));
        await tester.pumpAndSettle();

        // Verifica se o compromisso foi inserido no banco de dados Drift
        final appts = await db.select(db.appointments).get();
        expect(appts.length, equals(1));
        expect(appts.first.title, equals('Visita Pastoral Ana'));
        expect(appts.first.locationNotes, equals('Rua das Flores 123'));

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'TC-ICS-SET-07: showIcsExportResultDialog exibe diálogo com opção de copiar iCal',
      (tester) async {
        const icsSample = 'BEGIN:VCALENDAR\nVERSION:2.0\nEND:VCALENDAR';
        await tester.pumpWidget(
          createWidgetForTesting(
            Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showIcsExportResultDialog(ctx, icsSample),
                child: const Text('Exportar'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Exportar'));
        await tester.pumpAndSettle();

        expect(find.text('Arquivo .ics Gerado com Sucesso'), findsOneWidget);
        expect(
          find.text('Copiar Conteúdo iCal para a Área de Transferência'),
          findsOneWidget,
        );

        await tester.tap(
          find.text('Copiar Conteúdo iCal para a Área de Transferência'),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('iCal copiado para a área de transferência!'),
          findsOneWidget,
        );

        await tester.tap(find.text('Entendido'));
        await tester.pumpAndSettle();

        expect(find.text('Arquivo .ics Gerado com Sucesso'), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });
}
