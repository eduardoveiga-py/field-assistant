import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_logger.dart';
import 'core/app_theme.dart';
import 'core/i18n/app_locale_strings.dart';
import 'database/connection/db_status.dart';
import 'sync/supabase_sync_service.dart';
import 'ui/screens/auth_splash_screen.dart';
import 'ui/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SupabaseSyncService.initialize();
  } catch (e, st) {
    // Continua em modo offline-first caso a inicialização falhe, mas registra erro (M9)
    AppLogger.error(
      'Falha ao inicializar Supabase; aplicativo operando em modo offline-first.',
      e,
      st,
    );
  }
  runApp(const ProviderScope(child: MinisterioPessoalApp()));
}

class MinisterioPessoalApp extends ConsumerWidget {
  const MinisterioPessoalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSunMode = ref.watch(sunModeProvider);
    final currentLocale = ref.watch(appLocaleTypeProvider);

    return MaterialApp(
      title: 'Ministério Pessoal',
      debugShowCheckedModeBanner: false,
      locale: currentLocale.toLocale,
      theme: isSunMode ? AppTheme.sunModeTheme : AppTheme.lightTheme,
      darkTheme: isSunMode ? AppTheme.sunModeTheme : AppTheme.darkTheme,
      themeMode: isSunMode ? ThemeMode.light : ThemeMode.system,
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
      home: const _PersistenceHealthGate(child: AuthSplashScreen()),
    );
  }
}

class _PersistenceHealthGate extends ConsumerStatefulWidget {
  final Widget child;
  const _PersistenceHealthGate({required this.child});

  @override
  ConsumerState<_PersistenceHealthGate> createState() =>
      _PersistenceHealthGateState();
}

class _PersistenceHealthGateState
    extends ConsumerState<_PersistenceHealthGate> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      Future.microtask(_probeWebPersistence);
    }
  }

  Future<void> _probeWebPersistence() async {
    try {
      await ref.read(databaseProvider).customSelect('SELECT 1').get();
    } catch (e, st) {
      AppLogger.error(
        'Erro fatal ao inicializar banco de dados local na Web',
        e,
        st,
      );
      dbFatalPersistenceError.value ??= e.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: dbFatalPersistenceError,
      builder: (context, fatalError, _) {
        if (fatalError != null) {
          return FatalPersistenceScreen(
            errorMessage: fatalError,
            onRetry: () {
              dbFatalPersistenceError.value = null;
              ref.invalidate(databaseProvider);
              _probeWebPersistence();
            },
          );
        }
        return widget.child;
      },
    );
  }
}

/// Tela de erro fatal para Web quando WebAssembly/IndexedDB não puderam ser inicializados (C3).
class FatalPersistenceScreen extends StatelessWidget {
  final String errorMessage;
  final VoidCallback? onRetry;

  const FatalPersistenceScreen({
    super.key,
    required this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.storage_rounded,
                    size: 64,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Armazenamento Local Indisponível',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'O navegador não conseguiu inicializar o banco local seguro (WebAssembly/IndexedDB). Para proteger seus registros e evitar perda silenciosa de dados, a leitura e gravação foram bloqueadas.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      errorMessage,
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (onRetry != null)
                    ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar Reconectar'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
