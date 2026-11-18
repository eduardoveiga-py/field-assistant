import 'dart:convert';
import 'dart:typed_data';

import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_crypto.dart';

void main() {
  test(
    'frase de 24 palavras portuguesa reproduz chave em outro aparelho',
    () async {
      final phrase = RecoveryCrypto.createPhrase();
      expect(phrase.split(' '), hasLength(24));
      final first = await RecoveryCrypto.keyFromPhrase(phrase);
      final other = await RecoveryCrypto.keyFromPhrase(
        '  ${phrase.replaceAll(' ', '  ')}  ',
      );
      expect(await first.extractBytes(), await other.extractBytes());
      expect(await first.extractBytes(), hasLength(32));
    },
  );

  test('rejeita frase incorreta ou com checksum adulterado', () async {
    await expectLater(
      RecoveryCrypto.keyFromPhrase('frase curta'),
      throwsFormatException,
    );
    final phrase = Mnemonic(List<int>.filled(32, 0), Language.portuguese).words;
    phrase[23] =
        Language.portuguese.list[0]; // checksum conhecido diferente de zero
    await expectLater(
      RecoveryCrypto.keyFromPhrase(phrase.join(' ')),
      throwsFormatException,
    );
  });

  test('cifra, detecta adulteração, chave errada e contexto trocado', () async {
    final key = await RecoveryCrypto.keyFromPhrase(
      RecoveryCrypto.createPhrase(),
    );
    final otherKey = await RecoveryCrypto.keyFromPhrase(
      RecoveryCrypto.createPhrase(),
    );
    final plain = Uint8List.fromList(
      utf8.encode('Nota pessoal e conteúdo privado'),
    );
    final box = await RecoveryCrypto.seal(
      key: key,
      owner: 'conta',
      kind: 'nota',
      id: 'id',
      plaintext: plain,
    );
    final second = await RecoveryCrypto.seal(
      key: key,
      owner: 'conta',
      kind: 'nota',
      id: 'id',
      plaintext: plain,
    );
    expect(box['nonce'], isNot(second['nonce']));
    expect(jsonEncode(box), isNot(contains('Nota pessoal')));
    expect(
      await RecoveryCrypto.open(
        key: key,
        owner: 'conta',
        kind: 'nota',
        id: 'id',
        envelope: box,
      ),
      plain,
    );
    await expectLater(
      RecoveryCrypto.open(
        key: otherKey,
        owner: 'conta',
        kind: 'nota',
        id: 'id',
        envelope: box,
      ),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
    await expectLater(
      RecoveryCrypto.open(
        key: key,
        owner: 'conta',
        kind: 'nota',
        id: 'outro',
        envelope: box,
      ),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
    final ciphertext = base64Decode(box['ciphertext']! as String)..[0] ^= 1;
    final altered = {...box, 'ciphertext': base64Encode(ciphertext)};
    await expectLater(
      RecoveryCrypto.open(
        key: key,
        owner: 'conta',
        kind: 'nota',
        id: 'id',
        envelope: altered,
      ),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
    await expectLater(
      RecoveryCrypto.open(
        key: key,
        owner: 'conta',
        kind: 'nota',
        id: 'id',
        envelope: {...box, 'v': 0},
      ),
      throwsFormatException,
    );
  });
}
