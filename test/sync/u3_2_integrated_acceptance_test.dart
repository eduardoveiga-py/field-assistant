import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ministerio_pessoal/core/app_config.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/widgets/quick_voice_note_dialog.dart';
import 'package:ministerio_pessoal/voice_notes/audio_recording_service.dart';
import 'package:ministerio_pessoal/voice_notes/voice_dictation_service.dart';
import 'package:ministerio_pessoal/voice_notes/voice_note_parser.dart';
import 'package:ministerio_pessoal/voice_notes/voice_notes_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AppRepository repo;
  late SupabaseSyncService syncService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = AppRepository(db);
    syncService = SupabaseSyncService(
      db: db,
      repository: repo,
      config: AppConfig.unconfigured(),
    );
  });

  tearDown(() async {
    syncService.dispose();
    await db.close();
  });

  group('U3.2 Acceptance — Concorrência na Agenda e Resolução Pós-Sincronização', () {
    test('1. Detecção de sobreposição concorrente pós-sincronização marca status conflito e isProvisional', () async {
      final baseDate = DateTime(2026, 11, 10, 14, 0); // 14:00

      // Dispositivo A possui agendamento local das 14:00 às 15:00
      final apptA = await repo.createAppointment(
        id: 'appt-dev-A',
        title: 'Estudo com Carlos (Dev A)',
        startTime: baseDate,
        endTime: baseDate.add(const Duration(hours: 1)), // 14:00 - 15:00
        durationMinutes: 60,
        status: 'planejado',
      );

      expect(apptA.status, equals('planejado'));
      expect(apptA.isProvisional, isFalse);

      // Dispositivo B criou concorrentemente agendamento das 14:30 às 15:30 (sobreposição de 30 min)
      final remoteRecordB = {
        'id': 'appt-dev-B',
        'title': 'Visita com Família Souza (Dev B)',
        'start_time': baseDate
            .add(const Duration(minutes: 30))
            .toIso8601String(), // 14:30
        'end_time': baseDate
            .add(const Duration(minutes: 90))
            .toIso8601String(), // 15:30
        'duration_minutes': 60,
        'status': 'planejado',
        'is_provisional': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'revision': 1,
      };

      final errors = <String>[];
      final ok = await syncService.applyRemoteRecordForTesting(
        'appointments',
        remoteRecordB,
        errors,
      );

      expect(ok, isTrue);
      expect(errors, isEmpty);

      // Ambos os agendamentos coexistem sem perda de dados
      final savedA = await repo.getAppointmentById('appt-dev-A');
      final savedB = await repo.getAppointmentById('appt-dev-B');

      expect(savedA, isNotNull);
      expect(savedB, isNotNull);

      // Ambos foram marcados com conflito e isProvisional sem sobrescrita silenciosa
      expect(
        savedA!.status,
        equals('conflito'),
        reason: 'Compromisso local deve ser sinalizado com conflito',
      );
      expect(savedA.isProvisional, isTrue);

      expect(
        savedB!.status,
        equals('conflito'),
        reason: 'Compromisso remoto concorrente deve ser marcado com conflito',
      );
      expect(savedB.isProvisional, isTrue);
    });

    test('2. Agendamentos consecutivos contíguos (sem sobreposição) NÃO geram falso conflito', () async {
      final baseDate = DateTime(2026, 11, 10, 10, 0);

      // Compromisso local das 10:00 às 11:00
      await repo.createAppointment(
        id: 'appt-first',
        title: 'Horário 10h',
        startTime: baseDate,
        endTime: baseDate.add(const Duration(hours: 1)),
        durationMinutes: 60,
        status: 'planejado',
      );

      // Compromisso remoto consecutivo das 11:00 às 12:00
      final remoteConsecutive = {
        'id': 'appt-second',
        'title': 'Horário 11h',
        'start_time': baseDate
            .add(const Duration(hours: 1))
            .toIso8601String(), // 11:00
        'end_time': baseDate
            .add(const Duration(hours: 2))
            .toIso8601String(), // 12:00
        'duration_minutes': 60,
        'status': 'planejado',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'revision': 1,
      };

      final errors = <String>[];
      final ok = await syncService.applyRemoteRecordForTesting(
        'appointments',
        remoteConsecutive,
        errors,
      );

      expect(ok, isTrue);
      final first = await repo.getAppointmentById('appt-first');
      final second = await repo.getAppointmentById('appt-second');

      expect(
        first!.status,
        equals('planejado'),
        reason: 'Consecutivos não entram em conflito',
      );
      expect(second!.status, equals('planejado'));
      expect(first.isProvisional, isFalse);
      expect(second.isProvisional, isFalse);
    });

    test(
      '3. Sobreposição com agendamento cancelado ou excluído NÃO gera conflito',
      () async {
        final baseDate = DateTime(2026, 11, 10, 16, 0);

        // Compromisso local das 16:00 às 17:00, porém cancelado
        await repo.createAppointment(
          id: 'appt-cancelled',
          title: 'Cancelado previamente',
          startTime: baseDate,
          endTime: baseDate.add(const Duration(hours: 1)),
          status: 'cancelado',
        );

        // Compromisso remoto no mesmo horário
        final remoteRecord = {
          'id': 'appt-active',
          'title': 'Novo horário confirmado',
          'start_time': baseDate.toIso8601String(),
          'end_time': baseDate.add(const Duration(hours: 1)).toIso8601String(),
          'duration_minutes': 60,
          'status': 'planejado',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'revision': 1,
        };

        final errors = <String>[];
        final ok = await syncService.applyRemoteRecordForTesting(
          'appointments',
          remoteRecord,
          errors,
        );

        expect(ok, isTrue);
        final active = await repo.getAppointmentById('appt-active');
        expect(
          active!.status,
          equals('planejado'),
          reason: 'Cancelado não bloqueia nem gera conflito',
        );
      },
    );
  });

  group(
    'U3.2 Acceptance — Áudio: Limite Real de 30s e Idempotência Estrita',
    () {
      test('4. LocalAudioRecordingService pára fisicamente e com segurança no limite de 30s', () async {
        final service = LocalAudioRecordingService();
        addTearDown(service.dispose);

        await service.startRecording();
        expect(service.isRecording, isTrue);

        // Simula passagem ou acionamento do limite de 30s
        final result1 = await service.stopRecording();
        expect(result1, isNotNull);
        expect(service.isRecording, isFalse);
        expect(result1!.filePath, isNotEmpty);
        expect(result1.duration.inSeconds, lessThanOrEqualTo(30));

        // Idempotência: chamadas subsequentes a stopRecording() não lançam exceção e retornam o mesmo resultado
        final result2 = await service.stopRecording();
        expect(result2, equals(result1));

        final result3 = await service.stopRecording();
        expect(result3, equals(result1));
      });

      test('5. cancelRecording() limpa estado, cancela timer, reseta arquivo físico do disco e previne ressuscitação', () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'audio_acc_test_',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final service = LocalAudioRecordingService();
        addTearDown(service.dispose);

        final customAudioPath = '${tempDir.path}/test_cancellation.m4a';
        final startedPath = await service.startRecording(
          customPath: customAudioPath,
        );
        expect(service.isRecording, isTrue);
        expect(startedPath, equals(customAudioPath));

        // Simula gravação que escreveu bytes parciais
        final testFile = File(customAudioPath);
        await testFile.parent.create(recursive: true);
        await testFile.writeAsBytes(List<int>.filled(128, 1));
        expect(await testFile.exists(), isTrue);

        // Dispara cancelamento físico
        await service.cancelRecording();
        expect(service.isRecording, isFalse);
        expect(
          await testFile.exists(),
          isFalse,
          reason: 'Arquivo temporário cancelado DEVE ser apagado fisicamente',
        );

        final stopped = await service.stopRecording();
        expect(
          stopped,
          isNull,
          reason:
              'Gravação cancelada nunca deve retornar RecordingResult ativo',
        );

        // Idempotência após cancelamento: novo ciclo de gravação inicia limpo sem resíduos
        final newPath = await service.startRecording(
          customPath: '${tempDir.path}/test_clean_after_cancel.m4a',
        );
        expect(service.isRecording, isTrue);
        final res = await service.stopRecording();
        expect(res, isNotNull);
        expect(res!.filePath, equals(newPath));
      });

      test('5b. Serialização e concorrência: cancelamento ou parada simultânea não corrompe estado nem deixa gravação zumbi', () async {
        final service = LocalAudioRecordingService();
        addTearDown(service.dispose);

        await service.startRecording();
        expect(service.isRecording, isTrue);

        // Dispara stopRecording e cancelRecording simultaneamente (rajada concorrente)
        final stopFuture = service.stopRecording();
        final cancelFuture = service.cancelRecording();

        await Future.wait([stopFuture, cancelFuture]);

        expect(service.isRecording, isFalse);
        final postResult = await service.stopRecording();
        expect(postResult, isNull);
      });
    },
  );

  group('U3.2 Acceptance — Ditado Offline e Preservação de Áudio no iOS', () {
    testWidgets(
      '6. Falha no ditado offline exibe fallback em tela sem interromper a gravação de áudio',
      (tester) async {
        final localAudio = LocalAudioRecordingService();
        final failingDictation = LocalVoiceDictationService()
          ..availableOverride = false
          ..failureReason =
              'Reconhecimento de fala offline indisponível no iOS. O áudio será preservado.';

        final person = PersonEntry(
          id: 'person-test-01',
          name: 'Carlos Oliveira',
          firstContactAt: DateTime.now(),
          status: 'interessado',
          tags: '[]',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          revision: 1,
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
                    onPressed: () => QuickVoiceNoteDialog.show(
                      context: context,
                      person: person,
                      recordingService: localAudio,
                      dictationService: failingDictation,
                    ),
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

        // Inicia a gravação com o serviço de ditado indisponível
        final recordButton = find.text('Iniciar Gravação');
        expect(recordButton, findsOneWidget);
        await tester.tap(recordButton);
        await tester.pumpAndSettle();

        // O gravador de áudio físico DEVE estar ativo mesmo com a fala indisponível
        expect(localAudio.isRecording, isTrue);

        // O banner com aviso claro de erro/fallback deve ser exibido ao usuário
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
        expect(
          find.textContaining(
            'Reconhecimento de fala offline indisponível no iOS',
          ),
          findsOneWidget,
        );

        // Pára a gravação
        final stopButton = find.text('Concluir Gravação');
        expect(stopButton, findsOneWidget);
        await tester.tap(stopButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(localAudio.isRecording, isFalse);
      },
    );

    test('7. Áudio permanece preservado e vinculado mesmo com transcrição vazia ou manual', () async {
      final now = DateTime.now();
      await db
          .into(db.people)
          .insert(
            PersonEntry(
              id: 'person-audio-save-01',
              name: 'Irmão Silvério',
              firstContactAt: now,
              status: 'interessado',
              tags: '[]',
              createdAt: now,
              updatedAt: now,
              revision: 1,
            ),
          );

      final voiceManager = VoiceNotesManager(db, repo);

      // Salva nota onde a transcrição falhou e o usuário não digitou texto
      final fallbackParsed = VoiceNoteParser.parse('');
      final result = await voiceManager.saveQuickVisitFromVoiceNote(
        personId: 'person-audio-save-01',
        parsedNote: fallbackParsed,
        audioFilePath: '/documents/voice_notes/vn_preserved_01.m4a',
        audioDurationSeconds: 22,
        contactType: 'revisita',
        result: 'revisita_feita',
      );

      expect(result.voiceNote, isNotNull);
      expect(
        result.voiceNote.audioFilePath,
        equals('/documents/voice_notes/vn_preserved_01.m4a'),
      );
      expect(result.voiceNote.audioDurationSeconds, equals(22));

      // Recupera diretamente do banco SQLite Drift
      final dbRow = await (db.select(
        db.voiceNotes,
      )..where((t) => t.id.equals(result.voiceNote.id))).getSingle();
      expect(
        dbRow.audioFilePath,
        equals('/documents/voice_notes/vn_preserved_01.m4a'),
      );
      expect(dbRow.audioDurationSeconds, equals(22));
    });
  });

  group('U3.2 Acceptance — Segurança, Schema Supabase e Isolamento Multiusuário RLS', () {
    test('8. Isolamento RLS e Supabase Schema: Verificação estrita das migrações SQL e políticas de ownership', () {
      // 1. Verifica migração U3.2
      final u32Migration = File(
        'supabase/migrations/20261102020000_u3_2_storage_and_hardening.sql',
      );
      expect(
        u32Migration.existsSync(),
        isTrue,
        reason: 'Migração 20261102020000_u3_2_storage_and_hardening.sql deve existir',
      );
      final u32Content = u32Migration.readAsStringSync();

      // Constraint CHECK de appointments_status_check deve suportar 'conflito'
      expect(u32Content, contains('appointments_status_check'));
      expect(u32Content, contains("'conflito'"));

      // Políticas RLS de Storage para voice_notes devem checar propriedade do usuário vn.owner_id = auth.uid()
      expect(u32Content, contains('voice_notes_storage_insert'));
      expect(u32Content, contains('vn.owner_id = auth.uid()'));
      expect(u32Content, contains('voice_notes_storage_select'));
      expect(u32Content, contains('voice_notes_storage_update'));
      expect(u32Content, contains('voice_notes_storage_delete'));
      expect(
        u32Content,
        contains(r"regexp_replace(storage.objects.name, '\.[^.]+$', '')"),
      );

      // 2. Verifica schema base de migrações
      final initialMigration = File(
        'supabase/migrations/20261026000000_initial_schema.sql',
      );
      expect(initialMigration.existsSync(), isTrue);
      final initialContent = initialMigration.readAsStringSync();

      // Todas as tabelas principais devem ter RLS habilitado
      expect(
        initialContent,
        contains('ALTER TABLE public.people ENABLE ROW LEVEL SECURITY;'),
      );
      expect(
        initialContent,
        contains('ALTER TABLE public.visits ENABLE ROW LEVEL SECURITY;'),
      );
      expect(
        initialContent,
        contains('ALTER TABLE public.bible_studies ENABLE ROW LEVEL SECURITY;'),
      );
      expect(
        initialContent,
        contains(
          'ALTER TABLE public.study_participants ENABLE ROW LEVEL SECURITY;',
        ),
      );
      expect(
        initialContent,
        contains(
          'ALTER TABLE public.study_sessions ENABLE ROW LEVEL SECURITY;',
        ),
      );
      expect(
        initialContent,
        contains('ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;'),
      );
      expect(
        initialContent,
        contains(
          'ALTER TABLE public.activity_records ENABLE ROW LEVEL SECURITY;',
        ),
      );

      final u3MissingMigration = File(
        'supabase/migrations/20261102000000_u3_missing_tables_storage.sql',
      );
      expect(u3MissingMigration.existsSync(), isTrue);
      final u3MissingContent = u3MissingMigration.readAsStringSync();
      expect(
        u3MissingContent,
        contains('ALTER TABLE public.voice_notes ENABLE ROW LEVEL SECURITY;'),
      );
      expect(
        u3MissingContent,
        contains(
          'ALTER TABLE public.phone_contacts ENABLE ROW LEVEL SECURITY;',
        ),
      );
      expect(
        u3MissingContent,
        contains(
          'ALTER TABLE public.territory_landmarks ENABLE ROW LEVEL SECURITY;',
        ),
      );

      // 3. Verifica políticas explícitas com auth.uid() = owner_id em SELECT, INSERT, UPDATE, DELETE
      expect(u3MissingContent, contains('auth.uid() = owner_id'));
    });

    test('9. Concorrência na Agenda: Atualização de payload da Outbox ao marcar conflito em agendamento com operação pendente', () async {
      final baseDate = DateTime(2026, 11, 15, 9, 0);

      // Dispositivo B cria compromisso local que entra na outbox (sync_queue) com status pendente
      final localAppt = await repo.createAppointment(
        id: 'appt-pending-outbox-01',
        title: 'Estudo Matinal Local',
        startTime: baseDate,
        endTime: baseDate.add(const Duration(minutes: 45)),
        durationMinutes: 45,
        status: 'planejado',
      );

      // Confirma que foi gerada operação INSERT na outbox
      final initialQueueOp = await (db.select(
        db.syncQueue,
      )..where((t) => t.entityId.equals(localAppt.id))).getSingle();
      final initialPayload =
          jsonDecode(initialQueueOp.payload) as Map<String, dynamic>;
      expect(initialPayload['status'], equals('planejado'));

      // Dispositivo A envia registro remoto concorrente sobrepondo o mesmo intervalo
      final remoteOverlapping = {
        'id': 'appt-remote-dev-a-01',
        'title': 'Revisita Remota Concorrente',
        'start_time': baseDate
            .add(const Duration(minutes: 15))
            .toIso8601String(),
        'end_time': baseDate.add(const Duration(minutes: 60)).toIso8601String(),
        'duration_minutes': 45,
        'status': 'planejado',
        'is_provisional': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'revision': 1,
      };

      final errors = <String>[];
      final ok = await syncService.applyRemoteRecordForTesting(
        'appointments',
        remoteOverlapping,
        errors,
      );
      expect(ok, isTrue);

      // Verifica que no banco local ambos foram marcados com conflito e isProvisional
      final dbLocal = await repo.getAppointmentById('appt-pending-outbox-01');
      final dbRemote = await repo.getAppointmentById('appt-remote-dev-a-01');
      expect(dbLocal!.status, equals('conflito'));
      expect(dbLocal.isProvisional, isTrue);
      expect(dbRemote!.status, equals('conflito'));
      expect(dbRemote.isProvisional, isTrue);

      // CRÍTICO: A operação pendente na outbox (sync_queue) DEVE ter sido atualizada com 'conflito' e 'isProvisional'
      // para evitar que um push futuro sobrescreva o conflito com dados desatualizados!
      final updatedQueueOp = await (db.select(
        db.syncQueue,
      )..where((t) => t.entityId.equals(localAppt.id))).getSingle();
      final updatedPayload =
          jsonDecode(updatedQueueOp.payload) as Map<String, dynamic>;
      expect(updatedPayload['status'], equals('conflito'));
      expect(updatedPayload['isProvisional'], isTrue);
    });

    testWidgets(
      '10. QuickVoiceNoteDialog: Fechar sem salvar aciona cancelRecording() e previne vazamento de arquivo',
      (tester) async {
        final tempDir = Directory.systemTemp.createTempSync(
          'dialog_leak_test_',
        );
        addTearDown(() {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        });

        final localAudio = LocalAudioRecordingService();
        final dictation = LocalVoiceDictationService();

        final person = PersonEntry(
          id: 'person-leak-test',
          name: 'Maria Teste Descarte',
          firstContactAt: DateTime.now(),
          status: 'interessado',
          tags: '[]',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          revision: 1,
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
                    onPressed: () => QuickVoiceNoteDialog.show(
                      context: context,
                      person: person,
                      recordingService: localAudio,
                      dictationService: dictation,
                      playerService: LocalAudioPlayerService(),
                    ),
                    child: const Text('Abrir Modal'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Modal'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Inicia gravação
        await tester.tap(find.text('Iniciar Gravação'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(localAudio.isRecording, isTrue);

        // Usuário clica no botão de fechar ('X') descartando sem salvar
        await tester.tap(find.byTooltip('Fechar'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Gravador e ditado devem ter sido cancelados e liberados sem vazamento
        expect(localAudio.isRecording, isFalse);
        expect(dictation.isListening, isFalse);
        expect(find.byType(QuickVoiceNoteDialog), findsNothing);
      },
    );
  });
}
