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
  final config = AppConfig.fromEnvironment();

  // 3. Banco relacional SQLite Drift local
  final db = AppDatabase();

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
        appConfigProvider.overrideWithValue(config),
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
