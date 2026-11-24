import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/inbox/email_sync_coordinator.dart';
import 'package:ministerio_pessoal/inbox/jw_email_service.dart';
import 'package:ministerio_pessoal/ui/widgets/email_html_frame.dart';

void main() {
  group('EmailHtmlFrame srcdoc & Sanitization Tests', () {
    test('buildIframeSrcDoc builds valid sandboxed HTML with base target _blank and no scripts', () {
      const maliciousHtml = '''
<div>
  <h1>Comunicado Importante</h1>
  <script>alert('xss');</script>
  <p>Texto do e-mail com <a href="https://jw.org">link seguro</a>.</p>
  <img src="https://example.com/logo.png" />
</div>
''';
      final srcdoc = EmailHtmlFrame.buildIframeSrcDoc(maliciousHtml);

      expect(srcdoc, contains('<!doctype html>'));
      expect(srcdoc, contains('<base target="_blank" />'));
      expect(srcdoc, contains('max-width: 100% !important'));
      expect(srcdoc, contains('Comunicado Importante'));
      expect(srcdoc, contains('https://jw.org'));
      expect(srcdoc, isNot(contains('<script>')));
      expect(srcdoc, isNot(contains("alert('xss')")));
    });

    test('buildIframeSrcDoc handles empty or null-like safely', () {
      final emptyDoc = EmailHtmlFrame.buildIframeSrcDoc('');
      expect(emptyDoc, contains('<!doctype html>'));
      expect(emptyDoc, contains('<base target="_blank" />'));
    });
  });

  group('JW Mail Tag Isolation Tests (Exchange Only)', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('EmailSyncCoordinator tags Exchange messages as email_jw, but Gmail/Outlook/IMAP as email', () async {
      final coordinator = EmailSyncCoordinator(db);

      // 1. Simula mensagem Exchange
      final exchangeMsg = JwEmailMessage(
        id: 'ex-01',
        accountEmail: 'usuario@exchange.jw.org',
        folderName: 'Caixa de Entrada',
        subject: 'Carta Oficial Teocrática',
        from: 'betel@exchange.jw.org',
        to: 'usuario@exchange.jw.org',
        date: DateTime.now(),
        bodyText: 'Conteúdo restrito',
      );

      await coordinator.persistSyncedMessages([exchangeMsg], 'exchange');

      final exchangeEntry = await (db.select(
        db.inboxEntries,
      )..where((t) => t.id.equals('email_ex-01'))).getSingle();
      expect(exchangeEntry.suggestedCategory, equals('email_jw'));

      // 2. Simula mensagem Gmail API
      final gmailMsg = JwEmailMessage(
        id: 'gm-01',
        accountEmail: 'irmao@gmail.com',
        folderName: 'INBOX',
        subject: 'E-mail Pessoal Google',
        from: 'amigo@gmail.com',
        to: 'irmao@gmail.com',
        date: DateTime.now(),
        bodyText: 'Olá amigo',
      );

      await coordinator.persistSyncedMessages([gmailMsg], 'gmail_api');

      final gmailEntry = await (db.select(
        db.inboxEntries,
      )..where((t) => t.id.equals('email_gm-01'))).getSingle();
      expect(gmailEntry.suggestedCategory, equals('email'));
      expect(gmailEntry.suggestedCategory, isNot(equals('email_jw')));

      // 3. Simula mensagem Microsoft Graph (Hotmail/Outlook)
      final msMsg = JwEmailMessage(
        id: 'ms-01',
        accountEmail: 'irmao@hotmail.com',
        folderName: 'inbox',
        subject: 'Ofertas OneDrive',
        from: 'photos@onedrive.com',
        to: 'irmao@hotmail.com',
        date: DateTime.now(),
        bodyText: 'Suas lembranças',
      );

      await coordinator.persistSyncedMessages([msMsg], 'microsoft_graph');

      final msEntry = await (db.select(
        db.inboxEntries,
      )..where((t) => t.id.equals('email_ms-01'))).getSingle();
      expect(msEntry.suggestedCategory, equals('email'));
      expect(msEntry.suggestedCategory, isNot(equals('email_jw')));

      // 4. Simula mensagem IMAP
      final imapMsg = JwEmailMessage(
        id: 'imap-01',
        accountEmail: 'irmao@provedor.com',
        folderName: 'INBOX',
        subject: 'Fatura Provedor',
        from: 'cobranca@provedor.com',
        to: 'irmao@provedor.com',
        date: DateTime.now(),
        bodyText: 'Fatura do mês',
      );

      await coordinator.persistSyncedMessages([imapMsg], 'imap');

      final imapEntry = await (db.select(
        db.inboxEntries,
      )..where((t) => t.id.equals('email_imap-01'))).getSingle();
      expect(imapEntry.suggestedCategory, equals('email'));
      expect(imapEntry.suggestedCategory, isNot(equals('email_jw')));
    });
  });
}
