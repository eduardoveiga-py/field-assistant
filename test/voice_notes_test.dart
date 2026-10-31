import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/contacts/doorstep_briefing_helper.dart';
import 'package:ministerio_pessoal/ui/widgets/doorstep_briefing_card.dart';
import 'package:ministerio_pessoal/ui/widgets/quick_voice_note_dialog.dart';
import 'package:ministerio_pessoal/voice_notes/voice_note_parser.dart';
import 'package:ministerio_pessoal/voice_notes/voice_note_models.dart';
import 'package:ministerio_pessoal/voice_notes/voice_notes_manager.dart';
import 'package:ministerio_pessoal/voice_notes/audio_recording_service.dart';
import 'package:ministerio_pessoal/voice_notes/voice_dictation_service.dart';

void main() {
  group('VoiceNoteParser (Nível 3 - Motor Determinístico Puro Dart)', () {
    test('TC-PARSER-01: Exemplo canônico do usuário com estudo, lição, ponto, pendência e empatia', () {
      const text =
          'Estudo com o Marcos, paramos na lição 18 ponto 3. '
          'Ficou pendente mostrar o vídeo sobre batismo porque estava sem sinal. '
          'Ele comentou que o turno do trabalho vai mudar semana que vem.';

      final parsed = VoiceNoteParser.parse(text);

      expect(parsed.studentName, equals('Marcos'));
      expect(parsed.lesson, equals(18));
      expect(parsed.point, equals(3));
      expect(parsed.formattedProgress, equals('Lição 18, Ponto 3'));
      expect(parsed.pendingDoubt, contains('mostrar o vídeo sobre batismo'));
      expect(parsed.empathyNote, contains('turno do trabalho vai mudar'));
      expect(parsed.hasAnyExtraction, isTrue);
    });

    test('TC-PARSER-02: Números por extenso em português para lição e parágrafo', () {
      const text =
          'Paramos na lição dezoito, ponto três. '
          'Ficou de ler o texto de Isaías. '
          'Ela comentou sobre a saúde da família.';

      final parsed = VoiceNoteParser.parse(text);

      expect(parsed.lesson, equals(18));
      expect(parsed.point, equals(3));
      expect(parsed.formattedProgress, equals('Lição 18, Ponto 3'));
      expect(parsed.pendingDoubt, contains('ler o texto de Isaías'));
      expect(parsed.empathyNote, contains('saúde da família'));
    });

    test('TC-PARSER-03: Dezenas compostas por extenso (vinte e quatro, ponto cinco)', () {
      const text = 'Estudo na lição vinte e quatro, ponto cinco. Combinamos de assistir o vídeo na próxima visita.';

      final parsed = VoiceNoteParser.parse(text);

      expect(parsed.lesson, equals(24));
      expect(parsed.point, equals(5));
      expect(parsed.formattedProgress, equals('Lição 24, Ponto 5'));
      expect(parsed.pendingDoubt, contains('assistir o vídeo na próxima visita'));
    });

    test('TC-PARSER-04: Variações de termos teocráticos (capítulo, seção, parágrafo, estudo)', () {
      const t1 = 'Capítulo 7 parágrafo 4. Ficou pendente levar a brochura.';
      final p1 = VoiceNoteParser.parse(t1);
      expect(p1.lesson, equals(7));
      expect(p1.point, equals(4));
      expect(p1.pendingDoubt, contains('levar a brochura'));

      const t2 = 'Estudo 12 seção 2. Próximo passo responder à pergunta sobre sofrimento.';
      final p2 = VoiceNoteParser.parse(t2);
      expect(p2.lesson, equals(12));
      expect(p2.point, equals(2));
      expect(p2.pendingDoubt, contains('responder à pergunta'));

      const t3 = 'Lição nº 04, parágrafo segundo.';
      final p3 = VoiceNoteParser.parse(t3);
      expect(p3.lesson, equals(4));
      expect(p3.point, equals(2));
    });

    test('TC-PARSER-05: Gatilhos empáticos de vida (cirurgia, hospital, luto, emprego)', () {
      const t1 = 'A cirurgia da mãe foi transferida para semana que vem.';
      final p1 = VoiceNoteParser.parse(t1);
      expect(p1.empathyNote, contains('cirurgia da mãe'));

      const t2 = 'Ele está desempregado e pediu uma oração.';
      final p2 = VoiceNoteParser.parse(t2);
      expect(p2.empathyNote, contains('desempregado'));

      const t3 = 'Família em luto devido ao falecimento do avô.';
      final p3 = VoiceNoteParser.parse(t3);
      expect(p3.empathyNote, contains('luto devido ao falecimento'));
    });

    test('TC-PARSER-06: Robustez com entradas vazias, nulas, espaços e pontuação', () {
      expect(VoiceNoteParser.parse(null).hasAnyExtraction, isFalse);
      expect(VoiceNoteParser.parse('').hasAnyExtraction, isFalse);
      expect(VoiceNoteParser.parse('   ').hasAnyExtraction, isFalse);
      expect(VoiceNoteParser.parse('... ,,, ;;;').hasAnyExtraction, isFalse);
    });

    test('TC-PARSER-07: Conversão isolada de números em português (parsePortugueseNumber)', () {
      expect(VoiceNoteParser.parsePortugueseNumber('18'), equals(18));
      expect(VoiceNoteParser.parsePortugueseNumber('dezoito'), equals(18));
      expect(VoiceNoteParser.parsePortugueseNumber('trinta e cinco'), equals(35));
      expect(VoiceNoteParser.parsePortugueseNumber('quarenta e dois'), equals(42));
      expect(VoiceNoteParser.parsePortugueseNumber('cinquenta e nove'), equals(59));
      expect(VoiceNoteParser.parsePortugueseNumber('primeiro'), equals(1));
      expect(VoiceNoteParser.parsePortugueseNumber('segundo'), equals(2));
      expect(VoiceNoteParser.parsePortugueseNumber('invalido'), isNull);
    });

    test('TC-PARSER-08: Model ParsedVoiceNote copyWith e equals', () {
      const p1 = ParsedVoiceNote(lesson: 5, point: 2, rawText: 'Lição 5 ponto 2');
      final p2 = p1.copyWith(pendingDoubt: 'Levar livro');

      expect(p2.lesson, equals(5));
      expect(p2.point, equals(2));
      expect(p2.pendingDoubt, equals('Levar livro'));
      expect(p1 == p2, isFalse);
      expect(p1 == p1.copyWith(), isTrue);
    });

    test('TC-PARSER-09: Fala natural contínua sem pontuação nem vírgulas (ditado real Android/iOS)', () {
      const text =
          'Estudo com o Marcos paramos na lição 18 ponto 3 '
          'ficou pendente mostrar o vídeo sobre batismo porque estava sem sinal '
          'ele comentou que o turno do trabalho vai mudar semana que vem';

      final parsed = VoiceNoteParser.parse(text);

      expect(parsed.studentName, equals('Marcos'));
      expect(parsed.lesson, equals(18));
      expect(parsed.point, equals(3));
      expect(parsed.pendingDoubt, contains('mostrar o vídeo sobre batismo'));
      expect(parsed.empathyNote, contains('turno do trabalho vai mudar'));
    });

    test('TC-PARSER-10: Ordinais teocráticos por extenso e compostos', () {
      const t1 = 'Paramos na décima oitava lição, vigésimo primeiro parágrafo.';
      final p1 = VoiceNoteParser.parse(t1);
      expect(p1.lesson, equals(18));
      expect(p1.point, equals(21));

      const t2 = 'Lição vigésima quarta, ponto terceiro.';
      final p2 = VoiceNoteParser.parse(t2);
      expect(p2.lesson, equals(24));
      expect(p2.point, equals(3));
    });

    test('TC-PARSER-11: Ordem inversa com sufixos ordinais e cardinais (18ª lição, 3º ponto)', () {
      const t1 = 'Na 18ª lição paramos no 3º ponto. Ficou combinado de levar a brochura.';
      final p1 = VoiceNoteParser.parse(t1);
      expect(p1.lesson, equals(18));
      expect(p1.point, equals(3));
      expect(p1.pendingDoubt, contains('levar a brochura'));

      const t2 = 'No 4º parágrafo da 12ª lição.';
      final p2 = VoiceNoteParser.parse(t2);
      expect(p2.lesson, equals(12));
      expect(p2.point, equals(4));
    });

    test('TC-PARSER-12: Extração robusta de nomes de estudantes sem capturar verbos ou locais', () {
      expect(VoiceNoteParser.parse('Visita na parte da manhã com o Carlos').studentName, equals('Carlos'));
      expect(VoiceNoteParser.parse('Estudo na casa do Marcos').studentName, equals('Marcos'));
      expect(VoiceNoteParser.parse('Estudo com o Marcos paramos na lição 18').studentName, equals('Marcos'));
      expect(VoiceNoteParser.parse('Estudo no livro Seja Feliz').studentName, isNull);
    });
  });

  group('VoiceNotesManager e Persistência SQLite Offline', () {
    late AppDatabase db;
    late AppRepository repo;
    late VoiceNotesManager manager;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
      manager = VoiceNotesManager(db, repo);
    });

    tearDown(() async {
      await db.close();
    });

    test('TC-DB-01: Criação de nota de voz e recuperação pelo personId', () async {
      final now = DateTime.now();
      final item = VoiceNoteItem(
        id: 'vn-101',
        personId: 'p-1',
        transcription: 'Estudo lição 18 ponto 3',
        detectedLesson: 18,
        detectedPoint: 3,
        extractedPendingDoubt: 'Mostrar vídeo',
        extractedEmpathyNote: 'Turno de trabalho',
        audioFilePath: '/data/audio/vn-101.m4a',
        audioDurationSeconds: 15,
        createdAt: now,
        updatedAt: now,
      );

      await manager.saveVoiceNote(item);

      final list = await manager.getVoiceNotesForPerson('p-1');
      expect(list.length, equals(1));
      expect(list.first.id, equals('vn-101'));
      expect(list.first.detectedLesson, equals(18));
      expect(list.first.formattedDuration, equals('00:15'));

      final latest = await manager.getLatestVoiceNoteForPerson('p-1');
      expect(latest, isNotNull);
      expect(latest!.extractedPendingDoubt, equals('Mostrar vídeo'));
    });

    test('TC-DB-02: Exclusão lógica (soft delete) da nota de voz', () async {
      final now = DateTime.now();
      final item = VoiceNoteItem(
        id: 'vn-102',
        personId: 'p-2',
        transcription: 'Teste exclusão',
        createdAt: now,
        updatedAt: now,
      );

      await manager.saveVoiceNote(item);
      expect((await manager.getVoiceNotesForPerson('p-2')).length, equals(1));

      await manager.deleteVoiceNote('vn-102');
      expect((await manager.getVoiceNotesForPerson('p-2')).isEmpty, isTrue);
    });

    test('TC-DB-03: Fluxo Unificado Atômico saveQuickVisitFromVoiceNote atualiza Briefing', () async {
      // 1. Cria pessoa e estudo no repositório
      final person = await repo.createPerson(
        name: 'Carlos Oliveira',
        status: 'estudo',
      );

      final study = await repo.createStudy(
        title: 'Seja Feliz para Sempre!',
        publicationId: 'lff-book',
        currentLesson: 17,
        currentParagraph: 5,
        participantPersonIds: [person.id],
      );

      // 2. Executa a nota rápida
      const rawText =
          'Estudo com o Carlos, paramos na lição 18 ponto 3. '
          'Ficou pendente mostrar o vídeo de batismo. '
          'Ele comentou que a mãe fez cirurgia.';
      final parsed = VoiceNoteParser.parse(rawText);

      final result = await manager.saveQuickVisitFromVoiceNote(
        personId: person.id,
        parsedNote: parsed,
        audioFilePath: '/storage/test.m4a',
        audioDurationSeconds: 15,
      );

      expect(result.voiceNote, isNotNull);
      expect(result.visit, isNotNull);
      expect(result.visit!.personId, equals(person.id));
      expect(result.visit!.nextStep, contains('mostrar o vídeo de batismo'));

      // 3. Verifica se o estudo bíblico teve lição e ponto atualizados
      final updatedStudy = await repo.getStudyById(study.id);
      expect(updatedStudy!.currentLesson, equals(18));
      expect(updatedStudy.currentParagraph, equals(3));
      expect(updatedStudy.pendingDoubts, contains('mostrar o vídeo de batismo'));

      // 4. Verifica se a pessoa recebeu a nota empática no formato JSON de anotações
      final updatedPerson = await repo.getPersonById(person.id);
      expect(updatedPerson!.generalNotes, contains('cirurgia'));
      final notes = DoorstepBriefingHelper.parseNotes(updatedPerson.generalNotes);
      expect(notes.isNotEmpty, isTrue);
      expect(notes.first['text'], contains('cirurgia'));

      // 5. Verifica se o DoorstepBriefingHelper consolida tudo com perfeição
      final latestVn = await manager.getLatestVoiceNoteForPerson(person.id);
      final briefing = DoorstepBriefingHelper.build(
        person: updatedPerson,
        linkedStudy: updatedStudy,
        latestVisit: result.visit,
        latestVoiceNote: latestVn,
      );

      expect(briefing.lessonAndPoint, equals('Lição 18, Ponto 3'));
      expect(briefing.pendingDoubt, contains('mostrar o vídeo de batismo'));
      expect(briefing.empathyNote, contains('cirurgia'));
      expect(briefing.hasVoiceNote, isTrue);
      expect(briefing.voiceNoteDurationSeconds, equals(15));
    });

    test('TC-DB-04: Concorrência e integridade — saveQuickVisitFromVoiceNote preserva lastContactAt e revision sem sobrescrita obsoleta', () async {
      final oldDate = DateTime(2025, 1, 1, 10, 0);
      final person = await repo.createPerson(
        name: 'Ana Souza',
        status: 'revisita',
        lastContactAt: oldDate,
      );

      final visitDate = DateTime(2026, 10, 31, 15, 30);
      final note = VoiceNoteParser.parse(
        'Visita com a Ana. Ficou de ler o texto de Isaías. Ela comentou sobre a cirurgia da mãe.',
      );

      await manager.saveQuickVisitFromVoiceNote(
        personId: person.id,
        parsedNote: note,
        dateTime: visitDate,
      );

      final freshPerson = await repo.getPersonById(person.id);
      expect(freshPerson, isNotNull);
      // Confirma que o lastContactAt da visita não foi apagado/revertido por person obsoleto
      expect(freshPerson!.lastContactAt, equals(visitDate));
      expect(freshPerson.revision, greaterThanOrEqualTo(2));
      expect(freshPerson.generalNotes, contains('cirurgia da mãe'));
    });
  });

  group('DoorstepBriefingCard com Suporte a Nota de Voz (Testes de Widget)', () {
    testWidgets('TC-W-VN01: Renderiza seção de última nota de voz quando hasVoiceNote é true', (tester) async {
      String? playedPath;
      final data = DoorstepBriefingData(
        lessonAndPoint: 'Lição 18, Ponto 3',
        pendingDoubt: 'Mostrar vídeo sobre batismo',
        empathyNote: 'Turno de trabalho vai mudar',
        audioFilePath: '/audio/marcos_18.m4a',
        voiceNoteTranscription: 'Estudo com o Marcos, lição 18 ponto 3...',
        voiceNoteDurationSeconds: 15,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DoorstepBriefingCard(
              data: data,
              onPlayVoiceNote: (path) {
                playedPath = path;
              },
            ),
          ),
        ),
      );

      expect(find.text('ÚLTIMA NOTA DE VOZ (DITADO RÁPIDO)'), findsOneWidget);
      expect(find.text('"Estudo com o Marcos, lição 18 ponto 3..."'), findsOneWidget);
      expect(find.text('Ouvir Nota (0:15)'), findsOneWidget);

      // Clica no botão de ouvir áudio
      await tester.tap(find.text('Ouvir Nota (0:15)'));
      await tester.pump();

      expect(playedPath, equals('/audio/marcos_18.m4a'));
    });

    testWidgets('TC-W-VN02: Alvo de toque mínimo >= 48dp no botão de ouvir nota', (tester) async {
      final data = const DoorstepBriefingData(
        lessonAndPoint: 'Lição 04',
        audioFilePath: '/audio/test.m4a',
        voiceNoteTranscription: 'Nota de áudio rápida',
        voiceNoteDurationSeconds: 12,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DoorstepBriefingCard(data: data),
          ),
        ),
      );

      final buttonFinder = find.widgetWithText(ElevatedButton, 'Ouvir Nota (0:12)');
      expect(buttonFinder, findsOneWidget);
      final size = tester.getSize(buttonFinder);
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('TC-W-VN03: Visual sob SunMode (alto contraste com bordas pretas)', (tester) async {
      final data = const DoorstepBriefingData(
        lessonAndPoint: 'Lição 18',
        audioFilePath: '/audio/test.m4a',
        voiceNoteTranscription: 'Transcrição SunMode',
        voiceNoteDurationSeconds: 15,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: Colors.white,
            colorScheme: const ColorScheme.light(primary: Colors.black),
            cardTheme: const CardThemeData(
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.black, width: 2.0),
              ),
            ),
          ),
          home: Scaffold(
            body: DoorstepBriefingCard(data: data),
          ),
        ),
      );

      expect(find.text('Briefing na Porta'), findsOneWidget);
      expect(find.text('ÚLTIMA NOTA DE VOZ (DITADO RÁPIDO)'), findsOneWidget);
    });
  });

  group('QuickVoiceNoteDialog (Testes de Modal de Gravação / Ditado 15s)', () {
    late AppDatabase db;
    late AppRepository repo;
    late PersonEntry testPerson;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
      testPerson = await repo.createPerson(
        name: 'Roberto Silva',
        status: 'estudo',
      );
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('TC-W-MODAL-01: Modal abre, grava, dita e preenche cards estruturados', (tester) async {
      final mockRecordService = LocalAudioRecordingService();
      final mockDictationService = LocalVoiceDictationService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            repositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    QuickVoiceNoteDialog.show(
                      context: context,
                      person: testPerson,
                      recordingService: mockRecordService,
                      dictationService: mockDictationService,
                    );
                  },
                  child: const Text('Abrir Modal'),
                ),
              ),
            ),
          ),
        ),
      );

      // Abre o diálogo
      await tester.tap(find.text('Abrir Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Registro Rápido (15s)'), findsOneWidget);
      expect(find.text('Roberto Silva'), findsOneWidget);
      expect(find.text('Iniciar Gravação'), findsOneWidget);

      // Clica em iniciar gravação
      await tester.tap(find.text('Iniciar Gravação'));
      await tester.pumpAndSettle();

      expect(find.text('Concluir Gravação'), findsOneWidget);
      expect(mockRecordService.isRecording, isTrue);

      // Emite transcrição durante o ditado
      mockDictationService.emitTranscription(
        'Estudo com o Roberto, lição 18 ponto 3. Ficou pendente mostrar vídeo sobre batismo. Ele comentou que o trabalho vai mudar.',
      );
      await tester.pumpAndSettle();

      // Finaliza a gravação
      await tester.tap(find.text('Concluir Gravação'));
      await tester.pumpAndSettle();

      // Verifica preenchimento dos campos da pré-visualização estruturada
      expect(find.text('📖 Progresso: Lição 18, Ponto 3'), findsOneWidget);
      expect(find.text('Salvar Visita & Atualizar Briefing'), findsOneWidget);

      // Salva em 1 toque
      await tester.ensureVisible(find.text('Salvar Visita & Atualizar Briefing'));
      await tester.tap(find.text('Salvar Visita & Atualizar Briefing'));
      await tester.pumpAndSettle();

      // Diálogo fechou e snackbar apareceu
      expect(find.text('Registro Rápido (15s)'), findsNothing);
      expect(find.text('Visita salva e Briefing na Porta atualizado com sucesso!'), findsOneWidget);

      // Confere persistência no banco
      final vnList = await VoiceNotesManager(db, repo).getVoiceNotesForPerson(testPerson.id);
      expect(vnList.length, equals(1));
      expect(vnList.first.detectedLesson, equals(18));
      expect(vnList.first.detectedPoint, equals(3));
    });

    testWidgets('TC-W-MODAL-02: Robustez sob Dynamic Text Scaling 2.0x (sem RenderFlex overflow)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            repositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2.0),
              ),
              child: Scaffold(
                body: QuickVoiceNoteDialog(
                  person: testPerson,
                  initialTranscription: 'Lição 18 ponto 3. Ficou pendente mostrar vídeo.',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final err = tester.takeException();
      expect(err, isNull);
      expect(find.text('Registro Rápido (15s)'), findsOneWidget);
      expect(find.text('📖 Progresso: Lição 18, Ponto 3'), findsOneWidget);
    });

    testWidgets('TC-W-MODAL-03: Edição manual de campos estruturados não é apagada por alterações na transcrição', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            repositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QuickVoiceNoteDialog(
                person: testPerson,
                initialTranscription: 'Lição 18 ponto 3. Ficou de mostrar vídeo.',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Edita manualmente o campo de pendência
      final pendingFinder = find.widgetWithText(TextFormField, '📌 Pendência / Próximo Passo');
      await tester.enterText(pendingFinder, 'Comprar publicação especial');
      await tester.pumpAndSettle();

      // Altera o campo de transcrição
      final transcriptionFinder = find.byType(TextFormField).last;
      await tester.enterText(transcriptionFinder, 'Lição 18 ponto 3. Ficou de mostrar vídeo sobre fé.');
      await tester.pumpAndSettle();

      // Verifica se a edição manual foi estritamente preservada
      expect(find.text('Comprar publicação especial'), findsOneWidget);
    });

    testWidgets('TC-W-MODAL-04: Edição direta de Lição e Ponto nos text fields dedicados reflete no salvamento', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            repositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QuickVoiceNoteDialog(
                person: testPerson,
                initialTranscription: 'Conversa boa sobre esperança.',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Digita lição 25 e ponto 4 diretamente
      final lessonFinder = find.widgetWithText(TextFormField, 'Lição');
      final pointFinder = find.widgetWithText(TextFormField, 'Ponto / Parágrafo');

      await tester.enterText(lessonFinder, '25');
      await tester.enterText(pointFinder, '4');
      await tester.pumpAndSettle();

      expect(find.text('📖 Progresso: Lição 25, Ponto 4'), findsOneWidget);

      // Salva a visita
      await tester.ensureVisible(find.text('Salvar Visita & Atualizar Briefing'));
      await tester.tap(find.text('Salvar Visita & Atualizar Briefing'));
      await tester.pumpAndSettle();

      final vnList = await VoiceNotesManager(db, repo).getVoiceNotesForPerson(testPerson.id);
      expect(vnList.length, equals(1));
      expect(vnList.first.detectedLesson, equals(25));
      expect(vnList.first.detectedPoint, equals(4));
    });

    testWidgets('TC-W-MODAL-05: Tela estreita (320px) sob TextScaler 2.0x sem nenhum RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            repositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2.0),
              ),
              child: Scaffold(
                body: QuickVoiceNoteDialog(
                  person: testPerson,
                  initialTranscription: 'Lição 18 ponto 3. Ficou de mostrar vídeo sobre batismo.',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final err = tester.takeException();
      expect(err, isNull);
    });
  });
}
