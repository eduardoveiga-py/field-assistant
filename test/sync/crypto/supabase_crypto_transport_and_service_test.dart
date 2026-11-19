import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/sync/crypto/e2ee_service.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_media_transfer.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_record_sync.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_crypto.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_key_store.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_vault_transport.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Test helper: keep the phrase before initiating the create-only request.
Future<String> _createTestVault(E2eeService service, String owner) async {
  final phrase = RecoveryCrypto.createPhrase();
  await service.setupVaultWithPhrase(owner, phrase);
  return phrase;
}

class _FakeAuthClient extends GoTrueClient {
  final User? _fakeUser;

  _FakeAuthClient(this._fakeUser);

  @override
  User? get currentUser => _fakeUser;
}

class _AuthedSupabaseClient extends SupabaseClient {
  final GoTrueClient _fakeAuth;

  _AuthedSupabaseClient({
    required String? userId,
    required http.Client httpClient,
  }) : _fakeAuth = _FakeAuthClient(
         userId == null
             ? null
             : User(
                 id: userId,
                 appMetadata: const {},
                 userMetadata: const {},
                 aud: 'authenticated',
                 createdAt: '2026-01-01T00:00:00Z',
               ),
       ),
       super(
         'https://mock.supabase.co',
         'mock-anon-key',
         httpClient: httpClient,
       );

  @override
  GoTrueClient get auth => _fakeAuth;
}

class _ThrowingStorage extends FlutterSecureStorage {
  const _ThrowingStorage();

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw StateError('Simulated keychain read failure');
  }
}

class _InMemoryVaultTransport implements RecoveryVaultTransport {
  Map<String, dynamic>? stored;
  bool throwOnFetch = false;

  @override
  Future<Map<String, dynamic>?> fetch() async {
    if (throwOnFetch) throw StateError('Simulated remote fetch error');
    return stored;
  }

  @override
  Future<bool> createIfAbsent(Map<String, dynamic> marker) async {
    if (stored != null) return false;
    stored = Map<String, dynamic>.from(marker);
    return true;
  }
}

http.Response _jsonResp(http.Request req, Object? data, {int status = 200}) {
  return http.Response(
    jsonEncode(data),
    status,
    request: req,
    headers: {'content-type': 'application/json'},
  );
}

http.Response _emptyMaybeSingleResp(http.Request req) {
  return http.Response(
    '[]',
    200,
    request: req,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    RecoveryKeyStore.resetForTesting();
  });

  group('SupabaseEncryptedRecordTransport wire-level contract tests', () {
    const owner = 'user-1111-2222';

    test(
      'fetch parses valid rows, handles null, and rejects malformed rows',
      () async {
        var mode = 'valid';
        final client = _AuthedSupabaseClient(
          userId: owner,
          httpClient: MockClient((req) async {
            if (mode == 'null') {
              return _emptyMaybeSingleResp(req);
            }
            if (mode == 'malformed') {
              return _jsonResp(req, {
                'route': 123,
                'revision': 'bad',
                'envelope': 'nope',
              });
            }
            return _jsonResp(req, {
              'route': 'rt-1',
              'revision': 3,
              'server_seq': 42.0,
              'envelope': {'v': 1, 'c': 'abc'},
            });
          }),
        );

        final transport = SupabaseEncryptedRecordTransport(
          client: client,
          owner: owner,
        );

        final rec = await transport.fetch('rt-1');
        expect(rec, isNotNull);
        expect(rec!.route, equals('rt-1'));
        expect(rec.revision, equals(3));
        expect(rec.serverSeq, equals(42));
        expect(rec.envelope['c'], equals('abc'));

        mode = 'null';
        expect(await transport.fetch('rt-missing'), isNull);

        mode = 'malformed';
        await expectLater(
          () => transport.fetch('rt-bad'),
          throwsFormatException,
        );
      },
    );

    test(
      'compareAndSwap handles success, conflict, and rejects invalid payloads',
      () async {
        var mode = 'success';
        final client = _AuthedSupabaseClient(
          userId: owner,
          httpClient: MockClient((req) async {
            expect(req.url.path, contains('/rpc/encrypted_record_cas'));
            if (mode == 'success') {
              return _jsonResp(req, {
                'success': true,
                'revision': 2,
                'server_seq': 7,
              });
            }
            if (mode == 'conflict') {
              return _jsonResp(req, {
                'success': false,
                'conflict': true,
                'revision': 5,
                'server_seq': 11.0,
              });
            }
            return _jsonResp(req, {'success': false, 'conflict': false});
          }),
        );

        final transport = SupabaseEncryptedRecordTransport(
          client: client,
          owner: owner,
        );

        final ok = await transport.compareAndSwap(
          route: 'rt-1',
          expectedRevision: 1,
          envelope: {'v': 1},
        );
        expect(ok.success, isTrue);
        expect(ok.revision, equals(2));
        expect(ok.serverSeq, equals(7));

        mode = 'conflict';
        final conflict = await transport.compareAndSwap(
          route: 'rt-1',
          expectedRevision: 1,
          envelope: {'v': 1},
        );
        expect(conflict.success, isFalse);
        expect(conflict.revision, equals(5));
        expect(conflict.serverSeq, equals(11));

        mode = 'invalid';
        await expectLater(
          () => transport.compareAndSwap(
            route: 'rt-1',
            expectedRevision: 1,
            envelope: {'v': 1},
          ),
          throwsFormatException,
        );
      },
    );

    test('pullSince parses list, enforces cursor >= 0, and rejects malformed responses', () async {
      var mode = 'valid';
      final client = _AuthedSupabaseClient(
        userId: owner,
        httpClient: MockClient((req) async {
          expect(req.url.path, contains('/rpc/encrypted_records_pull_since'));
          if (mode == 'not_list') {
            return _jsonResp(req, {'unexpected': true});
          }
          if (mode == 'bad_item') {
            return _jsonResp(req, ['not-a-map']);
          }
          return _jsonResp(req, [
            {
              'route': 'rt-a',
              'revision': 1,
              'server_seq': 10,
              'envelope': {'v': 1},
            },
            {
              'route': 'rt-b',
              'revision': 2,
              'server_seq': 11,
              'envelope': {'v': 1},
            },
          ]);
        }),
      );

      final transport = SupabaseEncryptedRecordTransport(
        client: client,
        owner: owner,
      );

      await expectLater(
        () => transport.pullSince(sinceSeq: -1),
        throwsArgumentError,
      );

      final items = await transport.pullSince(sinceSeq: 0, limit: 50);
      expect(items.length, equals(2));
      expect(items.last.serverSeq, equals(11));

      mode = 'not_list';
      await expectLater(
        () => transport.pullSince(sinceSeq: 0),
        throwsFormatException,
      );

      mode = 'bad_item';
      await expectLater(
        () => transport.pullSince(sinceSeq: 0),
        throwsFormatException,
      );
    });

    test('fails closed when authenticated user does not match owner', () async {
      final client = _AuthedSupabaseClient(
        userId: 'other-user',
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );
      final transport = SupabaseEncryptedRecordTransport(
        client: client,
        owner: owner,
      );

      await expectLater(() => transport.fetch('rt'), throwsStateError);
      await expectLater(
        () => transport.compareAndSwap(
          route: 'rt',
          expectedRevision: 0,
          envelope: const {},
        ),
        throwsStateError,
      );
      await expectLater(
        () => transport.pullSince(sinceSeq: 0),
        throwsStateError,
      );
    });
  });

  group('SupabaseRecoveryVaultTransport wire-level contract tests', () {
    const owner = 'vault-owner-1';

    test('fetch and createIfAbsent handle success, conflict, null, and invalid shapes', () async {
      var mode = 'ok';
      final client = _AuthedSupabaseClient(
        userId: owner,
        httpClient: MockClient((req) async {
          if (req.url.path.contains('/rpc/recovery_vault_create')) {
            if (mode == 'created') {
              return _jsonResp(req, {'success': true});
            }
            if (mode == 'conflict') {
              return _jsonResp(req, {'success': false, 'conflict': true});
            }
            return _jsonResp(req, {'success': false});
          }
          if (mode == 'null') {
            return _emptyMaybeSingleResp(req);
          }
          if (mode == 'bad_marker') {
            return _jsonResp(req, {'marker': 'not-a-map'});
          }
          return _jsonResp(req, {
            'marker': {'vaultId': 'v-123', 'v': 1},
          });
        }),
      );

      final transport = SupabaseRecoveryVaultTransport(
        client: client,
        owner: owner,
      );

      final marker = await transport.fetch();
      expect(marker?['vaultId'], equals('v-123'));

      mode = 'null';
      expect(await transport.fetch(), isNull);

      mode = 'bad_marker';
      await expectLater(() => transport.fetch(), throwsFormatException);

      mode = 'created';
      expect(await transport.createIfAbsent({'vaultId': 'v-1'}), isTrue);

      mode = 'conflict';
      expect(await transport.createIfAbsent({'vaultId': 'v-1'}), isFalse);

      mode = 'bad_rpc';
      await expectLater(
        () => transport.createIfAbsent({'vaultId': 'v-1'}),
        throwsFormatException,
      );
    });
  });

  group('E2eeService & EncryptedMediaTransfer edge-path coverage tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('E2eeService handles storage exceptions, clearKey, hasRemoteVault, and migration guards', () async {
      final brokenService = E2eeService(
        db: db,
        keyStore: RecoveryKeyStore(storage: const _ThrowingStorage()),
      );
      expect(await brokenService.isKeyInstalled('u1'), isFalse);
      expect(await brokenService.getKey('u1'), isNull);

      final vaultTransport = _InMemoryVaultTransport();
      final authedClient = _AuthedSupabaseClient(
        userId: 'target-user',
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );
      final service = E2eeService(
        db: db,
        client: authedClient,
        vaultTransportOverride: vaultTransport,
      );

      // Record transport resolves for matching owner, returns null for mismatched owner
      expect(service.getRecordTransport('target-user'), isNotNull);
      expect(service.getRecordTransport('wrong-user'), isNull);

      // Vault transport resolves directly when no override is set
      final directClientService = E2eeService(db: db, client: authedClient);
      expect(directClientService.getVaultTransport('target-user'), isNotNull);
      expect(directClientService.getVaultTransport('wrong-user'), isNull);

      // Migration guardrails
      await expectLater(
        () => service.migrateLocalKeyToAccount(
          targetOwnerId: 'target-user',
          userConfirmed: false,
        ),
        throwsStateError,
      );
      await expectLater(
        () => service.migrateLocalKeyToAccount(
          targetOwnerId: E2eeService.localUserId,
          userConfirmed: true,
        ),
        throwsArgumentError,
      );
      // No local key yet
      await expectLater(
        () => service.migrateLocalKeyToAccount(
          targetOwnerId: 'target-user',
          userConfirmed: true,
        ),
        throwsStateError,
      );

      // Install key on target-user -> migration blocked because target already has key
      await _createTestVault(service, 'target-user');
      expect(await service.hasRemoteVault('target-user'), isTrue);

      // Second setupNewVault on same owner throws conflict StateError
      await expectLater(
        () => _createTestVault(service, 'target-user'),
        throwsStateError,
      );

      await expectLater(
        () => service.migrateLocalKeyToAccount(
          targetOwnerId: 'target-user',
          userConfirmed: true,
        ),
        throwsStateError,
      );

      // Clear local key for target-user, remote vault still exists -> migration blocked
      await service.clearKey('target-user');
      expect(await service.isKeyInstalled('target-user'), isFalse);
      await expectLater(
        () => service.migrateLocalKeyToAccount(
          targetOwnerId: 'target-user',
          userConfirmed: true,
        ),
        throwsStateError,
      );

      // Falha de rede não deve ser confundida com cofre ausente.
      vaultTransport.throwOnFetch = true;
      await expectLater(
        () => service.hasRemoteVault('target-user'),
        throwsStateError,
      );
    });

    test('EncryptedMediaTransfer validates bucket, owner, mediaId, and cleans up failed uploads', () async {
      final key = SecretKey(List<int>.filled(32, 7));
      final deletedPaths = <String>[];
      var failOnManifest = false;

      final client = _AuthedSupabaseClient(
        userId: 'owner-1',
        httpClient: MockClient((req) async {
          if (req.method == 'DELETE') {
            final body = jsonDecode(req.body) as Map<String, dynamic>;
            final prefixes = (body['prefixes'] as List).cast<String>();
            deletedPaths.addAll(prefixes);
            return http.Response(
              jsonEncode([]),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (failOnManifest && req.url.path.contains('manifest.enc')) {
            return http.Response('Storage failure', 500);
          }
          return http.Response(
            jsonEncode({'Key': req.url.path}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final transfer = EncryptedMediaTransfer(
        client: client,
        owner: 'owner-1',
        key: key,
      );

      // Unsupported bucket
      await expectLater(
        () => transfer.uploadEncrypted(
          bucket: 'invalid_bucket',
          mediaId: 'm1',
          plaintextBytes: Uint8List.fromList([1, 2, 3]),
        ),
        throwsArgumentError,
      );

      // Invalid mediaId with path traversal
      await expectLater(
        () => transfer.uploadEncrypted(
          bucket: 'voice_notes',
          mediaId: '../escape',
          plaintextBytes: Uint8List.fromList([1, 2, 3]),
        ),
        throwsArgumentError,
      );

      // Empty owner
      final noOwner = EncryptedMediaTransfer(
        client: client,
        owner: '',
        key: key,
      );
      await expectLater(
        () => noOwner.uploadEncrypted(
          bucket: 'voice_notes',
          mediaId: 'm1',
          plaintextBytes: Uint8List.fromList([1, 2, 3]),
        ),
        throwsStateError,
      );

      // Failed manifest upload cleans up uploaded chunk
      failOnManifest = true;
      await expectLater(
        () => transfer.uploadEncrypted(
          bucket: 'voice_notes',
          mediaId: 'audio-fail',
          versionId: 'v1',
          plaintextBytes: Uint8List.fromList([9, 8, 7, 6]),
        ),
        throwsA(anything),
      );
      expect(
        deletedPaths.any((p) => p.contains('audio-fail/v_v1/chunk_0.enc')),
        isTrue,
      );
    });

    test('EncryptedRecordSync validates revision boundaries and RecoveryKeyStore options', () async {
      expect(RecoveryKeyStore.defaultIosOptions.synchronizable, isFalse);
      expect(
        RecoveryKeyStore.defaultIosOptions.accessibility,
        equals(KeychainAccessibility.first_unlock_this_device),
      );

      final key = await RecoveryCrypto.keyFromPhrase(
        RecoveryCrypto.createPhrase(),
      );
      final client = _AuthedSupabaseClient(
        userId: 'u-bounds',
        httpClient: MockClient((_) async => http.Response('null', 200)),
      );
      final sync = EncryptedRecordSync(
        owner: 'u-bounds',
        key: key,
        transport: SupabaseEncryptedRecordTransport(
          client: client,
          owner: 'u-bounds',
        ),
      );

      await expectLater(
        () => sync.read(
          entityType: 'people',
          entityId: 'p1',
          minimumRevision: -1,
        ),
        throwsArgumentError,
      );
      await expectLater(
        () => sync.write(
          entityType: 'people',
          entityId: 'p1',
          expectedRevision: -1,
          data: const {},
        ),
        throwsArgumentError,
      );
    });
  });
}
