import 'dart:convert';

import 'package:drift/native.dart';
import 'package:eas_client/eas_client.dart' as eas;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/inbox/exchange_service.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeExchange implements ExchangeSession {
  FakeExchange(this.pages, {this.failureAt});
  final List<eas.SyncResult> pages;
  final int? failureAt;
  final List<String> keys = [];
  bool closed = false;
  @override
  Future<String> inboxId() async => 'inbox';
  @override
  Future<List<eas.EasFolder>> mailFolders() async => const [eas.EasFolder(serverId: 'inbox', parentId: '0', displayName: 'Inbox', type: eas.EasFolderType.defaultInbox)];
  @override
  Future<eas.SyncResult> readPage(String folder, String key) async {
    keys.add(key);
    if (failureAt == keys.length) throw StateError('sensitive secret');
    return pages[keys.length - 1];
  }
  @override
  void close() { closed = true; }
}

class MultiFolderExchange implements ExchangeSession {
  final List<String> calls = [];
  @override
  Future<String> inboxId() async => 'inbox';
  @override
  Future<List<eas.EasFolder>> mailFolders() async => const [
    eas.EasFolder(serverId: 'inbox', parentId: '0', displayName: 'Entrada', type: eas.EasFolderType.defaultInbox),
    eas.EasFolder(serverId: 'sent', parentId: '0', displayName: 'Enviados', type: eas.EasFolderType.defaultSentItems),
  ];
  @override
  Future<eas.SyncResult> readPage(String folder, String key) async {
    calls.add('$folder:$key');
    return eas.SyncResult(status: 1, syncKey: key == '0' ? '${folder}_1' : '${folder}_2',
      collectionId: folder, addedEmails: key == '0' ? [] : [
        eas.EasEmail(serverId: 'same-id', subject: 'Mensagem $folder', body: 'Corpo $folder'),
      ]);
  }
  @override
  void close() {}
}

eas.SyncResult page(String key, {int status = 1, bool more = false, List<eas.EasEmail> emails = const [], List<String> deleted = const []}) =>
  eas.SyncResult(status: status, syncKey: key, collectionId: 'inbox', addedEmails: emails, deletedIds: deleted, moreAvailable: more);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());
  Future<ExchangeReadResult> sync(FakeExchange fake, {int maxPages = 50}) => ExchangeReadService(db).sync(
      session: fake, host: 'mail.example.org', account: 'user@example.org', deviceId: 'device1', maxPages: maxPages);

  test('páginas são salvas com chave e exclusões remotas não apagam prévias', () async {
    const mail = eas.EasEmail(serverId: 'm1', subject: 'Teste', from: 'from@example.org', body: 'Mensagem');
    final first = FakeExchange([page('k1'), page('k2', more: true, emails: [mail]), page('k3', deleted: ['m1'])]);
    final result = await sync(first);
    expect(result.saved, 1);
    expect(result.moreAvailable, isFalse);
    expect(first.keys, ['0', 'k1', 'k2']);
    expect(first.closed, isTrue);
    final items = await db.select(db.inboxEntries).get();
    expect(items.length, 1);
    expect((jsonDecode(items.single.metadata) as Map)['exchangePreview'], isTrue);
    expect(items.single.deletedAt, isNull);
    final queue = await db.select(db.syncQueue).get();
    expect(queue.single.entityType, 'inbox_entries');
    expect(queue.single.entityId, items.single.id);
    expect(queue.single.operation, 'INSERT');
    final second = FakeExchange([page('k4', emails: [mail])]);
    expect((await sync(second)).saved, 0);
    expect(second.keys, ['k3']);
  });

  test('falha interrompe sem avançar chave do lote e nova execução retoma', () async {
    const mail = eas.EasEmail(serverId: 'm1', subject: 'Teste', body: 'Texto');
    final first = FakeExchange([page('k1'), page('k2', more: true, emails: [mail])], failureAt: 3);
    await expectLater(sync(first), throwsA(isA<ExchangeException>()
        .having((e) => e.message, 'no secret', isNot(contains('secret')))));
    expect(first.closed, isTrue);
    expect((await db.select(db.inboxEntries).get()).length, 1);
    final retry = FakeExchange([page('k3')]);
    await sync(retry);
    expect(retry.keys, ['k2']);
  });

  test('chave expirada reinicia sem excluir mensagens locais', () async {
    final first = FakeExchange([page('k1'), page('k2', emails: [const eas.EasEmail(serverId: 'm', body: 'x')])]);
    await sync(first);
    final retry = FakeExchange([page('k2', status: 3), page('j1'), page('j2')]);
    await sync(retry);
    expect(retry.keys, ['k2', '0', 'j1']);
    expect((await db.select(db.inboxEntries).get()).length, 1);
  });

  test('limite informa que ainda há mais páginas', () async {
    final first = FakeExchange([page('k1'), page('k2', more: true)]);
    final result = await sync(first, maxPages: 2);
    expect(result.moreAvailable, isTrue);
  });

  test('pastas recebem chaves independentes e prévias enfileiradas', () async {
    final session = MultiFolderExchange();
    final result = await ExchangeReadService(db).sync(session: session,
      host: 'mail.example.org', account: 'user', deviceId: 'device1', allMailFolders: true);
    expect(result.foldersRead, 2);
    expect(result.saved, 2);
    expect(result.moreAvailable, isFalse);
    expect(session.calls, ['inbox:0', 'inbox:inbox_1', 'sent:0', 'sent:sent_1']);
    final rows = await db.select(db.inboxEntries).get();
    final names = rows.map((row) => (jsonDecode(row.metadata)['email'] as Map)['folderName']).toSet();
    expect(names, {'Entrada', 'Enviados'});
    expect((await db.select(db.syncQueue).get()).length, 2);
    final second = MultiFolderExchange();
    await ExchangeReadService(db).sync(session: second, host: 'mail.example.org',
        account: 'user', deviceId: 'device1', allMailFolders: true);
    expect(second.calls, ['inbox:inbox_2', 'sent:sent_2']);
    expect((await db.select(db.inboxEntries).get()).length, 2);
    expect((await db.select(db.syncQueue).get()).length, 2);
  });

  test('falha ao enfileirar prévia reverte página e chave Exchange', () async {
    await db.customStatement("CREATE TRIGGER reject_queue BEFORE INSERT ON sync_queue BEGIN SELECT RAISE(ABORT, 'queue failed'); END");
    final fake = FakeExchange([page('k1'), page('k2', emails: [const eas.EasEmail(serverId: 'x', body: 'x')])]);
    await expectLater(sync(fake), throwsA(isA<ExchangeException>()));
    expect(await db.select(db.inboxEntries).get(), isEmpty);
    expect(await db.select(db.syncQueue).get(), isEmpty);
    await db.customStatement('DROP TRIGGER reject_queue');
    final retry = FakeExchange([page('k2', emails: [const eas.EasEmail(serverId: 'x', body: 'x')])]);
    expect((await sync(retry)).saved, 1);
    expect(retry.keys, ['k1']);
  });

  test('prévia enfileirada atravessa push e pull simulados para outro dispositivo', () async {
    const mail = eas.EasEmail(serverId: 'm1', subject: 'Teste', from: 'from@example.org', body: 'Texto');
    await sync(FakeExchange([page('k1'), page('k2', emails: [mail])]));
    Map<String, dynamic>? stored;
    final httpClient = MockClient((request) async {
      Object body = <dynamic>[];
      if (request.method == 'POST' && request.url.path.endsWith('/rpc/sync_upsert_if_unchanged')) {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['p_table'], 'inbox_entries');
        stored = Map<String, dynamic>.from(payload['p_payload'] as Map);
        body = {'success': true};
      } else if (request.method == 'GET' && request.url.path.endsWith('/inbox_entries') && stored != null) {
        body = [stored!];
      }
      return http.Response(jsonEncode(body), 200, request: request,
          headers: {'content-type': 'application/json', 'content-range': '*/0'});
    });
    final client = SupabaseClient('https://mock.supabase.co', 'dummy-key', httpClient: httpClient);
    final sender = SupabaseSyncService(allowLegacySyncForTesting: true, db: db, repository: AppRepository(db), clientOverride: client);
    addTearDown(sender.dispose);
    final pushed = await sender.processQueue();
    expect(pushed.success, isTrue, reason: pushed.errors.toString());
    expect((await db.select(db.syncQueue).get()).single.status, 'synced');
    expect(stored, isNotNull);
    final other = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(other.close);
    final receiver = SupabaseSyncService(allowLegacySyncForTesting: true, db: other, repository: AppRepository(other), clientOverride: client);
    addTearDown(receiver.dispose);
    final pulled = await receiver.fetchRemoteChanges();
    expect(pulled.success, isTrue, reason: pulled.errors.toString());
    final copied = (await other.select(other.inboxEntries).get()).single;
    final email = (jsonDecode(copied.metadata) as Map)['email'] as Map;
    expect(email['subject'], 'Teste');
    expect(email['bodyText'], contains('Texto'));
    expect(email['isPermanentRetained'], isFalse);
  });

  test('FolderSync usa HTTPS, sem redirecionamento e decodifica INBOX', () async {
    eas.WbxmlElement node(String tag, {String? text, List<eas.WbxmlElement>? children}) =>
        eas.WbxmlElement(namespace: 'FolderHierarchy', tag: tag, text: text, children: children, codePageIndex: 7);
    final response = eas.WbxmlEncoder().encode(eas.WbxmlDocument(root: node('FolderSync', children: [
      node('Status', text: '1'), node('SyncKey', text: '1'), node('Changes', children: [
        node('Count', text: '1'), node('Add', children: [node('ServerId', text: 'inbox'),
          node('ParentId', text: '0'), node('DisplayName', text: 'Inbox'), node('Type', text: '2')])])])));
    final client = MockClient((request) async {
      expect(request.url.scheme, 'https');
      expect(request.url.host, 'mail.example.org');
      expect(request.url.path, '/Microsoft-Server-ActiveSync');
      expect(request.url.queryParameters['Cmd'], 'FolderSync');
      expect(request.followRedirects, isFalse);
      return http.Response.bytes(response, 200);
    });
    final session = ExchangeProtocolSession(host: 'mail.example.org', username: 'user',
        password: 'secret', deviceId: 'device1', httpClient: client);
    expect(await session.inboxId(), 'inbox');
    session.close();
  });

  test('pedido de política é recusado sem confirmação de conformidade', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['Cmd'], 'FolderSync');
      return http.Response('', 449);
    });
    final session = ExchangeProtocolSession(host: 'mail.example.org', username: 'user',
        password: 'secret', deviceId: 'device1', httpClient: client);
    await expectLater(ExchangeReadService(db).sync(session: session, host: 'mail.example.org',
      account: 'user', deviceId: 'device1'),
      throwsA(isA<ExchangeException>().having((e) => e.message, 'políticas', contains('políticas'))));
    expect(await db.select(db.inboxEntries).get(), isEmpty);
  });

  test('rejeita URL em vez de hostname antes de enviar credenciais', () {
    expect(() => ExchangeProtocolSession(host: 'https://mail.example.org', username: 'u', password: 'p', deviceId: 'd'),
      throwsA(isA<ExchangeException>()));
  });
}
