import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/bible/nwt_bible_service.dart';
import 'package:ministerio_pessoal/core/feature_registry.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/knowledge/knowledge_manager.dart';
import 'package:ministerio_pessoal/picture_bank/picture_entry_model.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/picture_bank_screen.dart';
import 'package:ministerio_pessoal/ui/widgets/app_reference_picker_dialog.dart';
import 'package:ministerio_pessoal/ui/widgets/app_reference_viewer.dart';
import 'package:ministerio_pessoal/ui/widgets/bible_verse_popup_dialog.dart';
import 'package:ministerio_pessoal/ui/widgets/knowledge_item_reader_dialog.dart';
import 'package:ministerio_pessoal/ui/widgets/markdown_preview_text.dart';
import 'package:ministerio_pessoal/ui/widgets/rich_markdown_toolbar.dart';

void main() {
  group('Cross References, Bible Popup & JW Library Highlights Widget Tests', () {
    late AppDatabase db;
    late AppRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets(
      'RichMarkdownToolbar insere referência de Perguntas & Dúvidas e texto bíblico TNM',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final km = KnowledgeManager(db: db);
        final question = await km.createQuestion(
          question: 'Jeová e a pré ciência',
          context: 'Contexto detalhado da pergunta.',
        );

        final ctrl = TextEditingController(text: 'Estudo: ');
        addTearDown(ctrl.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    RichMarkdownToolbar(controller: ctrl),
                    TextField(controller: ctrl),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Botão de referências e botão de paleta JW Library visíveis em editores padrão
        expect(find.byKey(const Key('btn_toolbar_insert_ref')), findsOneWidget);
        expect(
          find.byKey(const Key('btn_toolbar_highlight_color')),
          findsOneWidget,
        );

        // Abre seletor de referências (inicia na categoria Perguntas & Dúvidas)
        await tester.tap(find.byKey(const Key('btn_toolbar_insert_ref')));
        await tester.pumpAndSettle();

        expect(find.byType(AppReferencePickerDialog), findsOneWidget);
        expect(find.text('Jeová e a pré ciência'), findsOneWidget);

        // Seleciona a pergunta
        await tester.tap(find.text('Jeová e a pré ciência'));
        await tester.pumpAndSettle();

        expect(
          ctrl.text,
          contains(
            '[❓ Jeová e a pré ciência](app://ref/question/${question.id})',
          ),
        );

        // Reabre seletor e muda categoria para Bíblia (TNM)
        await tester.tap(find.byKey(const Key('btn_toolbar_insert_ref')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('dropdown_ref_category')));
        await tester.pumpAndSettle();
        final bibleMenuItem = find
            .textContaining('Tradução do Novo Mundo')
            .last;
        await tester.ensureVisible(bibleMenuItem);
        await tester.tap(bibleMenuItem);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('field_bible_chapter')),
          '3',
        );
        await tester.enterText(
          find.byKey(const Key('field_bible_verses')),
          '16-17',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btn_insert_bible_ref')));
        await tester.pumpAndSettle();

        expect(
          ctrl.text,
          contains('[📖 João 3:16-17 (TNM)](app://ref/bible/43/3/16-17)'),
        );
      },
    );

    testWidgets(
      'AppReferenceViewer abre leitor da dúvida com "Ir para a aba", gravura e popup bíblico TNM',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final km = KnowledgeManager(db: db);
        final q = await km.createQuestion(
          question: 'Por que estudar profecias?',
          context: 'Contexto inicial',
        );
        await km.answerQuestion(
          q.id,
          answer: 'Resposta fundamentada nas Escrituras.',
        );

        await PictureBankManager.savePicture(
          db,
          PictureEntry(
            id: 'pic-viewer-1',
            caption: 'Barco no rio Amazonas',
            tags: const ['barco'],
            imageData: 'assets/pictures/example.png',
            createdAt: DateTime(2026, 11, 24),
            updatedAt: DateTime(2026, 11, 24),
          ),
        );

        await NwtBibleService.saveManualVerse(
          db,
          bookNumber: 43,
          chapter: 3,
          verse: 16,
          text: 'Verso sintético de João três dezesseis salvo offline.',
        );

        late BuildContext capturedContext;
        late ProviderContainer container;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context, listen: false);
                return MaterialApp(
                  home: Builder(
                    builder: (innerCtx) {
                      capturedContext = innerCtx;
                      return const Scaffold(body: Text('Host Screen'));
                    },
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1) Referência para Pergunta -> abre KnowledgeItemReaderDialog + salto "Ir para a aba"
        AppReferenceViewer.openUrl(
          capturedContext,
          'app://ref/question/${q.id}',
        );
        await tester.pumpAndSettle();

        expect(find.byType(KnowledgeItemReaderDialog), findsOneWidget);
        expect(find.text('Por que estudar profecias?'), findsOneWidget);
        expect(find.byKey(const Key('btn_reader_jump_to_tab')), findsOneWidget);

        await tester.tap(find.byKey(const Key('btn_reader_jump_to_tab')));
        await tester.pumpAndSettle();

        final navReq = container.read(appNavigationProvider);
        expect(navReq, isNotNull);
        expect(navReq!.feature, equals(AppFeature.knowledge));
        expect(navReq.subTabIndex, equals(1));

        // 2) Referência bíblica TNM -> abre BibleVersePopupDialog offline
        AppReferenceViewer.openUrl(capturedContext, 'app://ref/bible/43/3/16');
        await tester.pumpAndSettle();

        expect(find.byType(BibleVersePopupDialog), findsOneWidget);
        expect(find.text('João 3:16'), findsOneWidget);
        expect(
          find.textContaining('Verso sintético de João três dezesseis'),
          findsOneWidget,
        );

        await tester.tap(find.byTooltip('Fechar'));
        await tester.pumpAndSettle();

        // 3) Referência de Gravura -> abre PictureDetailViewerScreen
        AppReferenceViewer.openUrl(
          capturedContext,
          'app://ref/picture/pic-viewer-1',
        );
        await tester.pumpAndSettle();

        expect(find.byType(PictureDetailViewerScreen), findsOneWidget);
        expect(find.textContaining('Barco no rio Amazonas'), findsWidgets);
      },
    );

    testWidgets(
      'KnowledgeItemReaderDialog permite sublinhar diretamente na leitura e remove exclusão em e-mail',
      (tester) async {
        String latestSaved = 'Meditar diariamente fortalece o ministério.';
        var updateCalls = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KnowledgeItemReaderDialog(
                title: 'Nota Interativa',
                content: latestSaved,
                category: 'Estudo',
                itemType: 'Nota',
                allowHighlights: true,
                onContentUpdated: (updated) async {
                  updateCalls++;
                  latestSaved = updated;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('btn_reader_hl_green')), findsOneWidget);
        expect(find.byKey(const Key('btn_reader_hl_clear')), findsOneWidget);

        // Simula seleção do usuário em modo leitura ("Meditar")
        final selectable = tester.widget<SelectableText>(
          find.byType(SelectableText).first,
        );
        selectable.onSelectionChanged?.call(
          const TextSelection(baseOffset: 0, extentOffset: 7),
          SelectionChangedCause.drag,
        );
        await tester.pump();

        // Toca no botão Verde da paleta JW Library
        await tester.tap(find.byKey(const Key('btn_reader_hl_green')));
        await tester.pumpAndSettle();

        expect(updateCalls, equals(1));
        expect(
          latestSaved,
          equals(
            '<u style="color:#10B981">Meditar</u> diariamente fortalece o ministério.',
          ),
        );

        // Limpa sublinhado da mesma seleção
        final selectableAfter = tester.widget<SelectableText>(
          find.byType(SelectableText).first,
        );
        selectableAfter.onSelectionChanged?.call(
          const TextSelection(baseOffset: 0, extentOffset: 7),
          SelectionChangedCause.drag,
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('btn_reader_hl_clear')));
        await tester.pumpAndSettle();

        expect(updateCalls, equals(2));
        expect(
          latestSaved,
          equals('Meditar diariamente fortalece o ministério.'),
        );
      },
    );

    testWidgets(
      'Exclusão obrigatória: Toolbar de E-mail e leitores de Estudo/E-mail ocultam paleta JW',
      (tester) async {
        final ctrl = TextEditingController();
        addTearDown(ctrl.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  RichMarkdownToolbar(
                    controller: ctrl,
                    enableHighlightPalette: false,
                    enableCrossReferences: true,
                  ),
                  const Expanded(
                    child: KnowledgeItemReaderDialog(
                      title: 'Estudo Bíblico / E-mail',
                      content: 'Conteúdo sem sublinhado JW.',
                      category: 'Estudo',
                      itemType: 'Estudo Bíblico',
                      allowHighlights: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Cross-reference continua disponível no compositor de e-mails
        expect(find.byKey(const Key('btn_toolbar_insert_ref')), findsOneWidget);
        // Paleta JW ocultada explicitamente no compositor de e-mails e no leitor de estudos/e-mails
        expect(
          find.byKey(const Key('btn_toolbar_highlight_color')),
          findsNothing,
        );
        expect(find.byKey(const Key('btn_reader_hl_yellow')), findsNothing);
        expect(find.byKey(const Key('btn_reader_hl_clear')), findsNothing);
      },
    );

    testWidgets(
      'MarkdownPreviewText em painéis de leitura exibe barra JW ao selecionar trecho e salva alteração',
      (tester) async {
        String saved = 'Jeová sustenta seus servos fiéis.';
        var callbacks = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MarkdownPreviewText(
                text: saved,
                selectable: true,
                allowHighlights: true,
                onContentUpdated: (updated) async {
                  callbacks++;
                  saved = updated;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('btn_inline_hl_yellow')), findsNothing);

        final selectable = tester.widget<SelectableText>(
          find.byType(SelectableText),
        );
        selectable.onSelectionChanged?.call(
          const TextSelection(baseOffset: 0, extentOffset: 5),
          SelectionChangedCause.drag,
        );
        await tester.pump();

        expect(find.byKey(const Key('btn_inline_hl_yellow')), findsOneWidget);
        await tester.tap(find.byKey(const Key('btn_inline_hl_yellow')));
        await tester.pumpAndSettle();

        expect(callbacks, equals(1));
        expect(
          saved,
          equals(
            '<u style="color:#EAB308">Jeová</u> sustenta seus servos fiéis.',
          ),
        );
      },
    );

    testWidgets(
      'BibleVersePopupDialog permite sublinhar versículos em modo leitura e persiste localmente',
      (tester) async {
        await NwtBibleService.saveManualVerse(
          db,
          bookNumber: 19,
          chapter: 83,
          verse: 18,
          text: 'Versículo sintético para teste de destaque bíblico offline.',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BibleVersePopupDialog(
                db: db,
                bookNumber: 19,
                chapter: 83,
                verseSpec: '18',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final selectable = tester.widget<SelectableText>(
          find.byType(SelectableText),
        );
        // Prefixo "18 " ocupa 3 chars; "Versículo" ocupa índices 3..12
        selectable.onSelectionChanged?.call(
          const TextSelection(baseOffset: 3, extentOffset: 12),
          SelectionChangedCause.drag,
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('btn_bible_hl_blue')));
        await tester.pumpAndSettle();

        final lookup = await NwtBibleService.lookupPassage(
          db,
          bookNumber: 19,
          chapter: 83,
          verseSpec: '18',
        );
        expect(lookup.verses.single.highlightedMarkup, isNotNull);
        expect(
          lookup.verses.single.highlightedMarkup,
          startsWith('<u style="color:#3B82F6">Versículo</u>'),
        );
      },
    );
  });
}
