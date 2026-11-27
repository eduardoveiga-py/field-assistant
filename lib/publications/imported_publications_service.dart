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

/// Bloco/parágrafo estruturado dentro de um capítulo de publicação importada.
class ImportedPublicationParagraph {
  final int? number;
  final String? heading;
  final String text;

  const ImportedPublicationParagraph({
    this.number,
    this.heading,
    required this.text,
  });

  bool get isHeadingOnly =>
      heading != null && heading == text && number == null;

  Map<String, dynamic> toJson() => {
    if (number != null) 'number': number,
    if (heading != null && heading!.isNotEmpty) 'heading': heading,
    'text': text,
  };

  factory ImportedPublicationParagraph.fromJson(Map<String, dynamic> json) {
    return ImportedPublicationParagraph(
      number: (json['number'] as num?)?.toInt(),
      heading: json['heading']?.toString(),
      text: json['text']?.toString() ?? '',
    );
  }
}

/// Conteúdo completo de um capítulo/lição extraído de uma publicação EPUB.
class ImportedPublicationChapterContent {
  final String publicationId;
  final int index;
  final String title;
  final List<String> paragraphs;
  final List<ImportedPublicationParagraph> paragraphItems;

  const ImportedPublicationChapterContent({
    required this.publicationId,
    required this.index,
    required this.title,
    required this.paragraphs,
    this.paragraphItems = const [],
  });

  String get plainText => paragraphs.join('\n\n');

  /// Retorna os parágrafos estruturados (com número e subtítulo quando disponíveis),
  /// inferindo metadados dinamicamente para publicações importadas em versões anteriores.
  List<ImportedPublicationParagraph> get resolvedParagraphs {
    if (paragraphItems.isNotEmpty) return paragraphItems;
    return ImportedPublicationsService.deriveParagraphItems(
      paragraphs,
      chapterTitle: title,
    );
  }
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
        final rawItems = (decoded['paragraphItems'] as List?) ?? const [];
        final items = rawItems
            .whereType<Map>()
            .map(
              (m) => ImportedPublicationParagraph.fromJson(
                Map<String, dynamic>.from(m),
              ),
            )
            .toList();
        return ImportedPublicationChapterContent(
          publicationId: publicationId,
          index: chapterIndex,
          title: decoded['title']?.toString() ?? 'Capítulo ${chapterIndex + 1}',
          paragraphs: rawParas.map((e) => e.toString()).toList(),
          paragraphItems: items,
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
        <
          ({
            String title,
            String href,
            List<String> paragraphs,
            List<ImportedPublicationParagraph> paragraphItems,
          })
        >[];
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
          paragraphItems: extracted.paragraphItems,
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
          jsonEncode({
            'title': ch.title,
            'paragraphs': ch.paragraphs,
            'paragraphItems': ch.paragraphItems.map((p) => p.toJson()).toList(),
          }),
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

  static final RegExp _numericOnlyLabelRe = RegExp(r'^\d{1,4}$');

  static bool isNumericOnlyLabel(String? label) {
    if (label == null) return true;
    final t = label.trim();
    return t.isEmpty || _numericOnlyLabelRe.hasMatch(t);
  }

  /// Faz o parsing de intervalos de parágrafos (`3`, `3-5`, `1, 4-6`) no mesmo formato dos versículos.
  static List<int> parseParagraphNumbers(String? spec) {
    if (spec == null || spec.trim().isEmpty) return const [];
    final normalized = spec.replaceAll(RegExp(r'\s+'), '');
    final out = <int>[];
    for (final chunk in normalized.split(',')) {
      if (chunk.isEmpty) continue;
      final rangeParts = chunk.split('-');
      if (rangeParts.length == 2) {
        final start = int.tryParse(rangeParts[0]);
        final end = int.tryParse(rangeParts[1]);
        if (start != null && end != null && start > 0 && end >= start) {
          final cappedEnd = (end - start > 150) ? start + 150 : end;
          for (var n = start; n <= cappedEnd; n++) {
            if (!out.contains(n)) out.add(n);
          }
        }
      } else if (rangeParts.length == 1) {
        final single = int.tryParse(rangeParts[0]);
        if (single != null && single > 0 && !out.contains(single)) {
          out.add(single);
        }
      }
    }
    return out;
  }

  /// Infere estrutura de parágrafos (números e subtítulos) para capítulos já gravados sem `paragraphItems`.
  static List<ImportedPublicationParagraph> deriveParagraphItems(
    List<String> paragraphs, {
    String? chapterTitle,
  }) {
    final items = <ImportedPublicationParagraph>[];
    String? activeHeading;
    final normalizedChapter = (chapterTitle ?? '').trim().toLowerCase();

    for (final raw in paragraphs) {
      final text = raw.trim();
      if (text.isEmpty) continue;
      final lower = text.toLowerCase();

      // Detecta subtítulo numerado (ex: "1. Quais são...", ou pergunta curta de seção)
      final numberedPoint = RegExp(r'^(\d{1,2})\.\s+\S').firstMatch(text);
      if (numberedPoint != null && text.length < 180) {
        activeHeading = text;
        items.add(
          ImportedPublicationParagraph(heading: activeHeading, text: text),
        );
        continue;
      }

      // Detecta número de parágrafo inicial (ex: "2 Estamos felizes...")
      final leadingPar = RegExp(r'^(\d{1,3})\s+(?=[A-ZÁÀÂÃÉÊÍÓÔÕÚÜÇ“"\(\[])')
          .firstMatch(text);
      int? parNum;
      if (leadingPar != null) {
        final parsed = int.tryParse(leadingPar.group(1)!);
        if (parsed != null &&
            parsed > 0 &&
            parsed <= 250 &&
            lower != normalizedChapter) {
          parNum = parsed;
        }
      }

      items.add(
        ImportedPublicationParagraph(
          number: parNum,
          heading: activeHeading,
          text: text,
        ),
      );
    }
    return _applyNumberedSectionFallback(items);
  }

  /// Quando o capítulo não usa números explícitos de parágrafo (`data-pnum`),
  /// atribui o número dos subtítulos de ponto (`1. ...`, `2. ...`) aos parágrafos
  /// correspondentes (estilo *Seja Feliz Para Sempre!* / LFF).
  static List<ImportedPublicationParagraph> _applyNumberedSectionFallback(
    List<ImportedPublicationParagraph> items,
  ) {
    if (items.isEmpty || items.any((p) => p.number != null)) {
      return items;
    }
    final pointRe = RegExp(r'^(\d{1,3})\.\s+\S');
    return items.map((p) {
      if (p.isHeadingOnly || p.heading == null) return p;
      final match = pointRe.firstMatch(p.heading!.trim());
      if (match == null) return p;
      final n = int.tryParse(match.group(1)!);
      if (n == null || n <= 0 || n > 200) return p;
      return ImportedPublicationParagraph(
        number: n,
        heading: p.heading,
        text: p.text,
      );
    }).toList();
  }

  /// Seleciona os parágrafos de um capítulo de acordo com [paragraphSpec] (`"1"`, `"3-5"`, `"1, 4-6"`).
  static List<ImportedPublicationParagraph> selectParagraphs(
    ImportedPublicationChapterContent chapter, {
    String? paragraphSpec,
  }) {
    final items = chapter.resolvedParagraphs;
    final requested = parseParagraphNumbers(paragraphSpec);
    if (requested.isEmpty) return items;

    final requestedSet = requested.toSet();
    final hasExplicitNumbers = items.any((p) => p.number != null);
    if (hasExplicitNumbers) {
      final matched = items
          .where((p) => p.number != null && requestedSet.contains(p.number))
          .toList();
      if (matched.isNotEmpty) return matched;
    }

    // Fallback para publicações sem parNum (ex: Lições lff com pontos 1., 2., ou blocos)
    final pointBuckets = <int, List<ImportedPublicationParagraph>>{};
    var fallbackIdx = 0;
    for (final item in items) {
      final pointMatch = RegExp(r'^(\d{1,2})\.\s+\S')
          .firstMatch((item.heading ?? item.text).trim());
      if (pointMatch != null) {
        final pt = int.tryParse(pointMatch.group(1)!);
        if (pt != null && pt > 0) {
          pointBuckets.putIfAbsent(pt, () => []).add(item);
        }
      }
    }
    if (pointBuckets.isNotEmpty) {
      final out = <ImportedPublicationParagraph>[];
      for (final num in requested) {
        final bucket = pointBuckets[num];
        if (bucket != null) {
          for (final item in bucket) {
            if (!out.contains(item)) out.add(item);
          }
        }
      }
      if (out.isNotEmpty) return out;
    }

    final bodyOnly = items.where((p) => !p.isHeadingOnly).toList();
    final out = <ImportedPublicationParagraph>[];
    for (final item in bodyOnly) {
      fallbackIdx++;
      if (requestedSet.contains(fallbackIdx)) {
        out.add(item);
      }
    }
    return out;
  }

  /// Formata trecho de publicação em citação Markdown limpa pronta para leitura ou impressão.
  static String formatChapterTranscript({
    required ImportedPublicationSummary publication,
    required ImportedPublicationChapterContent chapter,
    String? paragraphSpec,
    int maxChars = 3600,
  }) {
    final selected = selectParagraphs(chapter, paragraphSpec: paragraphSpec);
    final list = selected.isNotEmpty ? selected : chapter.resolvedParagraphs;
    if (list.isEmpty) return '';

    final specClean = paragraphSpec?.trim();
    final headerSuffix = (specClean != null && specClean.isNotEmpty)
        ? ' (§/$specClean)'
        : '';
    final lines = <String>[
      '> 📚 **${publication.title} — ${chapter.title}$headerSuffix**',
    ];
    var totalLen = lines.first.length;
    String? lastHeading;
    for (final p in list) {
      final txt = p.text.trim();
      if (txt.isEmpty) continue;
      if (p.heading != null &&
          p.heading!.isNotEmpty &&
          p.heading != lastHeading &&
          p.heading != txt) {
        lines.add('> _${p.heading}_');
        lastHeading = p.heading;
      }
      final prefix =
          (p.number != null &&
              !txt.startsWith('${p.number} ') &&
              !txt.startsWith('${p.number}\u00A0'))
          ? '${p.number}. '
          : '';
      final lineText = '> $prefix$txt';
      if (totalLen + lineText.length > maxChars && lines.length > 1) {
        lines.add('> *(trecho resumido para manter a nota leve)*');
        break;
      }
      lines.add(lineText);
      totalLen += lineText.length;
    }
    return lines.join('\n');
  }

  /// Corrige automaticamente capítulos já salvos com título puramente numérico (ex: "11")
  /// derivando o nome legível a partir dos cabeçalhos armazenados no banco local.
  static Future<ImportedPublicationSummary?> repairNumericChapterTitlesIfNeeded(
    AppDatabase db,
    String publicationId,
  ) async {
    final summary = await getPublication(db, publicationId);
    if (summary == null) return null;
    final hasBroken = summary.chapters.any((c) => isNumericOnlyLabel(c.title));
    if (!hasBroken) return summary;

    var changed = false;
    final updatedMetas = <ImportedPublicationChapterMeta>[];
    for (final ch in summary.chapters) {
      if (!isNumericOnlyLabel(ch.title)) {
        updatedMetas.add(ch);
        continue;
      }
      final content = await loadChapter(
        db,
        publicationId: publicationId,
        chapterIndex: ch.index,
      );
      if (content == null || content.paragraphs.isEmpty) {
        updatedMetas.add(ch);
        continue;
      }
      final p0 = content.paragraphs.first.trim();
      final p1 = content.paragraphs.length > 1
          ? content.paragraphs[1].trim()
          : '';
      String rebuilt = ch.title;
      if (p0.isNotEmpty &&
          p0.length <= 45 &&
          p1.isNotEmpty &&
          p1.length <= 95 &&
          !RegExp(r'^\d+\s').hasMatch(p1)) {
        rebuilt = '$p0 — $p1';
      } else if (p0.isNotEmpty && p0.length <= 95) {
        rebuilt = p0;
      } else if (p0.isNotEmpty) {
        rebuilt = '${p0.substring(0, 72).trimRight()}…';
      }
      if (rebuilt != ch.title && !isNumericOnlyLabel(rebuilt)) {
        changed = true;
        updatedMetas.add(
          ImportedPublicationChapterMeta(
            index: ch.index,
            title: rebuilt,
            href: ch.href,
          ),
        );
        await _putKv(
          db,
          chapterKvKey(publicationId, ch.index),
          jsonEncode({
            'title': rebuilt,
            'paragraphs': content.paragraphs,
            if (content.paragraphItems.isNotEmpty)
              'paragraphItems': content.paragraphItems
                  .map((p) => p.toJson())
                  .toList(),
          }),
        );
      } else {
        updatedMetas.add(ch);
      }
    }

    if (!changed) return summary;
    final updatedSummary = ImportedPublicationSummary(
      id: summary.id,
      title: summary.title,
      language: summary.language,
      sourceFormat: summary.sourceFormat,
      importedAt: summary.importedAt,
      chapterCount: updatedMetas.length,
      coverBase64: summary.coverBase64,
      chapters: updatedMetas,
    );
    final all = await listPublications(db);
    final nextCatalog = all
        .map((p) => p.id == publicationId ? updatedSummary : p)
        .toList();
    await _putKv(
      db,
      catalogKvKey,
      jsonEncode(nextCatalog.map((e) => e.toJson()).toList()),
    );
    return updatedSummary;
  }

  static ({
    String title,
    List<String> paragraphs,
    List<ImportedPublicationParagraph> paragraphItems,
  })?
  _extractChapterFromXhtml(
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
    final sanitizedHint =
        (tocTitleHint != null &&
            tocTitleHint.trim().isNotEmpty &&
            !isNumericOnlyLabel(tocTitleHint))
        ? _normalizeWhitespace(tocTitleHint)
        : null;

    String? contextTtlText;
    for (final p in doc.findAllElements('p')) {
      final cls = (p.getAttribute('class') ?? '').toLowerCase();
      if (cls.contains('contextttl')) {
        final t = _normalizeWhitespace(p.innerText);
        if (t.isNotEmpty) {
          contextTtlText = t;
          break;
        }
      }
    }

    String? h1Text;
    final h1El = doc.findAllElements('h1').firstOrNull;
    if (h1El != null) {
      final t = _normalizeWhitespace(h1El.innerText);
      if (t.isNotEmpty) h1Text = t;
    }

    String? detectedTitle = sanitizedHint;
    if (detectedTitle == null || detectedTitle.isEmpty) {
      if (contextTtlText != null &&
          h1Text != null &&
          !h1Text.toLowerCase().contains(contextTtlText.toLowerCase()) &&
          !contextTtlText.toLowerCase().contains(h1Text.toLowerCase())) {
        detectedTitle = '$contextTtlText — $h1Text';
      } else {
        detectedTitle = h1Text ?? contextTtlText;
      }
    }
    if (detectedTitle == null || detectedTitle.isEmpty) {
      for (final tag in const ['h2', 'title']) {
        final el = doc.findAllElements(tag).firstOrNull;
        if (el != null) {
          final t = _normalizeWhitespace(el.innerText);
          if (t.isNotEmpty && !isNumericOnlyLabel(t)) {
            detectedTitle = t;
            break;
          }
        }
      }
    }

    final paragraphs = <String>[];
    final paragraphItems = <ImportedPublicationParagraph>[];
    final seen = <String>{};
    String? activeHeading;

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

      int? explicitParNum;
      for (final desc in el.descendants.whereType<XmlElement>()) {
        final pnumAttr = desc.getAttribute('data-pnum');
        if (pnumAttr != null && pnumAttr.trim().isNotEmpty) {
          explicitParNum = int.tryParse(pnumAttr.trim());
          if (explicitParNum != null) break;
        }
        final dCls = (desc.getAttribute('class') ?? '').toLowerCase();
        if (dCls.contains('parnum')) {
          final parsed = int.tryParse(_normalizeWhitespace(desc.innerText));
          if (parsed != null && parsed > 0) {
            explicitParNum = parsed;
            break;
          }
        }
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
      if (tag == 'h2' || tag == 'h3') {
        activeHeading = text;
      }
      if (seen.add(text) || paragraphs.isEmpty || paragraphs.last != text) {
        paragraphs.add(text);
        paragraphItems.add(
          ImportedPublicationParagraph(
            number: explicitParNum,
            heading: (tag == 'h2' || tag == 'h3') ? text : activeHeading,
            text: text,
          ),
        );
      }
    }

    if (paragraphs.isEmpty) return null;
    return (
      title: (detectedTitle != null && detectedTitle.isNotEmpty)
          ? detectedTitle
          : fallbackTitle,
      paragraphs: paragraphs,
      paragraphItems: _applyNumberedSectionFallback(paragraphItems),
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

  static bool _isBetterTocLabel(String candidate, String? existing) {
    if (existing == null || existing.trim().isEmpty) return true;
    final candNumeric = isNumericOnlyLabel(candidate);
    final existNumeric = isNumericOnlyLabel(existing);
    if (candNumeric && !existNumeric) return false;
    if (!candNumeric && existNumeric) return true;
    return candidate.length > existing.length;
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
          final hasFragment = src.contains('#');
          final resolved = _resolveZipPath(baseDir, src.split('#').first);
          final cleanLabel = _normalizeWhitespace(label);
          if (cleanLabel.isEmpty) continue;
          if (hasFragment && outLabels.containsKey(resolved)) continue;
          if (_isBetterTocLabel(cleanLabel, outLabels[resolved]) ||
              (!hasFragment && isNumericOnlyLabel(outLabels[resolved]))) {
            outLabels[resolved] = cleanLabel;
          }
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
        // Ignora blocos de paginação (page-list / landmarks) que sobrescrevem títulos com números de página
        var skipNav = false;
        XmlNode? parent = a.parent;
        while (parent is XmlElement) {
          if (parent.name.local.toLowerCase() == 'nav') {
            final epubType = parent.attributes
                .where((attr) => attr.name.local.toLowerCase() == 'type')
                .map((attr) => attr.value.toLowerCase())
                .join(' ');
            final navClass = (parent.getAttribute('class') ?? '').toLowerCase();
            if (epubType.contains('page-list') ||
                epubType.contains('landmarks') ||
                navClass.contains('page')) {
              skipNav = true;
            }
            break;
          }
          parent = parent.parent;
        }
        if (skipNav) continue;

        final href = a.getAttribute('href');
        final label = _normalizeWhitespace(a.innerText);
        if (href == null || href.isEmpty || label.isEmpty) continue;

        final hashIdx = href.indexOf('#');
        final fragment = hashIdx >= 0 ? href.substring(hashIdx + 1) : '';
        // Nunca sobrescreve título de capítulo com links de âncora de página (#page11) ou rótulo só numérico
        if (fragment.toLowerCase().startsWith('page') ||
            isNumericOnlyLabel(label)) {
          continue;
        }

        final resolved = _resolveZipPath(baseDir, href.split('#').first);
        if (_isBetterTocLabel(label, outLabels[resolved])) {
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
