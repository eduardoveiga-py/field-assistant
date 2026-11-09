import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/ticuna/models/ticuna_models.dart';
import 'package:ministerio_pessoal/ticuna/ticuna_repository.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;
  late TicunaRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TicunaRepository(db);
    // Aguarda inicialização e seeds
    await repo.getAllWords();
  });

  tearDown(() async {
    await db.close();
  });

  group('TicunaRepository - Inicialização e Seed Data', () {
    test('Inicializa tabelas e carrega vocabulário padrão autêntico Ticuna', () async {
      final words = await repo.getAllWords();
      expect(words.length, greaterThanOrEqualTo(10));
      expect(words.any((w) => w.word == 'Taemãẽ'), isTrue);
      expect(words.any((w) => w.word == 'Tamaü'), isTrue);
      expect(words.any((w) => w.word == 'Tupana'), isTrue);
      expect(words.any((w) => w.word == 'Duü̃'), isTrue);

      final phrases = await repo.getAllPhrases();
      expect(phrases.length, greaterThanOrEqualTo(5));
      expect(phrases.any((p) => p.phrase.contains('Tamaü')), isTrue);
      expect(phrases.any((p) => p.phrase.contains('Tupana')), isTrue);

      final tags = await repo.getAllTags();
      expect(tags.any((t) => t.name == 'Ministério'), isTrue);
      expect(tags.any((t) => t.name == 'Saudações'), isTrue);
    });

    test('Estado explícito de inicialização bem-sucedida', () async {
      expect(repo.isInitialized, isTrue);
      expect(repo.hasInitializationFailed, isFalse);
      expect(repo.initializationError, isNull);
    });

    test('Registra falha explícita quando a inicialização das tabelas falha', () async {
      final brokenDb = _FailingDatabase();
      final brokenRepo = TicunaRepository(brokenDb);
      final words = await brokenRepo.getAllWords();
      expect(words, isEmpty);
      expect(brokenRepo.isInitialized, isFalse);
      expect(brokenRepo.hasInitializationFailed, isTrue);
      expect(brokenRepo.initializationError, contains('Simulated database corruption'));
      await brokenDb.close();
    });
  });

  group('TicunaRepository - Dicionário (CRUD & Anki Spaced Repetition)', () {
    test('Adiciona, atualiza, favorita e exclui termo do dicionário', () async {
      final item = await repo.addWord(
        word: 'Ngoxü̃',
        translation: 'Todos / Juntos',
        phonetics: 'ngo-xü̃',
        grammaticalClass: 'Pronome',
        exampleSentence: 'Ngoxü̃ duü̃',
        exampleTranslation: 'Todas as pessoas',
        notes: 'Pronome quantificador coletivo.',
        tags: ['Ministério'],
      );

      expect(item.id, isNotEmpty);
      expect(item.word, equals('Ngoxü̃'));

      // Verifica recuperação
      var words = await repo.getAllWords(searchQuery: 'Ngoxü̃');
      expect(words.length, equals(1));
      expect(words.first.translation, equals('Todos / Juntos'));

      // Favorita
      await repo.toggleWordFavorite(item.id);
      words = await repo.getAllWords(searchQuery: 'Ngoxü̃');
      expect(words.first.isFavorite, isTrue);

      // Atualiza
      await repo.updateWord(
        words.first.copyWith(
          translation: 'Todos nós / Coletivo',
        ),
      );
      words = await repo.getAllWords(searchQuery: 'Ngoxü̃');
      expect(words.first.translation, equals('Todos nós / Coletivo'));

      // Exclui
      await repo.deleteWord(item.id);
      words = await repo.getAllWords(searchQuery: 'Ngoxü̃');
      expect(words, isEmpty);
    });

    test('recordWordReview aplica algoritmo de repetição espaçada estilo Anki', () async {
      final item = await repo.addWord(
        word: 'Yegorü Teste',
        translation: 'Boas novas teste',
      );

      expect(item.reviewLevel, equals(0));
      expect(item.reviewCount, equals(0));

      // Avaliação 2: "Bom" -> reviewLevel passa para 1, reviewCount = 1
      await repo.recordWordReview(item.id, 2);
      var words = await repo.getAllWords(searchQuery: 'Yegorü Teste');
      expect(words.first.reviewLevel, equals(1));
      expect(words.first.reviewCount, equals(1));
      expect(words.first.lastReviewedAt, isNotNull);

      // Avaliação 3: "Fácil" -> reviewLevel avança +2 (nível 3), reviewCount = 2
      await repo.recordWordReview(item.id, 3);
      words = await repo.getAllWords(searchQuery: 'Yegorü Teste');
      expect(words.first.reviewLevel, equals(3));
      expect(words.first.reviewCount, equals(2));

      // Avaliação 1: "Errei" (De novo) -> reviewLevel volta para 1, reviewCount = 3
      await repo.recordWordReview(item.id, 1);
      words = await repo.getAllWords(searchQuery: 'Yegorü Teste');
      expect(words.first.reviewLevel, equals(1));
      expect(words.first.reviewCount, equals(3));
    });

    test('Filtra termos por tag, favoritos e classe gramatical', () async {
      final favs = await repo.getAllWords(onlyFavorites: true);
      expect(favs.every((w) => w.isFavorite), isTrue);

      final minist = await repo.getAllWords(tag: 'Ministério');
      expect(minist.every((w) => w.tags.contains('Ministério')), isTrue);

      final substantivos = await repo.getAllWords(grammaticalClass: 'Substantivo');
      expect(substantivos.every((w) => w.grammaticalClass == 'Substantivo'), isTrue);
    });
  });

  group('TicunaRepository - Frases Úteis (CRUD)', () {
    test('Adiciona, atualiza, favorita e exclui frase útil', () async {
      final phrase = await repo.addPhrase(
        phrase: 'Pa ga rü meã!',
        translation: 'Que esteja tudo bem com você!',
        category: 'Saudação & Conversa',
        phonetics: 'pa ga rü me-ã!',
        notes: 'Expressão cordial para visitas.',
        tags: ['Saudações'],
        isFavorite: true,
      );

      expect(phrase.id, isNotEmpty);
      expect(phrase.isFavorite, isTrue);

      var phrases = await repo.getAllPhrases(searchQuery: 'Pa ga rü meã');
      expect(phrases.length, equals(1));
      expect(phrases.first.category, equals('Saudação & Conversa'));

      // Desfavorita
      await repo.togglePhraseFavorite(phrase.id);
      phrases = await repo.getAllPhrases(searchQuery: 'Pa ga rü meã');
      expect(phrases.first.isFavorite, isFalse);

      // Exclui
      await repo.deletePhrase(phrase.id);
      phrases = await repo.getAllPhrases(searchQuery: 'Pa ga rü meã');
      expect(phrases, isEmpty);
    });
  });

  group('TicunaRepository - Import & Export (JSON & CSV)', () {
    test('exportToJson e importFromJson realizam backup e restauração idempotente', () async {
      final jsonBackup = await repo.exportToJson();
      expect(jsonBackup, contains('"format": "ministerio_pessoal_ticuna_backup"'));
      expect(jsonBackup, contains('Taemãẽ'));
      expect(jsonBackup, contains('Tamaü'));

      // Importa mesclando (replace: false)
      final importResult = await repo.importFromJson(jsonBackup, replace: false);
      expect(importResult.success, isTrue);
      expect(importResult.wordsCount, greaterThan(0));
      expect(importResult.phrasesCount, greaterThan(0));

      // Importa substituindo tudo (replace: true)
      final replaceResult = await repo.importFromJson(jsonBackup, replace: true);
      expect(replaceResult.success, isTrue);
      final wordsAfter = await repo.getAllWords();
      expect(wordsAfter.isNotEmpty, isTrue);
    });

    test('exportToCsv e importFromCsv realizam exportação e importação tabular', () async {
      final wordsCsv = await repo.exportToCsv(TicunaEntryType.word);
      expect(wordsCsv, startsWith('word,translation,phonetics'));
      expect(wordsCsv, contains('Taemãẽ'));

      final phrasesCsv = await repo.exportToCsv(TicunaEntryType.phrase);
      expect(phrasesCsv, startsWith('phrase,translation,category'));

      // Importa CSV de palavras
      const customCsv = '''word,translation,phonetics,grammatical_class,example_sentence,example_translation,notes,tags
"Kuwee","Obrigado amigo","ku-we-e","Interjeição","Kuwee nügũ","Obrigado amigo","Dica","Saudações;Ministério"
''';
      final importWords = await repo.importFromCsv(customCsv, TicunaEntryType.word);
      expect(importWords.success, isTrue);
      expect(importWords.wordsCount, equals(1));

      final imported = await repo.getAllWords(searchQuery: 'Kuwee');
      expect(imported.length, equals(1));
      expect(imported.first.translation, equals('Obrigado amigo'));
      expect(imported.first.tags, contains('Saudações'));
    });

    test('importFromCsv suporta notas com quebras de linha entre aspas (RFC 4180)', () async {
      const multilineCsv = '''word,translation,phonetics,grammatical_class,example_sentence,example_translation,notes,tags
"Tupana Meã","Deus é Bom","tu-pa-na me-ã","Frase","Exemplo","Tradução","Nota linha 1\nNota linha 2 com ""aspas""","Bíblia, Ministério"
''';
      final res = await repo.importFromCsv(multilineCsv, TicunaEntryType.word);
      expect(res.success, isTrue);
      expect(res.wordsCount, equals(1));
      final word = (await repo.getAllWords(searchQuery: 'Tupana Meã')).first;
      expect(word.notes, contains('Nota linha 1\nNota linha 2 com "aspas"'));
      expect(word.tags, contains('Bíblia'));
      expect(word.tags, contains('Ministério'));
    });

    test('importAuto importa JSON array direto e detecta CSV automaticamente', () async {
      const jsonArray = '''[
        {"word": "Wotü̃", "translation": "Casa / Habitação"}
      ]''';
      final resJson = await repo.importAuto(jsonArray);
      expect(resJson.success, isTrue);
      expect(resJson.wordsCount, equals(1));

      const csvContent = '''phrase,translation,category
"Tamaü meã","Bom dia de paz","Saudação"''';
      final resCsv = await repo.importAuto(csvContent);
      expect(resCsv.success, isTrue);
      expect(resCsv.phrasesCount, equals(1));
    });

    test('TicunaWord calcula intervalos Leitner e vencimento de revisão', () {
      final now = DateTime.now();
      final w0 = TicunaWord(
        id: '1',
        word: 'A',
        translation: 'B',
        reviewLevel: 0,
        createdAt: now,
        updatedAt: now,
      );
      expect(w0.intervalDays, equals(0));
      expect(w0.isDueForReview, isTrue);

      final w1 = w0.copyWith(
        reviewLevel: 1,
        lastReviewedAt: now.subtract(const Duration(days: 2)),
      );
      expect(w1.intervalDays, equals(1));
      expect(w1.isDueForReview, isTrue);

      final w2 = w0.copyWith(
        reviewLevel: 3,
        lastReviewedAt: now, // revisado agora, intervalo de 7 dias
      );
      expect(w2.intervalDays, equals(7));
      expect(w2.isDueForReview, isFalse);
    });

    test('Operações de mutação registram na syncQueue para todas as ações (add, fav, review, delete)', () async {
      final initialQueue = await db.select(db.syncQueue).get();
      final initialCount = initialQueue.length;

      final item = await repo.addWord(word: 'SyncWord', translation: 'Palavra Sync');
      var q = await db.select(db.syncQueue).get();
      expect(q.length, equals(initialCount + 1));
      expect(q.last.operation, equals('INSERT'));

      await repo.toggleWordFavorite(item.id);
      q = await db.select(db.syncQueue).get();
      expect(q.length, equals(initialCount + 2));
      expect(q.last.operation, equals('UPDATE'));

      await repo.recordWordReview(item.id, 2);
      q = await db.select(db.syncQueue).get();
      expect(q.length, equals(initialCount + 3));
      expect(q.last.operation, equals('UPDATE'));

      await repo.deleteWord(item.id);
      q = await db.select(db.syncQueue).get();
      expect(q.length, equals(initialCount + 4));
      expect(q.last.operation, equals('DELETE'));
    });
  });

  group('TicunaRepository - Transações e Integridade de Sincronização', () {
    test('Rollback atômico: se syncQueue falha, mutação em ticuna_words não é persistida', () async {
      final testDb = AppDatabase.forTesting(NativeDatabase.memory());
      final testRepo = TicunaRepository(testDb);
      await testRepo.getAllWords(); // aguarda inicialização das tabelas

      // Adiciona trigger no SQLite que falha toda inserção na sync_queue
      await testDb.customStatement('''
        CREATE TRIGGER test_fail_sync_insert BEFORE INSERT ON sync_queue
        BEGIN
          SELECT RAISE(ABORT, 'Simulated sync_queue write failure');
        END;
      ''');

      // Tentativa de adicionar palavra deve falhar devido à trigger
      await expectLater(
        () => testRepo.addWord(word: 'PalavraNaoSalva', translation: 'Nao deve existir'),
        throwsA(isA<Exception>()),
      );

      // Garante que a transação fez rollback e a palavra NUNCA foi gravada em ticuna_words
      final words = await testRepo.getAllWords(searchQuery: 'PalavraNaoSalva');
      expect(words, isEmpty);

      await testDb.close();
    });
  });
}

class _FailingDatabase extends AppDatabase {
  _FailingDatabase() : super.forTesting(NativeDatabase.memory());

  @override
  Future<void> customStatement(String statement, [List<dynamic>? args]) {
    throw Exception('Simulated database corruption / I/O error');
  }
}
