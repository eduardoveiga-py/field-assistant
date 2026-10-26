import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/main.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/ui/providers.dart';

void main() {
  testWidgets('Interface UI (iPad/Desktop): Renderiza NavigationRail lateral e alterna telas', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final testDb = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
        ],
        child: const MinisterioPessoalApp(),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verifica título da tela inicial Hoje
    expect(find.text('Hoje no Ministério'), findsOneWidget);
    expect(find.text('Salvo Localmente'), findsOneWidget);

    // 2. Verifica presença dos destinos da barra lateral NavigationRail
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.descendant(of: find.byType(NavigationRail), matching: find.text('Hoje')), findsOneWidget);
    expect(find.descendant(of: find.byType(NavigationRail), matching: find.text('Pessoas')), findsOneWidget);
    expect(find.descendant(of: find.byType(NavigationRail), matching: find.text('Agenda')), findsOneWidget);
    expect(find.descendant(of: find.byType(NavigationRail), matching: find.text('Estudos')), findsOneWidget);
    expect(find.descendant(of: find.byType(NavigationRail), matching: find.text('Estatísticas')), findsOneWidget);

    // 3. Toca na aba Pessoas na NavigationRail
    final pessoasNav = find.descendant(of: find.byType(NavigationRail), matching: find.text('Pessoas'));
    await tester.tap(pessoasNav);
    await tester.pumpAndSettle();

    // 4. Verifica se a tela mudou para Pessoas e Contatos
    expect(find.text('Pessoas e Contatos'), findsOneWidget);
    expect(find.text('Novo Contato'), findsOneWidget);

    // 5. Toca na aba Estudos na NavigationRail
    final estudosNav = find.descendant(of: find.byType(NavigationRail), matching: find.text('Estudos'));
    await tester.tap(estudosNav);
    await tester.pumpAndSettle();

    expect(find.text('Estudos Bíblicos'), findsOneWidget);

    // Desmonta widgets e drena timers de streams do Drift
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('Interface UI (iPhone XR): Renderiza NavigationBar inferior e navega', (WidgetTester tester) async {
    // Resolução lógica típica do iPhone XR: 414 x 896
    tester.view.physicalSize = const Size(414, 896);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final testDb = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
        ],
        child: const MinisterioPessoalApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verifica que NavigationBar inferior é usada em tela mobile e NavigationRail não existe
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    // Toca no atalho rápido de Estudos na TodayScreen
    final estudosQuickAction = find.text('Estudos').first;
    await tester.tap(estudosQuickAction);
    await tester.pumpAndSettle();

    expect(find.text('Estudos Bíblicos'), findsOneWidget);

    // Desmonta widgets e drena timers de streams do Drift
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
