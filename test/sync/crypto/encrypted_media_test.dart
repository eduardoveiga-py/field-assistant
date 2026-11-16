import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_media.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_crypto.dart';

void main() {
  test('mídia dividida em blocos é autenticada e recuperada em ordem', () async {
    final key = await RecoveryCrypto.keyFromPhrase(RecoveryCrypto.createPhrase());
    final bytes = Uint8List.fromList(List.generate(EncryptedMedia.chunkSize * 2 + 17, (i) => i % 251));
    final chunks = <Map<String, Object>>[];
    final manifest = await EncryptedMedia.encrypt(
      key: key, owner: 'dono', mediaId: 'foto',
      source: Stream.fromIterable([bytes.sublist(0, 3), bytes.sublist(3)]),
      storeChunk: (i, box) async { expect(i, chunks.length); chunks.add(box); },
    );
    expect(chunks, hasLength(3));
    final restored = <int>[];
    await for (final block in EncryptedMedia.decrypt(
      key: key, owner: 'dono', mediaId: 'foto', manifestEnvelope: manifest,
      fetchChunk: (i) async => chunks[i],
    )) { restored.addAll(block); }
    expect(restored, bytes);
  });

  test('manifesto não aceita blocos removidos, trocados ou de outra versão', () async {
    final key = await RecoveryCrypto.keyFromPhrase(RecoveryCrypto.createPhrase());
    final bytes = Uint8List(EncryptedMedia.chunkSize + 1);
    Future<(Map<String, Object>, List<Map<String, Object>>)> encrypt() async {
      final chunks = <Map<String, Object>>[];
      final manifest = await EncryptedMedia.encrypt(key: key, owner: 'dono', mediaId: 'id',
        source: Stream.value(bytes), storeChunk: (i, box) async => chunks.add(box));
      return (manifest, chunks);
    }
    final (manifest, chunks) = await encrypt();
    final (_, newerChunks) = await encrypt();
    Future<List<Uint8List>> read(Future<Map<String, dynamic>> Function(int) fetch) =>
        EncryptedMedia.decrypt(key: key, owner: 'dono', mediaId: 'id',
          manifestEnvelope: manifest, fetchChunk: fetch).toList();
    await expectLater(read((i) async => chunks[1 - i]), throwsA(isA<SecretBoxAuthenticationError>()));
    await expectLater(read((i) async => newerChunks[i]), throwsA(isA<FormatException>()));
    await expectLater(read((i) async { if (i == 1) throw StateError('ausente'); return chunks[i]; }),
        throwsStateError);
    await expectLater(EncryptedMedia.decrypt(key: key, owner: 'outro', mediaId: 'id',
      manifestEnvelope: manifest, fetchChunk: (i) async => chunks[i]).toList(), throwsA(isA<SecretBoxAuthenticationError>()));
  });

  test('arquivo vazio e falha de gravação não produzem falso sucesso', () async {
    final key = await RecoveryCrypto.keyFromPhrase(RecoveryCrypto.createPhrase());
    final empty = await EncryptedMedia.encrypt(key: key, owner: 'dono', mediaId: 'id',
      source: const Stream<List<int>>.empty(), storeChunk: (i, box) async => fail('sem blocos'));
    expect(await EncryptedMedia.decrypt(key: key, owner: 'dono', mediaId: 'id',
      manifestEnvelope: empty, fetchChunk: (i) async => throw StateError('sem blocos')).toList(), isEmpty);
    await expectLater(EncryptedMedia.encrypt(key: key, owner: 'dono', mediaId: 'id',
      source: Stream.value([1, 2, 3]), storeChunk: (i, box) async => throw StateError('falha')),
      throwsStateError);
  });
}
