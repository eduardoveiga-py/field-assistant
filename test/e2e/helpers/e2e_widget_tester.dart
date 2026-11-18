import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/src/internals.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/core/app_theme.dart';
import 'package:ministerio_pessoal/inbox/inbox_manager.dart';
import 'package:ministerio_pessoal/knowledge/knowledge_manager.dart';
import 'package:ministerio_pessoal/main.dart';
import 'package:ministerio_pessoal/projects/project_manager.dart';
import 'package:ministerio_pessoal/settings/backup_service.dart';
import 'package:ministerio_pessoal/tasks/task_manager.dart';
import 'package:ministerio_pessoal/ui/providers.dart';

import 'e2e_test_context.dart';

// ignore: implementation_imports
export 'package:flutter_riverpod/src/internals.dart' show Override;

export 'e2e_test_context.dart';

/// Predefined standard screen dimensions and device pixel ratios for responsive
/// opaque-box E2E UI testing across mobile, tablet, and desktop viewports.
enum E2EDevicePreset {
  /// iPhone standard screen (390 x 844 dp, devicePixelRatio: 1.0).
  phone(Size(390, 844), 1.0),

  /// Compact mobile viewport (360 x 640 dp, devicePixelRatio: 1.0).
  phoneSmall(Size(360, 640), 1.0),

  /// Large mobile / Phablet viewport (430 x 932 dp, devicePixelRatio: 1.0).
  phoneLarge(Size(430, 932), 1.0),

  /// iPad standard landscape viewport (1024 x 768 dp, devicePixelRatio: 1.0).
  /// Exceeds the adaptive layout threshold (`isWide >= 900 dp`) to trigger
  /// master-detail two-pane split views.
  tablet(Size(1024, 768), 1.0),

  /// iPad portrait viewport (768 x 1024 dp, devicePixelRatio: 1.0).
  tabletPortrait(Size(768, 1024), 1.0),

  /// Desktop / Full-width viewport (1280 x 800 dp, devicePixelRatio: 1.0).
  desktop(Size(1280, 800), 1.0);

  final Size size;
  final double pixelRatio;

  const E2EDevicePreset(this.size, this.pixelRatio);

  /// True when width is greater than or equal to 900 dp (adaptive master-detail breakpoint).
  bool get isWide => size.width >= 900;
}

/// Generates hermetic Riverpod [Override]s binding all core application providers
/// to the isolated in-memory dependencies managed by [context].
///
/// If [additionalOverrides] contains an override for a provider that is already in
/// the default list, the custom override in [additionalOverrides] takes precedence,
/// preventing duplicate override errors.
List<Override> createHermeticRiverpodOverrides(
  E2ETestContext context, {
  List<Override> additionalOverrides = const [],
}) {
  final overriddenOrigins = <Object?>{
    for (final extra in additionalOverrides) extra.origin,
  };

  final defaultOverrides = <Override>[
    databaseProvider.overrideWithValue(context.db),
    repositoryProvider.overrideWithValue(context.repo),
    backupServiceProvider.overrideWithValue(BackupService(context.repo)),
    inboxManagerProvider.overrideWithValue(InboxManager(db: context.db)),
    taskManagerProvider.overrideWithValue(TaskManager(db: context.db)),
    projectManagerProvider.overrideWithValue(ProjectManager(db: context.db)),
    knowledgeManagerProvider.overrideWithValue(
      KnowledgeManager(db: context.db),
    ),
  ];

  final filteredDefaults = defaultOverrides.where(
    (item) => !overriddenOrigins.contains(item.origin),
  );

  return [...filteredDefaults, ...additionalOverrides];
}

/// Builds a testable root widget hierarchy wrapping [child] in a hermetic [ProviderScope]
/// and a fully localized [MaterialApp].
Widget buildE2ETestApp({
  required Widget child,
  required E2ETestContext context,
  List<Override> additionalOverrides = const [],
  ThemeData? theme,
  ThemeData? darkTheme,
  ThemeMode themeMode = ThemeMode.system,
  Locale locale = const Locale('pt', 'BR'),
  List<NavigatorObserver> navigatorObservers = const [],
}) {
  return ProviderScope(
    overrides: createHermeticRiverpodOverrides(
      context,
      additionalOverrides: additionalOverrides,
    ),
    child: MaterialApp(
      title: 'E2E Opaque-Box Test Harness',
      debugShowCheckedModeBanner: false,
      theme: theme ?? AppTheme.lightTheme,
      darkTheme: darkTheme ?? AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      navigatorObservers: navigatorObservers,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'),
        Locale('es', 'ES'),
      ],
      home: child,
    ),
  );
}

/// Extension on [WidgetTester] providing opaque-box UI pumping and interaction helpers
/// tailored for hermetic E2E tests.
extension E2EWidgetTesterExtension on WidgetTester {
  /// Sets the test viewport physical size and device pixel ratio.
  /// Automatically registers a [tearDown] callback to reset the view.
  void setE2EViewport({required Size size, double pixelRatio = 1.0}) {
    view.physicalSize = size;
    view.devicePixelRatio = pixelRatio;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  }

  /// Sets the test viewport using a predefined [E2EDevicePreset].
  void setE2EDevicePreset(E2EDevicePreset preset) {
    setE2EViewport(size: preset.size, pixelRatio: preset.pixelRatio);
  }

  /// Pumps a specific screen or widget wrapped with hermetic Riverpod overrides
  /// and localized [MaterialApp], then settles all animations safely.
  Future<void> pumpE2EScreen({
    required Widget screen,
    required E2ETestContext context,
    List<Override> additionalOverrides = const [],
    E2EDevicePreset devicePreset = E2EDevicePreset.phone,
    ThemeMode themeMode = ThemeMode.system,
    Locale locale = const Locale('pt', 'BR'),
    Duration? settleTimeout,
    List<NavigatorObserver> navigatorObservers = const [],
  }) async {
    setE2EDevicePreset(devicePreset);
    await pumpWidget(
      buildE2ETestApp(
        child: screen,
        context: context,
        additionalOverrides: additionalOverrides,
        themeMode: themeMode,
        locale: locale,
        navigatorObservers: navigatorObservers,
      ),
    );
    await pumpAndSettle();
  }

  /// Pumps the entire application [MinisterioPessoalApp] with hermetic overrides
  /// and settles all startup transitions safely.
  Future<void> pumpE2EMasterApp({
    required E2ETestContext context,
    List<Override> additionalOverrides = const [],
    E2EDevicePreset devicePreset = E2EDevicePreset.phone,
    Duration? settleTimeout,
  }) async {
    setE2EDevicePreset(devicePreset);
    await pumpWidget(
      ProviderScope(
        overrides: createHermeticRiverpodOverrides(
          context,
          additionalOverrides: additionalOverrides,
        ),
        child: const MinisterioPessoalApp(),
      ),
    );
    await pumpAndSettle();
  }

  /// Repeatedly calls [pump] until no further frames are scheduled or until [timeout] expires.
  /// Unlike standard [pumpAndSettle], this helper does not throw a fatal error when continuous
  /// animations (such as CircularProgressIndicator) keep frames scheduled, enabling safe
  /// assertion execution.
  Future<void> pumpAndSettleSafely({
    Duration step = const Duration(milliseconds: 50),
    Duration? timeout,
    int maxPumps = 50,
  }) async {
    int count = 0;
    final effectiveTimeout = timeout ?? const Duration(seconds: 3);
    final end = DateTime.now().add(effectiveTimeout);
    while (count < maxPumps && DateTime.now().isBefore(end)) {
      await pump(step);
      count++;
      if (!binding.hasScheduledFrame) {
        break;
      }
    }
  }

  /// Taps [finder] and settles animations.
  Future<void> tapAndSettle(
    Finder finder, {
    Duration? settleTimeout,
    int? pointer,
    int buttons = kPrimaryButton,
  }) async {
    await tap(finder, pointer: pointer, buttons: buttons);
    await pumpAndSettle();
  }

  /// Enters [text] into [finder] and pumps a frame for text update.
  Future<void> enterTextAndSettle(
    Finder finder,
    String text, {
    Duration? settleTimeout,
  }) async {
    await enterText(finder, text);
    await pump();
  }

  /// Scrolls [scrollable] until [item] is visible, then settles safely.
  Future<void> scrollUntilVisibleSafely({
    required Finder finder,
    required Finder scrollable,
    double delta = 50.0,
    int maxScrolls = 50,
  }) async {
    await scrollUntilVisible(
      finder,
      delta,
      scrollable: scrollable,
      maxScrolls: maxScrolls,
    );
    await pumpAndSettleSafely();
  }
}

/// Extension on [E2ETestContext] providing direct convenience methods to pump
/// screens and the master application using the context's isolated resources.
extension E2ETestContextWidgetExtension on E2ETestContext {
  /// Pumps a screen using this context's hermetic dependencies.
  Future<void> pumpScreen(
    WidgetTester tester, {
    required Widget screen,
    List<Override> additionalOverrides = const [],
    E2EDevicePreset devicePreset = E2EDevicePreset.phone,
    ThemeMode themeMode = ThemeMode.system,
    Locale locale = const Locale('pt', 'BR'),
    Duration? settleTimeout,
    List<NavigatorObserver> navigatorObservers = const [],
  }) async {
    await tester.pumpE2EScreen(
      screen: screen,
      context: this,
      additionalOverrides: additionalOverrides,
      devicePreset: devicePreset,
      themeMode: themeMode,
      locale: locale,
      settleTimeout: settleTimeout,
      navigatorObservers: navigatorObservers,
    );
  }

  /// Pumps the entire [MinisterioPessoalApp] using this context's hermetic dependencies.
  Future<void> pumpMasterApp(
    WidgetTester tester, {
    List<Override> additionalOverrides = const [],
    E2EDevicePreset devicePreset = E2EDevicePreset.phone,
    Duration? settleTimeout,
  }) async {
    await tester.pumpE2EMasterApp(
      context: this,
      additionalOverrides: additionalOverrides,
      devicePreset: devicePreset,
      settleTimeout: settleTimeout,
    );
  }

  /// Returns the hermetic Riverpod overrides tied to this context.
  List<Override> riverpodOverrides({
    List<Override> additionalOverrides = const [],
  }) {
    return createHermeticRiverpodOverrides(
      this,
      additionalOverrides: additionalOverrides,
    );
  }
}
