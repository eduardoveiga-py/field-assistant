import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/core/biometric_auth_service.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/inbox/jw_email_service.dart';

class _FakeSmtpClient extends JwSmtpClient {
  int sendCount = 0;

  _FakeSmtpClient() : super(allowPlaintextForTesting: true);

  @override
  Future<void> sendMail({
    String? host,
    int? port,
    String? username,
    String? password,
    required JwEmailMessage message,
    String? securityMode,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    sendCount++;
  }
}

class _FakeImapSession implements JwImapSession {
  final List<JwEmailMessage> messages;

  _FakeImapSession(this.messages);

  @override
  Future<void> connect(
    String host,
    int port,
    String username,
    String password,
    Duration timeout,
  ) async {}

  @override
  Future<int> selectInbox() async => 42;

  @override
  Future<List<int>> searchUids() async =>
      messages.map((m) => m.remoteUid!).toList();

  @override
  Future<List<JwEmailMessage>> fetchUids(List<int> uids) async =>
      messages.where((m) => uids.contains(m.remoteUid)).toList();

  @override
  Future<void> close() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group(
    'FA-SEC-08: Atomicidade transacional, _base e revision em JwEmailService',
    () {
      late AppDatabase db;
      late _FakeSmtpClient smtp;
      late JwEmailService service;

      setUp(() {
        db = AppDatabase.forTesting(NativeDatabase.memory());
        smtp = _FakeSmtpClient();
        service = JwEmailService(
          db: db,
          biometricAuth: BiometricAuthService(),
          smtpClient: smtp,
          imapClient: JwImapClient(
            sessionFactory: (_) => _FakeImapSession([
              JwEmailMessage(
                id: 'imap_101',
                remoteUid: 101,
                subject: 'Carta Congregação',
                from: 'secretaria@hub.jw.org',
                to: 'anciao@jw.org',
                date: DateTime.utc(2026, 11, 17, 12, 0),
                bodyText: 'Conteúdo retido',
                isHubCommunication: true,
                hubType: 'letter',
              ),
            ]),
          ),
        );
      });

      tearDown(() async {
        await db.close();
      });

      test('saveDraft cria revision=1 e atualizações incrementam revision gravando _base', () async {
        final draft = JwEmailMessage(
          id: 'draft-1',
          subject: 'Assunto v1',
          from: 'eu@jw.org',
          to: 'dest@jw.org',
          date: DateTime.utc(2026, 11, 17, 10, 0),
          bodyText: 'Texto inicial',
          isDraft: true,
        );

        await service.saveDraft(draft);
        final firstEntry = await (db.select(
          db.inboxEntries,
        )..where((t) => t.id.equals('email_draft_draft-1'))).getSingle();
        expect(firstEntry.revision, 1);

        final firstOps = await (db.select(
          db.syncQueue,
        )..where((t) => t.entityId.equals('email_draft_draft-1'))).get();
        expect(firstOps.length, 1);
        expect(firstOps.first.operation, 'INSERT');
        final firstPayload =
            jsonDecode(firstOps.first.payload) as Map<String, dynamic>;
        expect(firstPayload.containsKey('_base'), isFalse);
        expect(firstPayload['revision'], 1);

        // Segunda gravação: UPDATE com revision=2 e _base apontando para revision=1
        await service.saveDraft(
          draft.copyWith(subject: 'Assunto v2', bodyText: 'Texto editado'),
        );
        final secondEntry = await (db.select(
          db.inboxEntries,
        )..where((t) => t.id.equals('email_draft_draft-1'))).getSingle();
        expect(secondEntry.revision, 2);
        expect(secondEntry.createdAt, firstEntry.createdAt);

        final allOps = await (db.select(
          db.syncQueue,
        )..where((t) => t.entityId.equals('email_draft_draft-1'))).get();
        expect(allOps.length, 2);
        final updateOp = allOps.last;
        expect(updateOp.operation, 'UPDATE');
        final updatePayload =
            jsonDecode(updateOp.payload) as Map<String, dynamic>;
        expect(updatePayload['revision'], 2);
        expect(updatePayload['_base'], isA<Map<String, dynamic>>());
        expect((updatePayload['_base'] as Map)['revision'], 1);
        expect(
          (updatePayload['_base'] as Map)['content'],
          'Assunto v1\n\nTexto inicial',
        );
      });

      test('sendEmail a partir de rascunho incrementa revision e anexa _base atomicamente', () async {
        final draft = JwEmailMessage(
          id: 'draft-send-1',
          subject: 'Relatório Mensal',
          from: 'eu@jw.org',
          to: 'dest@jw.org',
          date: DateTime.utc(2026, 11, 17, 10, 0),
          bodyText: 'Rascunho pronto',
          isDraft: true,
        );
        await service.saveDraft(draft);

        await service.sendEmail(
          host: 'mail.jw.org',
          port: 587,
          username: 'eu@jw.org',
          password: 'secret',
          message: draft.copyWith(bodyText: 'Versão final enviada'),
          draftId: 'draft-send-1',
        );
        expect(smtp.sendCount, 1);

        final persisted = await (db.select(
          db.inboxEntries,
        )..where((t) => t.id.equals('email_draft_draft-send-1'))).getSingle();
        expect(persisted.revision, 2);
        expect(persisted.sourceType, 'email');

        final ops = await (db.select(
          db.syncQueue,
        )..where((t) => t.entityId.equals('email_draft_draft-send-1'))).get();
        expect(ops.length, 2);
        expect(ops.last.operation, 'UPDATE');
        final payload = jsonDecode(ops.last.payload) as Map<String, dynamic>;
        expect(payload['revision'], 2);
        expect(payload['_base'], isA<Map<String, dynamic>>());
        expect((payload['_base'] as Map)['revision'], 1);
      });

      test(
        'syncEmails persiste atomicamente com revision=1 e é idempotente',
        () async {
          final count1 = await service.syncEmails(
            host: 'mail.jw.org',
            port: 993,
            username: 'anciao@jw.org',
            password: 'secret',
          );
          expect(count1, 1);

          final entries = await db.select(db.inboxEntries).get();
          expect(entries.length, 1);
          expect(entries.first.revision, 1);

          final ops = await db.select(db.syncQueue).get();
          expect(ops.length, 1);
          expect(ops.first.operation, 'INSERT');

          // Re-sync não duplica entrada nem operação de fila
          final count2 = await service.syncEmails(
            host: 'mail.jw.org',
            port: 993,
            username: 'anciao@jw.org',
            password: 'secret',
          );
          expect(count2, 0);
          expect((await db.select(db.inboxEntries).get()).length, 1);
          expect((await db.select(db.syncQueue).get()).length, 1);
        },
      );
    },
  );
}
