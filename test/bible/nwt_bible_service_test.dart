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
  });
}
