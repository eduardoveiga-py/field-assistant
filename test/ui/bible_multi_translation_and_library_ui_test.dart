import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ministerio_pessoal/bible/nwt_bible_service.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/publications/imported_publications_service.dart';
import 'package:ministerio_pessoal/references/app_reference.dart';
import 'package:ministerio_pessoal/ui/widgets/app_reference_picker_dialog.dart';
import 'package:ministerio_pessoal/ui/widgets/bible_verse_popup_dialog.dart';
import 'package:ministerio_pessoal/ui/widgets/settings/offline_library_dialog.dart';

Uint8List _syntheticPublicationEpubBytes() {
  final archive = Archive();
  void addText(String path, String text) {
    final raw = utf8.encode(text);
    archive.addFile(ArchiveFile(path, raw.length, raw));
  }

  addText('META-INF/container.xml', '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>''');
  addText('OEBPS/content.opf', '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Escute a Deus (Publicação Teste)</dc:title>
    <dc:language>pt</dc:language>
  </metadata>
  <manifest>
    <item id="c0" href="c0.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="c0"/>
  </spine>
</package>''');
  addText(
    'OEBPS/c0.xhtml',
    '<html><head><title>Capítulo Único</title></head><body><p>Parágrafo de teste da publicação.</p></body></html>',
  );
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Biblioteca Offline, Multi-Traduções e Referências', () {
    // Testa o OfflineLibraryDialog diretamente (sem SettingsScreen, que tem
    // dependências pesadas de Supabase/OAuth que travam o pumpAndSettle em testes).
    testWidgets(
      'OfflineLibraryDialog lista Bíblias e Publicações importadas e exibe botões de importação',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          await db.close();
        });

        await NwtBibleService.importFromBytes(
          db,
          bytes: Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                'title': 'Bíblia Português',
                'language': 'pt-BR',
                'books': {
                  '43': {
                    '3': {'16': 'Texto em português.'},
                  },
                },
              }),
            ),
          ),
          fileName: 'pt.json',
        );
        await NwtBibleService.importFromBytes(
          db,
          bytes: Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                'title': 'Tupanaãrü Ore (Ticuna)',
                'language': 'tca',
                'books': {
                  '43': {
                    '3': {'16': 'Texto em ticuna.'},
                  },
                },
              }),
            ),
          ),
          fileName: 'tca.json',
        );
        await ImportedPublicationsService.importPublicationFromBytes(
          db,
          bytes: _syntheticPublicationEpubBytes(),
          fileName: 'pub_teste.epub',
        );

        tester.view.physicalSize = const Size(1000, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Renderiza o diálogo diretamente, sem SettingsScreen
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: OfflineLibraryDialog(db: db)),
          ),
        );
        await tester.pumpAndSettle();

        // Aba Bíblias (padrão)
        expect(find.textContaining('Biblioteca Offline'), findsOneWidget);
        expect(
          find.byKey(const Key('btn_settings_import_bible')),
          findsOneWidget,
        );
        expect(find.text('Bíblia Português'), findsOneWidget);
        expect(find.text('Tupanaãrü Ore (Ticuna)'), findsOneWidget);

        // Muda para aba Publicações
        await tester.tap(find.text('Publicações (1)'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('btn_settings_import_publication')),
          findsOneWidget,
        );
        expect(find.text('Escute a Deus (Publicação Teste)'), findsOneWidget);
      },
    );

    testWidgets(
      'BibleVersePopupDialog remove botoes de importacao e compara 2+ traducoes no estilo JW Library',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          await db.close();
        });

        final pt = await NwtBibleService.importFromBytes(
          db,
          bytes: Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                'title': 'Bíblia de Estudo',
                'language': 'pt-BR',
                'books': {
                  '43': {
                    '3': {'16': 'Porque Deus amou tanto o mundo em português.'},
                  },
                },
              }),
            ),
          ),
          fileName: 'nwt_pt.json',
        );
        final tcn = await NwtBibleService.importFromBytes(
          db,
          bytes: Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                'title': 'Tupanaãrü Ore (Perú)',
                'language': 'tca',
                'books': {
                  '43': {
                    '3': {
                      '16': 'Tupana rü meãxü̃chi i naãnecü̃ãxü̃ em ticuna.',
                    },
                  },
                },
              }),
            ),
          ),
          fileName: 'sbi1_tca.json',
        );

        tester.view.physicalSize = const Size(900, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BibleVersePopupDialog(
                db: db,
                bookNumber: 43,
                chapter: 3,
                verseSpec: '16',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Nenhum botão de importação direta deve existir no popup
        expect(find.textContaining('Importar'), findsNothing);
        // Ao ter 2 traduções importadas, inicia exibindo ambas no estilo JW Library
        expect(find.text('Comparar versões • 2 traduções'), findsOneWidget);
        expect(
          find.byKey(Key('bible_compare_card_${pt.catalog.id}')),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('bible_compare_card_${tcn.catalog.id}')),
          findsOneWidget,
        );
        expect(find.text('Português (Brasil)'), findsOneWidget);
        expect(find.text('Ticuna'), findsOneWidget);
        expect(
          find.textContaining('Porque Deus amou tanto o mundo em português.'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Tupana rü meãxü̃chi i naãnecü̃ãxü̃ em ticuna.'),
          findsOneWidget,
        );

        // Abre "Comparar versões" e desmarca Ticuna para ler apenas 1 tradução
        await tester.tap(find.byKey(const Key('btn_bible_compare_versions')));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(Key('chk_compare_bible_${tcn.catalog.id}')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('btn_apply_compare_versions')));
        await tester.pumpAndSettle();

        expect(find.text('Comparar versões • 2 traduções'), findsNothing);
        expect(
          find.text('Bíblia de Estudo (Português (Brasil))'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Tupana rü meãxü̃chi i naãnecü̃ãxü̃ em ticuna.'),
          findsNothing,
        );

        // Reabre "Comparar versões" e marca todas novamente para comparar 2 traduções
        await tester.tap(find.byKey(const Key('btn_bible_compare_versions')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Marcar todas'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('btn_apply_compare_versions')));
        await tester.pumpAndSettle();

        expect(find.text('Comparar versões • 2 traduções'), findsOneWidget);
        expect(
          find.textContaining('Tupana rü meãxü̃chi i naãnecü̃ãxü̃ em ticuna.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'BibleVersePopupDialog exibe aviso claro quando traducao parcial nao contem o versiculo',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          await db.close();
        });

        final fullPt = await NwtBibleService.importFromBytes(
          db,
          bytes: Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                'title': 'Tupanaarü Ore (Brasil)',
                'language': 'tca',
                'books': {
                  '51': {
                    '1': {'21': 'Rü pema ga ü̃pa rü tama...'},
                  },
                },
              }),
            ),
          ),
          fileName: 'sbi2.json',
        );
        final partialNwtp = await NwtBibleService.importFromBytes(
          db,
          bytes: Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                'title': 'Norü wetchicurugü i tnn (nwtp)',
                'language': 'tca',
                'books': {
                  '55': {
                    '3': {'1': 'Notürü nüü̃ nacuaꞌ...'},
                  },
                },
              }),
            ),
          ),
          fileName: 'nwtp.json',
        );

        tester.view.physicalSize = const Size(900, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Comparação entre completa e parcial em Colossenses 1:21
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BibleVersePopupDialog(
                db: db,
                bookNumber: 51,
                chapter: 1,
                verseSpec: '21',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(Key('bible_compare_card_${fullPt.catalog.id}')),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('bible_compare_card_${partialNwtp.catalog.id}')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Rü pema ga ü̃pa rü tama...'),
          findsOneWidget,
        );
        expect(
          find.text(
            'O versículo selecionado não aparece nesta versão da Bíblia.',
          ),
          findsOneWidget,
        );

        // Seleciona apenas a parcial e abre versículo ausente nela
        await tester.tap(find.byKey(const Key('btn_bible_compare_versions')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(Key('chk_compare_bible_${fullPt.catalog.id}')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('btn_apply_compare_versions')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(Key('bible_compare_card_${partialNwtp.catalog.id}')),
          findsOneWidget,
        );
        expect(
          find.text(
            'O versículo selecionado não aparece nesta versão da Bíblia.',
          ),
          findsOneWidget,
        );
        expect(find.text('Colar / Salvar Versículo Manual'), findsOneWidget);
      },
    );

    testWidgets(
      'AppReferencePickerDialog nao tem botao de importacao e lista Publicacoes Importadas',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          await db.close();
        });

        await NwtBibleService.importFromBytes(
          db,
          bytes: Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                'title': 'Bíblia A',
                'language': 'pt',
                'books': {
                  '43': {
                    '3': {'16': 'Verso A.'},
                  },
                },
              }),
            ),
          ),
          fileName: 'a.json',
        );
        await NwtBibleService.importFromBytes(
          db,
          bytes: Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                'title': 'Bíblia B',
                'language': 'en',
                'books': {
                  '43': {
                    '3': {'16': 'Verse B.'},
                  },
                },
              }),
            ),
          ),
          fileName: 'b.json',
        );
        final pub =
            await ImportedPublicationsService.importPublicationFromBytes(
              db,
              bytes: _syntheticPublicationEpubBytes(),
              fileName: 'pub_ref.epub',
            );

        AppReferencePickResult? picked;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    picked = await showAppReferencePickerDialog(
                      ctx,
                      db: db,
                      initialCategory: AppRefCategory.bible,
                    );
                  },
                  child: const Text('Abrir Seletor'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir Seletor'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Importar'), findsNothing);
        expect(
          find.byKey(const Key('dropdown_picker_bible_translation')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('dropdown_ref_category')));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Publicações Importadas').last);
        await tester.pumpAndSettle();

        expect(find.text('Escute a Deus (Publicação Teste)'), findsOneWidget);
        await tester.tap(find.text('Escute a Deus (Publicação Teste)'));
        await tester.pumpAndSettle();

        expect(picked, isNotNull);
        expect(picked!.category, equals(AppRefCategory.publication));
        expect(
          picked!.markdownToken,
          contains('app://ref/publication/${pub.id}'),
        );
      },
    );

    testWidgets(
      'OfflineLibraryDialog importa Biblia JSON, Publicacao EPUB e trata cancelamento ou arquivo vazio',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          await db.close();
        });

        ({String name, Uint8List bytes})? nextPick;

        tester.view.physicalSize = const Size(1000, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OfflineLibraryDialog(
                db: db,
                onPickFile: () async => nextPick,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1) Cancelamento retorna sem travar spinner
        nextPick = null;
        await tester.tap(find.byKey(const Key('btn_settings_import_bible')));
        await tester.pumpAndSettle();
        expect(find.text('Importar Bíblia (.epub / .json)'), findsOneWidget);

        // 2) Arquivo vazio exibe erro legível
        nextPick = (name: 'vazio.json', bytes: Uint8List(0));
        await tester.tap(find.byKey(const Key('btn_settings_import_bible')));
        await tester.pumpAndSettle();
        expect(find.textContaining('vazio.json'), findsOneWidget);

        // 3) JSON Bíblico com BOM importa com sucesso e lista tradução
        nextPick = (
          name: 'ticuna_bom.json',
          bytes: Uint8List.fromList(
            utf8.encode(
              '\uFEFF${jsonEncode({
                'title': 'Bíblia UI BOM',
                'language': 'tca',
                'books': {
                  '43': {
                    '3': {'16': 'Versículo importado pela UI.'},
                  },
                },
              })}',
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('btn_settings_import_bible')));
        await tester.pumpAndSettle();
        expect(find.text('Bíblia UI BOM'), findsOneWidget);

        // 4) Aba Publicações importa EPUB e exibe título na lista
        await tester.tap(find.text('Publicações (0)'));
        await tester.pumpAndSettle();
        nextPick = (
          name: 'publicacao_ui.epub',
          bytes: _syntheticPublicationEpubBytes(),
        );
        await tester.tap(
          find.byKey(const Key('btn_settings_import_publication')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Escute a Deus (Publicação Teste)'), findsOneWidget);
      },
    );
  });
}
