import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/core/app_theme.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/activities_screen.dart';
import 'package:ministerio_pessoal/ui/screens/people_screen.dart';
import 'package:ministerio_pessoal/ui/screens/today_screen.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('TodayScreen - Filtro de Revisitas e Remoção do Modo Demonstração', () {
    testWidgets(
      'Não exibe card "Modo Demonstração Disponível" na tela inicial',
      (tester) async {
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

        // Card Modo Demonstração Disponível NÃO deve estar na Home
        expect(find.textContaining('Modo Demonstração'), findsNothing);
        expect(find.textContaining('Modo de Demonstração'), findsNothing);
        expect(find.textContaining('demonstração disponível'), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'Tocar no atalho Revisitas define peopleFilterProvider para "Revisitas"',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final testDb = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(testDb.close);

        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(testDb)],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
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

        // Filtro inicial é 'Todos'
        expect(container.read(peopleFilterProvider), equals('Todos'));

        // Localiza o atalho 'Revisitas'
        final revisitasBtn = find.text('Revisitas');
        expect(revisitasBtn, findsOneWidget);

        // Toca no atalho 'Revisitas'
        await tester.tap(revisitasBtn);
        await tester.pumpAndSettle();

        // Verifica que o provedor de filtro foi alterado para 'Revisitas'
        expect(container.read(peopleFilterProvider), equals('Revisitas'));

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'PeopleScreen inicializa com filtro "Revisitas" e exibe apenas pessoas com status "revisita"',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final testDb = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(testDb.close);

        // Insere uma pessoa 'revisita' e uma 'estudo'
        await testDb.into(testDb.people).insert(
          PeopleCompanion.insert(
            id: 'rev_1',
            name: 'Maria Revisita',
            status: const Value('revisita'),
            firstContactAt: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        await testDb.into(testDb.people).insert(
          PeopleCompanion.insert(
            id: 'est_1',
            name: 'Carlos Estudo',
            status: const Value('estudo'),
            firstContactAt: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(testDb)],
        );
        addTearDown(container.dispose);
        container.read(peopleFilterProvider.notifier).state = 'Revisitas';

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('pt', 'BR')],
              home: const Scaffold(body: PeopleScreen()),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Deve exibir Maria Revisita, mas NÃO Carlos Estudo
        expect(find.text('Maria Revisita'), findsOneWidget);
        expect(find.text('Carlos Estudo'), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });

  group('ActivitiesScreen - Resolução de Overflow', () {
    testWidgets(
      'Renderiza sem estouro visual (BOTTOM OVERFLOWED) em telas pequenas (360x640)',
      (tester) async {
        // Simula tela pequena de smartphone (360x640) da foto do usuário
        tester.view.physicalSize = const Size(360, 640);
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
              home: const Scaffold(body: ActivitiesScreen()),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Não deve ocorrer erro de overflow
        expect(tester.takeException(), isNull);
        expect(find.text('Atividades do Ministério'), findsOneWidget);

        // Pode rolar sem erros
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });
}
