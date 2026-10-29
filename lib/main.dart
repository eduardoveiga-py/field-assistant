import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_theme.dart';
import 'ui/main_navigation_shell.dart';
import 'ui/providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: MinisterioPessoalApp(),
    ),
  );
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
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      home: const MainNavigationShell(),
    );
  }
}

