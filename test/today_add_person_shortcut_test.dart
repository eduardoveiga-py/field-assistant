import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/core/app_theme.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/today_screen.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  testWidgets(
    'Tocar em Nova Pessoa na tela Hoje abre diretamente o diálogo Novo Contato',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(testDb.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(testDb)],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('pt', 'BR')],
            home: const Scaffold(body: TodayScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Localiza o atalho rápido 'Nova Pessoa'
      final novaPessoaBtn = find.text('Nova Pessoa');
      expect(novaPessoaBtn, findsOneWidget);

      // Toca no botão 'Nova Pessoa'
      await tester.tap(novaPessoaBtn);
      await tester.pumpAndSettle();

      // O diálogo de cadastro 'Novo Contato' deve estar visível diretamente!
      expect(find.text('Novo Contato'), findsOneWidget);
      expect(
        find.text('Nome completo ou como é conhecido(a) *'),
        findsOneWidget,
      );
      expect(find.text('Salvar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      // Toca em cancelar para fechar o diálogo
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Novo Contato'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
}
