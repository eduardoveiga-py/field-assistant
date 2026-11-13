import 'dart:convert';

import 'package:drift/native.dart';
import 'package:eas_client/eas_client.dart' as eas;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/inbox/exchange_service.dart';

class FakeExchange implements ExchangeSession {
  FakeExchange(this.pages, {this.failureAt});
  final List<eas.SyncResult> pages;
  final int? failureAt;
  final List<String> keys = [];
  bool closed = false;
  @override
  Future<String> inboxId() async => 'inbox';
  @override
  Future<eas.SyncResult> readPage(String folder, String key) async {
    keys.add(key);
    if (failureAt == keys.length) throw StateError('sensitive secret');
    return pages[keys.length - 1];
  }
  @override
  void close() { closed = true; }
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
