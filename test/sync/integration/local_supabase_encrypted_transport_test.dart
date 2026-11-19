import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/sync/crypto/e2ee_service.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_key_store.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_media_transfer.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_record_sync.dart';
import 'package:ministerio_pessoal/sync/crypto/immutable_encrypted_media.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_crypto.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_vault_transport.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_vault_verifier.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final enabled = Platform.environment['FA_RUN_LOCAL_SUPABASE_E2E'] == '1';
  if (enabled) {
    // The Flutter test binding normally intercepts all HTTP with a fake 400.
    // This probe can only connect to the literal loopback URL below.
    HttpOverrides.global = null;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }
  test(
    'isolated Auth, vault, encrypted CAS, account isolation and Storage',
    () async {
      // This is deliberately not configurable to prevent reaching a hosted project.
      const localUrl = 'http://127.0.0.1:54321';
      final anonKey = Platform.environment['FA_LOCAL_SUPABASE_ANON_KEY'];
      if (anonKey == null || anonKey.isEmpty)
        throw StateError('Local anonymous key missing');
      // Local signup has no browser redirect or PKCE verifier persistence.
      const authOptions = AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      );
      final alice = SupabaseClient(localUrl, anonKey, authOptions: authOptions);
      final aliceDevice2 = SupabaseClient(
        localUrl,
        anonKey,
        authOptions: authOptions,
      );
      final bob = SupabaseClient(localUrl, anonKey, authOptions: authOptions);
      const password = 'local-test-password-only-2026';
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final emailA = 'fa-test-a-$suffix@example.com';
      final emailB = 'fa-test-b-$suffix@example.com';
      try {
        final a = await alice.auth.signUp(email: emailA, password: password);
        final b = await bob.auth.signUp(email: emailB, password: password);
        expect(a.session, isNotNull);
        expect(b.session, isNotNull);
        final ownerA = a.user!.id;
        final ownerB = b.user!.id;
        expect(ownerA, isNot(ownerB));
        await aliceDevice2.auth.signInWithPassword(
          email: emailA,
          password: password,
        );

        final phrase = RecoveryCrypto.createPhrase();
        final key = await RecoveryCrypto.keyFromPhrase(phrase);
        final marker = await RecoveryVaultVerifier.create(
          root: key,
          owner: ownerA,
        );
        final vaultA = SupabaseRecoveryVaultTransport(
          client: alice,
          owner: ownerA,
        );
        final setupA = RecoveryVaultSetup(owner: ownerA, transport: vaultA);
        expect(
          await setupA.createConfirmed(
            key: key,
            marker: marker,
            expectedVaultId: marker['vaultId'] as String,
          ),
          isTrue,
        );
        expect(await vaultA.createIfAbsent(marker), isFalse);
        final key2 = await RecoveryCrypto.keyFromPhrase(phrase);
        final setupA2 = RecoveryVaultSetup(
          owner: ownerA,
          transport: SupabaseRecoveryVaultTransport(
            client: aliceDevice2,
            owner: ownerA,
          ),
        );
        final verified = await setupA2.fetchVerified(
          key: key2,
          expectedVaultId: marker['vaultId'] as String,
        );
        expect(verified['vaultId'], marker['vaultId']);
        expect(
          await SupabaseRecoveryVaultTransport(
            client: bob,
            owner: ownerB,
          ).fetch(),
          isNull,
        );

        final transportA = SupabaseEncryptedRecordTransport(
          client: alice,
          owner: ownerA,
        );
        final syncA = EncryptedRecordSync(
          owner: ownerA,
          key: key,
          transport: transportA,
        );
        const secret = 'synthetic secret for isolated test only';
        final sealed = await syncA.writeSealed(
          entityType: 'people',
          entityId: 'test-person',
          expectedRevision: 0,
          data: {'name': secret},
        );
        expect(sealed.result.success, isTrue);
        expect(sealed.result.revision, 1);
        final raw = await transportA.fetch(sealed.route);
        expect(raw, isNotNull);
        expect(jsonEncode(raw!.envelope), isNot(contains(secret)));
        final syncA2 = EncryptedRecordSync(
          owner: ownerA,
          key: key2,
          transport: SupabaseEncryptedRecordTransport(
            client: aliceDevice2,
            owner: ownerA,
          ),
        );
        expect(
          (await syncA2.read(
            entityType: 'people',
            entityId: 'test-person',
          ))!['data'],
          {'name': secret},
        );
        final conflict = await syncA2.write(
          entityType: 'people',
          entityId: 'test-person',
          expectedRevision: 0,
          data: {'name': 'other'},
        );
        expect(conflict.success, isFalse);
        expect(
          (await syncA.read(
            entityType: 'people',
            entityId: 'test-person',
          ))!['data'],
          {'name': secret},
        );
        final unauthorized = await bob
            .from('encrypted_records')
            .select('route')
            .eq('owner_id', ownerA)
            .eq('route', sealed.route);
        expect(unauthorized, isEmpty);
        await expectLater(
          SupabaseEncryptedRecordTransport(
            client: bob,
            owner: ownerA,
          ).fetch(sealed.route),
          throwsStateError,
        );

        // Two clients stage different immutable versions and race the CAS.
        final stagedA = ImmutableEncryptedMedia(client: alice, owner: ownerA, key: key);
        final stagedB = ImmutableEncryptedMedia(client: aliceDevice2, owner: ownerA, key: key2);
        final payloadA = Uint8List.fromList(utf8.encode('fictional media version A'));
        final payloadB = Uint8List.fromList(utf8.encode('fictional media version B'));
        final refs = await Future.wait([
          stagedA.stage(bucket: 'voice_notes', mediaId: 'race-media', plaintextBytes: payloadA),
          stagedB.stage(bucket: 'voice_notes', mediaId: 'race-media', plaintextBytes: payloadB),
        ]);
        expect(refs[0].versionId, isNot(refs[1].versionId));
        final writes = await Future.wait([
          syncA.write(entityType: 'voice_notes', entityId: 'race-media', expectedRevision: 0, data: {'media': refs[0].toJson()}),
          syncA2.write(entityType: 'voice_notes', entityId: 'race-media', expectedRevision: 0, data: {'media': refs[1].toJson()}),
        ]);
        expect(writes.where((result) => result.success).length, 1);
        expect(writes.where((result) => !result.success).length, 1);
        final committed = await syncA2.read(entityType: 'voice_notes', entityId: 'race-media');
        final data = Map<String, dynamic>.from(committed!['data'] as Map);
        final winner = ImmutableMediaReference.fromJson(Map<String, dynamic>.from(data['media'] as Map));
        final winnerBytes = winner.versionId == refs[0].versionId ? payloadA : payloadB;
        expect(await stagedB.download(bucket: 'voice_notes', mediaId: 'race-media', reference: winner), winnerBytes);
        // Neither the losing version nor the winning version is purged.
        expect(await stagedA.download(bucket: 'voice_notes', mediaId: 'race-media', reference: refs[0]), payloadA);
        expect(await stagedB.download(bucket: 'voice_notes', mediaId: 'race-media', reference: refs[1]), payloadB);
        await expectLater(
          ImmutableEncryptedMedia(client: bob, owner: ownerA, key: key)
              .download(bucket: 'voice_notes', mediaId: 'race-media', reference: winner),
          throwsStateError,
        );
        // Copying valid ciphertext to a different version cannot authenticate.
        const forgedVersion = '00000000000000000000000000000000';
        final prefix = '$ownerA/e2ee/race-media';
        for (final name in ['manifest.enc', 'chunk_0.enc']) {
          final copied = await alice.storage.from('voice_notes').download('$prefix/v2_${refs[0].versionId}/$name');
          await alice.storage.from('voice_notes').uploadBinary(
            '$prefix/v2_$forgedVersion/$name', copied,
            fileOptions: const FileOptions(upsert: false),
          );
        }
        final forged = ImmutableMediaReference(versionId: forgedVersion, sizeBytes: refs[0].sizeBytes, sha256: refs[0].sha256);
        await expectLater(stagedA.download(bucket: 'voice_notes', mediaId: 'race-media', reference: forged), throwsA(anything));

        final media = EncryptedMediaTransfer(
          client: alice,
          owner: ownerA,
          key: key,
        );
        final plain = Uint8List.fromList(
          utf8.encode('local synthetic media secret'),
        );
        await media.uploadEncrypted(
          bucket: 'voice_notes',
          mediaId: 'isolated-media',
          plaintextBytes: plain,
        );
        final rawChunk = await alice.storage
            .from('voice_notes')
            .download('$ownerA/e2ee/isolated-media/chunk_0.enc');
        expect(
          utf8.decode(rawChunk),
          isNot(contains('local synthetic media secret')),
        );
        expect(
          await media.downloadDecrypted(
            bucket: 'voice_notes',
            mediaId: 'isolated-media',
          ),
          plain,
        );
        await expectLater(
          bob.storage
              .from('voice_notes')
              .download('$ownerA/e2ee/isolated-media/chunk_0.enc'),
          throwsA(anything),
        );
      } finally {
        alice.dispose();
        aliceDevice2.dispose();
        bob.dispose();
      }
    },
    skip: !enabled,
  );
  test('isolated two-client Drift outbox and encrypted person pull', () async {
    const url = 'http://127.0.0.1:54321';
    final anon = Platform.environment['FA_LOCAL_SUPABASE_ANON_KEY'];
    if (anon == null || anon.isEmpty)
      throw StateError('Local anonymous key missing');
    const auth = AuthClientOptions(authFlowType: AuthFlowType.implicit);
    final client1 = SupabaseClient(url, anon, authOptions: auth);
    final client2 = SupabaseClient(url, anon, authOptions: auth);
    final db1 = AppDatabase.forTesting(NativeDatabase.memory());
    final db2 = AppDatabase.forTesting(NativeDatabase.memory());
    final repo1 = AppRepository(db1);
    final repo2 = AppRepository(db2);
    FlutterSecureStorage.setMockInitialValues({});
    RecoveryKeyStore.resetForTesting();
    final email = 'fa-app-${DateTime.now().microsecondsSinceEpoch}@example.com';
    const password = 'synthetic-local-password-2026';
    SupabaseSyncService? sync1;
    SupabaseSyncService? sync2;
    try {
      final signed = await client1.auth.signUp(
        email: email,
        password: password,
      );
      expect(signed.session, isNotNull);
      final owner = signed.user!.id;
      await client2.auth.signInWithPassword(email: email, password: password);
      final phrase = RecoveryCrypto.createPhrase();
      final e2ee1 = E2eeService(db: db1, client: client1);
      await e2ee1.setupVaultWithPhrase(owner, phrase);
      final e2ee2 = E2eeService(db: db2, client: client2);
      expect(await e2ee2.restoreVault(owner, phrase), isTrue);
      sync1 = SupabaseSyncService(
        db: db1,
        repository: repo1,
        clientOverride: client1,
        e2eeServiceOverride: e2ee1,
        allowEncryptedSyncForTesting: true,
      );
      sync2 = SupabaseSyncService(
        db: db2,
        repository: repo2,
        clientOverride: client2,
        e2eeServiceOverride: e2ee2,
        allowEncryptedSyncForTesting: true,
      );
      const secretName = 'Synthetic Local Private Person';
      final person = await repo1.createPerson(name: secretName);
      expect(await db1.select(db1.syncQueue).get(), isNotEmpty);
      final pushed = await sync1.processQueue();
      expect(pushed.failureCount, 0, reason: pushed.errors.join('; '));
      expect(pushed.successCount, greaterThanOrEqualTo(1));
      final remote = await client1.from('encrypted_records').select('envelope');
      expect(remote, isNotEmpty);
      expect(jsonEncode(remote), isNot(contains(secretName)));
      final pulled = await sync2.fetchRemoteChanges();
      expect(pulled.failureCount, 0, reason: pulled.errors.join('; '));
      expect((await repo2.getPersonById(person.id))?.name, secretName);
    } finally {
      sync1?.dispose();
      sync2?.dispose();
      await db1.close();
      await db2.close();
      client1.dispose();
      client2.dispose();
    }
  }, skip: !enabled);
}
