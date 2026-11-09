import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../core/app_logger.dart';
import '../database/app_database.dart';
import 'models/ticuna_models.dart';
import 'ticuna_unicode_helper.dart';

class TicunaImportResult {
  final int wordsCount;
  final int phrasesCount;
  final int tagsCount;
  final bool success;
  final String? errorMessage;

  const TicunaImportResult({
    required this.wordsCount,
    required this.phrasesCount,
    required this.tagsCount,
    required this.success,
    this.errorMessage,
  });
}

/// Repositório Offline-First de Dicionário, Frases Úteis e Tags em Língua Ticuna
class TicunaRepository {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();

  final StreamController<List<TicunaWord>> _wordsController =
      StreamController<List<TicunaWord>>.broadcast();
  final StreamController<List<TicunaPhrase>> _phrasesController =
      StreamController<List<TicunaPhrase>>.broadcast();
  final StreamController<List<TicunaTag>> _tagsController =
      StreamController<List<TicunaTag>>.broadcast();

  Future<void>? _initFuture;
  bool _initialized = false;
  bool _initializationFailed = false;
  String? _initializationError;

  bool get isInitialized => _initialized;
  bool get hasInitializationFailed => _initializationFailed;
  String? get initializationError => _initializationError;

  TicunaRepository(this.db) {
    _initTables();
  }

  Future<void> _initTables() async {
    if (_initialized) return;
    if (_initializationFailed) {
      _initFuture = _doInitTables();
    } else {
      _initFuture ??= _doInitTables();
    }
    await _initFuture;
  }

  Future<void> _enqueueSync(
    String entityType,
    String entityId,
    String operation,
    Map<String, dynamic> payload,
  ) async {
    try {
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: entityType,
          entityId: entityId,
          operation: operation,
          payload: jsonEncode(payload),
          createdAt: DateTime.now(),
          status: const Value('pending'),
        ),
      );
    } catch (e, st) {
      AppLogger.error(
        'Erro ao enfileirar operação na syncQueue ($entityType / $entityId / $operation): $e',
        e,
        st,
      );
      rethrow;
    }
  }

  Future<void> _doInitTables() async {
    try {
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS ticuna_words (
          id TEXT PRIMARY KEY,
          word TEXT NOT NULL,
          translation TEXT NOT NULL,
          phonetics TEXT,
          grammatical_class TEXT,
          example_sentence TEXT,
          example_translation TEXT,
          notes TEXT,
          tags TEXT NOT NULL DEFAULT '[]',
          is_favorite INTEGER NOT NULL DEFAULT 0,
          review_level INTEGER NOT NULL DEFAULT 0,
          review_count INTEGER NOT NULL DEFAULT 0,
          last_reviewed_at TEXT,
          audio_path TEXT,
          audio_duration_seconds INTEGER,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
      ''');

      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS ticuna_phrases (
          id TEXT PRIMARY KEY,
          phrase TEXT NOT NULL,
          translation TEXT NOT NULL,
          category TEXT,
          phonetics TEXT,
          notes TEXT,
          tags TEXT NOT NULL DEFAULT '[]',
          is_favorite INTEGER NOT NULL DEFAULT 0,
          audio_path TEXT,
          audio_duration_seconds INTEGER,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
      ''');

      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS ticuna_tags (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          created_at TEXT NOT NULL
        );
      ''');

      // Migrações idempotentes caso colunas já existam em bancos preexistentes
      try {
        await db.customStatement('ALTER TABLE ticuna_words ADD COLUMN audio_path TEXT;');
      } catch (e) {
        AppLogger.debug('Coluna audio_path em ticuna_words já existe ou inicializada: $e');
      }
      try {
        await db.customStatement('ALTER TABLE ticuna_words ADD COLUMN audio_duration_seconds INTEGER;');
      } catch (e) {
        AppLogger.debug('Coluna audio_duration_seconds em ticuna_words já existe ou inicializada: $e');
      }
      try {
        await db.customStatement('ALTER TABLE ticuna_phrases ADD COLUMN audio_path TEXT;');
      } catch (e) {
        AppLogger.debug('Coluna audio_path em ticuna_phrases já existe ou inicializada: $e');
      }
      try {
        await db.customStatement('ALTER TABLE ticuna_phrases ADD COLUMN audio_duration_seconds INTEGER;');
      } catch (e) {
        AppLogger.debug('Coluna audio_duration_seconds em ticuna_phrases já existe ou inicializada: $e');
      }

      // Normalização defensiva para recuperar termos canônicos corrigidos
      try {
        await db.customStatement(
          "UPDATE ticuna_words SET word = 'Duü\u0303', phonetics = 'du-ü\u0303 [nasal]', example_sentence = 'Duü\u0303 meã' WHERE word = 'Duũ' OR word = 'Duũũ' OR word LIKE 'Duũ%' OR word LIKE 'duũ%';",
        );
      } catch (e, st) {
        AppLogger.warning('Aviso na normalização de termos canônicos Ticuna: $e', e, st);
      }

      // Seed inicial de tags e vocabulário caso tabelas estejam vazias
      final wordsCount = await db
          .customSelect('SELECT COUNT(*) AS count FROM ticuna_words')
          .getSingle();
      if (wordsCount.read<int>('count') == 0) {
        await _seedInitialData();
      }
      _initialized = true;
      _initializationFailed = false;
      _initializationError = null;
      _refreshAll();
    } catch (e, st) {
      _initialized = false;
      _initializationFailed = true;
      _initializationError = e.toString();
      AppLogger.error(
        'Falha ao inicializar tabelas Ticuna: $e',
        e,
        st,
      );
    }
  }

  Future<void> _seedInitialData() async {
    final now = DateTime.now();

    // Tags padrão
    final defaultTags = [
      'Ministério',
      'Saudações',
      'Bíblia',
      'Deus',
      'Família',
      'Perguntas',
      'Revisita',
    ];
    for (final tag in defaultTags) {
      await db.customInsert(
        'INSERT OR IGNORE INTO ticuna_tags (id, name, created_at) VALUES (?, ?, ?)',
        variables: [
          Variable.withString(_uuid.v4()),
          Variable.withString(tag),
          Variable.withString(now.toIso8601String()),
        ],
      );
    }

    // Vocabulário padrão autêntico Ticuna (Dicionário / Flashcards)
    final defaultWords = [
      TicunaWord(
        id: _uuid.v4(),
        word: 'Taemãẽ',
        translation: 'Obrigado / Muito obrigado',
        phonetics: 'ta-e-mã-ẽ',
        grammaticalClass: 'Interjeição',
        exampleSentence: 'Taemãẽ Tupana',
        exampleTranslation: 'Obrigado a Deus',
        notes: 'Expressão de gratidão universal.',
        tags: const ['Saudações', 'Ministério'],
        isFavorite: true,
        createdAt: now,
        updatedAt: now,
      ),
      TicunaWord(
        id: _uuid.v4(),
        word: 'Tamaü',
        translation: 'Olá / Paz / Bom dia',
        phonetics: 'ta-ma-ü',
        grammaticalClass: 'Saudação',
        exampleSentence: 'Tamaü! Ku meã pe\'ĩ?',
        exampleTranslation: 'Olá! Tudo bem com você?',
        notes: 'Saudação respeitosa comum ao bater de porta em porta.',
        tags: const ['Saudações', 'Ministério'],
        isFavorite: true,
        createdAt: now,
        updatedAt: now,
      ),
      TicunaWord(
        id: _uuid.v4(),
        word: 'Tupana',
        translation: 'Deus / Jeová',
        phonetics: 'tu-pa-na',
        grammaticalClass: 'Substantivo',
        exampleSentence: 'Tupana ngi\'ũ meã',
        exampleTranslation: 'Deus é bom',
        notes: 'Nome empregado para se referir ao Criador e a Jeová.',
        tags: const ['Deus', 'Bíblia'],
        isFavorite: true,
        createdAt: now,
        updatedAt: now,
      ),
      TicunaWord(
        id: _uuid.v4(),
        word: 'Bíblia',
        translation: 'Bíblia / Livro Sagrado',
        phonetics: 'bí-bli-a',
        grammaticalClass: 'Substantivo',
        exampleSentence: 'Bíblia nangü ye\'ẽ',
        exampleTranslation: 'A Bíblia diz isso',
        notes: 'Referência às Sagradas Escrituras.',
        tags: const ['Bíblia', 'Ministério'],
        isFavorite: true,
        createdAt: now,
        updatedAt: now,
      ),
      TicunaWord(
        id: _uuid.v4(),
        word: 'Yegorü',
        translation: 'Boas novas / Mensagem boa',
        phonetics: 'ye-go-rü',
        grammaticalClass: 'Substantivo',
        exampleSentence: 'Yegorü meã ga Tupana arü Reino',
        exampleTranslation: 'Boas novas do Reino de Deus',
        notes: 'Termo central para a pregação do evangelho.',
        tags: const ['Ministério', 'Bíblia'],
        isFavorite: true,
        createdAt: now,
        updatedAt: now,
      ),
      TicunaWord(
        id: _uuid.v4(),
        word: 'Duü̃',
        translation: 'Pessoa / Pessoas / Gente',
        phonetics: 'du-ü̃ [nasal]',
        grammaticalClass: 'Substantivo',
        exampleSentence: 'Duü̃ meã',
        exampleTranslation: 'Pessoas boas / Gente bondosa',
        notes: 'Refere-se ao ser humano ou povo.',
        tags: const ['Ministério'],
        createdAt: now,
        updatedAt: now,
      ),
      TicunaWord(
        id: _uuid.v4(),
        word: 'Nügũ',
        translation: 'Irmão / Amigo',
        phonetics: 'nü-gũ',
        grammaticalClass: 'Substantivo',
        exampleSentence: 'Nügũ meã',
        exampleTranslation: 'Meu irmão / meu amigo',
        notes: 'Forma cordial e fraterna de tratamento.',
        tags: const ['Família', 'Saudações'],
        createdAt: now,
        updatedAt: now,
      ),
      TicunaWord(
        id: _uuid.v4(),
        word: 'Naãnetü',
        translation: 'Coração / Mente sincera',
        phonetics: 'na-ã-ne-tü',
        grammaticalClass: 'Substantivo',
        exampleSentence: 'Naãnetü meã',
        exampleTranslation: 'De coração puro e bom',
        notes: 'Usado para falar sobre sentimentos e fé íntima.',
        tags: const ['Bíblia'],
        createdAt: now,
        updatedAt: now,
      ),
      TicunaWord(
        id: _uuid.v4(),
        word: 'Taü̃',
        translation: 'Palavra / Mensagem / Voz',
        phonetics: 'ta-ü̃',
        grammaticalClass: 'Substantivo',
        exampleSentence: 'Tupana arü taü̃',
        exampleTranslation: 'A palavra de Deus',
        notes: 'Refere-se ao que foi dito ou escrito.',
        tags: const ['Deus', 'Bíblia'],
        createdAt: now,
        updatedAt: now,
      ),
      TicunaWord(
        id: _uuid.v4(),
        word: 'Meã',
        translation: 'Bom / Bem / Paz',
        phonetics: 'me-ã',
        grammaticalClass: 'Adjetivo',
        exampleSentence: 'Meã nangü',
        exampleTranslation: 'Está tudo bem / É bom',
        notes: 'Um dos adjetivos mais utilizados no cotidiano.',
        tags: const ['Saudações'],
        createdAt: now,
        updatedAt: now,
      ),
      TicunaWord(
        id: _uuid.v4(),
        word: 'Ü̃́',
        translation: 'Ele / Ela / Aquele(a)',
        phonetics: 'ü̃́ [tom alto]',
        grammaticalClass: 'Pronome',
        exampleSentence: 'Ü̃́ Tupana arü duü̃',
        exampleTranslation: 'Aquele servo de Deus',
        notes: 'Pronome de terceira pessoa com acento alto nasal.',
        tags: const ['Bíblia'],
        createdAt: now,
        updatedAt: now,
      ),
      TicunaWord(
        id: _uuid.v4(),
        word: 'Ũma',
        translation: 'Não / Não há',
        phonetics: 'ũ-ma',
        grammaticalClass: 'Advérbio',
        exampleSentence: 'Ũma ngĩ',
        exampleTranslation: 'Não é assim',
        notes: 'Advérbio de negação.',
        tags: const ['Perguntas'],
        createdAt: now,
        updatedAt: now,
      ),
    ];

    for (final w in defaultWords) {
      await _insertWordDirect(w);
    }

    // Frases úteis padrão para o ministério
    final defaultPhrases = [
      TicunaPhrase(
        id: _uuid.v4(),
        phrase: 'Tamaü! Ku meã pe\'ĩ?',
        translation: 'Olá! Você está bem?',
        category: 'Saudação & Conversa',
        phonetics: 'ta-ma-ü! ku me-ã pe-ĩ?',
        notes: 'Saudação inicial ao chegar na residência.',
        tags: const ['Saudações', 'Ministério'],
        isFavorite: true,
        createdAt: now,
        updatedAt: now,
      ),
      TicunaPhrase(
        id: _uuid.v4(),
        phrase: 'Tupana ü̃́ meã ngi\'ũ com duü̃.',
        translation: 'Deus quer o bem de todas as pessoas.',
        category: 'Ministério de Casa em Casa',
        phonetics: 'tu-pa-na ü̃́ me-ã ngi-ũ com du-ü̃.',
        notes: 'Frase de impacto para início de testemunho.',
        tags: const ['Ministério', 'Deus'],
        isFavorite: true,
        createdAt: now,
        updatedAt: now,
      ),
      TicunaPhrase(
        id: _uuid.v4(),
        phrase: 'Yegorü meã ga Tupana arü Reino.',
        translation: 'Boas novas sobre o Reino de Deus.',
        category: 'Ministério de Casa em Casa',
        phonetics: 'ye-go-rü me-ã ga tu-pa-na a-rü rei-no.',
        notes: 'Apresentação do tema principal da pregação.',
        tags: const ['Ministério', 'Bíblia'],
        isFavorite: true,
        createdAt: now,
        updatedAt: now,
      ),
      TicunaPhrase(
        id: _uuid.v4(),
        phrase: 'Bíblia nangü ye\'ẽ Salmo 37:29.',
        translation: 'A Bíblia diz isso no Salmo 37:29.',
        category: 'Leitura Bíblica',
        phonetics: 'bí-bli-a na-ngü ye-ẽ...',
        notes: 'Convite para ler um versículo na Bíblia.',
        tags: const ['Bíblia', 'Ministério'],
        isFavorite: true,
        createdAt: now,
        updatedAt: now,
      ),
      TicunaPhrase(
        id: _uuid.v4(),
        phrase: 'Ku nangü ta\'acü Bíblia nixũ?',
        translation: 'O que você acha sobre a Bíblia?',
        category: 'Perguntas de Ponto de Vista',
        phonetics: 'ku na-ngü ta-a-cü bí-bli-a ni-xũ?',
        notes: 'Pergunta amigável de ponto de vista.',
        tags: const ['Perguntas', 'Ministério'],
        isFavorite: true,
        createdAt: now,
        updatedAt: now,
      ),
      TicunaPhrase(
        id: _uuid.v4(),
        phrase: 'Pa ga tora gu ü̃ duü̃ rü meã gu Bíblia arü estudo.',
        translation: 'Gostaríamos de conversar sobre um estudo bíblico gratuito.',
        category: 'Oferecer Estudo',
        phonetics: 'pa ga to-ra...',
        notes: 'Oferta de estudo do manual Seja Feliz Para Sempre!.',
        tags: const ['Ministério'],
        createdAt: now,
        updatedAt: now,
      ),
      TicunaPhrase(
        id: _uuid.v4(),
        phrase: 'Kawa\'ne nügũ rü taemãẽ.',
        translation: 'Até logo e muito obrigado, meu irmão!',
        category: 'Saudação & Conversa',
        phonetics: 'ka-wa-ne nü-gũ rü ta-e-mã-ẽ.',
        notes: 'Despedida cordial após a conversa.',
        tags: const ['Saudações'],
        isFavorite: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    for (final p in defaultPhrases) {
      await _insertPhraseDirect(p);
    }
  }

  void _refreshAll() {
    _refreshWords();
    _refreshPhrases();
    _refreshTags();
  }

  Future<void> _refreshWords() async {
    try {
      final list = await getAllWords();
      if (!_wordsController.isClosed) {
        _wordsController.add(list);
      }
    } catch (e, st) {
      AppLogger.error('Erro ao atualizar stream de palavras Ticuna: $e', e, st);
    }
  }

  Future<void> _refreshPhrases() async {
    try {
      final list = await getAllPhrases();
      if (!_phrasesController.isClosed) {
        _phrasesController.add(list);
      }
    } catch (e, st) {
      AppLogger.error('Erro ao atualizar stream de frases Ticuna: $e', e, st);
    }
  }

  Future<void> _refreshTags() async {
    try {
      final list = await getAllTags();
      if (!_tagsController.isClosed) {
        _tagsController.add(list);
      }
    } catch (e, st) {
      AppLogger.error('Erro ao atualizar stream de tags Ticuna: $e', e, st);
    }
  }

  // ==========================================
  // OPERAÇÕES DO DICIONÁRIO (FLASHCARDS / ANKI)
  // ==========================================

  Future<List<TicunaWord>> getAllWords({
    String? searchQuery,
    String? tag,
    bool onlyFavorites = false,
    String? grammaticalClass,
  }) async {
    await _initTables();
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ticuna_words ORDER BY word ASC',
      ).get();

      var list = rows.map((r) => TicunaWord.fromMap(r.data)).toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = TicunaUnicodeHelper.normalize(searchQuery.trim().toLowerCase());
        list = list.where((w) {
          final wordNorm = TicunaUnicodeHelper.normalize(w.word.toLowerCase());
          return wordNorm.contains(q) ||
              w.translation.toLowerCase().contains(q) ||
              (w.phonetics?.toLowerCase().contains(q) ?? false) ||
              (w.notes?.toLowerCase().contains(q) ?? false) ||
              (w.exampleSentence != null &&
                  TicunaUnicodeHelper.normalize(w.exampleSentence!.toLowerCase()).contains(q)) ||
              (w.exampleTranslation?.toLowerCase().contains(q) ?? false);
        }).toList();
      }

      if (tag != null && tag.isNotEmpty && tag != 'Todos') {
        list = list.where((w) => w.tags.contains(tag)).toList();
      }

      if (onlyFavorites) {
        list = list.where((w) => w.isFavorite).toList();
      }

      if (grammaticalClass != null &&
          grammaticalClass.isNotEmpty &&
          grammaticalClass != 'Todas') {
        list = list.where((w) => w.grammaticalClass == grammaticalClass).toList();
      }

      return list;
    } catch (e, st) {
      AppLogger.error('Erro ao buscar palavras Ticuna: $e', e, st);
      return [];
    }
  }

  Stream<List<TicunaWord>> watchWords() async* {
    yield await getAllWords();
    yield* _wordsController.stream;
  }

  Future<TicunaWord> addWord({
    required String word,
    required String translation,
    String? phonetics,
    String? grammaticalClass,
    String? exampleSentence,
    String? exampleTranslation,
    String? notes,
    List<String> tags = const [],
    bool isFavorite = false,
    String? audioPath,
    int? audioDurationSeconds,
  }) async {
    await _initTables();
    final now = DateTime.now();
    final item = TicunaWord(
      id: _uuid.v4(),
      word: TicunaUnicodeHelper.normalize(word.trim()),
      translation: translation.trim(),
      phonetics: phonetics?.trim().isEmpty ?? true ? null : phonetics!.trim(),
      grammaticalClass: grammaticalClass?.trim().isEmpty ?? true
          ? null
          : grammaticalClass!.trim(),
      exampleSentence: exampleSentence?.trim().isEmpty ?? true
          ? null
          : TicunaUnicodeHelper.normalize(exampleSentence!.trim()),
      exampleTranslation: exampleTranslation?.trim().isEmpty ?? true
          ? null
          : exampleTranslation!.trim(),
      notes: notes?.trim().isEmpty ?? true ? null : notes!.trim(),
      tags: tags,
      isFavorite: isFavorite,
      reviewLevel: 0,
      reviewCount: 0,
      audioPath: audioPath,
      audioDurationSeconds: audioDurationSeconds,
      createdAt: now,
      updatedAt: now,
    );

    await db.transaction(() async {
      await _insertWordDirect(item);
      await _enqueueSync('ticuna_words', item.id, 'INSERT', item.toMap());
    });
    await _refreshWords();
    return item;
  }

  Future<void> _insertWordDirect(TicunaWord item) async {
    await db.customInsert(
      '''
      INSERT OR REPLACE INTO ticuna_words (
        id, word, translation, phonetics, grammatical_class,
        example_sentence, example_translation, notes, tags,
        is_favorite, review_level, review_count, last_reviewed_at,
        audio_path, audio_duration_seconds,
        created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      variables: [
        Variable.withString(item.id),
        Variable.withString(item.word),
        Variable.withString(item.translation),
        Variable.withString(item.phonetics ?? ''),
        Variable.withString(item.grammaticalClass ?? ''),
        Variable.withString(item.exampleSentence ?? ''),
        Variable.withString(item.exampleTranslation ?? ''),
        Variable.withString(item.notes ?? ''),
        Variable.withString(jsonEncode(item.tags)),
        Variable.withInt(item.isFavorite ? 1 : 0),
        Variable.withInt(item.reviewLevel),
        Variable.withInt(item.reviewCount),
        Variable.withString(item.lastReviewedAt?.toIso8601String() ?? ''),
        Variable.withString(item.audioPath ?? ''),
        Variable.withInt(item.audioDurationSeconds ?? 0),
        Variable.withString(item.createdAt.toIso8601String()),
        Variable.withString(item.updatedAt.toIso8601String()),
      ],
    );
  }

  Future<void> updateWord(TicunaWord item) async {
    await _initTables();
    final now = DateTime.now();
    await db.transaction(() async {
      await db.customUpdate(
        '''
        UPDATE ticuna_words SET
          word = ?,
          translation = ?,
          phonetics = ?,
          grammatical_class = ?,
          example_sentence = ?,
          example_translation = ?,
          notes = ?,
          tags = ?,
          is_favorite = ?,
          review_level = ?,
          review_count = ?,
          last_reviewed_at = ?,
          audio_path = ?,
          audio_duration_seconds = ?,
          updated_at = ?
        WHERE id = ?
        ''',
        variables: [
          Variable.withString(TicunaUnicodeHelper.normalize(item.word.trim())),
          Variable.withString(item.translation.trim()),
          Variable.withString(item.phonetics?.trim() ?? ''),
          Variable.withString(item.grammaticalClass?.trim() ?? ''),
          Variable.withString(item.exampleSentence != null
              ? TicunaUnicodeHelper.normalize(item.exampleSentence!.trim())
              : ''),
          Variable.withString(item.exampleTranslation?.trim() ?? ''),
          Variable.withString(item.notes?.trim() ?? ''),
          Variable.withString(jsonEncode(item.tags)),
          Variable.withInt(item.isFavorite ? 1 : 0),
          Variable.withInt(item.reviewLevel),
          Variable.withInt(item.reviewCount),
          Variable.withString(item.lastReviewedAt?.toIso8601String() ?? ''),
          Variable.withString(item.audioPath ?? ''),
          Variable.withInt(item.audioDurationSeconds ?? 0),
          Variable.withString(now.toIso8601String()),
          Variable.withString(item.id),
        ],
      );
      await _enqueueSync('ticuna_words', item.id, 'UPDATE', item.toMap());
    });
    await _refreshWords();
  }

  Future<void> deleteWord(String id) async {
    await _initTables();
    await db.transaction(() async {
      await db.customUpdate(
        'DELETE FROM ticuna_words WHERE id = ?',
        variables: [Variable.withString(id)],
      );
      await _enqueueSync('ticuna_words', id, 'DELETE', {'id': id});
    });
    await _refreshWords();
  }

  Future<void> updateWordAudio(
    String wordId,
    String? audioPath, {
    int? durationSeconds,
  }) async {
    await _initTables();
    final now = DateTime.now();
    await db.transaction(() async {
      await db.customUpdate(
        '''
        UPDATE ticuna_words SET
          audio_path = ?,
          audio_duration_seconds = ?,
          updated_at = ?
        WHERE id = ?
        ''',
        variables: [
          Variable.withString(audioPath ?? ''),
          Variable.withInt(durationSeconds ?? 0),
          Variable.withString(now.toIso8601String()),
          Variable.withString(wordId),
        ],
      );
      await _enqueueSync('ticuna_words', wordId, 'UPDATE', {
        'id': wordId,
        'audio_path': audioPath,
        'audio_duration_seconds': durationSeconds,
        'updated_at': now.toIso8601String(),
      });
    });
    await _refreshWords();
  }

  Future<void> deleteWordAudio(String wordId) async {
    await updateWordAudio(wordId, null, durationSeconds: 0);
  }

  Future<void> toggleWordFavorite(String id) async {
    await _initTables();
    final rows = await db.customSelect(
      'SELECT is_favorite FROM ticuna_words WHERE id = ?',
      variables: [Variable.withString(id)],
    ).get();

    if (rows.isNotEmpty) {
      final current = rows.first.read<int>('is_favorite') == 1;
      final newFav = current ? 0 : 1;
      final now = DateTime.now();
      await db.transaction(() async {
        await db.customUpdate(
          'UPDATE ticuna_words SET is_favorite = ?, updated_at = ? WHERE id = ?',
          variables: [
            Variable.withInt(newFav),
            Variable.withString(now.toIso8601String()),
            Variable.withString(id),
          ],
        );
        await _enqueueSync('ticuna_words', id, 'UPDATE', {
          'id': id,
          'is_favorite': newFav == 1,
          'updated_at': now.toIso8601String(),
        });
      });
      await _refreshWords();
    }
  }

  /// Registra uma sessão de revisão no estilo Anki (1=De novo, 2=Bom, 3=Fácil)
  Future<void> recordWordReview(String id, int rating) async {
    await _initTables();
    final rows = await db.customSelect(
      'SELECT review_level, review_count FROM ticuna_words WHERE id = ?',
      variables: [Variable.withString(id)],
    ).get();

    if (rows.isNotEmpty) {
      final currentLevel = rows.first.read<int>('review_level');
      final currentCount = rows.first.read<int>('review_count');

      int newLevel;
      if (rating <= 1) {
        newLevel = 1; // Reinicia para o nível de aprendizado
      } else if (rating == 2) {
        newLevel = currentLevel + 1; // Avança 1 nível
      } else {
        newLevel = currentLevel + 2; // Avança 2 níveis (Fácil)
      }
      if (newLevel > 5) newLevel = 5;

      final now = DateTime.now();
      await db.transaction(() async {
        await db.customUpdate(
          '''
          UPDATE ticuna_words SET
            review_level = ?,
            review_count = ?,
            last_reviewed_at = ?,
            updated_at = ?
          WHERE id = ?
          ''',
          variables: [
            Variable.withInt(newLevel),
            Variable.withInt(currentCount + 1),
            Variable.withString(now.toIso8601String()),
            Variable.withString(now.toIso8601String()),
            Variable.withString(id),
          ],
        );
        await _enqueueSync('ticuna_words', id, 'UPDATE', {
          'id': id,
          'review_level': newLevel,
          'review_count': currentCount + 1,
          'last_reviewed_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
      });
      await _refreshWords();
    }
  }

  // ==========================================
  // OPERAÇÕES DE FRASES ÚTEIS
  // ==========================================

  Future<List<TicunaPhrase>> getAllPhrases({
    String? searchQuery,
    String? tag,
    bool onlyFavorites = false,
    String? category,
  }) async {
    await _initTables();
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ticuna_phrases ORDER BY phrase ASC',
      ).get();

      var list = rows.map((r) => TicunaPhrase.fromMap(r.data)).toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = TicunaUnicodeHelper.normalize(searchQuery.trim().toLowerCase());
        list = list.where((p) {
          final phraseNorm = TicunaUnicodeHelper.normalize(p.phrase.toLowerCase());
          return phraseNorm.contains(q) ||
              p.translation.toLowerCase().contains(q) ||
              (p.phonetics?.toLowerCase().contains(q) ?? false) ||
              (p.notes?.toLowerCase().contains(q) ?? false) ||
              (p.category?.toLowerCase().contains(q) ?? false);
        }).toList();
      }

      if (tag != null && tag.isNotEmpty && tag != 'Todos') {
        list = list.where((p) => p.tags.contains(tag)).toList();
      }

      if (onlyFavorites) {
        list = list.where((p) => p.isFavorite).toList();
      }

      if (category != null && category.isNotEmpty && category != 'Todas') {
        list = list.where((p) => p.category == category).toList();
      }

      return list;
    } catch (e, st) {
      AppLogger.error('Erro ao buscar frases Ticuna: $e', e, st);
      return [];
    }
  }

  Stream<List<TicunaPhrase>> watchPhrases() async* {
    yield await getAllPhrases();
    yield* _phrasesController.stream;
  }

  Future<TicunaPhrase> addPhrase({
    required String phrase,
    required String translation,
    String? category,
    String? phonetics,
    String? notes,
    List<String> tags = const [],
    bool isFavorite = false,
    String? audioPath,
    int? audioDurationSeconds,
  }) async {
    await _initTables();
    final now = DateTime.now();
    final item = TicunaPhrase(
      id: _uuid.v4(),
      phrase: TicunaUnicodeHelper.normalize(phrase.trim()),
      translation: translation.trim(),
      category: category?.trim().isEmpty ?? true ? null : category!.trim(),
      phonetics: phonetics?.trim().isEmpty ?? true ? null : phonetics!.trim(),
      notes: notes?.trim().isEmpty ?? true ? null : notes!.trim(),
      tags: tags,
      isFavorite: isFavorite,
      audioPath: audioPath,
      audioDurationSeconds: audioDurationSeconds,
      createdAt: now,
      updatedAt: now,
    );

    await db.transaction(() async {
      await _insertPhraseDirect(item);
      await _enqueueSync('ticuna_phrases', item.id, 'INSERT', item.toMap());
    });
    await _refreshPhrases();
    return item;
  }

  Future<void> _insertPhraseDirect(TicunaPhrase item) async {
    await db.customInsert(
      '''
      INSERT OR REPLACE INTO ticuna_phrases (
        id, phrase, translation, category, phonetics, notes,
        tags, is_favorite, audio_path, audio_duration_seconds,
        created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      variables: [
        Variable.withString(item.id),
        Variable.withString(item.phrase),
        Variable.withString(item.translation),
        Variable.withString(item.category ?? ''),
        Variable.withString(item.phonetics ?? ''),
        Variable.withString(item.notes ?? ''),
        Variable.withString(jsonEncode(item.tags)),
        Variable.withInt(item.isFavorite ? 1 : 0),
        Variable.withString(item.audioPath ?? ''),
        Variable.withInt(item.audioDurationSeconds ?? 0),
        Variable.withString(item.createdAt.toIso8601String()),
        Variable.withString(item.updatedAt.toIso8601String()),
      ],
    );
  }

  Future<void> updatePhrase(TicunaPhrase item) async {
    await _initTables();
    final now = DateTime.now();
    await db.transaction(() async {
      await db.customUpdate(
        '''
        UPDATE ticuna_phrases SET
          phrase = ?,
          translation = ?,
          category = ?,
          phonetics = ?,
          notes = ?,
          tags = ?,
          is_favorite = ?,
          audio_path = ?,
          audio_duration_seconds = ?,
          updated_at = ?
        WHERE id = ?
        ''',
        variables: [
          Variable.withString(TicunaUnicodeHelper.normalize(item.phrase.trim())),
          Variable.withString(item.translation.trim()),
          Variable.withString(item.category?.trim() ?? ''),
          Variable.withString(item.phonetics?.trim() ?? ''),
          Variable.withString(item.notes?.trim() ?? ''),
          Variable.withString(jsonEncode(item.tags)),
          Variable.withInt(item.isFavorite ? 1 : 0),
          Variable.withString(item.audioPath ?? ''),
          Variable.withInt(item.audioDurationSeconds ?? 0),
          Variable.withString(now.toIso8601String()),
          Variable.withString(item.id),
        ],
      );
      await _enqueueSync('ticuna_phrases', item.id, 'UPDATE', item.toMap());
    });
    await _refreshPhrases();
  }

  Future<void> updatePhraseAudio(
    String phraseId,
    String? audioPath, {
    int? durationSeconds,
  }) async {
    await _initTables();
    final now = DateTime.now();
    await db.transaction(() async {
      await db.customUpdate(
        '''
        UPDATE ticuna_phrases SET
          audio_path = ?,
          audio_duration_seconds = ?,
          updated_at = ?
        WHERE id = ?
        ''',
        variables: [
          Variable.withString(audioPath ?? ''),
          Variable.withInt(durationSeconds ?? 0),
          Variable.withString(now.toIso8601String()),
          Variable.withString(phraseId),
        ],
      );
      await _enqueueSync('ticuna_phrases', phraseId, 'UPDATE', {
        'id': phraseId,
        'audio_path': audioPath,
        'audio_duration_seconds': durationSeconds,
        'updated_at': now.toIso8601String(),
      });
    });
    await _refreshPhrases();
  }

  Future<void> deletePhraseAudio(String phraseId) async {
    await updatePhraseAudio(phraseId, null, durationSeconds: 0);
  }

  Future<void> deletePhrase(String id) async {
    await _initTables();
    await db.transaction(() async {
      await db.customUpdate(
        'DELETE FROM ticuna_phrases WHERE id = ?',
        variables: [Variable.withString(id)],
      );
      await _enqueueSync('ticuna_phrases', id, 'DELETE', {'id': id});
    });
    await _refreshPhrases();
  }

  Future<void> togglePhraseFavorite(String id) async {
    await _initTables();
    final rows = await db.customSelect(
      'SELECT is_favorite FROM ticuna_phrases WHERE id = ?',
      variables: [Variable.withString(id)],
    ).get();

    if (rows.isNotEmpty) {
      final current = rows.first.read<int>('is_favorite') == 1;
      final newFav = current ? 0 : 1;
      final now = DateTime.now();
      await db.transaction(() async {
        await db.customUpdate(
          'UPDATE ticuna_phrases SET is_favorite = ?, updated_at = ? WHERE id = ?',
          variables: [
            Variable.withInt(newFav),
            Variable.withString(now.toIso8601String()),
            Variable.withString(id),
          ],
        );
        await _enqueueSync('ticuna_phrases', id, 'UPDATE', {
          'id': id,
          'is_favorite': newFav == 1,
          'updated_at': now.toIso8601String(),
        });
      });
      await _refreshPhrases();
    }
  }

  // ==========================================
  // OPERAÇÕES DE TAGS
  // ==========================================

  Future<List<TicunaTag>> getAllTags() async {
    await _initTables();
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ticuna_tags ORDER BY name ASC',
      ).get();
      return rows.map((r) => TicunaTag.fromMap(r.data)).toList();
    } catch (e, st) {
      AppLogger.error('Erro ao buscar tags Ticuna: $e', e, st);
      return [];
    }
  }

  Stream<List<TicunaTag>> watchTags() async* {
    yield await getAllTags();
    yield* _tagsController.stream;
  }

  Future<TicunaTag> addTag(String name) async {
    await _initTables();
    final trimmed = name.trim();
    final id = _uuid.v4();
    final now = DateTime.now();

    await db.customInsert(
      'INSERT OR IGNORE INTO ticuna_tags (id, name, created_at) VALUES (?, ?, ?)',
      variables: [
        Variable.withString(id),
        Variable.withString(trimmed),
        Variable.withString(now.toIso8601String()),
      ],
    );

    final item = TicunaTag(id: id, name: trimmed, createdAt: now);
    await _refreshTags();
    return item;
  }

  Future<void> deleteTag(String id) async {
    await _initTables();
    await db.customUpdate(
      'DELETE FROM ticuna_tags WHERE id = ?',
      variables: [Variable.withString(id)],
    );
    await _refreshTags();
  }

  // ==========================================
  // IMPORTAÇÃO E EXPORTAÇÃO (JSON & CSV)
  // ==========================================

  /// Exporta o banco de dados completo de Ticuna em formato JSON formatado
  Future<String> exportToJson() async {
    await _initTables();
    final words = await getAllWords();
    final phrases = await getAllPhrases();
    final tags = await getAllTags();

    final exportData = TicunaExportData(
      version: 1,
      exportedAt: DateTime.now(),
      words: words,
      phrases: phrases,
      tags: tags,
    );

    return exportData.toJson();
  }

  /// Exporta o dicionário ou as frases em formato CSV limpo
  Future<String> exportToCsv(TicunaEntryType type) async {
    await _initTables();
    final buffer = StringBuffer();

    if (type == TicunaEntryType.word) {
      buffer.writeln('word,translation,phonetics,grammatical_class,example_sentence,example_translation,notes,tags');
      final words = await getAllWords();
      for (final w in words) {
        final tagsStr = w.tags.join(';');
        buffer.writeln(
          '"${w.word.replaceAll('"', '""')}","${w.translation.replaceAll('"', '""')}","${(w.phonetics ?? '').replaceAll('"', '""')}","${(w.grammaticalClass ?? '').replaceAll('"', '""')}","${(w.exampleSentence ?? '').replaceAll('"', '""')}","${(w.exampleTranslation ?? '').replaceAll('"', '""')}","${(w.notes ?? '').replaceAll('"', '""')}","${tagsStr.replaceAll('"', '""')}"',
        );
      }
    } else {
      buffer.writeln('phrase,translation,category,phonetics,notes,tags');
      final phrases = await getAllPhrases();
      for (final p in phrases) {
        final tagsStr = p.tags.join(';');
        buffer.writeln(
          '"${p.phrase.replaceAll('"', '""')}","${p.translation.replaceAll('"', '""')}","${(p.category ?? '').replaceAll('"', '""')}","${(p.phonetics ?? '').replaceAll('"', '""')}","${(p.notes ?? '').replaceAll('"', '""')}","${tagsStr.replaceAll('"', '""')}"',
        );
      }
    }

    return buffer.toString();
  }

  /// Importa dados a partir de uma string JSON (mesclando ou substituindo)
  Future<TicunaImportResult> importFromJson(
    String jsonString, {
    bool replace = false,
  }) async {
    await _initTables();
    try {
      final data = TicunaExportData.fromJson(jsonString);

      if (replace) {
        await db.customUpdate('DELETE FROM ticuna_words');
        await db.customUpdate('DELETE FROM ticuna_phrases');
        await db.customUpdate('DELETE FROM ticuna_tags');
      }

      int wordsImported = 0;
      int phrasesImported = 0;
      int tagsImported = 0;

      for (final tag in data.tags) {
        await db.customInsert(
          'INSERT OR IGNORE INTO ticuna_tags (id, name, created_at) VALUES (?, ?, ?)',
          variables: [
            Variable.withString(tag.id.isEmpty ? _uuid.v4() : tag.id),
            Variable.withString(tag.name.trim()),
            Variable.withString(tag.createdAt.toIso8601String()),
          ],
        );
        tagsImported++;
      }

      for (final word in data.words) {
        final id = word.id.isEmpty ? _uuid.v4() : word.id;
        await _insertWordDirect(word.copyWith(id: id));
        wordsImported++;
      }

      for (final phrase in data.phrases) {
        final id = phrase.id.isEmpty ? _uuid.v4() : phrase.id;
        await _insertPhraseDirect(phrase.copyWith(id: id));
        phrasesImported++;
      }

      _refreshAll();

      return TicunaImportResult(
        wordsCount: wordsImported,
        phrasesCount: phrasesImported,
        tagsCount: tagsImported,
        success: true,
      );
    } catch (e, st) {
      AppLogger.error('Erro ao importar backup JSON Ticuna: $e', e, st);
      return TicunaImportResult(
        wordsCount: 0,
        phrasesCount: 0,
        tagsCount: 0,
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Retorna os termos que precisam de revisão hoje pelo algoritmo de repetição espaçada (Leitner / Anki)
  Future<List<TicunaWord>> getDueWordsForReview() async {
    final all = await getAllWords();
    return all.where((w) => w.isDueForReview).toList();
  }

  /// Importa dados detectando automaticamente se o formato é JSON (backup completo ou array de termos) ou CSV
  Future<TicunaImportResult> importAuto(
    String content, {
    bool replace = false,
    TicunaEntryType defaultType = TicunaEntryType.word,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return const TicunaImportResult(
        wordsCount: 0,
        phrasesCount: 0,
        tagsCount: 0,
        success: false,
        errorMessage: 'Conteúdo vazio para importação',
      );
    }

    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      return importFromJson(trimmed, replace: replace);
    }

    final firstLine = trimmed.split(RegExp(r'[\r\n]')).first.toLowerCase();
    final type = (firstLine.contains('phrase') || firstLine.contains('frase'))
        ? TicunaEntryType.phrase
        : defaultType;
    return importFromCsv(trimmed, type, replace: replace);
  }

  /// Importa termos ou frases a partir de CSV compatível com RFC 4180
  Future<TicunaImportResult> importFromCsv(
    String csvContent,
    TicunaEntryType type, {
    bool replace = false,
  }) async {
    await _initTables();
    try {
      final records = _parseCsvRecords(csvContent);
      if (records.isEmpty) {
        return const TicunaImportResult(
          wordsCount: 0,
          phrasesCount: 0,
          tagsCount: 0,
          success: false,
          errorMessage: 'Arquivo CSV vazio',
        );
      }

      if (replace) {
        if (type == TicunaEntryType.word) {
          await db.customUpdate('DELETE FROM ticuna_words');
        } else {
          await db.customUpdate('DELETE FROM ticuna_phrases');
        }
      }

      int count = 0;
      final now = DateTime.now();

      // Pula cabeçalho se houver
      final dataRecords = records.first.isNotEmpty &&
              (records.first[0].toLowerCase().contains('word') ||
                  records.first[0].toLowerCase().contains('phrase') ||
                  records.first[0].toLowerCase().contains('palavra') ||
                  records.first[0].toLowerCase().contains('frase'))
          ? records.skip(1)
          : records;

      for (final parts in dataRecords) {
        if (parts.length < 2) continue;

        if (type == TicunaEntryType.word) {
          final word = parts[0].trim();
          final translation = parts[1].trim();
          final phonetics = parts.length > 2 ? parts[2].trim() : null;
          final grammaticalClass = parts.length > 3 ? parts[3].trim() : null;
          final exampleSentence = parts.length > 4 ? parts[4].trim() : null;
          final exampleTranslation = parts.length > 5 ? parts[5].trim() : null;
          final notes = parts.length > 6 ? parts[6].trim() : null;
          final tags = parts.length > 7
              ? parts[7]
                  .split(RegExp(r'[;,]'))
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList()
              : <String>[];

          if (word.isNotEmpty && translation.isNotEmpty) {
            await _insertWordDirect(
              TicunaWord(
                id: _uuid.v4(),
                word: TicunaUnicodeHelper.normalize(word),
                translation: translation,
                phonetics: phonetics?.isEmpty ?? true ? null : phonetics,
                grammaticalClass:
                    grammaticalClass?.isEmpty ?? true ? null : grammaticalClass,
                exampleSentence:
                    (exampleSentence != null && exampleSentence.isNotEmpty)
                        ? TicunaUnicodeHelper.normalize(exampleSentence)
                        : null,
                exampleTranslation: exampleTranslation?.isEmpty ?? true
                    ? null
                    : exampleTranslation,
                notes: notes?.isEmpty ?? true ? null : notes,
                tags: tags,
                createdAt: now,
                updatedAt: now,
              ),
            );
            count++;
          }
        } else {
          final phrase = parts[0].trim();
          final translation = parts[1].trim();
          final category = parts.length > 2 ? parts[2].trim() : null;
          final phonetics = parts.length > 3 ? parts[3].trim() : null;
          final notes = parts.length > 4 ? parts[4].trim() : null;
          final tags = parts.length > 5
              ? parts[5]
                  .split(RegExp(r'[;,]'))
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList()
              : <String>[];

          if (phrase.isNotEmpty && translation.isNotEmpty) {
            await _insertPhraseDirect(
              TicunaPhrase(
                id: _uuid.v4(),
                phrase: TicunaUnicodeHelper.normalize(phrase),
                translation: translation,
                category: category?.isEmpty ?? true ? null : category,
                phonetics: phonetics?.isEmpty ?? true ? null : phonetics,
                notes: notes?.isEmpty ?? true ? null : notes,
                tags: tags,
                createdAt: now,
                updatedAt: now,
              ),
            );
            count++;
          }
        }
      }

      _refreshAll();

      return TicunaImportResult(
        wordsCount: type == TicunaEntryType.word ? count : 0,
        phrasesCount: type == TicunaEntryType.phrase ? count : 0,
        tagsCount: 0,
        success: true,
      );
    } catch (e, st) {
      AppLogger.error('Erro ao importar CSV Ticuna: $e', e, st);
      return TicunaImportResult(
        wordsCount: 0,
        phrasesCount: 0,
        tagsCount: 0,
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Parser CSV conforme RFC 4180 com suporte a quebras de linha e aspas duplas ""
  List<List<String>> _parseCsvRecords(String csvContent) {
    final records = <List<String>>[];
    final currentField = StringBuffer();
    final currentRecord = <String>[];
    bool inQuotes = false;

    for (int i = 0; i < csvContent.length; i++) {
      final char = csvContent[i];

      if (char == '"') {
        if (inQuotes && i + 1 < csvContent.length && csvContent[i + 1] == '"') {
          currentField.write('"');
          i++; // Pula aspas duplas escapadas ""
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        currentRecord.add(currentField.toString());
        currentField.clear();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' &&
            i + 1 < csvContent.length &&
            csvContent[i + 1] == '\n') {
          i++; // Pula \n de \r\n
        }
        currentRecord.add(currentField.toString());
        currentField.clear();
        if (currentRecord.any((f) => f.trim().isNotEmpty)) {
          records.add(List<String>.from(currentRecord));
        }
        currentRecord.clear();
      } else {
        currentField.write(char);
      }
    }

    if (currentField.isNotEmpty || currentRecord.isNotEmpty) {
      currentRecord.add(currentField.toString());
      if (currentRecord.any((f) => f.trim().isNotEmpty)) {
        records.add(currentRecord);
      }
    }

    return records;
  }
}
