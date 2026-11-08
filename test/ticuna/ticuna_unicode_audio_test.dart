import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/ticuna/services/ticuna_audio_service.dart';
import 'package:ministerio_pessoal/ticuna/ticuna_providers.dart';
import 'package:ministerio_pessoal/ticuna/ticuna_repository.dart';
import 'package:ministerio_pessoal/ticuna/ticuna_unicode_helper.dart';
import 'package:ministerio_pessoal/ticuna/widgets/ticuna_audio_player_widget.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('TicunaUnicodeHelper - Normalização e Diacríticos Compostos', () {
    test('Valida todos os 12 caracteres especiais de referência (Imagens 2 e 3 e WOL)', () {
      // Linha 1 (6 minúsculas canônicas): ĩ, ü̃, ü̃́, ũ, ã́, ẽ
      expect(TicunaUnicodeHelper.row1.length, equals(6));
      expect(TicunaUnicodeHelper.row1[0], equals('ĩ'));
      expect(TicunaUnicodeHelper.row1[1], equals('ü\u0303'));
      expect(TicunaUnicodeHelper.row1[2], equals('ü\u0303\u0301'));
      expect(TicunaUnicodeHelper.row1[3], equals('ũ'));
      expect(TicunaUnicodeHelper.row1[4], equals('ã\u0301'));
      expect(TicunaUnicodeHelper.row1[5], equals('ẽ'));

      // Linha 2 (6 maiúsculas canônicas): Ĩ, Ü̃, Ü̃́, Ũ, Ã́, Ẽ
      expect(TicunaUnicodeHelper.row2.length, equals(6));
      expect(TicunaUnicodeHelper.row2[0], equals('Ĩ'));
      expect(TicunaUnicodeHelper.row2[1], equals('Ü\u0303'));
      expect(TicunaUnicodeHelper.row2[2], equals('Ü\u0303\u0301'));
      expect(TicunaUnicodeHelper.row2[3], equals('Ũ'));
      expect(TicunaUnicodeHelper.row2[4], equals('Ã\u0301'));
      expect(TicunaUnicodeHelper.row2[5], equals('Ẽ'));

      // Valida que canonicalVowels contém exatamente os 12 glifos canônicos do WOL
      expect(TicunaUnicodeHelper.canonicalVowels.length, equals(12));
    });

    test('Normaliza sequências decompostas e compostas para forma canônica estável', () {
      // Teste com vogais com til e acento agudo empilhados
      final raw1 = 'ü\u0303'; // u com trema + til
      final raw2 = 'ã\u0301'; // a com til + agudo
      final raw3 = 'Duü\u0303';
      final raw4 = 'ü\u0301\u0303'; // u trema + agudo + til

      final norm1 = TicunaUnicodeHelper.normalize(raw1);
      final norm2 = TicunaUnicodeHelper.normalize(raw2);
      final norm3 = TicunaUnicodeHelper.normalize(raw3);
      final norm4 = TicunaUnicodeHelper.normalize(raw4);

      expect(norm1, equals('ü\u0303'));
      expect(norm2, equals('ã\u0301'));
      expect(norm3, equals('Duü\u0303'));
      expect(norm4, equals('ü\u0303\u0301'));
    });

    test('Converte diacríticos espaçados/soltos (~, ´, ¨) colados na vogal em acentos combinados empilhados', () {
      expect(TicunaUnicodeHelper.normalize('ü~'), equals('ü\u0303'));
      expect(TicunaUnicodeHelper.normalize('Ü~'), equals('Ü\u0303'));
      expect(TicunaUnicodeHelper.normalize('ǘ~'), equals('ü\u0303\u0301'));
      expect(TicunaUnicodeHelper.normalize('Ǘ~'), equals('Ü\u0303\u0301'));
      expect(TicunaUnicodeHelper.normalize('ã´'), equals('ã\u0301'));
      expect(TicunaUnicodeHelper.normalize('Ã´'), equals('Ã\u0301'));
      expect(TicunaUnicodeHelper.normalize('i~'), equals('ĩ'));
      expect(TicunaUnicodeHelper.normalize('u~'), equals('ũ'));
      expect(TicunaUnicodeHelper.normalize('e~'), equals('ẽ'));
      expect(TicunaUnicodeHelper.normalize('Duü~'), equals('Duü\u0303'));
      expect(TicunaUnicodeHelper.normalize('ü\u0303´'), equals('ü\u0303\u0301'));
      expect(TicunaUnicodeHelper.normalize('Ü\u0303´'), equals('Ü\u0303\u0301'));
    });

    test('Garante que ü̃ NUNCA é substituído por ũ e que termos canônicos são preservados', () {
      // ü̃ e ũ são fonemas distintos na língua Ticuna
      expect(TicunaUnicodeHelper.normalize('ü\u0303'), equals('ü\u0303'));
      expect(TicunaUnicodeHelper.normalize('ü\u0303\u0301'), equals('ü\u0303\u0301'));
      expect(TicunaUnicodeHelper.normalize('ũ'), equals('ũ'));
      expect(TicunaUnicodeHelper.normalize('Ũ'), equals('Ũ'));
      expect(TicunaUnicodeHelper.normalize('Duü\u0303'), equals('Duü\u0303'));

      // Se o usuário digitou acidentalmente com trema sobre ũ, normaliza para ü̃
      expect(TicunaUnicodeHelper.normalize('ũ\u0308'), equals('ü\u0303'));
      expect(TicunaUnicodeHelper.normalize('Ũ\u0308'), equals('Ü\u0303'));
      expect(TicunaUnicodeHelper.normalize('ũ¨'), equals('ü\u0303'));
      expect(TicunaUnicodeHelper.normalize('Ũ¨'), equals('Ü\u0303'));
      expect(TicunaUnicodeHelper.normalize('ũ\u0308\u0301'), equals('ü\u0303\u0301'));

      // Recuperação do termo canônico "Duü̃" (pessoa/gente)
      expect(TicunaUnicodeHelper.normalize('Duũũ'), equals('Duü\u0303'));
      expect(TicunaUnicodeHelper.normalize('Duũ'), equals('Duü\u0303'));
    });

    test('TicunaInputFormatter formata em tempo real durante a digitação', () {
      const formatter = TicunaInputFormatter();
      const oldVal = TextEditingValue(text: 'Duü');
      const newVal = TextEditingValue(
        text: 'Duü~',
        selection: TextSelection.collapsed(offset: 4),
      );
      final result = formatter.formatEditUpdate(oldVal, newVal);
      expect(result.text, equals('Duü\u0303'));
    });

    test('textStyle fornece fallbacks tipográficos sem corte vertical de linha', () {
      final style = TicunaUnicodeHelper.textStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.teal,
      );

      expect(style.fontSize, equals(18));
      expect(style.fontWeight, equals(FontWeight.bold));
      expect(style.color, equals(Colors.teal));
      // Garante que não haja clipping agressivo de altura
      expect(style.height, isNull);
      // Garante que haja fallback de fontes com suporte a GPOS
      expect(style.fontFamilyFallback, isNotNull);
      expect(style.fontFamilyFallback, contains('Gentium Plus'));
      expect(style.fontFamilyFallback, contains('Charis SIL'));
      expect(style.fontFamilyFallback, contains('Noto Sans'));
    });
  });

  group('TicunaAudioService - Gravação Compacta e Velocidade de Reprodução', () {
    late ITicunaAudioService audioService;

    setUp(() {
      audioService = FakeTicunaAudioService();
    });

    tearDown(() {
      audioService.dispose();
    });

    test('Inicia e para gravação produzindo arquivo leve e temporário', () async {
      expect(audioService.isRecording, isFalse);

      final path = await audioService.startRecording(
        id: 'test_word_123',
        prefix: 'word',
      );

      expect(path, isNotEmpty);
      expect(path.endsWith('.m4a'), isTrue);
      expect(audioService.isRecording, isTrue);

      final result = await audioService.stopRecording();
      expect(result, isNotNull);
      expect(result!.filePath, equals(path));
      expect(result.durationSeconds, greaterThanOrEqualTo(1));
      // Arquivo de 1 a 15 segundos em 32kbps mono deve ser leve (< 100 KB)
      expect(result.fileSizeBytes, lessThan(100 * 1024));
      expect(audioService.isRecording, isFalse);

      // Limpeza
      await audioService.deleteAudioFile(path);
    });

    test('Controla e altera a velocidade de reprodução', () async {
      expect(audioService.currentPlaybackSpeed, equals(1.0));

      await audioService.setPlaybackSpeed(0.5);
      expect(audioService.currentPlaybackSpeed, equals(0.5));

      await audioService.setPlaybackSpeed(0.75);
      expect(audioService.currentPlaybackSpeed, equals(0.75));

      await audioService.setPlaybackSpeed(1.25);
      expect(audioService.currentPlaybackSpeed, equals(1.25));

      await audioService.setPlaybackSpeed(1.0);
      expect(audioService.currentPlaybackSpeed, equals(1.0));
    });

    test('Cancela gravação e descarta arquivo sem erros', () async {
      final path = await audioService.startRecording(
        id: 'test_cancel',
        prefix: 'phrase',
      );
      expect(audioService.isRecording, isTrue);

      await audioService.cancelRecording();
      expect(audioService.isRecording, isFalse);

      final file = File(path);
      expect(await file.exists(), isFalse);
    });

    test('TicunaAudioService real suporta play/pause/stop e deleteAudioFile defensivamente', () async {
      final realService = TicunaAudioService();
      addTearDown(realService.dispose);

      // Reprodução com URL blob simulada
      await realService.play('blob:http://localhost:8080/fake-blob-uuid', speed: 1.0);
      expect(realService.currentPlaybackSpeed, equals(1.0));

      await realService.pause();
      await realService.stop();

      // deleteAudioFile com blob ou vazio retorna true defensivamente
      expect(await realService.deleteAudioFile('blob:http://localhost/test'), isTrue);
      expect(await realService.deleteAudioFile(''), isFalse);
    });
  });

  group('TicunaRepository - Persistência de Áudio e Diacríticos no Drift/SQLite', () {
    late AppDatabase db;
    late TicunaRepository repo;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = TicunaRepository(db);
      await repo.getAllWords();
    });

    tearDown(() async {
      await db.close();
    });

    test('Grava termo com caracteres acentuados empilhados no banco fielmente', () async {
      final item = await repo.addWord(
        word: 'Ü\u0303\u0301recura',
        translation: 'Palavra / Teste Diacrítico',
        phonetics: 'ü-re-cu-ra',
        grammaticalClass: 'Substantivo',
        audioPath: '/local/test_audio.m4a',
        audioDurationSeconds: 4,
      );

      final words = await repo.getAllWords();
      final saved = words.firstWhere((w) => w.id == item.id);
      expect(saved.word, equals('Ü\u0303\u0301recura'));
      expect(saved.audioPath, equals('/local/test_audio.m4a'));
      expect(saved.audioDurationSeconds, equals(4));

      // Atualiza o áudio
      await repo.updateWordAudio(
        item.id,
        '/local/new_pronunciation.m4a',
        durationSeconds: 6,
      );

      final updatedWords = await repo.getAllWords();
      final updated = updatedWords.firstWhere((w) => w.id == item.id);
      expect(updated.audioPath, equals('/local/new_pronunciation.m4a'));
      expect(updated.audioDurationSeconds, equals(6));

      // Apaga o áudio
      await repo.deleteWordAudio(item.id);
      final clearedWords = await repo.getAllWords();
      final cleared = clearedWords.firstWhere((w) => w.id == item.id);
      expect(cleared.audioPath, isNull);
    });

    test('Grava frase com áudio e remove áudio para regravar', () async {
      final phrase = await repo.addPhrase(
        phrase: 'Tamaü! Ku meã pe\'ĩ?',
        translation: 'Olá! Você está bem?',
        audioPath: '/local/phrase_audio.m4a',
        audioDurationSeconds: 5,
      );

      var phrases = await repo.getAllPhrases();
      var found = phrases.firstWhere((p) => p.id == phrase.id);
      expect(found.audioPath, equals('/local/phrase_audio.m4a'));
      expect(found.audioDurationSeconds, equals(5));

      // Apaga áudio para regravar
      await repo.deletePhraseAudio(phrase.id);
      phrases = await repo.getAllPhrases();
      found = phrases.firstWhere((p) => p.id == phrase.id);
      expect(found.audioPath, isNull);
    });

    test('Operações de CRUD no repositório enfileiram mutações na SyncQueue para sincronização multi-dispositivo', () async {
      final initialQueue = await db.select(db.syncQueue).get();
      final initialCount = initialQueue.length;

      // Adiciona palavra
      final w = await repo.addWord(
        word: 'Nawü̃',
        translation: 'Irmão',
      );
      var queue = await db.select(db.syncQueue).get();
      expect(queue.length, equals(initialCount + 1));
      expect(queue.last.entityType, equals('ticuna_words'));
      expect(queue.last.operation, equals('INSERT'));
      expect(queue.last.entityId, equals(w.id));

      // Atualiza palavra
      await repo.updateWord(w.copyWith(translation: 'Irmão / Companheiro'));
      queue = await db.select(db.syncQueue).get();
      expect(queue.length, equals(initialCount + 2));
      expect(queue.last.operation, equals('UPDATE'));

      // Remove palavra
      await repo.deleteWord(w.id);
      queue = await db.select(db.syncQueue).get();
      expect(queue.length, equals(initialCount + 3));
      expect(queue.last.operation, equals('DELETE'));

      // Adiciona frase
      final p = await repo.addPhrase(
        phrase: 'Tamaü',
        translation: 'Olá',
      );
      queue = await db.select(db.syncQueue).get();
      expect(queue.last.entityType, equals('ticuna_phrases'));
      expect(queue.last.operation, equals('INSERT'));
      expect(queue.last.entityId, equals(p.id));

      // Remove frase
      await repo.deletePhrase(p.id);
      queue = await db.select(db.syncQueue).get();
      expect(queue.last.entityType, equals('ticuna_phrases'));
      expect(queue.last.operation, equals('DELETE'));
    });

    test('Migra automaticamente termos corrompidos com diacríticos como Duũ para o canônico Duü̃', () async {
      // Cria instância nova de repositório após inserção forçada de dado corrompido
      await db.customInsert(
        "INSERT INTO ticuna_words (id, word, translation, phonetics, example_sentence, created_at, updated_at) "
        "VALUES ('legacy_corrupt_1', 'Duũ', 'Gente / Pessoa', 'du-u', 'Duũ meã', '2026-01-01', '2026-01-01')",
      );
      await db.customInsert(
        "INSERT INTO ticuna_words (id, word, translation, phonetics, example_sentence, created_at, updated_at) "
        "VALUES ('legacy_corrupt_2', 'Duũũ', 'Gente', 'du-u', 'Duũũ meã', '2026-01-01', '2026-01-01')",
      );

      final freshRepo = TicunaRepository(db);
      final words = await freshRepo.getAllWords();

      final w1 = words.firstWhere((w) => w.id == 'legacy_corrupt_1');
      expect(w1.word, equals('Duü\u0303'));
      expect(w1.phonetics, equals('du-ü\u0303 [nasal]'));
      expect(w1.exampleSentence, equals('Duü\u0303 meã'));

      final w2 = words.firstWhere((w) => w.id == 'legacy_corrupt_2');
      expect(w2.word, equals('Duü\u0303'));
    });
  });

  group('TicunaAudioPlayerWidget - Interface Gráfica', () {
    testWidgets('Exibe botão "Gravar" quando não há áudio gravado', (tester) async {
      final fakeAudio = FakeTicunaAudioService();
      addTearDown(fakeAudio.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ticunaAudioServiceProvider.overrideWithValue(fakeAudio),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: TicunaAudioPlayerWidget(
                id: 'w1',
                title: 'Taemãẽ',
                audioPath: null,
                compact: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Gravar'), findsOneWidget);
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
    });

    testWidgets('Exibe player com play, duração e velocidade quando áudio existe', (tester) async {
      final fakeAudio = FakeTicunaAudioService();
      addTearDown(fakeAudio.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ticunaAudioServiceProvider.overrideWithValue(fakeAudio),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: TicunaAudioPlayerWidget(
                id: 'w2',
                title: 'Duü̃',
                audioPath: '/data/user/duu.m4a',
                audioDurationSeconds: 4,
                compact: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);
      expect(find.text('00:04'), findsOneWidget);
      expect(find.text('1.0x'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);

      // Toca na tag de velocidade para alternar
      await tester.tap(find.text('1.0x'));
      await tester.pumpAndSettle();

      expect(find.text('1.25x'), findsOneWidget);
    });
  });
}
