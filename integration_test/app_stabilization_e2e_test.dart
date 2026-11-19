import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/settings/backup_service.dart';
import 'package:ministerio_pessoal/sync/crypto/e2ee_service.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_crypto.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_record_sync.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_key_store.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_vault_transport.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:ministerio_pessoal/sync/sync_owner_guard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Test helper: keep the phrase before initiating the create-only request.
Future<String> _createTestVault(E2eeService service, String owner) async {
  final phrase = RecoveryCrypto.createPhrase();
  await service.setupVaultWithPhrase(owner, phrase);
  return phrase;
}


class _CloudStub {
  final Map<String, Map<String, dynamic>> vaults = {};
  final Map<String, Map<String, EncryptedRemoteRecord>> recordsByOwner = {};
  int _seq = 0;
  int nextSeq() => ++_seq;
}

class _StubVault implements RecoveryVaultTransport {
  final _CloudStub cloud;
  final String owner;
  _StubVault(this.cloud, this.owner);
  @override
  Future<Map<String, dynamic>?> fetch() async => cloud.vaults[owner];
  @override
  Future<bool> createIfAbsent(Map<String, dynamic> marker) async {
    if (cloud.vaults.containsKey(owner)) return false;
    cloud.vaults[owner] = Map<String, dynamic>.from(marker);
    return true;
  }
}

class _StubRecords implements PaginatedEncryptedRecordTransport {
  final _CloudStub cloud;
  final String owner;
  _StubRecords(this.cloud, this.owner);
  Map<String, EncryptedRemoteRecord> get _rows =>
      cloud.recordsByOwner.putIfAbsent(owner, () => {});
  @override
  Future<EncryptedRemoteRecord?> fetch(String route) async => _rows[route];
  @override
  Future<EncryptedWriteResult> compareAndSwap({
    required String route,
    required int expectedRevision,
    required Map<String, dynamic> envelope,
  }) async {
    final existing = _rows[route];
    if ((existing?.revision ?? 0) != expectedRevision) {
      return EncryptedWriteResult(success: false, revision: existing?.revision);
    }
    final rev = expectedRevision + 1;
    final seq = cloud.nextSeq();
    _rows[route] = EncryptedRemoteRecord(
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
    final list = _rows.values.where((r) => r.serverSeq > sinceSeq).toList()
      ..sort((a, b) => a.serverSeq.compareTo(b.serverSeq));
    return list.take(limit).toList();
  }
}

/// Fluxo de integração end-to-end (FA-TEST-01):
/// Cadastro -> Revisita -> Estudo -> Sessão -> Agenda -> Backup -> Restore ->
/// Sincronização E2EE 2 dispositivos -> Isolamento Conta A / Conta B.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  test('E2E: Jornada ministerial completa + Backup/Restore + E2EE 2 dispositivos + Isolamento de contas', () async {
    FlutterSecureStorage.setMockInitialValues({});
    RecoveryKeyStore.resetForTesting();

    const ownerA = 'aaaa1111-1111-1111-1111-111111111111';
    const ownerB = 'bbbb2222-2222-2222-2222-222222222222';
    final cloud = _CloudStub();
    final mockClient = SupabaseClient(
      'https://mock.supabase.co',
      'mock-key',
      httpClient: MockClient((req) async => http.Response(jsonEncode([]), 200)),
    );
    final dir1 = await Directory.systemTemp.createTemp('int_dev1_');
    final dir2 = await Directory.systemTemp.createTemp('int_dev2_');
    final db1 = AppDatabase.forTesting(NativeDatabase.memory());
    final repo1 = AppRepository(db1);
    final db2 = AppDatabase.forTesting(NativeDatabase.memory());
    final repo2 = AppRepository(db2);

    addTearDown(() async {
      await db1.close();
      await db2.close();
      mockClient.dispose();
      if (await dir1.exists()) await dir1.delete(recursive: true);
      if (await dir2.exists()) await dir2.delete(recursive: true);
    });

    // 1. Jornada ministerial offline completa na Conta A (Dispositivo 1)
    final now = DateTime.now().toUtc();
    final person = await repo1.createPerson(
      name: 'Lucas Amazonas',
      phone: '+5592991112222',
      address: 'Av. Beira Rio, 100',
      status: 'revisita',
    );
    await repo1.createVisit(
      personId: person.id,
      dateTime: now,
      contactType: 'revisita',
      result: 'Pediu estudo bíblico',
      topicsDiscussed: 'Esperança para o futuro',
    );
    final study = await repo1.createStudy(
      title: 'Estudo com Lucas',
      publicationId: 'lff-book',
      language: 'pt',
      participantPersonIds: [person.id],
      primaryParticipantId: person.id,
    );
    await repo1.createStudySession(
      studyId: study.id,
      dateTime: now,
      publicationCode: 'lff-book',
      lessonCovered: 1,
      paragraphsCovered: '1-5',
      status: 'realizada',
      participantIds: [person.id],
    );
    await repo1.createAppointment(
      personId: person.id,
      studyId: study.id,
      title: 'Estudo Bíblico Lucas',
      startTime: now.add(const Duration(days: 7)),
      endTime: now.add(const Duration(days: 7, hours: 1)),
      durationMinutes: 60,
      status: 'confirmado',
    );

    // 2. E2EE Push (Dispositivo 1) -> Pull (Dispositivo 2)
    final e2ee1 = E2eeService(
      db: db1,
      keyStore: RecoveryKeyStore(),
      vaultTransportOverride: _StubVault(cloud, ownerA),
      recordTransportOverride: _StubRecords(cloud, ownerA),
    );
    final phraseA = await _createTestVault(e2ee1, ownerA);
    final sync1 = SupabaseSyncService(
      db: db1,
      repository: repo1,
      clientOverride: mockClient,
      e2eeServiceOverride: e2ee1,
      documentsDirectoryProvider: () async => dir1.path,
      allowEncryptedSyncForTesting: true,
      authenticatedOwnerOverrideForTesting: ownerA,
    );
    addTearDown(sync1.dispose);

    final pushRes = await sync1.sync();
    expect(pushRes.success, isTrue, reason: pushRes.errors.join('; '));
    expect(
      jsonEncode(
        cloud.recordsByOwner[ownerA]!.values.map((e) => e.envelope).toList(),
      ),
      isNot(contains('Lucas Amazonas')),
    );

    // 3. Dispositivo 2 recebe e descriptografa toda a jornada
    FlutterSecureStorage.setMockInitialValues({});
    final e2ee2 = E2eeService(
      db: db2,
      keyStore: RecoveryKeyStore(),
      vaultTransportOverride: _StubVault(cloud, ownerA),
      recordTransportOverride: _StubRecords(cloud, ownerA),
    );
    expect(await e2ee2.restoreVault(ownerA, phraseA), isTrue);
    final sync2 = SupabaseSyncService(
      db: db2,
      repository: repo2,
      clientOverride: mockClient,
      e2eeServiceOverride: e2ee2,
      documentsDirectoryProvider: () async => dir2.path,
      allowEncryptedSyncForTesting: true,
      authenticatedOwnerOverrideForTesting: ownerA,
    );
    addTearDown(sync2.dispose);

    final pullRes = await sync2.fetchRemoteChanges();
    expect(pullRes.success, isTrue, reason: pullRes.errors.join('; '));
    expect((await repo2.getAllPeople()).single.name, 'Lucas Amazonas');
    expect((await repo2.getAllStudies()).single.title, 'Estudo com Lucas');
    expect(
      (await repo2.getAllAppointments()).single.title,
      'Estudo Bíblico Lucas',
    );

    // 4. Backup & Restore real (preview + commitRestore) preserva owner da Conta A
    final backup = BackupService(
      repo2,
      documentsDirectoryProvider: () async => dir2,
    );
    final encryptedBak = await backup.exportEncryptedBackup(
      'IntPass#2026',
      iterations: 1000,
    );
    final preview = await backup.previewBackup(
      encryptedDataString: encryptedBak,
      password: 'IntPass#2026',
    );
    expect(preview.isIntegral, isTrue);
    final restoreRes = await backup.commitRestore(preview);
    expect(restoreRes.isIntegral, isTrue);
    expect(await SyncOwnerGuard.getBoundOwnerId(db2), equals(ownerA));

    // 5. Conta B entra no Dispositivo 2 -> bloqueada pelo SyncOwnerGuard
    final decisionB = await SyncOwnerGuard.evaluate(
      db: db2,
      authenticatedUserId: ownerB,
    );
    expect(decisionB.status, SyncOwnerGuardStatus.ownerMismatch);
    expect(decisionB.isAllowed, isFalse);
  });
}
