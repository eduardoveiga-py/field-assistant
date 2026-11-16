import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:enough_mail/imap.dart' as mail;
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/core/biometric_auth_service.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/inbox/jw_email_service.dart';

class FakeSession implements JwImapSession {
  FakeSession(this.uids, {this.validity = 7, this.failPage, this.incompletePage, this.connectError, this.selectError});
  final List<int> uids;
  final int validity;
  final int? failPage;
  final int? incompletePage;
  final Object? connectError;
  final Object? selectError;
  bool searched = false;
  final List<List<int>> fetched = [];
  bool closed = false;

  @override
  Future<void> connect(String host, int port, String username, String password, Duration timeout) async {
    if (connectError != null) throw connectError!;
  }
  @override
  Future<int> selectInbox() async {
    if (selectError != null) throw selectError!;
    return validity;
  }
  @override
  Future<List<int>> searchUids() async {
    searched = true;
    return List.of(uids.reversed);
  }
  @override
  Future<List<JwEmailMessage>> fetchUids(List<int> ids) async {
    fetched.add(List.of(ids));
    if (fetched.length == failPage) throw const JwEmailConnectionException('interrompido');
    final selected = fetched.length == incompletePage ? ids.skip(1) : ids;
    return selected.map((id) => JwEmailMessage(
      id: 'temp_$id', remoteUid: id, subject: 'Mensagem $id',
      from: 'a@example.org', to: 'b@example.org', date: DateTime.utc(2026),
      bodyText: 'Corpo $id', rawEmlBase64: base64Encode(utf8.encode('MIME $id')),
    )).toList();
  }
  @override
  Future<void> close() async { closed = true; }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  JwEmailService service(JwImapSession session) => JwEmailService(
    db: db, biometricAuth: BiometricAuthService(),
    imapClient: JwImapClient(sessionFactory: (_) => session),
  );

  test('verificação IMAP acessa INBOX sem listar ou baixar mensagens', () async {
    final session = FakeSession(List.generate(1000, (i) => i + 1));
    await JwImapClient(sessionFactory: (_) => session).verifyConnection(
      host: 'imap.example.org', port: 993, username: 'a@example.org', password: 'secret');
    expect(session.searched, isFalse);
    expect(session.fetched, isEmpty);
    expect(session.closed, isTrue);
  });

  test('falhas IMAP identificam etapa e não revelam conteúdo da exceção', () async {
    for (final entry in <(Object, String)>[
      (const SocketException('secret'), 'conexão e autenticação'),
      (TimeoutException('secret'), 'conexão e autenticação'),
    ]) {
      final session = FakeSession([], connectError: entry.$1);
      await expectLater(
        JwImapClient(sessionFactory: (_) => session).verifyConnection(
          host: 'imap.example.org', port: 993, username: 'a@example.org', password: 'secret'),
        throwsA(isA<JwEmailConnectionException>()
            .having((e) => e.message, 'etapa', contains(entry.$2))
            .having((e) => e.message, 'sigilo', isNot(contains('secret')))),
      );
      expect(session.closed, isTrue);
    }
    final session = FakeSession([], selectError: StateError('secret'));
    await expectLater(
      JwImapClient(sessionFactory: (_) => session).verifyConnection(
        host: 'imap.example.org', port: 993, username: 'a@example.org', password: 'secret'),
      throwsA(isA<JwEmailConnectionException>()
          .having((e) => e.message, 'etapa', contains('abertura da INBOX'))
          .having((e) => e.message, 'sigilo', isNot(contains('secret')))),
    );
    expect(session.closed, isTrue);
  });

  test('importa mais de 25, pagina e não baixa UIDs já persistidos', () async {
    final ids = List.generate(73, (i) => i + 1);
    final first = FakeSession(ids);
    final count = await service(first).syncEmails(username: 'a@example.org', password: 'pw');
    expect(count, 73);
    expect(first.fetched.length, 8);
    expect(first.fetched.every((page) => page.length <= 10), isTrue);
    expect(first.closed, isTrue);
    expect((await db.select(db.inboxEntries).get()).length, 73);
    final retry = FakeSession([...ids, 90]);
    expect(await service(retry).syncEmails(username: 'a@example.org', password: 'pw'), 1);
    expect(retry.fetched.expand((page) => page).toList(), [90]);
  });

  test('UID antigo ausente é buscado mesmo após UIDs mais altos', () async {
    expect(await service(FakeSession([1, 3, 10, 80])).syncEmails(
      username: 'a@example.org', password: 'pw'), 4);
    final next = FakeSession([1, 2, 3, 10, 80]);
    expect(await service(next).syncEmails(username: 'a@example.org', password: 'pw'), 1);
    expect(next.fetched.single, [2]);
  });

  test('lista de UIDs inválida é rejeitada sem importar dados', () async {
    final session = FakeSession([1, 2, 2]);
    await expectLater(service(session).syncEmails(username: 'a@example.org', password: 'pw'),
        throwsA(isA<JwEmailConnectionException>()));
    expect(await db.select(db.inboxEntries).get(), isEmpty);
    expect(session.closed, isTrue);
  });

  test('falha intermediária preserva páginas e a próxima execução retoma', () async {
    final ids = List.generate(42, (i) => i + 1);
    final failing = FakeSession(ids, failPage: 3);
    await expectLater(service(failing).syncEmails(username: 'a@example.org', password: 'pw'),
        throwsA(isA<JwEmailConnectionException>()));
    expect((await db.select(db.inboxEntries).get()).length, 20);
    expect(failing.closed, isTrue);
    final retry = FakeSession(ids);
    expect(await service(retry).syncEmails(username: 'a@example.org', password: 'pw'), 22);
    expect(retry.fetched.expand((p) => p).toList(), ids.skip(20).toList());
    expect((await db.select(db.inboxEntries).get()).length, 42);
  });

  test('página incompleta não é confirmada e pode ser repetida', () async {
    final ids = List.generate(31, (i) => i + 1);
    final failing = FakeSession(ids, incompletePage: 2);
    await expectLater(service(failing).syncEmails(username: 'a@example.org', password: 'pw'),
        throwsA(isA<JwEmailConnectionException>()));
    expect((await db.select(db.inboxEntries).get()).length, 10);
    expect(await service(FakeSession(ids)).syncEmails(username: 'a@example.org', password: 'pw'), 21);
  });

  test('UIDVALIDITY e conta isolam mensagens com o mesmo UID', () async {
    expect(await service(FakeSession([1], validity: 7)).syncEmails(username: 'a@example.org', password: 'pw'), 1);
    expect(await service(FakeSession([1], validity: 8)).syncEmails(username: 'a@example.org', password: 'pw'), 1);
    expect(await service(FakeSession([1], validity: 7)).syncEmails(username: 'b@example.org', password: 'pw'), 1);
    expect((await db.select(db.inboxEntries).get()).length, 3);
  });

  test('MIME binário é preservado e texto codificado é interpretado', () {
    final raw = Uint8List.fromList(utf8.encode(
      'From: remetente@example.org\r\nTo: destino@example.org\r\n'
      'Subject: =?UTF-8?B?T2zDoQ==?=\r\nMIME-Version: 1.0\r\n'
      'Content-Type: multipart/mixed; boundary="part"\r\n\r\n'
      '--part\r\nContent-Type: text/plain; charset=utf-8\r\n'
      'Content-Transfer-Encoding: base64\r\n\r\nVGV4dG8gZGEgbWVuc2FnZW0=\r\n'
      '--part\r\nContent-Type: application/octet-stream; name="a.bin"\r\n'
      'Content-Disposition: attachment; filename="a.bin"\r\n'
      'Content-Transfer-Encoding: base64\r\n\r\nAAECA/8=\r\n--part--\r\n'));
    final mime = mail.MimeMessage.parseFromData(raw)..uid = 55;
    final message = jwEmailFromMime(mime);
    expect(message.subject, 'Olá');
    expect(message.bodyText, contains('Texto da mensagem'));
    expect(base64Decode(message.rawEmlBase64!), orderedEquals(raw));
    expect(JwEmailMessage.fromJson(message.toJson()).rawEmlBase64, message.rawEmlBase64);
  });
}
