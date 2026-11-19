import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/sync/crypto/e2ee_service.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_crypto.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_media_transfer.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_record_sync.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_key_store.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_vault_transport.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

// Test helper: keep the phrase before initiating the create-only request.
Future<String> _createTestVault(E2eeService service, String owner) async {
  final phrase = RecoveryCrypto.createPhrase();
  await service.setupVaultWithPhrase(owner, phrase);
  return phrase;
}


class _WireSpyCloud {
  final Map<String, Map<String, dynamic>> vaults = {};
  final Map<String, EncryptedRemoteRecord> records = {};
  final Map<String, Uint8List> storageObjects = {};
  final List<String> httpRequestLog = [];
  int _seq = 0;
  bool failNextCas = false;

  int nextSeq() => ++_seq;
}

class _SpyVaultTransport implements RecoveryVaultTransport {
  final _WireSpyCloud cloud;
  final String owner;
  _SpyVaultTransport(this.cloud, this.owner);

  @override
  Future<Map<String, dynamic>?> fetch() async => cloud.vaults[owner];

  @override
  Future<bool> createIfAbsent(Map<String, dynamic> proposed) async {
    if (cloud.vaults.containsKey(owner)) return false;
    cloud.vaults[owner] = Map<String, dynamic>.from(proposed);
    return true;
  }
}

class _SpyRecordTransport implements PaginatedEncryptedRecordTransport {
  final _WireSpyCloud cloud;
  _SpyRecordTransport(this.cloud);

  @override
  Future<EncryptedRemoteRecord?> fetch(String route) async =>
      cloud.records[route];

  @override
  Future<EncryptedWriteResult> compareAndSwap({
    required String route,
    required int expectedRevision,
    required Map<String, dynamic> envelope,
  }) async {
    if (cloud.failNextCas) {
      cloud.failNextCas = false;
      throw StateError('Falha simulada no transporte E2EE');
    }
    final existing = cloud.records[route];
    if ((existing?.revision ?? 0) != expectedRevision) {
      return EncryptedWriteResult(success: false, revision: existing?.revision);
    }
    final rev = expectedRevision + 1;
    final seq = cloud.nextSeq();
    cloud.records[route] = EncryptedRemoteRecord(
      route: route,
      revision: rev,
      serverSeq: seq,
      envelope: Map<String, dynamic>.from(envelope),
    );
    return EncryptedWriteResult(success: true, revision: rev, serverSeq: seq);
  }

  @override
  Future<List<EncryptedRemoteRecord>> pullSince({
    required int sinceSeq,
    int limit = 100,
  }) async {
    final rows =
        cloud.records.values.where((r) => r.serverSeq > sinceSeq).toList()
          ..sort((a, b) => a.serverSeq.compareTo(b.serverSeq));
    return rows.take(limit).toList();
  }
}

Uint8List _extractMultipartOrRawBody(http.Request request) {
  final raw = request.bodyBytes;
  final contentType = request.headers['content-type'] ?? '';
  if (!contentType.contains('multipart/form-data')) {
    return Uint8List.fromList(raw);
  }
  final boundaryMatch = RegExp(r'boundary=([^\s;]+)').firstMatch(contentType);
  if (boundaryMatch == null) return Uint8List.fromList(raw);
  final boundary = '--${boundaryMatch.group(1)}';
  final text = utf8.decode(raw, allowMalformed: true);
  final parts = text.split(boundary);
  for (final part in parts) {
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

SupabaseClient _buildSpySupabaseClient(_WireSpyCloud cloud) {
  final httpClient = MockClient((request) async {
    final path = request.url.path;
    cloud.httpRequestLog.add('${request.method} $path');

    // Simula Supabase Storage para os 4 buckets criptografados
    final storagePrefix = '/storage/v1/object/';
    if (path.contains(storagePrefix)) {
      final objectKey = path.substring(
        path.indexOf(storagePrefix) + storagePrefix.length,
      );
      if (request.method == 'POST' || request.method == 'PUT') {
        cloud.storageObjects[objectKey] = _extractMultipartOrRawBody(request);
        return http.Response(
          jsonEncode({'Key': objectKey}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'GET') {
        final data = cloud.storageObjects[objectKey];
        if (data == null) return http.Response('Not found', 404);
        return http.Response.bytes(data, 200);
      }
    }

    // Qualquer chamada a PostgREST plaintext (sync_upsert_if_unchanged ou tabelas)
    // DEVE falhar explicitamente se alcançada pelo modo E2EE.
    fail(
      'Chamada PostgREST plaintext inesperada no modo E2EE: ${request.method} $path',
    );
  });

  return SupabaseClient(
    'https://mock.supabase.co',
    'mock-anon-key',
    httpClient: httpClient,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('FA-SEC-01/02/03 & FA-TEST-01: Fluxo E2EE real ponta a ponta (zero plaintext)', () {
    const testOwner = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      RecoveryKeyStore.resetForTesting();
    });

    test('Push, Pull paginado (server_seq), Tombstone DELETE, Inbox E-mail e Mídia cifrada entre 2 dispositivos com ZERO plaintext no wire', () async {
      final cloud = _WireSpyCloud();
      final client = _buildSpySupabaseClient(cloud);
      final dir1 = await Directory.systemTemp.createTemp('e2ee_dev1_');
      final dir2 = await Directory.systemTemp.createTemp('e2ee_dev2_');
      final db1 = AppDatabase.forTesting(NativeDatabase.memory());
      final repo1 = AppRepository(db1);
      final db2 = AppDatabase.forTesting(NativeDatabase.memory());
      final repo2 = AppRepository(db2);

      addTearDown(() async {
        await db1.close();
        await db2.close();
        client.dispose();
        if (await dir1.exists()) await dir1.delete(recursive: true);
        if (await dir2.exists()) await dir2.delete(recursive: true);
      });

      final e2ee1 = E2eeService(
        db: db1,
        keyStore: RecoveryKeyStore(),
        vaultTransportOverride: _SpyVaultTransport(cloud, testOwner),
        recordTransportOverride: _SpyRecordTransport(cloud),
      );
      final phrase = await _createTestVault(e2ee1, testOwner);

      final sync1 = SupabaseSyncService(
        db: db1,
        repository: repo1,
        clientOverride: client,
        e2eeServiceOverride: e2ee1,
        documentsDirectoryProvider: () async => dir1.path,
        allowEncryptedSyncForTesting: true,
        authenticatedOwnerOverrideForTesting: testOwner,
      );
      addTearDown(sync1.dispose);

      // 1. Dispositivo 1 cria Pessoa, E-mail JW na Inbox e Nota de Voz com áudio real
      final person = await repo1.createPerson(
        name: 'João Confidencial',
        phone: '+5592999998888',
        address: 'Rua Secreta 42',
      );
      final nowUtc = DateTime.now().toUtc();
      await db1
          .into(db1.inboxEntries)
          .insert(
            InboxEntriesCompanion.insert(
              id: 'email_jw_1',
              content: 'Carta JW Confidencial — corpo privado não pode vazar em texto claro',
              sourceType: const drift.Value('jw_email'),
              capturedAt: nowUtc,
              createdAt: nowUtc,
              updatedAt: nowUtc,
            ),
          );
      await db1
          .into(db1.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: 'sq_email_jw_1',
              entityType: 'inbox_entries',
              entityId: 'email_jw_1',
              operation: 'INSERT',
              payload: jsonEncode({
                'id': 'email_jw_1',
                'content': 'Carta JW Confidencial — corpo privado não pode vazar em texto claro',
                'sourceType': 'jw_email',
                'capturedAt': nowUtc.toIso8601String(),
                'createdAt': nowUtc.toIso8601String(),
                'updatedAt': nowUtc.toIso8601String(),
              }),
              createdAt: nowUtc,
            ),
          );

      final audioSecretBytes = Uint8List.fromList(
        utf8.encode('RAW_VOICE_NOTE_SECRET_AUDIO_BYTES_12345'),
      );
      final audioFile = File(p.join(dir1.path, 'vn_e2ee_1.m4a'));
      await audioFile.writeAsBytes(audioSecretBytes);
      await db1
          .into(db1.voiceNotes)
          .insert(
            VoiceNotesCompanion.insert(
              id: 'vn_e2ee_1',
              personId: person.id,
              audioFilePath: drift.Value(audioFile.path),
              audioDurationSeconds: const drift.Value(12),
              transcription: 'Transcrição confidencial do campo',
              createdAt: nowUtc,
              updatedAt: nowUtc,
            ),
          );
      await db1
          .into(db1.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: 'sq_vn_e2ee_1',
              entityType: 'voice_notes',
              entityId: 'vn_e2ee_1',
              operation: 'INSERT',
              payload: jsonEncode({'id': 'vn_e2ee_1'}),
              createdAt: nowUtc,
            ),
          );

      // 2. Push real E2EE no Dispositivo 1
      final pushRes = await sync1.processQueue();
      expect(pushRes.failureCount, 0, reason: pushRes.errors.join('; '));
      expect(pushRes.successCount, greaterThanOrEqualTo(3));
      expect(cloud.records.length, greaterThanOrEqualTo(3));

      // 3. PROVA CRIPTOGRÁFICA NO WIRE: zero texto claro nos envelopes e no Storage!
      final wireRecordsDump = jsonEncode(
        cloud.records.values.map((r) => r.envelope).toList(),
      );
      expect(wireRecordsDump, isNot(contains('João Confidencial')));
      expect(wireRecordsDump, isNot(contains('Rua Secreta 42')));
      expect(wireRecordsDump, isNot(contains('Carta JW Confidencial')));
      expect(wireRecordsDump, isNot(contains('Transcrição confidencial')));
      expect(
        cloud.httpRequestLog.where(
          (l) => l.contains('sync_upsert_if_unchanged'),
        ),
        isEmpty,
      );

      // Verifica Storage criptografado (manifest + chunk versionado, zero bytes em claro)
      expect(
        cloud.storageObjects.keys,
        contains('voice_notes/$testOwner/e2ee/vn_e2ee_1/manifest.enc'),
      );
      expect(
        cloud.storageObjects.keys.any(
          (k) =>
              k.startsWith('voice_notes/$testOwner/e2ee/vn_e2ee_1/') &&
              k.endsWith('chunk_0.enc'),
        ),
        isTrue,
      );
      for (final rawObj in cloud.storageObjects.values) {
        final asText = utf8.decode(rawObj, allowMalformed: true);
        expect(
          asText,
          isNot(contains('RAW_VOICE_NOTE_SECRET_AUDIO_BYTES_12345')),
        );
      }

      // 4. Dispositivo 2 restaura cofre com a frase e faz PULL paginado (server_seq)
      FlutterSecureStorage.setMockInitialValues({});
      final e2ee2 = E2eeService(
        db: db2,
        keyStore: RecoveryKeyStore(),
        vaultTransportOverride: _SpyVaultTransport(cloud, testOwner),
        recordTransportOverride: _SpyRecordTransport(cloud),
      );
      expect(await e2ee2.restoreVault(testOwner, phrase), isTrue);

      final sync2 = SupabaseSyncService(
        db: db2,
        repository: repo2,
        clientOverride: client,
        e2eeServiceOverride: e2ee2,
        documentsDirectoryProvider: () async => dir2.path,
        allowEncryptedSyncForTesting: true,
        authenticatedOwnerOverrideForTesting: testOwner,
      );
      addTearDown(sync2.dispose);

      final pullRes = await sync2.fetchRemoteChanges();
      expect(pullRes.failureCount, 0, reason: pullRes.errors.join('; '));
      expect(pullRes.successCount, greaterThanOrEqualTo(3));

      final dev2People = await repo2.getAllPeople();
      expect(dev2People.single.name, 'João Confidencial');

      final dev2Inbox = await db2.select(db2.inboxEntries).get();
      expect(dev2Inbox.single.content, contains('Carta JW Confidencial'));

      // Áudio descriptografado e salvo atomicamente no Dispositivo 2!
      final dev2VoiceNote = await (db2.select(
        db2.voiceNotes,
      )..where((t) => t.id.equals('vn_e2ee_1'))).getSingle();
      expect(dev2VoiceNote.audioFilePath, isNotNull);
      expect(
        await File(dev2VoiceNote.audioFilePath!).readAsBytes(),
        equals(audioSecretBytes),
      );

      // 5. Sincronização de DELETE (Tombstone cifrado): Dispositivo 1 exclui -> Dispositivo 2 recebe soft-delete
      // Reinstala chave do Dispositivo 1 (setMockInitialValues anterior limpou storage global mock)
      await e2ee1.restoreVault(testOwner, phrase);
      await repo1.deletePerson(person.id);
      final delPush = await sync1.processQueue();
      expect(delPush.failureCount, 0, reason: delPush.errors.join('; '));
      expect(delPush.successCount, 1);

      final delPull = await sync2.fetchRemoteChanges();
      expect(delPull.failureCount, 0, reason: delPull.errors.join('; '));
      final deletedCheck = await (db2.select(
        db2.people,
      )..where((t) => t.id.equals(person.id))).getSingle();
      expect(deletedCheck.deletedAt, isNotNull);
    });

    test('Falha no transporte E2EE aborta fail-closed sem fallback para plaintext e preserva outbox', () async {
      final cloud = _WireSpyCloud()..failNextCas = true;
      final client = _buildSpySupabaseClient(cloud);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = AppRepository(db);
      addTearDown(() async {
        await db.close();
        client.dispose();
      });

      final e2ee = E2eeService(
        db: db,
        keyStore: RecoveryKeyStore(),
        vaultTransportOverride: _SpyVaultTransport(cloud, testOwner),
        recordTransportOverride: _SpyRecordTransport(cloud),
      );
      await _createTestVault(e2ee, testOwner);

      final sync = SupabaseSyncService(
        db: db,
        repository: repo,
        clientOverride: client,
        e2eeServiceOverride: e2ee,
        allowEncryptedSyncForTesting: true,
        authenticatedOwnerOverrideForTesting: testOwner,
      );
      addTearDown(sync.dispose);

      await repo.createPerson(name: 'Nunca Deve Vazar Plaintext');
      final res = await sync.processQueue();

      expect(res.failureCount, 1);
      expect(res.successCount, 0);
      expect(cloud.records, isEmpty);
      expect(cloud.httpRequestLog, isEmpty);
      expect(await repo.getUnresolvedSyncOperations(), isNotEmpty);
    });

    test('Gate padrão de produção (FAES 6.7) bloqueia sync remoto sem ENABLE_E2EE_SYNC', () async {
      final cloud = _WireSpyCloud();
      final client = _buildSpySupabaseClient(cloud);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = AppRepository(db);
      addTearDown(() async {
        await db.close();
        client.dispose();
      });

      final e2ee = E2eeService(
        db: db,
        keyStore: RecoveryKeyStore(),
        vaultTransportOverride: _SpyVaultTransport(cloud, testOwner),
        recordTransportOverride: _SpyRecordTransport(cloud),
      );
      await _createTestVault(e2ee, testOwner);

      final sync = SupabaseSyncService(
        db: db,
        repository: repo,
        clientOverride: client,
        e2eeServiceOverride: e2ee,
        authenticatedOwnerOverrideForTesting: testOwner,
        // allowEncryptedSyncForTesting == false (padrão de produção)
      );
      addTearDown(sync.dispose);

      await repo.createPerson(name: 'Offline Local Seguro');
      final res = await sync.sync();
      expect(res.success, isFalse);
      expect(cloud.records, isEmpty);
      expect(cloud.httpRequestLog, isEmpty);
      expect((await repo.getAllPeople()).length, 1);
    });

    test('EncryptedMediaTransfer protege os 4 buckets Storage (AES-256-GCM) e detecta adulteração', () async {
      final cloud = _WireSpyCloud();
      final client = _buildSpySupabaseClient(cloud);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() async {
        await db.close();
        client.dispose();
      });

      final e2ee = E2eeService(
        db: db,
        keyStore: RecoveryKeyStore(),
        vaultTransportOverride: _SpyVaultTransport(cloud, testOwner),
      );
      await _createTestVault(e2ee, testOwner);
      final key = (await e2ee.getKey(testOwner))!;
      final transfer = EncryptedMediaTransfer(
        client: client,
        owner: testOwner,
        key: key,
      );

      for (final bucket in EncryptedMediaTransfer.supportedBuckets) {
        final secretPayload = Uint8List.fromList(
          utf8.encode('SECRET_MEDIA_CONTENT_FOR_$bucket'),
        );
        final mediaId = 'item_$bucket';
        await transfer.uploadEncrypted(
          bucket: bucket,
          mediaId: mediaId,
          plaintextBytes: secretPayload,
        );

        // Storage nunca contém plaintext
        final chunkKey = '$bucket/$testOwner/e2ee/$mediaId/chunk_0.enc';
        expect(cloud.storageObjects.containsKey(chunkKey), isTrue);
        expect(
          utf8.decode(cloud.storageObjects[chunkKey]!, allowMalformed: true),
          isNot(contains('SECRET_MEDIA_CONTENT_FOR_$bucket')),
        );

        // Download descriptografa com integridade autenticada
        final decrypted = await transfer.downloadDecrypted(
          bucket: bucket,
          mediaId: mediaId,
        );
        expect(decrypted, equals(secretPayload));

        // Adulteração de 1 byte no chunk é rejeitada pela tag GCM/digest do manifesto
        final tampered = Uint8List.fromList(cloud.storageObjects[chunkKey]!);
        final parsed =
            jsonDecode(utf8.decode(tampered)) as Map<String, dynamic>;
        final ct = parsed['ciphertext'] as String;
        parsed['ciphertext'] = '${ct[0] == 'A' ? 'B' : 'A'}${ct.substring(1)}';
        cloud.storageObjects[chunkKey] = Uint8List.fromList(
          utf8.encode(jsonEncode(parsed)),
        );
        await expectLater(
          () => transfer.downloadDecrypted(bucket: bucket, mediaId: mediaId),
          throwsA(anything),
        );
      }
    });
  });
}
