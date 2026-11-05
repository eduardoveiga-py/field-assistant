import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'ui/screens/auth_splash_screen.dart';
import 'ui/providers.dart';
import 'sync/supabase_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SupabaseSyncService.initialize();
  } catch (_) {
    // A tela de login permite tentar novamente se a inicialização falhar.
    debugPrint('Não foi possível inicializar o Supabase.');
  }
  runApp(const ProviderScope(child: MinisterioPessoalApp()));
}

class MinisterioPessoalApp extends ConsumerWidget {
  const MinisterioPessoalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSunMode = ref.watch(sunModeProvider);

    return MaterialApp(
      title: 'Field Assistant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isSunMode ? ThemeMode.light : ThemeMode.dark,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      home: const AuthSplashScreen(),
    );
  }
}
