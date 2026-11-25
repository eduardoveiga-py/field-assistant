import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:eas_client/eas_client.dart' as eas;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/core/biometric_auth_service.dart';
import 'package:ministerio_pessoal/core/google_sign_in_initializer.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/inbox/email_account_model.dart';
import 'package:ministerio_pessoal/inbox/email_sync_coordinator.dart';
import 'package:ministerio_pessoal/inbox/exchange_service.dart';
import 'package:ministerio_pessoal/inbox/gmail_oauth_service.dart';
import 'package:ministerio_pessoal/inbox/jw_email_service.dart';
import 'package:ministerio_pessoal/inbox/microsoft_oauth_service.dart';
import 'package:ministerio_pessoal/inbox/oauth_token_store.dart';

class _FakeMultiFolderImapSession implements JwImapFolderSession {
  final Map<String, List<JwEmailMessage>> messagesByMailbox;
  final Map<String, List<JwImapUidFlag>> flagsByMailbox;
  final List<String> fetchedMailboxes = [];
  final List<String> pushActions = [];
  String _selectedMailbox = 'INBOX';

  _FakeMultiFolderImapSession({
    required this.messagesByMailbox,
    required this.flagsByMailbox,
  });

  @override
  Future<void> connect(
    String host,
    int port,
    String username,
    String password,
    Duration timeout,
  ) async {}

  @override
  Future<void> close() async {}

  @override
  Future<int> selectInbox() => selectMailbox('INBOX');

  @override
  Future<List<int>> searchUids() async =>
      (flagsByMailbox[_selectedMailbox] ?? const []).map((f) => f.uid).toList();

  @override
  Future<List<JwEmailMessage>> fetchUids(List<int> uids) async =>
      (messagesByMailbox[_selectedMailbox] ?? const [])
          .where((m) => uids.contains(m.remoteUid))
          .toList();

  @override
  Future<List<JwImapMailboxInfo>> listTargetMailboxes() async => const [
    JwImapMailboxInfo(path: 'INBOX', folderName: 'Caixa de Entrada'),
    JwImapMailboxInfo(path: 'Sent', folderName: 'Enviadas', isSent: true),
  ];

  @override
  Future<int> selectMailbox(String mailboxPath) async {
    _selectedMailbox = mailboxPath;
    return mailboxPath == 'Sent' ? 200 : 100;
  }

  @override
  Future<List<JwImapUidFlag>> searchUidFlags() async =>
      List.of(flagsByMailbox[_selectedMailbox] ?? const []);

  @override
  Future<List<JwEmailMessage>> fetchUidsInMailbox(
    List<int> uids, {
    required JwImapMailboxInfo mailbox,
  }) async {
    fetchedMailboxes.add('${mailbox.path}:$uids');
    return (messagesByMailbox[mailbox.path] ?? const [])
        .where((m) => uids.contains(m.remoteUid))
        .map(
          (m) => m.copyWith(
            folderId: mailbox.path,
            folderName: mailbox.folderName,
            isDraft: mailbox.isDraft,
          ),
        )
        .toList();
  }

  @override
  Future<void> setReadFlag(
    List<int> uids, {
    required String mailboxPath,
    required bool isRead,
  }) async {
    pushActions.add('STORE:$mailboxPath:$uids:$isRead');
  }

  @override
  Future<void> moveUidsToFolder(
    List<int> uids, {
    required String sourceMailbox,
    required String targetFolderName,
  }) async {
    pushActions.add('MOVE:$sourceMailbox:$uids->$targetFolderName');
  }

  @override
  Future<void> deleteUids(
    List<int> uids, {
    required String sourceMailbox,
    bool permanent = false,
  }) async {
    pushActions.add('DELETE:$sourceMailbox:$uids:perm=$permanent');
  }
}

class _FakeExchangeChangedSession implements ExchangeSession {
  int pass = 0;

  @override
  Future<String> inboxId() async => 'inbox';

  @override
  Future<List<eas.EasFolder>> mailFolders() async => const [
    eas.EasFolder(
      serverId: 'inbox',
      parentId: '0',
      displayName: 'Inbox',
      type: eas.EasFolderType.defaultInbox,
    ),
  ];

  @override
  Future<eas.SyncResult> readPage(String folder, String key) async {
    pass++;
    if (key == '0') {
      return const eas.SyncResult(
        status: 1,
        syncKey: 'k1',
        collectionId: 'inbox',
      );
    }
    if (key == 'k1') {
      return const eas.SyncResult(
        status: 1,
        syncKey: 'k2',
        collectionId: 'inbox',
        addedEmails: [
          eas.EasEmail(
            serverId: 'srv_1',
            subject: 'Aviso',
            from: 'hub@jw.org',
            body: 'Corpo aviso',
            read: false,
          ),
        ],
      );
    }
    return const eas.SyncResult(
      status: 1,
      syncKey: 'k3',
      collectionId: 'inbox',
      changedEmails: [eas.EasEmail(serverId: 'srv_1', read: true)],
    );
  }

  @override
  void close() {}

  @override
  Future<void> sendMail({
    required String to,
    required String subject,
    required String body,
    String? from,
    List<String> cc = const [],
    List<String> bcc = const [],
    List<Map<String, dynamic>> attachments = const [],
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('PWA Attachment Bloat Prevention & Legacy Cleanup', () {
    test('JwEmailMessage.toJson and persistSyncedMessages strip rawBytes while preserving base64', () async {
      final rawPayload = Uint8List.fromList(List.generate(512, (i) => i % 256));
      final b64 = base64Encode(rawPayload);

      final msg = JwEmailMessage(
        id: 'ms_att_1',
        subject: 'Com Anexo Binário',
        from: 'user@outlook.com',
        to: 'dest@outlook.com',
        accountEmail: 'user@outlook.com',
        date: DateTime.utc(2026, 11, 24),
        bodyText: 'Corpo',
        attachments: [
          {
            'name': 'foto.png',
            'attachmentId': 'att_1',
            'size': rawPayload.length,
            'mimeType': 'image/png',
            'base64': b64,
            'rawBytes': rawPayload,
          },
        ],
      );

      final jsonMap = msg.toJson();
      final serializedAtts = jsonMap['attachments'] as List<dynamic>;
      expect(serializedAtts.single['rawBytes'], isNull);
      expect(serializedAtts.single['base64'], equals(b64));

      final coordinator = EmailSyncCoordinator(db);
      final saved = await coordinator.persistSyncedMessages([
        msg,
      ], 'microsoft_graph');
      expect(saved, equals(1));

      final row = await (db.select(
        db.inboxEntries,
      )..where((t) => t.id.equals('email_ms_att_1'))).getSingle();
      expect(row.metadata, isNot(contains('"rawBytes"')));
      expect(row.attachments, isNot(contains('"rawBytes"')));
      expect(row.attachments, contains(b64));

      final qRow = await (db.select(
        db.syncQueue,
      )..where((t) => t.entityId.equals('email_ms_att_1'))).getSingle();
      expect(qRow.payload, isNot(contains('"rawBytes"')));
    });

    test('sanitizeLegacyAttachmentBlobs strips rawBytes from bloated inbox_entries and sync_queue rows', () async {
      final now = DateTime.now().toUtc();
      final legacyAtts = [
        {
          'name': 'legacy.png',
          'base64': 'AAAA',
          'rawBytes': [1, 2, 3, 4, 5],
        },
      ];
      final legacyMeta = jsonEncode({
        'email': {
          'id': 'legacy_1',
          'subject': 'Antigo',
          'from': 'a@b.com',
          'to': 'c@d.com',
          'date': now.toIso8601String(),
          'bodyText': 'oi',
          'attachments': legacyAtts,
        },
      });
      await db
          .into(db.inboxEntries)
          .insert(
            InboxEntriesCompanion.insert(
              id: 'email_legacy_1',
              content: 'Antigo',
              attachments: drift.Value(jsonEncode(legacyAtts)),
              metadata: drift.Value(legacyMeta),
              capturedAt: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: 'q_legacy_1',
              entityType: 'inbox_entries',
              entityId: 'email_legacy_1',
              operation: 'INSERT',
              payload: jsonEncode({
                'id': 'email_legacy_1',
                'attachments': jsonEncode(legacyAtts),
                'metadata': legacyMeta,
              }),
              createdAt: now,
            ),
          );

      final cleaned = await EmailSyncCoordinator.sanitizeLegacyAttachmentBlobs(
        db,
      );
      expect(cleaned, equals(2));

      final row = await (db.select(
        db.inboxEntries,
      )..where((t) => t.id.equals('email_legacy_1'))).getSingle();
      expect(row.metadata, isNot(contains('"rawBytes"')));
      expect(row.attachments, isNot(contains('"rawBytes"')));
      expect(row.attachments, contains('AAAA'));

      final qRow = await (db.select(
        db.syncQueue,
      )..where((t) => t.id.equals('q_legacy_1'))).getSingle();
      expect(qRow.payload, isNot(contains('"rawBytes"')));

      // Idempotente na segunda execução
      final secondRun =
          await EmailSyncCoordinator.sanitizeLegacyAttachmentBlobs(db);
      expect(secondRun, equals(0));
    });
  });

  group('Sent Folder & Two-Way Server Sync (Gmail, Graph, IMAP, Exchange)', () {
    test('GmailOAuthService uses metadata-only fetch for knownMessageIds, fetches SENT, and pushes read/move/delete', () async {
      const tokenStore = OAuthTokenStore();
      await tokenStore.saveTokenBundle(
        'acc_gmail_1',
        OAuthTokenBundle(
          accessToken: 'tok_g_1',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );

      final requestsLog = <String>[];
      final client = MockClient((req) async {
        requestsLog.add('${req.method} ${req.url}');
        final url = req.url.toString();

        if (req.method == 'GET' && url.contains('labelIds=INBOX')) {
          return http.Response(
            jsonEncode({
              'messages': [
                {'id': 'known_msg_1'},
              ],
            }),
            200,
          );
        }
        if (req.method == 'GET' && url.contains('labelIds=SENT')) {
          return http.Response(
            jsonEncode({
              'messages': [
                {'id': 'sent_msg_new'},
              ],
            }),
            200,
          );
        }
        if (req.method == 'GET' &&
            url.contains('/messages/known_msg_1?format=metadata')) {
          return http.Response(
            jsonEncode({
              'id': 'known_msg_1',
              'labelIds': [
                'INBOX',
              ], // UNREAD removida fora do app -> isRead=true
              'internalDate': '1795559282000',
              'payload': {
                'headers': [
                  {'name': 'Subject', 'value': 'Assunto conhecido'},
                  {'name': 'From', 'value': 'amigo@gmail.com'},
                ],
              },
            }),
            200,
          );
        }
        if (req.method == 'GET' &&
            url.contains('/messages/sent_msg_new?format=full')) {
          return http.Response(
            jsonEncode({
              'id': 'sent_msg_new',
              'labelIds': ['SENT'],
              'internalDate': '1795559290000',
              'payload': {
                'headers': [
                  {'name': 'Subject', 'value': 'Enviado fora do app'},
                  {'name': 'From', 'value': 'user@gmail.com'},
                  {'name': 'To', 'value': 'dest@outlook.com'},
                ],
                'mimeType': 'text/plain',
                'body': {
                  'data': base64Url.encode(utf8.encode('Texto enviado')),
                },
              },
            }),
            200,
          );
        }
        if (req.method == 'POST' || req.method == 'DELETE') {
          return http.Response(jsonEncode({'id': 'ok'}), 200);
        }
        return http.Response(jsonEncode({'messages': []}), 200);
      });

      final gmail = GmailOAuthService(
        httpClient: client,
        tokenStore: tokenStore,
      );
      final fetched = await gmail.fetchMessages(
        accountId: 'acc_gmail_1',
        accountEmail: 'user@gmail.com',
        knownMessageIds: const {'known_msg_1'},
      );

      expect(fetched.length, equals(2));
      final knownMeta = fetched.firstWhere((m) => m.id == 'known_msg_1');
      expect(knownMeta.isMetadataOnly, isTrue);
      expect(knownMeta.isRead, isTrue);

      final sentNew = fetched.firstWhere((m) => m.id == 'sent_msg_new');
      expect(sentNew.folderName, equals('Enviadas'));
      expect(sentNew.labels, contains('SENT'));

      expect(
        requestsLog.any((u) => u.contains('known_msg_1?format=metadata')),
        isTrue,
      );
      expect(
        requestsLog.any((u) => u.contains('known_msg_1?format=full')),
        isFalse,
      );

      await gmail.markMessageRead(
        accountId: 'acc_gmail_1',
        messageId: 'sent_msg_new',
        isRead: false,
      );
      await gmail.moveMessageToFolder(
        accountId: 'acc_gmail_1',
        messageId: 'sent_msg_new',
        targetFolderName: 'Spam',
      );
      await gmail.deleteMessage(
        accountId: 'acc_gmail_1',
        messageId: 'sent_msg_new',
        permanent: true,
      );

      expect(
        requestsLog.any(
          (u) =>
              u.contains('POST') && u.contains('/messages/sent_msg_new/modify'),
        ),
        isTrue,
      );
      expect(
        requestsLog.any(
          (u) => u.contains('DELETE') && u.contains('/messages/sent_msg_new'),
        ),
        isTrue,
      );
    });

    test('MicrosoftOAuthService orders sentitems by sentDateTime desc, skips known attachments, and tracks new Graph id on move', () async {
      const tokenStore = OAuthTokenStore();
      await tokenStore.saveTokenBundle(
        'acc_ms_2',
        OAuthTokenBundle(
          accessToken: 'tok_ms_2',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );

      final requestedUrls = <String>[];
      final client = MockClient((req) async {
        requestedUrls.add('${req.method} ${req.url}');
        final url = req.url.toString();

        if (req.method == 'GET' && url.contains('/sentitems/messages')) {
          return http.Response(
            jsonEncode({
              'value': [
                {
                  'id': 'ms_sent_remote_1',
                  'subject': 'Resposta Enviada',
                  'sentDateTime': '2026-11-24T20:00:00Z',
                  'isRead': true,
                  'hasAttachments': true,
                  'from': {
                    'emailAddress': {'address': 'user@outlook.com'},
                  },
                  'toRecipients': [
                    {
                      'emailAddress': {'address': 'amigo@gmail.com'},
                    },
                  ],
                  'body': {'contentType': 'text', 'content': 'Tudo certo'},
                },
              ],
            }),
            200,
          );
        }
        if (req.method == 'PATCH' && url.contains('/me/messages/ms_moved_99')) {
          return http.Response(jsonEncode({'isRead': false}), 200);
        }
        if (req.method == 'POST' &&
            url.contains('/me/messages/ms_sent_remote_1/move')) {
          return http.Response(jsonEncode({'id': 'ms_moved_99'}), 200);
        }
        return http.Response(jsonEncode({'value': []}), 200);
      });

      final ms = MicrosoftOAuthService(
        httpClient: client,
        tokenStore: tokenStore,
      );

      // Salva conta no banco + mensagem conhecida antes da reconciliação
      await EmailAccountsManager.saveAccount(
        db,
        EmailAccount(
          id: 'acc_ms_2',
          name: 'Outlook',
          email: 'user@outlook.com',
          providerType: EmailProviderType.hotmail,
          incomingHost: 'outlook.office365.com',
          incomingProtocol: 'microsoft_graph',
          outgoingHost: 'smtp.office365.com',
          outgoingProtocol: 'microsoft_graph',
          username: 'user@outlook.com',
          createdAt: DateTime.utc(2026, 11, 24),
        ),
      );

      final fetched = await ms.fetchMessages(
        accountId: 'acc_ms_2',
        accountEmail: 'user@outlook.com',
        knownMessageIds: const {'ms_sent_remote_1'},
      );
      expect(fetched.length, equals(1));
      expect(fetched.single.folderName, equals('Enviadas'));
      expect(fetched.single.isMetadataOnly, isTrue);
      // Não deve chamar /attachments para ID conhecido
      expect(requestedUrls.any((u) => u.contains('/attachments')), isFalse);
      expect(
        requestedUrls.any(
          (u) =>
              u.contains('/sentitems/messages') &&
              u.contains('sentDateTime%20desc'),
        ),
        isTrue,
      );

      final coordinator = EmailSyncCoordinator(db, microsoftService: ms);
      await coordinator.persistSyncedMessages(fetched, 'microsoft_graph');

      // Move pasta -> Graph retorna ms_moved_99 e coordenador usa ms_moved_99 ao alterar leitura
      final moveRes = await coordinator.moveMessagesToFolder(
        fetched,
        targetFolderName: 'Lixeira',
      );
      expect(moveRes.remoteSynced, equals(1));

      final readRes = await coordinator.updateReadStatus(
        fetched,
        isRead: false,
      );
      expect(readRes.remoteSynced, equals(1));
      expect(
        requestedUrls.any(
          (u) => u.contains('PATCH') && u.contains('/me/messages/ms_moved_99'),
        ),
        isTrue,
      );
    });

    test('EmailSyncCoordinator queues offline mutations cleanly and flushes them on next syncAll before pulling', () async {
      const tokenStore = OAuthTokenStore();
      await tokenStore.saveTokenBundle(
        'acc_off_g',
        OAuthTokenBundle(
          accessToken: 'tok_off',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      await EmailAccountsManager.saveAccount(
        db,
        EmailAccount(
          id: 'acc_off_g',
          name: 'Gmail',
          email: 'user@gmail.com',
          providerType: EmailProviderType.google,
          incomingHost: 'imap.gmail.com',
          incomingProtocol: 'gmail_api',
          outgoingHost: 'smtp.gmail.com',
          outgoingProtocol: 'gmail_api',
          username: 'user@gmail.com',
          createdAt: DateTime.utc(2026, 11, 24),
        ),
      );

      var isOnline = false;
      final syncedCalls = <String>[];
      final gmail = GmailOAuthService(
        tokenStore: tokenStore,
        httpClient: MockClient((req) async {
          if (!isOnline) {
            throw Exception('SocketException: Offline');
          }
          syncedCalls.add('${req.method} ${req.url}');
          if (req.method == 'POST' && req.url.path.contains('/modify')) {
            return http.Response(jsonEncode({'id': 'g_msg_1'}), 200);
          }
          return http.Response(jsonEncode({'messages': []}), 200);
        }),
      );

      final coordinator = EmailSyncCoordinator(db, gmailService: gmail);
      final msg = JwEmailMessage(
        id: 'g_msg_1',
        subject: 'Offline test',
        from: 'amigo@gmail.com',
        to: 'user@gmail.com',
        accountEmail: 'user@gmail.com',
        date: DateTime.utc(2026, 11, 24),
        bodyText: 'Corpo',
        isRead: false,
        folderName: 'Caixa de Entrada',
      );
      await coordinator.persistSyncedMessages([msg], 'gmail_api');

      // Sem rede: atualiza localmente e enfileira para retry
      final offlineRes = await coordinator.updateReadStatus([
        msg,
      ], isRead: true);
      expect(offlineRes.localUpdated, equals(1));
      expect(offlineRes.queuedOffline, equals(1));
      expect(offlineRes.warnings, isNotEmpty);

      // Enquanto offline-queue tem mutação pendente, pull desatualizado (UNREAD) não reverte local
      await coordinator.persistSyncedMessages([
        msg.copyWith(isRead: false),
      ], 'gmail_api');
      final rowDuringQueue = await (db.select(
        db.inboxEntries,
      )..where((t) => t.id.equals('email_g_msg_1'))).getSingle();
      expect(
        (jsonDecode(rowDuringQueue.metadata)['email'] as Map)['isRead'],
        isTrue,
      );

      // Quando reconecta, syncAll envia mutação pendente antes de puxar
      isOnline = true;
      await coordinator.syncAll();
      expect(
        syncedCalls.any((c) => c.contains('/messages/g_msg_1/modify')),
        isTrue,
      );
    });

    test('JwEmailService syncs IMAP Sent folder and reconciles \\Seen flag updates without re-fetching bodies', () async {
      final session = _FakeMultiFolderImapSession(
        messagesByMailbox: {
          'INBOX': [
            JwEmailMessage(
              id: 'temp_1',
              remoteUid: 1,
              subject: 'Entrada',
              from: 'remetente@jw.org',
              to: 'eu@jw.org',
              date: DateTime.utc(2026, 11, 24),
              bodyText: 'Corpo entrada',
              isRead: false,
            ),
          ],
          'Sent': [
            JwEmailMessage(
              id: 'temp_2',
              remoteUid: 2,
              subject: 'Enviada IMAP',
              from: 'eu@jw.org',
              to: 'destino@jw.org',
              date: DateTime.utc(2026, 11, 24),
              bodyText: 'Corpo enviada',
              isRead: true,
            ),
          ],
        },
        flagsByMailbox: {
          'INBOX': [const JwImapUidFlag(uid: 1, isSeen: false)],
          'Sent': [const JwImapUidFlag(uid: 2, isSeen: true)],
        },
      );

      final svc = JwEmailService(
        db: db,
        biometricAuth: BiometricAuthService(),
        imapClient: JwImapClient(sessionFactory: (_) => session),
      );

      final firstCount = await svc.syncEmails(
        host: 'imap.jw.org',
        port: 993,
        username: 'eu@jw.org',
        password: 'pwd',
        accountEmail: 'eu@jw.org',
      );
      expect(firstCount, equals(2));

      final entries = await db.select(db.inboxEntries).get();
      final folders = entries
          .map((e) => (jsonDecode(e.metadata)['email'] as Map)['folderName'])
          .toSet();
      expect(folders, containsAll(['Caixa de Entrada', 'Enviadas']));

      // Segunda sincronização: apenas flag \Seen mudou em UID 1 na INBOX -> não baixa corpo novamente!
      session.fetchedMailboxes.clear();
      session.flagsByMailbox['INBOX'] = [
        const JwImapUidFlag(uid: 1, isSeen: true),
      ];

      final secondCount = await svc.syncEmails(
        host: 'imap.jw.org',
        port: 993,
        username: 'eu@jw.org',
        password: 'pwd',
        accountEmail: 'eu@jw.org',
      );
      expect(secondCount, equals(0));
      expect(session.fetchedMailboxes, isEmpty);

      final inboxId = JwImapClient.scopedMessageId(
        host: 'imap.jw.org',
        port: 993,
        username: 'eu@jw.org',
        uidValidity: 100,
        uid: 1,
      );
      final updatedRow = await (db.select(
        db.inboxEntries,
      )..where((t) => t.id.equals('email_$inboxId'))).getSingle();
      expect(
        (jsonDecode(updatedRow.metadata)['email'] as Map)['isRead'],
        isTrue,
      );
    });

    test('ExchangeReadService updates isRead on changedEmails without duplicating entries', () async {
      final session = _FakeExchangeChangedSession();
      final service = ExchangeReadService(db);

      await service.sync(
        session: session,
        host: 'mail.jw.org',
        account: 'user@jw.org',
        deviceId: 'dev1',
      );
      var entries = await db.select(db.inboxEntries).get();
      expect(entries.length, equals(1));
      expect(
        (jsonDecode(entries.single.metadata)['email'] as Map)['isRead'],
        isFalse,
      );

      await service.sync(
        session: session,
        host: 'mail.jw.org',
        account: 'user@jw.org',
        deviceId: 'dev1',
      );
      entries = await db.select(db.inboxEntries).get();
      expect(entries.length, equals(1));
      expect(
        (jsonDecode(entries.single.metadata)['email'] as Map)['isRead'],
        isTrue,
      );
    });

    test('Microsoft Graph evita HTTP 400 ErrorInvalidIdMalformed em IDs UUID sintéticos e limpa fila envenenada', () async {
      final now = DateTime.now().toUtc();
      final acc = EmailAccount(
        id: 'acc_ms_synth',
        name: 'Outlook Teste',
        email: 'eduveiga@hotmail.com',
        providerType: EmailProviderType.hotmail,
        incomingHost: 'graph.microsoft.com',
        outgoingHost: 'graph.microsoft.com',
        incomingProtocol: 'microsoft_graph',
        outgoingProtocol: 'microsoft_graph',
        username: 'eduveiga@hotmail.com',
        createdAt: now,
      );
      await EmailAccountsManager.saveAccount(db, acc);
      await const OAuthTokenStore().saveTokenBundle(
        acc.id,
        OAuthTokenBundle(
          accessToken: 'ms_valid_token',
          refreshToken: 'ms_refresh',
          expiresAt: now.add(const Duration(hours: 1)),
        ),
      );

      const syntheticUuid = '123e4567-e89b-12d3-a456-426614174000';
      final localSentMsg = JwEmailMessage(
        id: syntheticUuid,
        accountEmail: acc.email,
        folderName: 'Enviadas',
        subject: 'Assunto Local Sem Match',
        from: acc.email,
        to: 'dest@gmail.com',
        date: now,
        bodyText: 'Corpo local',
        isRead: false,
      );
      await db
          .into(db.inboxEntries)
          .insert(
            InboxEntriesCompanion.insert(
              id: 'email_$syntheticUuid',
              content: localSentMsg.bodyText,
              sourceType: const drift.Value('email'),
              suggestedCategory: const drift.Value('email'),
              capturedAt: now,
              metadata: drift.Value(
                jsonEncode({'email': localSentMsg.toJson()}),
              ),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Injeta uma ação antiga envenenada com UUID sintético na fila offline
      await db
          .into(db.appKvStore)
          .insertOnConflictUpdate(
            AppKvStoreCompanion.insert(
              key: 'email_pending_remote_actions_v1',
              value: jsonEncode([
                {
                  'entryId': 'email_$syntheticUuid',
                  'accountId': acc.id,
                  'accountEmail': acc.email,
                  'protocol': 'microsoft_graph',
                  'messageId': syntheticUuid,
                  'remoteId': syntheticUuid,
                  'action': 'read',
                  'isRead': true,
                },
              ]),
              updatedAt: drift.Value(now),
            ),
          );

      final hitPaths = <String>[];
      final mockClient = MockClient((req) async {
        hitPaths.add('${req.method} ${req.url.path}');
        if (req.url.path.contains('/sentitems/messages')) {
          return http.Response(jsonEncode({'value': []}), 200);
        }
        if (req.url.path.contains(syntheticUuid)) {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'ErrorInvalidIdMalformed',
                'message': 'Id is malformed.',
              },
            }),
            400,
          );
        }
        return http.Response(jsonEncode({'value': []}), 200);
      });

      final coordinator = EmailSyncCoordinator(
        db,
        microsoftService: MicrosoftOAuthService(
          httpClient: mockClient,
          clientId: 'test-client',
        ),
      );

      final res = await coordinator.updateReadStatus([
        localSentMsg,
      ], isRead: true);
      expect(res.localUpdated, equals(1));
      expect(res.warnings, isEmpty);
      expect(hitPaths.any((p) => p.contains(syntheticUuid)), isFalse);

      // Flush limpa a fila legada envenenada sem warnings
      final flushWarnings = await coordinator.flushPendingRemoteActions([acc]);
      expect(flushWarnings, isEmpty);

      final queueRow =
          await (db.select(db.appKvStore)
                ..where((t) => t.key.equals('email_pending_remote_actions_v1')))
              .getSingle();
      expect(jsonDecode(queueRow.value), isEmpty);
    });

    test('Gmail sendEmail retorna id real do servidor e GoogleSignInInitializer guarda prompt único Web', () async {
      const accountId = 'acc_gmail_send_1';
      await const OAuthTokenStore().saveTokenBundle(
        accountId,
        OAuthTokenBundle(
          accessToken: 'gmail_valid_token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );

      final mockClient = MockClient((req) async {
        if (req.method == 'POST' && req.url.path.endsWith('/messages/send')) {
          return http.Response(
            jsonEncode({'id': 'gmail_real_msg_999', 'threadId': 'thr_1'}),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      final gmail = GmailOAuthService(httpClient: mockClient);
      final sentId = await gmail.sendEmail(
        accountId: accountId,
        from: 'eu@gmail.com',
        to: const ['amigo@gmail.com'],
        subject: 'Teste ID real',
        bodyText: 'Corpo teste',
      );
      expect(sentId, equals('gmail_real_msg_999'));

      GoogleSignInInitializer.resetForTesting();
      expect(GoogleSignInInitializer.hasPromptedWebSession, isFalse);
      GoogleSignInInitializer.markWebSessionPrompted();
      expect(GoogleSignInInitializer.hasPromptedWebSession, isTrue);
      GoogleSignInInitializer.resetForTesting();
      expect(GoogleSignInInitializer.hasPromptedWebSession, isFalse);
    });
  });
}
