import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/publications/imported_publications_service.dart';

Uint8List _buildSyntheticPublicationEpub({
  required String title,
  required String language,
  required List<({String href, String label, String bodyHtml})> chapters,
}) {
  final archive = Archive();
  void addText(String path, String text) {
    final raw = utf8.encode(text);
    archive.addFile(ArchiveFile(path, raw.length, raw));
  }

  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  );
  archive.addFile(ArchiveFile('OEBPS/images/cover.png', png.length, png));

  addText('META-INF/container.xml', '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>''');

  final manifestItems = StringBuffer()
    ..writeln(
      '<item id="cover" href="images/cover.png" media-type="image/png" properties="cover-image"/>',
    )
    ..writeln(
      '<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>',
    );
  final spineItems = StringBuffer();
  final navPoints = StringBuffer();

  for (var i = 0; i < chapters.length; i++) {
    final ch = chapters[i];
    final id = 'ch$i';
    manifestItems.writeln(
      '<item id="$id" href="${ch.href}" media-type="application/xhtml+xml"/>',
    );
    spineItems.writeln('<itemref idref="$id"/>');
    navPoints.writeln('''
    <navPoint id="np$i" playOrder="${i + 1}">
      <navLabel><text>${ch.label}</text></navLabel>
      <content src="${ch.href}"/>
    </navPoint>''');
    addText('OEBPS/${ch.href}', '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>${ch.label}</title></head>
<body>${ch.bodyHtml}</body>
</html>''');
  }

  addText('OEBPS/toc.ncx', '''<?xml version="1.0" encoding="utf-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <navMap>$navPoints</navMap>
</ncx>''');

  addText('OEBPS/content.opf', '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>$title</dc:title>
    <dc:language>$language</dc:language>
  </metadata>
  <manifest>$manifestItems</manifest>
  <spine toc="ncx">$spineItems</spine>
</package>''');

  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('ImportedPublicationsService', () {
    test('Importa publicacao EPUB com capitulos, capa e exclusao limpa', () async {
      final bytes = _buildSyntheticPublicationEpub(
        title: 'Seja Feliz Para Sempre! (Sintetico)',
        language: 'pt-BR',
        chapters: const [
          (
            href: 'cap1.xhtml',
            label: 'Lição 01 — Como a Bíblia ajuda',
            bodyHtml: '<h1>Lição 01</h1><p>Primeiro parágrafo de estudo sintético.</p><p>Segundo parágrafo com pergunta.</p>',
          ),
          (
            href: 'cap2.xhtml',
            label: 'Lição 02 — Esperança para o futuro',
            bodyHtml:
                '<h1>Lição 02</h1><p>Conteúdo sintético da segunda lição.</p>',
          ),
        ],
      );

      final summary =
          await ImportedPublicationsService.importPublicationFromBytes(
            db,
            bytes: bytes,
            fileName: 'lff_sintetico.epub',
          );

      expect(summary.title, equals('Seja Feliz Para Sempre! (Sintetico)'));
      expect(summary.language, equals('pt-BR'));
      expect(summary.chapterCount, equals(2));
      expect(summary.coverBase64, isNotNull);

      final list = await ImportedPublicationsService.listPublications(db);
      expect(list.length, equals(1));
      expect(list.single.id, equals(summary.id));

      final ch0 = await ImportedPublicationsService.loadChapter(
        db,
        publicationId: summary.id,
        chapterIndex: 0,
      );
      expect(ch0, isNotNull);
      expect(ch0!.title, contains('Lição 01'));
      expect(
        ch0.paragraphs,
        containsAll([
          'Primeiro parágrafo de estudo sintético.',
          'Segundo parágrafo com pergunta.',
        ]),
      );

      final ch1 = await ImportedPublicationsService.loadChapter(
        db,
        publicationId: summary.id,
        chapterIndex: 1,
      );
      expect(
        ch1!.paragraphs.last,
        equals('Conteúdo sintético da segunda lição.'),
      );

      await ImportedPublicationsService.deletePublication(db, summary.id);
      expect(await ImportedPublicationsService.listPublications(db), isEmpty);
      expect(
        await ImportedPublicationsService.loadChapter(
          db,
          publicationId: summary.id,
          chapterIndex: 0,
        ),
        isNull,
      );
    });

    test('Rejeita .jwpub criptografado exibindo titulo do manifesto', () async {
      final archive = Archive();
      final manifest = utf8.encode(
        jsonEncode({
          'name': 'lff_T',
          'publication': {'title': 'Publicação Protegida Sintética'},
          'contentFormat': 'z-a',
        }),
      );
      archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));

      await expectLater(
        ImportedPublicationsService.importPublicationFromBytes(
          db,
          bytes: bytes,
          fileName: 'lff_T.jwpub',
        ),
        throwsA(
          isA<PublicationImportException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Publicação Protegida Sintética'),
              contains('.epub'),
              contains('jw.org'),
            ),
          ),
        ),
      );
    });

    test('Importa publicacao EPUB com BOM UTF-8, href URL-encoded (%20) e entidades HTML comuns', () async {
      final archive = Archive();
      void addRaw(String path, String text) {
        final raw = utf8.encode('\uFEFF$text');
        archive.addFile(ArchiveFile(path, raw.length, raw));
      }

      addRaw('META-INF/container.xml', '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>''');
      addRaw('OEBPS/content.opf', '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/opf" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Organizados Teste</dc:title>
    <dc:language>pt</dc:language>
  </metadata>
  <manifest>
    <item id="c1" href="Cap%2001.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine><itemref idref="c1"/></spine>
</package>''');
      addRaw('OEBPS/Cap 01.xhtml', '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<body>
  <h1>Capítulo&nbsp;1 &mdash; Organização</h1>
  <p>Primeiro parágrafo&rsquo;s texto&hellip;</p>
</body>
</html>''');

      final summary =
          await ImportedPublicationsService.importPublicationFromBytes(
            db,
            bytes: Uint8List.fromList(ZipEncoder().encode(archive)),
            fileName: 'od_T.epub',
          );

      expect(summary.title, equals('Organizados Teste'));
      expect(summary.chapterCount, equals(1));
      final ch0 = await ImportedPublicationsService.loadChapter(
        db,
        publicationId: summary.id,
        chapterIndex: 0,
      );
      expect(ch0, isNotNull);
      expect(ch0!.paragraphs.join(' '), contains('Organização'));
    });

    test('Preserva titulos do toc.ncx sem sobrescrever por links page-list/#pageN, indexa data-pnum e repara indices numericos legados', () async {
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
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <metadata>
    <dc:title>Organizados (Teste JW)</dc:title>
    <dc:language>pt</dc:language>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="nav" href="toc.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="ch1" href="1102014931.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="ch1"/>
  </spine>
</package>''');
      addText('OEBPS/toc.ncx', '''<?xml version="1.0" encoding="utf-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <navMap>
    <navPoint id="np1" playOrder="1">
      <navLabel><text>1 Organizados para fazer a vontade de Jeová</text></navLabel>
      <content src="1102014931.xhtml"/>
    </navPoint>
  </navMap>
</ncx>''');
      addText('OEBPS/toc.xhtml', '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<body>
  <nav epub:type="toc" id="toc">
    <ol><li><a href="1102014931.xhtml"> 1 Organizados para fazer a vontade de Jeová</a></li></ol>
  </nav>
  <nav epub:type="page-list" hidden="hidden">
    <ol>
      <li><a href="1102014931.xhtml#page6">6</a></li>
      <li><a href="1102014931.xhtml#page11">11</a></li>
    </ol>
  </nav>
</body>
</html>''');
      addText(
        'OEBPS/1102014931.xhtml',
        '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<body>
  <header>
    <p class="contextTtl"><strong>CAPÍTULO 1</strong></p>
    <h1><strong>Organizados para fazer a vontade de Jeová</strong></h1>
  </header>
  <h2>Subtítulo Importante</h2>
  <p><span class="parNum" data-pnum="1"></span>EM TODO o mundo há uma organização singular.</p>
  <p><span class="parNum" data-pnum="2"><sup>2</sup></span> Estamos felizes por estar nela.</p>
  <p><span class="parNum" data-pnum="3"><sup>3</sup></span> A bênção de Jeová traz alegria.</p>
</body>
</html>''',
      );

      final summary =
          await ImportedPublicationsService.importPublicationFromBytes(
            db,
            bytes: Uint8List.fromList(ZipEncoder().encode(archive)),
            fileName: 'od_T_sint.epub',
          );

      expect(summary.chapters.length, equals(1));
      expect(
        summary.chapters.first.title,
        equals('1 Organizados para fazer a vontade de Jeová'),
      );

      final ch0 = await ImportedPublicationsService.loadChapter(
        db,
        publicationId: summary.id,
        chapterIndex: 0,
      );
      expect(ch0, isNotNull);
      final selected = ImportedPublicationsService.selectParagraphs(
        ch0!,
        paragraphSpec: '1, 3',
      );
      expect(selected.map((p) => p.number).toList(), equals([1, 3]));
      final transcript = ImportedPublicationsService.formatChapterTranscript(
        publication: summary,
        chapter: ch0,
        paragraphSpec: '1, 3',
      );
      expect(transcript, contains('Subtítulo Importante'));
      expect(transcript, contains('1. EM TODO o mundo'));
      expect(transcript, contains('A bênção de Jeová traz alegria.'));
      expect(transcript, isNot(contains('Estamos felizes por estar nela')));

      // Simula título numérico legado ("11") no catálogo KV e verifica reparo automático
      final brokenCatalog = [
        ImportedPublicationSummary(
          id: summary.id,
          title: summary.title,
          language: summary.language,
          sourceFormat: 'epub',
          importedAt: summary.importedAt,
          chapterCount: 1,
          chapters: const [
            ImportedPublicationChapterMeta(
              index: 0,
              title: '11',
              href: '1102014931.xhtml',
            ),
          ],
        ).toJson(),
      ];
      await db
          .into(db.appKvStore)
          .insertOnConflictUpdate(
            AppKvStoreCompanion.insert(
              key: ImportedPublicationsService.catalogKvKey,
              value: jsonEncode(brokenCatalog),
            ),
          );
      final repaired =
          await ImportedPublicationsService.repairNumericChapterTitlesIfNeeded(
            db,
            summary.id,
          );
      expect(repaired, isNotNull);
      expect(
        repaired!.chapters.first.title,
        equals('CAPÍTULO 1 — Organizados para fazer a vontade de Jeová'),
      );
    });

    test('atribui números de pontos em seções numeradas estilo LFF sem parNum explícito', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final epubBytes = _buildSyntheticPublicationEpub(
        title: 'Seja Feliz Para Sempre!',
        language: 'pt',
        chapters: const [
          (
            href: 'lesson1.xhtml',
            label: 'Lição 01 — Como a Bíblia pode ajudar você?',
            bodyHtml: '''
              <p class="contextTtl">LIÇÃO 01</p>
              <h1>Como a Bíblia pode ajudar você?</h1>
              <p>Introdução inicial sem número.</p>
              <h3>1. Quais são algumas perguntas?</h3>
              <p>A Bíblia responde a perguntas importantes.</p>
              <h3>2. Como ser mais feliz?</h3>
              <p>Seus conselhos ajudam no dia a dia.</p>
            ''',
          ),
        ],
      );

      final summary =
          await ImportedPublicationsService.importPublicationFromBytes(
            db,
            bytes: epubBytes,
            fileName: 'lff_sample.epub',
          );
      final chapter = await ImportedPublicationsService.loadChapter(
        db,
        publicationId: summary.id,
        chapterIndex: 0,
      );
      expect(chapter, isNotNull);
      final point2 = ImportedPublicationsService.selectParagraphs(
        chapter!,
        paragraphSpec: '2',
      );
      expect(point2.length, equals(1));
      expect(point2.first.number, equals(2));
      expect(point2.first.heading, equals('2. Como ser mais feliz?'));
      expect(point2.first.text, contains('conselhos ajudam'));

      // Legado sem paragraphItems também infere pontos corretamente
      final legacyItems = ImportedPublicationsService.deriveParagraphItems(
        chapter.paragraphs,
        chapterTitle: chapter.title,
      );
      expect(legacyItems.where((p) => p.number == 1), hasLength(1));
      expect(legacyItems.where((p) => p.number == 2), hasLength(1));
    });
  });
}
