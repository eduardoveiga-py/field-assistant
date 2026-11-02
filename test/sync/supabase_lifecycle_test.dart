import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/core/app_config.dart';
import 'package:ministerio_pessoal/core/supabase_initializer.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:ministerio_pessoal/sync/sync_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

http.Response mockJsonResponse(
  http.BaseRequest request,
  Object body, {
  int statusCode = 200,
  String contentRange = '*/0',
}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    request: request,
    headers: {
      'content-type': 'application/json',
      'content-range': contentRange,
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Unidade U2 — SupabaseSyncService & Ciclo de Vida Resiliente', () {
    late AppDatabase db;
    late AppRepository repo;
    late Directory tempDir;

    setUp(() async {
      await SupabaseInitializer.resetForTesting();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
      tempDir = await Directory.systemTemp.createTemp('lifecycle_test_');
    });

    tearDown(() async {
      await db.close();
      await SupabaseInitializer.resetForTesting();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('1. Modo Offline Total: boot sem internet, SQLite local 100% funcional, zero AssertionError', () async {
      // Configuração puramente offline (AppConfig unconfigured)
      final offlineConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: '',
        supabaseAnonKey: '',
      );

      final syncService = SupabaseSyncService(
        db: db,
        repository: repo,
        config: offlineConfig,
        documentsDirectoryProvider: () async => tempDir.path,
      );
      addTearDown(syncService.dispose);

      expect(syncService.isConfigured, isFalse);
      expect(syncService.client, isNull);

      // Inserções locais no banco de dados Drift
      final person = await repo.createPerson(
        name: 'Carlos Oliveira',
        phone: '11988887777',
        generalNotes: 'Interessado na profecia de Daniel',
      );
      expect(person.id, isNotEmpty);

      final visit = await repo.createVisit(
        personId: person.id,
        dateTime: DateTime.now(),
        contactType: 'presencial',
        result: 'conversa',
        notes: 'Conversa inicial muito receptiva',
      );
      expect(visit.id, isNotEmpty);

      // Outbox acumulou operações
      final pendingOps = await repo.getPendingSyncOperations();
      expect(
        pendingOps.length,
        equals(3),
      ); // 1 INSERT person + 1 INSERT visit + 1 UPDATE person

      // Executa processamento da fila sem rede/Supabase
      final result = await syncService.processQueue();

      expect(result.totalProcessed, equals(3));
      expect(result.successCount, equals(0));
      expect(result.message, contains('não configurado'));
      expect(syncService.currentStatus, equals(SyncStatus.waitingConnection));

      // As operações continuam intactas no banco Drift
      final opsAfter = await repo.getPendingSyncOperations();
      expect(opsAfter.length, equals(3));
    });

    test('2. Preservação da Outbox em falha transitória de rede (SocketException / 503)', () async {
      final validConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://transient-fail.supabase.co',
        supabaseAnonKey: 'transient-anon-key-12345678',
      );

      final mockHttpClient = MockClient((request) async {
        throw const SocketException('Conexão recusada pelo host remoto');
      });

      final mockClient = SupabaseClient(
        validConfig.supabaseUrl,
        validConfig.supabaseAnonKey,
        httpClient: mockHttpClient,
      );

      final syncService = SupabaseSyncService(
        db: db,
        repository: repo,
        config: validConfig,
        clientOverride: mockClient,
        documentsDirectoryProvider: () async => tempDir.path,
      );
      addTearDown(syncService.dispose);

      // Cria registro local
      await repo.createPerson(name: 'Ana Ribeiro');
      final opsBefore = await repo.getPendingSyncOperations();
      expect(opsBefore.length, equals(1));

      // 1ª tentativa falha por rede
      final failResult = await syncService.processQueue();
      expect(failResult.failureCount, equals(1));
      expect(failResult.errors.first, contains('Conexão recusada'));

      // Operação NÃO foi descartada da outbox
      final opsAfterFail = await repo.getPendingSyncOperations();
      expect(opsAfterFail.length, equals(1));
      expect(opsAfterFail.first.status, equals('failed'));
      expect(opsAfterFail.first.attempts, equals(1));
    });

    test('3. Limite de retentativas: operação que atinge 5 tentativas não é mais reprocessada automaticamente e permanece na outbox', () async {
      final validConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://limit-test.supabase.co',
        supabaseAnonKey: 'limit-anon-key-123456789012',
      );

      final mockHttpClient = MockClient((req) async {
        throw const SocketException('Offline permanente');
      });

      final syncService = SupabaseSyncService(
        db: db,
        repository: repo,
        config: validConfig,
        clientOverride: SupabaseClient(
          validConfig.supabaseUrl,
          validConfig.supabaseAnonKey,
          httpClient: mockHttpClient,
        ),
      );
      addTearDown(syncService.dispose);

      await repo.createPerson(name: 'Membro Teste');
      final op = (await repo.getPendingSyncOperations()).first;

      // Força 4 tentativas anteriores no banco
      await (db.update(db.syncQueue)..where((t) => t.id.equals(op.id))).write(
        const SyncQueueCompanion(attempts: Value(4), status: Value('failed')),
      );

      // 5ª tentativa falha
      final result = await syncService.processQueue(ignoreBackoff: true);
      expect(result.failureCount, equals(1));

      // Após atingir 5 tentativas, a operação não é mais incluída em getPendingSyncOperations (evita loop infinito)
      final pendingAfter5 = await repo.getPendingSyncOperations();
      expect(pendingAfter5.isEmpty, isTrue);

      // Mas continua preservada integralmente no banco para auditoria manual (durabilidade absoluta)
      final allQueue = await (db.select(db.syncQueue)).get();
      expect(allQueue.length, equals(1));
      expect(allQueue.first.attempts, equals(5));
      expect(allQueue.first.status, equals('failed'));
    });

    test('4. Cálculo de Backoff com Jitter: exponencial limitado a 300s com até 25% de jitter', () {
      // 0 tentativas
      expect(SupabaseSyncService.calculateBackoffSeconds(0), equals(0));

      // 1 tentativa: base 2s + até 25% (2 a 3s)
      final b1 = SupabaseSyncService.calculateBackoffSeconds(1);
      expect(b1, inInclusiveRange(2, 3));

      // 2 tentativas: base 4s + até 25% (4 a 5s)
      final b2 = SupabaseSyncService.calculateBackoffSeconds(2);
      expect(b2, inInclusiveRange(4, 5));

      // 5 tentativas: base 32s + até 25% (32 a 40s)
      final b5 = SupabaseSyncService.calculateBackoffSeconds(5);
      expect(b5, inInclusiveRange(32, 40));

      // 10 tentativas: base limitada a 300s + jitter limitado a 300s
      final b10 = SupabaseSyncService.calculateBackoffSeconds(10);
      expect(b10, inInclusiveRange(256, 300));

      // Verificação com gerador determinístico
      final fixedRandom = Random(42);
      final val = SupabaseSyncService.calculateBackoffSeconds(
        3,
        random: fixedRandom,
      );
      expect(val, greaterThanOrEqualTo(8));
      expect(val, lessThanOrEqualTo(10));
    });

    test('5. Recuperação de Conexão (handleReconnection): esvazia outbox com sucesso após restauração de rede', () async {
      final validConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://reconnect-test.supabase.co',
        supabaseAnonKey: 'reconnect-anon-key-1234567890',
      );

      bool networkOnline = false;
      final mockHttpClient = MockClient((request) async {
        if (!networkOnline) {
          throw const SocketException('Host unavailable');
        }
        return mockJsonResponse(request, []);
      });

      final mockClient = SupabaseClient(
        validConfig.supabaseUrl,
        validConfig.supabaseAnonKey,
        httpClient: mockHttpClient,
      );

      final syncService = SupabaseSyncService(
        db: db,
        repository: repo,
        config: validConfig,
        clientOverride: mockClient,
      );
      addTearDown(syncService.dispose);

      await repo.createPerson(name: 'Irmão Recuperado');

      // Tentativa offline falha
      await syncService.processQueue(ignoreBackoff: true);
      var pending = await repo.getPendingSyncOperations();
      expect(pending.length, equals(1));
      expect(pending.first.status, equals('failed'));

      // Conexão restabelecida
      networkOnline = true;
      await syncService.handleReconnection();

      // Fila sincronizada com sucesso
      final syncedOp = await (db.select(
        db.syncQueue,
      )..where((t) => t.id.equals(pending.first.id))).getSingle();
      expect(syncedOp.status, equals('synced'));
      expect(syncService.currentStatus, equals(SyncStatus.synced));
    });

    test('6. Background Resume (handleAppResume & WidgetsBindingObserver): reavalia conectividade e sincroniza', () async {
      final validConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://resume-test.supabase.co',
        supabaseAnonKey: 'resume-anon-key-1234567890123',
      );

      int requestCount = 0;
      final mockHttpClient = MockClient((request) async {
        requestCount++;
        return mockJsonResponse(request, []);
      });

      final mockClient = SupabaseClient(
        validConfig.supabaseUrl,
        validConfig.supabaseAnonKey,
        httpClient: mockHttpClient,
      );

      SupabaseInitializer.setMockStateForTesting(
        state: SupabaseConnectionState.connected,
        client: mockClient,
        config: validConfig,
        httpClient: mockHttpClient,
      );

      final syncService = SupabaseSyncService(
        db: db,
        repository: repo,
        config: validConfig,
        clientOverride: mockClient,
      );
      syncService.startLifecycleObservation();
      addTearDown(syncService.dispose);

      await repo.createPerson(name: 'Maria Santos');

      // Executa retorno do segundo plano
      await syncService.handleAppResume();

      expect(requestCount, greaterThanOrEqualTo(1));
      final pendingAfter = await repo.getPendingSyncOperations();
      expect(pendingAfter.isEmpty, isTrue);
    });

    test('7. Transações Locais Concorrentes: inserções simultâneas na outbox mantêm integridade SQLite', () async {
      final syncService = SupabaseSyncService(
        db: db,
        repository: repo,
        config: AppConfig.create(
          environment: AppEnvironment.development,
          supabaseUrl: '',
          supabaseAnonKey: '',
        ),
      );
      addTearDown(syncService.dispose);

      // 20 inserções locais simultâneas
      await Future.wait(
        List.generate(
          20,
          (i) => repo.createPerson(name: 'Contato Concorrente $i'),
        ),
      );

      final ops = await repo.getPendingSyncOperations();
      expect(ops.length, equals(20));

      // ProcessQueue sob concorrência não quebra o banco
      final result = await syncService.processQueue();
      expect(result.totalProcessed, equals(20));
      expect(syncService.currentStatus, equals(SyncStatus.waitingConnection));
    });
  });
}
