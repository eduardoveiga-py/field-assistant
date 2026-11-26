import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/core/biometric_auth_service.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/knowledge/knowledge_manager.dart';
import 'package:ministerio_pessoal/knowledge/knowledge_search_common.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/knowledge_base_screen.dart';
import 'package:ministerio_pessoal/ui/widgets/knowledge/rich_block_markdown_view.dart';
import 'package:ministerio_pessoal/ui/widgets/knowledge/second_brain_rich_editor.dart';
import 'package:ministerio_pessoal/ui/widgets/markdown_preview_text.dart';
import 'package:ministerio_pessoal/ui/widgets/rich_formatted_editing_controller.dart';

class _UnlockedBiometric extends BiometricAuthService {
  @override
  bool get isSessionUnlocked => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Segundo Cérebro UI — Editor, Blocos Notion, Views & Revisão', () {
    testWidgets(
      'SecondBrainRichEditor detecta comandos / e gatilho [[ de autocompletar',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final km = KnowledgeManager(db: db);
        var dbClosed = false;
        addTearDown(() async {
          if (!dbClosed) await db.close();
        });

        final targetNote = await km.createNote(
          title: 'Roteiro Assembleia',
          content: 'Detalhes principais',
        );

        final ctrl = TextEditingController();
        addTearDown(ctrl.dispose);

        tester.view.physicalSize = const Size(900, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(AppRepository(db)),
              biometricAuthServiceProvider.overrideWithValue(
                _UnlockedBiometric(),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SecondBrainRichEditor(controller: ctrl),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Testa comando /callout
        ctrl.value = const TextEditingValue(
          text: '/call',
          selection: TextSelection.collapsed(offset: 5),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('/callout'), findsOneWidget);
        await tester.tap(find.textContaining('/callout'));
        await tester.pumpAndSettle();
        expect(ctrl.text, contains('> [!NOTE]'));

        // Testa autocompletar [[ Roteiro
        ctrl.value = const TextEditingValue(
          text: 'Ver [[Roteiro',
          selection: TextSelection.collapsed(offset: 13),
        );
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();
        expect(find.text('Roteiro Assembleia'), findsOneWidget);
        await tester.tap(find.text('Roteiro Assembleia'));
        await tester.pumpAndSettle();
        expect(ctrl.text, contains('app://ref/note/${targetNote.id}'));
      },
    );

    testWidgets(
      'RichBlockMarkdownView renderiza Callout, Toggle expansível, Tabela e Checklist clicável',
      (tester) async {
        String? updatedMarkdown;
        const markdown = '''
> [!TIP] Dica prática de campo.

:::toggle Abrir esboço secreto
Conteúdo oculto do toggle.
:::

| Tema | Texto |
| --- | --- |
| Reino | Mat 24:14 |

- [ ] Tarefa pendente
''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: RichBlockMarkdownView(
                  text: markdown,
                  isDark: false,
                  onContentUpdated: (updated) async {
                    updatedMarkdown = updated;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('DICA'), findsOneWidget);
        expect(find.textContaining('Dica prática de campo.'), findsOneWidget);
        expect(find.text('Tema'), findsOneWidget);
        expect(find.text('Mat 24:14'), findsOneWidget);

        // Toggle fechado inicialmente e abre ao tocar
        expect(find.textContaining('Conteúdo oculto do toggle.'), findsNothing);
        await tester.tap(find.text('Abrir esboço secreto'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Conteúdo oculto do toggle.'),
          findsOneWidget,
        );

        // Checklist clicável marca como [x]
        await tester.tap(find.byIcon(Icons.check_box_outline_blank_rounded));
        await tester.pumpAndSettle();
        expect(updatedMarkdown, isNotNull);
        expect(updatedMarkdown, contains('- [x] Tarefa pendente'));
      },
    );

    testWidgets(
      'KnowledgeBaseScreen alterna Lista/Tabela/Kanban/Galeria, exibe Backlinks, Subpáginas e Revisão Semanal',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final km = KnowledgeManager(db: db);
        var dbClosed = false;
        addTearDown(() async {
          if (!dbClosed) await db.close();
        });

        final area = await km.createArea(
          name: 'Congregação',
          colorHex: '#10B981',
        );
        final rootNote = await km.createNote(
          title: 'Nota Raiz P.A.R.A.',
          content: 'Visão geral da nota raiz.',
          areaId: area.id,
          properties: {'status': 'em_estudo', 'priority': 'alta'},
          nextReviewAt: DateTime.now().toUtc().subtract(
            const Duration(hours: 1),
          ),
        );
        await km.createNote(
          title: 'Subpágina Detalhe',
          content: 'Comentário extra citando [[Nota Raiz P.A.R.A.]].',
          areaId: area.id,
          parentNoteId: rootNote.id,
          properties: {'status': 'revisar', 'priority': 'normal'},
        );

        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(AppRepository(db)),
              biometricAuthServiceProvider.overrideWithValue(
                _UnlockedBiometric(),
              ),
            ],
            child: const MaterialApp(home: KnowledgeBaseScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Área P.A.R.A. aparece na barra horizontal
        expect(find.text('Congregação'), findsWidgets);

        // Seleciona a Nota Raiz no split-pane
        await tester.tap(find.text('Nota Raiz P.A.R.A.').first);
        await tester.pumpAndSettle();

        expect(find.textContaining('SUBPÁGINAS (1)'), findsOneWidget);
        expect(find.text('Subpágina Detalhe'), findsWidgets);
        expect(find.textContaining('MENCIONADO EM (1)'), findsOneWidget);
        expect(find.text('Em Estudo'), findsWidgets);

        // Alterna para Tabela, Kanban e Galeria
        await tester.tap(find.byKey(const Key('view_mode_chip_table')));
        await tester.pumpAndSettle();
        expect(find.byType(DataTable), findsOneWidget);

        await tester.tap(find.byKey(const Key('view_mode_chip_kanban')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Em Estudo (1)'), findsOneWidget);
        expect(find.textContaining('Revisar (1)'), findsOneWidget);

        await tester.tap(find.byKey(const Key('view_mode_chip_gallery')));
        await tester.pumpAndSettle();
        expect(find.byType(GridView), findsOneWidget);

        // Volta para Lista e abre Revisão Semanal
        await tester.tap(find.byKey(const Key('btn_kb_weekly_review')));
        await tester.pumpAndSettle();
        expect(find.text('Revisão Semanal & Espaçada'), findsOneWidget);
        expect(find.textContaining('SM-2 Pendentes: 1'), findsOneWidget);

        await tester.tap(find.text('Concluir'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        dbClosed = true;
        await db.close();
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'KnowledgeBaseScreen adapta sem overflow no layout compacto de iPhone (390x844)',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final km = KnowledgeManager(db: db);
        var dbClosed = false;
        addTearDown(() async {
          if (!dbClosed) await db.close();
        });

        final area = await km.createArea(name: 'Ministério');
        await km.createNote(
          title: 'Apresentação Breve',
          content: '- [ ] Ler texto',
          areaId: area.id,
        );

        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(AppRepository(db)),
              biometricAuthServiceProvider.overrideWithValue(
                _UnlockedBiometric(),
              ),
            ],
            child: const MaterialApp(home: KnowledgeBaseScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Apresentação Breve'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        dbClosed = true;
        await db.close();
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'Visualização (Galeria/Kanban/SM-2/Busca) e Edição nunca exibem tags <u>, <details> ou URLs app://ref cruas',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final km = KnowledgeManager(db: db);
        var dbClosed = false;
        addTearDown(() async {
          if (!dbClosed) await db.close();
        });

        const richNoteA =
            '[📖 Mateus 7:12 (TNM)](app://ref/bible/40/7/12) '
            '[📖 João 3:1-5 (TNM)](app://ref/bible/43/3/1-5)\n'
            'Teste de <u style="color:#F97316">conteudo</u>';
        const richNoteB =
            '<u style="color:#EC4899">Testando</u> minha nova '
            '<u style="color: #EAB308;">nota</u> e '
            '<u style="color: 3B82F6">formatação</u>!\n'
            '> [!TIP] Aplicação no campo\n'
            '<details><summary>Detalhes Extras</summary>Ponto interno.</details>';

        await km.createNote(
          title: 'Teste 2',
          content: richNoteA,
          nextReviewAt: DateTime.now().toUtc().subtract(
            const Duration(hours: 2),
          ),
        );
        await km.createNote(title: 'Teste', content: richNoteB);

        // 1. Verifica edição limpa via RichFormattedEditingController.fromMarkup
        final ctrlA = RichFormattedEditingController.fromMarkup(richNoteA);
        final ctrlB = RichFormattedEditingController.fromMarkup(richNoteB);
        addTearDown(() {
          ctrlA.dispose();
          ctrlB.dispose();
        });
        expect(ctrlA.text, contains('Mateus 7:12 (TNM)'));
        expect(ctrlA.text, contains('conteudo'));
        expect(ctrlA.text, isNot(contains('<u')));
        expect(ctrlA.text, isNot(contains('app://ref/')));
        expect(ctrlB.text, contains('Testando minha nova nota e formatação!'));
        expect(ctrlB.text, isNot(contains('<u')));
        expect(ctrlB.text, isNot(contains('</u>')));
        expect(ctrlB.text, isNot(contains('<details>')));
        expect(ctrlB.text, isNot(contains('<summary>')));

        // Roundtrip preserva URLs e cores internamente sem vazar na edição
        final roundtripA = ctrlA.toMarkup();
        expect(roundtripA, contains('app://ref/bible/40/7/12'));
        expect(roundtripA, contains('#F97316'));

        // 2. Verifica limpeza em snippet de busca e cleanMarkdown
        final snippetB = KnowledgeSearchCommon.buildSnippet(richNoteB);
        expect(snippetB, contains('Testando'));
        expect(snippetB, isNot(contains('<u')));
        expect(snippetB, isNot(contains('color:')));
        expect(snippetB, isNot(contains('[!TIP]')));
        final cleanA = MarkdownPreviewText.cleanMarkdown(richNoteA);
        expect(cleanA, isNot(contains('app://ref/')));
        expect(cleanA, isNot(contains('<u')));

        // 3. Verifica Galeria, Kanban e SM-2 na UI real sem tags/URLs cruas
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(AppRepository(db)),
              biometricAuthServiceProvider.overrideWithValue(
                _UnlockedBiometric(),
              ),
            ],
            child: const MaterialApp(home: KnowledgeBaseScreen()),
          ),
        );
        await tester.pumpAndSettle();

        for (final chipKey in const [
          'view_mode_chip_gallery',
          'view_mode_chip_kanban',
        ]) {
          await tester.tap(find.byKey(Key(chipKey)));
          await tester.pumpAndSettle();

          expect(
            find.textContaining('Mateus 7:12 (TNM)', findRichText: true),
            findsWidgets,
          );
          expect(
            find.textContaining('Testando', findRichText: true),
            findsWidgets,
          );
          expect(find.textContaining('<u', findRichText: true), findsNothing);
          expect(find.textContaining('</u>', findRichText: true), findsNothing);
          expect(
            find.textContaining('app://ref/', findRichText: true),
            findsNothing,
          );
          expect(
            find.textContaining('color:', findRichText: true),
            findsNothing,
          );
          expect(
            find.textContaining('<details>', findRichText: true),
            findsNothing,
          );
        }

        // Abre Revisão Semanal e revela o cartão SM-2
        await tester.tap(find.byKey(const Key('btn_kb_weekly_review')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mostrar resposta / notas'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Mateus 7:12 (TNM)', findRichText: true),
          findsWidgets,
        );
        expect(find.textContaining('<u', findRichText: true), findsNothing);
        expect(
          find.textContaining('app://ref/', findRichText: true),
          findsNothing,
        );

        await tester.tap(find.text('Concluir'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        dbClosed = true;
        await db.close();
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'Kanban permite puxar e arrastar cartões entre colunas de status atualizando o banco',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final km = KnowledgeManager(db: db);
        var dbClosed = false;
        addTearDown(() async {
          if (!dbClosed) await db.close();
        });

        final note = await km.createNote(
          title: 'Cartão Arrastável',
          content: 'Preparar argumento com <u style="color:#10B981">texto-chave</u>.',
          properties: {'status': 'rascunho', 'priority': 'alta'},
        );

        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(AppRepository(db)),
              biometricAuthServiceProvider.overrideWithValue(
                _UnlockedBiometric(),
              ),
            ],
            child: const MaterialApp(home: KnowledgeBaseScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('view_mode_chip_kanban')));
        await tester.pumpAndSettle();

        expect(find.text('Rascunho (1)'), findsOneWidget);
        expect(find.text('Em Estudo (0)'), findsOneWidget);

        // Puxa o cartão da coluna Rascunho para a coluna Em Estudo
        final cardFinder = find.byKey(Key('kanban_card_${note.id}'));
        final targetStudy = find.byKey(const Key('kanban_col_em_estudo'));
        final startPos = tester.getCenter(cardFinder);
        final endPos = tester.getCenter(targetStudy);
        await tester.timedDragFrom(
          startPos,
          endPos - startPos,
          const Duration(milliseconds: 300),
        );
        await tester.pumpAndSettle();

        expect(find.text('Rascunho (0)'), findsOneWidget);
        expect(find.text('Em Estudo (1)'), findsOneWidget);

        var updated = await (db.select(
          db.knowledgeNotes,
        )..where((t) => t.id.equals(note.id))).getSingle();
        expect(
          KnowledgeManager.decodeProperties(updated.propertiesJson)['status'],
          'em_estudo',
        );

        // Arrasta agora para coluna vazia Concluído
        final targetDone = find.byKey(const Key('kanban_col_concluido'));
        final start2 = tester.getCenter(cardFinder);
        final end2 = tester.getCenter(targetDone);
        await tester.timedDragFrom(
          start2,
          end2 - start2,
          const Duration(milliseconds: 300),
        );
        await tester.pumpAndSettle();

        expect(find.text('Em Estudo (0)'), findsOneWidget);
        expect(find.text('Concluído (1)'), findsOneWidget);

        updated = await (db.select(
          db.knowledgeNotes,
        )..where((t) => t.id.equals(note.id))).getSingle();
        expect(
          KnowledgeManager.decodeProperties(updated.propertiesJson)['status'],
          'concluido',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        dbClosed = true;
        await db.close();
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });
}
