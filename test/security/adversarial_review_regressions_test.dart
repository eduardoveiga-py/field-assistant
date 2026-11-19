import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/core/app_theme.dart';
import 'package:ministerio_pessoal/core/biometric_auth_service.dart';
import 'package:ministerio_pessoal/core/feature_registry.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/settings/backup_service.dart';
import 'package:ministerio_pessoal/sync/crypto/e2ee_service.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_crypto.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_media.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_media_transfer.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_record_sync.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_key_store.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_vault_transport.dart';
import 'package:ministerio_pessoal/sync/media_bytes_io.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:ministerio_pessoal/sync/sync_owner_guard.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/today_screen.dart';
import 'package:ministerio_pessoal/voice_notes/voice_dictation_service.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

// Test helper: keep the phrase before initiating the create-only request.
Future<String> _createTestVault(E2eeService service, String owner) async {
  final phrase = RecoveryCrypto.createPhrase();
  await service.setupVaultWithPhrase(owner, phrase);
  return phrase;
}

class _AdvCloud {
  final Map<String, Map<String, dynamic>> vaults = {};
  final Map<String, EncryptedRemoteRecord> records = {};
  final Map<String, Uint8List> storageObjects = {};
  final List<String> deletedStorageKeys = [];
  int _seq = 0;
  bool failStorageDownloads = false;

  int nextSeq() => ++_seq;
}

class _AdvVault implements RecoveryVaultTransport {
  final _AdvCloud cloud;
  final String owner;
  _AdvVault(this.cloud, this.owner);

  @override
  Future<Map<String, dynamic>?> fetch() async => cloud.vaults[owner];

  @override
  Future<bool> createIfAbsent(Map<String, dynamic> marker) async {
    if (cloud.vaults.containsKey(owner)) return false;
    cloud.vaults[owner] = Map<String, dynamic>.from(marker);
    return true;
  }
}

class _AdvRecords implements PaginatedEncryptedRecordTransport {
  final _AdvCloud cloud;
  _AdvRecords(this.cloud);

  @override
  Future<EncryptedRemoteRecord?> fetch(String route) async =>
      cloud.records[route];

  @override
  Future<EncryptedWriteResult> compareAndSwap({
    required String route,
    required int expectedRevision,
    required Map<String, dynamic> envelope,
  }) async {
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
    final list =
        cloud.records.values.where((r) => r.serverSeq > sinceSeq).toList()
          ..sort((a, b) => a.serverSeq.compareTo(b.serverSeq));
    return list.take(limit).toList();
  }
}

Uint8List _extractMultipartOrRaw(http.Request request) {
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

SupabaseClient _buildAdvClient(_AdvCloud cloud) {
  final httpClient = MockClient((request) async {
    final path = request.url.path;
    const storagePrefix = '/storage/v1/object/';
    if (path.contains(storagePrefix)) {
      final objectKey = path.substring(
        path.indexOf(storagePrefix) + storagePrefix.length,
      );
      if (request.method == 'POST' || request.method == 'PUT') {
        cloud.storageObjects[objectKey] = _extractMultipartOrRaw(request);
        return http.Response(
          jsonEncode({'Key': objectKey}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'GET') {
        if (cloud.failStorageDownloads) {
          return http.Response('Service Unavailable', 503);
        }
        final data = cloud.storageObjects[objectKey];
        if (data == null) return http.Response('Not Found', 404);
        return http.Response.bytes(data, 200);
      }
      if (request.method == 'DELETE') {
        final bucket = objectKey.split('/').first;
        final decoded = jsonDecode(request.body) as Map<String, dynamic>;
        final prefixes = (decoded['prefixes'] as List).cast<String>();
        final removed = <Map<String, dynamic>>[];
        for (final pref in prefixes) {
          final fullKey = '$bucket/$pref';
          cloud.deletedStorageKeys.add(fullKey);
          if (cloud.storageObjects.remove(fullKey) != null) {
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
    fail('Chamada PostgREST inesperada: ${request.method} $path');
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

  group('Adversarial E2EE Sync Regressions (Bugs 1-6)', () {
    const owner = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      RecoveryKeyStore.resetForTesting();
    });

    test('Bug 1 & 4: conflito no pull não avança cursor server_seq e resolveConflictAcceptRemote atualiza checkpoint permitindo novo push sem loop CAS', () async {
      final cloud = _AdvCloud();
      final client = _buildAdvClient(cloud);
      final db1 = AppDatabase.forTesting(NativeDatabase.memory());
      final repo1 = AppRepository(db1);
      final db2 = AppDatabase.forTesting(NativeDatabase.memory());
      final repo2 = AppRepository(db2);
      addTearDown(() async {
        await db1.close();
        await db2.close();
        client.dispose();
      });

      final e2ee1 = E2eeService(
        db: db1,
        keyStore: RecoveryKeyStore(),
        vaultTransportOverride: _AdvVault(cloud, owner),
        recordTransportOverride: _AdvRecords(cloud),
      );
      final phrase = await _createTestVault(e2ee1, owner);
      final sync1 = SupabaseSyncService(
        db: db1,
        repository: repo1,
        clientOverride: client,
        e2eeServiceOverride: e2ee1,
        allowEncryptedSyncForTesting: true,
        authenticatedOwnerOverrideForTesting: owner,
      );
      addTearDown(sync1.dispose);

      final person = await repo1.createPerson(
        name: 'Ana Original',
        phone: '1111',
      );
      expect((await sync1.processQueue()).failureCount, 0);

      // Dispositivo 2 baixa rev 1
      final e2ee2 = E2eeService(
        db: db2,
        keyStore: RecoveryKeyStore(),
        vaultTransportOverride: _AdvVault(cloud, owner),
        recordTransportOverride: _AdvRecords(cloud),
      );
      await e2ee2.restoreVault(owner, phrase);
      final sync2 = SupabaseSyncService(
        db: db2,
        repository: repo2,
        clientOverride: client,
        e2eeServiceOverride: e2ee2,
        allowEncryptedSyncForTesting: true,
        authenticatedOwnerOverrideForTesting: owner,
      );
      addTearDown(sync2.dispose);
      expect((await sync2.fetchRemoteChanges()).successCount, 1);

      final cursorBeforeConflict = await (db2.select(
        db2.appKvStore,
      )..where((t) => t.key.equals('e2ee_last_server_seq_$owner'))).getSingle();
      expect(int.parse(cursorBeforeConflict.value), equals(1));

      // Dispositivo 1 edita phone -> rev 2 (server_seq 2)
      await repo1.updatePerson(
        person.copyWith(phone: const drift.Value('2222')),
      );
      expect((await sync1.processQueue()).successCount, 1);

      // Dispositivo 2 edita o MESMO campo phone offline -> conflito real!
      final p2Before = (await repo2.getPersonById(person.id))!;
      await repo2.updatePerson(
        p2Before.copyWith(phone: const drift.Value('9999')),
      );

      final pullConflict = await sync2.fetchRemoteChanges();
      expect(pullConflict.conflictCount, equals(1));

      // Cursor server_seq NÃO pode ter avançado para 2 sobre registro em conflito!
      final cursorAfterConflict = await (db2.select(
        db2.appKvStore,
      )..where((t) => t.key.equals('e2ee_last_server_seq_$owner'))).getSingle();
      expect(int.parse(cursorAfterConflict.value), equals(1));

      final conflictOps = (await repo2.getUnresolvedSyncOperations())
          .where((op) => op.status == 'conflict')
          .toList();
      expect(conflictOps, hasLength(1));

      // Aceitar versão remota DEVE atualizar tanto o registro local quanto o checkpoint (rev=2)
      final resolved = await sync2.resolveConflictAcceptRemote(
        conflictOps.single.id,
      );
      expect(resolved, isTrue);

      final afterResolve = await (db2.select(
        db2.people,
      )..where((t) => t.id.equals(person.id))).getSingle();
      expect(afterResolve.phone, equals('2222'));

      final cp2 = (await e2ee2.getCheckpoint(owner))!;
      expect(
        await cp2.getKnownRevision(entityType: 'people', entityId: person.id),
        equals(2),
      );

      // Nova edição no Dispositivo 2 agora envia como rev=3 SEM loop de conflito CAS!
      await repo2.updatePerson(
        afterResolve.copyWith(phone: const drift.Value('3333')),
      );
      final push3 = await sync2.processQueue();
      expect(push3.conflictCount, equals(0));
      expect(push3.failureCount, equals(0));
      expect(push3.successCount, equals(1));
      expect(
        await cp2.getKnownRevision(entityType: 'people', entityId: person.id),
        equals(3),
      );
    });

    test('Bug 2: falha temporária no Storage marca pending_audio_download e retryPendingMediaDownloads recupera e limpa o marcador', () async {
      final cloud = _AdvCloud();
      final client = _buildAdvClient(cloud);
      final dir1 = await Directory.systemTemp.createTemp('adv_m1_');
      final dir2 = await Directory.systemTemp.createTemp('adv_m2_');
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
        vaultTransportOverride: _AdvVault(cloud, owner),
        recordTransportOverride: _AdvRecords(cloud),
      );
      final phrase = await _createTestVault(e2ee1, owner);
      final sync1 = SupabaseSyncService(
        db: db1,
        repository: repo1,
        clientOverride: client,
        e2eeServiceOverride: e2ee1,
        documentsDirectoryProvider: () async => dir1.path,
        allowEncryptedSyncForTesting: true,
        authenticatedOwnerOverrideForTesting: owner,
      );
      addTearDown(sync1.dispose);

      final person = await repo1.createPerson(name: 'Carlos Áudio');
      final audioBytes = Uint8List.fromList(utf8.encode('AUDIO_RECOVERY_OK'));
      final audioFile = File(p.join(dir1.path, 'vn_rec_1.m4a'));
      await audioFile.writeAsBytes(audioBytes);
      final now = DateTime.now().toUtc();
      await db1
          .into(db1.voiceNotes)
          .insert(
            VoiceNotesCompanion.insert(
              id: 'vn_rec_1',
              personId: person.id,
              audioFilePath: drift.Value(audioFile.path),
              audioDurationSeconds: const drift.Value(8),
              transcription: 'Teste recuperação mídia',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db1
          .into(db1.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: 'sq_vn_rec_1',
              entityType: 'voice_notes',
              entityId: 'vn_rec_1',
              operation: 'INSERT',
              payload: jsonEncode({'id': 'vn_rec_1'}),
              createdAt: now,
            ),
          );
      expect((await sync1.processQueue()).failureCount, 0);

      // Dispositivo 2 puxa enquanto Storage retorna 503
      cloud.failStorageDownloads = true;
      final e2ee2 = E2eeService(
        db: db2,
        keyStore: RecoveryKeyStore(),
        vaultTransportOverride: _AdvVault(cloud, owner),
        recordTransportOverride: _AdvRecords(cloud),
      );
      await e2ee2.restoreVault(owner, phrase);
      final sync2 = SupabaseSyncService(
        db: db2,
        repository: repo2,
        clientOverride: client,
        e2eeServiceOverride: e2ee2,
        documentsDirectoryProvider: () async => dir2.path,
        allowEncryptedSyncForTesting: true,
        authenticatedOwnerOverrideForTesting: owner,
      );
      addTearDown(sync2.dispose);

      await sync2.fetchRemoteChanges();

      final pendingKey =
          await (db2.select(db2.appKvStore)
                ..where((t) => t.key.equals('pending_audio_download_vn_rec_1')))
              .getSingleOrNull();
      expect(pendingKey, isNotNull);

      // Storage volta ao ar: retryPendingMediaDownloads baixa, descriptografa e apaga o marcador!
      cloud.failStorageDownloads = false;
      final recovered = await sync2.retryPendingMediaDownloads();
      expect(recovered, equals(1));

      final pendingAfter =
          await (db2.select(db2.appKvStore)
                ..where((t) => t.key.equals('pending_audio_download_vn_rec_1')))
              .getSingleOrNull();
      expect(pendingAfter, isNull);

      final vn2 = await (db2.select(
        db2.voiceNotes,
      )..where((t) => t.id.equals('vn_rec_1'))).getSingle();
      expect(await File(vn2.audioFilePath!).readAsBytes(), equals(audioBytes));
    });

    test('Bug 3: tombstone remoto contra edição local pendente (delete-vs-update) sinaliza conflito sem corromper registro local', () async {
      final cloud = _AdvCloud();
      final client = _buildAdvClient(cloud);
      final db1 = AppDatabase.forTesting(NativeDatabase.memory());
      final repo1 = AppRepository(db1);
      final db2 = AppDatabase.forTesting(NativeDatabase.memory());
      final repo2 = AppRepository(db2);
      addTearDown(() async {
        await db1.close();
        await db2.close();
        client.dispose();
      });

      final e2ee1 = E2eeService(
        db: db1,
        keyStore: RecoveryKeyStore(),
        vaultTransportOverride: _AdvVault(cloud, owner),
        recordTransportOverride: _AdvRecords(cloud),
      );
      final phrase = await _createTestVault(e2ee1, owner);
      final sync1 = SupabaseSyncService(
        db: db1,
        repository: repo1,
        clientOverride: client,
        e2eeServiceOverride: e2ee1,
        allowEncryptedSyncForTesting: true,
        authenticatedOwnerOverrideForTesting: owner,
      );
      addTearDown(sync1.dispose);

      final person = await repo1.createPerson(
        name: 'Maria Preservada',
        address: 'Rua Inicial 10',
      );
      expect((await sync1.processQueue()).failureCount, 0);

      final e2ee2 = E2eeService(
        db: db2,
        keyStore: RecoveryKeyStore(),
        vaultTransportOverride: _AdvVault(cloud, owner),
        recordTransportOverride: _AdvRecords(cloud),
      );
      await e2ee2.restoreVault(owner, phrase);
      final sync2 = SupabaseSyncService(
        db: db2,
        repository: repo2,
        clientOverride: client,
        e2eeServiceOverride: e2ee2,
        allowEncryptedSyncForTesting: true,
        authenticatedOwnerOverrideForTesting: owner,
      );
      addTearDown(sync2.dispose);
      expect((await sync2.fetchRemoteChanges()).successCount, 1);

      // Dispositivo 1 exclui (tombstone cifrado)
      await repo1.deletePerson(person.id);
      expect((await sync1.processQueue()).successCount, 1);

      // Dispositivo 2 edita offline
      final p2 = (await repo2.getPersonById(person.id))!;
      await repo2.updatePerson(
        p2.copyWith(address: const drift.Value('Edição offline valiosa')),
      );

      final pullRes = await sync2.fetchRemoteChanges();
      expect(pullRes.conflictCount, equals(1));

      // Registro local deve continuar íntegro (nome preservado, não corrompido nem apagado silenciosamente)
      final localAfter = await (db2.select(
        db2.people,
      )..where((t) => t.id.equals(person.id))).getSingle();
      expect(localAfter.name, equals('Maria Preservada'));
      expect(localAfter.address, equals('Edição offline valiosa'));
      expect(localAfter.deletedAt, isNull);
    });

    test('Bug 5: pull com PRAGMA foreign_keys = ON aplica pai atualizado após filho sem deadlock FK', () async {
      final cloud = _AdvCloud();
      final client = _buildAdvClient(cloud);
      final db1 = AppDatabase.forTesting(NativeDatabase.memory());
      final repo1 = AppRepository(db1);
      final db2 = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;'),
        ),
      );
      final repo2 = AppRepository(db2);
      addTearDown(() async {
        await db1.close();
        await db2.close();
        client.dispose();
      });

      final e2ee1 = E2eeService(
        db: db1,
        keyStore: RecoveryKeyStore(),
        vaultTransportOverride: _AdvVault(cloud, owner),
        recordTransportOverride: _AdvRecords(cloud),
      );
      final phrase = await _createTestVault(e2ee1, owner);
      final sync1 = SupabaseSyncService(
        db: db1,
        repository: repo1,
        clientOverride: client,
        e2eeServiceOverride: e2ee1,
        allowEncryptedSyncForTesting: true,
        authenticatedOwnerOverrideForTesting: owner,
      );
      addTearDown(sync1.dispose);

      // 1. Cria Pessoa (seq 1)
      final person = await repo1.createPerson(name: 'Pai FK');
      expect((await sync1.processQueue()).failureCount, 0);

      // 2. Cria Visita filha (seq 2)
      await repo1.createVisit(
        personId: person.id,
        dateTime: DateTime.now().toUtc(),
        contactType: 'revisita',
        result: 'Interessado',
      );
      expect((await sync1.processQueue()).failureCount, 0);

      // 3. Atualiza Pessoa -> server_seq do pai salta para 3 (DEPOIS da visita seq 2!)
      await repo1.updatePerson(
        person.copyWith(
          address: const drift.Value('Atualizado depois do filho'),
        ),
      );
      expect((await sync1.processQueue()).failureCount, 0);

      // Dispositivo 2 limpo com PRAGMA foreign_keys = ON puxa desde 0
      final e2ee2 = E2eeService(
        db: db2,
        keyStore: RecoveryKeyStore(),
        vaultTransportOverride: _AdvVault(cloud, owner),
        recordTransportOverride: _AdvRecords(cloud),
      );
      await e2ee2.restoreVault(owner, phrase);
      final sync2 = SupabaseSyncService(
        db: db2,
        repository: repo2,
        clientOverride: client,
        e2eeServiceOverride: e2ee2,
        allowEncryptedSyncForTesting: true,
        authenticatedOwnerOverrideForTesting: owner,
      );
      addTearDown(sync2.dispose);

      final pullRes = await sync2.fetchRemoteChanges();
      expect(
        pullRes.failureCount,
        equals(0),
        reason: pullRes.errors.join('; '),
      );
      expect(pullRes.successCount, equals(2));
      expect(
        (await repo2.getAllPeople()).single.address,
        'Atualizado depois do filho',
      );
      expect((await db2.select(db2.visits).get()), hasLength(1));
    });

    test('Bug 6: EncryptedMediaTransfer.deleteEncrypted remove TODOS os blocos (>16 chunks / >4 MiB) sem deixar órfãos', () async {
      final cloud = _AdvCloud();
      final client = _buildAdvClient(cloud);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() async {
        await db.close();
        client.dispose();
      });

      final e2ee = E2eeService(
        db: db,
        keyStore: RecoveryKeyStore(),
        vaultTransportOverride: _AdvVault(cloud, owner),
      );
      await _createTestVault(e2ee, owner);
      final key = (await e2ee.getKey(owner))!;
      final transfer = EncryptedMediaTransfer(
        client: client,
        owner: owner,
        key: key,
      );

      // 17 chunks completos + 100 bytes (> 4 MiB, acima do antigo maxChunkProbe = 16)
      final bigPayload = Uint8List(EncryptedMedia.chunkSize * 17 + 100);
      for (var i = 0; i < bigPayload.length; i += 4096) {
        bigPayload[i] = i % 251;
      }
      await transfer.uploadEncrypted(
        bucket: 'knowledge_vault',
        mediaId: 'big_doc',
        plaintextBytes: bigPayload,
      );
      // 18 chunks (0..17) + 1 manifest = 19 objetos
      expect(cloud.storageObjects.length, equals(19));

      await transfer.deleteEncrypted(
        bucket: 'knowledge_vault',
        mediaId: 'big_doc',
      );
      expect(cloud.storageObjects, isEmpty);
    });
  });

  group('Adversarial Security, Backup, KDF & Account Switch Regressions (Bugs 7-11)', () {
    test('Bug 7: saveMediaBytes bloqueia caracteres ilegais, ponto final e escape via symlink', () async {
      final root = await Directory.systemTemp.createTemp('adv_media_root_');
      final baseDir = Directory(p.join(root.path, 'app_docs'));
      final outsideDir = Directory(p.join(root.path, 'outside_secret'));
      await baseDir.create(recursive: true);
      await outsideDir.create(recursive: true);
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });

      for (final bad in ['a*b.m4a', 'a?b.m4a', 'a<b.m4a', 'a|b.m4a', 'file.']) {
        await expectLater(
          () => saveMediaBytes(
            baseDir: baseDir.path,
            subDir: 'voice_notes',
            fileName: bad,
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
          throwsArgumentError,
          reason: 'Deve rejeitar nome inválido: $bad',
        );
      }

      // Testa escape por symlink quando o ambiente permite criar links simbólicos
      final symlinkPath = p.join(baseDir.path, 'linked_sub');
      var symlinkCreated = false;
      try {
        await Link(symlinkPath).create(outsideDir.path);
        symlinkCreated = true;
      } on FileSystemException {
        symlinkCreated = false;
      }
      if (symlinkCreated) {
        await expectLater(
          () => saveMediaBytes(
            baseDir: baseDir.path,
            subDir: 'linked_sub',
            fileName: 'escaped.m4a',
            bytes: Uint8List.fromList([9, 9, 9]),
          ),
          throwsArgumentError,
        );
        expect(outsideDir.listSync(), isEmpty);
      }
    });

    test('Bug 8: BiometricAuthService migra hash legado SHA-256 mesmo com salt não-hexadecimal sem travar usuário', () async {
      const legacyNonHexSalt = 'legacy-uuid-salt-not-hex!';
      final legacyHash = sha256
          .convert(utf8.encode('$legacyNonHexSalt:4321'))
          .toString();
      FlutterSecureStorage.setMockInitialValues({
        'app_security_pin_salt': legacyNonHexSalt,
        'app_security_pin_hash': legacyHash,
      });

      final auth = BiometricAuthService(pbkdf2Iterations: 2000);
      expect(await auth.verifyPin('4321'), isTrue);

      const storage = FlutterSecureStorage();
      final newSalt = await storage.read(key: 'app_security_pin_salt');
      final newKdf = await storage.read(key: 'app_security_pin_kdf');
      expect(newSalt, isNot(equals(legacyNonHexSalt)));
      expect(newSalt?.length, equals(32));
      expect(newKdf, equals('pbkdf2_hmac_sha256:2000'));

      auth.lockSession();
      expect(await auth.verifyPin('4321'), isTrue);
    });

    test('Bug 9: BackupService.previewBackup rejeita iterações PBKDF2 inválidas, DoS ou downgrade de v3', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = AppRepository(db);
      final backup = BackupService(repo);
      addTearDown(db.close);

      for (final badContainer in [
        {
          'version': 2,
          'salt': base64Encode(List.filled(16, 1)),
          'iterations': 0,
          'iv': base64Encode(List.filled(16, 2)),
          'ciphertext': 'AAAA',
        },
        {
          'version': 2,
          'salt': base64Encode(List.filled(16, 1)),
          'iterations': -10,
          'iv': base64Encode(List.filled(16, 2)),
          'ciphertext': 'AAAA',
        },
        {
          'version': 2,
          'salt': base64Encode(List.filled(16, 1)),
          'iterations': 999999999,
          'iv': base64Encode(List.filled(16, 2)),
          'ciphertext': 'AAAA',
        },
        {
          'version': 3,
          'kdf': 'PBKDF2-HMAC-SHA256',
          'salt': base64Encode(List.filled(16, 1)),
          'iterations': 1000,
          'iv': base64Encode(List.filled(16, 2)),
          'ciphertext': 'AAAA',
        },
      ]) {
        await expectLater(
          () => backup.previewBackup(
            encryptedDataString: jsonEncode(badContainer),
            password: 'any-password',
          ),
          throwsFormatException,
        );
      }
    });

    test('Bug 11: SyncOwnerGuard.prepareWorkspaceForAuthenticatedAccount exige confirmação com dados não sincronizados e isola quando sincronizado ou confirmado', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = AppRepository(db);
      addTearDown(db.close);

      const accountA = 'aaaa-account-a';
      const accountB = 'bbbb-account-b';
      await SyncOwnerGuard.bindOwnerId(db, accountA);
      await repo.createPerson(name: 'Dado Pendente Conta A');

      // Com fila pendente, troca sem confirmação NÃO apaga dados
      final blocked =
          await SyncOwnerGuard.prepareWorkspaceForAuthenticatedAccount(
            db: db,
            authenticatedUserId: accountB,
          );
      expect(
        blocked.status,
        AccountWorkspacePreparationStatus.requiresConfirmationDueToUnsyncedData,
      );
      expect(blocked.pendingUnsyncedCount, greaterThan(0));
      expect((await repo.getAllPeople()), hasLength(1));

      // Com confirmação explícita, isola atomicamente para Conta B
      final switched =
          await SyncOwnerGuard.prepareWorkspaceForAuthenticatedAccount(
            db: db,
            authenticatedUserId: accountB,
            discardUnsyncedIfSwitching: true,
          );
      expect(
        switched.status,
        AccountWorkspacePreparationStatus.switchedCleanly,
      );
      expect(await SyncOwnerGuard.getBoundOwnerId(db), equals(accountB));
      expect((await repo.getAllPeople()), isEmpty);

      // Sem dados pendentes, troca de Conta B para Conta A ocorre de forma limpa
      final cleanSwitch =
          await SyncOwnerGuard.prepareWorkspaceForAuthenticatedAccount(
            db: db,
            authenticatedUserId: accountA,
          );
      expect(
        cleanSwitch.status,
        AccountWorkspacePreparationStatus.switchedCleanly,
      );
      expect(await SyncOwnerGuard.getBoundOwnerId(db), equals(accountA));
    });

    test(
      'Bug I: VoiceDictationService rejeita locale "ticuna" além de "tca_BR"',
      () async {
        final svc = LocalVoiceDictationService();
        String? error;
        await svc.startListening(
          localeId: 'ticuna',
          onResult: (_) {},
          onError: (msg) => error = msg,
        );
        expect(error, isNotNull);
        expect(error, contains('Ticuna'));
        expect(svc.isListening, isFalse);
      },
    );

    testWidgets(
      'Bug 10: Desativar inbox/tasksProjects/knowledge oculta atalhos na Hoje e resultados na Busca Global sem apagar dados do SQLite',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final now = DateTime.now().toUtc();

        await db
            .into(db.inboxEntries)
            .insert(
              InboxEntriesCompanion.insert(
                id: 'inb_toggle_1',
                content: 'SegredoInboxUnico',
                capturedAt: now,
                createdAt: now,
                updatedAt: now,
              ),
            );
        await db
            .into(db.tasks)
            .insert(
              TasksCompanion.insert(
                id: 'tsk_toggle_1',
                title: 'SegredoTarefaUnica',
                createdAt: now,
                updatedAt: now,
              ),
            );
        await db
            .into(db.knowledgeNotes)
            .insert(
              KnowledgeNotesCompanion.insert(
                id: 'knw_toggle_1',
                title: 'SegredoConhecimentoUnico',
                content: 'Conteúdo preservado',
                createdAt: now,
                updatedAt: now,
              ),
            );

        // Desativa os 3 módulos nas configurações
        for (final feat in [
          AppFeature.inbox,
          AppFeature.tasksProjects,
          AppFeature.knowledge,
        ]) {
          await db
              .into(db.appKvStore)
              .insertOnConflictUpdate(
                AppKvStoreCompanion.insert(
                  key: FeatureRegistry.settingKey(feat),
                  value: 'false',
                ),
              );
        }

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('pt', 'BR')],
              home: const TodayScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Atalhos ocultos na TodayScreen
        expect(find.text('Inbox'), findsNothing);
        expect(find.text('Tarefas'), findsNothing);
        expect(find.text('Conhecimento'), findsNothing);
        expect(find.byIcon(Icons.all_inbox_rounded), findsNothing);

        // Abre Busca Global pelo botão real da AppBar da TodayScreen e pesquisa "Segredo"
        await tester.tap(find.byIcon(Icons.search));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Segredo');
        await tester.pumpAndSettle();

        expect(find.text('SegredoInboxUnico'), findsNothing);
        expect(find.text('SegredoTarefaUnica'), findsNothing);
        expect(find.text('SegredoConhecimentoUnico'), findsNothing);

        // Dados permanecem 100% preservados no banco local!
        expect((await db.select(db.inboxEntries).get()), hasLength(1));
        expect((await db.select(db.tasks).get()), hasLength(1));
        expect((await db.select(db.knowledgeNotes).get()), hasLength(1));

        // Drena timers de cancelamento de StreamQuery do Drift antes do verifyInvariants
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'Bug 13: Busca Global tipada retorna Pessoas (generalNotes), Telefones, Pesquisas, Tarefas, Conhecimento e Inbox sem NoSuchMethodError',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final now = DateTime.now().toUtc();

        await db
            .into(db.people)
            .insert(
              PeopleCompanion.insert(
                id: 'p_srch_1',
                name: 'Pedro AlvoUnico',
                generalNotes: const drift.Value('Nota especial AlvoUnico'),
                firstContactAt: now,
                createdAt: now,
                updatedAt: now,
              ),
            );
        await db
            .into(db.phoneContacts)
            .insert(
              PhoneContactsCompanion.insert(
                id: 'ph_srch_1',
                name: 'ContatoFone AlvoUnico',
                phone: '92999990000',
                createdAt: now,
                updatedAt: now,
              ),
            );
        await db
            .into(db.researchArticles)
            .insert(
              ResearchArticlesCompanion.insert(
                id: 'res_srch_1',
                title: 'Artigo AlvoUnico',
                summary: 'Resumo',
                content: 'Conteúdo bíblico',
                createdAt: now,
                updatedAt: now,
              ),
            );
        await db
            .into(db.tasks)
            .insert(
              TasksCompanion.insert(
                id: 'tsk_srch_1',
                title: 'Tarefa AlvoUnico',
                createdAt: now,
                updatedAt: now,
              ),
            );
        await db
            .into(db.knowledgeNotes)
            .insert(
              KnowledgeNotesCompanion.insert(
                id: 'knw_srch_1',
                title: 'NotaConhecimento AlvoUnico',
                content: 'Detalhes',
                createdAt: now,
                updatedAt: now,
              ),
            );
        await db
            .into(db.inboxEntries)
            .insert(
              InboxEntriesCompanion.insert(
                id: 'inb_srch_1',
                content: 'ItemInbox AlvoUnico',
                capturedAt: now,
                createdAt: now,
                updatedAt: now,
              ),
            );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('pt', 'BR')],
              home: const TodayScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.search));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'AlvoUnico');
        await tester.pumpAndSettle();

        expect(find.text('Pedro AlvoUnico'), findsOneWidget);
        expect(find.text('ContatoFone AlvoUnico'), findsOneWidget);
        expect(find.text('Artigo AlvoUnico'), findsOneWidget);
        expect(find.text('Tarefa AlvoUnico'), findsOneWidget);
        expect(find.text('NotaConhecimento AlvoUnico'), findsOneWidget);
        expect(find.text('ItemInbox AlvoUnico'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });
}
