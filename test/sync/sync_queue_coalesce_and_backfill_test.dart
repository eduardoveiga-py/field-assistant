import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/core/biometric_auth_service.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/inbox/email_sync_coordinator.dart';
import 'package:ministerio_pessoal/inbox/jw_email_service.dart';
import 'package:ministerio_pessoal/knowledge/knowledge_manager.dart';
import 'package:ministerio_pessoal/sync/crypto/e2ee_service.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_record_sync.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_key_store.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_vault_transport.dart';
import 'package:ministerio_pessoal/sync/realtime_sync_notifier.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:ministerio_pessoal/sync/sync_owner_guard.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/widgets/settings/sync_queue_management_sheet.dart';
import 'package:ministerio_pessoal/ui/widgets/settings/sync_status_summary.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _InMemoryCloud {
  final Map<String, Map<String, dynamic>> vaults = {};
  final Map<String, EncryptedRemoteRecord> records = {};
  int _seq = 0;

  int nextSeq() => ++_seq;
}

class _SpyVaultTransport implements RecoveryVaultTransport {
  final _InMemoryCloud cloud;
  final String owner;

  _SpyVaultTransport(this.cloud, this.owner);

  @override
  Future<Map<String, dynamic>?> fetch() async => cloud.vaults[owner];

  @override
  Future<bool> createIfAbsent(Map<String, dynamic> proposed) async {
    if (cloud.vaults.containsKey(owner)) return false;
    cloud.vaults[owner] = Map<String, dynamic>.from(proposed);
    return true;
  }
}

class _SpyRecordTransport implements PaginatedEncryptedRecordTransport {
  final _InMemoryCloud cloud;

  _SpyRecordTransport(this.cloud);

  @override
  Future<EncryptedRemoteRecord?> fetch(String route) async =>
      cloud.records[route];

  @override
  Future<EncryptedWriteResult> compareAndSwap({
    required String route,
    required int expectedRevision,
    required Map<String, dynamic> envelope,
  }) async {
    final existing = cloud.records[route];
    if ((existing?.revision ?? 0) != expectedRevision) {
      return EncryptedWriteResult(success: false, revision: existing?.revision);
    }
    final rev = expectedRevision + 1;
    final seq = cloud.nextSeq();
    cloud.records[route] = EncryptedRemoteRecord(
      route: route,
      revision: rev,
      serverSeq: seq,
      envelope: Map<String, dynamic>.from(envelope),
    );
    return EncryptedWriteResult(success: true, revision: rev, serverSeq: seq);
  }

  @override
  Future<List<EncryptedRemoteRecord>> pullSince({
    required int sinceSeq,
    int limit = 100,
  }) async {
    final rows =
        cloud.records.values.where((r) => r.serverSeq > sinceSeq).toList()
          ..sort((a, b) => a.serverSeq.compareTo(b.serverSeq));
    return rows.take(limit).toList();
  }
}

SupabaseClient _mockClient() => SupabaseClient(
  'https://mock.supabase.co',
  'mock-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
  httpClient: MockClient(
    (req) async => http.Response(
      jsonEncode([]),
      200,
      headers: {'content-type': 'application/json'},
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Sync Queue Coalesce, E2EE Backfill, Email Hygiene & Realtime', () {
    const ownerId = '33333333-3333-4333-8333-333333333333';

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      RecoveryKeyStore.resetForTesting();
    });

    test('Cadeia legada de UPDATEs em inbox_entries sem _base é consolidada automaticamente e sincronizada via E2EE', () async {
      final cloud = _InMemoryCloud();
      final db1 = AppDatabase.forTesting(NativeDatabase.memory());
      final db2 = AppDatabase.forTesting(NativeDatabase.memory());
      final client = _mockClient();
      addTearDown(() async {
        await db1.close();
        await db2.close();
        client.dispose();
      });

      final e2ee1 = E2eeService(
        db: db1,
        keyStore: RecoveryKeyStore(),
        vaultTransportOverride: _SpyVaultTransport(cloud, ownerId),
        recordTransportOverride: _SpyRecordTransport(cloud),
      );
      final phrase = await e2ee1.setupNewVault(ownerId);

      final now = DateTime.now().toUtc();
      const entryId = 'email_AQMk_stuck_001';
      await db1
          .into(db1.inboxEntries)
          .insert(
            InboxEntriesCompanion.insert(
              id: entryId,
              content: 'Carta importante • Conteúdo final',
              sourceType: const drift.Value('email'),
              capturedAt: now,
              metadata: drift.Value(
                jsonEncode({
                  'email': {
                    'id': 'AQMk_stuck_001',
                    'subject': 'Carta importante',
                    'from': 'remetente@jw.org',
                    'to': 'eu@jw.org',
                    'date': now.toIso8601String(),
                    'bodyText': 'Conteúdo final',
                    'isRead': true,
                  },
                }),
              ),
              createdAt: now,
              updatedAt: now,
              revision: const drift.Value(3),
            ),
          );
      final currentRow = await (db1.select(
        db1.inboxEntries,
      )..where((t) => t.id.equals(entryId))).getSingle();

      // Simula duas mutações antigas enfileiradas sem _base e com timestamps epoch brutos
      await db1
          .into(db1.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: 'legacy_q_1',
              entityType: 'inbox_entries',
              entityId: entryId,
              operation: 'UPDATE',
              payload: jsonEncode(currentRow.toJson()),
              createdAt: now.subtract(const Duration(seconds: 10)),
            ),
          );
      await db1
          .into(db1.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: 'legacy_q_2',
              entityType: 'inbox_entries',
              entityId: entryId,
              operation: 'UPDATE',
              payload: jsonEncode(currentRow.toJson()),
              createdAt: now.subtract(const Duration(seconds: 5)),
            ),
          );

      final sync1 = SupabaseSyncService(
        db: db1,
        repository: AppRepository(db1),
        clientOverride: client,
        e2eeServiceOverride: e2ee1,
        allowEncryptedSyncForTesting: true,
        authenticatedOwnerOverrideForTesting: ownerId,
      );
      addTearDown(sync1.dispose);

      final res = await sync1.sync();
      expect(res.failureCount, 0, reason: res.errors.join('; '));
      expect(res.successCount, 1);
      expect(await AppRepository(db1).getUnresolvedSyncOperations(), isEmpty);

      // Segundo dispositivo restaura cofre e puxa o registro destravado
      FlutterSecureStorage.setMockInitialValues({});
      final e2ee2 = E2eeService(
        db: db2,
        keyStore: RecoveryKeyStore(),
        vaultTransportOverride: _SpyVaultTransport(cloud, ownerId),
        recordTransportOverride: _SpyRecordTransport(cloud),
      );
      await e2ee2.restoreVault(ownerId, phrase);

      final sync2 = SupabaseSyncService(
        db: db2,
        repository: AppRepository(db2),
        clientOverride: client,
        e2eeServiceOverride: e2ee2,
        allowEncryptedSyncForTesting: true,
        authenticatedOwnerOverrideForTesting: ownerId,
      );
      addTearDown(sync2.dispose);

      final pullRes = await sync2.sync();
      expect(pullRes.failureCount, 0, reason: pullRes.errors.join('; '));
      expect(pullRes.successCount, 1);

      final syncedRow = await (db2.select(
        db2.inboxEntries,
      )..where((t) => t.id.equals(entryId))).getSingle();
      expect(syncedRow.content, contains('Conteúdo final'));
    });

    test('EmailSyncCoordinator evita churn de folderId/ordem de labels e anexa _base em UPDATEs reais', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final coordinator = EmailSyncCoordinator(db);
      final now = DateTime.now().toUtc();

      final initial = JwEmailMessage(
        id: 'AQMk_graph_01',
        subject: 'Convocação',
        from: 'a@jw.org',
        to: 'b@jw.org',
        date: now,
        bodyText: 'Corpo',
        folderName: 'Caixa de Entrada',
        isRead: false,
        labels: ['INBOX', 'IMPORTANT'],
      );

      expect(
        await coordinator.persistSyncedMessages([initial], 'microsoft_graph'),
        1,
      );
      await (db.delete(db.syncQueue)).go();

      // Mesmo e-mail volta com labels reordenadas e folderId recém-descoberto -> 0 UPDATEs na fila!
      final reordered = initial.copyWith(
        folderId: 'AQMkFolderGuid123',
        labels: ['IMPORTANT', 'INBOX'],
      );
      await coordinator.persistSyncedMessages([reordered], 'microsoft_graph');
      expect(await db.select(db.syncQueue).get(), isEmpty);

      // Mudança real de isRead gera exatamente 1 UPDATE normalizado COM _base
      final markedRead = reordered.copyWith(isRead: true);
      await coordinator.persistSyncedMessages([markedRead], 'microsoft_graph');
      final q = await db.select(db.syncQueue).get();
      expect(q.length, 1);
      expect(q.single.operation, 'UPDATE');
      final decoded = jsonDecode(q.single.payload) as Map<String, dynamic>;
      expect(decoded['_base'], isA<Map<String, dynamic>>());
    });

    test('JwEmailService (setEmailsReadStatus, moveEmailsToFolder, deleteEmails) sempre registra _base para permitir compactação', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final service = JwEmailService(
        db: db,
        biometricAuth: BiometricAuthService(),
      );
      final coordinator = EmailSyncCoordinator(db);
      final now = DateTime.now().toUtc();

      await coordinator.persistSyncedMessages([
        JwEmailMessage(
          id: 'msg_chain_1',
          subject: 'Cadeia E-mail',
          from: 'a@jw.org',
          to: 'b@jw.org',
          date: now,
          bodyText: 'Texto',
          folderName: 'Caixa de Entrada',
          isRead: false,
        ),
      ], 'imap');
      await (db.delete(db.syncQueue)).go();

      await service.setEmailsReadStatus(['email_msg_chain_1'], isRead: true);
      await service.moveEmailsToFolder([
        'email_msg_chain_1',
      ], targetFolderName: 'Arquivo');
      await service.deleteEmails(['email_msg_chain_1']);

      final ops = await db.select(db.syncQueue).get();
      expect(ops.length, 3);
      for (final op in ops) {
        final map = jsonDecode(op.payload) as Map<String, dynamic>;
        expect(map['_base'], isA<Map<String, dynamic>>());
        expect(map['revision'], isNotNull);
      }
    });

    test('E2eeLocalBackfill envia registros pré-existentes sem fila para novo dispositivo e respeita isolamento/tombstone', () async {
      final cloud = _InMemoryCloud();
      final db1 = AppDatabase.forTesting(NativeDatabase.memory());
      final repo1 = AppRepository(db1);
      final kb1 = KnowledgeManager(db: db1);
      final db2 = AppDatabase.forTesting(NativeDatabase.memory());
      final repo2 = AppRepository(db2);
      final client = _mockClient();

      addTearDown(() async {
        await db1.close();
        await db2.close();
        client.dispose();
      });

      // 1. Dispositivo 1 cria dados offline ANTES de habilitar nuvem/E2EE
      final person = await repo1.createPerson(name: 'Estudante Antigo');
      final area = await kb1.createArea(name: 'Ministério Geral');
      final note = await kb1.createNote(
        title: 'Nota Histórica Pré-E2EE',
        content: 'Esboço salvo antes do cofre E2EE.',
        areaId: area.id,
      );
      // Simula base pré-existente sem entradas pendentes na sync_queue
      await (db1.delete(db1.syncQueue)).go();

      // 2. Usuário configura E2EE no Dispositivo 1 e sincroniza
      final e2ee1 = E2eeService(
        db: db1,
        keyStore: RecoveryKeyStore(),
        vaultTransportOverride: _SpyVaultTransport(cloud, ownerId),
        recordTransportOverride: _SpyRecordTransport(cloud),
      );
      final phrase = await e2ee1.setupNewVault(ownerId);

      final sync1 = SupabaseSyncService(
        db: db1,
        repository: repo1,
        clientOverride: client,
        e2eeServiceOverride: e2ee1,
        allowEncryptedSyncForTesting: true,
        authenticatedOwnerOverrideForTesting: ownerId,
      );
      addTearDown(sync1.dispose);

      final firstSync = await sync1.sync();
      expect(firstSync.failureCount, 0, reason: firstSync.errors.join('; '));
      expect(firstSync.successCount, greaterThanOrEqualTo(3));

      // Segundo sync imediato não re-enfileira itens já checkpointados
      final backfilledSecond = await sync1.enqueueMissingLocalRecordsForSync();
      expect(backfilledSecond, 0);

      // 3. Dispositivo 2 restaura frase e sincroniza -> recebe tudo ("o restante")
      FlutterSecureStorage.setMockInitialValues({});
      final e2ee2 = E2eeService(
        db: db2,
        keyStore: RecoveryKeyStore(),
        vaultTransportOverride: _SpyVaultTransport(cloud, ownerId),
        recordTransportOverride: _SpyRecordTransport(cloud),
      );
      await e2ee2.restoreVault(ownerId, phrase);

      final sync2 = SupabaseSyncService(
        db: db2,
        repository: repo2,
        clientOverride: client,
        e2eeServiceOverride: e2ee2,
        allowEncryptedSyncForTesting: true,
        authenticatedOwnerOverrideForTesting: ownerId,
      );
      addTearDown(sync2.dispose);

      final dev2Pull = await sync2.sync();
      expect(dev2Pull.failureCount, 0, reason: dev2Pull.errors.join('; '));
      expect((await repo2.getPersonById(person.id))?.name, 'Estudante Antigo');
      final dev2Note = await KnowledgeManager(db: db2).getNoteById(note.id);
      expect(dev2Note?.title, 'Nota Histórica Pré-E2EE');

      // Troca de conta limpa a flag de backfill (prefixo e2ee_)
      await SyncOwnerGuard.resetLocalWorkspaceForAccountSwitch(
        db: db1,
        newOwnerId: '44444444-4444-4444-8444-444444444444',
      );
      final flagRows = await (db1.select(
        db1.appKvStore,
      )..where((t) => t.key.like('e2ee_initial_backfill_%'))).get();
      expect(flagRows, isEmpty);
    });

    test('RealtimeSyncNotifier filtra ecos da própria instância e gera tópico opaco sem PII', () {
      final notifier = RealtimeSyncNotifier(instanceId: 'dev-a');
      final topic = RealtimeSyncNotifier.channelTopicForOwner(ownerId);
      expect(topic, startsWith('sync_notify_'));
      expect(topic, isNot(contains(ownerId)));

      expect(notifier.shouldTriggerFromBroadcast({'sender': 'dev-a'}), isFalse);
      expect(
        notifier.shouldTriggerFromBroadcast({
          'payload': {'sender': 'dev-a'},
        }),
        isFalse,
      );
      expect(notifier.shouldTriggerFromBroadcast({'sender': 'dev-b'}), isTrue);
      expect(
        notifier.shouldTriggerFromBroadcast({
          'payload': {'sender': 'dev-b'},
        }),
        isTrue,
      );
    });

    testWidgets(
      'SyncQueueManagementSheet exibe rótulos claros e Desbloquear & Reenviar drena a fila',
      (tester) async {
        tester.view.physicalSize = const Size(900, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final repo = AppRepository(db);

        final cloud = _InMemoryCloud();
        final client = _mockClient();
        final e2ee = E2eeService(
          db: db,
          keyStore: RecoveryKeyStore(),
          vaultTransportOverride: _SpyVaultTransport(cloud, ownerId),
          recordTransportOverride: _SpyRecordTransport(cloud),
        );
        final syncSvc = SupabaseSyncService(
          db: db,
          repository: repo,
          clientOverride: client,
          e2eeServiceOverride: e2ee,
          allowEncryptedSyncForTesting: true,
          authenticatedOwnerOverrideForTesting: ownerId,
        );

        await tester.runAsync(() async {
          await e2ee.setupNewVault(ownerId);
          final now = DateTime.now().toUtc();
          const entryId = 'email_ui_unlock_1';
          await db
              .into(db.inboxEntries)
              .insert(
                InboxEntriesCompanion.insert(
                  id: entryId,
                  content: 'E-mail preso em UI',
                  sourceType: const drift.Value('email'),
                  capturedAt: now,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          final row = await (db.select(
            db.inboxEntries,
          )..where((t) => t.id.equals(entryId))).getSingle();
          await db
              .into(db.syncQueue)
              .insert(
                SyncQueueCompanion.insert(
                  id: 'ui_op_1',
                  entityType: 'inbox_entries',
                  entityId: entryId,
                  operation: 'UPDATE',
                  payload: jsonEncode(row.toJson()),
                  createdAt: now,
                  attempts: const drift.Value(2),
                  lastAttemptAt: drift.Value(now),
                ),
              );
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
              supabaseSyncServiceProvider.overrideWithValue(syncSvc),
              e2eeServiceProvider.overrideWithValue(e2ee),
            ],
            child: const MaterialApp(
              home: Scaffold(body: SyncQueueManagementSheet()),
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Inbox / E-mail (inbox_entries) • UPDATE'),
          findsOneWidget,
        );
        expect(find.text('Todos (1)'), findsOneWidget);

        await tester.tap(find.text('Desbloquear & Reenviar'));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Todos (0)'), findsOneWidget);
        final remainingAfterTap = await tester.runAsync(
          () => repo.getUnresolvedSyncOperations(),
        );
        expect(remainingAfterTap, isEmpty);

        // Testa também widget SyncStatusSummaryHeader no estado Local-First
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
              supabaseSyncServiceProvider.overrideWithValue(syncSvc),
              e2eeServiceProvider.overrideWithValue(e2ee),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SyncStatusSummaryHeader(
                  syncCounts: (pending: 0, failed: 0, conflict: 0),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pumpAndSettle();
        expect(find.text('Estado da Sincronização'), findsOneWidget);
        expect(find.text('Local-First'), findsOneWidget);

        // Testa também os estados ativos E2EE (Pendente • Auto e Sincronizado • E2EE)
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
              supabaseSyncServiceProvider.overrideWithValue(syncSvc),
              e2eeServiceProvider.overrideWithValue(e2ee),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    SyncStatusSummaryHeader(
                      syncCounts: (pending: 2, failed: 0, conflict: 0),
                      authenticatedUserIdOverride: ownerId,
                      remoteSyncEnabledOverride: true,
                    ),
                    SyncStatusSummaryHeader(
                      syncCounts: (pending: 0, failed: 0, conflict: 0),
                      authenticatedUserIdOverride: ownerId,
                      remoteSyncEnabledOverride: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pumpAndSettle();
        expect(find.text('Pendente • Auto'), findsOneWidget);
        expect(find.text('Sincronizado • E2EE'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          syncSvc.dispose();
          await db.close();
          client.dispose();
        });
      },
    );
  });
}
