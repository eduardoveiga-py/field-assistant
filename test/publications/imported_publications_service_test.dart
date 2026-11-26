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
  });
}
