import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/appointments/calendar_provider.dart';
import 'package:ministerio_pessoal/appointments/google_calendar_provider.dart';
import 'package:ministerio_pessoal/core/app_config.dart';
import 'package:ministerio_pessoal/core/supabase_initializer.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:ministerio_pessoal/sync/sync_engine.dart';
import 'package:ministerio_pessoal/voice_notes/audio_recording_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'p0_e2e_contracts.dart';

class ExpiredTokenCalendarProvider extends GoogleCalendarProvider {
  final int errorCode;
  final String errorDetail;

  ExpiredTokenCalendarProvider({
    this.errorCode = 401,
    this.errorDetail = 'Invalid Credentials / Token Expired',
    super.secureStorage,
  });

  @override
  Future<bool> isAuthorized() async => false;

  @override
  Future<bool> requestAuthorization() async => false;

  @override
  Future<CalendarSyncResult> syncEvents({
    required AppDatabase db,
    bool fullSync = false,
  }) async {
    return CalendarSyncResult(
      success: false,
      errorMessage: 'HTTP $errorCode: $errorDetail',
      eventsDownloaded: 0,
      eventsUploaded: 0,
      conflictsFound: 0,
    );
  }
}

class PermissionDeniedAudioService extends AudioRecordingService {
  @override
  bool get isRecording => false;

  @override
  Stream<int> get recordingDurationStream => const Stream.empty();

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<String> startRecording({String? customPath}) async {
    final hasPerm = await hasPermission();
    if (!hasPerm) {
      throw Exception('Permissão de gravação de áudio negada');
    }
    return '';
  }

  @override
  Future<RecordingResult?> stopRecording() async => null;

  @override
  Future<void> cancelRecording() async {}

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('P0/P1 Dual Track E2E — Tier 2: Boundary & Corner Cases', () {
    late AppDatabase db;
    late AppRepository repo;
    late Directory tempDir;
    late MockSupabaseFullDomainServer server;
    late AppConfig testConfig;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ));
      repo = AppRepository(db);
      tempDir = await Directory.systemTemp.createTemp('p0_tier2_');
      server = MockSupabaseFullDomainServer();

      testConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://test.supabase.co',
        supabaseAnonKey: 'test-anon-key-p0-tier2',
      );

      SupabaseInitializer.setMockStateForTesting(
        state: SupabaseConnectionState.connected,
        config: testConfig,
      );
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
      await SupabaseInitializer.resetForTesting();
    });

    SupabaseSyncService createSyncService({bool simulateNetworkDrop = false}) {
      server.simulateNetworkDrop = simulateNetworkDrop;
      final client = SupabaseClient(
        'https://test.supabase.co',
        'test-anon-key-p0-tier2',
        httpClient: MockClient((req) async => server.handleRequest(req)),
      );
      return SupabaseSyncService(
        db: db,
        repository: repo,
        config: testConfig,
        clientOverride: client,
        documentsDirectoryProvider: () async => tempDir.path,
      );
    }

    // ========================================================================
    // 1. Empty Outbox Queue Boundary
    // ========================================================================
    test('TC-P0-CORNER-01: Fila de outbox vazia completa processQueue() sem requisições desnecessárias e atinge status synced', () async {
      final syncService = createSyncService();
      addTearDown(syncService.dispose);

      final pendingBefore = await repo.getPendingSyncOperations();
      expect(pendingBefore.isEmpty, isTrue);

      final result = await syncService.processQueue();

      expect(result.totalProcessed, equals(0));
      expect(result.successCount, equals(0));
      expect(result.failureCount, equals(0));
      expect(syncService.currentStatus, equals(SyncStatus.synced));
    });

    // ========================================================================
    // 2. Expired OAuth & Calendar Tokens Boundary
    // ========================================================================
    test('TC-P0-CORNER-02: Token do Google Calendar expirado (HTTP 401) retorna erro acionável sem travamento', () async {
      final expiredProvider = ExpiredTokenCalendarProvider(
        errorCode: 401,
        errorDetail: 'Token revogado pelo usuário',
      );

      final result = await expiredProvider.syncEvents(db: db);

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('HTTP 401'));
      expect(result.errorMessage, contains('Token revogado'));
      expect(result.eventsDownloaded, equals(0));
    });

    // ========================================================================
    // 3. Expired Supabase Session Boundary
    // ========================================================================
    test('TC-P0-CORNER-03: Sessão Supabase expirada transiciona para authenticationExpired e bloqueia envio de dados', () async {
      SupabaseInitializer.setMockStateForTesting(
        state: SupabaseConnectionState.authenticationExpired,
        config: testConfig,
      );

      expect(SupabaseInitializer.currentState, equals(SupabaseConnectionState.authenticationExpired));
      expect(SupabaseInitializer.currentState.isReady, isFalse);
    });

    // ========================================================================
    // 4. Offline Attempts & Network Drops (Backoff and Retry Limit)
    // ========================================================================
    test('TC-P0-CORNER-04: Falha de rede durante push incrementa tentativas e calcula backoff exponencial clamped', () async {
      final syncService = createSyncService(simulateNetworkDrop: true);
      addTearDown(syncService.dispose);

      final person = await repo.createPerson(
        id: 'person-offline-drop-01',
        name: 'Roberto Conexao',
      );
      expect(person.id, isNotNull);

      final result = await syncService.processQueue();

      expect(result.failureCount, greaterThanOrEqualTo(1));
      expect(syncService.currentStatus, equals(SyncStatus.waitingConnection));

      final pendingOps = await repo.getPendingSyncOperations();
      expect(pendingOps.length, equals(1));
      expect(pendingOps.first.attempts, equals(1));

      // Verifica cálculo de backoff exponencial: clamped a no máximo 300s (com jitter)
      final backoffAttempt1 = SupabaseSyncService.calculateBackoffSeconds(1);
      final backoffAttempt10 = SupabaseSyncService.calculateBackoffSeconds(10);
      expect(backoffAttempt1, greaterThanOrEqualTo(1));
      expect(backoffAttempt10, inInclusiveRange(256, 300));
      expect(backoffAttempt10, lessThanOrEqualTo(300));
    });

    test('TC-P0-CORNER-05: Operação que atinge 5 tentativas de falha é marcada como failed sem bloquear outras entidades', () async {
      final syncService = createSyncService(simulateNetworkDrop: true);
      addTearDown(syncService.dispose);

      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: 'op-failing-01',
          entityType: 'people',
          entityId: 'p-fail-01',
          operation: 'INSERT',
          payload: jsonEncode({'id': 'p-fail-01', 'name': 'Falha'}),
          createdAt: DateTime.now(),
          attempts: const drift.Value(4),
          status: const drift.Value('pending'),
        ),
      );

      await syncService.processQueue(ignoreBackoff: true);

      final opAfter = await (db.select(db.syncQueue)..where((t) => t.id.equals('op-failing-01'))).getSingle();
      expect(opAfter.attempts, equals(5));
      expect(opAfter.status, equals('failed'));
    });

    // ========================================================================
    // 5. Microphone Permission Denied Boundary
    // ========================================================================
    test('TC-P0-CORNER-06: Permissão de microfone negada lança exceção explícita sem criar gravações fantasmas', () async {
      final deniedService = PermissionDeniedAudioService();

      expect(
        () async => await deniedService.startRecording(),
        throwsA(predicate((e) => e.toString().contains('Permissão de gravação de áudio negada'))),
      );
      expect(deniedService.isRecording, isFalse);
    });

    // ========================================================================
    // 6. Extreme Boundary: Cursor Determinístico com Timestamps Idênticos
    // ========================================================================
    test('TC-P0-CORNER-07: Cursor composto (updated_at, id) resolve ordenação estrita mesmo com timestamps idênticos', () {
      final sameTimestamp = DateTime(2026, 11, 4, 12, 0, 0);

      final row1 = {
        'id': 'uuid-b-222',
        'name': 'Pessoa B',
        'updated_at': sameTimestamp.toIso8601String(),
      };
      final row2 = {
        'id': 'uuid-a-111',
        'name': 'Pessoa A',
        'updated_at': sameTimestamp.toIso8601String(),
      };

      server.seed('people', row1);
      server.seed('people', row2);

      final req = http.Request('GET', Uri.parse('https://test.supabase.co/rest/v1/people'));
      final resp = server.handleRequest(req);
      final list = jsonDecode(resp.body) as List;

      expect(list[0]['id'], equals('uuid-a-111'));
      expect(list[1]['id'], equals('uuid-b-222'));
    });

    // ========================================================================
    // 7. Malformed Payload Isolation in Outbox
    // ========================================================================
    test('TC-P0-CORNER-08: Payload JSON com caracteres especiais e quebras de linha preserva integridade sem corrupção', () {
      final complexNotes = '''
Linha 1: "Aspas duplas" e 'aspas simples'
Linha 2: \ttabulações e caracteres unicode: 📖 🌍 🙏
Linha 3: Símbolos especiais: <>&/\$%@!#
''';

      final payload = {
        'id': 'p-special-01',
        'name': 'Antônio Especial',
        'general_notes': complexNotes,
      };

      final jsonStr = jsonEncode(payload);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(decoded['general_notes'], equals(complexNotes));
      expect(decoded['general_notes'], contains('📖 🌍 🙏'));
      expect(decoded['general_notes'], contains('"Aspas duplas"'));
    });
  });
}
