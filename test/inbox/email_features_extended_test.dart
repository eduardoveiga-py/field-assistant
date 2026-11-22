import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:ministerio_pessoal/core/biometric_auth_service.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/inbox/email_contacts_manager.dart';
import 'package:ministerio_pessoal/inbox/email_account_model.dart';
import 'package:ministerio_pessoal/inbox/jw_email_service.dart';
import 'package:ministerio_pessoal/picture_bank/picture_entry_model.dart';

void main() {
  group('EmailContactsManager & Autocomplete Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'parseAddress extracts name and clean email from complex addresses',
      () {
        final p1 = EmailContactsManager.parseAddress(
          'João Silva <joao@exemplo.com>',
        );
        expect(p1.name, equals('João Silva'));
        expect(p1.email, equals('joao@exemplo.com'));

        final p2 = EmailContactsManager.parseAddress(
          '"Maria Souza" <maria.souza@jw.org>',
        );
        expect(p2.name, equals('Maria Souza'));
        expect(p2.email, equals('maria.souza@jw.org'));

        final p3 = EmailContactsManager.parseAddress('pedro@hotmail.com');
        expect(p3.name, isEmpty);
        expect(p3.email, equals('pedro@hotmail.com'));
      },
    );

    test(
      'recordSender saves sender and getAllSuggestions retrieves it',
      () async {
        await EmailContactsManager.recordSender(
          db,
          'Secretário <secretario@jw.org>',
        );
        await EmailContactsManager.recordSender(
          db,
          'Eduardo Veiga <eduardo@gmail.com>',
        );

        final all = await EmailContactsManager.getAllSuggestions(db);
        expect(all.length, equals(2));
        expect(all.any((c) => c.email == 'secretario@jw.org'), isTrue);
        expect(all.any((c) => c.email == 'eduardo@gmail.com'), isTrue);
      },
    );

    test('getAllSuggestions filters dynamically by query', () async {
      await EmailContactsManager.recordSender(
        db,
        'Secretário de Congregação <secretario@jw.org>',
      );
      await EmailContactsManager.recordSender(
        db,
        'Eduardo Veiga <eduardo@gmail.com>',
      );
      await EmailContactsManager.recordSender(
        db,
        'Marcos Oliveira <marcos@hotmail.com>',
      );

      final eduMatches = await EmailContactsManager.getAllSuggestions(
        db,
        query: 'edu',
      );
      expect(eduMatches.length, equals(1));
      expect(eduMatches.first.email, equals('eduardo@gmail.com'));

      final jwMatches = await EmailContactsManager.getAllSuggestions(
        db,
        query: 'jw.org',
      );
      expect(jwMatches.length, equals(1));
      expect(jwMatches.first.email, equals('secretario@jw.org'));
    });

    test('deleteContact removes contact from persistent registry', () async {
      await EmailContactsManager.recordSender(
        db,
        'Contato Removível <remover@jw.org>',
      );
      var saved = await EmailContactsManager.loadSavedContacts(db);
      expect(saved.any((c) => c.email == 'remover@jw.org'), isTrue);

      await EmailContactsManager.deleteContact(db, 'remover@jw.org');
      saved = await EmailContactsManager.loadSavedContacts(db);
      expect(saved.any((c) => c.email == 'remover@jw.org'), isFalse);
    });
  });

  group('EmailAccount Multi-Account Model Tests', () {
    test(
      'EmailAccount serialization roundtrip supports multiple providers',
      () {
        final now = DateTime.utc(2026, 11, 19);
        final googleAcc = EmailAccount(
          id: 'acc_google_1',
          name: 'Gmail Pessoal',
          email: 'usuario@gmail.com',
          username: 'usuario@gmail.com',
          providerType: EmailProviderType.google,
          incomingProtocol: 'imap',
          incomingHost: 'imap.gmail.com',
          incomingPort: 993,
          outgoingHost: 'smtp.gmail.com',
          outgoingPort: 465,
          createdAt: now,
        );

        final json = googleAcc.toJson();
        final recovered = EmailAccount.fromJson(json);

        expect(recovered.id, equals('acc_google_1'));
        expect(recovered.providerType, equals(EmailProviderType.google));
        expect(recovered.incomingHost, equals('imap.gmail.com'));
        expect(recovered.outgoingHost, equals('smtp.gmail.com'));
        expect(recovered.isActive, isTrue);
      },
    );

    test('EmailAccount implements value equality and hashCode based on ID', () {
      final now = DateTime.now();
      final acc1 = EmailAccount(
        id: 'acc_fixed_id',
        name: 'Google 1',
        email: 'user@gmail.com',
        providerType: EmailProviderType.google,
        incomingHost: 'gmail.googleapis.com',
        outgoingHost: 'gmail.googleapis.com',
        username: 'user@gmail.com',
        createdAt: now,
      );
      final acc2 = EmailAccount(
        id: 'acc_fixed_id',
        name: 'Google 1 (Updated)',
        email: 'user@gmail.com',
        providerType: EmailProviderType.google,
        incomingHost: 'gmail.googleapis.com',
        outgoingHost: 'gmail.googleapis.com',
        username: 'user@gmail.com',
        createdAt: now,
      );
      final acc3 = EmailAccount(
        id: 'acc_other_id',
        name: 'Google 2',
        email: 'user2@gmail.com',
        providerType: EmailProviderType.google,
        incomingHost: 'gmail.googleapis.com',
        outgoingHost: 'gmail.googleapis.com',
        username: 'user2@gmail.com',
        createdAt: now,
      );

      expect(acc1, equals(acc2));
      expect(acc1.hashCode, equals(acc2.hashCode));
      expect(acc1 == acc3, isFalse);
    });

    test('EmailAccount presets generate valid configurations for hotmail and jwpub', () {
      final hotmail = EmailAccount.createPreset(
        providerType: EmailProviderType.hotmail,
        name: 'Hotmail / Outlook',
        email: 'irmao@hotmail.com',
        username: 'irmao@hotmail.com',
      );
      expect(hotmail.incomingHost, equals('outlook.office365.com'));
      expect(hotmail.outgoingHost, equals('smtp.office365.com'));

      final jwpub = EmailAccount.createPreset(
        providerType: EmailProviderType.jwpub,
        name: 'JWPUB Oficial',
        email: 'pioneiro@jwpub.org',
        username: 'pioneiro@jwpub.org',
      );
      expect(jwpub.incomingHost, equals('mail.jw.org'));
      expect(jwpub.outgoingHost, equals('mail.jw.org'));
    });

    test('loadAccounts synthesizes deterministic legacy accounts and resolves passwords', () async {
      FlutterSecureStorage.setMockInitialValues({
        'jw_imap_password': 'legacy_imap_secret_pass',
      });
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await db
          .into(db.appKvStore)
          .insert(
            AppKvStoreCompanion.insert(
              key: 'jw_imap_email',
              value: 'antigo@jw.org',
            ),
          );
      await db
          .into(db.appKvStore)
          .insert(
            AppKvStoreCompanion.insert(
              key: 'jw_imap_host',
              value: 'mail.jw.org',
            ),
          );

      final accounts = await EmailAccountsManager.loadAccounts(db);
      expect(accounts.length, equals(1));
      final legacyAcc = accounts.first;
      expect(legacyAcc.id, equals(EmailAccountsManager.legacyImapAccountId));
      expect(legacyAcc.email, equals('antigo@jw.org'));

      final recoveredPass = await EmailAccountsManager.getAccountPassword(
        legacyAcc.id,
        db,
      );
      expect(recoveredPass, equals('legacy_imap_secret_pass'));
    });
  });

  group('PictureEntry Picture Bank Model Tests', () {
    test('PictureEntry serialization roundtrip with tags and captions', () {
      final now = DateTime.utc(2026, 11, 19);
      final pic = PictureEntry(
        id: 'pic_1',
        caption: 'Visita pastoral às famílias Ticuna no Rio Jandiatuba',
        tags: ['betania', 'ticuna', 'pastoral'],
        imageData: '/data/photos/betania_estudo.jpg',
        category: 'Estudos Bíblicos',
        createdAt: now,
        updatedAt: now,
      );

      final json = pic.toJson();
      final recovered = PictureEntry.fromJson(json);

      expect(recovered.id, equals('pic_1'));
      expect(
        recovered.caption,
        equals('Visita pastoral às famílias Ticuna no Rio Jandiatuba'),
      );
      expect(recovered.tags, containsAll(['betania', 'ticuna', 'pastoral']));
      expect(recovered.imageData, equals('/data/photos/betania_estudo.jpg'));
      expect(recovered.category, equals('Estudos Bíblicos'));
    });
  });

  group('RFC Compliance & IMAP/SMTP Integration Edge Cases', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('JwSmtpClient formats valid RFC 2822 date and RFC 2047 header', () {
      final date = DateTime.utc(2026, 11, 22, 14, 30, 45);
      final formattedDate = JwSmtpClient.formatRfc2822Date(date);
      expect(formattedDate, equals('Sun, 22 Nov 2026 14:30:45 +0000'));

      final asciiHeader = JwSmtpClient.encodeHeaderValue('Meeting invitation');
      expect(asciiHeader, equals('Meeting invitation'));

      final unicodeHeader = JwSmtpClient.encodeHeaderValue(
        'Reunião e Ação Pastoral em Santo Antônio',
      );
      expect(unicodeHeader, startsWith('=?UTF-8?B?'));
      expect(unicodeHeader, endsWith('?='));
      final encodedPart = unicodeHeader.substring(10, unicodeHeader.length - 2);
      final decoded = utf8.decode(base64.decode(encodedPart));
      expect(decoded, equals('Reunião e Ação Pastoral em Santo Antônio'));
    });

    test(
      'syncEmails tags Drift inbox entries with provided accountEmail',
      () async {
        final testMsg = JwEmailMessage(
          id: 'msg_imap_1',
          remoteUid: 42,
          folderName: 'Caixa de Entrada',
          subject: 'Comunicado Regional',
          from: 'sede@jw.org',
          to: 'servo@dominio.com.br',
          date: DateTime.utc(2026, 11, 22),
          bodyText: 'Texto do comunicado',
        );

        final service = JwEmailService(
          db: db,
          biometricAuth: BiometricAuthService(),
          imapClient: JwImapClient(
            sessionFactory: (_) => _FakeImapSession([testMsg]),
          ),
        );

        final saved = await service.syncEmails(
          host: 'imap.dominio.com.br',
          port: 993,
          username: 'servo123',
          password: 'secret_password',
          accountEmail: 'servo@dominio.com.br',
        );

        expect(saved, equals(1));
        final entries = await db.select(db.inboxEntries).get();
        expect(entries.length, equals(1));

        final metadata =
            jsonDecode(entries.first.metadata) as Map<String, dynamic>;
        final emailJson = metadata['email'] as Map<String, dynamic>;
        expect(emailJson['accountEmail'], equals('servo@dominio.com.br'));
        expect(emailJson['folderName'], equals('Caixa de Entrada'));
      },
    );
  });
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
  Future<int> selectInbox() async => 99;

  @override
  Future<List<int>> searchUids() async =>
      messages.map((m) => m.remoteUid!).toList();

  @override
  Future<List<JwEmailMessage>> fetchUids(List<int> uids) async =>
      messages.where((m) => uids.contains(m.remoteUid)).toList();

  @override
  Future<void> close() async {}
}
