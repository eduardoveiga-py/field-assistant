import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/ui/main_navigation_shell.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/appointments_screen.dart';
import 'package:ministerio_pessoal/ui/screens/contacts_map_screen.dart';
import 'package:ministerio_pessoal/ui/screens/settings_screen.dart';
import 'package:ministerio_pessoal/ui/screens/studies_screen.dart';
import 'package:ministerio_pessoal/ui/widgets/quick_voice_note_dialog.dart';
import 'package:ministerio_pessoal/voice_notes/audio_recording_service.dart';
import 'package:ministerio_pessoal/voice_notes/voice_dictation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Accessibility & VoiceOver/TalkBack Semantics Tests (P2-02)', () {
    testWidgets(
      'MainNavigationShell exposes semantic navigation labels on mobile',
      (tester) async {
        final handle = tester.ensureSemantics();
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = AppRepository(db);

        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(db),
                repositoryProvider.overrideWithValue(repo),
              ],
              child: const MaterialApp(home: MainNavigationShell()),
            ),
          );
          await tester.pump(const Duration(milliseconds: 200));

          expect(
            find.bySemanticsLabel(RegExp('Abrir menu Mais recursos')),
            findsOneWidget,
          );

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 50));
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets(
      'StudiesScreen, AppointmentsScreen, and SettingsScreen expose semantic headers and action labels',
      (tester) async {
        final handle = tester.ensureSemantics();
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = AppRepository(db);

        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(db),
                repositoryProvider.overrideWithValue(repo),
              ],
              child: const MaterialApp(home: StudiesScreen()),
            ),
          );
          await tester.pump(const Duration(milliseconds: 200));

          expect(
            find.bySemanticsLabel(RegExp('Iniciar novo estudo bíblico')),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel(RegExp('Abrir Base de Conhecimento')),
            findsOneWidget,
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(db),
                repositoryProvider.overrideWithValue(repo),
              ],
              child: const MaterialApp(home: AppointmentsScreen()),
            ),
          );
          await tester.pump(const Duration(milliseconds: 200));

          expect(
            find.bySemanticsLabel(RegExp('Agendar novo compromisso')),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel(RegExp('Sincronizar calendários')),
            findsOneWidget,
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(db),
                repositoryProvider.overrideWithValue(repo),
              ],
              child: const MaterialApp(home: SettingsScreen()),
            ),
          );
          await tester.pump(const Duration(milliseconds: 200));

          expect(
            find.bySemanticsLabel(
              RegExp('Abrir gerenciamento da fila de sincronização'),
            ),
            findsOneWidget,
          );

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 50));
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets(
      'ContactsMapScreen exposes semantic labels for offline maps, layers, compass, and zoom controls',
      (tester) async {
        final handle = tester.ensureSemantics();
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = AppRepository(db);

        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(db),
                repositoryProvider.overrideWithValue(repo),
              ],
              child: const MaterialApp(home: ContactsMapScreen()),
            ),
          );
          await tester.pump(const Duration(milliseconds: 200));

          expect(
            find.bySemanticsLabel(RegExp('Baixar e gerenciar mapas offline')),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel(RegExp('Abrir opções de camadas e motor')),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel(RegExp('Aproximar zoom do mapa')),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel(RegExp('Afastar zoom do mapa')),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel(RegExp('Bússola: alinhar mapa ao norte')),
            findsOneWidget,
          );

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 50));
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets(
      'QuickVoiceNoteDialog exposes live timer and microphone recording semantics',
      (tester) async {
        final handle = tester.ensureSemantics();
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = AppRepository(db);
        final now = DateTime.now();
        final person = PersonEntry(
          id: 'p_voice_1',
          name: 'Dona Helena',
          status: 'revisita',
          tags: '',
          firstContactAt: now,
          createdAt: now,
          updatedAt: now,
          revision: 1,
        );

        final fakeRecorder = LocalAudioRecordingService();
        final fakeDictation = UnsupportedVoiceDictationService();
        final fakePlayer = LocalAudioPlayerService();
        addTearDown(() {
          fakeRecorder.dispose();
          fakeDictation.dispose();
          fakePlayer.dispose();
        });

        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(db),
                repositoryProvider.overrideWithValue(repo),
              ],
              child: MaterialApp(
                home: Scaffold(
                  body: QuickVoiceNoteDialog(
                    person: person,
                    recordingService: fakeRecorder,
                    dictationService: fakeDictation,
                    playerService: fakePlayer,
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 200));

          expect(
            find.bySemanticsLabel(RegExp('Iniciar gravação de voz')),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel(RegExp('Tempo de gravação: 0 segundos')),
            findsOneWidget,
          );

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 50));
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets(
      'TC-SEM-01: AppointmentsScreen FAB has isButton and label containing Novo Compromisso',
      (tester) async {
        final handle = tester.ensureSemantics();
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = AppRepository(db);

        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(db),
                repositoryProvider.overrideWithValue(repo),
              ],
              child: const MaterialApp(home: AppointmentsScreen()),
            ),
          );
          await tester.pump(const Duration(milliseconds: 200));

          final fabFinder = find.byType(FloatingActionButton);
          expect(fabFinder, findsOneWidget);
          final semData = tester.getSemantics(fabFinder).getSemanticsData();
          expect(semData.label, contains('Novo Compromisso'));
          expect(semData.flagsCollection.isButton, isTrue);

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 50));
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets(
      'TC-SEM-02: StudiesScreen FAB has isButton and label containing Novo Estudo',
      (tester) async {
        final handle = tester.ensureSemantics();
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = AppRepository(db);

        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(db),
                repositoryProvider.overrideWithValue(repo),
              ],
              child: const MaterialApp(home: StudiesScreen()),
            ),
          );
          await tester.pump(const Duration(milliseconds: 200));

          final fabFinder = find.byType(FloatingActionButton);
          expect(fabFinder, findsOneWidget);
          final semData = tester.getSemantics(fabFinder).getSemanticsData();
          expect(semData.label, contains('Novo Estudo'));
          expect(semData.flagsCollection.isButton, isTrue);

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 50));
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets(
      'TC-SEM-03: QuickVoiceNoteDialog record button has button semantics with label and hint',
      (tester) async {
        final handle = tester.ensureSemantics();
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = AppRepository(db);
        final now = DateTime.now();
        final person = PersonEntry(
          id: 'p_voice_sem',
          name: 'Maria Teste',
          status: 'revisita',
          tags: '',
          firstContactAt: now,
          createdAt: now,
          updatedAt: now,
          revision: 1,
        );

        final fakeRecorder = LocalAudioRecordingService();
        final fakeDictation = UnsupportedVoiceDictationService();
        final fakePlayer = LocalAudioPlayerService();
        addTearDown(() {
          fakeRecorder.dispose();
          fakeDictation.dispose();
          fakePlayer.dispose();
        });

        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(db),
                repositoryProvider.overrideWithValue(repo),
              ],
              child: MaterialApp(
                home: Scaffold(
                  body: QuickVoiceNoteDialog(
                    person: person,
                    recordingService: fakeRecorder,
                    dictationService: fakeDictation,
                    playerService: fakePlayer,
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 200));

          final recordButtonFinder = find.bySemanticsLabel(
            RegExp('Iniciar gravação de voz'),
          );
          expect(recordButtonFinder, findsOneWidget);
          final semData = tester
              .getSemantics(recordButtonFinder)
              .getSemanticsData();
          expect(semData.label, contains('gravação'));
          expect(semData.hint, contains('microfone'));
          expect(semData.flagsCollection.isButton, isTrue);

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 50));
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets(
      'TC-SEM-04: ContactsMapScreen map controls have button semantics with labels and hints',
      (tester) async {
        final handle = tester.ensureSemantics();
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = AppRepository(db);

        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(db),
                repositoryProvider.overrideWithValue(repo),
              ],
              child: const MaterialApp(home: ContactsMapScreen()),
            ),
          );
          await tester.pump(const Duration(milliseconds: 200));

          final zoomInSemFinder = find.bySemanticsLabel(
            RegExp('Aproximar zoom do mapa'),
          );
          expect(zoomInSemFinder, findsOneWidget);
          final zoomInSem = tester
              .getSemantics(zoomInSemFinder)
              .getSemanticsData();
          expect(zoomInSem.label, contains('Aproximar zoom'));
          expect(zoomInSem.hint, contains('aproximação'));

          final zoomOutSemFinder = find.bySemanticsLabel(
            RegExp('Afastar zoom do mapa'),
          );
          expect(zoomOutSemFinder, findsOneWidget);
          final zoomOutSem = tester
              .getSemantics(zoomOutSemFinder)
              .getSemanticsData();
          expect(zoomOutSem.label, contains('Afastar zoom'));

          final gpsSemFinder = find.bySemanticsLabel(
            RegExp('minha localização GPS', caseSensitive: false),
          );
          expect(gpsSemFinder, findsOneWidget);
          final gpsSem = tester.getSemantics(gpsSemFinder).getSemanticsData();
          expect(gpsSem.label, contains('localização'));

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 50));
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets(
      'TC-SEM-05: Interactive buttons satisfy touch target size >= 48x48 dp',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = AppRepository(db);
        final now = DateTime.now();
        final person = PersonEntry(
          id: 'p_touch_target',
          name: 'João Alvo',
          status: 'revisita',
          tags: '',
          firstContactAt: now,
          createdAt: now,
          updatedAt: now,
          revision: 1,
        );

        final fakeRecorder = LocalAudioRecordingService();
        final fakeDictation = UnsupportedVoiceDictationService();
        final fakePlayer = LocalAudioPlayerService();
        addTearDown(() {
          fakeRecorder.dispose();
          fakeDictation.dispose();
          fakePlayer.dispose();
        });

        // 1. AppointmentsScreen FAB >= 48x48
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
            ],
            child: const MaterialApp(home: AppointmentsScreen()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        final apptFabSize = tester.getSize(find.byType(FloatingActionButton));
        expect(apptFabSize.width, greaterThanOrEqualTo(48.0));
        expect(apptFabSize.height, greaterThanOrEqualTo(48.0));

        // 2. StudiesScreen FAB >= 48x48
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
            ],
            child: const MaterialApp(home: StudiesScreen()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        final studiesFabSize = tester.getSize(
          find.byType(FloatingActionButton),
        );
        expect(studiesFabSize.width, greaterThanOrEqualTo(48.0));
        expect(studiesFabSize.height, greaterThanOrEqualTo(48.0));

        // 3. QuickVoiceNoteDialog record button >= 48x48
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: QuickVoiceNoteDialog(
                  person: person,
                  recordingService: fakeRecorder,
                  dictationService: fakeDictation,
                  playerService: fakePlayer,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        final recordBtnSize = tester.getSize(find.byType(ElevatedButton).first);
        expect(recordBtnSize.width, greaterThanOrEqualTo(48.0));
        expect(recordBtnSize.height, greaterThanOrEqualTo(48.0));

        // 4. ContactsMapScreen map controls >= 48x48
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
            ],
            child: const MaterialApp(home: ContactsMapScreen()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        final zoomInSize = tester.getSize(find.byTooltip('Aproximar Zoom'));
        expect(zoomInSize.width, greaterThanOrEqualTo(48.0));
        expect(zoomInSize.height, greaterThanOrEqualTo(48.0));

        final zoomOutSize = tester.getSize(find.byTooltip('Afastar Zoom'));
        expect(zoomOutSize.width, greaterThanOrEqualTo(48.0));
        expect(zoomOutSize.height, greaterThanOrEqualTo(48.0));

        final gpsSize = tester.getSize(find.byTooltip('Minha Localização GPS'));
        expect(gpsSize.width, greaterThanOrEqualTo(48.0));
        expect(gpsSize.height, greaterThanOrEqualTo(48.0));

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );
  });
}
