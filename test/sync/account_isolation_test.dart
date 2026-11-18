import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/sync/crypto/e2ee_service.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_record_sync.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_crypto.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_key_store.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_vault_transport.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:ministerio_pessoal/sync/sync_owner_guard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _InMemoryCloud {
  final Map<String, Map<String, dynamic>> vaultsByOwner = {};
  final Map<String, Map<String, EncryptedRemoteRecord>> recordsByOwner = {};
  int _seq = 0;

  RecoveryVaultTransport vaultFor(String owner) => _OwnerVault(this, owner);
  PaginatedEncryptedRecordTransport recordsFor(String owner) =>
      _OwnerRecords(this, owner);

  int nextSeq() => ++_seq;
}

class _OwnerVault implements RecoveryVaultTransport {
  final _InMemoryCloud cloud;
  final String owner;
  _OwnerVault(this.cloud, this.owner);

  @override
  Future<Map<String, dynamic>?> fetch() async => cloud.vaultsByOwner[owner];

  @override
  Future<bool> createIfAbsent(Map<String, dynamic> marker) async {
    if (cloud.vaultsByOwner.containsKey(owner)) return false;
    cloud.vaultsByOwner[owner] = Map<String, dynamic>.from(marker);
    return true;
  }
}

class _OwnerRecords implements PaginatedEncryptedRecordTransport {
  final _InMemoryCloud cloud;
  final String owner;
  _OwnerRecords(this.cloud, this.owner);

  Map<String, EncryptedRemoteRecord> get _bucket =>
      cloud.recordsByOwner.putIfAbsent(owner, () => {});

  @override
  Future<EncryptedRemoteRecord?> fetch(String route) async => _bucket[route];

  @override
  Future<EncryptedWriteResult> compareAndSwap({
    required String route,
    required int expectedRevision,
    required Map<String, dynamic> envelope,
  }) async {
    final existing = _bucket[route];
    if ((existing?.revision ?? 0) != expectedRevision) {
      return EncryptedWriteResult(success: false, revision: existing?.revision);
    }
    final rev = expectedRevision + 1;
    final seq = cloud.nextSeq();
    _bucket[route] = EncryptedRemoteRecord(
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
    final list = _bucket.values.where((r) => r.serverSeq > sinceSeq).toList()
      ..sort((a, b) => a.serverSeq.compareTo(b.serverSeq));
    return list.take(limit).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('FA-SEC-04: Isolamento total de contas, chaves e SyncOwnerGuard', () {
    const accountA = '11111111-1111-1111-1111-111111111111';
    const accountB = '22222222-2222-2222-2222-222222222222';

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      RecoveryKeyStore.resetForTesting();
    });

    test('Conta A cria/sincroniza -> logout -> Conta B entra: zero vazamento de chaves ou dados, Conta A recuperável', () async {
      final cloud = _InMemoryCloud();
      final deviceDb = AppDatabase.forTesting(NativeDatabase.memory());
      final deviceRepo = AppRepository(deviceDb);
      final keyStore = RecoveryKeyStore();
      var httpCalls = 0;
      final httpClient = MockClient((req) async {
        httpCalls++;
        return http.Response(jsonEncode([]), 200);
      });
      final mockSupabase = SupabaseClient(
        'https://mock.supabase.co',
        'mock-key',
        httpClient: httpClient,
      );

      addTearDown(() async {
        await deviceDb.close();
        mockSupabase.dispose();
      });

      // 1. Conta A configura cofre, cria dados pessoais e sincroniza
      final e2eeA = E2eeService(
        db: deviceDb,
        keyStore: keyStore,
        vaultTransportOverride: cloud.vaultFor(accountA),
        recordTransportOverride: cloud.recordsFor(accountA),
      );
      final phraseA = await e2eeA.setupNewVault(accountA);

      // Nunca deve espelhar a chave de Conta A para local_user
      expect(await e2eeA.isKeyInstalled(E2eeService.localUserId), isFalse);
      expect(await e2eeA.isKeyInstalled(accountB), isFalse);

      final personA = await deviceRepo.createPerson(
        name: 'Segredo da Conta A',
        phone: '+5511999990001',
      );
      final syncA = SupabaseSyncService(
        db: deviceDb,
        repository: deviceRepo,
        clientOverride: mockSupabase,
        e2eeServiceOverride: e2eeA,
        allowEncryptedSyncForTesting: true,
        authenticatedOwnerOverrideForTesting: accountA,
      );
      addTearDown(syncA.dispose);

      final resA = await syncA.sync();
      expect(resA.success, isTrue);
      expect(cloud.recordsByOwner[accountA], isNotEmpty);
      expect(await SyncOwnerGuard.getBoundOwnerId(deviceDb), accountA);

      // 2. Conta A cria alteração offline pendente e faz logout
      await deviceRepo.createPerson(name: 'Pendente Privado da Conta A');

      // 3. Conta B autentica no mesmo dispositivo (sem limpar workspace)
      final e2eeB = E2eeService(
        db: deviceDb,
        keyStore: keyStore,
        vaultTransportOverride: cloud.vaultFor(accountB),
        recordTransportOverride: cloud.recordsFor(accountB),
      );
      // Conta B NÃO herda a chave da Conta A
      expect(await e2eeB.isKeyInstalled(accountB), isFalse);
      expect(await e2eeB.getKey(accountB), isNull);

      await e2eeB.setupNewVault(accountB);
      expect(await e2eeB.isKeyInstalled(accountB), isTrue);

      final syncB = SupabaseSyncService(
        db: deviceDb,
        repository: deviceRepo,
        clientOverride: mockSupabase,
        e2eeServiceOverride: e2eeB,
        allowEncryptedSyncForTesting: true,
        authenticatedOwnerOverrideForTesting: accountB,
      );
      addTearDown(syncB.dispose);

      // 4. Sync da Conta B DEVE ser bloqueado pelo SyncOwnerGuard (ownerMismatch)
      final resBBlocked = await syncB.sync();
      expect(resBBlocked.success, isFalse);
      expect(resBBlocked.message, contains('isolamento de contas'));
      expect(cloud.recordsByOwner[accountB] ?? {}, isEmpty);
      expect(httpCalls, 0);

      // 5. Conta B executa troca explícita de workspace -> inicia limpa
      await SyncOwnerGuard.resetLocalWorkspaceForAccountSwitch(
        db: deviceDb,
        newOwnerId: accountB,
      );
      expect(await deviceRepo.getAllPeople(), isEmpty);
      expect(await SyncOwnerGuard.getBoundOwnerId(deviceDb), accountB);

      await deviceRepo.createPerson(name: 'Contato Exclusivo da Conta B');
      final resBClean = await syncB.sync();
      expect(resBClean.success, isTrue);
      expect(cloud.recordsByOwner[accountB]?.length, 1);

      // 6. Conta A recupera integralmente seus dados em um segundo dispositivo com sua frase
      final device2Db = AppDatabase.forTesting(NativeDatabase.memory());
      final device2Repo = AppRepository(device2Db);
      addTearDown(device2Db.close);

      final e2eeA2 = E2eeService(
        db: device2Db,
        keyStore: RecoveryKeyStore(),
        vaultTransportOverride: cloud.vaultFor(accountA),
        recordTransportOverride: cloud.recordsFor(accountA),
      );
      // Novo dispositivo usa outra instância de storage em memória
      FlutterSecureStorage.setMockInitialValues({});
      expect(await e2eeA2.restoreVault(accountA, phraseA), isTrue);

      final syncA2 = SupabaseSyncService(
        db: device2Db,
        repository: device2Repo,
        clientOverride: mockSupabase,
        e2eeServiceOverride: e2eeA2,
        allowEncryptedSyncForTesting: true,
        authenticatedOwnerOverrideForTesting: accountA,
      );
      addTearDown(syncA2.dispose);

      final pullA2 = await syncA2.fetchRemoteChanges();
      expect(pullA2.success, isTrue);
      final recoveredPeople = await device2Repo.getAllPeople();
      expect(recoveredPeople.map((p) => p.id), contains(personA.id));
      expect(
        recoveredPeople.map((p) => p.name),
        contains('Segredo da Conta A'),
      );
      expect(
        recoveredPeople.map((p) => p.name),
        isNot(contains('Contato Exclusivo da Conta B')),
      );
    });

    test('restoreVault falha fechado quando cofre remoto não existe (nunca cria cofre silenciosamente)', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final cloud = _InMemoryCloud();
      final e2ee = E2eeService(
        db: db,
        keyStore: RecoveryKeyStore(),
        vaultTransportOverride: cloud.vaultFor(accountA),
      );

      final phrase = RecoveryCrypto.createPhrase();
      await expectLater(
        () => e2ee.restoreVault(accountA, phrase),
        throwsStateError,
      );
      expect(cloud.vaultsByOwner[accountA], isNull);
      expect(await e2ee.isKeyInstalled(accountA), isFalse);
    });

    test(
      'demo_mode bloqueia sincronização centralmente no SyncOwnerGuard',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await db
            .into(db.appKvStore)
            .insert(
              AppKvStoreCompanion.insert(key: 'demo_mode', value: 'true'),
            );
        final decision = await SyncOwnerGuard.evaluate(
          db: db,
          authenticatedUserId: accountA,
        );
        expect(decision.status, SyncOwnerGuardStatus.demoModeActive);
        expect(decision.isAllowed, isFalse);
      },
    );

    test('migração local_user -> conta exige confirmação explícita', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final keyStore = RecoveryKeyStore();
      final e2ee = E2eeService(db: db, keyStore: keyStore);

      await e2ee.setupNewVault(E2eeService.localUserId);
      expect(await e2ee.isKeyInstalled(E2eeService.localUserId), isTrue);
      expect(await e2ee.isKeyInstalled(accountA), isFalse);

      await expectLater(
        () => e2ee.migrateLocalKeyToAccount(
          targetOwnerId: accountA,
          userConfirmed: false,
        ),
        throwsStateError,
      );
      expect(await e2ee.isKeyInstalled(accountA), isFalse);

      await e2ee.migrateLocalKeyToAccount(
        targetOwnerId: accountA,
        userConfirmed: true,
      );
      expect(await e2ee.isKeyInstalled(accountA), isTrue);
      expect(await e2ee.isKeyInstalled(E2eeService.localUserId), isFalse);
    });
  });
}
