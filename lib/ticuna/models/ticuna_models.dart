import 'dart:convert';

import '../../core/app_logger.dart';

enum TicunaEntryType {
  word,
  phrase;

  String get displayName => this == TicunaEntryType.word ? 'Dicionário' : 'Frases Úteis';
}

/// Item do Dicionário Ticuna (estilo Flashcard / Anki)
class TicunaWord {
  final String id;
  final String word; // Palavra ou termo em Ticuna
  final String translation; // Tradução em Português
  final String? phonetics; // Notas de pronúncia e tons (ex: "ta-e-mã-ẽ [tom alto]")
  final String? grammaticalClass; // Substantivo, Verbo, Adjetivo, Pronome, etc.
  final String? exampleSentence; // Exemplo prático de frase em Ticuna
  final String? exampleTranslation; // Tradução da frase de exemplo
  final String? notes; // Notas culturais ou contexto ministerial
  final List<String> tags; // Tags (ex: Ministério, Saudações, Bíblia)
  final bool isFavorite; // Marcador de favorito
  final int reviewLevel; // Caixa / Nível no método Leitner/Anki (0 a 5)
  final int reviewCount; // Total de revisões concluídas
  final DateTime? lastReviewedAt; // Data da última revisão
  final String? audioPath; // Caminho do áudio local ou remoto da pronúncia
  final int? audioDurationSeconds; // Duração em segundos da pronúncia gravada
  final String? languageId; // Código/ID do idioma (ex: 'tca', 'gub', 'yan')
  final DateTime createdAt;
  final DateTime updatedAt;

  const TicunaWord({
    required this.id,
    required this.word,
    required this.translation,
    this.phonetics,
    this.grammaticalClass,
    this.exampleSentence,
    this.exampleTranslation,
    this.notes,
    this.tags = const [],
    this.isFavorite = false,
    this.reviewLevel = 0,
    this.reviewCount = 0,
    this.lastReviewedAt,
    this.audioPath,
    this.audioDurationSeconds,
    this.languageId = 'tca',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Intervalo em dias baseado no sistema Leitner (níveis 0 a 5)
  int get intervalDays {
    switch (reviewLevel) {
      case 1:
        return 1;
      case 2:
        return 3;
      case 3:
        return 7;
      case 4:
        return 14;
      case 5:
        return 30;
      default:
        return 0;
    }
  }

  /// Data prevista para a próxima revisão espaçada
  DateTime? get nextReviewDate {
    if (lastReviewedAt == null) return null;
    return lastReviewedAt!.add(Duration(days: intervalDays));
  }

  /// Indica se o termo está pronto para ser revisado hoje
  bool get isDueForReview {
    if (lastReviewedAt == null || reviewLevel == 0) return true;
    final next = nextReviewDate;
    if (next == null) return true;
    return DateTime.now().isAfter(next);
  }

  TicunaWord copyWith({
    String? id,
    String? word,
    String? translation,
    String? phonetics,
    String? grammaticalClass,
    String? exampleSentence,
    String? exampleTranslation,
    String? notes,
    List<String>? tags,
    bool? isFavorite,
    int? reviewLevel,
    int? reviewCount,
    DateTime? lastReviewedAt,
    String? audioPath,
    int? audioDurationSeconds,
    String? languageId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TicunaWord(
      id: id ?? this.id,
      word: word ?? this.word,
      translation: translation ?? this.translation,
      phonetics: phonetics ?? this.phonetics,
      grammaticalClass: grammaticalClass ?? this.grammaticalClass,
      exampleSentence: exampleSentence ?? this.exampleSentence,
      exampleTranslation: exampleTranslation ?? this.exampleTranslation,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      reviewLevel: reviewLevel ?? this.reviewLevel,
      reviewCount: reviewCount ?? this.reviewCount,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      audioPath: audioPath ?? this.audioPath,
      audioDurationSeconds: audioDurationSeconds ?? this.audioDurationSeconds,
      languageId: languageId ?? this.languageId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'word': word,
    'translation': translation,
    'phonetics': phonetics,
    'grammatical_class': grammaticalClass,
    'example_sentence': exampleSentence,
    'example_translation': exampleTranslation,
    'notes': notes,
    'tags': jsonEncode(tags),
    'is_favorite': isFavorite ? 1 : 0,
    'review_level': reviewLevel,
    'review_count': reviewCount,
    'last_reviewed_at': lastReviewedAt?.toIso8601String(),
    'audio_path': audioPath,
    'audio_duration_seconds': audioDurationSeconds,
    'language_id': languageId ?? 'tca',
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory TicunaWord.fromMap(Map<String, dynamic> map) {
    List<String> parsedTags = [];
    try {
      final raw = map['tags'];
      if (raw is List) {
        parsedTags = raw.map((e) => e.toString()).toList();
      } else if (raw is String && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          parsedTags = decoded.map((e) => e.toString()).toList();
        }
      }
    } catch (e, st) {
      AppLogger.debug('Falha ao parsear tags em modelo linguístico: $e', st);
    }

    return TicunaWord(
      id: map['id']?.toString() ?? '',
      word: map['word'] as String? ?? '',
      translation: map['translation'] as String? ?? '',
      phonetics: map['phonetics'] as String?,
      grammaticalClass: map['grammatical_class'] as String?,
      exampleSentence: map['example_sentence'] as String?,
      exampleTranslation: map['example_translation'] as String?,
      notes: map['notes'] as String?,
      tags: parsedTags,
      isFavorite: (map['is_favorite'] == 1 || map['is_favorite'] == true),
      reviewLevel: (map['review_level'] as num?)?.toInt() ?? 0,
      reviewCount: (map['review_count'] as num?)?.toInt() ?? 0,
      lastReviewedAt: map['last_reviewed_at'] != null
          ? DateTime.tryParse(map['last_reviewed_at'] as String)
          : null,
      audioPath: (map['audio_path'] as String?)?.trim().isNotEmpty == true
          ? (map['audio_path'] as String).trim()
          : null,
      audioDurationSeconds: (map['audio_duration_seconds'] as num?)?.toInt(),
      languageId: map['language_id'] as String? ?? 'tca',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// Item de Frase Útil em Ticuna para o ministério e conversação
class TicunaPhrase {
  final String id;
  final String phrase; // Frase em Ticuna
  final String translation; // Tradução em Português
  final String? category; // Tópico/categoria (Saudação, Campo, Bíblia, Perguntas, etc.)
  final String? phonetics; // Pronúncia sugerida
  final String? notes; // Versículo bíblico ou observação contextual
  final List<String> tags; // Tags associadas
  final bool isFavorite; // Marcador de favorito
  final String? audioPath; // Caminho do áudio local ou remoto da pronúncia
  final int? audioDurationSeconds; // Duração em segundos da pronúncia gravada
  final String? languageId; // Código/ID do idioma
  final DateTime createdAt;
  final DateTime updatedAt;

  const TicunaPhrase({
    required this.id,
    required this.phrase,
    required this.translation,
    this.category,
    this.phonetics,
    this.notes,
    this.tags = const [],
    this.isFavorite = false,
    this.audioPath,
    this.audioDurationSeconds,
    this.languageId = 'tca',
    required this.createdAt,
    required this.updatedAt,
  });

  TicunaPhrase copyWith({
    String? id,
    String? phrase,
    String? translation,
    String? category,
    String? phonetics,
    String? notes,
    List<String>? tags,
    bool? isFavorite,
    String? audioPath,
    int? audioDurationSeconds,
    String? languageId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TicunaPhrase(
      id: id ?? this.id,
      phrase: phrase ?? this.phrase,
      translation: translation ?? this.translation,
      category: category ?? this.category,
      phonetics: phonetics ?? this.phonetics,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      audioPath: audioPath ?? this.audioPath,
      audioDurationSeconds: audioDurationSeconds ?? this.audioDurationSeconds,
      languageId: languageId ?? this.languageId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'phrase': phrase,
    'translation': translation,
    'category': category,
    'phonetics': phonetics,
    'notes': notes,
    'tags': jsonEncode(tags),
    'is_favorite': isFavorite ? 1 : 0,
    'audio_path': audioPath,
    'audio_duration_seconds': audioDurationSeconds,
    'language_id': languageId ?? 'tca',
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory TicunaPhrase.fromMap(Map<String, dynamic> map) {
    List<String> parsedTags = [];
    try {
      final raw = map['tags'];
      if (raw is List) {
        parsedTags = raw.map((e) => e.toString()).toList();
      } else if (raw is String && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          parsedTags = decoded.map((e) => e.toString()).toList();
        }
      }
    } catch (e, st) {
      AppLogger.debug('Falha ao parsear tags em modelo linguístico: $e', st);
    }

    return TicunaPhrase(
      id: map['id']?.toString() ?? '',
      phrase: map['phrase'] as String? ?? '',
      translation: map['translation'] as String? ?? '',
      category: map['category'] as String?,
      phonetics: map['phonetics'] as String?,
      notes: map['notes'] as String?,
      tags: parsedTags,
      isFavorite: (map['is_favorite'] == 1 || map['is_favorite'] == true),
      audioPath: (map['audio_path'] as String?)?.trim().isNotEmpty == true
          ? (map['audio_path'] as String).trim()
          : null,
      audioDurationSeconds: (map['audio_duration_seconds'] as num?)?.toInt(),
      languageId: map['language_id'] as String? ?? 'tca',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// Tag/Categoria para organização em Ticuna
class TicunaTag {
  final String id;
  final String name;
  final DateTime createdAt;

  const TicunaTag({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'created_at': createdAt.toIso8601String(),
  };

  factory TicunaTag.fromMap(Map<String, dynamic> map) => TicunaTag(
    id: map['id']?.toString() ?? '',
    name: map['name'] as String? ?? '',
    createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
  );
}

/// Estrutura completa de exportação / importação do banco de dados Ticuna
class TicunaExportData {
  final int version;
  final DateTime exportedAt;
  final List<TicunaWord> words;
  final List<TicunaPhrase> phrases;
  final List<TicunaTag> tags;

  const TicunaExportData({
    this.version = 1,
    required this.exportedAt,
    required this.words,
    required this.phrases,
    required this.tags,
  });

  Map<String, dynamic> toMap() => {
    'format': 'ministerio_pessoal_ticuna_backup',
    'version': version,
    'exported_at': exportedAt.toIso8601String(),
    'words_count': words.length,
    'phrases_count': phrases.length,
    'tags_count': tags.length,
    'words': words.map((w) => w.toMap()).toList(),
    'phrases': phrases.map((p) => p.toMap()).toList(),
    'tags': tags.map((t) => t.toMap()).toList(),
  };

  String toJson() => const JsonEncoder.withIndent('  ').convert(toMap());

  factory TicunaExportData.fromMap(Map<String, dynamic> map) {
    final rawWords = map['words'] as List? ?? [];
    final rawPhrases = map['phrases'] as List? ?? [];
    final rawTags = map['tags'] as List? ?? [];

    return TicunaExportData(
      version: (map['version'] as num?)?.toInt() ?? 1,
      exportedAt: DateTime.tryParse(map['exported_at'] as String? ?? '') ?? DateTime.now(),
      words: rawWords
          .map((e) => TicunaWord.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      phrases: rawPhrases
          .map((e) => TicunaPhrase.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      tags: rawTags
          .map((e) => TicunaTag.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  factory TicunaExportData.fromJson(String jsonStr) {
    final decoded = jsonDecode(jsonStr);
    if (decoded is List) {
      final words = <TicunaWord>[];
      final phrases = <TicunaPhrase>[];
      for (final item in decoded) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          if (map.containsKey('phrase')) {
            phrases.add(TicunaPhrase.fromMap(map));
          } else {
            words.add(TicunaWord.fromMap(map));
          }
        }
      }
      return TicunaExportData(
        version: 1,
        exportedAt: DateTime.now(),
        words: words,
        phrases: phrases,
        tags: const [],
      );
    }
    if (decoded is! Map<String, dynamic> && decoded is Map) {
      return TicunaExportData.fromMap(Map<String, dynamic>.from(decoded));
    }
    return TicunaExportData.fromMap(decoded as Map<String, dynamic>);
  }
}
