import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'ui/screens/auth_splash_screen.dart';
import 'ui/providers.dart';
import 'sync/supabase_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
  var supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    final savedUrl = await SupabaseSyncService.getSavedUrl();
    final savedKey = await SupabaseSyncService.getSavedAnonKey();
    if (savedUrl != null && savedKey != null && savedUrl.isNotEmpty && savedKey.isNotEmpty) {
      supabaseUrl = savedUrl;
      supabaseAnonKey = savedKey;
    }
  }

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
