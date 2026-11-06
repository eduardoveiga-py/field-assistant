import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/ui/screens/auth_splash_screen.dart';

void main() {
  group('AuthSplashScreen e Fluxo de Autenticação Supabase', () {
    testWidgets('AuthSplashScreen pode ser instanciada como subclasse de AuthGateShell', (tester) async {
      const splash = AuthSplashScreen();
      expect(splash, isA<AuthGateShell>());
    });

    testWidgets('SupabaseAuthScreen possui botão de continuar em modo offline', (tester) async {
      bool offlineClicked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: SupabaseAuthScreen(
            onAuthenticated: () {
              offlineClicked = true;
            },
          ),
        ),
      );

      expect(find.text('Entrar na Conta'), findsOneWidget);
      expect(find.text('Continuar em Modo Offline (Sem Conta)'), findsOneWidget);

      await tester.tap(find.text('Continuar em Modo Offline (Sem Conta)'));
      await tester.pump();

      expect(offlineClicked, isTrue);
    });
  });
}
