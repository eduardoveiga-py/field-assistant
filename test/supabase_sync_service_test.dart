import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/sync/sync_engine.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';

void main() {
  group('SupabaseSyncService - Sincronização e Resiliência Offline', () {
    late AppDatabase db;
    late AppRepository repo;
    late SupabaseSyncService syncService;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
      syncService = SupabaseSyncService(
        db: db,
        repository: repo,
        supabaseUrl: '', // Não configurado
        supabaseAnonKey: '',
      );
    });

    tearDown(() async {
      syncService.dispose();
      await db.close();
    });

    test('TC-SYNC-04: Relatório honesto — quando não configurado, reporta waitingConnection e não simula sucesso falso', () async {
      expect(syncService.isConfigured, isFalse);

      // Insere uma operação pendente na fila
      await repo.createPerson(name: 'Irmão Teste');

      final result = await syncService.processQueue();

      expect(result.totalProcessed, greaterThanOrEqualTo(1));
      expect(result.successCount, equals(0));
      expect(result.message, contains('não configurado'));
      expect(syncService.currentStatus, equals(SyncStatus.waitingConnection));
    });

    test(
      'TC-SYNC-05: Fila vazia reporta status synced com 0 operações',
      () async {
        final result = await syncService.processQueue();

        expect(result.totalProcessed, equals(0));
        expect(result.successCount, equals(0));
        expect(syncService.currentStatus, equals(SyncStatus.synced));
      },
    );

    test('TC-SYNC-06: Sanitização de payload remove caminhos de arquivos locais de voice_notes', () {
      final voiceNotePayload = {
        'id': 'vn-123',
        'person_id': 'p-456',
        'transcription': 'Estudo realizado na lição 18 ponto 3',
        'audio_file_path':
            '/data/user/0/com.app/app_flutter/voice_notes/secret_note.m4a',
        'audio_duration_seconds': 15,
      };

      final cleanPayload = SupabaseSyncService.sanitizePayload(
        'voice_notes',
        voiceNotePayload,
      );

      expect(cleanPayload.containsKey('audio_file_path'), isFalse);
      expect(
        cleanPayload['transcription'],
        equals('Estudo realizado na lição 18 ponto 3'),
      );
      expect(cleanPayload['audio_duration_seconds'], equals(15));
      expect(cleanPayload['id'], equals('vn-123'));
    });

    test('TC-SYNC-07: Mapeamento de entidades para nomes oficiais de tabelas PostgreSQL', () {
      expect(
        SupabaseSyncService.mapEntityToRemoteTable('people'),
        equals('people'),
      );
      expect(
        SupabaseSyncService.mapEntityToRemoteTable('visits'),
        equals('visits'),
      );
      expect(
        SupabaseSyncService.mapEntityToRemoteTable('bibleStudies'),
        equals('bible_studies'),
      );
      expect(
        SupabaseSyncService.mapEntityToRemoteTable('studyParticipants'),
        equals('study_participants'),
      );
      expect(
        SupabaseSyncService.mapEntityToRemoteTable('studySessions'),
        equals('study_sessions'),
      );
      expect(
        SupabaseSyncService.mapEntityToRemoteTable('appointments'),
        equals('appointments'),
      );
      expect(
        SupabaseSyncService.mapEntityToRemoteTable('activityRecords'),
        equals('activity_records'),
      );
      expect(
        SupabaseSyncService.mapEntityToRemoteTable('voiceNotes'),
        equals('voice_notes'),
      );
    });
  });
}
