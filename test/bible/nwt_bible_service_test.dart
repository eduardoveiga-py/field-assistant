import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/bible/nwt_bible_books.dart';
import 'package:ministerio_pessoal/bible/nwt_bible_service.dart';
import 'package:ministerio_pessoal/database/app_database.dart';

void main() {
  group('NwtBibleBooks & NwtBibleService Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'identifica livros da Bíblia em português, inglês, código e número',
      () {
        expect(NwtBibleBooks.all.length, equals(66));
        expect(NwtBibleBooks.findByQuery('Gênesis')?.number, equals(1));
        expect(NwtBibleBooks.findByQuery('genesis')?.number, equals(1));
        expect(NwtBibleBooks.findByQuery('João')?.number, equals(43));
        expect(NwtBibleBooks.findByQuery('jo')?.number, equals(18));
        expect(NwtBibleBooks.findByQuery('joao')?.number, equals(43));
        expect(NwtBibleBooks.findByQuery('Revelation')?.number, equals(66));
        expect(NwtBibleBooks.findByQuery('43')?.number, equals(43));
        expect(
          NwtBibleBooks.findByQuery('Salmos capítulo 83')?.number,
          equals(19),
        );

        expect(
          NwtBibleBooks.formatReferenceLabel(
            bookNumber: 43,
            chapter: 3,
            verseSpec: '16-17',
          ),
          equals('João 3:16-17'),
        );
        expect(
          NwtBibleBooks.buildJwOrgFinderUrl(
            bookNumber: 19,
            chapter: 83,
            firstVerse: 18,
          ),
          equals(
            'https://www.jw.org/finder?wtlocale=T&prefer=lang&bible=19083018',
          ),
        );
      },
    );

    test('parseVerseNumbers interpreta único, intervalo e vírgula', () {
      expect(NwtBibleService.parseVerseNumbers('16'), equals([16]));
      expect(NwtBibleService.parseVerseNumbers('16-18'), equals([16, 17, 18]));
      expect(
        NwtBibleService.parseVerseNumbers('6, 7-9, 7'),
        equals([6, 7, 8, 9]),
      );
      expect(NwtBibleService.parseVerseNumbers(''), isEmpty);
      expect(NwtBibleService.parseVerseNumbers('abc'), isEmpty);
    });

    test(
      'rejeita arquivo .jwpub com erro explicativo orientando para .epub',
      () async {
        await expectLater(
          () => NwtBibleService.importFromBytes(
            db,
            bytes: Uint8List.fromList([1, 2, 3, 4]),
            fileName: 'nwt_T.jwpub',
          ),
          throwsA(
            isA<BibleImportException>().having(
              (e) => e.message,
              'message',
              allOf(contains('.jwpub'), contains('.epub'), contains('jw.org')),
            ),
          ),
        );
      },
    );

    test(
      'importa JSON em armazenamento sharded por livro e resolve lookup',
      () async {
        final jsonPayload = {
          'title': 'Bíblia Sintética de Teste (JSON)',
          'language': 'pt',
          'books': {
            'João': {
              '3': {
                '16':
                    'Texto sintético de teste referente a João três dezesseis.',
                '17':
                    'Texto sintético de teste referente a João três dezessete.',
              },
            },
            'Salmos': {
              '83': {
                '18': 'Texto sintético de teste referente ao Salmo oitenta e três dezoito.',
              },
            },
          },
        };

        final res = await NwtBibleService.importFromBytes(
          db,
          bytes: Uint8List.fromList(utf8.encode(jsonEncode(jsonPayload))),
          fileName: 'biblia_teste.json',
        );

        expect(res.catalog.bookCount, equals(2));
        expect(res.catalog.verseCount, equals(3));
        expect(res.catalog.hasFullLibrary, isTrue);

        // Verifica sharding em AppKvStore por livro (sem blob gigante único)
        final kvJohn =
            await (db.select(db.appKvStore)
                  ..where((t) => t.key.equals(NwtBibleService.bookKvKey(43))))
                .getSingleOrNull();
        expect(kvJohn, isNotNull);

        final lookup = await NwtBibleService.lookupPassage(
          db,
          bookNumber: 43,
          chapter: 3,
          verseSpec: '16-17',
        );
        expect(lookup.hasImportedBible, isTrue);
        expect(lookup.verses.length, equals(2));
        expect(lookup.verses.first.number, equals(16));
        expect(lookup.verses.last.number, equals(17));
        expect(lookup.verses.first.isManualOverride, isFalse);

        // Anotação manual sobrepõe localmente e é preservada quando limpa importação
        await NwtBibleService.saveManualVerse(
          db,
          bookNumber: 43,
          chapter: 3,
          verse: 16,
          text: 'Nota manual sintética do versículo dezesseis.',
        );

        final overridden = await NwtBibleService.lookupPassage(
          db,
          bookNumber: 43,
          chapter: 3,
          verseSpec: '16',
        );
        expect(overridden.verses.single.isManualOverride, isTrue);
        expect(
          overridden.verses.single.text,
          equals('Nota manual sintética do versículo dezesseis.'),
        );

        await NwtBibleService.clearImportedBible(db, includeManual: false);
        final afterClear = await NwtBibleService.lookupPassage(
          db,
          bookNumber: 43,
          chapter: 3,
          verseSpec: '16-17',
        );
        expect(afterClear.hasImportedBible, isFalse);
        expect(afterClear.verses.length, equals(1));
        expect(afterClear.verses.single.number, equals(16));

        await NwtBibleService.clearImportedBible(db, includeManual: true);
        final afterFullClear = await NwtBibleService.lookupPassage(
          db,
          bookNumber: 43,
          chapter: 3,
          verseSpec: '16',
        );
        expect(afterFullClear.verses, isEmpty);
      },
    );

    test('importa arquivo EPUB sintético via spine/toc/XHTML com <span class="verse">', () async {
      final archive = Archive();

      void addUtf8(String path, String content) {
        final data = utf8.encode(content);
        archive.addFile(ArchiveFile(path, data.length, data));
      }

      addUtf8(
        'META-INF/container.xml',
        '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''',
      );

      addUtf8('OEBPS/content.opf', '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Bíblia EPUB Sintética Offline</dc:title>
    <dc:language>pt</dc:language>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="john03" href="john03.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="john03"/>
  </spine>
</package>''');

      addUtf8('OEBPS/toc.ncx', '''<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <navMap>
    <navPoint id="np1" playOrder="1">
      <navLabel><text>João 3</text></navLabel>
      <content src="john03.xhtml"/>
    </navPoint>
  </navMap>
</ncx>''');

      addUtf8('OEBPS/john03.xhtml', '''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>João 3</title></head>
  <body>
    <span class="verse" id="v43-3-16"><sup>16</sup>Conteúdo sintético do verso dezesseis em EPUB.</span>
    <span class="verse" id="v43-3-17"><sup>17</sup>Conteúdo sintético do verso dezessete em EPUB.</span>
  </body>
</html>''');

      final epubBytes = Uint8List.fromList(ZipEncoder().encode(archive));
      final result = await NwtBibleService.importFromBytes(
        db,
        bytes: epubBytes,
        fileName: 'nwt_teste.epub',
      );

      expect(result.catalog.sourceFormat, equals('epub'));
      expect(result.catalog.title, equals('Bíblia EPUB Sintética Offline'));
      expect(result.catalog.bookCount, equals(1));
      expect(result.catalog.verseCount, equals(2));

      final passage = await NwtBibleService.lookupPassage(
        db,
        bookNumber: 43,
        chapter: 3,
        verseSpec: '16,17',
      );
      expect(passage.hasFoundVerses, isTrue);
      expect(passage.verses.length, equals(2));
      expect(
        passage.verses[0].text,
        equals('Conteúdo sintético do verso dezesseis em EPUB.'),
      );
      expect(
        passage.verses[1].text,
        equals('Conteúdo sintético do verso dezessete em EPUB.'),
      );
    });

    test('importa estrutura oficial JW EPUB3 sintética (verso 1 sem sup, w_ch, parágrafos contínuos, Salmo singular, livro de 1 capítulo e início no meio do capítulo)', () async {
      final archive = Archive();

      void addUtf8(String path, String content) {
        final data = utf8.encode(content);
        archive.addFile(ArchiveFile(path, data.length, data));
      }

      addUtf8(
        'META-INF/container.xml',
        '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''',
      );

      addUtf8('OEBPS/content.opf', '''<?xml version="1.0" encoding="UTF-8"?>
<package version="3.0" xmlns="http://www.idpf.org/2007/opf">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Bíblia Oficial Sintética JW</dc:title>
    <dc:language>pt</dc:language>
  </metadata>
  <manifest>
    <item id="nav_bible" href="bibleversenav66_1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ext_rev" href="1001061170-extracted.xhtml" media-type="application/xhtml+xml"/>
    <item id="rev1" href="1001061170.xhtml" media-type="application/xhtml+xml"/>
    <item id="ps3" href="1001061123-split3.xhtml" media-type="application/xhtml+xml"/>
    <item id="obad" href="1001061135.xhtml" media-type="application/xhtml+xml"/>
    <item id="jhn8" href="1001061147-split8.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="nav_bible"/>
    <itemref idref="ext_rev"/>
    <itemref idref="rev1"/>
    <itemref idref="ps3"/>
    <itemref idref="obad"/>
    <itemref idref="jhn8"/>
  </spine>
</package>''');

      addUtf8(
        'OEBPS/bibleversenav66_1.xhtml',
        '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Apocalipse 1</title></head>
<body><p class="w_bibleVerse"><a href="1001061170.xhtml#chapter1_verse1">1</a></p></body></html>''',
      );

      addUtf8(
        'OEBPS/1001061170-extracted.xhtml',
        '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Textos extraídos: Apocalipse</title></head>
<body><div class="groupExt"><p class="sb"><span id="chapter1_verse1"></span>Ignorar extrato.</p></div></body></html>''',
      );

      addUtf8(
        'OEBPS/1001061170.xhtml',
        '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<head><title>Apocalipse 1</title></head>
<body>
<p class="w_navigation w_biblebookname"><a href="biblebooknav.xhtml">Apocalipse</a> <a href="biblechapternav66.xhtml">1</a></p>
<header><h1 id="p1"><span id="page1700" class="pageNum" aria-hidden="true">1700</span><strong>APOCALIPSE</strong></h1></header>
<p id="p2" class="p2 sb"><span id="chapter1"></span><span id="chapter1_verse1"></span><span class="w_ch"><strong>1</strong> </span>Primeiro verso sintetico<span id="fn1"></span><a epub:type="noteref" href="#footnote1">*</a> de Apocalipse. <span id="chapter1_verse2"></span><strong><sup>2</sup></strong>&#x202F;Segundo verso sintetico.</p>
<p id="p3" class="p3 sb"><span id="chapter1_verse4"></span><strong><sup>4</sup></strong>&#x202F;Inicio do quarto verso.</p>
<p id="p4" class="p4 sb">Continuacao em outro paragrafo. <span id="chapter1_verse5"></span><strong><sup>5</sup></strong>&#x202F;Quinto verso sintetico.</p>
<div class="groupFootnote"><aside epub:type="footnote" id="footnote1"><p>Nota de rodape ignorada.</p></aside></div>
</body></html>''',
      );

      addUtf8(
        'OEBPS/1001061123-split3.xhtml',
        '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Salmo 3</title></head>
<body>
<p class="w_navigation w_biblebookname"><a href="biblebooknav.xhtml">Salmos</a> <a href="biblechapternav19.xhtml">3</a></p>
<p id="p23" class="p23 sw">Subtitulo editorial ignorado.</p>
<p id="p24" class="p24 sl"><span id="chapter3"></span><span id="chapter3_verse1"></span><span class="w_ch"><strong>3</strong> </span>Primeira linha poetica.</p>
<p id="p25" class="p25 sz">Segunda linha poetica continuada.</p>
</body></html>''',
      );

      addUtf8(
        'OEBPS/1001061135.xhtml',
        '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Obadias</title></head>
<body>
<p class="w_navigation w_biblebookname"><a href="biblebooknav.xhtml">Obadias</a></p>
<header><h1 id="p1"><strong>OBADIAS</strong></h1></header>
<p id="p2" class="p2 sb"><span id="chapter1"></span><span id="chapter1_verse1"></span><strong><sup>1</sup></strong>&#x202F;Visao sintetica de livro unico.</p>
<p id="p3" class="p3 sz">Segunda linha de Obadias.</p>
</body></html>''',
      );

      addUtf8(
        'OEBPS/1001061147-split8.xhtml',
        '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>João 8</title></head>
<body>
<p class="w_navigation w_biblebookname"><a href="biblebooknav.xhtml">João</a> <a href="biblechapternav43.xhtml">8</a></p>
<p id="p58" class="p58 sb"><span id="chapter8"></span><span id="chapter8_verse12"></span><span class="w_ch"><strong>8</strong> </span><strong><sup>12</sup></strong>&#x202F;Texto sintetico do verso doze.</p>
</body></html>''',
      );

      expect(NwtBibleBooks.findByQuery('Salmo 23')?.number, equals(19));

      final epubBytes = Uint8List.fromList(ZipEncoder().encode(archive));
      final result = await NwtBibleService.importFromBytes(
        db,
        bytes: epubBytes,
        fileName: 'nwt_jw_epub3_sintetico.epub',
      );

      expect(result.catalog.bookCount, equals(4));

      final rev1 = await NwtBibleService.lookupPassage(
        db,
        bookNumber: 66,
        chapter: 1,
        verseSpec: '1,2,4,5',
      );
      expect(rev1.hasFoundVerses, isTrue);
      expect(rev1.verses.map((v) => v.number).toList(), equals([1, 2, 4, 5]));
      expect(
        rev1.verses[0].text,
        equals('Primeiro verso sintetico de Apocalipse.'),
      );
      expect(rev1.verses[0].text, isNot(contains('1')));
      expect(rev1.verses[0].text, isNot(contains('*')));
      expect(
        rev1.verses[2].text,
        equals('Inicio do quarto verso. Continuacao em outro paragrafo.'),
      );
      expect(rev1.verses[3].text, equals('Quinto verso sintetico.'));

      final ps3 = await NwtBibleService.lookupPassage(
        db,
        bookNumber: 19,
        chapter: 3,
        verseSpec: '1',
      );
      expect(ps3.hasFoundVerses, isTrue);
      expect(
        ps3.verses.single.text,
        equals('Primeira linha poetica. Segunda linha poetica continuada.'),
      );
      expect(ps3.verses.single.text, isNot(contains('Subtitulo editorial')));

      final obad1 = await NwtBibleService.lookupPassage(
        db,
        bookNumber: 31,
        chapter: 1,
        verseSpec: '1',
      );
      expect(obad1.hasFoundVerses, isTrue);
      expect(
        obad1.verses.single.text,
        equals('Visao sintetica de livro unico. Segunda linha de Obadias.'),
      );

      final jhn8 = await NwtBibleService.lookupPassage(
        db,
        bookNumber: 43,
        chapter: 8,
        verseSpec: '12',
      );
      expect(jhn8.hasFoundVerses, isTrue);
      expect(jhn8.verses.single.text, equals('Texto sintetico do verso doze.'));
    });

    test('Importa multiplas traduções e idiomas (Portugues + Ticuna), compara lado a lado, isola grifos e rejeita .jwpub com título do manifesto', () async {
      final ptJson = jsonEncode({
        'title': 'Tradução do Novo Mundo (PT)',
        'language': 'pt-BR',
        'books': {
          '43': {
            '3': {'16': 'Porque Deus amou tanto o mundo em portugues.'},
          },
        },
      });
      final ptImport = await NwtBibleService.importFromBytes(
        db,
        bytes: Uint8List.fromList(utf8.encode(ptJson)),
        fileName: 'nwt_T.json',
      );

      // EPUB sintético em idioma Ticuna usando links biblechapternav / bibleversenav
      final tcnArchive = Archive();
      void addTcn(String path, String text) {
        final raw = utf8.encode(text);
        tcnArchive.addFile(ArchiveFile(path, raw.length, raw));
      }

      // Tiny 1x1 PNG transparente válido como capa sintética
      final coverPng = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      );
      tcnArchive.addFile(
        ArchiveFile('OEBPS/images/cover.png', coverPng.length, coverPng),
      );
      addTcn('META-INF/container.xml', '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>''');
      addTcn('OEBPS/content.opf', '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Tupanaãrü Ore (Ticuna)</dc:title>
    <dc:language>tca</dc:language>
  </metadata>
  <manifest>
    <item id="cover-img" href="images/cover.png" media-type="image/png" properties="cover-image"/>
    <item id="c1" href="jhn3.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine><itemref idref="c1"/></spine>
</package>''');
      addTcn('OEBPS/jhn3.xhtml', '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<body>
<p class="w_navigation w_biblebookname"><a href="biblebooknav.xhtml">Juaũ</a> <a href="biblechapternav43.xhtml">3</a></p>
<p id="p1" class="p1 sb"><span id="chapter3"></span><span id="chapter3_verse16"></span><strong><sup>16</sup></strong>&#x202F;Tupana rü meãxü̃chi i naãnecü̃ãxü̃.</p>
</body></html>''');
      final tcnBytes = Uint8List.fromList(ZipEncoder().encode(tcnArchive));
      final tcnImport = await NwtBibleService.importFromBytes(
        db,
        bytes: tcnBytes,
        fileName: 'sbi1_TCN.epub',
      );

      final translations = await NwtBibleService.listTranslations(db);
      expect(translations.length, equals(2));
      expect(tcnImport.catalog.language, equals('tca'));
      expect(tcnImport.catalog.languageDisplay, equals('Ticuna'));
      expect(tcnImport.catalog.coverBase64, isNotNull);

      await NwtBibleService.saveSelectedComparisonIds(db, [
        ptImport.catalog.id,
        tcnImport.catalog.id,
      ]);
      final savedIds = await NwtBibleService.loadSelectedComparisonIds(db);
      expect(savedIds, equals([ptImport.catalog.id, tcnImport.catalog.id]));

      final passages = await NwtBibleService.lookupComparisonPassages(
        db,
        translationIds: savedIds,
        bookNumber: 43,
        chapter: 3,
        verseSpec: '16',
      );
      expect(passages.length, equals(2));
      expect(
        passages[0].lookup.verses.single.text,
        contains('Deus amou tanto'),
      );
      expect(
        passages[1].lookup.verses.single.text,
        contains('Tupana rü meãxü̃chi'),
      );

      // Grifo aplicado apenas na tradução Ticuna não contamina a tradução em Português
      await NwtBibleService.saveVerseHighlightMarkup(
        db,
        bookNumber: 43,
        chapter: 3,
        verse: 16,
        translationId: tcnImport.catalog.id,
        markedText:
            '<u style="color:#3B82F6">Tupana</u> rü meãxü̃chi i naãnecü̃ãxü̃.',
      );
      final ptAfterHl = await NwtBibleService.lookupPassage(
        db,
        bookNumber: 43,
        chapter: 3,
        verseSpec: '16',
        translationId: ptImport.catalog.id,
      );
      final tcnAfterHl = await NwtBibleService.lookupPassage(
        db,
        bookNumber: 43,
        chapter: 3,
        verseSpec: '16',
        translationId: tcnImport.catalog.id,
      );
      expect(ptAfterHl.verses.single.highlightedMarkup, isNull);
      expect(
        tcnAfterHl.verses.single.highlightedMarkup,
        startsWith('<u style="color:#3B82F6">Tupana</u>'),
      );

      // Alterna principal e exclui uma tradução preservando a restante
      await NwtBibleService.setPrimaryTranslation(db, tcnImport.catalog.id);
      final reloaded = await NwtBibleService.listTranslations(db);
      expect(
        reloaded.firstWhere((t) => t.id == tcnImport.catalog.id).isPrimary,
        isTrue,
      );
      await NwtBibleService.deleteTranslation(db, ptImport.catalog.id);
      final afterDelete = await NwtBibleService.listTranslations(db);
      expect(afterDelete.length, equals(1));
      expect(afterDelete.single.id, equals(tcnImport.catalog.id));

      // Arquivo .jwpub criptografado com manifest.json retorna erro contextualizado
      final jwpubArchive = Archive();
      final manifestRaw = utf8.encode(
        jsonEncode({
          'name': 'sbi1_TCN',
          'publication': {'title': 'Tupanaãrü Ore (Perú)'},
          'contentFormat': 'z-a',
        }),
      );
      jwpubArchive.addFile(
        ArchiveFile('manifest.json', manifestRaw.length, manifestRaw),
      );
      final jwpubBytes = Uint8List.fromList(ZipEncoder().encode(jwpubArchive));
      await expectLater(
        NwtBibleService.importFromBytes(
          db,
          bytes: jwpubBytes,
          fileName: 'sbi1_TCN.jwpub',
        ),
        throwsA(
          isA<BibleImportException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Tupanaãrü Ore (Perú)'),
              contains('.epub'),
              contains('jw.org'),
            ),
          ),
        ),
      );
    });

    test('tradução parcial não faz fallback para livros da tradução padrão e preserva versículos combinados', () async {
      await NwtBibleService.importFromBytes(
        db,
        bytes: Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'title': 'Bíblia Completa PT',
              'language': 'pt-BR',
              'books': {
                '51': {
                  '1': {'21': 'Colossenses completo em português.'},
                },
              },
            }),
          ),
        ),
        fileName: 'pt_full.json',
      );

      final partial = await NwtBibleService.importFromBytes(
        db,
        bytes: Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'title': 'Norü wetchicurugü i tnn (nwtp)',
              'language': 'tca',
              'books': {
                '49': {
                  '2': {
                    '11': '2:11-12 Rü ngẽmaca̱ i pema...',
                    '12': 'Nüü̃ nadau 2:11',
                  },
                },
              },
            }),
          ),
        ),
        fileName: 'nwtp_partial.json',
      );

      final colInPartial = await NwtBibleService.lookupPassage(
        db,
        bookNumber: 51,
        chapter: 1,
        verseSpec: '21',
        translationId: partial.catalog.id,
      );
      expect(colInPartial.verses, isEmpty);

      final ep12 = await NwtBibleService.lookupPassage(
        db,
        bookNumber: 49,
        chapter: 2,
        verseSpec: '12',
        translationId: partial.catalog.id,
      );
      expect(ep12.verses.single.text, equals('Nüü̃ nadau 2:11'));

      // Mesmo conteúdo via EPUB com <span class="verse" id="v49-2-12">
      final epubArchive = Archive();
      void addStr(String p, String c) {
        final b = utf8.encode(c);
        epubArchive.addFile(ArchiveFile(p, b.length, b));
      }

      addStr('META-INF/container.xml', '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>''');
      addStr('OEBPS/content.opf', '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/opf" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Tupanaãrü Ore (Perú)</dc:title>
    <dc:language>tca</dc:language>
  </metadata>
  <manifest><item id="e2" href="b49_c002.xhtml" media-type="application/xhtml+xml"/></manifest>
  <spine><itemref idref="e2"/></spine>
</package>''');
      addStr('OEBPS/b49_c002.xhtml', '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<body>
  <p class="w_biblebookname"><a href="biblechapternav49.xhtml">2</a></p>
  <p class="sb"><span class="verse" id="v49-2-11"><sup>11</sup> 2:11-12 Rü ngẽmaca̱...</span></p>
  <p class="sb"><span class="verse" id="v49-2-12"><sup>12</sup> Nüü̃ nadau 2:11</span></p>
</body>
</html>''');
      final epubImport = await NwtBibleService.importFromBytes(
        db,
        bytes: Uint8List.fromList(ZipEncoder().encode(epubArchive)),
        fileName: 'peru.epub',
      );
      expect(epubImport.catalog.languageDisplay, equals('Ticuna'));
      final ep12Epub = await NwtBibleService.lookupPassage(
        db,
        bookNumber: 49,
        chapter: 2,
        verseSpec: '12',
        translationId: epubImport.catalog.id,
      );
      expect(ep12Epub.verses.single.text, equals('Nüü̃ nadau 2:11'));
    });

    test('importa JSON com BOM UTF-8, sem extensao e capitulo/versiculo em string', () async {
      final rawJson =
          '\uFEFF${jsonEncode({
            'title': 'Bíblia BOM Teste',
            'language': 'tca',
            'books': [
              {'bookNumber': '43', 'chapter': '3', 'verse': '16', 'text': 'Texto com BOM e números em string.'},
            ],
          })}';

      final res = await NwtBibleService.importFromBytes(
        db,
        bytes: Uint8List.fromList(utf8.encode(rawJson)),
        fileName: 'document_10492',
      );

      expect(res.catalog.title, equals('Bíblia BOM Teste'));
      expect(res.catalog.sourceFormat, equals('json'));
      expect(res.catalog.verseCount, equals(1));

      final lookup = await NwtBibleService.lookupPassage(
        db,
        bookNumber: 43,
        chapter: 3,
        verseSpec: '16',
        translationId: res.catalog.id,
      );
      expect(lookup.verses, hasLength(1));
      expect(
        lookup.verses.single.text,
        equals('Texto com BOM e números em string.'),
      );
    });

    test(
      'importa EPUB com BOM, href URL-encoded (%20) e entidades HTML comuns',
      () async {
        final archive = Archive();
        void addRaw(String path, List<int> data) {
          archive.addFile(ArchiveFile(path, data.length, data));
        }

        addRaw(
          'META-INF/container.xml',
          utf8.encode('''\uFEFF<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>'''),
        );
        addRaw(
          'OEBPS/content.opf',
          utf8.encode('''\uFEFF<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/opf" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Bíblia Entidades</dc:title>
    <dc:language>pt-BR</dc:language>
  </metadata>
  <manifest><item id="j1" href="Jo%203.xhtml" media-type="application/xhtml+xml"/></manifest>
  <spine><itemref idref="j1"/></spine>
</package>'''),
        );
        addRaw(
          'OEBPS/Jo 3.xhtml',
          utf8.encode('''\uFEFF<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<body>
  <p class="w_biblebookname">João 3</p>
  <p class="sb"><span class="verse" id="v43-3-16"><sup>16</sup>&nbsp;Deus amou&mdash;o mundo.&hellip;</span></p>
</body>
</html>'''),
        );

        final res = await NwtBibleService.importFromBytes(
          db,
          bytes: Uint8List.fromList(ZipEncoder().encode(archive)),
          fileName: 'ENTIDADES.EPUB',
        );
        expect(res.catalog.title, equals('Bíblia Entidades'));
        final lookup = await NwtBibleService.lookupPassage(
          db,
          bookNumber: 43,
          chapter: 3,
          verseSpec: '16',
          translationId: res.catalog.id,
        );
        expect(lookup.verses, hasLength(1));
        expect(lookup.verses.single.text, contains('Deus amou'));
      },
    );
  });
}
