import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_media.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_media_transfer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockStorageBackend {
  final Map<String, Uint8List> objects = {};
  final Map<String, Map<String, String>> uploadHeaders = {};
  final List<String> deletedKeys = [];
  bool failUploadOnChunk = false;
  int failChunkIndex = -1;
  int currentChunkUploadCount = 0;
}

Uint8List _extractMultipart(http.Request request) {
  final raw = request.bodyBytes;
  final contentType = request.headers['content-type'] ?? '';
  if (!contentType.contains('multipart/form-data')) {
    return Uint8List.fromList(raw);
  }
  final boundaryMatch = RegExp(r'boundary=([^\s;]+)').firstMatch(contentType);
  if (boundaryMatch == null) return Uint8List.fromList(raw);
  final boundary = '--${boundaryMatch.group(1)}';
  final text = utf8.decode(raw, allowMalformed: true);
  for (final part in text.split(boundary)) {
    final sep = part.indexOf('\r\n\r\n');
    if (sep == -1) continue;
    final headers = part.substring(0, sep);
    if (!headers.contains('filename=') &&
        !headers.contains('application/octet-stream')) {
      continue;
    }
    var body = part.substring(sep + 4);
    if (body.endsWith('\r\n')) {
      body = body.substring(0, body.length - 2);
    }
    return Uint8List.fromList(utf8.encode(body));
  }
  return Uint8List.fromList(raw);
}

SupabaseClient _createMockClient(_MockStorageBackend backend) {
  final httpClient = MockClient((request) async {
    final path = request.url.path;
    const storagePrefix = '/storage/v1/object/';
    if (path.contains(storagePrefix)) {
      final objectKey = path.substring(
        path.indexOf(storagePrefix) + storagePrefix.length,
      );

      if (request.method == 'POST' || request.method == 'PUT') {
        if (backend.failUploadOnChunk &&
            objectKey.contains('chunk_') &&
            backend.currentChunkUploadCount == backend.failChunkIndex) {
          backend.currentChunkUploadCount++;
          return http.Response('Simulated Chunk Network Failure', 500);
        }
        if (objectKey.contains('chunk_')) {
          backend.currentChunkUploadCount++;
        }

        final xUpsert = request.headers['x-upsert'] ?? 'false';
        backend.uploadHeaders[objectKey] = {
          'x-upsert': xUpsert,
          'method': request.method,
        };
        backend.objects[objectKey] = _extractMultipart(request);
        return http.Response(
          jsonEncode({'Key': objectKey}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (request.method == 'GET') {
        final data = backend.objects[objectKey];
        if (data == null) {
          return http.Response('Object Not Found: $objectKey', 404);
        }
        return http.Response.bytes(data, 200);
      }

      if (request.method == 'DELETE') {
        final bucket = objectKey.split('/').first;
        final decoded = jsonDecode(request.body) as Map<String, dynamic>;
        final prefixes = (decoded['prefixes'] as List).cast<String>();
        final removed = <Map<String, dynamic>>[];
        for (final pref in prefixes) {
          final fullKey = '$bucket/$pref';
          backend.deletedKeys.add(fullKey);
          if (backend.objects.remove(fullKey) != null) {
            removed.add({'name': pref});
          }
        }
        return http.Response(
          jsonEncode(removed),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
    }

    return http.Response('Not Found', 404);
  });

  return SupabaseClient(
    'https://immutable-test.supabase.co',
    'anon-test-key',
    httpClient: httpClient,
  );
}

void main() {
  const testOwner = 'user_audit_immutable_77';
  late SecretKey key;

  setUpAll(() async {
    final algorithm = AesGcm.with256bits();
    key = await algorithm.newSecretKey();
  });

  group('Milestone M2: Immutable Media Versioning & Atomic Commit Protocol', () {
    test('a) Upload com versionamento imutável e caminhos corretos (\$owner/e2ee/\$mediaId/v_\$versionId/)', () async {
      final backend = _MockStorageBackend();
      final client = _createMockClient(backend);
      addTearDown(client.dispose);

      final transfer = EncryptedMediaTransfer(
        client: client,
        owner: testOwner,
        key: key,
      );

      final payload = Uint8List.fromList(
        utf8.encode(
          'Conteudo binario autenticado v1 - Nota de voz ministerial',
        ),
      );
      const mediaId = 'media_vn_001';
      const versionId = '20261118_v1';

      final manifestPath = await transfer.uploadEncrypted(
        bucket: 'voice_notes',
        mediaId: mediaId,
        plaintextBytes: payload,
        versionId: versionId,
      );

      // Validação dos caminhos imutáveis
      final expectedVersionManifest =
          '$testOwner/e2ee/$mediaId/v_$versionId/manifest.enc';
      final expectedChunk0 =
          'voice_notes/$testOwner/e2ee/$mediaId/v_$versionId/chunk_0.enc';
      final expectedRootManifest =
          'voice_notes/$testOwner/e2ee/$mediaId/manifest.enc';

      expect(manifestPath, equals(expectedVersionManifest));
      expect(backend.objects.containsKey(expectedChunk0), isTrue);
      expect(
        backend.objects.containsKey('voice_notes/$expectedVersionManifest'),
        isTrue,
      );
      expect(backend.objects.containsKey(expectedRootManifest), isTrue);

      // Validação de imutabilidade: chunks e versioned manifest NUNCA usam upsert
      expect(
        backend.uploadHeaders[expectedChunk0]?['x-upsert'],
        equals('false'),
      );
      expect(
        backend
            .uploadHeaders['voice_notes/$expectedVersionManifest']?['x-upsert'],
        equals('false'),
      );

      // Download e integridade dos bytes decifrados
      final downloaded = await transfer.downloadDecrypted(
        bucket: 'voice_notes',
        mediaId: mediaId,
      );
      expect(downloaded, equals(payload));
    });

    test('b) Falha simulada durante o upload de versão 2 preservando 100% dos dados da versão 1', () async {
      final backend = _MockStorageBackend();
      final client = _createMockClient(backend);
      addTearDown(client.dispose);

      final transfer = EncryptedMediaTransfer(
        client: client,
        owner: testOwner,
        key: key,
      );

      const mediaId = 'media_vn_resilience_002';

      // 1. Grava Versão 1 estável
      final v1Bytes = Uint8List.fromList(
        utf8.encode('Versao 1 estavel de referencia preservada intacta'),
      );
      await transfer.uploadEncrypted(
        bucket: 'voice_notes',
        mediaId: mediaId,
        plaintextBytes: v1Bytes,
        versionId: 'ver_1',
      );

      final v1ChunkKey =
          'voice_notes/$testOwner/e2ee/$mediaId/v_ver_1/chunk_0.enc';
      expect(backend.objects.containsKey(v1ChunkKey), isTrue);

      // 2. Prepara Versão 2 multi-chunk (> 256 KiB)
      final v2LargeBytes = Uint8List(EncryptedMedia.chunkSize * 2 + 1024);
      for (var i = 0; i < v2LargeBytes.length; i++) {
        v2LargeBytes[i] = (i * 7) % 256;
      }

      // Simula falha na rede no segundo chunk da versão 2
      backend.failUploadOnChunk = true;
      backend.failChunkIndex = 1;
      backend.currentChunkUploadCount = 0;

      // Executa upload da versão 2 e espera falha
      await expectLater(
        () => transfer.uploadEncrypted(
          bucket: 'voice_notes',
          mediaId: mediaId,
          plaintextBytes: v2LargeBytes,
          versionId: 'ver_2_failing',
        ),
        throwsA(anything),
      );

      // 3. Rollback de integridade: Chunks órfãos de ver_2_failing devem ser removidos
      final v2OrphanChunk0 =
          'voice_notes/$testOwner/e2ee/$mediaId/v_ver_2_failing/chunk_0.enc';
      expect(backend.objects.containsKey(v2OrphanChunk0), isFalse);

      // 4. Invariante Atômico: Versão 1 permanece 100% intacta e legível
      expect(backend.objects.containsKey(v1ChunkKey), isTrue);
      final activeBytes = await transfer.downloadDecrypted(
        bucket: 'voice_notes',
        mediaId: mediaId,
      );
      expect(activeBytes, equals(v1Bytes));
    });

    test('c) Verificação de integridade de hashes e manifesto fail-closed sob adulteração', () async {
      final backend = _MockStorageBackend();
      final client = _createMockClient(backend);
      addTearDown(client.dispose);

      final transfer = EncryptedMediaTransfer(
        client: client,
        owner: testOwner,
        key: key,
      );

      const mediaId = 'media_tamper_audit';
      final originalBytes = Uint8List.fromList(
        utf8.encode(
          'Arquivo altamente confidencial com protecao criptografica',
        ),
      );

      await transfer.uploadEncrypted(
        bucket: 'knowledge_vault',
        mediaId: mediaId,
        plaintextBytes: originalBytes,
        versionId: 'tamper_v1',
      );

      final chunkKey =
          'knowledge_vault/$testOwner/e2ee/$mediaId/v_tamper_v1/chunk_0.enc';
      expect(backend.objects.containsKey(chunkKey), isTrue);

      // Adulteração intencional de 1 byte no bloco cifrado (ataque de corrupção/adulteração)
      final rawEnvelope = backend.objects[chunkKey]!;
      final decodedEnvelope =
          jsonDecode(utf8.decode(rawEnvelope)) as Map<String, dynamic>;
      final originalCiphertext = decodedEnvelope['ciphertext'] as String;
      // Inverte o último caractere do ciphertext
      final tamperedCiphertext =
          originalCiphertext.substring(0, originalCiphertext.length - 1) +
          (originalCiphertext.endsWith('A') ? 'B' : 'A');
      decodedEnvelope['ciphertext'] = tamperedCiphertext;
      backend.objects[chunkKey] = Uint8List.fromList(
        utf8.encode(jsonEncode(decodedEnvelope)),
      );

      // Leitura DEVE falhar fail-closed por detecção de inconsistência de digest ou MAC
      await expectLater(
        () => transfer.downloadDecrypted(
          bucket: 'knowledge_vault',
          mediaId: mediaId,
        ),
        throwsA(
          anyOf(isA<FormatException>(), isA<SecretBoxAuthenticationError>()),
        ),
      );
    });

    test('d) Transição atômica e expurgo controlado da versão obsoleta (purgeObsoleteVersion)', () async {
      final backend = _MockStorageBackend();
      final client = _createMockClient(backend);
      addTearDown(client.dispose);

      final transfer = EncryptedMediaTransfer(
        client: client,
        owner: testOwner,
        key: key,
      );

      const mediaId = 'media_purge_audit';

      // 1. Upload Versão 1
      final v1Bytes = Uint8List.fromList(utf8.encode('Foto antiga v1'));
      await transfer.uploadEncrypted(
        bucket: 'person_photos',
        mediaId: mediaId,
        plaintextBytes: v1Bytes,
        versionId: 'photo_v1',
      );
      final v1ChunkKey =
          'person_photos/$testOwner/e2ee/$mediaId/v_photo_v1/chunk_0.enc';
      expect(backend.objects.containsKey(v1ChunkKey), isTrue);

      // 2. Upload Versão 2 (ambas coexistem durante o processo de migração)
      final v2Bytes = Uint8List.fromList(utf8.encode('Foto atualizada v2'));
      await transfer.uploadEncrypted(
        bucket: 'person_photos',
        mediaId: mediaId,
        plaintextBytes: v2Bytes,
        versionId: 'photo_v2',
      );
      final v2ChunkKey =
          'person_photos/$testOwner/e2ee/$mediaId/v_photo_v2/chunk_0.enc';
      expect(backend.objects.containsKey(v1ChunkKey), isTrue);
      expect(backend.objects.containsKey(v2ChunkKey), isTrue);

      // 3. Expurgo pós-confirmação seguro de photo_v1
      await transfer.purgeObsoleteVersion(
        bucket: 'person_photos',
        mediaId: mediaId,
        versionId: 'photo_v1',
      );

      // Blocos da versão v1 foram excluídos do Storage
      expect(backend.objects.containsKey(v1ChunkKey), isFalse);

      // Versão 2 permanece ativa, íntegra e legível
      expect(backend.objects.containsKey(v2ChunkKey), isTrue);
      final currentBytes = await transfer.downloadDecrypted(
        bucket: 'person_photos',
        mediaId: mediaId,
      );
      expect(currentBytes, equals(v2Bytes));
    });

    test('e) Rollback CAS seguro (rollbackToVersion) descarta nova versão e restaura ponteiro raiz anterior', () async {
      final backend = _MockStorageBackend();
      final client = _createMockClient(backend);
      addTearDown(client.dispose);

      final transfer = EncryptedMediaTransfer(
        client: client,
        owner: testOwner,
        key: key,
      );

      const mediaId = 'media_cas_conflict_audit';

      // 1. Versão inicial ativa
      final vInitial = Uint8List.fromList(utf8.encode('Audio Ticuna Ativo v1'));
      await transfer.uploadEncrypted(
        bucket: 'ticuna_audio',
        mediaId: mediaId,
        plaintextBytes: vInitial,
        versionId: 'initial_v1',
      );

      final vInitialChunkKey =
          'ticuna_audio/$testOwner/e2ee/$mediaId/v_initial_v1/chunk_0.enc';
      expect(backend.objects.containsKey(vInitialChunkKey), isTrue);

      // 2. Nova versão enviada ao Storage
      final vRejected = Uint8List.fromList(
        utf8.encode('Tentativa rejeitada v2'),
      );
      await transfer.uploadEncrypted(
        bucket: 'ticuna_audio',
        mediaId: mediaId,
        plaintextBytes: vRejected,
        versionId: 'rejected_v2',
      );
      final vRejectedChunkKey =
          'ticuna_audio/$testOwner/e2ee/$mediaId/v_rejected_v2/chunk_0.enc';
      expect(backend.objects.containsKey(vRejectedChunkKey), isTrue);

      // 3. Ocorre conflito de CAS no banco de dados -> Aciona rollbackToVersion
      await transfer.rollbackToVersion(
        bucket: 'ticuna_audio',
        mediaId: mediaId,
        rejectedVersionId: 'rejected_v2',
        previousVersionId: 'initial_v1',
      );

      // Chunks e manifesto da versão rejeitada foram descartados
      expect(backend.objects.containsKey(vRejectedChunkKey), isFalse);

      // Versão inicial e ponteiro raiz permanecem válidos e restaurados
      expect(backend.objects.containsKey(vInitialChunkKey), isTrue);
      final restored = await transfer.downloadDecrypted(
        bucket: 'ticuna_audio',
        mediaId: mediaId,
      );
      expect(restored, equals(vInitial));
    });
  });
}
