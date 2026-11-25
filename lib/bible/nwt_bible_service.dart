import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' as drift;
import 'package:xml/xml.dart';

import '../core/app_logger.dart';
import '../database/app_database.dart';
import 'nwt_bible_books.dart';

/// Erro controlado de importação local da Bíblia Tradução do Novo Mundo (TNM).
class BibleImportException implements Exception {
  final String message;

  const BibleImportException(this.message);

  @override
  String toString() => message;
}

/// Versículo individual retornado pelo leitor offline da TNM.
class BibleVerseEntry {
  final int number;
  final String text;
  final bool isManualOverride;
  final String? highlightedMarkup;

  const BibleVerseEntry({
    required this.number,
    required this.text,
    this.isManualOverride = false,
    this.highlightedMarkup,
  });

  String get displayMarkup =>
      (highlightedMarkup != null && highlightedMarkup!.isNotEmpty)
      ? highlightedMarkup!
      : text;
}

/// Resumo leve do acervo bíblico importado armazenado localmente.
class BibleNwtCatalog {
  final String title;
  final String language;
  final String sourceFormat; // 'epub', 'json', 'manual'
  final DateTime importedAt;
  final int bookCount;
  final int chapterCount;
  final int verseCount;
  final Map<int, int> chaptersByBook;

  const BibleNwtCatalog({
    required this.title,
    required this.language,
    required this.sourceFormat,
    required this.importedAt,
    required this.bookCount,
    required this.chapterCount,
    required this.verseCount,
    required this.chaptersByBook,
  });

  bool get hasFullLibrary => bookCount > 0 && verseCount > 0;

  Map<String, dynamic> toJson() => {
    'title': title,
    'language': language,
    'sourceFormat': sourceFormat,
    'importedAt': importedAt.toUtc().toIso8601String(),
    'bookCount': bookCount,
    'chapterCount': chapterCount,
    'verseCount': verseCount,
    'chaptersByBook': {
      for (final e in chaptersByBook.entries) '${e.key}': e.value,
    },
  };

  factory BibleNwtCatalog.fromJson(Map<String, dynamic> json) {
    final rawMap = json['chaptersByBook'];
    final map = <int, int>{};
    if (rawMap is Map) {
      for (final entry in rawMap.entries) {
        final k = int.tryParse(entry.key.toString());
        final v = entry.value is int
            ? entry.value as int
            : int.tryParse(entry.value.toString());
        if (k != null && v != null) {
          map[k] = v;
        }
      }
    }
    return BibleNwtCatalog(
      title:
          json['title']?.toString() ??
          'Bíblia Sagrada (Tradução do Novo Mundo)',
      language: json['language']?.toString() ?? 'pt',
      sourceFormat: json['sourceFormat']?.toString() ?? 'epub',
      importedAt:
          DateTime.tryParse(json['importedAt']?.toString() ?? '') ??
          DateTime.now(),
      bookCount: (json['bookCount'] as num?)?.toInt() ?? map.length,
      chapterCount: (json['chapterCount'] as num?)?.toInt() ?? 0,
      verseCount: (json['verseCount'] as num?)?.toInt() ?? 0,
      chaptersByBook: map,
    );
  }
}

/// Resultado de uma leitura de referência bíblica offline.
class BiblePassageLookupResult {
  final NwtBibleBookInfo book;
  final int chapter;
  final String verseSpec;
  final List<BibleVerseEntry> verses;
  final bool hasImportedBible;

  const BiblePassageLookupResult({
    required this.book,
    required this.chapter,
    required this.verseSpec,
    required this.verses,
    required this.hasImportedBible,
  });

  bool get hasFoundVerses => verses.isNotEmpty;
}

/// Resultado de importação de arquivo EPUB ou JSON da TNM.
class BibleImportResult {
  final BibleNwtCatalog catalog;

  const BibleImportResult(this.catalog);
}

/// Serviço offline-first para importação local pelo usuário (EPUB oficial jw.org ou JSON)
/// e armazenamento sharded por livro em [AppKvStore], preservando fluidez na Web/Mobile.
class NwtBibleService {
  NwtBibleService._();

  static const String catalogKvKey = 'bible_nwt_catalog_v1';
  static const String manualKvKey = 'bible_nwt_manual_v1';
  static const String highlightsKvKey = 'bible_nwt_highlights_v1';
  static String bookKvKey(int bookNumber) => 'bible_nwt_book_$bookNumber';
  static String _verseHighlightKey(int bookNumber, int chapter, int verse) =>
      '$bookNumber:$chapter:$verse';

  static String _stripHighlightTags(String raw) => raw.replaceAll(
    RegExp(r'</?(?:u|mark)(?:\s+[^>]*)?>', caseSensitive: false),
    '',
  );

  /// Interpreta especificações como "16", "16-18", "6,7", "6, 7-9".
  static List<int> parseVerseNumbers(String? spec) {
    if (spec == null || spec.trim().isEmpty) return const [];
    final normalized = spec.replaceAll(RegExp(r'\s+'), '');
    final out = <int>[];
    final seen = <int>{};
    for (final part in normalized.split(',')) {
      if (part.isEmpty) continue;
      if (part.contains('-')) {
        final bounds = part.split('-');
        if (bounds.length == 2) {
          final start = int.tryParse(bounds[0]);
          final end = int.tryParse(bounds[1]);
          if (start != null && end != null && start >= 1 && end >= start) {
            final safeEnd = end - start > 200 ? start + 200 : end;
            for (var v = start; v <= safeEnd; v++) {
              if (seen.add(v)) out.add(v);
            }
          }
        }
      } else {
        final single = int.tryParse(part);
        if (single != null && single >= 1 && seen.add(single)) {
          out.add(single);
        }
      }
    }
    return out;
  }

  /// Lê o catálogo resumido da Bíblia importada localmente.
  static Future<BibleNwtCatalog?> loadCatalog(AppDatabase db) async {
    final row = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.equals(catalogKvKey))).getSingleOrNull();
    if (row == null || row.value.isEmpty) return null;
    try {
      final decoded = jsonDecode(row.value);
      if (decoded is Map) {
        return BibleNwtCatalog.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (e, st) {
      AppLogger.warning('Falha ao ler catálogo TNM local', e, st);
    }
    return null;
  }

  /// Remove os dados locais importados (preserva anotações manuais caso [includeManual] seja falso).
  static Future<void> clearImportedBible(
    AppDatabase db, {
    bool includeManual = false,
  }) async {
    await db.transaction(() async {
      await (db.delete(
        db.appKvStore,
      )..where((t) => t.key.equals(catalogKvKey))).go();
      await (db.delete(
        db.appKvStore,
      )..where((t) => t.key.like('bible_nwt_book_%'))).go();
      if (includeManual) {
        await (db.delete(
          db.appKvStore,
        )..where((t) => t.key.equals(manualKvKey))).go();
      }
    });
  }

  /// Salva ou remove marcações coloridas (JW Library) de um versículo separadamente em [AppKvStore].
  static Future<void> saveVerseHighlightMarkup(
    AppDatabase db, {
    required int bookNumber,
    required int chapter,
    required int verse,
    required String? markedText,
  }) async {
    final store = await _loadHighlightStore(db);
    final key = _verseHighlightKey(bookNumber, chapter, verse);
    final hasTags =
        markedText != null &&
        RegExp(
          r'<(?:u|mark)(?:\s+[^>]*)?>',
          caseSensitive: false,
        ).hasMatch(markedText);
    if (!hasTags) {
      store.remove(key);
    } else {
      store[key] = markedText;
    }
    await _putKv(db, highlightsKvKey, jsonEncode(store));
  }

  static Future<Map<String, dynamic>> _loadHighlightStore(
    AppDatabase db,
  ) async {
    final row = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.equals(highlightsKvKey))).getSingleOrNull();
    if (row == null || row.value.isEmpty) return {};
    try {
      final decoded = jsonDecode(row.value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e, st) {
      AppLogger.warning('Falha ao ler destaques bíblicos locais', e, st);
    }
    return {};
  }

  /// Salva ou atualiza versículos manuais para acesso offline imediato.
  static Future<void> saveManualVerse(
    AppDatabase db, {
    required int bookNumber,
    required int chapter,
    required int verse,
    required String text,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    final map = await _loadManualStore(db);
    final bookKey = '$bookNumber';
    final chapKey = '$chapter';
    final bookMap = Map<String, dynamic>.from(
      (map[bookKey] as Map?) ?? const {},
    );
    final chapMap = Map<String, dynamic>.from(
      (bookMap[chapKey] as Map?) ?? const {},
    );
    chapMap['$verse'] = clean;
    bookMap[chapKey] = chapMap;
    map[bookKey] = bookMap;

    await _putKv(db, manualKvKey, jsonEncode(map));
  }

  /// Consulta versículos de um livro/capítulo combinando acervo importado e entradas manuais.
  static Future<BiblePassageLookupResult> lookupPassage(
    AppDatabase db, {
    required int bookNumber,
    required int chapter,
    String? verseSpec,
  }) async {
    final book =
        NwtBibleBooks.byNumber(bookNumber) ??
        const NwtBibleBookInfo(
          number: 1,
          namePt: 'Bíblia',
          nameEn: 'Bible',
          code: 'BIB',
          chapterCount: 1,
        );
    final catalog = await loadCatalog(db);
    final importedChapter = await _loadImportedChapter(
      db,
      bookNumber: bookNumber,
      chapter: chapter,
    );
    final manualChapter = await _loadManualChapter(
      db,
      bookNumber: bookNumber,
      chapter: chapter,
    );
    final highlights = await _loadHighlightStore(db);

    final merged = <int, BibleVerseEntry>{};
    for (final e in importedChapter.entries) {
      merged[e.key] = BibleVerseEntry(number: e.key, text: e.value);
    }
    for (final e in manualChapter.entries) {
      merged[e.key] = BibleVerseEntry(
        number: e.key,
        text: e.value,
        isManualOverride: true,
      );
    }

    for (final vNum in merged.keys.toList()) {
      final base = merged[vNum]!;
      final savedMarkup =
          highlights[_verseHighlightKey(bookNumber, chapter, vNum)]?.toString();
      if (savedMarkup != null &&
          savedMarkup.isNotEmpty &&
          _stripHighlightTags(savedMarkup).trim() == base.text.trim()) {
        merged[vNum] = BibleVerseEntry(
          number: base.number,
          text: base.text,
          isManualOverride: base.isManualOverride,
          highlightedMarkup: savedMarkup,
        );
      }
    }

    final requested = parseVerseNumbers(verseSpec);
    final result = <BibleVerseEntry>[];
    if (requested.isEmpty) {
      final keys = merged.keys.toList()..sort();
      for (final k in keys) {
        result.add(merged[k]!);
      }
    } else {
      for (final num in requested) {
        final found = merged[num];
        if (found != null) result.add(found);
      }
    }

    return BiblePassageLookupResult(
      book: book,
      chapter: chapter,
      verseSpec: verseSpec?.trim() ?? '',
      verses: result,
      hasImportedBible: catalog?.hasFullLibrary ?? false,
    );
  }

  /// Importa arquivo `.epub` (baixado pelo usuário no jw.org) ou `.json` estruturado.
  static Future<BibleImportResult> importFromBytes(
    AppDatabase db, {
    required Uint8List bytes,
    required String fileName,
    void Function(int processed, int total)? onProgress,
  }) async {
    if (bytes.isEmpty) {
      throw const BibleImportException('O arquivo selecionado está vazio.');
    }

    final lowerName = fileName.toLowerCase().trim();
    if (lowerName.endsWith('.jwpub')) {
      throw const BibleImportException(
        'Arquivos .jwpub utilizam banco interno criptografado exclusivo do JW Library.\n'
        'Para leitura offline aqui no app, baixe no site jw.org a edição oficial em formato .epub '
        '(ou importe um arquivo .json próprio).',
      );
    }

    if (lowerName.endsWith('.json')) {
      return _importJsonBytes(db, bytes, onProgress: onProgress);
    }

    // Trata como EPUB (ZIP + OPF + XHTML) ou detecta JWPUB disfarçado
    return _importEpubBytes(db, bytes, fileName, onProgress: onProgress);
  }

  static Future<BibleImportResult> _importJsonBytes(
    AppDatabase db,
    Uint8List bytes, {
    void Function(int processed, int total)? onProgress,
  }) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (e) {
      throw BibleImportException('JSON bíblico inválido: $e');
    }

    final parsedBooks = <int, Map<int, Map<int, String>>>{};
    var title = 'Tradução do Novo Mundo (JSON)';
    var language = 'pt';

    if (decoded is Map) {
      if (decoded['title'] != null) title = decoded['title'].toString();
      if (decoded['language'] != null) {
        language = decoded['language'].toString();
      }
      final rawBooks = decoded['books'] ?? decoded;
      if (rawBooks is Map) {
        for (final bookEntry in rawBooks.entries) {
          final info = NwtBibleBooks.findByQuery(bookEntry.key.toString());
          if (info == null) continue;
          final rawBookVal = bookEntry.value;
          final chaptersSource =
              rawBookVal is Map && rawBookVal['chapters'] is Map
              ? rawBookVal['chapters'] as Map
              : (rawBookVal is Map ? rawBookVal : null);
          if (chaptersSource == null) continue;

          final chapMap = parsedBooks.putIfAbsent(info.number, () => {});
          for (final chEntry in chaptersSource.entries) {
            final chNum = int.tryParse(chEntry.key.toString());
            if (chNum == null || chNum < 1 || chEntry.value is! Map) continue;
            final verseMap = chapMap.putIfAbsent(chNum, () => {});
            for (final vEntry in (chEntry.value as Map).entries) {
              final vNum = int.tryParse(vEntry.key.toString());
              final vText = vEntry.value?.toString().trim() ?? '';
              if (vNum != null && vNum >= 1 && vText.isNotEmpty) {
                verseMap[vNum] = vText;
              }
            }
          }
        }
      } else if (rawBooks is List) {
        for (final item in rawBooks) {
          if (item is! Map) continue;
          final info = NwtBibleBooks.findByQuery(
            (item['book'] ?? item['bookNumber'] ?? item['name'] ?? '')
                .toString(),
          );
          final ch = (item['chapter'] as num?)?.toInt();
          final v = (item['verse'] as num?)?.toInt();
          final text = item['text']?.toString().trim() ?? '';
          if (info != null && ch != null && v != null && text.isNotEmpty) {
            parsedBooks
                    .putIfAbsent(info.number, () => {})
                    .putIfAbsent(ch, () => {})[v] =
                text;
          }
        }
      }
    } else if (decoded is List) {
      for (final item in decoded) {
        if (item is! Map) continue;
        final info = NwtBibleBooks.findByQuery(
          (item['book'] ?? item['bookNumber'] ?? item['name'] ?? '').toString(),
        );
        final ch = (item['chapter'] as num?)?.toInt();
        final v = (item['verse'] as num?)?.toInt();
        final text = item['text']?.toString().trim() ?? '';
        if (info != null && ch != null && v != null && text.isNotEmpty) {
          parsedBooks
                  .putIfAbsent(info.number, () => {})
                  .putIfAbsent(ch, () => {})[v] =
              text;
        }
      }
    }

    if (parsedBooks.isEmpty) {
      throw const BibleImportException(
        'Nenhum livro ou versículo reconhecido no JSON selecionado.',
      );
    }

    return _persistParsedBible(
      db,
      parsedBooks: parsedBooks,
      title: title,
      language: language,
      sourceFormat: 'json',
      onProgress: onProgress,
    );
  }

  static Future<BibleImportResult> _importEpubBytes(
    AppDatabase db,
    Uint8List bytes,
    String fileName, {
    void Function(int processed, int total)? onProgress,
  }) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw BibleImportException(
        'Não foi possível abrir o arquivo "$fileName" como EPUB/ZIP válido: $e',
      );
    }

    final filesByPath = <String, ArchiveFile>{};
    for (final f in archive.files) {
      if (f.isFile) {
        filesByPath[_normalizeZipPath(f.name)] = f;
      }
    }

    if (filesByPath.containsKey('manifest.json') &&
        filesByPath.keys.any((k) => k.endsWith('.db'))) {
      throw const BibleImportException(
        'Este arquivo é um pacote .jwpub com banco criptografado do JW Library.\n'
        'Por favor, baixe no site jw.org a edição oficial em formato .epub.',
      );
    }

    final opfPath = _findOpfPath(filesByPath);
    if (opfPath == null) {
      throw const BibleImportException(
        'Arquivo EPUB inválido: documento package/content .opf não encontrado.',
      );
    }

    final opfFile = filesByPath[opfPath];
    if (opfFile == null) {
      throw const BibleImportException('Arquivo .opf não encontrado no EPUB.');
    }

    final opfXml = XmlDocument.parse(_decodeFileUtf8(opfFile));
    final opfDir = _dirname(opfPath);

    final title =
        opfXml.findAllElements('dc:title').firstOrNull?.innerText.trim() ??
        opfXml.findAllElements('title').firstOrNull?.innerText.trim() ??
        'Tradução do Novo Mundo (EPUB)';
    final language =
        opfXml.findAllElements('dc:language').firstOrNull?.innerText.trim() ??
        'pt';

    // Mapeia ID -> href e verifica arquivo de navegação (ncx / nav)
    final manifestHrefById = <String, String>{};
    final manifestMediaById = <String, String>{};
    String? ncxPath;
    String? navXhtmlPath;

    for (final item in opfXml.findAllElements('item')) {
      final id = item.getAttribute('id') ?? '';
      final href = item.getAttribute('href') ?? '';
      final mediaType = item.getAttribute('media-type') ?? '';
      final properties = item.getAttribute('properties') ?? '';
      if (id.isNotEmpty && href.isNotEmpty) {
        final resolved = _resolveZipPath(opfDir, href);
        manifestHrefById[id] = resolved;
        manifestMediaById[id] = mediaType;
        if (mediaType.contains('dtbncx') ||
            resolved.toLowerCase().endsWith('.ncx')) {
          ncxPath ??= resolved;
        }
        if (properties.split(' ').contains('nav')) {
          navXhtmlPath ??= resolved;
        }
      }
    }

    final tocLabelsByHref = <String, String>{};
    if (ncxPath != null && filesByPath.containsKey(ncxPath)) {
      _extractNcxLabels(
        filesByPath[ncxPath]!,
        _dirname(ncxPath),
        tocLabelsByHref,
      );
    }
    if (navXhtmlPath != null && filesByPath.containsKey(navXhtmlPath)) {
      _extractNavXhtmlLabels(
        filesByPath[navXhtmlPath]!,
        _dirname(navXhtmlPath),
        tocLabelsByHref,
      );
    }

    final spinePaths = <String>[];
    for (final itemref in opfXml.findAllElements('itemref')) {
      final idref = itemref.getAttribute('idref');
      if (idref != null && manifestHrefById.containsKey(idref)) {
        final path = manifestHrefById[idref]!;
        final media = manifestMediaById[idref] ?? '';
        if (media.isEmpty ||
            media.contains('html') ||
            path.endsWith('.xhtml') ||
            path.endsWith('.html')) {
          spinePaths.add(path);
        }
      }
    }

    if (spinePaths.isEmpty) {
      spinePaths.addAll(
        filesByPath.keys.where(
          (k) => k.endsWith('.xhtml') || k.endsWith('.html'),
        ),
      );
    }

    final parsedBooks = <int, Map<int, Map<int, String>>>{};
    final total = spinePaths.length;
    for (var idx = 0; idx < total; idx++) {
      final path = spinePaths[idx];
      final archiveFile = filesByPath[path];
      if (archiveFile == null) continue;

      final lowerPath = path.toLowerCase();
      final isNonChapterNavOrExtract =
          lowerPath.contains('-extracted') ||
          RegExp(r'(?:^|/)bible(?:book|chapter|verse)nav')
              .hasMatch(lowerPath) ||
          RegExp(r'(?:^|/)(?:toc|nav|cover|pagenav)\.xhtml$')
              .hasMatch(lowerPath);
      if (isNonChapterNavOrExtract) {
        if (idx % 60 == 0) {
          onProgress?.call(idx + 1, total);
          await Future<void>.delayed(Duration.zero);
        }
        continue;
      }

      final tocHint = tocLabelsByHref[path];
      final xhtmlContent = _decodeFileUtf8(archiveFile);
      _extractBibleFromXhtml(
        xhtmlContent,
        filePath: path,
        tocTitleHint: tocHint,
        outBooks: parsedBooks,
      );

      if (idx % 12 == 0) {
        onProgress?.call(idx + 1, total);
        await Future<void>.delayed(Duration.zero);
      }
    }
    onProgress?.call(total, total);

    if (parsedBooks.isEmpty) {
      throw const BibleImportException(
        'Não foi possível identificar capítulos/versículos da TNM neste EPUB.\n'
        'Verifique se o arquivo selecionado é a Bíblia Tradução do Novo Mundo completa em .epub.',
      );
    }

    return _persistParsedBible(
      db,
      parsedBooks: parsedBooks,
      title: title,
      language: language,
      sourceFormat: 'epub',
      onProgress: onProgress,
    );
  }

  static Future<BibleImportResult> _persistParsedBible(
    AppDatabase db, {
    required Map<int, Map<int, Map<int, String>>> parsedBooks,
    required String title,
    required String language,
    required String sourceFormat,
    void Function(int processed, int total)? onProgress,
  }) async {
    final chaptersByBook = <int, int>{};
    var totalChapters = 0;
    var totalVerses = 0;

    final sortedBookNums = parsedBooks.keys.toList()..sort();
    await (db.delete(
      db.appKvStore,
    )..where((t) => t.key.like('bible_nwt_book_%'))).go();

    for (var i = 0; i < sortedBookNums.length; i++) {
      final bookNum = sortedBookNums[i];
      final chapters = parsedBooks[bookNum]!;
      chaptersByBook[bookNum] = chapters.length;
      totalChapters += chapters.length;

      final encodedChapters = <String, Map<String, String>>{};
      for (final chEntry in chapters.entries) {
        totalVerses += chEntry.value.length;
        encodedChapters['${chEntry.key}'] = {
          for (final vEntry in chEntry.value.entries)
            '${vEntry.key}': vEntry.value,
        };
      }

      await _putKv(db, bookKvKey(bookNum), jsonEncode(encodedChapters));
      if (i % 6 == 0) {
        onProgress?.call(i + 1, sortedBookNums.length);
        await Future<void>.delayed(Duration.zero);
      }
    }

    final catalog = BibleNwtCatalog(
      title: title,
      language: language,
      sourceFormat: sourceFormat,
      importedAt: DateTime.now(),
      bookCount: parsedBooks.length,
      chapterCount: totalChapters,
      verseCount: totalVerses,
      chaptersByBook: chaptersByBook,
    );
    await _putKv(db, catalogKvKey, jsonEncode(catalog.toJson()));
    return BibleImportResult(catalog);
  }

  static void _extractBibleFromXhtml(
    String xhtml, {
    required String filePath,
    String? tocTitleHint,
    required Map<int, Map<int, Map<int, String>>> outBooks,
  }) {
    if (xhtml.trim().isEmpty) return;

    XmlDocument? doc;
    try {
      doc = XmlDocument.parse(xhtml);
    } catch (_) {
      doc = null;
    }

    if (doc != null) {
      if (_isNonBibleNavigationOrExtractDocument(doc)) {
        return;
      }
    }

    var detectedBook = _inferBookNumber(
      doc: doc,
      filePath: filePath,
      tocTitleHint: tocTitleHint,
    );
    var detectedChapter = _inferChapterNumber(
      doc: doc,
      filePath: filePath,
      tocTitleHint: tocTitleHint,
    );
    if (detectedBook != null &&
        detectedChapter == null &&
        NwtBibleBooks.byNumber(detectedBook)?.chapterCount == 1) {
      detectedChapter = 1;
    }

    if (doc != null) {
      final body = doc.findAllElements('body').firstOrNull ?? doc.rootElement;
      final hasChapterVerseMarkers = body.descendants
          .whereType<XmlElement>()
          .any(
            (el) => RegExp(
              r'^chapter\d+_verse\d+$',
              caseSensitive: false,
            ).hasMatch(el.getAttribute('id') ?? ''),
          );

      if (!hasChapterVerseMarkers) {
        // 1. Padrão EPUB simplificado: <span class="verse"> / id="v43-3-16" / id="v16"
        final versesFound = <int, String>{};
        final verseElements = doc.descendants.whereType<XmlElement>().where((
          el,
        ) {
          final cls = (el.getAttribute('class') ?? '').toLowerCase();
          final id = (el.getAttribute('id') ?? '').toLowerCase();
          return cls.contains('verse') ||
              RegExp(r'^v\d+(-\d+-\d+)?$').hasMatch(id);
        });

        for (final el in verseElements) {
          final id = el.getAttribute('id') ?? '';
          final tripleMatch = RegExp(r'(\d{1,2})[-_](\d{1,3})[-_](\d{1,3})$')
              .firstMatch(id);
          if (tripleMatch != null) {
            detectedBook ??= int.tryParse(tripleMatch.group(1)!);
            detectedChapter ??= int.tryParse(tripleMatch.group(2)!);
            final vNum = int.tryParse(tripleMatch.group(3)!);
            if (vNum != null) {
              final text = _cleanVerseElementText(el, vNum);
              if (text.isNotEmpty) {
                versesFound[vNum] = _appendText(versesFound[vNum], text);
              }
            }
            continue;
          }

          final supNum = _extractSupNumber(el);
          final idNumMatch = RegExp(r'(\d{1,3})$').firstMatch(id);
          final vNum =
              supNum ??
              (idNumMatch != null ? int.tryParse(idNumMatch.group(1)!) : null);
          if (vNum != null && vNum >= 1 && vNum <= 176) {
            final text = _cleanVerseElementText(el, vNum);
            if (text.isNotEmpty) {
              versesFound[vNum] = _appendText(versesFound[vNum], text);
            }
          }
        }

        if (versesFound.isNotEmpty &&
            detectedBook != null &&
            detectedChapter != null) {
          final bookMap = outBooks.putIfAbsent(detectedBook, () => {});
          final chMap = bookMap.putIfAbsent(detectedChapter, () => {});
          for (final entry in versesFound.entries) {
            chMap[entry.key] = _appendText(chMap[entry.key], entry.value);
          }
          return;
        }
      }

      // 2. Padrão JW EPUB oficial: <span id="chapterX_verseY">, <span class="w_ch">,
      // <strong><sup>N</sup></strong>, parágrafos contínuos (.sb/.sl/.sz) ou <span id="v43003016">
      if (detectedBook != null && detectedChapter != null) {
        final fallbackVerses = _parseParagraphMarkerVerses(body);
        if (fallbackVerses.isNotEmpty) {
          final bookMap = outBooks.putIfAbsent(detectedBook, () => {});
          final chMap = bookMap.putIfAbsent(detectedChapter, () => {});
          for (final entry in fallbackVerses.entries) {
            chMap[entry.key] = _appendText(chMap[entry.key], entry.value);
          }
        }
      }
    }
  }

  static bool _isNonBibleNavigationOrExtractDocument(XmlDocument doc) {
    for (final div in doc.findAllElements('div')) {
      final cls = (div.getAttribute('class') ?? '').toLowerCase();
      final tokens = cls.split(RegExp(r'\s+'));
      if (tokens.contains('groupext')) {
        return true;
      }
    }
    for (final p in doc.findAllElements('p')) {
      final cls = (p.getAttribute('class') ?? '').toLowerCase();
      final tokens = cls.split(RegExp(r'\s+'));
      if (tokens.contains('w_biblebook') ||
          tokens.contains('w_biblechapter') ||
          tokens.contains('w_bibleverse')) {
        return true;
      }
    }
    return false;
  }

  static Map<int, String> _parseParagraphMarkerVerses(XmlElement root) {
    final result = <int, String>{};
    int? currentVerse;
    final buf = StringBuffer();
    var needParagraphSpace = false;

    void flush() {
      if (currentVerse != null) {
        final t = _normalizeWhitespace(
          buf.toString().replaceAll(RegExp(r'[\u00A0\u202F\u200B]'), ' '),
        );
        if (t.isNotEmpty) {
          result[currentVerse!] = _appendText(result[currentVerse!], t);
        }
      }
      buf.clear();
    }

    bool isIgnoredParagraph(XmlElement p) {
      final cls = (p.getAttribute('class') ?? '').toLowerCase();
      final tokens = cls
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .toSet();
      const skipParagraphClasses = <String>{
        'qu',
        'fn',
        'footnote',
        'w_navigation',
        'w_biblebookname',
        'docnav',
        'contextttl',
        'ss',
        'st',
        'sd',
        'sw',
      };
      if (tokens.any(skipParagraphClasses.contains)) {
        return true;
      }
      XmlNode? parent = p.parent;
      while (parent is XmlElement) {
        final pTag = parent.name.local.toLowerCase();
        if (pTag == 'header' ||
            pTag == 'nav' ||
            pTag == 'aside' ||
            pTag == 'figure' ||
            pTag == 'figcaption') {
          return true;
        }
        final pCls = (parent.getAttribute('class') ?? '').toLowerCase();
        if (pCls.contains('groupfootnote') ||
            pCls.contains('groupext') ||
            pCls.contains('footnote') ||
            pCls.contains('docnav')) {
          return true;
        }
        if (parent.attributes.any(
          (a) =>
              a.name.local.toLowerCase() == 'type' &&
              (a.value.toLowerCase() == 'footnote' ||
                  a.value.toLowerCase() == 'noteref'),
        )) {
          return true;
        }
        parent = parent.parent;
      }
      return false;
    }

    for (final p in root.findAllElements('p')) {
      if (isIgnoredParagraph(p)) {
        continue;
      }
      needParagraphSpace = currentVerse != null;

      void walk(XmlNode node) {
        if (node is XmlElement) {
          final tag = node.name.local.toLowerCase();
          if (tag == 'aside' || tag == 'header' || tag == 'nav') {
            return;
          }
          final id = (node.getAttribute('id') ?? '').toLowerCase();
          final elCls = (node.getAttribute('class') ?? '').toLowerCase();
          final elTokens = elCls
              .split(RegExp(r'\s+'))
              .where((t) => t.isNotEmpty)
              .toSet();

          if (elTokens.contains('w_ch') ||
              elTokens.contains('pagenum') ||
              elTokens.contains('fn') ||
              elTokens.contains('footnote') ||
              elTokens.contains('groupfootnote') ||
              node.getAttribute('aria-hidden') == 'true') {
            return;
          }

          if (node.attributes.any(
            (a) =>
                a.name.local.toLowerCase() == 'type' &&
                (a.value.toLowerCase() == 'footnote' ||
                    a.value.toLowerCase() == 'noteref'),
          )) {
            return;
          }

          final chapterVerseMatch = RegExp(
            r'^chapter\d+_verse(\d+)$',
            caseSensitive: false,
          ).firstMatch(id);
          if (chapterVerseMatch != null) {
            final v = int.tryParse(chapterVerseMatch.group(1)!);
            if (v != null && v >= 1 && v <= 176) {
              flush();
              currentVerse = v;
              needParagraphSpace = false;
              result.putIfAbsent(v, () => '');
            }
            for (final child in node.children) {
              walk(child);
            }
            return;
          }

          if (tag == 'sup' ||
              elTokens.contains('versenum') ||
              elTokens.contains('vl') ||
              (elTokens.contains('chapter') && id.startsWith('chapter')) ||
              RegExp(r'^v\d{6,9}$').hasMatch(id)) {
            final numCandidate = int.tryParse(
              node.innerText.replaceAll(RegExp(r'[^0-9]'), ''),
            );
            if (numCandidate != null &&
                numCandidate >= 1 &&
                numCandidate <= 176) {
              flush();
              currentVerse = numCandidate;
              needParagraphSpace = false;
              result.putIfAbsent(numCandidate, () => '');
              return;
            }
          }

          // Ignora marcadores de rodapé/referência cruzada (+, *)
          if (tag == 'a' &&
              (elTokens.contains('fn') ||
                  elTokens.contains('footnote') ||
                  elTokens.contains('noteref') ||
                  (node.getAttribute('href')?.startsWith('#footnote') ??
                      false) ||
                  node.innerText.trim() == '*' ||
                  node.innerText.trim() == '+')) {
            return;
          }

          for (final child in node.children) {
            walk(child);
          }
        } else if (node is XmlText) {
          if (currentVerse != null) {
            final txt = node.value;
            if (needParagraphSpace && txt.trim().isNotEmpty) {
              buf.write(' ');
              needParagraphSpace = false;
            }
            buf.write(txt);
          }
        }
      }

      walk(p);
    }
    flush();
    result.removeWhere((_, v) => v.trim().isEmpty);
    return result;
  }

  static int? _extractSupNumber(XmlElement el) {
    for (final sup in el.findAllElements('sup')) {
      final n = int.tryParse(sup.innerText.replaceAll(RegExp(r'[^0-9]'), ''));
      if (n != null && n >= 1 && n <= 176) return n;
    }
    return null;
  }

  static String _cleanVerseElementText(XmlElement el, int verseNum) {
    final buf = StringBuffer();
    void walk(XmlNode node) {
      if (node is XmlElement) {
        final cls = (node.getAttribute('class') ?? '').toLowerCase();
        if (node.name.local == 'sup' ||
            cls.contains('versenum') ||
            cls.contains('fn') ||
            cls.contains('footnote') ||
            (node.name.local == 'a' &&
                (node.innerText.trim() == '*' ||
                    node.innerText.trim() == '+'))) {
          return;
        }
        for (final child in node.children) {
          walk(child);
        }
      } else if (node is XmlText) {
        buf.write(node.value);
      }
    }

    walk(el);
    var cleaned = _normalizeWhitespace(buf.toString());
    final leadingPrefix = '$verseNum ';
    if (cleaned.startsWith(leadingPrefix)) {
      cleaned = cleaned.substring(leadingPrefix.length).trim();
    }
    return cleaned;
  }

  static int? _inferBookNumber({
    XmlDocument? doc,
    required String filePath,
    String? tocTitleHint,
  }) {
    if (tocTitleHint != null && tocTitleHint.isNotEmpty) {
      final byToc = NwtBibleBooks.findByQuery(tocTitleHint);
      if (byToc != null) return byToc.number;
    }

    final fileBase = filePath.split('/').last;
    final codeMatch = RegExp(
      r'([1-3]?[a-z]{2,4})[-_]?0*(\d{1,3})\.(xhtml|html)$',
      caseSensitive: false,
    ).firstMatch(fileBase);
    if (codeMatch != null) {
      final byCode = NwtBibleBooks.findByQuery(codeMatch.group(1)!);
      if (byCode != null) return byCode.number;
    }

    // Código numérico estilo jwpub/nwt: e.g. 1001061101 -> book 01..66 em alguns nomes
    final nwtCodeMatch = RegExp(
      r'book[_-]?(\d{1,2})',
      caseSensitive: false,
    ).firstMatch(fileBase);
    if (nwtCodeMatch != null) {
      final num = int.tryParse(nwtCodeMatch.group(1)!);
      if (num != null && num >= 1 && num <= 66) return num;
    }

    if (doc != null) {
      for (final p in doc.findAllElements('p')) {
        final cls = (p.getAttribute('class') ?? '').toLowerCase();
        if (cls.contains('w_biblebookname')) {
          final bookLink = p.findElements('a').firstOrNull;
          if (bookLink != null) {
            final found = NwtBibleBooks.findByQuery(bookLink.innerText);
            if (found != null) return found.number;
          }
        }
      }
      for (final tag in const ['title', 'h1', 'h2']) {
        for (final el in doc.findAllElements(tag)) {
          final txt = el.innerText.trim();
          if (txt.toLowerCase().startsWith('textos extraídos:')) continue;
          final found = NwtBibleBooks.findByQuery(txt);
          if (found != null) return found.number;
        }
      }
    }
    return null;
  }

  static int? _inferChapterNumber({
    XmlDocument? doc,
    required String filePath,
    String? tocTitleHint,
  }) {
    if (doc != null) {
      for (final p in doc.findAllElements('p')) {
        final cls = (p.getAttribute('class') ?? '').toLowerCase();
        if (cls.contains('w_biblebookname')) {
          for (final a in p.findElements('a')) {
            final href = (a.getAttribute('href') ?? '').toLowerCase();
            if (href.contains('biblechapternav')) {
              final ch = int.tryParse(a.innerText.trim());
              if (ch != null && ch >= 1 && ch <= 150) return ch;
            }
          }
        }
      }
      for (final el in doc.descendants.whereType<XmlElement>()) {
        final id = (el.getAttribute('id') ?? '').toLowerCase();
        final chMatch = RegExp(r'^chapter(\d+)(?:_verse\d+)?$').firstMatch(id);
        if (chMatch != null) {
          final ch = int.tryParse(chMatch.group(1)!);
          if (ch != null && ch >= 1 && ch <= 150) return ch;
        }
      }
    }

    if (tocTitleHint != null && tocTitleHint.isNotEmpty) {
      final m = RegExp(r'(\d{1,3})\s*$').firstMatch(tocTitleHint.trim());
      if (m != null) {
        final ch = int.tryParse(m.group(1)!);
        if (ch != null && ch >= 1 && ch <= 150) return ch;
      }
    }

    final fileBase = filePath.split('/').last;
    final fileMatch = RegExp(
      r'[_-]0*(\d{1,3})\.(xhtml|html)$',
      caseSensitive: false,
    ).firstMatch(fileBase);
    if (fileMatch != null) {
      final ch = int.tryParse(fileMatch.group(1)!);
      if (ch != null && ch >= 1 && ch <= 150) return ch;
    }

    if (doc != null) {
      for (final tag in const ['h1', 'h2', 'title']) {
        for (final el in doc.findAllElements(tag)) {
          final m = RegExp(r'(\d{1,3})\s*$').firstMatch(el.innerText.trim());
          if (m != null) {
            final ch = int.tryParse(m.group(1)!);
            if (ch != null && ch >= 1 && ch <= 150) return ch;
          }
        }
      }
    }
    return null;
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
          final pathOnly = src.split('#').first;
          final resolved = _resolveZipPath(baseDir, pathOnly);
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

  static String? _findOpfPath(Map<String, ArchiveFile> files) {
    final container =
        files['meta-inf/container.xml'] ?? files['META-INF/container.xml'];
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

  static Future<Map<int, String>> _loadImportedChapter(
    AppDatabase db, {
    required int bookNumber,
    required int chapter,
  }) async {
    final row = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.equals(bookKvKey(bookNumber)))).getSingleOrNull();
    if (row == null || row.value.isEmpty) return const {};
    try {
      final decoded = jsonDecode(row.value);
      if (decoded is Map) {
        final chRaw = decoded['$chapter'];
        if (chRaw is Map) {
          final out = <int, String>{};
          for (final e in chRaw.entries) {
            final v = int.tryParse(e.key.toString());
            if (v != null && e.value != null) {
              out[v] = e.value.toString();
            }
          }
          return out;
        }
      }
    } catch (e, st) {
      AppLogger.warning('Falha ao ler livro bíblico local #$bookNumber', e, st);
    }
    return const {};
  }

  static Future<Map<String, dynamic>> _loadManualStore(AppDatabase db) async {
    final row = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.equals(manualKvKey))).getSingleOrNull();
    if (row == null || row.value.isEmpty) return {};
    try {
      final decoded = jsonDecode(row.value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e, st) {
      AppLogger.warning('Falha ao ler versículos manuais locais', e, st);
    }
    return {};
  }

  static Future<Map<int, String>> _loadManualChapter(
    AppDatabase db, {
    required int bookNumber,
    required int chapter,
  }) async {
    final store = await _loadManualStore(db);
    final bookRaw = store['$bookNumber'];
    if (bookRaw is! Map) return const {};
    final chRaw = bookRaw['$chapter'];
    if (chRaw is! Map) return const {};
    final out = <int, String>{};
    for (final e in chRaw.entries) {
      final v = int.tryParse(e.key.toString());
      if (v != null && e.value != null) {
        out[v] = e.value.toString();
      }
    }
    return out;
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
    return utf8.decode(f.content, allowMalformed: true);
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

  static String _appendText(String? existing, String addition) {
    if (existing == null || existing.isEmpty) return addition;
    if (existing.endsWith(addition)) return existing;
    return '$existing $addition';
  }
}
