import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_config.dart';
import 'core/app_logger.dart';
import 'core/app_theme.dart';
import 'core/supabase_initializer.dart';
import 'database/app_database.dart';
import 'database/repository.dart';
import 'sync/supabase_sync_service.dart';
import 'ui/main_navigation_shell.dart';
import 'ui/providers.dart';

Future<void> main() async {
  // 1. Inicialização do binding do Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Configuração de ambiente centralizada
  var config = AppConfig.fromEnvironment();

  // 3. Banco relacional SQLite Drift local
  final db = AppDatabase();

  // Se não foi configurado via compile-time environment (--dart-define),
  // tenta carregar configurações previamente persistidas no banco local (appKvStore)
  if (config.status == ConfigStatus.unconfigured) {
    try {
      final savedUrlRow = await (db.select(db.appKvStore)
            ..where((t) => t.key.equals('config_supabase_url')))
          .getSingleOrNull();
      final savedKeyRow = await (db.select(db.appKvStore)
            ..where((t) => t.key.equals('config_supabase_anon_key')))
          .getSingleOrNull();
      final savedGoogleClientIdRow = await (db.select(db.appKvStore)
            ..where((t) => t.key.equals('config_google_web_client_id')))
          .getSingleOrNull();

      if (savedUrlRow != null &&
          savedKeyRow != null &&
          savedUrlRow.value.trim().isNotEmpty &&
          savedKeyRow.value.trim().isNotEmpty) {
        final runtimeConfig = AppConfig.create(
          environment: AppEnvironment.development,
          supabaseUrl: savedUrlRow.value.trim(),
          supabaseAnonKey: savedKeyRow.value.trim(),
          googleWebClientId: savedGoogleClientIdRow?.value.trim() ?? '',
        );
        if (runtimeConfig.isValid) {
          config = runtimeConfig;
          AppLogger.info(
            'AppConfig carregado a partir do armazenamento persistente local (appKvStore): ${config.toDiagnosticString()}',
          );
        }
      } else if (savedGoogleClientIdRow != null &&
          savedGoogleClientIdRow.value.trim().isNotEmpty) {
        config = config.copyWith(
          googleWebClientId: savedGoogleClientIdRow.value.trim(),
        );
      }
    } catch (e, st) {
      AppLogger.warning(
        'Falha não-bloqueante ao ler configurações salvas em appKvStore',
        e,
        st,
      );
    }
  }

  // 4. Dependências locais do repositório
  final repository = AppRepository(db);

  // 5. Inicialização condicional do Supabase (não-bloqueante para a UI se houver latência de rede)
  if (config.status == ConfigStatus.valid) {
    unawaited(
      initializeSupabaseIfConfigured(config: config).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        AppLogger.error(
          'Falha não-bloqueante na inicialização do Supabase durante o boot',
          error,
          stackTrace,
        );
        return SupabaseConnectionState.error;
      }),
    );
  } else {
    AppLogger.info(
      'Boot em modo local offline: Supabase ${config.status.name}.',
    );
  }

  // 6. Configuração dos providers Riverpod e 7. Execução da UI
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWith(() => AppConfigNotifier(config)),
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repository),
      ],
      child: const MinisterioPessoalApp(),
    ),
  );
}

class MinisterioPessoalApp extends ConsumerWidget {
  const MinisterioPessoalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Garante inicialização e observação de ciclo de vida e conectividade do SupabaseSyncService
    ref.watch(supabaseSyncServiceProvider);
    final isSunMode = ref.watch(sunModeProvider);

    return MaterialApp(
      title: 'Ministério Pessoal',
      debugShowCheckedModeBanner: false,
      theme: isSunMode ? AppTheme.sunModeTheme : AppTheme.lightTheme,
      darkTheme: isSunMode ? AppTheme.sunModeTheme : AppTheme.darkTheme,
      themeMode: isSunMode ? ThemeMode.light : ThemeMode.system,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      home: const MainNavigationShell(),
    );
  }
}
