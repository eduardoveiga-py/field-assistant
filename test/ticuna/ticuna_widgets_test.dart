import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/core/app_theme.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/ticuna_screen.dart';
import 'package:ministerio_pessoal/ticuna/widgets/ticuna_diacritics_bar.dart';
import 'package:ministerio_pessoal/ticuna/ticuna_repository.dart';
import 'package:ministerio_pessoal/ticuna/ticuna_providers.dart';
import 'package:ministerio_pessoal/ticuna/models/ticuna_models.dart';

Widget buildTestApp({
  required AppDatabase db,
  required Widget home,
  TicunaRepository? repo,
  List<TicunaWord>? initialWords,
  List<TicunaPhrase>? initialPhrases,
  List<TicunaTag>? initialTags,
}) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      if (repo != null) ticunaRepositoryProvider.overrideWithValue(repo),
      if (initialWords != null)
        ticunaWordsStreamProvider.overrideWithValue(AsyncValue.data(initialWords)),
      if (initialPhrases != null)
        ticunaPhrasesStreamProvider.overrideWithValue(AsyncValue.data(initialPhrases)),
      if (initialTags != null)
        ticunaTagsStreamProvider.overrideWithValue(AsyncValue.data(initialTags)),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      home: home,
    ),
  );
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('TicunaDiacriticsBar - Teclado Virtual de Caracteres Especiais', () {
    testWidgets('Renderiza botões das duas linhas com acentuações da língua Ticuna', (tester) async {
      final controller = TextEditingController(text: 'Du');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TicunaDiacriticsBar(
              controller: controller,
              label: 'Teclas Especiais Ticuna',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Teclas Especiais Ticuna'), findsOneWidget);

      // Linha 1 (9 teclas): ĩ, ü̃, ǘ̃, ũ, ã́, ẽ, Ĩ, Ü̃, Ǘ̃
      expect(find.text('ĩ'), findsOneWidget);
      expect(find.text('ũ'), findsOneWidget);
      expect(find.text('ẽ'), findsOneWidget);
      expect(find.text('Ĩ'), findsOneWidget);

      // Linha 2 (3 teclas): Ũ, Ã́, Ẽ
      expect(find.text('Ũ'), findsOneWidget);
      expect(find.text('Ẽ'), findsOneWidget);

      // Glifos incorretos (fora da ortografia Ticuna e ausentes na imagem) não devem existir
      expect(find.text('ấ'), findsNothing);
      expect(find.text('Ấ'), findsNothing);
    });

    testWidgets('Tocar no botão insere caractere na posição correta do cursor', (tester) async {
      final controller = TextEditingController(text: 'D');
      // Coloca o cursor no fim
      controller.selection = const TextSelection.collapsed(offset: 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TicunaDiacriticsBar(controller: controller),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Toca em 'ü\u0303' (ü̃)
      await tester.tap(find.text('ü\u0303'));
      await tester.pumpAndSettle();

      expect(controller.text, equals('Dü\u0303'));
      expect(controller.selection.baseOffset, equals(3)); // 'D' (1) + 'ü\u0303' (2 bytes UTF-16)
    });

    testWidgets('Substitui texto selecionado ao tocar no botão de caractere', (tester) async {
      final controller = TextEditingController(text: 'Dxyz');
      // Seleciona 'xyz'
      controller.selection = const TextSelection(baseOffset: 1, extentOffset: 4);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TicunaDiacriticsBar(controller: controller),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Toca em 'ĩ'
      await tester.tap(find.text('ĩ'));
      await tester.pumpAndSettle();

      expect(controller.text, equals('Dĩ'));
    });
  });

  group('TicunaScreen - Interface do Usuário e Abas', () {
    late AppDatabase db;
    late TicunaRepository repo;
    late List<TicunaWord> seedWords;
    late List<TicunaPhrase> seedPhrases;
    late List<TicunaTag> seedTags;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = TicunaRepository(db);
      seedWords = await repo.getAllWords();
      seedPhrases = await repo.getAllPhrases();
      seedTags = await repo.getAllTags();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Renderiza abas Dicionário e Frases Úteis e alterna entre elas', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp(
        db: db,
        home: const TicunaScreen(),
        repo: repo,
        initialWords: seedWords,
        initialPhrases: seedPhrases,
        initialTags: seedTags,
      ));
      await tester.pumpAndSettle();

      // Verifica título
      expect(find.text('Língua Ticuna'), findsOneWidget);
      expect(find.text('Dicionário & Frases de Campo'), findsOneWidget);

      // Verifica presença de palavras padrão do dicionário (seed inicial)
      expect(find.text('Bíblia'), findsWidgets);
      await tester.enterText(find.byType(TextField).first, 'Taemãẽ');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(Card, 'Taemãẽ'), findsOneWidget);
      expect(find.widgetWithText(Card, 'Obrigado / Muito obrigado'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();

      // Alterna para a aba Frases Úteis
      await tester.tap(find.textContaining('Frases Úteis'));
      await tester.pumpAndSettle();

      // Verifica presença de frase inicial ordenada (Salmo 37:29)
      expect(find.textContaining('Salmo 37:29'), findsWidgets);

      // Filtra por 'Tamaü' via campo de busca
      await tester.enterText(find.byType(TextField).first, 'Tamaü');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(Card, 'Tamaü! Ku meã pe\'ĩ?'), findsOneWidget);

      // FAB mostra 'Nova Frase'
      expect(find.text('Nova Frase'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Abre formulário de novo termo com barra de teclas especiais Ticuna', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp(
        db: db,
        home: const TicunaScreen(),
        repo: repo,
        initialWords: seedWords,
        initialPhrases: seedPhrases,
        initialTags: seedTags,
      ));
      await tester.pumpAndSettle();

      // Toca em '+ Novo Termo'
      await tester.tap(find.text('Novo Termo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Novo Termo Ticuna'), findsOneWidget);
      expect(find.text('Palavra ou Termo em Ticuna *'), findsOneWidget);
      expect(find.byType(TicunaDiacriticsBar), findsOneWidget);

      // Fecha o diálogo
      await tester.tap(find.text('Cancelar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Abre modo Flashcards (AnkiDroid) e interage com revelar e classificar', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp(
        db: db,
        home: const TicunaScreen(),
        repo: repo,
        initialWords: seedWords,
        initialPhrases: seedPhrases,
        initialTags: seedTags,
      ));
      await tester.pumpAndSettle();

      // Toca no ícone de estudo de flashcards
      final schoolIcon = find.byIcon(Icons.school_outlined);
      expect(schoolIcon, findsOneWidget);
      await tester.tap(schoolIcon);
      await tester.pumpAndSettle();

      // Modal de estudo abre exibindo a frente do cartão
      expect(find.textContaining('Cartão 1 de'), findsOneWidget);
      expect(find.text('Mostrar Resposta'), findsOneWidget);

      // Toca em 'Mostrar Resposta'
      await tester.tap(find.text('Mostrar Resposta'));
      await tester.pumpAndSettle();

      // Verso é revelado com os botões Anki: Errei, Bom, Fácil
      expect(find.text('Errei'), findsOneWidget);
      expect(find.text('Bom'), findsOneWidget);
      expect(find.text('Fácil'), findsOneWidget);

      // Classifica como 'Bom'
      await tester.tap(find.text('Bom'));
      await tester.pumpAndSettle();

      // Avança para o Cartão 2
      expect(find.textContaining('Cartão 2 de'), findsOneWidget);

      // Fecha o modal
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Abre modal de Importar/Exportar banco de dados Ticuna', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp(
        db: db,
        home: const TicunaScreen(),
        repo: repo,
        initialWords: seedWords,
        initialPhrases: seedPhrases,
        initialTags: seedTags,
      ));
      await tester.pumpAndSettle();

      final exportIcon = find.byIcon(Icons.import_export_rounded);
      expect(exportIcon, findsOneWidget);
      await tester.tap(exportIcon);
      await tester.pumpAndSettle();

      expect(find.text('Importar / Exportar Ticuna'), findsOneWidget);
      expect(find.text('Exportar JSON Completo'), findsOneWidget);
      expect(find.text('Importar Agora'), findsOneWidget);

      // Fecha
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Alterna teclado virtual de diacríticos na barra de pesquisa', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp(
        db: db,
        home: const TicunaScreen(),
        repo: repo,
        initialWords: seedWords,
        initialPhrases: seedPhrases,
        initialTags: seedTags,
      ));
      await tester.pumpAndSettle();

      final kbIcon = find.byTooltip('Teclado Especial Ticuna');
      expect(kbIcon, findsOneWidget);

      // Inicialmente oculto
      expect(find.text('Inserir Caractere Especial na Pesquisa:'), findsNothing);

      // Abre barra de diacríticos na busca
      await tester.tap(kbIcon);
      await tester.pumpAndSettle();

      expect(find.text('Inserir Caractere Especial na Pesquisa:'), findsOneWidget);

      // Fecha barra
      await tester.tap(kbIcon);
      await tester.pumpAndSettle();

      expect(find.text('Inserir Caractere Especial na Pesquisa:'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
