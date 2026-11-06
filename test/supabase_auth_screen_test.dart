import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/ui/screens/auth_splash_screen.dart';

void main() {
  testWidgets('Login e cadastro não exigem configuração do Supabase', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SupabaseAuthScreen(onAuthenticated: () {})));
    expect(find.text('Entrar no Assistente'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.text('Configurações do Supabase'), findsNothing);
    expect(find.text('Supabase URL'), findsNothing);
    await tester.tap(find.text('Não tem conta? Cadastre-se'));
    await tester.pumpAndSettle();
    expect(find.text('Criar Conta'), findsOneWidget);
    expect(find.text('Cadastrar'), findsOneWidget);
  });
}
