import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/ui/providers.dart';

import 'e2e_widget_tester.dart';

// Sample widget used to exercise opaque-box UI pumping and Riverpod reactivity.
class _SampleTestScreen extends ConsumerStatefulWidget {
  const _SampleTestScreen();

  @override
  ConsumerState<_SampleTestScreen> createState() => _SampleTestScreenState();
}

class _SampleTestScreenState extends ConsumerState<_SampleTestScreen> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sample E2E Test Screen')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Counter: $_counter', key: const Key('text_counter')),
            Text(
              'DB Dialect: ${db.executor.dialect.name}',
              key: const Key('text_db_dialect'),
            ),
            ElevatedButton(
              key: const Key('btn_increment'),
              onPressed: () {
                setState(() {
                  _counter++;
                });
              },
              child: const Text('Increment'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('E2EDevicePreset Viewport Tests', () {
    test('presets have correct dimensions and isWide characteristics', () {
      expect(E2EDevicePreset.phone.size.width, equals(390));
      expect(E2EDevicePreset.phone.size.height, equals(844));
      expect(E2EDevicePreset.phone.isWide, isFalse);

      expect(E2EDevicePreset.phoneSmall.size.width, equals(360));
      expect(E2EDevicePreset.phoneSmall.isWide, isFalse);

      expect(E2EDevicePreset.phoneLarge.size.width, equals(430));
      expect(E2EDevicePreset.phoneLarge.isWide, isFalse);

      expect(E2EDevicePreset.tablet.size.width, equals(1024));
      expect(E2EDevicePreset.tablet.size.height, equals(768));
      expect(E2EDevicePreset.tablet.isWide, isTrue);

      expect(E2EDevicePreset.tabletPortrait.size.width, equals(768));
      expect(E2EDevicePreset.tabletPortrait.isWide, isFalse);

      expect(E2EDevicePreset.desktop.size.width, equals(1280));
      expect(E2EDevicePreset.desktop.isWide, isTrue);
    });
  });

  group('createHermeticRiverpodOverrides Tests', () {
    test('creates default overrides without errors', () async {
      final ctx = await E2ETestContext.create();
      addTearDown(ctx.dispose);

      final overrides = createHermeticRiverpodOverrides(ctx);
      expect(overrides.length, equals(7));
    });

    test(
      'additionalOverrides properly override defaults without duplicates',
      () async {
        final ctx1 = await E2ETestContext.create();
        final ctx2 = await E2ETestContext.create();
        addTearDown(ctx1.dispose);
        addTearDown(ctx2.dispose);

        final customDbOverride = databaseProvider.overrideWithValue(ctx2.db);
        final overrides = createHermeticRiverpodOverrides(
          ctx1,
          additionalOverrides: [customDbOverride],
        );

        // Must have exactly 7 overrides (databaseProvider not duplicated)
        expect(overrides.length, equals(7));

        // ProviderContainer must initialize without throwing duplicate override error
        final container = ProviderContainer(overrides: overrides);
        addTearDown(container.dispose);

        // Verifies that ctx2.db is returned by databaseProvider
        expect(container.read(databaseProvider), equals(ctx2.db));
        expect(container.read(databaseProvider), isNot(equals(ctx1.db)));
      },
    );
  });

  group('E2EWidgetTester UI & Opaque-Box Interaction Tests', () {
    testWidgets('pumps screen in phone viewport and performs button tap', (
      tester,
    ) async {
      late E2ETestContext ctx;
      await tester.runAsync(() async {
        ctx = await E2ETestContext.create();
      });
      addTearDown(() async {
        await tester.runAsync(ctx.dispose);
      });

      await tester.pumpE2EScreen(
        screen: const _SampleTestScreen(),
        context: ctx,
        devicePreset: E2EDevicePreset.phone,
      );

      // Assert phone size
      expect(tester.view.physicalSize.width, equals(390));
      expect(tester.view.physicalSize.height, equals(844));

      // Check initial UI state
      expect(find.text('Sample E2E Test Screen'), findsOneWidget);
      expect(find.text('Counter: 0'), findsOneWidget);
      expect(find.text('DB Dialect: sqlite'), findsOneWidget);

      // Tap button and verify state update
      await tester.tapAndSettle(find.byKey(const Key('btn_increment')));
      expect(find.text('Counter: 1'), findsOneWidget);

      await tester.tapAndSettle(find.byKey(const Key('btn_increment')));
      expect(find.text('Counter: 2'), findsOneWidget);
    });

    testWidgets(
      'E2ETestContext.pumpScreen extension works with tablet preset',
      (tester) async {
        late E2ETestContext ctx;
        await tester.runAsync(() async {
          ctx = await E2ETestContext.create();
        });
        addTearDown(() async {
          await tester.runAsync(ctx.dispose);
        });

        // Use context extension directly
        await ctx.pumpScreen(
          tester,
          screen: const _SampleTestScreen(),
          devicePreset: E2EDevicePreset.tablet,
        );

        // Assert tablet size (isWide >= 900)
        expect(tester.view.physicalSize.width, equals(1024));
        expect(tester.view.physicalSize.height, equals(768));
        expect(find.text('Counter: 0'), findsOneWidget);
      },
    );

    testWidgets(
      'setE2EDevicePreset configures viewport and tearDown restores defaults',
      (tester) async {
        tester.setE2EDevicePreset(E2EDevicePreset.desktop);
        expect(tester.view.physicalSize.width, equals(1280));
        expect(tester.view.physicalSize.height, equals(800));
      },
    );
  });
}
