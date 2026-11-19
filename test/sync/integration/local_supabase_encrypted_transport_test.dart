import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_media_transfer.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_record_sync.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_crypto.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_vault_transport.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_vault_verifier.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final enabled = Platform.environment['FA_RUN_LOCAL_SUPABASE_E2E'] == '1';
  test(
    'isolated Auth, vault, encrypted CAS, account isolation and Storage',
    () async {
      // This is deliberately not configurable to prevent reaching a hosted project.
      const localUrl = 'http://127.0.0.1:54321';
      final anonKey = Platform.environment['FA_LOCAL_SUPABASE_ANON_KEY'];
      if (anonKey == null || anonKey.isEmpty)
        throw StateError('Local anonymous key missing');
      final alice = SupabaseClient(localUrl, anonKey);
      final aliceDevice2 = SupabaseClient(localUrl, anonKey);
      final bob = SupabaseClient(localUrl, anonKey);
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
}
