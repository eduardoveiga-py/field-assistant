import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';

import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/voice_notes/audio_recording_service.dart';
import 'package:ministerio_pessoal/voice_notes/voice_dictation_service.dart';
import 'package:ministerio_pessoal/voice_notes/voice_notes_manager.dart';
import 'package:ministerio_pessoal/ui/widgets/quick_voice_note_dialog.dart';

void main() {
  group('Empirical Challenge: Voice Dictation Platform Simulation Matrix', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('CHALLENGE-01: Exhaustive target platform capability matrix', () {
      final expectations = <TargetPlatform, bool>{
        TargetPlatform.linux: false,
        TargetPlatform.fuchsia: false,
        TargetPlatform.windows: true,
        TargetPlatform.macOS: true,
        TargetPlatform.android: true,
        TargetPlatform.iOS: true,
      };

      for (final entry in expectations.entries) {
        debugDefaultTargetPlatformOverride = entry.key;
        expect(
          VoiceDictationService.isPlatformSupported,
          equals(entry.value),
          reason: 'Platform ${entry.key} must have isPlatformSupported == ${entry.value}',
        );
      }
    });

    test('CHALLENGE-02: Factory resolution across all target platforms', () {
      final platforms = [
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.android,
        TargetPlatform.iOS,
      ];

      for (final p in platforms) {
        debugDefaultTargetPlatformOverride = p;
        final service = VoiceDictationService.platform();
        if (p == TargetPlatform.linux || p == TargetPlatform.fuchsia) {
          expect(
            service,
            isA<UnsupportedVoiceDictationService>(),
            reason: 'Platform $p must return UnsupportedVoiceDictationService',
          );
        } else {
          expect(
            service,
            isA<RealVoiceDictationService>(),
            reason: 'Platform $p must return RealVoiceDictationService',
          );
        }
      }
    });

    test('CHALLENGE-03: Factory overrideService takes absolute precedence on all platforms', () {
      final override = LocalVoiceDictationService();

      for (final p in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = p;
        final service = VoiceDictationService.platform(overrideService: override);
        expect(service, same(override));
      }
    });
  });

  group('Empirical Challenge: UnsupportedVoiceDictationService Hardening & Stress', () {
    late UnsupportedVoiceDictationService service;

    setUp(() {
      service = UnsupportedVoiceDictationService();
    });

    test('CHALLENGE-04: isAvailable and isListening under stress', () async {
      expect(service.isListening, isFalse);
      expect(await service.isAvailable(), isFalse);

      // Concurrent repeated calls to isAvailable
      final results = await Future.wait(List.generate(20, (_) => service.isAvailable()));
      expect(results.every((r) => r == false), isTrue);
      expect(service.isListening, isFalse);
    });

    test('CHALLENGE-05: startListening with null onError never throws unhandled exception', () async {
      bool onResultCalled = false;
      await expectLater(
        service.startListening(
          onResult: (_) => onResultCalled = true,
          onError: null,
        ),
        completes,
      );
      expect(onResultCalled, isFalse);
      expect(service.isListening, isFalse);
    });

    test('CHALLENGE-06: startListening with onError captures localized error text', () async {
      String? caughtError;
      bool onResultCalled = false;

      await service.startListening(
        onResult: (_) => onResultCalled = true,
        onError: (err) => caughtError = err,
      );

      expect(onResultCalled, isFalse);
      expect(caughtError, isNotNull);
      expect(caughtError, contains('Ditado por voz indisponível nesta plataforma'));
      expect(caughtError, contains('Digite o resumo manualmente'));
      expect(service.isListening, isFalse);
    });

    test('CHALLENGE-07: Rapid sequential and concurrent stopListening and dispose calls do not crash', () async {
      // Rapid stopListening
      for (int i = 0; i < 10; i++) {
        await expectLater(service.stopListening(), completes);
      }

      // Dispose multiple times
      for (int i = 0; i < 5; i++) {
        service.dispose();
      }

      // startListening after dispose still invokes onError gracefully
      String? caughtError;
      await service.startListening(
        onResult: (_) {},
        onError: (err) => caughtError = err,
      );
      expect(caughtError, isNotNull);
    });
  });

  group('Empirical Challenge: RealVoiceDictationService Direct Instantiation on Linux', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('CHALLENGE-08: Direct RealVoiceDictationService on Linux returns isAvailable == false immediately without touching STT', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final realService = RealVoiceDictationService();

      expect(realService.isListening, isFalse);
      final available = await realService.isAvailable();
      expect(available, isFalse);
      expect(realService.isListening, isFalse);
    });

    test('CHALLENGE-09: Direct RealVoiceDictationService on Linux triggers fallback onError without crash', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final realService = RealVoiceDictationService();

      String? caughtError;
      bool onResultCalled = false;

      await realService.startListening(
        onResult: (_) => onResultCalled = true,
        onError: (err) => caughtError = err,
      );

      expect(onResultCalled, isFalse);
      expect(caughtError, isNotNull);
      expect(caughtError, contains('Reconhecimento de fala indisponível no dispositivo'));
      expect(caughtError, contains('Digite o resumo manualmente'));
      expect(realService.isListening, isFalse);

      await realService.stopListening();
      realService.dispose();
    });

    test('CHALLENGE-10: Direct RealVoiceDictationService on Linux with null onError does not crash', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final realService = RealVoiceDictationService();

      await expectLater(
        realService.startListening(
          onResult: (_) {},
          onError: null,
        ),
        completes,
      );
      expect(realService.isListening, isFalse);
      realService.dispose();
    });
  });

  group('Empirical Challenge: QuickVoiceNoteDialog Desktop & Platform Stress Tests', () {
    late AppDatabase db;
    late AppRepository repo;
    late PersonEntry testPerson;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
      testPerson = await repo.createPerson(
        name: 'Carlos Oliveira',
        status: 'revisita',
      );
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('CHALLENGE-11: Linux full end-to-end flow with audio recording and manual entry', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final tempDir = Directory.systemTemp.createTempSync('challenge11_audio_');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });
      final audioFixture = File('${tempDir.path}/recorded_visit.m4a')
        ..writeAsBytesSync([
          0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x4D, 0x34, 0x41, 0x20,
          ...List.filled(64, 0x41),
        ]);
      try {
        final mockRecordService = LocalAudioRecordingService(
          defaultFilePath: audioFixture.path,
        );

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
                      );
                    },
                    child: const Text('Abrir Modal'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Modal'));
        await tester.pumpAndSettle();

        // Verify the Linux fallback notice is present
        expect(find.textContaining('Ditado de voz indisponível nesta plataforma (Linux/Desktop)'), findsOneWidget);

        // Verify Start Recording button is present and starts audio
        final startBtn = find.text('Iniciar Gravação');
        expect(startBtn, findsOneWidget);
        await tester.tap(startBtn);
        await tester.pump(const Duration(milliseconds: 100));

        expect(mockRecordService.isRecording, isTrue);

        // Simulate 10 seconds of recorded audio
        await mockRecordService.simulateElapsedSeconds(10);
        await tester.pump(const Duration(milliseconds: 100));

        // Stop recording
        final stopBtn = find.text('Concluir Gravação');
        expect(stopBtn, findsOneWidget);
        await tester.tap(stopBtn);
        await tester.pumpAndSettle();

        expect(mockRecordService.isRecording, isFalse);

        // Enter manual lesson and point
        final lessonField = find.widgetWithText(TextFormField, 'Lição');
        final pointField = find.widgetWithText(TextFormField, 'Ponto / Parágrafo');
        await tester.enterText(lessonField, '12');
        await tester.enterText(pointField, '4');
        await tester.pumpAndSettle();

        // Enter manual pending doubt
        final pendingField = find.widgetWithText(TextFormField, '📌 Pendência / Próximo Passo');
        await tester.enterText(pendingField, 'Levar folheto sobre o futuro');
        await tester.pumpAndSettle();

        // Save visit
        final saveBtn = find.text('Salvar Visita & Atualizar Briefing');
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // Dialog closed
        expect(find.text('Registro Rápido (15s)'), findsNothing);

        // Verify saved data in database
        final manager = VoiceNotesManager(db, repo);
        final notes = await manager.getVoiceNotesForPerson(testPerson.id);
        expect(notes.length, equals(1));
        expect(notes.first.detectedLesson, equals(12));
        expect(notes.first.detectedPoint, equals(4));
        expect(notes.first.extractedPendingDoubt, equals('Levar folheto sobre o futuro'));
        expect(notes.first.audioDurationSeconds, equals(10));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('CHALLENGE-12: Windows platform simulation with fallback LocalVoiceDictationService', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
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

        await tester.tap(find.text('Abrir Modal'));
        await tester.pumpAndSettle();

        // On Windows with working dictation, unsupported notice is NOT shown
        expect(find.textContaining('Ditado de voz indisponível'), findsNothing);

        // Start recording
        await tester.tap(find.text('Iniciar Gravação'));
        await tester.pump(const Duration(milliseconds: 100));

        expect(mockRecordService.isRecording, isTrue);
        expect(mockDictationService.isListening, isTrue);

        // Dictate text
        mockDictationService.emitTranscription('Lição 7 ponto 2. Ficou pendente responder dúvida.');
        await tester.pumpAndSettle();

        // Stop recording
        await tester.tap(find.text('Concluir Gravação'));
        await tester.pumpAndSettle();

        // In ParsedVoiceNote, single digits are 0-padded (e.g. Lição 07, Ponto 2)
        expect(find.text('📖 Progresso: Lição 07, Ponto 2'), findsOneWidget);

        await tester.ensureVisible(find.text('Salvar Visita & Atualizar Briefing'));
        await tester.tap(find.text('Salvar Visita & Atualizar Briefing'));
        await tester.pumpAndSettle();

        final notes = await VoiceNotesManager(db, repo).getVoiceNotesForPerson(testPerson.id);
        expect(notes.length, equals(1));
        expect(notes.first.detectedLesson, equals(7));
        expect(notes.first.detectedPoint, equals(2));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('CHALLENGE-13: macOS platform simulation under SunMode (High Contrast)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        final mockRecordService = LocalAudioRecordingService();
        final mockDictationService = LocalVoiceDictationService();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
            ],
            child: MaterialApp(
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
                    child: const Text('Abrir Modal SunMode'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Modal SunMode'));
        await tester.pumpAndSettle();

        // SunMode dialog renders without any layout exceptions
        expect(tester.takeException(), isNull);
        expect(find.text('Registro Rápido (15s)'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('CHALLENGE-14: Rapid tap on Iniciar Gravação followed immediately by Concluir Gravação', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        final mockRecordService = LocalAudioRecordingService();

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
                      );
                    },
                    child: const Text('Abrir Modal'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Modal'));
        await tester.pumpAndSettle();

        // Tap start
        await tester.tap(find.text('Iniciar Gravação'));
        // Immediate tap stop without elapsed time
        await tester.pump();
        await tester.tap(find.text('Concluir Gravação'));
        await tester.pumpAndSettle();

        expect(mockRecordService.isRecording, isFalse);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('CHALLENGE-15: Closing dialog with close icon while recording does not leak or crash', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        final mockRecordService = LocalAudioRecordingService();

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
                      );
                    },
                    child: const Text('Abrir Modal'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Modal'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Iniciar Gravação'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(mockRecordService.isRecording, isTrue);

        // Close dialog via 'X' icon
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(find.text('Registro Rápido (15s)'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
