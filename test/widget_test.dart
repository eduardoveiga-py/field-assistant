import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/main.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/ui/providers.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

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

  testWidgets('Interface UI: Navegação para Mapa dos Contatos e Calendário Visual da Agenda', (WidgetTester tester) async {
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

    // 1. Vai para Pessoas e Contatos
    final pessoasNav = find.descendant(of: find.byType(NavigationRail), matching: find.text('Pessoas'));
    await tester.tap(pessoasNav);
    await tester.pumpAndSettle();

    // 2. Toca no botão de abrir mapa
    final mapBtn = find.byIcon(Icons.map_outlined);
    expect(mapBtn, findsOneWidget);
    await tester.tap(mapBtn);
    await tester.pumpAndSettle();

    // 3. Verifica abertura da tela Mapa dos Contatos e Território
    expect(find.text('Mapa dos Contatos e Território'), findsOneWidget);

    // Alterna para o Mapa Visual (InteractiveViewer) e confirma ausência de erro de asset
    final toggleVisualMap = find.byTooltip('Ver Mapa Interativo');
    expect(toggleVisualMap, findsOneWidget);
    await tester.tap(toggleVisualMap);
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);

    // Volta para Pessoas
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // 4. Vai para a Agenda
    final agendaNav = find.descendant(of: find.byType(NavigationRail), matching: find.text('Agenda'));
    await tester.tap(agendaNav);
    await tester.pumpAndSettle();

    // 5. Verifica os modos de calendário Google Calendar / iPad Style
    expect(find.text('Agenda do Ministério'), findsOneWidget);
    expect(find.text('Mês'), findsOneWidget);
    expect(find.text('Semana'), findsOneWidget);
    expect(find.text('Dia'), findsOneWidget);
    expect(find.text('Lista'), findsOneWidget);

    // Alterna para modo Dia e verifica grade horária
    await tester.tap(find.text('Dia'));
    await tester.pumpAndSettle();
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('14:00'), findsOneWidget);

    // 6. Vai para Estatísticas (Witness Work style)
    final statsNav = find.descendant(of: find.byType(NavigationRail), matching: find.text('Estatísticas'));
    await tester.tap(statsNav);
    await tester.pumpAndSettle();

    expect(find.text('Estatísticas do Ministério'), findsOneWidget);
    expect(find.text('Relatório Mensal de Campo'), findsOneWidget);
    expect(find.text('HORAS'), findsOneWidget);
    expect(find.text('ESTUDOS'), findsOneWidget);
    expect(find.text('REVISITAS'), findsOneWidget);
    expect(find.text('Total Assistência'), findsOneWidget);
    expect(find.text('Meta Pessoal de Horas'), findsOneWidget);

    // Desmonta widgets
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
