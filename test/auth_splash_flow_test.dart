import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/core/app_version.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/ui/main_navigation_shell.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/auth_splash_screen.dart';

void main() {
  group('AuthSplashScreen e Fluxo de Autenticação Supabase', () {
    testWidgets('AuthSplashScreen pode ser instanciada como subclasse de AuthGateShell', (tester) async {
      const splash = AuthSplashScreen();
      expect(splash, isA<AuthGateShell>());
    });

    testWidgets('AuthSplashScreen exibe Splash Screen com logo, branding, versão e status antes do login', (tester) async {
      final testDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() => testDb.close());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(testDb),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [Locale('pt', 'BR')],
            home: AuthSplashScreen(),
          ),
        ),
      );

      // No início (tempo 0ms), a Splash Screen DEVE ser renderizada imediatamente
      expect(find.byKey(const ValueKey('splash_screen_view')), findsOneWidget);
      expect(find.text('Assistente de Campo'), findsOneWidget);
      expect(find.text('Ministério Pessoal • Sincronização em Nuvem'), findsOneWidget);
      expect(find.text('${AppVersion.displayVersion} • Offline-First'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Entrar na Conta'), findsNothing);

      // Em 1000ms, a Splash Screen ainda deve permanecer visível (mínimo de 1800ms)
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byKey(const ValueKey('splash_screen_view')), findsOneWidget);
      expect(find.text('Entrar na Conta'), findsNothing);

      // Em 2200ms (tempo >= 1800ms), a transição ocorre para SupabaseAuthScreen (não autenticado)
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Entrar na Conta'), findsOneWidget);
      expect(find.text('Continuar em Modo Offline (Sem Conta)'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('SupabaseAuthScreen possui botão de continuar em modo offline que navega para MainNavigationShell', (tester) async {
      final testDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() => testDb.close());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(testDb),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [Locale('pt', 'BR')],
            home: AuthSplashScreen(),
          ),
        ),
      );

      // Aguarda término da Splash Screen
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Entrar na Conta'), findsOneWidget);
      expect(find.text('Continuar em Modo Offline (Sem Conta)'), findsOneWidget);

      await tester.tap(find.text('Continuar em Modo Offline (Sem Conta)'));
      await tester.pump(const Duration(milliseconds: 300));

      // Navega para MainNavigationShell
      expect(find.byType(MainNavigationShell), findsOneWidget);

      // Confirma que gravou offline_mode_enabled no banco
      final offlineRow = await (testDb.select(testDb.appKvStore)
            ..where((t) => t.key.equals('offline_mode_enabled')))
          .getSingleOrNull();
      expect(offlineRow?.value, equals('true'));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('AuthSplashScreen com offline_mode_enabled navega direto para MainNavigationShell após Splash', (tester) async {
      final testDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() => testDb.close());

      // Previamente configurado em modo offline
      await testDb.into(testDb.appKvStore).insert(
        AppKvStoreCompanion.insert(key: 'offline_mode_enabled', value: 'true'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(testDb),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [Locale('pt', 'BR')],
            home: AuthSplashScreen(),
          ),
        ),
      );

      // Exibe Splash Screen no início
      expect(find.byKey(const ValueKey('splash_screen_view')), findsOneWidget);
      expect(find.text('Assistente de Campo'), findsOneWidget);

      // Aguarda término da Splash e sincronização
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pump(const Duration(milliseconds: 300));

      // Transiciona direto para MainNavigationShell sem passar pelo login
      expect(find.byType(MainNavigationShell), findsOneWidget);
      expect(find.text('Entrar na Conta'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
