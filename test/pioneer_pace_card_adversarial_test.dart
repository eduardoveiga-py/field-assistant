import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:ministerio_pessoal/ui/widgets/pioneer_pace_card.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/settings/app_settings_manager.dart';
import 'package:ministerio_pessoal/ui/providers.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('ADV-01: Rapid Theme Toggling Under Active State (Light -> Dark -> SunMode)', () {
    late AppDatabase db;
    late AppSettingsManager settings;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      settings = AppSettingsManager(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('30 rapid theme & SunMode toggle cycles preserve state with zero errors', (tester) async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appSettingsManagerProvider.overrideWithValue(settings),
        ],
      );
      addTearDown(container.dispose);

      bool isDark = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: StatefulBuilder(
            builder: (context, setState) {
              return MaterialApp(
                theme: ThemeData(brightness: isDark ? Brightness.dark : Brightness.light),
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: Column(
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() => isDark = !isDark);
                            container.read(sunModeProvider.notifier).toggle();
                          },
                          child: const Text('Toggle'),
                        ),
                        PioneerPaceCard(
                          currentMonthCompletedHours: 25.0,
                          currentDateOverride: DateTime(2026, 10, 15),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ritmo Real de Campo'), findsOneWidget);
      expect(find.text('Feitas: 25h de 50h (50%)'), findsOneWidget);

      // Perform 30 rapid toggle cycles
      for (int i = 0; i < 30; i++) {
        await tester.tap(find.text('Toggle'));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // State and UI must remain fully intact with no uncaught exceptions
      expect(tester.takeException(), isNull);
      expect(find.text('Ritmo Real de Campo'), findsOneWidget);
      expect(find.text('Feitas: 25h de 50h (50%)'), findsOneWidget);
    });

    testWidgets('SunMode visual contract: black 2.0dp border and monochromatic contrast', (tester) async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appSettingsManagerProvider.overrideWithValue(settings),
        ],
      );
      addTearDown(container.dispose);

      // Start with SunMode = true
      container.read(sunModeProvider.notifier).state = true;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(brightness: Brightness.light),
            home: Scaffold(
              body: PioneerPaceCard(
                currentMonthCompletedHours: 15.0,
                currentDateOverride: DateTime(2026, 10, 15),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final containerWidget = tester.widget<Container>(find.byType(Container).first);
      final decoration = containerWidget.decoration as BoxDecoration;
      expect(decoration.color, equals(Colors.white));
      final border = decoration.border as Border;
      expect(border.top.color, equals(Colors.black));
      expect(border.top.width, equals(2.0));

      // Toggle off to standard Light mode
      container.read(sunModeProvider.notifier).state = false;
      await tester.pumpAndSettle();

      final lightContainer = tester.widget<Container>(find.byType(Container).first);
      final lightDecoration = lightContainer.decoration as BoxDecoration;
      final lightBorder = lightDecoration.border as Border;
      expect(lightBorder.top.color, isNot(equals(Colors.black)));
      expect(lightBorder.top.width, equals(1.0));
      expect(tester.takeException(), isNull);
    });
  });

  group('ADV-02: Screen Size Constraints & Dynamic Text Scaling (RenderFlex Overflow Stress)', () {
    late AppDatabase db;
    late AppSettingsManager settings;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      settings = AppSettingsManager(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Small screen (320x480 dp) with standard text scale factor 1.0x', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            appSettingsManagerProvider.overrideWithValue(settings),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PioneerPaceCard(
                  currentMonthCompletedHours: 20.0,
                  currentDateOverride: DateTime(2026, 10, 15),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'RenderFlex overflow occurred on 320x480 at 1.0x scale');
      expect(find.text('Ritmo Real de Campo'), findsOneWidget);
    });

    testWidgets('Small screen (320x480 dp) with extreme dynamic text scaling (TextScaler 2.0x)', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            appSettingsManagerProvider.overrideWithValue(settings),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 480),
                textScaler: TextScaler.linear(2.0),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: PioneerPaceCard(
                    currentMonthCompletedHours: 20.5,
                    currentDateOverride: DateTime(2026, 10, 15),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final exception = tester.takeException();
      expect(exception, isNull, reason: 'RenderFlex overflow observed at 320x480 with TextScaler 2.0x: $exception');
    });

    testWidgets('Configuration dialog opened on 320x480 with TextScaler 2.0x does not overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            appSettingsManagerProvider.overrideWithValue(settings),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 480),
                textScaler: TextScaler.linear(2.0),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: PioneerPaceCard(
                    currentMonthCompletedHours: 10.0,
                    currentDateOverride: DateTime(2026, 10, 15),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      expect(find.text('Configurar Ritmo de Campo'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Dialog overflowed under TextScaler 2.0x');
    });
  });

  group('ADV-03: Ergonomic Touch Targets (>= 48x48 dp Minimum Bounding Box)', () {
    late AppDatabase db;
    late AppSettingsManager settings;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      settings = AppSettingsManager(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('IconButton(Icons.tune) maintains >= 48x48 dp touch target', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            appSettingsManagerProvider.overrideWithValue(settings),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PioneerPaceCard(
                currentMonthCompletedHours: 20.0,
                currentDateOverride: DateTime(2026, 10, 15),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tuneFinder = find.byTooltip('Configurar Meta e Dias de Campo');
      expect(tuneFinder, findsOneWidget);
      final size = tester.getSize(tuneFinder);
      expect(size.width, greaterThanOrEqualTo(48.0), reason: 'IconButton width is < 48dp: ${size.width}');
      expect(size.height, greaterThanOrEqualTo(48.0), reason: 'IconButton height is < 48dp: ${size.height}');
    });

    testWidgets('All dialog touch targets (ChoiceChips, FilterChips, Buttons) maintain >= 48x48 dp bounding boxes', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            appSettingsManagerProvider.overrideWithValue(settings),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PioneerPaceCard(
                currentMonthCompletedHours: 20.0,
                currentDateOverride: DateTime(2026, 10, 15),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      // 1. ChoiceChips
      for (final label in ['50h (Regular)', '30h (Auxiliar)', '15h (Reduzida)']) {
        final chipFinder = find.widgetWithText(ChoiceChip, label);
        expect(chipFinder, findsOneWidget);
        final size = tester.getSize(chipFinder);
        expect(size.width, greaterThanOrEqualTo(48.0), reason: 'ChoiceChip $label width < 48dp: ${size.width}');
        expect(size.height, greaterThanOrEqualTo(48.0), reason: 'ChoiceChip $label height < 48dp: ${size.height}');
      }

      // 2. Action buttons
      final cancelFinder = find.widgetWithText(TextButton, 'Cancelar');
      expect(cancelFinder, findsOneWidget);
      final cancelSize = tester.getSize(cancelFinder);
      expect(cancelSize.width, greaterThanOrEqualTo(48.0), reason: 'Cancelar button width < 48dp: ${cancelSize.width}');
      expect(cancelSize.height, greaterThanOrEqualTo(48.0), reason: 'Cancelar button height < 48dp: ${cancelSize.height}');

      final saveFinder = find.widgetWithText(ElevatedButton, 'Salvar');
      expect(saveFinder, findsOneWidget);
      final saveSize = tester.getSize(saveFinder);
      expect(saveSize.width, greaterThanOrEqualTo(48.0), reason: 'Salvar button width < 48dp: ${saveSize.width}');
      expect(saveSize.height, greaterThanOrEqualTo(48.0), reason: 'Salvar button height < 48dp: ${saveSize.height}');

      // 3. Weekday FilterChips
      for (final dayLabel in ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom']) {
        final dayFinder = find.widgetWithText(FilterChip, dayLabel);
        expect(dayFinder, findsOneWidget);
        final size = tester.getSize(dayFinder);
        expect(size.width, greaterThanOrEqualTo(48.0), reason: 'FilterChip $dayLabel width < 48dp: ${size.width}');
        expect(size.height, greaterThanOrEqualTo(48.0), reason: 'FilterChip $dayLabel height < 48dp: ${size.height}');
      }
    });
  });

  group('ADV-04: Concurrent Asynchronous Persistence & High-Frequency Input Stress', () {
    late AppDatabase db;
    late AppSettingsManager settings;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      settings = AppSettingsManager(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Rapidly alternating ChoiceChips and FilterChips before saving produces clean state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            appSettingsManagerProvider.overrideWithValue(settings),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PioneerPaceCard(
                currentMonthCompletedHours: 10.0,
                currentDateOverride: DateTime(2026, 10, 15),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      // Rapidly toggle choices back and forth
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.text('30h (Auxiliar)'));
        await tester.pump();
        await tester.tap(find.text('15h (Reduzida)'));
        await tester.pump();
        await tester.tap(find.text('50h (Regular)'));
        await tester.pump();
      }

      // Rapidly toggle weekday chips
      for (final day in ['Seg', 'Dom', 'Sex', 'Qua']) {
        await tester.tap(find.text(day));
        await tester.pump();
      }

      // Enter decimal hours in text field
      final textField = find.byType(TextField);
      await tester.enterText(textField, '42.5');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      // Hit save
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      // Verify that database reflects exactly the final chosen values
      final savedGoal = await settings.getString('pioneer_goal_hours');
      final savedWeekdays = await settings.getString('pioneer_weekdays');

      expect(savedGoal, equals('42.5'));
      expect(savedWeekdays, isNotNull);
      final parsedDays = savedWeekdays!.split(',').map(int.parse).toList();
      expect(parsedDays, equals(List<int>.from(parsedDays)..sort()), reason: 'Saved weekdays must be sorted');

      // Verify immediate reflection on card
      expect(find.textContaining('Feitas: 10h de 42.5h'), findsOneWidget);
    });

    testWidgets('Typing invalid, negative, or comma decimal numbers handles gracefully', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            appSettingsManagerProvider.overrideWithValue(settings),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PioneerPaceCard(
                currentMonthCompletedHours: 5.0,
                currentDateOverride: DateTime(2026, 10, 15),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);

      // Comma decimal (e.g. 35,5) should parse correctly
      await tester.enterText(textField, '35,5');
      await tester.pump();

      // Negative value should be ignored (guard: parsed > 0)
      await tester.enterText(textField, '-10');
      await tester.pump();

      // Text should not crash
      await tester.enterText(textField, 'invalid_abc');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      // If last valid input before invalid was 35.5, it should retain 35.5 or fallback gracefully
      final savedGoal = await settings.getString('pioneer_goal_hours');
      expect(savedGoal, equals('35.5'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Unselecting all weekdays saves empty string but reloading silently reverts to default [2, 4, 6]', (tester) async {
      await settings.setString('pioneer_goal_hours', '50.0');
      await settings.setString('pioneer_weekdays', ''); // saved empty list of days

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            appSettingsManagerProvider.overrideWithValue(settings),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PioneerPaceCard(
                currentMonthCompletedHours: 10.0,
                currentDateOverride: DateTime(2026, 10, 15),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // When user saved 0 designated weekdays, remainingOutings should be 0.
      // But due to bug in _loadSettings:
      // if (weekdaysStr != null && weekdaysStr.isNotEmpty)
      // an empty string is ignored and _designatedWeekdays reverts to default [2, 4, 6]!
      expect(find.textContaining('0 saída(s) restante(s)'), findsOneWidget);
    });
  });

  group('ADV-05: Reactive Instant UI Updates (Zero-Reload / Zero-Glitch State Reflection)', () {
    late AppDatabase db;
    late AppSettingsManager settings;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      settings = AppSettingsManager(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Saving new goal directly recalculates pace text and progress indicator synchronously', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            appSettingsManagerProvider.overrideWithValue(settings),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PioneerPaceCard(
                currentMonthCompletedHours: 30.0,
                currentDateOverride: DateTime(2026, 10, 6),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state: 30h of 50h (60%)
      expect(find.text('Feitas: 30h de 50h (60%)'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);

      // Change goal to 30h (Auxiliary)
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      await tester.tap(find.text('30h (Auxiliar)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      // Card immediately displays goal reached (30h of 30h = 100%)
      expect(find.text('Feitas: 30h de 30h (100%)'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.celebration), findsOneWidget);
      expect(find.text('Meta atingida! Parabéns pelo empenho no ministério.'), findsOneWidget);
    });
  });
}
