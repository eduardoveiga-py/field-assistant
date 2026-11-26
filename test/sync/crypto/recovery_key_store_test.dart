import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/sync/crypto/e2ee_service.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_crypto.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_key_store.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_vault_verifier.dart';
import 'package:ministerio_pessoal/sync/crypto/web_key_persistence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'confirma frase, guarda apenas chave e reabre para a mesma conta',
    () async {
      final store = RecoveryKeyStore();
      final phrase = RecoveryCrypto.createPhrase();
      await store.install(
        owner: 'conta-a',
        phrase: phrase,
        confirmation: phrase,
      );
      final restored = await store.load('conta-a');
      expect(restored, isNotNull);
      expect(
        await restored!.extractBytes(),
        await (await RecoveryCrypto.keyFromPhrase(phrase)).extractBytes(),
      );
      expect(await store.load('conta-b'), isNull);
      final entries = await const FlutterSecureStorage().readAll();
      expect(entries.length, 1);
      expect(entries.values.single, isNot(contains(phrase)));
      expect(entries.keys.single, isNot(contains('conta-a')));
    },
  );

  test('não aceita confirmação errada nem substitui chave existente', () async {
    final store = RecoveryKeyStore();
    final first = RecoveryCrypto.createPhrase();
    final second = RecoveryCrypto.createPhrase();
    await expectLater(
      store.install(owner: 'conta', phrase: first, confirmation: second),
      throwsFormatException,
    );
    expect(await store.load('conta'), isNull);
    await store.install(owner: 'conta', phrase: first, confirmation: first);
    await store.install(owner: 'conta', phrase: first, confirmation: first);
    await expectLater(
      store.install(owner: 'conta', phrase: second, confirmation: second),
      throwsStateError,
    );
    expect(
      await (await store.load('conta'))!.extractBytes(),
      await (await RecoveryCrypto.keyFromPhrase(first)).extractBytes(),
    );
  });

  test('instalações concorrentes não substituem a primeira', () async {
    final first = RecoveryCrypto.createPhrase();
    final second = RecoveryCrypto.createPhrase();
    final a = RecoveryKeyStore();
    final b = RecoveryKeyStore();
    final one = a.install(owner: 'conta', phrase: first, confirmation: first);
    final two = b.install(owner: 'conta', phrase: second, confirmation: second);
    final rejected = expectLater(two, throwsStateError);
    await one;
    await rejected;
    expect(
      await (await a.load('conta'))!.extractBytes(),
      await (await RecoveryCrypto.keyFromPhrase(first)).extractBytes(),
    );
  });
  test(
    'chave armazenada corrompida não é substituída silenciosamente',
    () async {
      final store = RecoveryKeyStore();
      final phrase = RecoveryCrypto.createPhrase();
      await store.install(owner: 'conta', phrase: phrase, confirmation: phrase);
      const secure = FlutterSecureStorage();
      final name = (await secure.readAll()).keys.single;
      await secure.write(key: name, value: 'v1:dado-corrompido');
      await expectLater(store.load('conta'), throwsFormatException);
      await expectLater(
        store.install(owner: 'conta', phrase: phrase, confirmation: phrase),
        throwsFormatException,
      );
      expect(await secure.read(key: name), 'v1:dado-corrompido');
    },
  );

  test(
    'restauração exige chave e identidade do cofre previamente conhecido',
    () async {
      final phrase = RecoveryCrypto.createPhrase();
      final other = RecoveryCrypto.createPhrase();
      final key = await RecoveryCrypto.keyFromPhrase(phrase);
      final marker = await RecoveryVaultVerifier.create(
        root: key,
        owner: 'conta',
      );
      final id = marker['vaultId'] as String;
      final store = RecoveryKeyStore();
      await expectLater(
        store.restoreVerified(
          owner: 'conta',
          phrase: other,
          confirmation: other,
          marker: marker,
          expectedVaultId: id,
        ),
        throwsA(anything),
      );
      await expectLater(
        store.restoreVerified(
          owner: 'conta',
          phrase: phrase,
          confirmation: phrase,
          marker: marker,
          expectedVaultId: 'outro',
        ),
        throwsStateError,
      );
      await expectLater(
        store.restoreVerified(
          owner: 'conta',
          phrase: phrase,
          confirmation: other,
          marker: marker,
          expectedVaultId: id,
        ),
        throwsFormatException,
      );
      expect(await store.load('conta'), isNull);
      await store.restoreVerified(
        owner: 'conta',
        phrase: phrase,
        confirmation: phrase,
        marker: marker,
        expectedVaultId: id,
      );
      expect(
        await (await store.load('conta'))!.extractBytes(),
        await key.extractBytes(),
      );
      await expectLater(
        store.restoreVerified(
          owner: 'outra',
          phrase: phrase,
          confirmation: phrase,
          marker: marker,
          expectedVaultId: id,
        ),
        throwsA(anything),
      );
      expect(await store.load('outra'), isNull);
    },
  );

  group('Web Persistent E2EE & PIN Lock (IndexedDB/WebCrypto adapter)', () {
    setUp(() => RecoveryKeyStore.resetForTesting());

    test(
      'persistência automática Web sobrevive a reload sem gravar frase',
      () async {
        final webAdapter = MemoryWebKeyPersistenceAdapter();
        final storeBeforeReload = RecoveryKeyStore(webPersistence: webAdapter);
        final phrase = RecoveryCrypto.createPhrase();
        final expectedBytes = await (await RecoveryCrypto.keyFromPhrase(phrase))
            .extractBytes();

        await storeBeforeReload.install(
          owner: 'user-pwa-1',
          phrase: phrase,
          confirmation: phrase,
        );
        expect(
          await storeBeforeReload.getWebUnlockState('user-pwa-1'),
          WebKeyUnlockMode.persistentBrowser,
        );

        // Simula recarregamento completo da página limpando o cache em RAM.
        RecoveryKeyStore.resetForTesting();
        final storeAfterReload = RecoveryKeyStore(webPersistence: webAdapter);
        final loaded = await storeAfterReload.load('user-pwa-1');
        expect(loaded, isNotNull);
        expect(await loaded!.extractBytes(), expectedBytes);
        expect(await storeAfterReload.load('user-pwa-2'), isNull);

        // Copy entre contas e limpeza explícita no navegador
        await storeAfterReload.copyOwnerKey(
          fromOwner: 'user-pwa-1',
          toOwner: 'local_user',
        );
        expect(
          await (await storeAfterReload.load('local_user'))!.extractBytes(),
          expectedBytes,
        );
        await storeAfterReload.clear('user-pwa-1');
        RecoveryKeyStore.resetForTesting();
        expect(await storeAfterReload.load('user-pwa-1'), isNull);
      },
    );

    test(
      'proteção por PIN Web bloqueia após reload e exige PIN correto',
      () async {
        expect(WebPinKeyWrapper.defaultIterations, equals(600000));
        final webAdapter = MemoryWebKeyPersistenceAdapter(
          pinWrapper: const WebPinKeyWrapper(iterations: 10000),
        );
        final store = RecoveryKeyStore(webPersistence: webAdapter);
        final phrase = RecoveryCrypto.createPhrase();
        final expectedBytes = await (await RecoveryCrypto.keyFromPhrase(phrase))
            .extractBytes();

        // Rejeita PIN curto
        await expectLater(
          store.install(
            owner: 'shared-pc',
            phrase: phrase,
            confirmation: phrase,
            webUnlockPin: '123',
          ),
          throwsFormatException,
        );

        await store.install(
          owner: 'shared-pc',
          phrase: phrase,
          confirmation: phrase,
          webUnlockPin: 'segredo-2026',
        );
        expect(
          await store.getWebUnlockState('shared-pc'),
          WebKeyUnlockMode.unlockedFromPin,
        );

        // Bloquear sessão ou recarregar aba limpa RAM, mantendo cofre cifrado no IndexedDB
        await store.lockWebSession('shared-pc');
        expect(await store.isWebPinLocked('shared-pc'), isTrue);
        expect(await store.load('shared-pc'), isNull);

        await expectLater(
          store.unlockWithPin(owner: 'shared-pc', pin: 'pin-errado'),
          throwsFormatException,
        );

        final unlocked = await store.unlockWithPin(
          owner: 'shared-pc',
          pin: 'segredo-2026',
        );
        expect(await unlocked.extractBytes(), expectedBytes);
        expect(
          await store.getWebUnlockState('shared-pc'),
          WebKeyUnlockMode.unlockedFromPin,
        );
      },
    );

    test('registro Web corrompido falha fechado e não é sobrescrito', () async {
      final webAdapter = MemoryWebKeyPersistenceAdapter(
        pinWrapper: const WebPinKeyWrapper(iterations: 2000),
      );
      final store = RecoveryKeyStore(webPersistence: webAdapter);
      final phrase = RecoveryCrypto.createPhrase();
      final keyId = RecoveryKeyStore.storageKeyForTesting('corrupt-owner');

      await store.install(
        owner: 'corrupt-owner',
        phrase: phrase,
        confirmation: phrase,
      );
      await store.lockWebSession('corrupt-owner');
      webAdapter.injectCorruptEntryForTesting(keyId, {
        'mode': 'corrupted-blob',
      });

      await expectLater(store.load('corrupt-owner'), throwsFormatException);
      await expectLater(
        store.install(
          owner: 'corrupt-owner',
          phrase: phrase,
          confirmation: phrase,
        ),
        throwsFormatException,
      );

      // Também testa envelope PIN adulterado e stub platform persistence
      final stubAdapter = createWebPersistenceAdapterForTest();
      expect(stubAdapter, isNotNull);
      webAdapter.injectCorruptEntryForTesting(keyId, {
        'mode': 'pin',
        'v': 1,
        'kdf': 'PBKDF2-SHA256',
        'iterations': 500, // abaixo do mínimo 1000
        'salt': 'a' * 24,
        'nonce': 'b' * 16,
        'ciphertext': 'c' * 44,
        'tag': 'd' * 24,
      });
      await expectLater(
        store.unlockWithPin(owner: 'corrupt-owner', pin: 'segredo123'),
        throwsFormatException,
      );
    });

    test(
      'E2eeService gerencia Web PIN lock, unlock e status mode com DB local',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final webAdapter = MemoryWebKeyPersistenceAdapter(
          pinWrapper: const WebPinKeyWrapper(iterations: 2000),
        );
        final keyStore = RecoveryKeyStore(webPersistence: webAdapter);
        final e2ee = E2eeService(db: db, keyStore: keyStore);
        final phrase = RecoveryCrypto.createPhrase();

        expect(await e2ee.getWebUnlockMode('u1'), WebKeyUnlockMode.none);
        await e2ee.restoreVault('u1', phrase, webUnlockPin: 'pin998877');
        expect(
          await e2ee.getWebUnlockMode('u1'),
          WebKeyUnlockMode.unlockedFromPin,
        );
        expect(await e2ee.isWebPinLocked('u1'), isFalse);

        await e2ee.lockWebSession('u1');
        expect(await e2ee.isWebPinLocked('u1'), isTrue);
        expect(await e2ee.isKeyInstalled('u1'), isFalse);

        expect(
          await e2ee.unlockWithWebPin(ownerId: 'u1', pin: 'pin998877'),
          isTrue,
        );
        expect(await e2ee.isKeyInstalled('u1'), isTrue);

        // Troca para outro key em persistent mode rejeita sobrescrita sem clear
        final other = RecoveryCrypto.createPhrase();
        await expectLater(
          keyStore.install(
            owner: 'u1',
            phrase: other,
            confirmation: other,
            webUnlockPin: 'pin998877',
          ),
          throwsStateError,
        );
      },
    );

    test(
      'WebPinKeyWrapper valida comprimento de chave, PIN e envelopes',
      () async {
        const wrapper = WebPinKeyWrapper(iterations: 2000);
        expect(
          () => wrapper.wrap(
            owner: 'u1',
            storageKey: 'k1',
            keyBytes: Uint8List(16),
            pin: 'abcdef',
          ),
          throwsArgumentError,
        );
        final valid = await wrapper.wrap(
          owner: 'u1',
          storageKey: 'k1',
          keyBytes: Uint8List.fromList(List<int>.filled(32, 7)),
          pin: 'abcdef',
        );
        final unwrapped = await wrapper.unwrap(
          owner: 'u1',
          storageKey: 'k1',
          envelope: valid,
          pin: 'abcdef',
        );
        expect(unwrapped, List<int>.filled(32, 7));
        await expectLater(
          wrapper.unwrap(
            owner: 'u1',
            storageKey: 'k1',
            envelope: valid,
            pin: '',
          ),
          throwsFormatException,
        );
      },
    );
  });
}

WebKeyPersistenceAdapter createWebPersistenceAdapterForTest() =>
    MemoryWebKeyPersistenceAdapter();
