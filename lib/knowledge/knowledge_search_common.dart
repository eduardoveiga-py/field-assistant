import 'dart:convert';

import '../database/app_database.dart';

/// Item de resultado em busca unificada na Base de Conhecimento
class KnowledgeSearchResult {
  final String id;
  final String title;
  final String snippet;
  final String entityType; // 'note', 'question', 'document', 'resource'
  final String category;
  final DateTime updatedAt;
  final String? areaId;
  final double score;

  const KnowledgeSearchResult({
    required this.id,
    required this.title,
    required this.snippet,
    required this.entityType,
    required this.category,
    required this.updatedAt,
    this.areaId,
    this.score = 0.0,
  });
}

class KnowledgeSearchCommon {
  static final RegExp _combiningMarks = RegExp(r'[\u0300-\u036f]');

  static const Map<String, String> _foldMap = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'ā': 'a',
    'ă': 'a',
    'ą': 'a',
    'a\u0303': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'ē': 'e',
    'ĕ': 'e',
    'ė': 'e',
    'ę': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ĩ': 'i',
    'ī': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ø': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ũ': 'u',
    'ű': 'u',
    'ç': 'c',
    'ć': 'c',
    'č': 'c',
    'ñ': 'n',
    'ń': 'n',
    'ý': 'y',
    'ÿ': 'y',
  };

  /// Normaliza texto removendo acentos, diacríticos e maiúsculas para busca tolerante.
  static String normalizeSearchText(String raw) {
    if (raw.isEmpty) return '';
    final lower = raw.toLowerCase().replaceAll(_combiningMarks, '');
    final sb = StringBuffer();
    for (var i = 0; i < lower.length; i++) {
      final ch = lower[i];
      sb.write(_foldMap[ch] ?? ch);
    }
    return sb.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<String> tokenizeQuery(String query) {
    final norm = normalizeSearchText(query);
    if (norm.isEmpty) return const [];
    return norm
        .split(RegExp(r'[^a-z0-9_@:/.-]+'))
        .where((t) => t.trim().isNotEmpty)
        .toSet()
        .toList();
  }

  static String decodeTagsText(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is List) {
        return decoded
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .join(' ');
      }
    } catch (_) {}
    return '';
  }

  static String extractNoteBody(KnowledgeNoteEntry n) {
    var text = n.content;
    if (n.category == 'official_doc') {
      try {
        final parsed = jsonDecode(n.content);
        if (parsed is Map<String, dynamic>) {
          final refSubj = (parsed['referenceSubject'] as String? ?? '').trim();
          final body = (parsed['bodyMarkup'] as String? ?? '').trim();
          text = [
            if (refSubj.isNotEmpty) refSubj,
            if (body.isNotEmpty) body,
          ].join(' — ');
        }
      } catch (_) {
        text = n.title;
      }
    }
    return text;
  }

  static String buildSnippet(
    String rawBody, {
    List<String> queryTokens = const [],
    int maxLength = 150,
  }) {
    final cleaned = rawBody
        .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '')
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\([^)]+\)'),
          (m) => m.group(1) ?? '',
        )
        .replaceAll(RegExp(r'[#*`>_]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return '';

    if (queryTokens.isNotEmpty && cleaned.length > maxLength) {
      final norm = normalizeSearchText(cleaned);
      final idx = norm.indexOf(queryTokens.first);
      if (idx > 30) {
        final start = (idx - 25).clamp(0, cleaned.length - 1);
        final end = (start + maxLength).clamp(start, cleaned.length);
        final prefix = start > 0 ? '...' : '';
        final suffix = end < cleaned.length ? '...' : '';
        return '$prefix${cleaned.substring(start, end)}$suffix';
      }
    }

    if (cleaned.length <= maxLength) return cleaned;
    return '${cleaned.substring(0, maxLength)}...';
  }

  static double scoreMatch({
    required String title,
    required String body,
    required String tagsText,
    required List<String> tokens,
    required String normalizedFullQuery,
  }) {
    if (tokens.isEmpty) return 0;
    final normTitle = normalizeSearchText(title);
    final normTags = normalizeSearchText(tagsText);
    final normBody = normalizeSearchText(body);
    final combined = '$normTitle $normTags $normBody';

    for (final tok in tokens) {
      if (!combined.contains(tok)) return 0;
    }

    var score = 0.0;
    if (normalizedFullQuery.isNotEmpty) {
      if (normTitle == normalizedFullQuery) {
        score += 120;
      } else if (normTitle.startsWith(normalizedFullQuery)) {
        score += 80;
      } else if (normTitle.contains(normalizedFullQuery)) {
        score += 45;
      }
    }

    for (final tok in tokens) {
      if (normTitle.contains(tok)) score += 20;
      if (normTags.contains(tok)) score += 14;
      if (normBody.contains(tok)) score += 5;
    }
    return score;
  }

  /// Ranqueador puro Dart utilizado na Web PWA e como fallback seguro no Native IO.
  static Future<List<KnowledgeSearchResult>> fallbackSearch(
    AppDatabase db,
    String rawQuery, {
    int limit = 30,
    String? areaId,
  }) async {
    final normFull = normalizeSearchText(rawQuery);
    final tokens = tokenizeQuery(rawQuery);
    if (tokens.isEmpty) return const [];

    final scored = <KnowledgeSearchResult>[];

    // 1. Notas
    final notesQuery = db.select(db.knowledgeNotes)
      ..where((t) => t.deletedAt.isNull());
    if (areaId != null && areaId.isNotEmpty) {
      notesQuery.where((t) => t.areaId.equals(areaId));
    }
    final notes = await notesQuery.get();
    for (final n in notes) {
      if (n.category == 'official_profile_bundle' ||
          n.category == 'official_template') {
        continue;
      }
      final body = extractNoteBody(n);
      final tagsText = decodeTagsText(n.tags);
      final sc = scoreMatch(
        title: n.title,
        body: '$body ${n.propertiesJson}',
        tagsText: tagsText,
        tokens: tokens,
        normalizedFullQuery: normFull,
      );
      if (sc > 0) {
        scored.add(
          KnowledgeSearchResult(
            id: n.id,
            title: n.title,
            snippet: buildSnippet(body, queryTokens: tokens),
            entityType: 'note',
            category: n.category,
            updatedAt: n.updatedAt,
            areaId: n.areaId,
            score: sc,
          ),
        );
      }
    }

    // 2. Perguntas / Dúvidas
    final qQuery = db.select(db.knowledgeQuestions)
      ..where((t) => t.deletedAt.isNull());
    if (areaId != null && areaId.isNotEmpty) {
      qQuery.where((t) => t.areaId.equals(areaId));
    }
    final questions = await qQuery.get();
    for (final q in questions) {
      final body = [
        q.context ?? '',
        q.answer ?? '',
      ].where((s) => s.trim().isNotEmpty).join('\n');
      final sc = scoreMatch(
        title: q.question,
        body: body,
        tagsText: q.category,
        tokens: tokens,
        normalizedFullQuery: normFull,
      );
      if (sc > 0) {
        final rawSnip = (q.answer?.trim().isNotEmpty == true)
            ? q.answer!
            : (q.context?.trim().isNotEmpty == true
                  ? q.context!
                  : 'Dúvida em aberto');
        scored.add(
          KnowledgeSearchResult(
            id: q.id,
            title: q.question,
            snippet: buildSnippet(rawSnip, queryTokens: tokens),
            entityType: 'question',
            category: q.category,
            updatedAt: q.updatedAt,
            areaId: q.areaId,
            score: sc,
          ),
        );
      }
    }

    // 3. Documentos (inclui extractedText de PDFs + nome de arquivo + tags)
    final dQuery = db.select(db.knowledgeDocuments)
      ..where((t) => t.deletedAt.isNull());
    if (areaId != null && areaId.isNotEmpty) {
      dQuery.where((t) => t.areaId.equals(areaId));
    }
    final docs = await dQuery.get();
    for (final d in docs) {
      final tagsText = decodeTagsText(d.tags);
      final body = [
        d.fileName,
        d.description ?? '',
        d.extractedText ?? '',
      ].where((s) => s.trim().isNotEmpty).join(' ');
      final sc = scoreMatch(
        title: d.title,
        body: body,
        tagsText: tagsText,
        tokens: tokens,
        normalizedFullQuery: normFull,
      );
      if (sc > 0) {
        final rawSnip = (d.extractedText?.trim().isNotEmpty == true)
            ? '${d.fileName} — ${buildSnippet(d.extractedText!, queryTokens: tokens, maxLength: 110)}'
            : 'Arquivo: ${d.fileName} (${(d.fileSize / 1024).toStringAsFixed(1)} KB)';
        scored.add(
          KnowledgeSearchResult(
            id: d.id,
            title: d.title,
            snippet: rawSnip,
            entityType: 'document',
            category: d.category,
            updatedAt: d.updatedAt,
            areaId: d.areaId,
            score: sc,
          ),
        );
      }
    }

    // 4. Recursos
    final rQuery = db.select(db.knowledgeResources)
      ..where((t) => t.deletedAt.isNull());
    if (areaId != null && areaId.isNotEmpty) {
      rQuery.where((t) => t.areaId.equals(areaId));
    }
    final resources = await rQuery.get();
    for (final r in resources) {
      final tagsText = decodeTagsText(r.tags);
      final body = [
        r.url ?? '',
        r.description ?? '',
        r.resourceType,
      ].where((s) => s.trim().isNotEmpty).join(' ');
      final sc = scoreMatch(
        title: r.title,
        body: body,
        tagsText: tagsText,
        tokens: tokens,
        normalizedFullQuery: normFull,
      );
      if (sc > 0) {
        scored.add(
          KnowledgeSearchResult(
            id: r.id,
            title: r.title,
            snippet: buildSnippet(
              r.description?.trim().isNotEmpty == true
                  ? r.description!
                  : (r.url ?? r.resourceType),
              queryTokens: tokens,
            ),
            entityType: 'resource',
            category: r.category,
            updatedAt: r.updatedAt,
            areaId: r.areaId,
            score: sc,
          ),
        );
      }
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    if (scored.length > limit) {
      return scored.sublist(0, limit);
    }
    return scored;
  }
}
