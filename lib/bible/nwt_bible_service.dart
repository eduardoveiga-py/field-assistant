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
  final String id;
  final String title;
  final String language;
  final String sourceFormat; // 'epub', 'json', 'manual'
  final DateTime importedAt;
  final int bookCount;
  final int chapterCount;
  final int verseCount;
  final Map<int, int> chaptersByBook;
  final String? coverBase64;
  final bool isPrimary;

  const BibleNwtCatalog({
    this.id = NwtBibleService.defaultTranslationId,
    required this.title,
    required this.language,
    required this.sourceFormat,
    required this.importedAt,
    required this.bookCount,
    required this.chapterCount,
    required this.verseCount,
    required this.chaptersByBook,
    this.coverBase64,
    this.isPrimary = true,
  });

  bool get hasFullLibrary => bookCount > 0 && verseCount > 0;

  String get languageDisplay => NwtBibleBooks.languageDisplayName(language);

  BibleNwtCatalog copyWith({
    String? id,
    String? title,
    String? language,
    String? sourceFormat,
    DateTime? importedAt,
    int? bookCount,
    int? chapterCount,
    int? verseCount,
    Map<int, int>? chaptersByBook,
    String? coverBase64,
    bool? isPrimary,
  }) {
    return BibleNwtCatalog(
      id: id ?? this.id,
      title: title ?? this.title,
      language: language ?? this.language,
      sourceFormat: sourceFormat ?? this.sourceFormat,
      importedAt: importedAt ?? this.importedAt,
      bookCount: bookCount ?? this.bookCount,
      chapterCount: chapterCount ?? this.chapterCount,
      verseCount: verseCount ?? this.verseCount,
      chaptersByBook: chaptersByBook ?? this.chaptersByBook,
      coverBase64: coverBase64 ?? this.coverBase64,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'language': language,
    'sourceFormat': sourceFormat,
    'importedAt': importedAt.toUtc().toIso8601String(),
    'bookCount': bookCount,
    'chapterCount': chapterCount,
    'verseCount': verseCount,
    if (coverBase64 != null && coverBase64!.isNotEmpty)
      'coverBase64': coverBase64,
    'isPrimary': isPrimary,
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
      id: json['id']?.toString().trim().isNotEmpty == true
          ? json['id'].toString().trim()
          : NwtBibleService.defaultTranslationId,
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
      coverBase64: json['coverBase64']?.toString(),
      isPrimary: json['isPrimary'] as bool? ?? true,
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
  final String? translationId;
  final BibleNwtCatalog? catalog;

  const BiblePassageLookupResult({
    required this.book,
    required this.chapter,
    required this.verseSpec,
    required this.verses,
    required this.hasImportedBible,
    this.translationId,
    this.catalog,
  });

  bool get hasFoundVerses => verses.isNotEmpty;
}

/// Passagem resolvida para uma tradução específica no modo de comparação.
class BibleTranslationPassage {
  final String translationId;
  final String title;
  final String language;
  final String languageDisplay;
  final String? coverBase64;
  final bool isManualFallback;
  final BiblePassageLookupResult lookup;

  const BibleTranslationPassage({
    required this.translationId,
    required this.title,
    required this.language,
    required this.languageDisplay,
    this.coverBase64,
    this.isManualFallback = false,
    required this.lookup,
  });
}

/// Resultado de importação de arquivo EPUB ou JSON da TNM.
class BibleImportResult {
  final BibleNwtCatalog catalog;

  const BibleImportResult(this.catalog);
}

/// Serviço offline-first para importação local pelo usuário (EPUB oficial jw.org ou JSON)
/// com suporte a múltiplas traduções/idiomas e armazenamento sharded por livro em [AppKvStore].
class NwtBibleService {
  NwtBibleService._();

  static const String defaultTranslationId = 'default';
  static const String catalogKvKey = 'bible_nwt_catalog_v1';
  static const String translationsCatalogKvKey =
      'bible_translations_catalog_v1';
  static const String selectedCompareIdsKvKey = 'bible_compare_selected_ids_v1';
  static const String manualKvKey = 'bible_nwt_manual_v1';
  static const String highlightsKvKey = 'bible_nwt_highlights_v1';
  static String bookKvKey(int bookNumber) => 'bible_nwt_book_$bookNumber';
  static String translationBookKvKey(String translationId, int bookNumber) =>
      translationId == defaultTranslationId
      ? bookKvKey(bookNumber)
      : 'bible_tr_${translationId}_book_$bookNumber';
  static String translationHighlightsKvKey(String? translationId) =>
      (translationId == null || translationId == defaultTranslationId)
      ? highlightsKvKey
      : 'bible_tr_highlights_$translationId';
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

  /// Lista todas as traduções bíblicas importadas localmente (migrando a legada se houver).
  static Future<List<BibleNwtCatalog>> listTranslations(AppDatabase db) async {
    final row = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.equals(translationsCatalogKvKey))).getSingleOrNull();

    final list = <BibleNwtCatalog>[];
    if (row != null && row.value.isNotEmpty) {
      try {
        final decoded = jsonDecode(row.value);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              list.add(
                BibleNwtCatalog.fromJson(Map<String, dynamic>.from(item)),
              );
            }
          }
        }
      } catch (e, st) {
        AppLogger.warning('Falha ao ler catálogo de traduções bíblicas', e, st);
      }
    }

    final legacy = await _loadLegacyCatalog(db);
    if (legacy != null &&
        legacy.hasFullLibrary &&
        !list.any((c) => c.id == legacy.id)) {
      list.insert(0, legacy.copyWith(isPrimary: list.isEmpty));
    }

    if (list.isNotEmpty && !list.any((c) => c.isPrimary)) {
      list[0] = list[0].copyWith(isPrimary: true);
    }
    list.sort((a, b) {
      if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
      return b.importedAt.compareTo(a.importedAt);
    });
    return list;
  }

  static Future<BibleNwtCatalog?> _loadLegacyCatalog(AppDatabase db) async {
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

  /// Lê o catálogo resumido da Bíblia principal importada localmente.
  static Future<BibleNwtCatalog?> loadCatalog(AppDatabase db) async {
    final list = await listTranslations(db);
    if (list.isNotEmpty) {
      return list.where((c) => c.isPrimary).firstOrNull ?? list.first;
    }
    return _loadLegacyCatalog(db);
  }

  /// Lê a lista de IDs de traduções selecionadas para leitura/comparação no popup.
  static Future<List<String>> loadSelectedComparisonIds(AppDatabase db) async {
    final translations = await listTranslations(db);
    final validIds = translations.map((t) => t.id).toSet();
    final row = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.equals(selectedCompareIdsKvKey))).getSingleOrNull();
    if (row != null && row.value.isNotEmpty) {
      try {
        final decoded = jsonDecode(row.value);
        if (decoded is List) {
          final filtered = decoded
              .map((e) => e.toString())
              .where(validIds.contains)
              .toList();
          if (filtered.isNotEmpty) return filtered;
        }
      } catch (_) {}
    }
    if (translations.isEmpty) return const [];
    final primary =
        translations.where((t) => t.isPrimary).firstOrNull ??
        translations.first;
    return [primary.id];
  }

  /// Persiste as traduções selecionadas para leitura/comparação no popup.
  static Future<void> saveSelectedComparisonIds(
    AppDatabase db,
    List<String> ids,
  ) async {
    final dedup = <String>[];
    for (final id in ids) {
      if (id.isNotEmpty && !dedup.contains(id)) dedup.add(id);
    }
    await _putKv(db, selectedCompareIdsKvKey, jsonEncode(dedup));
  }

  /// Define uma tradução importada como principal.
  static Future<void> setPrimaryTranslation(
    AppDatabase db,
    String translationId,
  ) async {
    final list = await listTranslations(db);
    if (list.isEmpty) return;
    final updated = <BibleNwtCatalog>[];
    BibleNwtCatalog? primary;
    for (final item in list) {
      final isTarget = item.id == translationId;
      final next = item.copyWith(isPrimary: isTarget);
      if (isTarget) primary = next;
      updated.add(next);
    }
    if (primary == null) return;
    await db.transaction(() async {
      await _putKv(
        db,
        translationsCatalogKvKey,
        jsonEncode(updated.map((e) => e.toJson()).toList()),
      );
      await _putKv(db, catalogKvKey, jsonEncode(primary!.toJson()));
    });
  }

  /// Remove uma tradução específica preservando as demais e versículos manuais.
  static Future<void> deleteTranslation(
    AppDatabase db,
    String translationId,
  ) async {
    final current = await listTranslations(db);
    final remaining = current.where((c) => c.id != translationId).toList();
    if (remaining.isNotEmpty && !remaining.any((c) => c.isPrimary)) {
      remaining[0] = remaining[0].copyWith(isPrimary: true);
    }
    final newPrimary = remaining.where((c) => c.isPrimary).firstOrNull;

    await db.transaction(() async {
      if (translationId == defaultTranslationId) {
        await (db.delete(
          db.appKvStore,
        )..where((t) => t.key.like('bible_nwt_book_%'))).go();
      } else {
        await (db.delete(
          db.appKvStore,
        )..where((t) => t.key.like('bible_tr_${translationId}_book_%'))).go();
        await (db.delete(db.appKvStore)..where(
              (t) => t.key.equals(translationHighlightsKvKey(translationId)),
            ))
            .go();
      }

      if (remaining.isEmpty) {
        await (db.delete(
          db.appKvStore,
        )..where((t) => t.key.equals(catalogKvKey))).go();
        await (db.delete(
          db.appKvStore,
        )..where((t) => t.key.equals(translationsCatalogKvKey))).go();
      } else {
        await _putKv(
          db,
          translationsCatalogKvKey,
          jsonEncode(remaining.map((e) => e.toJson()).toList()),
        );
        if (newPrimary != null) {
          await _putKv(db, catalogKvKey, jsonEncode(newPrimary.toJson()));
        }
      }
    });

    final selected = await loadSelectedComparisonIds(db);
    final filteredSelected = selected
        .where((id) => id != translationId)
        .toList();
    await saveSelectedComparisonIds(db, filteredSelected);
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
      )..where((t) => t.key.equals(translationsCatalogKvKey))).go();
      await (db.delete(
        db.appKvStore,
      )..where((t) => t.key.equals(selectedCompareIdsKvKey))).go();
      await (db.delete(
        db.appKvStore,
      )..where((t) => t.key.like('bible_nwt_book_%'))).go();
      await (db.delete(
        db.appKvStore,
      )..where((t) => t.key.like('bible_tr_%'))).go();
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
    String? translationId,
  }) async {
    final store = await _loadHighlightStore(db, translationId: translationId);
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
    await _putKv(
      db,
      translationHighlightsKvKey(translationId),
      jsonEncode(store),
    );
  }

  static Future<Map<String, dynamic>> _loadHighlightStore(
    AppDatabase db, {
    String? translationId,
  }) async {
    final row =
        await (db.select(db.appKvStore)..where(
              (t) => t.key.equals(translationHighlightsKvKey(translationId)),
            ))
            .getSingleOrNull();
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
    String? translationId,
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
    final translations = await listTranslations(db);
    final targetCatalog = translationId != null
        ? translations.where((c) => c.id == translationId).firstOrNull
        : (translations.where((c) => c.isPrimary).firstOrNull ??
              translations.firstOrNull);
    final resolvedId =
        targetCatalog?.id ?? translationId ?? defaultTranslationId;
    final importedChapter = await _loadImportedChapter(
      db,
      translationId: resolvedId,
      bookNumber: bookNumber,
      chapter: chapter,
    );
    final includeManual =
        targetCatalog == null ||
        targetCatalog.isPrimary ||
        translationId == null;
    final manualChapter = includeManual
        ? await _loadManualChapter(db, bookNumber: bookNumber, chapter: chapter)
        : const <int, String>{};
    final highlights = await _loadHighlightStore(db, translationId: resolvedId);

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
      hasImportedBible: targetCatalog?.hasFullLibrary ?? false,
      translationId: resolvedId,
      catalog: targetCatalog,
    );
  }

  /// Consulta múltiplas traduções simultaneamente para o modo Comparar Versões (estilo JW Library).
  static Future<List<BibleTranslationPassage>> lookupComparisonPassages(
    AppDatabase db, {
    required List<String> translationIds,
    required int bookNumber,
    required int chapter,
    String? verseSpec,
  }) async {
    final translations = await listTranslations(db);
    final byId = {for (final t in translations) t.id: t};
    final idsToQuery = translationIds.where(byId.containsKey).toList();

    if (idsToQuery.isEmpty) {
      final manualOnly = await lookupPassage(
        db,
        bookNumber: bookNumber,
        chapter: chapter,
        verseSpec: verseSpec,
      );
      if (manualOnly.hasFoundVerses) {
        return [
          BibleTranslationPassage(
            translationId: defaultTranslationId,
            title: 'Versículos Salvos Manualmente',
            language: 'pt',
            languageDisplay: 'Português',
            isManualFallback: true,
            lookup: manualOnly,
          ),
        ];
      }
      return const [];
    }

    final results = <BibleTranslationPassage>[];
    for (final id in idsToQuery) {
      final cat = byId[id]!;
      final lookup = await lookupPassage(
        db,
        bookNumber: bookNumber,
        chapter: chapter,
        verseSpec: verseSpec,
        translationId: id,
      );
      results.add(
        BibleTranslationPassage(
          translationId: cat.id,
          title: cat.title,
          language: cat.language,
          languageDisplay: cat.languageDisplay,
          coverBase64: cat.coverBase64,
          lookup: lookup,
        ),
      );
    }
    return results;
  }

  /// Importa arquivo `.epub` (baixado pelo usuário no jw.org) ou `.json` estruturado.
  static Future<BibleImportResult> importFromBytes(
    AppDatabase db, {
    required Uint8List bytes,
    required String fileName,
    String? translationId,
    bool setAsPrimary = false,
    void Function(int processed, int total)? onProgress,
  }) async {
    if (bytes.isEmpty) {
      throw const BibleImportException('O arquivo selecionado está vazio.');
    }
    if (_looksLikePdf(bytes)) {
      throw BibleImportException(
        'O arquivo "$fileName" é um documento PDF, não um EPUB ou JSON bíblico.',
      );
    }

    final lowerName = fileName.toLowerCase().trim();
    if (lowerName.endsWith('.jwpub') || lowerName.endsWith('.jwlpub')) {
      final titleHint = _tryReadJwpubManifestTitle(bytes);
      final label = titleHint != null ? ' ("$titleHint")' : '';
      throw BibleImportException(
        'Arquivos .jwpub$label utilizam banco interno criptografado exclusivo do JW Library.\n'
        'Para leitura offline aqui no app, baixe no site jw.org a edição oficial em formato .epub '
        '(ou importe um arquivo .json próprio).',
      );
    }

    if (lowerName.endsWith('.json') ||
        (!lowerName.endsWith('.epub') && _looksLikeJson(bytes))) {
      return _importJsonBytes(
        db,
        bytes,
        translationId: translationId,
        setAsPrimary: setAsPrimary,
        onProgress: onProgress,
      );
    }

    // Trata como EPUB (ZIP + OPF + XHTML) ou detecta JWPUB disfarçado
    return _importEpubBytes(
      db,
      bytes,
      fileName,
      translationId: translationId,
      setAsPrimary: setAsPrimary,
      onProgress: onProgress,
    );
  }

  static bool _looksLikeJson(Uint8List bytes) {
    var i = 0;
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      i = 3;
    }
    while (i < bytes.length && i < 128) {
      final b = bytes[i];
      if (b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D) {
        i++;
        continue;
      }
      return b == 0x7B || b == 0x5B; // '{' ou '['
    }
    return false;
  }

  static int? _parsePositiveInt(dynamic raw) {
    if (raw is num) {
      final v = raw.toInt();
      return v >= 1 ? v : null;
    }
    if (raw != null) {
      final v = int.tryParse(raw.toString().trim());
      return (v != null && v >= 1) ? v : null;
    }
    return null;
  }

  static String _decodeUtf8Text(Uint8List bytes) {
    String raw;
    try {
      raw = utf8.decode(bytes);
    } on FormatException {
      raw = utf8.decode(bytes, allowMalformed: true);
    }
    return raw.startsWith('\uFEFF') ? raw.substring(1) : raw;
  }

  static Future<BibleImportResult> _importJsonBytes(
    AppDatabase db,
    Uint8List bytes, {
    String? translationId,
    bool setAsPrimary = false,
    void Function(int processed, int total)? onProgress,
  }) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(_decodeUtf8Text(bytes));
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
          final ch = _parsePositiveInt(item['chapter']);
          final v = _parsePositiveInt(item['verse']);
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
        final ch = _parsePositiveInt(item['chapter']);
        final v = _parsePositiveInt(item['verse']);
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
      translationId: translationId,
      setAsPrimary: setAsPrimary,
      onProgress: onProgress,
    );
  }

  static Future<BibleImportResult> _importEpubBytes(
    AppDatabase db,
    Uint8List bytes,
    String fileName, {
    String? translationId,
    bool setAsPrimary = false,
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
        (filesByPath.containsKey('contents') ||
            filesByPath.keys.any((k) => k.endsWith('.db')))) {
      throw const BibleImportException(
        'Este arquivo é um pacote .jwpub com banco criptografado do JW Library.\n'
        'Por favor, baixe no site jw.org a edição oficial em formato .epub.',
      );
    }

    final opfPath = _findOpfPath(filesByPath);
    final opfFile = opfPath == null
        ? null
        : _lookupArchiveFile(filesByPath, opfPath);
    if (opfPath == null || opfFile == null) {
      throw const BibleImportException(
        'Arquivo EPUB inválido: documento package/content .opf não encontrado.',
      );
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

    // Mapeia ID -> href e verifica arquivo de navegação (ncx / nav) e capa
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
      if (id.isNotEmpty && href.isNotEmpty) {
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
        final lowerHref = path.toLowerCase();
        final media = (manifestMediaById[idref] ?? '').toLowerCase();
        if (media.isEmpty ||
            media.contains('html') ||
            lowerHref.endsWith('.xhtml') ||
            lowerHref.endsWith('.html')) {
          spinePaths.add(path);
        }
      }
    }

    if (spinePaths.isEmpty) {
      spinePaths.addAll(
        filesByPath.keys.where((k) {
          final lk = k.toLowerCase();
          return lk.endsWith('.xhtml') || lk.endsWith('.html');
        }),
      );
    }

    final parsedBooks = <int, Map<int, Map<int, String>>>{};
    final total = spinePaths.length;
    for (var idx = 0; idx < total; idx++) {
      final path = spinePaths[idx];
      final archiveFile = _lookupArchiveFile(filesByPath, path);
      if (archiveFile == null) continue;

      final lowerPath = path.toLowerCase();
      final isNonChapterNavOrExtract =
          lowerPath.contains('-extracted') ||
          RegExp(r'(?:^|/)bible(?:book|chapter|verse)nav')
              .hasMatch(lowerPath) ||
          RegExp(r'(?:^|/)(?:toc|nav|cover|pagenav)\.xhtml$')
              .hasMatch(lowerPath);
      if (isNonChapterNavOrExtract) {
        if (idx > 0 && idx % 60 == 0) {
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

      if (idx > 0 && idx % 12 == 0) {
        onProgress?.call(idx + 1, total);
        await Future<void>.delayed(Duration.zero);
      }
    }
    onProgress?.call(total, total);

    if (parsedBooks.isEmpty) {
      throw const BibleImportException(
        'Não foi possível identificar capítulos/versículos da Bíblia neste EPUB.\n'
        'Verifique se o arquivo selecionado é uma Bíblia em .epub válido.',
      );
    }

    return _persistParsedBible(
      db,
      parsedBooks: parsedBooks,
      title: title,
      language: language,
      sourceFormat: 'epub',
      coverBase64: coverBase64,
      translationId: translationId,
      setAsPrimary: setAsPrimary,
      onProgress: onProgress,
    );
  }

  static Future<BibleImportResult> _persistParsedBible(
    AppDatabase db, {
    required Map<int, Map<int, Map<int, String>>> parsedBooks,
    required String title,
    required String language,
    required String sourceFormat,
    String? coverBase64,
    String? translationId,
    bool setAsPrimary = false,
    void Function(int processed, int total)? onProgress,
  }) async {
    final existingList = await listTranslations(db);
    String targetId;
    if (translationId != null && translationId.trim().isNotEmpty) {
      targetId = translationId.trim();
    } else if (existingList.isEmpty) {
      targetId = defaultTranslationId;
    } else {
      final matching = existingList
          .where(
            (c) =>
                c.title.trim().toLowerCase() == title.trim().toLowerCase() &&
                c.language.trim().toLowerCase() ==
                    language.trim().toLowerCase(),
          )
          .firstOrNull;
      var candidate =
          matching?.id ?? _buildTranslationId(language: language, title: title);
      if (matching == null) {
        final usedIds = existingList.map((e) => e.id).toSet();
        var suffix = 2;
        while (usedIds.contains(candidate)) {
          candidate = '${candidate}_$suffix';
          suffix++;
        }
      }
      targetId = candidate;
    }

    final shouldBePrimary =
        setAsPrimary ||
        existingList.isEmpty ||
        existingList.any((c) => c.id == targetId && c.isPrimary);

    final chaptersByBook = <int, int>{};
    var totalChapters = 0;
    var totalVerses = 0;

    final sortedBookNums = parsedBooks.keys.toList()..sort();
    final encodedBooks = <int, String>{};
    for (final bookNum in sortedBookNums) {
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
      encodedBooks[bookNum] = jsonEncode(encodedChapters);
    }

    final catalog = BibleNwtCatalog(
      id: targetId,
      title: title,
      language: language,
      sourceFormat: sourceFormat,
      importedAt: DateTime.now(),
      bookCount: parsedBooks.length,
      chapterCount: totalChapters,
      verseCount: totalVerses,
      chaptersByBook: chaptersByBook,
      coverBase64: coverBase64,
      isPrimary: shouldBePrimary,
    );

    final nextList = <BibleNwtCatalog>[];
    for (final item in existingList) {
      if (item.id == targetId) continue;
      nextList.add(shouldBePrimary ? item.copyWith(isPrimary: false) : item);
    }
    nextList.insert(0, catalog);

    final currentSelected = await loadSelectedComparisonIds(db);

    await db.transaction(() async {
      if (targetId == defaultTranslationId) {
        await (db.delete(
          db.appKvStore,
        )..where((t) => t.key.like('bible_nwt_book_%'))).go();
      } else {
        await (db.delete(
          db.appKvStore,
        )..where((t) => t.key.like('bible_tr_${targetId}_book_%'))).go();
      }

      for (final bookNum in sortedBookNums) {
        await _putKv(
          db,
          translationBookKvKey(targetId, bookNum),
          encodedBooks[bookNum]!,
        );
      }

      await _putKv(
        db,
        translationsCatalogKvKey,
        jsonEncode(nextList.map((e) => e.toJson()).toList()),
      );
      if (shouldBePrimary || targetId == defaultTranslationId) {
        await _putKv(db, catalogKvKey, jsonEncode(catalog.toJson()));
      }
      if (!currentSelected.contains(targetId)) {
        await saveSelectedComparisonIds(db, [...currentSelected, targetId]);
      }
    });

    onProgress?.call(1, 1);
    return BibleImportResult(catalog);
  }

  static String _buildTranslationId({
    required String language,
    required String title,
  }) {
    final clean = '${language}_$title'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final prefix = clean.isEmpty
        ? 'bible'
        : (clean.length > 24 ? clean.substring(0, 24) : clean);
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}';
  }

  static bool _looksLikePdf(Uint8List bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
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

  static void _extractBibleFromXhtml(
    String xhtml, {
    required String filePath,
    String? tocTitleHint,
    required Map<int, Map<int, Map<int, String>>> outBooks,
  }) {
    if (xhtml.trim().isEmpty) return;

    final XmlDocument? doc = _tryParseXhtmlXml(xhtml);

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
    if (doc != null) {
      for (final p in doc.findAllElements('p')) {
        final cls = (p.getAttribute('class') ?? '').toLowerCase();
        if (cls.contains('w_biblebookname')) {
          for (final a in p.findElements('a')) {
            final href = (a.getAttribute('href') ?? '').toLowerCase();
            final chapNavMatch = RegExp(
              r'biblechapternav(\d{1,2})\.(?:xhtml|html)',
            ).firstMatch(href);
            if (chapNavMatch != null) {
              final num = int.tryParse(chapNavMatch.group(1)!);
              if (num != null && num >= 1 && num <= 66) return num;
            }
            final verseNavMatch = RegExp(
              r'bibleversenav(\d{1,2})_\d+\.(?:xhtml|html)',
            ).firstMatch(href);
            if (verseNavMatch != null) {
              final num = int.tryParse(verseNavMatch.group(1)!);
              if (num != null && num >= 1 && num <= 66) return num;
            }
          }
          final bookLink = p.findElements('a').firstOrNull;
          if (bookLink != null) {
            final found = NwtBibleBooks.findByQuery(bookLink.innerText);
            if (found != null) return found.number;
          }
        }
      }
    }

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

  static XmlDocument? _tryParseXhtmlXml(String xhtml) {
    try {
      return XmlDocument.parse(xhtml);
    } catch (_) {
      final sanitized = _replaceCommonHtmlEntities(xhtml);
      if (sanitized == xhtml) return null;
      try {
        return XmlDocument.parse(sanitized);
      } catch (_) {
        return null;
      }
    }
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

  static Future<Map<int, String>> _loadImportedChapter(
    AppDatabase db, {
    String translationId = defaultTranslationId,
    required int bookNumber,
    required int chapter,
  }) async {
    final row =
        await (db.select(db.appKvStore)..where(
              (t) =>
                  t.key.equals(translationBookKvKey(translationId, bookNumber)),
            ))
            .getSingleOrNull();
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

  static String _appendText(String? existing, String addition) {
    if (existing == null || existing.isEmpty) return addition;
    if (existing.endsWith(addition)) return existing;
    return '$existing $addition';
  }
}
