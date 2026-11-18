import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/widgets/e2ee_setup_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'E2eeSetupDialog exibe tabs, gera 24 palavras e valida checkbox',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = AppRepository(db);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            repositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: Scaffold(body: E2eeSetupDialog(userId: 'test-user-dialog')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Criptografia Ponta a Ponta (E2EE)'), findsOneWidget);
      expect(find.text('Novo Cofre'), findsOneWidget);
      expect(find.text('Restaurar com Frase'), findsOneWidget);
      expect(find.text('Ativar Criptografia E2EE'), findsOneWidget);

      // O botão deve estar inicialmente desabilitado porque a checkbox não foi marcada
      final buttonFinder = find.widgetWithText(
        ElevatedButton,
        'Ativar Criptografia E2EE',
      );
      ElevatedButton button = tester.widget(buttonFinder);
      expect(button.onPressed, isNull);

      // Toca na checkbox
      final checkboxTileFinder = find.byType(CheckboxListTile);
      expect(checkboxTileFinder, findsOneWidget);
      await tester.tap(checkboxTileFinder);
      await tester.pumpAndSettle();

      button = tester.widget(buttonFinder);
      expect(button.onPressed, isNotNull);

      // Troca para a aba de restauração
      await tester.tap(find.text('Restaurar com Frase'));
      await tester.pumpAndSettle();

      expect(find.text('0 / 24 palavras'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'palavra1 palavra2 palavra3',
      );
      await tester.pumpAndSettle();
      expect(find.text('3 / 24 palavras'), findsOneWidget);

      await db.close();
    },
  );

  testWidgets('E2eeViewPhraseDialog exibe 24 palavras e botão de copiar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    const phrase =
        'abaixar abelha abismo abrigo abrir absinto abutre acalmar acampamento acampar acatar aceitar acenar aceno acerto acesso acolher acordo acossar acudir acusar adaptar adega adeus';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: E2eeViewPhraseDialog(phrase: phrase)),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Frase de Recuperação E2EE'), findsOneWidget);
    expect(find.text('abaixar'), findsOneWidget);

    // Rola para encontrar as últimas palavras se necessário
    await tester.scrollUntilVisible(find.text('adeus'), 100);
    expect(find.text('adeus'), findsOneWidget);
    expect(find.text('Copiar'), findsOneWidget);
    expect(find.text('Fechar'), findsOneWidget);
  });
}
