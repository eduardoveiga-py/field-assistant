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
      expect(syncService.currentStatus, equals(SyncStatus.savedLocally));

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
      expect(syncService.currentStatus, equals(SyncStatus.savedLocally));
    });

    test('8. Reentrância e Trava isSyncing: chamadas simultâneas a processQueue aguardam a execução ativa sem duplicar requisições', () async {
      final validConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://reentrancy-test.supabase.co',
        supabaseAnonKey: 'valid-anon-key-1234567890',
      );

      int remoteUpsertCalls = 0;
      final mockHttpClient = MockClient((request) async {
        remoteUpsertCalls++;
        await Future.delayed(const Duration(milliseconds: 50));
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

      await repo.createPerson(name: 'Contato Reentrante');

      // Dispara 5 chamadas simultâneas a processQueue
      final futures = List.generate(
        5,
        (_) => syncService.processQueue(ignoreBackoff: true),
      );

      expect(syncService.isSyncing, isTrue);

      final results = await Future.wait(futures);

      expect(syncService.isSyncing, isFalse);
      // Exatamente 1 envio remoto para o item, nunca 5 requisições duplicadas
      expect(remoteUpsertCalls, equals(1));
      for (final res in results) {
        expect(res.successCount, equals(1));
      }
    });

    test('9. Resiliência de Falha de Rede: preserva waitingConnection e aborta lote sem queimar tentativas dos próximos', () async {
      final validConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://network-abort-test.supabase.co',
        supabaseAnonKey: 'valid-anon-key-1234567890',
      );

      int httpCalls = 0;
      final mockHttpClient = MockClient((req) async {
        httpCalls++;
        throw const SocketException('Host unresolvable');
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

      // Cria 3 contatos na outbox
      await repo.createPerson(name: 'Contato 1');
      await repo.createPerson(name: 'Contato 2');
      await repo.createPerson(name: 'Contato 3');

      final pendingBefore = await repo.getPendingSyncOperations();
      expect(pendingBefore.length, equals(3));

      // Executa processQueue com rede indisponível
      final result = await syncService.processQueue(ignoreBackoff: true);

      // Status DEVE ser waitingConnection (não pode ser sobrescrito por error)
      expect(syncService.currentStatus, equals(SyncStatus.waitingConnection));
      // Interrompeu após a 1ª falha para não gastar chamadas nem queimar tentativas das outras 2 operações
      expect(httpCalls, equals(1));
      expect(result.failureCount, equals(1));

      final allQueue = await (db.select(db.syncQueue)).get();
      final failedOp = allQueue.firstWhere((q) => q.status == 'failed');
      final pendingOps = allQueue.where((q) => q.status == 'pending').toList();

      expect(failedOp.attempts, equals(1));
      expect(pendingOps.length, equals(2));
      for (final p in pendingOps) {
        expect(p.attempts, equals(0)); // Não foram queimadas tentativas!
      }
    });

    test('10. Integridade de Dados Locais: _applyRemoteRecord detecta outbox item com status failed e faz 3-way merge', () async {
      final validConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://merge-test.supabase.co',
        supabaseAnonKey: 'valid-anon-key-1234567890',
      );

      final person = await repo.createPerson(
        name: 'Carlos Local',
        phone: '11999990000',
        generalNotes: 'Nota local original',
      );

      // Simula que a operação na outbox falhou temporariamente por falta de rede
      final op = (await repo.getPendingSyncOperations()).first;
      await (db.update(db.syncQueue)..where((t) => t.id.equals(op.id))).write(
        const SyncQueueCompanion(
          status: Value('failed'),
          attempts: Value(1),
          lastError: Value('SocketException transitória'),
        ),
      );

      // Chega alteração remota com telefone atualizado remotamente
      final remotePerson = {
        'id': person.id,
        'name': 'Carlos Local',
        'phone': '11999991111', // Atualizado remotamente
        'general_notes': 'Nota local original',
        'status': 'interessado',
        'first_contact_at': person.firstContactAt.toIso8601String(),
        'updated_at': DateTime.now()
            .add(const Duration(minutes: 5))
            .toIso8601String(),
        'revision': 2,
      };

      final mockHttpClient = MockClient((req) async {
        if (req.url.path.contains('people')) {
          return mockJsonResponse(req, [remotePerson]);
        }
        return mockJsonResponse(req, []);
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

      // Executa fetchRemoteChanges
      final pullResult = await syncService.fetchRemoteChanges();
      expect(pullResult.successCount, equals(1));

      // 3-way merge foi realizado: telefone remoto foi integrado sem destruir as notas locais
      final updatedPerson = await (db.select(
        db.people,
      )..where((t) => t.id.equals(person.id))).getSingle();
      expect(updatedPerson.phone, equals('11999991111'));
      expect(updatedPerson.generalNotes, equals('Nota local original'));

      // E a outbox foi atualizada com os dados mesclados
      final updatedOp = (await repo.getPendingSyncOperations()).first;
      final payload = jsonDecode(updatedOp.payload) as Map<String, dynamic>;
      expect(payload['phone'], equals('11999991111'));
    });

    test('11. Auto-Reconexão via stateStream: transição para connected dispara handleReconnection automaticamente', () async {
      final validConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://stream-reconnect.supabase.co',
        supabaseAnonKey: 'valid-anon-key-1234567890',
      );

      int upsertCount = 0;
      final mockHttpClient = MockClient((req) async {
        if (req.method == 'POST') {
          upsertCount++;
        }
        return mockJsonResponse(req, []);
      });

      final mockClient = SupabaseClient(
        validConfig.supabaseUrl,
        validConfig.supabaseAnonKey,
        httpClient: mockHttpClient,
      );

      SupabaseInitializer.setMockStateForTesting(
        state: SupabaseConnectionState.disconnected,
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

      await repo.createPerson(name: 'Auto Reconnect Person');
      expect((await repo.getPendingSyncOperations()).length, equals(1));

      // Simula restauração de conexão detectada pelo SupabaseInitializer
      SupabaseInitializer.setMockStateForTesting(
        state: SupabaseConnectionState.connected,
        client: mockClient,
        config: validConfig,
        httpClient: mockHttpClient,
      );

      // Aguarda processamento assíncrono do listener do stream
      await Future.delayed(const Duration(milliseconds: 100));

      expect(upsertCount, greaterThanOrEqualTo(1));
      final pendingAfter = await repo.getPendingSyncOperations();
      expect(pendingAfter.isEmpty, isTrue);
    });

    test('12. Instabilidade HTTP 503 PostgREST: aborta lote sem queimar tentativas subsequentes e notifica desconexão', () async {
      final validConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://postgrest-503-test.supabase.co',
        supabaseAnonKey: 'valid-anon-key-1234567890',
      );

      SupabaseInitializer.setMockStateForTesting(
        state: SupabaseConnectionState.connected,
        config: validConfig,
      );

      int httpCalls = 0;
      final mockHttpClient = MockClient((req) async {
        httpCalls++;
        return http.Response(
          jsonEncode({
            'code': '503',
            'message':
                '503 Service Unavailable: upstream server temporary outage',
            'details': 'Cloudflare gateway timeout or upstream down',
            'hint': null,
          }),
          503,
          request: req,
          headers: {'content-type': 'application/json'},
        );
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

      await repo.createPerson(name: 'Item 1');
      await repo.createPerson(name: 'Item 2');
      await repo.createPerson(name: 'Item 3');

      final pendingBefore = await repo.getPendingSyncOperations();
      expect(pendingBefore.length, equals(3));

      final result = await syncService.processQueue(ignoreBackoff: true);

      expect(httpCalls, equals(1));
      expect(result.failureCount, equals(1));
      expect(syncService.currentStatus, equals(SyncStatus.waitingConnection));
      expect(
        SupabaseInitializer.currentState,
        equals(SupabaseConnectionState.disconnected),
      );

      final allQueue = await (db.select(db.syncQueue)).get();
      final failedOp = allQueue.firstWhere((q) => q.status == 'failed');
      final pendingOps = allQueue.where((q) => q.status == 'pending').toList();

      expect(failedOp.attempts, equals(1));
      expect(pendingOps.length, equals(2));
      for (final op in pendingOps) {
        expect(op.attempts, equals(0));
      }
    });

    test('13. Blindagem de dados locais em _applyRemoteRecord com outbox attempts >= 5 (failed)', () async {
      final validConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://merge-failed-test.supabase.co',
        supabaseAnonKey: 'valid-anon-key-1234567890',
      );

      final person = await repo.createPerson(
        name: 'Carlos Excedido',
        phone: '11988880000',
        generalNotes:
            'Anotação confidencial do usuário que NÃO pode ser perdida',
      );

      final op = (await repo.getPendingSyncOperations()).first;
      await (db.update(db.syncQueue)..where((t) => t.id.equals(op.id))).write(
        const SyncQueueCompanion(
          status: Value('failed'),
          attempts: Value(5),
          lastError: Value('Max attempts exceeded'),
        ),
      );

      final remotePerson = {
        'id': person.id,
        'name': 'Carlos Excedido',
        'phone': '11988889999',
        'general_notes':
            'Anotação confidencial do usuário que NÃO pode ser perdida',
        'status': 'interessado',
        'first_contact_at': person.firstContactAt.toIso8601String(),
        'updated_at': DateTime.now()
            .add(const Duration(minutes: 10))
            .toIso8601String(),
        'revision': 2,
      };

      final mockHttpClient = MockClient((req) async {
        if (req.url.path.contains('people')) {
          return mockJsonResponse(req, [remotePerson]);
        }
        return mockJsonResponse(req, []);
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

      final pullResult = await syncService.fetchRemoteChanges();
      expect(pullResult.successCount, equals(1));

      final localPersonAfter = await repo.getPersonById(person.id);
      expect(localPersonAfter, isNotNull);
      expect(
        localPersonAfter!.generalNotes,
        equals('Anotação confidencial do usuário que NÃO pode ser perdida'),
      );
      expect(localPersonAfter.phone, equals('11988889999'));
    });

    test('14. Status com Fila Vazia em Modo Desconfigurado ou Offline NÃO deve ser synced', () async {
      final unconfiguredService = SupabaseSyncService(
        db: db,
        repository: repo,
        config: AppConfig.create(
          environment: AppEnvironment.development,
          supabaseUrl: '',
          supabaseAnonKey: '',
        ),
      );
      addTearDown(unconfiguredService.dispose);

      final resultUnconfigured = await unconfiguredService.processQueue();
      expect(
        unconfiguredService.currentStatus,
        equals(SyncStatus.savedLocally),
      );
      expect(resultUnconfigured.message, contains('não configurado'));

      final validConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://offline-empty-test.supabase.co',
        supabaseAnonKey: 'valid-anon-key-1234567890',
      );

      SupabaseInitializer.setMockStateForTesting(
        state: SupabaseConnectionState.disconnected,
        config: validConfig,
      );

      final offlineService = SupabaseSyncService(
        db: db,
        repository: repo,
        config: validConfig,
      );
      addTearDown(offlineService.dispose);

      final resultOffline = await offlineService.processQueue();
      expect(
        offlineService.currentStatus,
        equals(SyncStatus.waitingConnection),
      );
      expect(resultOffline.message, contains('offline'));
    });

    test('15. Falsos Indicadores de Sincronização em sync(): mensagem reflete suspensão remota quando offline ou não configurado', () async {
      final unconfiguredService = SupabaseSyncService(
        db: db,
        repository: repo,
        config: AppConfig.create(
          environment: AppEnvironment.development,
          supabaseUrl: '',
          supabaseAnonKey: '',
        ),
      );
      addTearDown(unconfiguredService.dispose);

      final syncResultUnconfigured = await unconfiguredService.sync();
      expect(
        syncResultUnconfigured.message,
        contains('Supabase não configurado'),
      );
      expect(
        syncResultUnconfigured.message,
        isNot(contains('Sincronização bidirecional: 0 enviados, 0 recebidos.')),
      );

      final validConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://sync-msg-test.supabase.co',
        supabaseAnonKey: 'valid-anon-key-1234567890',
      );

      SupabaseInitializer.setMockStateForTesting(
        state: SupabaseConnectionState.disconnected,
        config: validConfig,
      );

      final offlineService = SupabaseSyncService(
        db: db,
        repository: repo,
        config: validConfig,
      );
      addTearDown(offlineService.dispose);

      final syncResultOffline = await offlineService.sync();
      expect(
        syncResultOffline.message,
        contains('Dispositivo offline para sincronização remota'),
      );
      expect(
        syncResultOffline.message,
        isNot(contains('Sincronização bidirecional: 0 enviados, 0 recebidos.')),
      );
    });
  });
}
