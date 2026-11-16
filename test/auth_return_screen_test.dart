import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/ui/screens/auth_return_screen.dart';

void main() {
  testWidgets('resultado exibe mensagem e executa ação', (tester) async {
    var acted = false;
    await tester.pumpWidget(MaterialApp(home: AuthReturnScreen(
      success: false,
      title: 'Não foi possível confirmar',
      message: 'Solicite outro link.',
      actionLabel: 'Voltar',
      onAction: () => acted = true,
    )));
    expect(find.text('Não foi possível confirmar'), findsOneWidget);
    expect(find.text('Solicite outro link.'), findsOneWidget);
    await tester.tap(find.text('Voltar'));
    expect(acted, isTrue);
  });

  testWidgets('recuperação valida as duas senhas antes de chamar o servidor', (tester) async {
    final sent = <String>[];
    var success = false;
    await tester.pumpWidget(MaterialApp(home: AuthNewPasswordScreen(
      updatePassword: (password) async { sent.add(password); },
      onSuccess: () => success = true,
      onCancel: () {},
    )));
    await tester.tap(find.text('Salvar nova senha'));
    await tester.pump();
    expect(find.text('A senha deve ter pelo menos 6 caracteres.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('new_password')), 'senha123');
    await tester.enterText(find.byKey(const ValueKey('confirm_new_password')), 'outrasenha');
    await tester.tap(find.text('Salvar nova senha'));
    await tester.pump();
    expect(find.text('As senhas não coincidem.'), findsOneWidget);
    expect(sent, isEmpty);
    await tester.enterText(find.byKey(const ValueKey('confirm_new_password')), 'senha123');
    await tester.tap(find.text('Salvar nova senha'));
    await tester.pump();
    expect(sent, ['senha123']);
    expect(success, isTrue);
  });

  testWidgets('erro do servidor mantém o formulário e não mostra sucesso', (tester) async {
    var success = false;
    await tester.pumpWidget(MaterialApp(home: AuthNewPasswordScreen(
      updatePassword: (_) async => throw Exception('erro de rede'),
      onSuccess: () => success = true,
      onCancel: () {},
    )));
    await tester.enterText(find.byKey(const ValueKey('new_password')), 'senha123');
    await tester.enterText(find.byKey(const ValueKey('confirm_new_password')), 'senha123');
    await tester.tap(find.text('Salvar nova senha'));
    await tester.pump();
    expect(success, isFalse);
    expect(find.textContaining('Não foi possível alterar a senha.'), findsOneWidget);
  });
}
