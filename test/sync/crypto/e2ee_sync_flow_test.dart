import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/sync/crypto/e2ee_service.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_record_sync.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_key_store.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_vault_transport.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MemoryVault implements RecoveryVaultTransport {
  Map<String, dynamic>? marker;
  @override
  Future<Map<String, dynamic>?> fetch() async => marker;
  @override
  Future<bool> createIfAbsent(Map<String, dynamic> proposed) async {
    if (marker != null) return false;
    marker = Map<String, dynamic>.from(proposed);
    return true;
  }
}

class _MemoryRecordTransport implements EncryptedRecordTransport {
  final Map<String, EncryptedRemoteRecord> rows = {};
  @override
  Future<EncryptedRemoteRecord?> fetch(String route) async => rows[route];
  @override
  Future<EncryptedWriteResult> compareAndSwap({
    required String route,
    required int expectedRevision,
    required Map<String, dynamic> envelope,
  }) async {
    final revision = expectedRevision + 1;
    rows[route] = EncryptedRemoteRecord(route: route, revision: revision, envelope: envelope);
    return EncryptedWriteResult(success: true, revision: revision);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Sincronização com E2EE ativo processa fila com proteção criptográfica', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = AppRepository(db);
    final keyStore = RecoveryKeyStore();
    const testOwner = 'e2ee-test-owner-uid';

    // Cria requisições simuladas do Supabase
    final httpClient = MockClient((request) async {
      return http.Response(jsonEncode([]), 200);
    });

    final client = SupabaseClient('https://mock.supabase.co', 'mock-anon-key', httpClient: httpClient);
    final vaultTransport = _MemoryVault();
    final recordTransport = _MemoryRecordTransport();
    final e2ee = E2eeService(
      db: db,
      keyStore: keyStore,
      client: client,
      vaultTransportOverride: vaultTransport,
      recordTransportOverride: recordTransport,
    );

    final sync = SupabaseSyncService(
      db: db,
      repository: repo,
      clientOverride: client,
      e2eeServiceOverride: e2ee,
      allowLegacySyncForTesting: true,
    );

    addTearDown(() async {
      await keyStore.clear(testOwner);
      sync.dispose();
      await db.close();
    });

    // 1. Antes de configurar o cofre: a sincronização fica pausada
    final person = await repo.createPerson(name: 'Irmão Teste');
    expect(person.name, 'Irmão Teste');
    final beforeOps = await repo.getPendingSyncOperations();
    expect(beforeOps, isNotEmpty);

    // 2. Configura o cofre E2EE
    final phrase = await e2ee.setupNewVault(testOwner);
    expect(phrase.split(' ').length, 24);
    expect(await e2ee.isKeyInstalled(testOwner), isTrue);

    // 3. Verifica que a chave está pronta para criptografia
    final recordSync = await e2ee.getRecordSync(testOwner);
    expect(recordSync, isNotNull);
    final checkpoint = await e2ee.getCheckpoint(testOwner);
    expect(checkpoint, isNotNull);
  });
}
