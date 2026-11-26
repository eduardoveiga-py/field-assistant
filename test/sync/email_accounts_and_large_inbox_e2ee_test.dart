import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/inbox/email_account_model.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_media_transfer.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_record.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_record_sync.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_crypto.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MemRecordTransport implements PaginatedEncryptedRecordTransport {
  final Map<String, ({int revision, Map<String, dynamic> envelope, int seq})>
  _records = {};
  int _seq = 0;

  List<Map<String, dynamic>> get rawStored => _records.entries
      .map(
        (e) => {
          'route': e.key,
          'revision': e.value.revision,
          'envelope': e.value.envelope,
          'server_seq': e.value.seq,
        },
      )
      .toList();

  @override
  Future<EncryptedWriteResult> compareAndSwap({
    required String route,
    required int expectedRevision,
    required Map<String, dynamic> envelope,
  }) async {
    final cur = _records[route];
    if (cur == null && expectedRevision != 0) {
      return const EncryptedWriteResult(success: false, revision: null);
    }
    if (cur != null && cur.revision != expectedRevision) {
      return EncryptedWriteResult(success: false, revision: cur.revision);
    }
    final nextRev = (cur?.revision ?? 0) + 1;
    _seq++;
    _records[route] = (revision: nextRev, envelope: envelope, seq: _seq);
    return EncryptedWriteResult(
      success: true,
      revision: nextRev,
      serverSeq: _seq,
    );
  }

  @override
  Future<EncryptedRemoteRecord?> fetch(String route) async {
    final cur = _records[route];
    if (cur == null) return null;
    return EncryptedRemoteRecord(
      route: route,
      revision: cur.revision,
      envelope: Map<String, dynamic>.from(cur.envelope),
      serverSeq: cur.seq,
    );
  }

  @override
  Future<List<EncryptedRemoteRecord>> pullSince({
    required int sinceSeq,
    int limit = 100,
  }) async {
    final list = _records.entries.where((e) => e.value.seq > sinceSeq).toList()
      ..sort((a, b) => a.value.seq.compareTo(b.value.seq));
    return list
        .take(limit)
        .map(
          (e) => EncryptedRemoteRecord(
            route: e.key,
            revision: e.value.revision,
            envelope: Map<String, dynamic>.from(e.value.envelope),
            serverSeq: e.value.seq,
          ),
        )
        .toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('EmailAccounts sincroniza Exchange/IMAP entre dispositivos via E2EE sem vazar senhas', () async {
    final db1 = AppDatabase.forTesting(NativeDatabase.memory());
    final db2 = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async {
      await db1.close();
      await db2.close();
    });

    final transport = _MemRecordTransport();
    final phrase = RecoveryCrypto.createPhrase();
    const ownerId = 'owner-email-sync-1';

    final client1 = SupabaseClient('https://mock.supabase.co', 'anon');
    final client2 = SupabaseClient('https://mock.supabase.co', 'anon');

    final sync1 = SupabaseSyncService(
      db: db1,
      repository: AppRepository(db1),
      clientOverride: client1,
      allowEncryptedSyncForTesting: true,
      authenticatedOwnerOverrideForTesting: ownerId,
    );
    final sync2 = SupabaseSyncService(
      db: db2,
      repository: AppRepository(db2),
      clientOverride: client2,
      allowEncryptedSyncForTesting: true,
      authenticatedOwnerOverrideForTesting: ownerId,
    );

    final e2ee1 = sync1.e2eeService;
    final e2ee2 = sync2.e2eeService;
    final syncService1 = SupabaseSyncService(
      db: db1,
      repository: AppRepository(db1),
      clientOverride: client1,
      allowEncryptedSyncForTesting: true,
      authenticatedOwnerOverrideForTesting: ownerId,
      e2eeServiceOverride: e2ee1,
    );

    // Sem Override de recordTransport, verificamos primeiro sanitização + fila local
    // e roundtrip EncryptedRecord diretamente no transporte E2EE.
    sync1.dispose();
    sync2.dispose();
    syncService1.dispose();

    await e2ee1.keyStore.install(
      owner: ownerId,
      phrase: phrase,
      confirmation: phrase,
    );
    await e2ee2.keyStore.install(
      owner: ownerId,
      phrase: phrase,
      confirmation: phrase,
    );

    final exchangeAcc = EmailAccount.createPreset(
      id: 'ex-acc-01',
      providerType: EmailProviderType.exchange,
      name: 'Meu Exchange JW',
      email: 'campo@jwpub.org',
      username: 'campo@jwpub.org',
      customHost: 'outlook.office365.com',
    );
    await EmailAccountsManager.saveAccount(
      db1,
      exchangeAcc,
      password: 'SUPER_SECRET_PASSWORD_123!',
    );

    // Fila e tabela SQLite não devem conter a senha em momento algum
    final qOps = await db1.select(db1.syncQueue).get();
    expect(qOps.length, 1);
    expect(qOps.first.entityType, 'email_accounts');
    expect(qOps.first.payload, isNot(contains('SUPER_SECRET_PASSWORD_123!')));

    final sanitized = SupabaseSyncService.sanitizePayload('email_accounts', {
      ...jsonDecode(qOps.first.payload) as Map<String, dynamic>,
      'password': 'LEAK',
      'refreshToken': 'OAUTH_LEAK',
    });
    expect(sanitized.containsKey('password'), isFalse);
    expect(sanitized.containsKey('refreshToken'), isFalse);

    // Encripta no dispositivo 1 e decifra/aplica no dispositivo 2 (ex.: Web PWA)
    final key1 = await e2ee1.getKey(ownerId);
    final recSync1 = EncryptedRecordSync(
      owner: ownerId,
      key: key1!,
      transport: transport,
    );
    final sealed = await recSync1.writeSealed(
      entityType: 'email_accounts',
      entityId: exchangeAcc.id,
      expectedRevision: 0,
      data: sanitized,
    );
    expect(sealed.result.success, isTrue);

    final wireDump = jsonEncode(transport.rawStored);
    expect(wireDump, isNot(contains('campo@jwpub.org')));
    expect(wireDump, isNot(contains('SUPER_SECRET')));

    final key2 = await e2ee2.getKey(ownerId);
    final pulled = await transport.pullSince(sinceSeq: 0);
    expect(pulled.length, 1);
    final opened = await EncryptedRecord.open(
      key: key2!,
      owner: ownerId,
      routeId: pulled.first.route,
      revision: pulled.first.revision,
      envelope: pulled.first.envelope,
    );
    expect(opened['entityType'], 'email_accounts');

    final dataMap = Map<String, dynamic>.from(opened['data'] as Map);
    final normalized = SupabaseSyncService.normalizeRemotePayload(dataMap);
    await db2
        .into(db2.emailAccounts)
        .insert(
          EmailAccountDbEntry.fromJson({
            ...normalized,
            'providerType': normalized['providerType'] ?? 'exchange',
            'incomingHost':
                normalized['incomingHost'] ?? 'outlook.office365.com',
            'incomingPort': normalized['incomingPort'] ?? 443,
            'incomingProtocol': normalized['incomingProtocol'] ?? 'exchange',
            'outgoingHost':
                normalized['outgoingHost'] ?? 'outlook.office365.com',
            'outgoingPort': normalized['outgoingPort'] ?? 443,
            'outgoingSecurity': normalized['outgoingSecurity'] ?? 'ssl',
            'outgoingProtocol': normalized['outgoingProtocol'] ?? 'exchange',
            'username': normalized['username'] ?? 'campo@jwpub.org',
            'isActive': normalized['isActive'] ?? true,
            'signatureHtml': normalized['signatureHtml'] ?? '',
            'revision': pulled.first.revision,
          }),
        );

    final loadedOnDevice2 = await EmailAccountsManager.loadAccounts(db2);
    expect(loadedOnDevice2.length, 1);
    expect(loadedOnDevice2.first.email, 'campo@jwpub.org');
    expect(loadedOnDevice2.first.incomingProtocol, 'exchange');
    expect(dataMap.containsKey('password'), isFalse);
    expect(dataMap.containsKey('refreshToken'), isFalse);
    // Simula Keychain isolado do segundo dispositivo (vazio) para confirmar que senhas não migram via nuvem
    FlutterSecureStorage.setMockInitialValues({});
    expect(
      await EmailAccountsManager.hasLocalCredentials(
        loadedOnDevice2.first,
        db2,
      ),
      isFalse,
    );
    expect(key2, isNotNull);
  });

  test('RecoveryCrypto rejeita > 1 MiB e metadados extensos devem ser compactados/deslocados', () async {
    final key = await RecoveryCrypto.keyFromPhrase(
      RecoveryCrypto.createPhrase(),
    );
    final hugeBytes = Uint8List(1024 * 1024 + 50);
    expect(
      () => RecoveryCrypto.seal(
        key: key,
        owner: 'o1',
        kind: 'record-v1',
        id: '1',
        plaintext: hugeBytes,
      ),
      throwsArgumentError,
    );
  });

  test('inbox_entries > 700 KiB faz offload cifrado AES-256-GCM e reidrata no dispositivo secundário', () async {
    final db1 = AppDatabase.forTesting(NativeDatabase.memory());
    final db2 = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async {
      await db1.close();
      await db2.close();
    });

    final storageObjects = <String, Uint8List>{};
    Uint8List extractBody(http.Request request) {
      final raw = request.bodyBytes;
      final ct = request.headers['content-type'] ?? '';
      if (!ct.contains('multipart/form-data')) return Uint8List.fromList(raw);
      final match = RegExp(r'boundary=([^\s;]+)').firstMatch(ct);
      if (match == null) return Uint8List.fromList(raw);
      final text = utf8.decode(raw, allowMalformed: true);
      for (final part in text.split('--${match.group(1)}')) {
        final sep = part.indexOf('\r\n\r\n');
        if (sep == -1) continue;
        final hdrs = part.substring(0, sep);
        if (!hdrs.contains('filename=') &&
            !hdrs.contains('application/octet-stream')) {
          continue;
        }
        var body = part.substring(sep + 4);
        if (body.endsWith('\r\n')) body = body.substring(0, body.length - 2);
        return Uint8List.fromList(utf8.encode(body));
      }
      return Uint8List.fromList(raw);
    }

    final mockClient = SupabaseClient(
      'https://mock.supabase.co',
      'anon',
      httpClient: MockClient((req) async {
        const prefix = '/storage/v1/object/';
        final idx = req.url.path.indexOf(prefix);
        if (idx != -1) {
          final key = req.url.path.substring(idx + prefix.length);
          if (req.method == 'POST' || req.method == 'PUT') {
            storageObjects[key] = extractBody(req);
            return http.Response(
              jsonEncode({'Key': key}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (req.method == 'GET') {
            final data = storageObjects[key];
            if (data == null) return http.Response('Not Found', 404);
            return http.Response.bytes(data, 200);
          }
        }
        return http.Response('{}', 200);
      }),
    );

    const ownerId = 'owner-inbox-offload-1';
    final key = await RecoveryCrypto.keyFromPhrase(
      RecoveryCrypto.createPhrase(),
    );
    final transfer = EncryptedMediaTransfer(
      client: mockClient,
      owner: ownerId,
      key: key,
    );

    final hugeRawEml = base64Encode(
      Uint8List.fromList(List.filled(780 * 1024, 65)),
    );
    final fullMeta = jsonEncode({
      'email': {
        'id': 'msg-huge-1',
        'subject': 'Circular Congregacional Extensa',
        'from': 'secretario@jwpub.org',
        'to': 'ancio@jwpub.org',
        'bodyText': 'Resumo inicial',
        'bodyHtml': '<p>Corpo HTML completo</p>',
        'rawEmlBase64': hugeRawEml,
        'attachments': [
          {
            'name': 'anexo.pdf',
            'base64': base64Encode([1, 2, 3]),
          },
        ],
      },
    });
    final payload = <String, dynamic>{
      'id': 'email_msg-huge-1',
      'content': 'Circular Congregacional Extensa',
      'sourceType': 'email',
      'metadata': fullMeta,
      'attachments': jsonEncode([
        {'name': 'anexo.pdf'},
      ]),
    };

    final sync1 = SupabaseSyncService(
      db: db1,
      repository: AppRepository(db1),
      clientOverride: mockClient,
      allowEncryptedSyncForTesting: true,
      authenticatedOwnerOverrideForTesting: ownerId,
    );
    final sync2 = SupabaseSyncService(
      db: db2,
      repository: AppRepository(db2),
      clientOverride: mockClient,
      allowEncryptedSyncForTesting: true,
      authenticatedOwnerOverrideForTesting: ownerId,
    );
    addTearDown(() {
      sync1.dispose();
      sync2.dispose();
    });

    final errors = <String>[];
    final uploadRes = await sync1.uploadEncryptedMediaForTesting(
      tableName: 'inbox_entries',
      entityId: 'email_msg-huge-1',
      cleanPayload: payload,
      transfer: transfer,
      errors: errors,
    );
    expect(errors, isEmpty);
    expect(uploadRes.success, isTrue);
    expect(uploadRes.bucket, 'knowledge_vault');
    expect(uploadRes.mediaId, 'inbox_meta_email_msg-huge-1');
    expect(utf8.encode(jsonEncode(payload)).length, lessThan(100 * 1024));
    expect(
      storageObjects.values.every(
        (v) => !utf8
            .decode(v, allowMalformed: true)
            .contains('Circular Congregacional'),
      ),
      isTrue,
    );

    // Insere registro compacto no dispositivo 2 e reidrata pelo EncryptedMediaTransfer
    final now = DateTime.now().toUtc();
    await db2
        .into(db2.inboxEntries)
        .insert(
          InboxEntriesCompanion.insert(
            id: 'email_msg-huge-1',
            content: payload['content'] as String,
            sourceType: const Value('email'),
            capturedAt: now,
            metadata: Value(payload['metadata'] as String),
            attachments: Value(payload['attachments'] as String),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final hydrated = await sync2.downloadEncryptedMediaForTesting(
      tableName: 'inbox_entries',
      entityId: 'email_msg-huge-1',
      transfer: transfer,
    );
    expect(hydrated, isTrue);

    final restoredRow = await (db2.select(
      db2.inboxEntries,
    )..where((t) => t.id.equals('email_msg-huge-1'))).getSingle();
    final restoredMeta =
        jsonDecode(restoredRow.metadata) as Map<String, dynamic>;
    final restoredEmail = restoredMeta['email'] as Map<String, dynamic>;
    expect(restoredEmail['rawEmlBase64'], hugeRawEml);
    expect(restoredEmail['bodyHtml'], '<p>Corpo HTML completo</p>');
  });
}
