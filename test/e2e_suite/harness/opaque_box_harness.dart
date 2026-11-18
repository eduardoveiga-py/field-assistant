import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/src/internals.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/core/app_theme.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/inbox/inbox_manager.dart';
import 'package:ministerio_pessoal/knowledge/knowledge_manager.dart';
import 'package:ministerio_pessoal/projects/project_manager.dart';
import 'package:ministerio_pessoal/settings/app_settings_manager.dart';
import 'package:ministerio_pessoal/settings/backup_service.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:ministerio_pessoal/tasks/task_manager.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'airplane_network_gate.dart';
import 'in_memory_encrypted_db.dart';
import 'tile_server_test_lifecycle.dart';

export 'airplane_network_gate.dart';
export 'in_memory_encrypted_db.dart';
export 'synthetic_vector_fixtures.dart';
export 'tile_server_test_lifecycle.dart';

/// Predefinições canônicas de dispositivos e viewports para testes opaque-box
/// (iPhone 390x844, iPad 1024x768 landscape com master-detail split, etc.).
enum E2EDevicePreset {
  /// iPhone padrão (390 x 844 dp, pixelRatio: 1.0).
  phone(Size(390, 844), 1.0),

  /// iPhone compacto (360 x 640 dp, pixelRatio: 1.0).
  phoneSmall(Size(360, 640), 1.0),

  /// iPhone / Phablet grande (430 x 932 dp, pixelRatio: 1.0).
  phoneLarge(Size(430, 932), 1.0),

  /// iPad padrão em paisagem (1024 x 768 dp, pixelRatio: 1.0).
  /// Ultrapassa o breakpoint adaptativo (`isWide >= 900 dp`), ativando a divisão
  /// master-detail de dois painéis lado a lado.
  tablet(Size(1024, 768), 1.0),

  /// iPad em modo retrato (768 x 1024 dp, pixelRatio: 1.0).
  tabletPortrait(Size(768, 1024), 1.0),

  /// Desktop / Telas amplas (1280 x 800 dp, pixelRatio: 1.0).
  desktop(Size(1280, 800), 1.0);

  final Size size;
  final double pixelRatio;

  const E2EDevicePreset(this.size, this.pixelRatio);

  /// True quando a largura ativa o modo amplo (`isWide >= 900`).
  bool get isWide => size.width >= 900;
}

/// Harness unificado e hermético de testes E2E Opaque-Box para o Field Assistant.
///
/// Encapsula de forma integrada:
/// 1. Modo Avião Fail-Closed ([AirplaneNetworkGate]): intercepta todas as chamadas HTTP
///    externas, autorizando exclusivamente loopback local (`127.0.0.1`, `localhost`).
/// 2. Banco de Dados SQLite Hermético ([AppDatabase] via [InMemoryEncryptedDb]): isolado
///    com `PRAGMA foreign_keys = ON;` e suporte a SQLite3MultipleCiphers ChaCha20.
/// 3. Servidor de Tiles Vetoriais Loopback ([TileServerTestLifecycle]): vinculado a
///    `127.0.0.1` em porta efêmera com desligamento limpo automático.
/// 4. Sincronização e Repositório Offline: [AppRepository], [AppSettingsManager],
///    [SupabaseSyncService] desacoplados com [MockClient].
/// 5. Injeção Riverpod e Predefinições de Dispositivo (Phone / Tablet / Desktop).
class OpaqueBoxHarness {
  final AppDatabase db;
  final AppRepository repo;
  final AppSettingsManager settings;
  final TileServerTestLifecycle? tileServer;
  final AirplaneNetworkGate networkGate;
  final Directory tempDir;
  final SupabaseSyncService syncService;
  final MockClient mockHttpClient;
  final SupabaseClient supabaseClient;
  bool _isDisposed = false;

  OpaqueBoxHarness._({
    required this.db,
    required this.repo,
    required this.settings,
    required this.tileServer,
    required this.networkGate,
    required this.tempDir,
    required this.syncService,
    required this.mockHttpClient,
    required this.supabaseClient,
  });

  /// Cria e inicializa o ambiente de teste hermético.
  ///
  /// ```dart
  /// final harness = await OpaqueBoxHarness.create(airplaneMode: true);
  /// addTearDown(harness.dispose);
  /// ```
  static Future<OpaqueBoxHarness> create({
    bool airplaneMode = true,
    bool startTileServer = true,
    AppDatabase? customDb,
    Future<http.Response> Function(http.Request request)? mockHttpHandler,
    String? supabaseUrl,
    String? supabaseAnonKey,
  }) async {
    final tempDir = Directory.systemTemp.createTempSync('e2e_opaque_box_');

    // 1. Inicializa o Network Gate fail-closed
    final networkGate = AirplaneNetworkGate(
      airplaneModeActive: airplaneMode,
    )..install();

    // 2. Inicializa o TileServer local (se requisitado)
    TileServerTestLifecycle? tileServer;
    if (startTileServer) {
      tileServer = await TileServerTestLifecycle.createStarted(
        packagesDir: Directory(p.join(tempDir.path, 'map_packages')),
        assetsDir: Directory(p.join(tempDir.path, 'map_assets')),
      );
    }

    // 3. Inicializa o banco de dados hermético
    final db = customDb ?? InMemoryEncryptedDb.createInMemory();
    final repo = AppRepository(db);
    final settings = AppSettingsManager(db);

    // 4. Configura o mock do cliente Supabase HTTP
    final handler =
        mockHttpHandler ??
        (http.Request request) async {
          final path = request.url.path;
          if (path.contains('/storage/v1/object')) {
            return http.Response(
              '{"Key":"mock_storage_object"}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (path.contains('/rest/v1/rpc/sync_upsert_if_unchanged')) {
            return http.Response(
              '{"success": true, "processed_count": 1, "errors": []}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            '[]',
            200,
            headers: {
              'content-type': 'application/json',
              'content-range': '*/0',
            },
          );
        };

    final mockClient = MockClient(handler);
    final effectiveUrl = supabaseUrl ?? 'https://mock.supabase.co';
    final effectiveKey = supabaseAnonKey ?? 'dummy-anon-key-e2e';

    final supabaseClient = SupabaseClient(
      effectiveUrl,
      effectiveKey,
      httpClient: mockClient,
    );

    final syncService = SupabaseSyncService(
      allowLegacySyncForTesting: true,
      db: db,
      repository: repo,
      supabaseUrl: effectiveUrl,
      supabaseAnonKey: effectiveKey,
      clientOverride: supabaseClient,
      documentsDirectoryProvider: () async => tempDir.path,
    );

    return OpaqueBoxHarness._(
      db: db,
      repo: repo,
      settings: settings,
      tileServer: tileServer,
      networkGate: networkGate,
      tempDir: tempDir,
      syncService: syncService,
      mockHttpClient: mockClient,
      supabaseClient: supabaseClient,
    );
  }

  /// Indica se o modo avião está ativo bloqueando tráfego não-loopback.
  bool get airplaneMode => networkGate.airplaneModeActive;

  /// Alterna dinamicamente o estado do modo avião (ex: para testar reconexão).
  void setAirplaneMode(bool enabled) {
    networkGate.airplaneModeActive = enabled;
  }

  /// Gera os Riverpod [Override]s padrão para injeção hermética de dependências.
  List<Override> riverpodOverrides({
    List<Override> additionalOverrides = const [],
  }) {
    final overriddenOrigins = <Object?>{
      for (final extra in additionalOverrides) extra.origin,
    };

    final defaultOverrides = <Override>[
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      backupServiceProvider.overrideWithValue(BackupService(repo)),
      inboxManagerProvider.overrideWithValue(InboxManager(db: db)),
      taskManagerProvider.overrideWithValue(TaskManager(db: db)),
      projectManagerProvider.overrideWithValue(ProjectManager(db: db)),
      knowledgeManagerProvider.overrideWithValue(
        KnowledgeManager(db: db),
      ),
    ];

    final filteredDefaults = defaultOverrides.where(
      (item) => !overriddenOrigins.contains(item.origin),
    );

    return [...filteredDefaults, ...additionalOverrides];
  }

  /// Constrói um widget raiz de teste envolvendo [child] em um [ProviderScope]
  /// hermético com localização completa e tema do Field Assistant.
  Widget buildApp({
    required Widget child,
    List<Override> additionalOverrides = const [],
    ThemeData? theme,
    ThemeData? darkTheme,
    ThemeMode themeMode = ThemeMode.system,
    Locale locale = const Locale('pt', 'BR'),
    List<NavigatorObserver> navigatorObservers = const [],
  }) {
    return ProviderScope(
      overrides: riverpodOverrides(additionalOverrides: additionalOverrides),
      child: MaterialApp(
        title: 'Field Assistant E2E Harness',
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

  /// Configura o viewport e pixel ratio do [WidgetTester] de acordo com o preset.
  void applyDevicePreset(WidgetTester tester, E2EDevicePreset preset) {
    tester.view.physicalSize = preset.size * preset.pixelRatio;
    tester.view.devicePixelRatio = preset.pixelRatio;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  /// Cria um arquivo temporário isolado dentro do diretório temporário do harness.
  Future<File> createTempFile(String relativePath, List<int> bytes) async {
    final file = File(p.join(tempDir.path, relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Encerra todos os serviços, fecha conexões de banco e servidor, e desinstala
  /// o gate de rede fail-closed, garantindo isolamento total entre execuções.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    networkGate.uninstall();

    if (tileServer != null) {
      try {
        await tileServer!.dispose();
      } catch (_) {}
    }

    try {
      syncService.dispose();
    } catch (_) {}

    try {
      await db.close();
    } catch (_) {}

    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }
}

/// Extensão ergonômica sobre [WidgetTester] para integração com o [OpaqueBoxHarness].
extension OpaqueBoxTesterExtension on WidgetTester {
  /// Aplica a predefinição de tela informada.
  void setDevicePreset(E2EDevicePreset preset) {
    view.physicalSize = preset.size * preset.pixelRatio;
    view.devicePixelRatio = preset.pixelRatio;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  }

  /// Constrói e injeta a tela informada no ambiente hermético do harness.
  Future<void> pumpHarnessScreen({
    required Widget screen,
    required OpaqueBoxHarness harness,
    List<Override> additionalOverrides = const [],
    E2EDevicePreset devicePreset = E2EDevicePreset.phone,
    ThemeMode themeMode = ThemeMode.system,
    Locale locale = const Locale('pt', 'BR'),
    Duration? settleTimeout,
    List<NavigatorObserver> navigatorObservers = const [],
  }) async {
    setDevicePreset(devicePreset);
    await pumpWidget(
      harness.buildApp(
        child: screen,
        additionalOverrides: additionalOverrides,
        themeMode: themeMode,
        locale: locale,
        navigatorObservers: navigatorObservers,
      ),
    );
    await pumpAndSettleSafely(timeout: settleTimeout);
  }

  /// Executa `pumpAndSettle` com tolerância para animações contínuas,
  /// evitando timeouts desnecessários.
  Future<int> pumpAndSettleSafely({
    Duration duration = const Duration(milliseconds: 100),
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? const Duration(seconds: 10);
    final stopwatch = Stopwatch()..start();
    var count = 0;

    while (stopwatch.elapsed < effectiveTimeout) {
      await pump(duration);
      count++;
      if (!binding.hasScheduledFrame) {
        break;
      }
    }
    return count;
  }
}
