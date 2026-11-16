import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/sync/crypto/e2ee_service.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_record_sync.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_crypto.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_key_store.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_vault_transport.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_vault_verifier.dart';

class _MockVaultTransport implements RecoveryVaultTransport {
  Map<String, dynamic>? marker;
  @override
  Future<Map<String, dynamic>?> fetch() async => marker;
  @override
  Future<bool> createIfAbsent(Map<String, dynamic> m) async {
    if (marker != null) return false;
    marker = m;
    return true;
  }
}

class _MockRecordTransport implements EncryptedRecordTransport {
  @override
  Future<EncryptedRemoteRecord?> fetch(String route) async => null;
  @override
  Future<EncryptedWriteResult> compareAndSwap({
    required String route,
    required int expectedRevision,
    required Map<String, dynamic> envelope,
  }) async => const EncryptedWriteResult(success: true, revision: 1);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('E2eeService', () {
    late AppDatabase db;
    late RecoveryKeyStore keyStore;
    late _MockVaultTransport transport;
    late _MockRecordTransport recordTransport;
    late E2eeService service;
    const testOwner = 'user-e2ee-12345';

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      keyStore = RecoveryKeyStore();
      transport = _MockVaultTransport();
      recordTransport = _MockRecordTransport();
      service = E2eeService(
        db: db,
        keyStore: keyStore,
        vaultTransportOverride: transport,
        recordTransportOverride: recordTransport,
      );
    });

    tearDown(() async {
      await keyStore.clear(testOwner);
      await db.close();
    });

    test('isKeyInstalled inicial retorna falso e true após setupNewVault', () async {
      expect(await service.isKeyInstalled(testOwner), isFalse);

      final phrase = await service.setupNewVault(testOwner);
      final words = phrase.split(' ');
      expect(words.length, 24);

      expect(await service.isKeyInstalled(testOwner), isTrue);
      expect(await service.getKey(testOwner), isNotNull);
      expect(transport.marker, isNotNull);
      expect(transport.marker!['version'], 1);
    });

    test('restoreVault restaura chave com sucesso quando a frase é válida', () async {
      final phrase = RecoveryCrypto.createPhrase();
      final key = await RecoveryCrypto.keyFromPhrase(phrase);
      final marker = await RecoveryVaultVerifier.create(root: key, owner: testOwner);
      transport.marker = marker;

      expect(await service.isKeyInstalled(testOwner), isFalse);
      final ok = await service.restoreVault(testOwner, phrase);
      expect(ok, isTrue);
      expect(await service.isKeyInstalled(testOwner), isTrue);
    });

    test('restoreVault falha se a frase não corresponder ao cofre existente', () async {
      final phrase1 = RecoveryCrypto.createPhrase();
      final phrase2 = RecoveryCrypto.createPhrase();
      final key1 = await RecoveryCrypto.keyFromPhrase(phrase1);
      final marker1 = await RecoveryVaultVerifier.create(root: key1, owner: testOwner);
      transport.marker = marker1;

      expect(
        () => service.restoreVault(testOwner, phrase2),
        throwsA(isA<FormatException>()),
      );
    });

    test('getRecordSync e getCheckpoint retornam instâncias ativas quando chave existe', () async {
      await service.setupNewVault(testOwner);
      final recordSync = await service.getRecordSync(testOwner);
      expect(recordSync, isNotNull);
      expect(recordSync!.owner, testOwner);

      final checkpoint = await service.getCheckpoint(testOwner);
      expect(checkpoint, isNotNull);
    });
  });
}
