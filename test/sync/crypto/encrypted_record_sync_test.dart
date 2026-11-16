import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_record_sync.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemoryTransport implements EncryptedRecordTransport {
  final Map<String, EncryptedRemoteRecord> rows = {};
  int writes = 0;

  @override
  Future<EncryptedRemoteRecord?> fetch(String route) async => rows[route];

  @override
  Future<EncryptedWriteResult> compareAndSwap({required String route, required int expectedRevision,
      required Map<String, dynamic> envelope}) async {
    writes++;
    final existing = rows[route];
    if ((existing?.revision ?? 0) != expectedRevision) {
      return EncryptedWriteResult(success: false, revision: existing?.revision);
    }
    final revision = expectedRevision + 1;
    rows[route] = EncryptedRemoteRecord(route: route, revision: revision, envelope: envelope);
    return EncryptedWriteResult(success: true, revision: revision);
  }
}

void main() {
  test('dois aparelhos trocam envelopes sem texto claro e detectam concorrência', () async {
    final phrase = RecoveryCrypto.createPhrase();
    final transport = MemoryTransport();
    final first = EncryptedRecordSync(owner: 'owner', key: await RecoveryCrypto.keyFromPhrase(phrase), transport: transport);
    final second = EncryptedRecordSync(owner: 'owner', key: await RecoveryCrypto.keyFromPhrase(phrase), transport: transport);
    final result = await first.write(entityType: 'people', entityId: 'person-1',
        expectedRevision: 0, data: {'id': 'person-1', 'name': 'Nome secreto'});
    expect(result.success, isTrue);
    expect(jsonEncode(transport.rows.values.single.envelope), isNot(contains('Nome secreto')));
    expect(jsonEncode(transport.rows.values.single.envelope), isNot(contains('person-1')));
    final read = await second.read(entityType: 'people', entityId: 'person-1');
    expect(read, {'revision': 1, 'data': {'id': 'person-1', 'name': 'Nome secreto'}});
    expect((await second.write(entityType: 'people', entityId: 'person-1',
      expectedRevision: 1, data: {'name': 'Novo'})).success, isTrue);
    final conflict = await first.write(entityType: 'people', entityId: 'person-1',
      expectedRevision: 1, data: {'name': 'Outra alteração'});
    expect(conflict.success, isFalse);
    expect(conflict.revision, 2);
    expect((await first.read(entityType: 'people', entityId: 'person-1'))!['data'], {'name': 'Novo'});
  });

  test('checkpoint conhecido rejeita ausência, replay, adulteração e chave diferente', () async {
    final key = await RecoveryCrypto.keyFromPhrase(RecoveryCrypto.createPhrase());
    final transport = MemoryTransport();
    final sync = EncryptedRecordSync(owner: 'owner', key: key, transport: transport);
    await sync.write(entityType: 'people', entityId: 'p', expectedRevision: 0, data: {'name': 'v1'});
    final route = transport.rows.keys.single;
    final old = transport.rows[route]!;
    await sync.write(entityType: 'people', entityId: 'p', expectedRevision: 1, data: {'name': 'v2'});
    transport.rows[route] = old;
    await expectLater(sync.read(entityType: 'people', entityId: 'p', minimumRevision: 2), throwsStateError);
    transport.rows.remove(route);
    await expectLater(sync.read(entityType: 'people', entityId: 'p', minimumRevision: 1), throwsStateError);
    expect(await sync.read(entityType: 'people', entityId: 'p'), isNull);
    final tag = old.envelope['tag'] as String;
    transport.rows[route] = EncryptedRemoteRecord(route: route, revision: 1,
      envelope: {...old.envelope, 'tag': '${tag[0] == 'A' ? 'B' : 'A'}${tag.substring(1)}'});
    await expectLater(sync.read(entityType: 'people', entityId: 'p'), throwsA(anything));
    final wrong = EncryptedRecordSync(owner: 'owner', key: await RecoveryCrypto.keyFromPhrase(RecoveryCrypto.createPhrase()), transport: transport);
    expect(await wrong.read(entityType: 'people', entityId: 'p'), isNull);
    // Sem um marcador de cofre, ausência com outra chave não comprova cofre vazio.
  });

  test('conta não autenticada falha antes de acessar rede', () async {
    var requests = 0;
    final client = SupabaseClient('https://example.supabase.co', 'dummy-key', httpClient: MockClient((request) async {
      requests++;
      return http.Response('{}', 200);
    }));
    final transport = SupabaseEncryptedRecordTransport(client: client, owner: 'owner');
    await expectLater(transport.fetch('a' * 64), throwsStateError);
    await expectLater(transport.compareAndSwap(route: 'a' * 64, expectedRevision: 0, envelope: {}), throwsStateError);
    expect(requests, 0);
    client.dispose();
  });
}
