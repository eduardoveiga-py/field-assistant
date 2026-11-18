import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_record.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_crypto.dart';

void main() {
  test(
    'dois aparelhos reproduzem rota e decifram sem expor conteúdo',
    () async {
      final phrase = RecoveryCrypto.createPhrase();
      final sender = await RecoveryCrypto.keyFromPhrase(phrase);
      final receiver = await RecoveryCrypto.keyFromPhrase(phrase);
      final row = await EncryptedRecord.seal(
        key: sender,
        owner: 'owner',
        entityType: 'contacts',
        entityId: 'person-id',
        revision: 1,
        data: {'name': 'Nome pessoal', 'phone': '1234'},
      );
      expect(jsonEncode(row), isNot(contains('Nome pessoal')));
      expect(jsonEncode(row), isNot(contains('person-id')));
      expect(jsonEncode(row), isNot(contains('contacts')));
      final route = row['route'] as String;
      expect(
        route,
        await EncryptedRecord.route(
          key: receiver,
          owner: 'owner',
          entityType: 'contacts',
          entityId: 'person-id',
        ),
      );
      expect(
        route,
        isNot(
          await EncryptedRecord.route(
            key: receiver,
            owner: 'another',
            entityType: 'contacts',
            entityId: 'person-id',
          ),
        ),
      );
      final opened = await EncryptedRecord.open(
        key: receiver,
        owner: 'owner',
        routeId: route,
        revision: 1,
        envelope: row['envelope'] as Map<String, dynamic>,
      );
      expect(opened['entityId'], 'person-id');
      expect(opened['data'], {'name': 'Nome pessoal', 'phone': '1234'});
    },
  );

  test(
    'dono, identidade opaca, revisão ou chave errados são rejeitados',
    () async {
      final key = await RecoveryCrypto.keyFromPhrase(
        RecoveryCrypto.createPhrase(),
      );
      final other = await RecoveryCrypto.keyFromPhrase(
        RecoveryCrypto.createPhrase(),
      );
      final row = await EncryptedRecord.seal(
        key: key,
        owner: 'owner',
        entityType: 'notes',
        entityId: 'note',
        revision: 4,
        data: {'content': 'privado'},
      );
      final route = row['route'] as String;
      final box = row['envelope'] as Map<String, dynamic>;
      Future<Map<String, dynamic>> read(
        SecretKey k,
        String owner,
        String id,
        int rev,
      ) => EncryptedRecord.open(
        key: k,
        owner: owner,
        routeId: id,
        revision: rev,
        envelope: box,
      );
      await expectLater(
        read(other, 'owner', route, 4),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      await expectLater(
        read(key, 'another', route, 4),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      await expectLater(
        read(key, 'owner', route, 5),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      await expectLater(
        read(key, 'owner', '0' * 64, 4),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      await expectLater(read(key, 'owner', route, 0), throwsFormatException);
      await expectLater(
        EncryptedRecord.seal(
          key: key,
          owner: 'owner',
          entityType: 'notes',
          entityId: 'note',
          revision: 1,
          data: {'id': 'diferente'},
        ),
        throwsFormatException,
      );
    },
  );
}
