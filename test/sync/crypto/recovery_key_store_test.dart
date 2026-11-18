import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_crypto.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_key_store.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_vault_verifier.dart';

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
}
