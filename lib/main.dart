import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'ui/screens/auth_splash_screen.dart';
import 'ui/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: supabaseAnonKey,
      );
    } catch (_) {
      // Continua em modo offline-first caso a inicializacao falhe
    }
  }
  runApp(const ProviderScope(child: MinisterioPessoalApp()));
}

class MinisterioPessoalApp extends ConsumerWidget {
  const MinisterioPessoalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      home: const AuthGateShell(),
    );
  }
}
