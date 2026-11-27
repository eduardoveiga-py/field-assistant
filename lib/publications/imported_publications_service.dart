import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' as drift;
import 'package:xml/xml.dart';

import '../core/app_logger.dart';
import '../database/app_database.dart';

/// Erro controlado ao importar publicações locais em EPUB ou tentar JWPUB.
class PublicationImportException implements Exception {
  final String message;

  const PublicationImportException(this.message);

  @override
  String toString() => message;
}

/// Metadado leve de um capítulo/artigo dentro de uma publicação importada.
class ImportedPublicationChapterMeta {
  final int index;
  final String title;
  final String href;

  const ImportedPublicationChapterMeta({
    required this.index,
    required this.title,
    required this.href,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'title': title,
    'href': href,
  };

  factory ImportedPublicationChapterMeta.fromJson(Map<String, dynamic> json) {
    return ImportedPublicationChapterMeta(
      index: (json['index'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? 'Capítulo',
      href: json['href']?.toString() ?? '',
    );
  }
}

/// Resumo de uma publicação importada localmente pelo usuário.
class ImportedPublicationSummary {
  final String id;
  final String title;
  final String language;
  final String sourceFormat;
  final DateTime importedAt;
  final int chapterCount;
  final String? coverBase64;
  final List<ImportedPublicationChapterMeta> chapters;

  const ImportedPublicationSummary({
    required this.id,
    required this.title,
    required this.language,
    required this.sourceFormat,
    required this.importedAt,
    required this.chapterCount,
    this.coverBase64,
    this.chapters = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'language': language,
    'sourceFormat': sourceFormat,
    'importedAt': importedAt.toUtc().toIso8601String(),
    'chapterCount': chapterCount,
    if (coverBase64 != null && coverBase64!.isNotEmpty)
      'coverBase64': coverBase64,
    'chapters': chapters.map((c) => c.toJson()).toList(),
  };

  factory ImportedPublicationSummary.fromJson(Map<String, dynamic> json) {
    final rawChapters = (json['chapters'] as List?) ?? const [];
    final chapters = rawChapters
        .whereType<Map>()
        .map(
          (c) => ImportedPublicationChapterMeta.fromJson(
            Map<String, dynamic>.from(c),
          ),
        )
        .toList();
    return ImportedPublicationSummary(
      id: json['id']?.toString() ?? 'pub',
      title: json['title']?.toString() ?? 'Publicação',
      language: json['language']?.toString() ?? 'pt',
      sourceFormat: json['sourceFormat']?.toString() ?? 'epub',
      importedAt:
          DateTime.tryParse(json['importedAt']?.toString() ?? '') ??
          DateTime.now(),
      chapterCount: (json['chapterCount'] as num?)?.toInt() ?? chapters.length,
      coverBase64: json['coverBase64']?.toString(),
      chapters: chapters,
    );
  }
}

/// Conteúdo completo de um capítulo/lição extraído de uma publicação EPUB.
class ImportedPublicationChapterContent {
  final String publicationId;
  final int index;
  final String title;
  final List<String> paragraphs;

  const ImportedPublicationChapterContent({
    required this.publicationId,
    required this.index,
    required this.title,
    required this.paragraphs,
  });

  String get plainText => paragraphs.join('\n\n');
}

/// Serviço offline-first para importação e leitura local de publicações em EPUB
/// (livros, brochuras, revistas e apostilas), armazenadas sharded em [AppKvStore].
class ImportedPublicationsService {
  ImportedPublicationsService._();

  static const String catalogKvKey = 'pub_library_catalog_v1';
  static String chapterKvKey(String pubId, int index) =>
      'pub_item_${pubId}_ch_$index';

  static Future<List<ImportedPublicationSummary>> listPublications(
    AppDatabase db,
  ) async {
    final row = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.equals(catalogKvKey))).getSingleOrNull();
    if (row == null || row.value.isEmpty) return const [];
    try {
      final decoded = jsonDecode(row.value);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map(
              (m) => ImportedPublicationSummary.fromJson(
                Map<String, dynamic>.from(m),
              ),
            )
            .toList();
      }
    } catch (e, st) {
      AppLogger.warning(
        'Falha ao ler catálogo de publicações importadas',
        e,
        st,
      );
    }
    return const [];
  }

  static Future<ImportedPublicationSummary?> getPublication(
    AppDatabase db,
    String publicationId,
  ) async {
    final all = await listPublications(db);
    for (final p in all) {
      if (p.id == publicationId) return p;
    }
    return null;
  }

  static Future<ImportedPublicationChapterContent?> loadChapter(
    AppDatabase db, {
    required String publicationId,
    required int chapterIndex,
  }) async {
    final pub = await getPublication(db, publicationId);
    if (pub == null) return null;
    final row =
        await (db.select(db.appKvStore)..where(
              (t) => t.key.equals(chapterKvKey(publicationId, chapterIndex)),
            ))
            .getSingleOrNull();
    if (row == null || row.value.isEmpty) return null;
    try {
      final decoded = jsonDecode(row.value);
      if (decoded is Map) {
        final rawParas = (decoded['paragraphs'] as List?) ?? const [];
        return ImportedPublicationChapterContent(
          publicationId: publicationId,
          index: chapterIndex,
          title: decoded['title']?.toString() ?? 'Capítulo ${chapterIndex + 1}',
          paragraphs: rawParas.map((e) => e.toString()).toList(),
        );
      }
    } catch (e, st) {
      AppLogger.warning(
        'Falha ao ler capítulo $chapterIndex da publicação $publicationId',
        e,
        st,
      );
    }
    return null;
  }

  static Future<void> deletePublication(
    AppDatabase db,
    String publicationId,
  ) async {
    final current = await listPublications(db);
    final updated = current.where((p) => p.id != publicationId).toList();
    await db.transaction(() async {
      await (db.delete(
        db.appKvStore,
      )..where((t) => t.key.like('pub_item_${publicationId}_ch_%'))).go();
      await _putKv(
        db,
        catalogKvKey,
        jsonEncode(updated.map((e) => e.toJson()).toList()),
      );
    });
  }

  /// Importa publicação oficial em formato `.epub` para leitura e referência cruzada offline.
  static Future<ImportedPublicationSummary> importPublicationFromBytes(
    AppDatabase db, {
    required Uint8List bytes,
    required String fileName,
    void Function(int processed, int total)? onProgress,
  }) async {
    if (bytes.isEmpty) {
      throw const PublicationImportException(
        'O arquivo selecionado está vazio.',
      );
    }
    if (_looksLikePdf(bytes)) {
      throw PublicationImportException(
        'O arquivo "$fileName" é um PDF, não um EPUB. Para anexar PDFs use a aba Documentos da Base de Conhecimento.',
      );
    }

    final lowerName = fileName.toLowerCase().trim();
    if (lowerName.endsWith('.jwpub') || lowerName.endsWith('.jwlpub')) {
      final titleHint = _tryReadJwpubManifestTitle(bytes);
      final label = titleHint != null ? ' ("$titleHint")' : '';
      throw PublicationImportException(
        'O pacote .jwpub$label utiliza conteúdo interno criptografado exclusivo do aplicativo JW Library.\n'
        'Por segurança e respeito à proteção do arquivo, não é possível extrair o texto de .jwpub. '
        'Baixe no site jw.org a edição em formato .epub para importar esta publicação.',
      );
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw PublicationImportException(
        'Não foi possível abrir "$fileName" como EPUB/ZIP válido: $e',
      );
    }

    final filesByPath = <String, ArchiveFile>{};
    for (final f in archive.files) {
      if (f.isFile) {
        filesByPath[_normalizeZipPath(f.name)] = f;
      }
    }

    if (filesByPath.containsKey('manifest.json') &&
        (filesByPath.containsKey('contents') ||
            filesByPath.keys.any((k) => k.endsWith('.db')))) {
      final titleHint = _tryReadJwpubManifestTitle(bytes);
      final label = titleHint != null ? ' ("$titleHint")' : '';
      throw PublicationImportException(
        'Este arquivo$label é um pacote .jwpub criptografado exclusivo do JW Library.\n'
        'Baixe a versão em .epub no site jw.org para leitura offline.',
      );
    }

    final opfPath = _findOpfPath(filesByPath);
    final opfFile = opfPath == null
        ? null
        : _lookupArchiveFile(filesByPath, opfPath);
    if (opfPath == null || opfFile == null) {
      throw const PublicationImportException(
        'Arquivo EPUB inválido: documento package/content .opf não encontrado.',
      );
    }

    final opfXml = XmlDocument.parse(_decodeFileUtf8(opfFile));
    final opfDir = _dirname(opfPath);

    final rawTitle =
        opfXml.findAllElements('dc:title').firstOrNull?.innerText.trim() ??
        opfXml.findAllElements('title').firstOrNull?.innerText.trim() ??
        fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    final title = rawTitle.isEmpty ? 'Publicação EPUB' : rawTitle;
    final language =
        opfXml.findAllElements('dc:language').firstOrNull?.innerText.trim() ??
        'pt';

    final manifestHrefById = <String, String>{};
    final manifestMediaById = <String, String>{};
    String? ncxPath;
    String? navXhtmlPath;
    String? coverImagePath;
    String? coverMetaId;

    for (final meta in opfXml.findAllElements('meta')) {
      if (meta.getAttribute('name')?.toLowerCase() == 'cover') {
        coverMetaId = meta.getAttribute('content');
      }
    }

    for (final item in opfXml.findAllElements('item')) {
      final id = item.getAttribute('id') ?? '';
      final href = item.getAttribute('href') ?? '';
      final mediaType = item.getAttribute('media-type') ?? '';
      final properties = item.getAttribute('properties') ?? '';
      if (id.isEmpty || href.isEmpty) continue;
      final resolved = _resolveZipPath(opfDir, href);
      manifestHrefById[id] = resolved;
      manifestMediaById[id] = mediaType;

      if (mediaType.contains('dtbncx') ||
          resolved.toLowerCase().endsWith('.ncx')) {
        ncxPath ??= resolved;
      }
      if (properties.split(RegExp(r'\s+')).contains('nav')) {
        navXhtmlPath ??= resolved;
      }
      if (properties.split(RegExp(r'\s+')).contains('cover-image') ||
          (coverMetaId != null && id == coverMetaId)) {
        coverImagePath ??= resolved;
      }
    }

    String? coverBase64;
    if (coverImagePath != null) {
      final coverFile = _lookupArchiveFile(filesByPath, coverImagePath);
      if (coverFile != null) {
        final coverBytes = coverFile.content;
        if (coverBytes.isNotEmpty && coverBytes.length <= 180 * 1024) {
          coverBase64 = base64Encode(coverBytes);
        }
      }
    }

    final tocLabelsByHref = <String, String>{};
    if (ncxPath != null) {
      final ncxFile = _lookupArchiveFile(filesByPath, ncxPath);
      if (ncxFile != null) {
        _extractNcxLabels(ncxFile, _dirname(ncxPath), tocLabelsByHref);
      }
    }
    if (navXhtmlPath != null) {
      final navFile = _lookupArchiveFile(filesByPath, navXhtmlPath);
      if (navFile != null) {
        _extractNavXhtmlLabels(
          navFile,
          _dirname(navXhtmlPath),
          tocLabelsByHref,
        );
      }
    }

    final spinePaths = <String>[];
    for (final itemref in opfXml.findAllElements('itemref')) {
      final idref = itemref.getAttribute('idref');
      if (idref != null && manifestHrefById.containsKey(idref)) {
        final path = manifestHrefById[idref]!;
        final media = manifestMediaById[idref] ?? '';
        if (media.isEmpty ||
            media.contains('html') ||
            path.toLowerCase().endsWith('.xhtml') ||
            path.toLowerCase().endsWith('.html')) {
          spinePaths.add(path);
        }
      }
    }

    if (spinePaths.isEmpty) {
      spinePaths.addAll(
        filesByPath.keys.where(
          (k) =>
              k.toLowerCase().endsWith('.xhtml') ||
              k.toLowerCase().endsWith('.html'),
        ),
      );
    }

    final extractedChapters =
        <({String title, String href, List<String> paragraphs})>[];
    final total = spinePaths.length;
    for (var i = 0; i < total; i++) {
      final path = spinePaths[i];
      final lowerPath = path.toLowerCase();
      if (lowerPath.contains('-extracted') ||
          RegExp(r'(?:^|/)(?:toc|nav|cover|pagenav)\.xhtml$')
              .hasMatch(lowerPath) ||
          RegExp(r'(?:^|/)bible(?:book|chapter|verse)nav')
              .hasMatch(lowerPath)) {
        if (i > 0 && i % 15 == 0) {
          onProgress?.call(i + 1, total);
          await Future<void>.delayed(Duration.zero);
        }
        continue;
      }
      final f = _lookupArchiveFile(filesByPath, path);
      if (f == null) continue;
      final xhtml = _decodeFileUtf8(f);
      final extracted = _extractChapterFromXhtml(
        xhtml,
        tocTitleHint: tocLabelsByHref[path],
        fallbackTitle: 'Seção ${extractedChapters.length + 1}',
      );
      if (extracted != null && extracted.paragraphs.isNotEmpty) {
        extractedChapters.add((
          title: extracted.title,
          href: path,
          paragraphs: extracted.paragraphs,
        ));
      }
      if (i > 0 && i % 10 == 0) {
        onProgress?.call(i + 1, total);
        await Future<void>.delayed(Duration.zero);
      }
    }
    onProgress?.call(total, total);

    if (extractedChapters.isEmpty) {
      throw const PublicationImportException(
        'Não foi possível extrair conteúdo textual deste EPUB.',
      );
    }

    final existingList = await listPublications(db);
    final existingMatch = existingList
        .where(
          (p) =>
              p.title.toLowerCase() == title.toLowerCase() &&
              p.language.toLowerCase() == language.toLowerCase(),
        )
        .firstOrNull;
    final pubId = existingMatch?.id ?? _buildSlugId(title, language);

    final chapterMetas = <ImportedPublicationChapterMeta>[];
    await db.transaction(() async {
      await (db.delete(
        db.appKvStore,
      )..where((t) => t.key.like('pub_item_${pubId}_ch_%'))).go();

      for (var idx = 0; idx < extractedChapters.length; idx++) {
        final ch = extractedChapters[idx];
        chapterMetas.add(
          ImportedPublicationChapterMeta(
            index: idx,
            title: ch.title,
            href: ch.href,
          ),
        );
        await _putKv(
          db,
          chapterKvKey(pubId, idx),
          jsonEncode({'title': ch.title, 'paragraphs': ch.paragraphs}),
        );
      }

      final summary = ImportedPublicationSummary(
        id: pubId,
        title: title,
        language: language,
        sourceFormat: 'epub',
        importedAt: DateTime.now(),
        chapterCount: chapterMetas.length,
        coverBase64: coverBase64,
        chapters: chapterMetas,
      );

      final updatedCatalog = existingList.where((p) => p.id != pubId).toList()
        ..insert(0, summary);
      await _putKv(
        db,
        catalogKvKey,
        jsonEncode(updatedCatalog.map((e) => e.toJson()).toList()),
      );
    });

    return (await getPublication(db, pubId))!;
  }

  static String? _tryReadJwpubManifestTitle(Uint8List bytes) {
    try {
      final arch = ZipDecoder().decodeBytes(bytes);
      for (final f in arch.files) {
        if (f.isFile && _normalizeZipPath(f.name) == 'manifest.json') {
          final decoded = jsonDecode(
            utf8.decode(f.content, allowMalformed: true),
          );
          if (decoded is Map) {
            final pub = decoded['publication'];
            if (pub is Map && pub['title'] != null) {
              final t = pub['title'].toString().trim();
              if (t.isNotEmpty) return t;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static bool _looksLikePdf(Uint8List bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
  }

  static ({String title, List<String> paragraphs})? _extractChapterFromXhtml(
    String xhtml, {
    String? tocTitleHint,
    required String fallbackTitle,
  }) {
    if (xhtml.trim().isEmpty) return null;
    XmlDocument? doc;
    try {
      doc = XmlDocument.parse(xhtml);
    } catch (_) {
      final sanitized = _replaceCommonHtmlEntities(xhtml);
      if (sanitized != xhtml) {
        try {
          doc = XmlDocument.parse(sanitized);
        } catch (_) {
          doc = null;
        }
      }
    }
    if (doc == null) return null;

    final body = doc.findAllElements('body').firstOrNull ?? doc.rootElement;
    String? detectedTitle = tocTitleHint?.trim().isNotEmpty == true
        ? _normalizeWhitespace(tocTitleHint!)
        : null;

    if (detectedTitle == null || detectedTitle.isEmpty) {
      for (final tag in const ['h1', 'h2', 'title']) {
        final el = doc.findAllElements(tag).firstOrNull;
        if (el != null) {
          final t = _normalizeWhitespace(el.innerText);
          if (t.isNotEmpty) {
            detectedTitle = t;
            break;
          }
        }
      }
    }

    final paragraphs = <String>[];
    final seen = <String>{};

    bool isIgnoredElement(XmlElement el) {
      XmlNode? cur = el;
      while (cur is XmlElement) {
        final tag = cur.name.local.toLowerCase();
        if (tag == 'nav' ||
            tag == 'script' ||
            tag == 'style' ||
            tag == 'aside') {
          return true;
        }
        final cls = (cur.getAttribute('class') ?? '').toLowerCase();
        final tokens = cls
            .split(RegExp(r'\s+'))
            .where((t) => t.isNotEmpty)
            .toSet();
        if (tokens.contains('w_navigation') ||
            tokens.contains('docnav') ||
            tokens.contains('groupext') ||
            tokens.contains('groupfootnote') ||
            tokens.contains('pagenum')) {
          return true;
        }
        if (cur.attributes.any(
          (a) =>
              a.name.local.toLowerCase() == 'type' &&
              (a.value.toLowerCase() == 'footnote' ||
                  a.value.toLowerCase() == 'noteref'),
        )) {
          return true;
        }
        cur = cur.parent;
      }
      return false;
    }

    for (final el in body.descendants.whereType<XmlElement>()) {
      final tag = el.name.local.toLowerCase();
      if (tag != 'h1' &&
          tag != 'h2' &&
          tag != 'h3' &&
          tag != 'p' &&
          tag != 'li') {
        continue;
      }
      if (isIgnoredElement(el)) continue;
      // Avoid double-reading <p> inside <li> or nested <p>
      if (tag == 'p' && el.parent is XmlElement) {
        final pTag = (el.parent as XmlElement).name.local.toLowerCase();
        if (pTag == 'li' || pTag == 'p') continue;
      }

      final buf = StringBuffer();
      void walk(XmlNode n) {
        if (n is XmlElement) {
          final t = n.name.local.toLowerCase();
          final cls = (n.getAttribute('class') ?? '').toLowerCase();
          if (cls.contains('pagenum') ||
              n.getAttribute('aria-hidden') == 'true' ||
              t == 'script' ||
              t == 'style') {
            return;
          }
          for (final c in n.children) {
            walk(c);
          }
        } else if (n is XmlText) {
          buf.write(n.value);
        }
      }

      walk(el);
      var text = _normalizeWhitespace(buf.toString());
      if (text.isEmpty) continue;
      if (tag == 'li') {
        text = '• $text';
      }
      if (seen.add(text) || paragraphs.isEmpty || paragraphs.last != text) {
        paragraphs.add(text);
      }
    }

    if (paragraphs.isEmpty) return null;
    return (
      title: (detectedTitle != null && detectedTitle.isNotEmpty)
          ? detectedTitle
          : fallbackTitle,
      paragraphs: paragraphs,
    );
  }

  static String _buildSlugId(String title, String language) {
    final clean = '${language}_${title.toLowerCase()}'
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final prefix = clean.isEmpty
        ? 'pub'
        : (clean.length > 28 ? clean.substring(0, 28) : clean);
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}';
  }

  static void _extractNcxLabels(
    ArchiveFile file,
    String baseDir,
    Map<String, String> outLabels,
  ) {
    try {
      final doc = XmlDocument.parse(_decodeFileUtf8(file));
      for (final point in doc.findAllElements('navPoint')) {
        final label = point
            .findAllElements('text')
            .firstOrNull
            ?.innerText
            .trim();
        final src = point
            .findAllElements('content')
            .firstOrNull
            ?.getAttribute('src');
        if (label != null &&
            label.isNotEmpty &&
            src != null &&
            src.isNotEmpty) {
          final resolved = _resolveZipPath(baseDir, src.split('#').first);
          outLabels[resolved] = label;
        }
      }
    } catch (_) {}
  }

  static void _extractNavXhtmlLabels(
    ArchiveFile file,
    String baseDir,
    Map<String, String> outLabels,
  ) {
    try {
      final doc = XmlDocument.parse(_decodeFileUtf8(file));
      for (final a in doc.findAllElements('a')) {
        final href = a.getAttribute('href');
        final label = _normalizeWhitespace(a.innerText);
        if (href != null && href.isNotEmpty && label.isNotEmpty) {
          final resolved = _resolveZipPath(baseDir, href.split('#').first);
          outLabels[resolved] = label;
        }
      }
    } catch (_) {}
  }

  static String _replaceCommonHtmlEntities(String raw) {
    const map = <String, String>{
      '&nbsp;': '&#160;',
      '&mdash;': '&#8212;',
      '&ndash;': '&#8211;',
      '&rsquo;': '&#8217;',
      '&lsquo;': '&#8216;',
      '&rdquo;': '&#8221;',
      '&ldquo;': '&#8220;',
      '&hellip;': '&#8230;',
      '&copy;': '&#169;',
      '&reg;': '&#174;',
      '&laquo;': '&#171;',
      '&raquo;': '&#187;',
    };
    var out = raw;
    for (final e in map.entries) {
      if (out.contains(e.key)) {
        out = out.replaceAll(e.key, e.value);
      }
    }
    return out;
  }

  static ArchiveFile? _lookupArchiveFile(
    Map<String, ArchiveFile> files,
    String rawPath,
  ) {
    final direct = files[rawPath];
    if (direct != null) return direct;
    try {
      final decoded = _normalizeZipPath(Uri.decodeFull(rawPath));
      if (files[decoded] != null) return files[decoded];
      final lowerDecoded = decoded.toLowerCase();
      for (final e in files.entries) {
        if (e.key.toLowerCase() == lowerDecoded) return e.value;
      }
    } catch (_) {
      final lowerRaw = rawPath.toLowerCase();
      for (final e in files.entries) {
        if (e.key.toLowerCase() == lowerRaw) return e.value;
      }
    }
    return null;
  }

  static String? _findOpfPath(Map<String, ArchiveFile> files) {
    final container = _lookupArchiveFile(files, 'META-INF/container.xml');
    if (container != null) {
      try {
        final doc = XmlDocument.parse(_decodeFileUtf8(container));
        final rootfile = doc.findAllElements('rootfile').firstOrNull;
        final fullPath = rootfile?.getAttribute('full-path');
        if (fullPath != null && fullPath.isNotEmpty) {
          return _normalizeZipPath(fullPath);
        }
      } catch (_) {}
    }
    for (final k in files.keys) {
      if (k.toLowerCase().endsWith('.opf')) return k;
    }
    return null;
  }

  static Future<void> _putKv(AppDatabase db, String key, String value) async {
    await db
        .into(db.appKvStore)
        .insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: key,
            value: value,
            updatedAt: drift.Value(DateTime.now()),
          ),
        );
  }

  static String _decodeFileUtf8(ArchiveFile f) {
    final decoded = utf8.decode(f.content, allowMalformed: true);
    return decoded.startsWith('\uFEFF') ? decoded.substring(1) : decoded;
  }

  static String _normalizeZipPath(String raw) {
    final forward = raw.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
    final segments = <String>[];
    for (final part in forward.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (segments.isNotEmpty) segments.removeLast();
      } else {
        segments.add(part);
      }
    }
    return segments.join('/');
  }

  static String _dirname(String path) {
    final idx = path.lastIndexOf('/');
    return idx <= 0 ? '' : path.substring(0, idx);
  }

  static String _resolveZipPath(String baseDir, String relative) {
    if (relative.startsWith('/')) return _normalizeZipPath(relative);
    final joined = baseDir.isEmpty ? relative : '$baseDir/$relative';
    return _normalizeZipPath(joined);
  }

  static String _normalizeWhitespace(String raw) {
    return raw
        .replaceAll(RegExp(r'[\u00A0\u202F\u200B]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
