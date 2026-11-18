import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_crypto.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_vault_verifier.dart';

void main() {
  test(
    'verifica a mesma chave em outro dispositivo sem revelar a frase',
    () async {
      final phrase = RecoveryCrypto.createPhrase();
      final key = await RecoveryCrypto.keyFromPhrase(phrase);
      final marker = await RecoveryVaultVerifier.create(
        root: key,
        owner: 'account-a',
      );
      final decoded = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(marker)) as Map,
      );
      final restored = await RecoveryCrypto.keyFromPhrase(phrase);
      expect(
        await RecoveryVaultVerifier.verify(
          root: restored,
          owner: 'account-a',
          marker: decoded,
        ),
        marker['vaultId'],
      );
      expect(jsonEncode(marker), isNot(contains(phrase)));
      final other = await RecoveryVaultVerifier.create(
        root: key,
        owner: 'account-a',
      );
      expect(other['vaultId'], isNot(marker['vaultId']));
    },
  );

  test('rejeita chave errada, outra conta e adulteração', () async {
    final key = await RecoveryCrypto.keyFromPhrase(
      RecoveryCrypto.createPhrase(),
    );
    final wrong = await RecoveryCrypto.keyFromPhrase(
      RecoveryCrypto.createPhrase(),
    );
    final marker = await RecoveryVaultVerifier.create(
      root: key,
      owner: 'account-a',
    );
    await expectLater(
      RecoveryVaultVerifier.verify(
        root: wrong,
        owner: 'account-a',
        marker: marker,
      ),
      throwsA(anything),
    );
    await expectLater(
      RecoveryVaultVerifier.verify(
        root: key,
        owner: 'account-b',
        marker: marker,
      ),
      throwsA(anything),
    );
    final idChanged = Map<String, dynamic>.from(marker)
      ..['vaultId'] = '00000000000000000000000000000000';
    await expectLater(
      RecoveryVaultVerifier.verify(
        root: key,
        owner: 'account-a',
        marker: idChanged,
      ),
      throwsA(anything),
    );
    final altered = Map<String, dynamic>.from(marker);
    final envelope = Map<String, dynamic>.from(marker['envelope'] as Map);
    final tag = envelope['tag'] as String;
    envelope['tag'] = '${tag[0] == 'A' ? 'B' : 'A'}${tag.substring(1)}';
    altered['envelope'] = envelope;
    await expectLater(
      RecoveryVaultVerifier.verify(
        root: key,
        owner: 'account-a',
        marker: altered,
      ),
      throwsA(anything),
    );
  });

  test(
    'rejeita campos adicionais, formato desconhecido e id inválido',
    () async {
      final key = await RecoveryCrypto.keyFromPhrase(
        RecoveryCrypto.createPhrase(),
      );
      final marker = await RecoveryVaultVerifier.create(
        root: key,
        owner: 'account-a',
      );
      for (final bad in [
        Map<String, dynamic>.from(marker)..['extra'] = true,
        Map<String, dynamic>.from(marker)..['version'] = 2,
        Map<String, dynamic>.from(marker)..['vaultId'] = 'bad',
        Map<String, dynamic>.from(marker)..['envelope'] = 'bad',
      ]) {
        await expectLater(
          RecoveryVaultVerifier.verify(
            root: key,
            owner: 'account-a',
            marker: bad,
          ),
          throwsFormatException,
        );
      }
    },
  );
}
