import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_media.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_media_transfer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockCloudStorage {
  final Map<String, Uint8List> objects = {};
  final Map<String, Map<String, String>> uploadHeaders = {};
  final List<String> deletedKeys = [];
  bool failUploadOnChunk = false;
  int failChunkIndex = -1;
  int currentChunkUploadCount = 0;
}

Uint8List _extractMultipartBytes(http.Request request) {
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

SupabaseClient _buildMockClient(_MockCloudStorage cloud) {
  final httpClient = MockClient((request) async {
    final path = request.url.path;
    const storagePrefix = '/storage/v1/object/';
    if (path.contains(storagePrefix)) {
      final objectKey = path.substring(
        path.indexOf(storagePrefix) + storagePrefix.length,
      );

      if (request.method == 'POST' || request.method == 'PUT') {
        if (cloud.failUploadOnChunk &&
            objectKey.contains('chunk_') &&
            cloud.currentChunkUploadCount == cloud.failChunkIndex) {
          cloud.currentChunkUploadCount++;
          return http.Response(
            'Simulated Network Error during chunk upload',
            500,
          );
        }
        if (objectKey.contains('chunk_')) {
          cloud.currentChunkUploadCount++;
        }

        final xUpsert = request.headers['x-upsert'] ?? 'false';
        cloud.uploadHeaders[objectKey] = {
          'x-upsert': xUpsert,
          'method': request.method,
        };
        cloud.objects[objectKey] = _extractMultipartBytes(request);
        return http.Response(
          jsonEncode({'Key': objectKey}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (request.method == 'GET') {
        final data = cloud.objects[objectKey];
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
          cloud.deletedKeys.add(fullKey);
          if (cloud.objects.remove(fullKey) != null) {
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
    'https://mock-test.supabase.co',
    'anon-test-key',
    httpClient: httpClient,
  );
}

void main() {
  const owner = 'user_adv_test_42';
  late SecretKey key;

  setUpAll(() async {
    final algorithm = AesGcm.with256bits();
    key = await algorithm.newSecretKey();
  });

  group('FA-SEC-03 & P1-01: EncryptedMediaTransfer Versioning & Atomicity', () {
    test('Cenário 1: Upload versionado gera namespaces isolados e chunks imutáveis (upsert: false)', () async {
      final cloud = _MockCloudStorage();
      final client = _buildMockClient(cloud);
      addTearDown(client.dispose);

      final transfer = EncryptedMediaTransfer(
        client: client,
        owner: owner,
        key: key,
      );

      final v1Bytes = Uint8List.fromList(
        utf8.encode('Conteudo da versao 1 do audio gravado'),
      );
      final manifestV1Path = await transfer.uploadEncrypted(
        bucket: 'voice_notes',
        mediaId: 'audio_session_1',
        plaintextBytes: v1Bytes,
        versionId: '1001',
      );

      expect(
        manifestV1Path,
        equals('$owner/e2ee/audio_session_1/v_1001/manifest.enc'),
      );

      // Verifica caminhos no mock storage
      final chunkKey =
          'voice_notes/$owner/e2ee/audio_session_1/v_1001/chunk_0.enc';
      final vManifestKey =
          'voice_notes/$owner/e2ee/audio_session_1/v_1001/manifest.enc';
      final rootManifestKey =
          'voice_notes/$owner/e2ee/audio_session_1/manifest.enc';

      expect(cloud.objects.containsKey(chunkKey), isTrue);
      expect(cloud.objects.containsKey(vManifestKey), isTrue);
      expect(cloud.objects.containsKey(rootManifestKey), isTrue);

      // Chunks e manifesto versionado devem ser gravados como imutáveis
      expect(cloud.uploadHeaders[chunkKey]?['x-upsert'], equals('false'));
      expect(cloud.uploadHeaders[vManifestKey]?['x-upsert'], equals('false'));

      // Ponteiro raiz de CAS pode ter upsert
      expect(cloud.uploadHeaders[rootManifestKey]?['x-upsert'], equals('true'));

      // Download da versao 1
      final downloadedV1 = await transfer.downloadDecrypted(
        bucket: 'voice_notes',
        mediaId: 'audio_session_1',
      );
      expect(
        utf8.decode(downloadedV1),
        equals('Conteudo da versao 1 do audio gravado'),
      );
    });

    test('Cenário 2: Upload de nova versão não corrompe a versão anterior e atualiza ponteiro de CAS', () async {
      final cloud = _MockCloudStorage();
      final client = _buildMockClient(cloud);
      addTearDown(client.dispose);

      final transfer = EncryptedMediaTransfer(
        client: client,
        owner: owner,
        key: key,
      );

      final v1Bytes = Uint8List.fromList(utf8.encode('Versao 1 anterior'));
      await transfer.uploadEncrypted(
        bucket: 'voice_notes',
        mediaId: 'audio_session_2',
        plaintextBytes: v1Bytes,
        versionId: 'v_old',
      );

      final v2Bytes = Uint8List.fromList(utf8.encode('Versao 2 atualizada'));
      await transfer.uploadEncrypted(
        bucket: 'voice_notes',
        mediaId: 'audio_session_2',
        plaintextBytes: v2Bytes,
        versionId: 'v_new',
      );

      // Ambos os chunks existem em namespaces distintos
      final chunkOldKey =
          'voice_notes/$owner/e2ee/audio_session_2/v_v_old/chunk_0.enc';
      final chunkNewKey =
          'voice_notes/$owner/e2ee/audio_session_2/v_v_new/chunk_0.enc';
      expect(cloud.objects.containsKey(chunkOldKey), isTrue);
      expect(cloud.objects.containsKey(chunkNewKey), isTrue);

      // Download explícito da versão antiga
      final readOld = await transfer.downloadDecrypted(
        bucket: 'voice_notes',
        mediaId: 'audio_session_2',
        versionId: 'v_old',
      );
      expect(utf8.decode(readOld), equals('Versao 1 anterior'));

      // Download da versão ativa mais recente via ponteiro de CAS
      final readActive = await transfer.downloadDecrypted(
        bucket: 'voice_notes',
        mediaId: 'audio_session_2',
      );
      expect(utf8.decode(readActive), equals('Versao 2 atualizada'));
    });

    test('Cenário 3: Falha durante upload de chunks executa rollback sem corromper a versão ativa anterior', () async {
      final cloud = _MockCloudStorage();
      final client = _buildMockClient(cloud);
      addTearDown(client.dispose);

      final transfer = EncryptedMediaTransfer(
        client: client,
        owner: owner,
        key: key,
      );

      // 1. Grava versão estável v1
      final v1Bytes = Uint8List.fromList(
        utf8.encode('Audio estavel pre-existente'),
      );
      await transfer.uploadEncrypted(
        bucket: 'voice_notes',
        mediaId: 'audio_session_3',
        plaintextBytes: v1Bytes,
        versionId: 'stable_v1',
      );

      // 2. Tenta gravar v2 com payload multi-chunk e simula erro de rede no chunk 1
      final bigPayload = Uint8List(EncryptedMedia.chunkSize * 2 + 500);
      for (var i = 0; i < bigPayload.length; i++) {
        bigPayload[i] = i % 255;
      }

      cloud.failUploadOnChunk = true;
      cloud.failChunkIndex = 1; // falha no segundo chunk
      cloud.currentChunkUploadCount = 0;

      await expectLater(
        () => transfer.uploadEncrypted(
          bucket: 'voice_notes',
          mediaId: 'audio_session_3',
          plaintextBytes: bigPayload,
          versionId: 'broken_v2',
        ),
        throwsA(anything),
      );

      // 3. Verifica que blocos órfãos de broken_v2 foram removidos no rollback
      final brokenChunk0 =
          'voice_notes/$owner/e2ee/audio_session_3/v_broken_v2/chunk_0.enc';
      expect(cloud.objects.containsKey(brokenChunk0), isFalse);

      // 4. A versão anterior stable_v1 permanece 100% íntegra e legível
      final recovered = await transfer.downloadDecrypted(
        bucket: 'voice_notes',
        mediaId: 'audio_session_3',
      );
      expect(utf8.decode(recovered), equals('Audio estavel pre-existente'));
    });

    test('Cenário 4: Purga segura da versão anterior ocorre apenas após confirmação do CAS', () async {
      final cloud = _MockCloudStorage();
      final client = _buildMockClient(cloud);
      addTearDown(client.dispose);

      final transfer = EncryptedMediaTransfer(
        client: client,
        owner: owner,
        key: key,
      );

      await transfer.uploadEncrypted(
        bucket: 'knowledge_vault',
        mediaId: 'doc_1',
        plaintextBytes: Uint8List.fromList(utf8.encode('Conteudo antigo')),
        versionId: 'rev_1',
      );

      final oldChunkKey =
          'knowledge_vault/$owner/e2ee/doc_1/v_rev_1/chunk_0.enc';
      expect(cloud.objects.containsKey(oldChunkKey), isTrue);

      // Faz upload de rev_2 solicitando purga de rev_1
      await transfer.uploadEncrypted(
        bucket: 'knowledge_vault',
        mediaId: 'doc_1',
        plaintextBytes: Uint8List.fromList(
          utf8.encode('Conteudo novo atualizado'),
        ),
        versionId: 'rev_2',
        previousVersionId: 'rev_1',
      );

      // rev_1 foi purgado
      expect(cloud.objects.containsKey(oldChunkKey), isFalse);

      // rev_2 está ativo
      final current = await transfer.downloadDecrypted(
        bucket: 'knowledge_vault',
        mediaId: 'doc_1',
      );
      expect(utf8.decode(current), equals('Conteudo novo atualizado'));
    });

    test('Cenário 5: Retrocompatibilidade transparente com manifestos e blocos legados não-versionados', () async {
      final cloud = _MockCloudStorage();
      final client = _buildMockClient(cloud);
      addTearDown(client.dispose);

      final transfer = EncryptedMediaTransfer(
        client: client,
        owner: owner,
        key: key,
      );

      // Upload sem versionId (legado)
      final legacyBytes = Uint8List.fromList(
        utf8.encode('Audio legado em namespace plano'),
      );
      await transfer.uploadEncrypted(
        bucket: 'person_photos',
        mediaId: 'photo_legacy',
        plaintextBytes: legacyBytes,
      );

      final legacyChunkKey =
          'person_photos/$owner/e2ee/photo_legacy/chunk_0.enc';
      final legacyManifestKey =
          'person_photos/$owner/e2ee/photo_legacy/manifest.enc';
      expect(cloud.objects.containsKey(legacyChunkKey), isTrue);
      expect(cloud.objects.containsKey(legacyManifestKey), isTrue);

      // Download transparente
      final downloaded = await transfer.downloadDecrypted(
        bucket: 'person_photos',
        mediaId: 'photo_legacy',
      );
      expect(
        utf8.decode(downloaded),
        equals('Audio legado em namespace plano'),
      );

      // Exclusão completa
      await transfer.deleteEncrypted(
        bucket: 'person_photos',
        mediaId: 'photo_legacy',
      );
      expect(cloud.objects, isEmpty);
    });
  });
}
