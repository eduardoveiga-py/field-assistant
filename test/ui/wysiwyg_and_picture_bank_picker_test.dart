import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/media/media_picker_helper.dart';
import 'package:ministerio_pessoal/picture_bank/picture_entry_model.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/widgets/app_inline_image_view.dart';
import 'package:ministerio_pessoal/ui/widgets/knowledge_item_reader_dialog.dart';
import 'package:ministerio_pessoal/ui/widgets/markdown_preview_text.dart';
import 'package:ministerio_pessoal/ui/widgets/rich_formatted_editing_controller.dart';
import 'package:ministerio_pessoal/ui/widgets/rich_markdown_toolbar.dart';

// 1x1 PNG válido em base64 para renderização de imagens em ambiente headless
const _tinyPngDataUri =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

void main() {
  group('WYSIWYG Zero-Syntax Editor, HTML Signature & Inline Images Tests', () {
    late AppDatabase db;
    late AppRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('RichFormattedEditingController oculta Markdown, links, tags <u> e imagens no campo de texto', () {
      const raw =
          '### Estudo Semanal\n'
          'Olá **Eduardo**, leia [📖 João 3:16 (TNM)](app://ref/bible/43/3/16) e '
          '<u style="color:#EAB308">medite</u>.\n'
          '![Minha Gravura](app://ref/picture/pic-1)';

      final ctrl = RichFormattedEditingController.fromMarkup(raw);
      addTearDown(ctrl.dispose);

      // Nenhum delimitador cru pode aparecer no campo de edição
      expect(ctrl.text, isNot(contains('###')));
      expect(ctrl.text, isNot(contains('**')));
      expect(ctrl.text, isNot(contains('<u')));
      expect(ctrl.text, isNot(contains('app://')));
      expect(ctrl.text, isNot(contains('![')));
      expect(
        ctrl.text,
        equals(
          'Estudo Semanal\nOlá Eduardo, leia 📖 João 3:16 (TNM) e medite.',
        ),
      );
      expect(ctrl.inlineImages.length, equals(1));
      expect(ctrl.inlineImages.single.src, equals('app://ref/picture/pic-1'));

      // Round-trip de volta para Markdown válido preservando tudo
      final serialized = ctrl.toMarkup();
      expect(serialized, contains('### Estudo Semanal'));
      expect(serialized, contains('**Eduardo**'));
      expect(
        serialized,
        contains('[📖 João 3:16 (TNM)](app://ref/bible/43/3/16)'),
      );
      expect(serialized, contains('<u style="color:#EAB308">medite</u>'));
      expect(serialized, contains('![Minha Gravura](app://ref/picture/pic-1)'));
    });

    test('RichFormattedEditingController.fromHtml oculta <b>/<a>/<span>/<img> mantendo estilo visual em assinaturas', () {
      const rawHtml =
          'Atenciosamente,<br>'
          '<b>Eduardo Veiga</b> | <span style="color: #1E40AF;">Pioneiro</span><br>'
          '<a href="https://jw.org">Portal JW</a>'
          '<img src="$_tinyPngDataUri" alt="Logo" />';

      final ctrl = RichFormattedEditingController.fromHtml(rawHtml);
      addTearDown(ctrl.dispose);

      expect(ctrl.text, isNot(contains('<b>')));
      expect(ctrl.text, isNot(contains('<span')));
      expect(ctrl.text, isNot(contains('<a ')));
      expect(ctrl.text, isNot(contains('<img')));
      expect(ctrl.text, isNot(contains('<br')));
      expect(
        ctrl.text,
        equals('Atenciosamente,\nEduardo Veiga | Pioneiro\nPortal JW'),
      );
      expect(ctrl.inlineImages.length, equals(1));

      final outHtml = ctrl.toHtml();
      expect(outHtml, contains('<b>Eduardo Veiga</b>'));
      expect(outHtml, contains('color: #1E40AF;'));
      expect(outHtml, contains('<a href="https://jw.org">Portal JW</a>'));
      expect(outHtml, contains('<img src="$_tinyPngDataUri"'));
    });

    testWidgets(
      'Selecionar texto no TextField WYSIWYG dispara pílula flutuante JW Library e colore o texto sem <u...>',
      (tester) async {
        final ctrl = RichFormattedEditingController.fromMarkup(
          'Jeová fortalece seus servos',
        );
        addTearDown(ctrl.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  RichMarkdownToolbar(controller: ctrl),
                  TextField(controller: ctrl),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('btn_editor_hl_yellow')), findsNothing);

        // Seleciona "fortalece" no editor WYSIWYG
        ctrl.selection = const TextSelection(baseOffset: 6, extentOffset: 15);
        await tester.pump();

        expect(find.byKey(const Key('btn_editor_hl_yellow')), findsOneWidget);
        await tester.tap(find.byKey(const Key('btn_editor_hl_yellow')));
        await tester.pumpAndSettle();

        expect(ctrl.text, equals('Jeová fortalece seus servos'));
        expect(ctrl.text, isNot(contains('<u')));
        expect(
          ctrl.toMarkup(),
          equals('Jeová <u style="color:#EAB308">fortalece</u> seus servos'),
        );

        // Negrito antes de digitar não injeta palavra fictícia 'texto' e não exibe '**'
        final blankCtrl = RichFormattedEditingController();
        addTearDown(blankCtrl.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  RichMarkdownToolbar(controller: blankCtrl),
                  TextField(controller: blankCtrl),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        blankCtrl.value = const TextEditingValue(
          text: 'Eduardo ',
          selection: TextSelection.collapsed(offset: 8),
        );
        await tester.tap(find.byIcon(Icons.format_bold));
        await tester.pump();
        expect(blankCtrl.text, equals('Eduardo '));
        blankCtrl.value = const TextEditingValue(
          text: 'Eduardo Veiga',
          selection: TextSelection.collapsed(offset: 13),
        );
        await tester.pump();

        // Seleciona "Veig" e aplica Azul via pílula flutuante
        blankCtrl.selection = const TextSelection(
          baseOffset: 8,
          extentOffset: 12,
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('btn_editor_hl_blue')));
        await tester.pumpAndSettle();

        expect(blankCtrl.text, equals('Eduardo Veiga'));
        expect(blankCtrl.text, isNot(contains('**')));
        expect(blankCtrl.text, isNot(contains('<u')));
        final savedMarkup = blankCtrl.toMarkup();
        expect(
          savedMarkup,
          equals('Eduardo <u style="color:#3B82F6">**Veig**</u>**a**'),
        );

        // Mesmo formato legado `**<u ...>Veig</u>a**` abre limpo no editor e leitor
        final legacyCtrl = RichFormattedEditingController.fromMarkup(
          'Eduardo **<u style="color:#3B82F6">Veig</u>a**',
        );
        addTearDown(legacyCtrl.dispose);
        expect(legacyCtrl.text, equals('Eduardo Veiga'));
        expect(legacyCtrl.text, isNot(contains('**')));
        expect(legacyCtrl.text, isNot(contains('<u')));
      },
    );

    testWidgets(
      'AppInlineImageView e KnowledgeItemReaderDialog exibem a imagem real ao invés de apenas o nome da gravura',
      (tester) async {
        await PictureBankManager.savePicture(
          db,
          PictureEntry(
            id: 'pic-real-1',
            caption: 'Barco no Solimões',
            tags: const ['fluvial'],
            imageData: _tinyPngDataUri,
            createdAt: DateTime(2026, 11, 25),
            updatedAt: DateTime(2026, 11, 25),
          ),
        );

        const rawNote =
            'Texto de apoio acima.\n'
            '[<u style="color:#F97316">🖼️ Barco no Solimões</u>](app://ref/picture/pic-real-1)';

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: KnowledgeItemReaderDialog(
                  title: 'Nota com Gravura Real',
                  content: rawNote,
                  category: 'Ministério',
                  itemType: 'Nota',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Exibe o componente visual de imagem real e zero tag <u crua
        expect(find.byType(AppInlineImageView), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
        expect(find.textContaining('<u style'), findsNothing);

        // Também valida MarkdownPreviewText sem corte de linhas exibindo a foto inline
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: MarkdownPreviewText(
                  text: 'Veja gravura:\n![Barco](app://ref/picture/pic-real-1)',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AppInlineImageView), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
      },
    );

    testWidgets(
      'Inserir Imagem oferece Banco de Gravuras + Dispositivo no RichMarkdownToolbar, mantendo janela de Pessoas/Estudantes inalterada',
      (tester) async {
        await PictureBankManager.savePicture(
          db,
          PictureEntry(
            id: 'pic-pick-1',
            caption: 'Ponte na Amazônia',
            tags: const ['campo'],
            imageData: _tinyPngDataUri,
            createdAt: DateTime(2026, 11, 25),
            updatedAt: DateTime(2026, 11, 25),
          ),
        );

        final ctrl = RichFormattedEditingController();
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

        await tester.tap(find.byKey(const Key('btn_toolbar_insert_image')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('btn_pick_img_picture_bank')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('btn_pick_img_device')), findsOneWidget);

        // Escolhe do Banco de Gravuras
        await tester.tap(find.byKey(const Key('btn_pick_img_picture_bank')));
        await tester.pumpAndSettle();

        expect(find.text('Ponte na Amazônia'), findsOneWidget);
        await tester.tap(find.byKey(const Key('btn_pick_picture_pic-pick-1')));
        await tester.pumpAndSettle();

        // Deve inserir visualmente (miniatura + imagem real) sem sujar ctrl.text com ![...](app://...)
        expect(ctrl.text, isEmpty);
        expect(ctrl.inlineImages.length, equals(1));
        expect(find.byType(AppInlineImageView), findsOneWidget);
        expect(
          ctrl.toMarkup(),
          equals('![Ponte na Amazônia](app://ref/picture/pic-pick-1)'),
        );

        // Confirma exclusão na janela de Pessoas/Estudantes: sem Banco de Gravuras quando pictureBankDb é omitido
        late BuildContext hostCtx;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (ctx) {
                hostCtx = ctx;
                return const Scaffold(body: Text('Host'));
              },
            ),
          ),
        );
        MediaPickerHelper.pickImage(hostCtx, title: 'Foto do Estudante');
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('btn_media_pick_picture_bank')),
          findsNothing,
        );
        expect(find.text('Escolher do Dispositivo / Galeria'), findsOneWidget);
      },
    );
  });
}
