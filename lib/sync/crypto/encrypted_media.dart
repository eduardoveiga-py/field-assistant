import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as digest;
import 'package:cryptography/cryptography.dart';

import 'recovery_crypto.dart';

/// Protocolo experimental isolado, ainda não usado pelo Storage nem pela UI.
/// O manifesto só pode ser publicado depois de todos os blocos serem gravados.
/// O receptor deve gravar o stream em arquivo temporário e só substituir o
/// destino depois do stream terminar com sucesso (inclusive arquivo vazio).
/// Não protege contra replay de uma versão completa antiga do manifesto.
class EncryptedMedia {
  EncryptedMedia._();

  static const int chunkSize = 256 * 1024;
  static const int maxChunks = 4096;
  static const String _chunkKind = 'media-chunk-v1';
  static const String _manifestKind = 'media-manifest-v1';

  static String _chunkId(String mediaId, int index) =>
      jsonEncode([mediaId, index]);

  // Os campos e sua ordem são fixos; a reordenação de chaves JSON não muda o hash.
  static String _boxDigest(Map<String, dynamic> box) => digest.sha256
      .convert(
        utf8.encode(
          jsonEncode([
            box['v'],
            box['algorithm'],
            box['nonce'],
            box['ciphertext'],
            box['tag'],
          ]),
        ),
      )
      .toString();

  /// Grava blocos em ordem, com backpressure. Em caso de falha não retorna
  /// manifesto; o chamador deve tratar os blocos já gravados como órfãos.
  static Future<Map<String, Object>> encrypt({
    required SecretKey key,
    required String owner,
    required String mediaId,
    required Stream<List<int>> source,
    required Future<void> Function(int index, Map<String, Object> envelope)
    storeChunk,
  }) async {
    final buffer = Uint8List(chunkSize);
    var used = 0;
    var total = 0;
    final chunks = <Map<String, Object>>[];

    Future<void> flush() async {
      if (used == 0) return;
      if (chunks.length >= maxChunks) {
        throw const FormatException('Arquivo excede o limite de blocos.');
      }
      final bytes = Uint8List.fromList(buffer.sublist(0, used));
      final box = await RecoveryCrypto.seal(
        key: key,
        owner: owner,
        kind: _chunkKind,
        id: _chunkId(mediaId, chunks.length),
        plaintext: bytes,
      );
      final entry = <String, Object>{'length': used, 'digest': _boxDigest(box)};
      await storeChunk(chunks.length, box);
      chunks.add(entry);
      total += used;
      used = 0;
    }

    await for (final input in source) {
      if (input is! Uint8List && input.any((b) => b < 0 || b > 255)) {
        throw const FormatException('Bytes de mídia inválidos.');
      }
      var offset = 0;
      while (offset < input.length) {
        final available = chunkSize - used;
        final remaining = input.length - offset;
        final n = remaining < available ? remaining : available;
        buffer.setRange(used, used + n, input, offset);
        used += n;
        offset += n;
        if (used == chunkSize) await flush();
      }
    }
    await flush();
    final manifest = utf8.encode(
      jsonEncode({
        'version': 1,
        'chunkSize': chunkSize,
        'total': total,
        'chunks': chunks,
      }),
    );
    return RecoveryCrypto.seal(
      key: key,
      owner: owner,
      kind: _manifestKind,
      id: mediaId,
      plaintext: manifest,
    );
  }

  /// Autentica o manifesto cifrado e retorna a quantidade exata de blocos
  /// armazenados (usado para exclusão completa sem blocos órfãos em mídias > 4 MiB).
  static Future<int> inspectChunkCount({
    required SecretKey key,
    required String owner,
    required String mediaId,
    required Map<String, dynamic> manifestEnvelope,
  }) async {
    final raw = await RecoveryCrypto.open(
      key: key,
      owner: owner,
      kind: _manifestKind,
      id: mediaId,
      envelope: manifestEnvelope,
    );
    final manifest = jsonDecode(utf8.decode(raw));
    if (manifest is! Map ||
        manifest['version'] != 1 ||
        manifest['chunks'] is! List ||
        (manifest['chunks'] as List).length > maxChunks) {
      throw const FormatException('Manifesto de mídia inválido.');
    }
    return (manifest['chunks'] as List).length;
  }

  /// Os blocos são autenticados individualmente e vinculados ao manifesto.
  /// Uma falha posterior pode ocorrer após bytes já terem sido emitidos.
  static Stream<Uint8List> decrypt({
    required SecretKey key,
    required String owner,
    required String mediaId,
    required Map<String, dynamic> manifestEnvelope,
    required Future<Map<String, dynamic>> Function(int index) fetchChunk,
  }) async* {
    final raw = await RecoveryCrypto.open(
      key: key,
      owner: owner,
      kind: _manifestKind,
      id: mediaId,
      envelope: manifestEnvelope,
    );
    final manifest = jsonDecode(utf8.decode(raw));
    if (manifest is! Map ||
        manifest.length != 4 ||
        manifest['version'] != 1 ||
        manifest['chunkSize'] != chunkSize ||
        manifest['total'] is! int ||
        manifest['chunks'] is! List ||
        (manifest['chunks'] as List).length > maxChunks) {
      throw const FormatException('Manifesto de mídia inválido.');
    }
    final parts = manifest['chunks'] as List;
    final total = manifest['total'] as int;
    if (total < 0 ||
        total > chunkSize * maxChunks ||
        (total == 0 && parts.isNotEmpty) ||
        (total > 0 && parts.isEmpty)) {
      throw const FormatException('Tamanho de mídia inválido.');
    }
    var expectedTotal = 0;
    for (var i = 0; i < parts.length; i++) {
      final item = parts[i];
      if (item is! Map ||
          item.length != 2 ||
          item['length'] is! int ||
          item['digest'] is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(item['digest'] as String)) {
        throw const FormatException('Índice de mídia inválido.');
      }
      final length = item['length'] as int;
      if (length < 1 ||
          length > chunkSize ||
          (i < parts.length - 1 && length != chunkSize)) {
        throw const FormatException('Tamanho de bloco inválido.');
      }
      expectedTotal += length;
    }
    if (expectedTotal != total) {
      throw const FormatException('Comprimento de mídia inconsistente.');
    }
    for (var i = 0; i < parts.length; i++) {
      final item = parts[i] as Map;
      final box = await fetchChunk(i);
      final bytes = await RecoveryCrypto.open(
        key: key,
        owner: owner,
        kind: _chunkKind,
        id: _chunkId(mediaId, i),
        envelope: box,
      );
      if (bytes.length != item['length'] || _boxDigest(box) != item['digest']) {
        throw const FormatException(
          'Bloco de mídia não corresponde ao manifesto.',
        );
      }
      yield bytes;
    }
  }
}
