import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/inbox/email_account_model.dart';
import 'package:ministerio_pessoal/inbox/email_html_sanitizer.dart';
import 'package:ministerio_pessoal/ui/widgets/rich_email_editing_controller.dart';

void main() {
  group('EmailAccount Signature & Serialization Tests', () {
    test('serializes and deserializes signatureHtml correctly', () {
      final account = EmailAccount(
        id: 'acc-123',
        name: 'Minha Conta',
        email: 'test@example.com',
        username: 'test@example.com',
        providerType: EmailProviderType.custom,
        incomingProtocol: 'imap',
        incomingHost: 'imap.test.com',
        incomingPort: 993,
        outgoingHost: 'smtp.test.com',
        outgoingPort: 465,
        createdAt: DateTime(2026, 1, 1),
        signatureHtml: '<b>Atenciosamente</b><br>Eduardo Veiga',
      );

      final jsonMap = account.toJson();
      expect(
        jsonMap['signatureHtml'],
        equals('<b>Atenciosamente</b><br>Eduardo Veiga'),
      );

      final restored = EmailAccount.fromJson(jsonMap);
      expect(
        restored.signatureHtml,
        equals('<b>Atenciosamente</b><br>Eduardo Veiga'),
      );
      expect(restored.id, equals('acc-123'));
    });

    test('backward compatibility: defaults to empty string when signatureHtml is absent or null', () {
      final legacyJson = {
        'id': 'legacy-1',
        'name': 'Conta Antiga',
        'email': 'legacy@example.com',
        'username': 'legacy@example.com',
        'providerType': 'other',
        'incomingProtocol': 'imap',
        'incomingHost': 'imap.test.com',
        'incomingPort': 993,
        'outgoingHost': 'smtp.test.com',
        'outgoingPort': 465,
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
      };

      final account = EmailAccount.fromJson(legacyJson);
      expect(account.signatureHtml, equals(''));

      final accountWithNull = EmailAccount.fromJson({
        ...legacyJson,
        'signatureHtml': null,
      });
      expect(accountWithNull.signatureHtml, equals(''));
    });

    test('copyWith updates signatureHtml correctly', () {
      final account = EmailAccount(
        id: 'acc-copy',
        name: 'Conta Base',
        email: 'base@example.com',
        username: 'base@example.com',
        providerType: EmailProviderType.custom,
        incomingProtocol: 'imap',
        incomingHost: 'imap.test.com',
        incomingPort: 993,
        outgoingHost: 'smtp.test.com',
        outgoingPort: 465,
        createdAt: DateTime(2026, 1, 1),
      );

      final updated = account.copyWith(
        signatureHtml: '<p>Assinatura Atualizada</p>',
      );
      expect(account.signatureHtml, equals(''));
      expect(updated.signatureHtml, equals('<p>Assinatura Atualizada</p>'));
      expect(updated.id, equals('acc-copy'));
    });
  });

  group('EmailHtmlSanitizer Markdown Conversion Tests', () {
    test('markdownToCleanHtml converts formatting tags to clean valid HTML', () {
      const input =
          'Olá **Eduardo**,\n\nSegue o texto com *itálico*, __sublinhado__ e [link](https://jw.org).';
      final html = EmailHtmlSanitizer.markdownToCleanHtml(input);

      expect(html, contains('<b>Eduardo</b>'));
      expect(html, contains('<i>itálico</i>'));
      expect(html, contains('<u>sublinhado</u>'));
      expect(html, contains('<a href="https://jw.org">link</a>'));
      expect(html, contains('<br><br>'));
      expect(html, isNot(contains('**')));
      expect(html, isNot(contains('__')));
    });

    test('markdownToCleanHtml preserves existing HTML bodies', () {
      const rawHtml =
          '<!DOCTYPE html><html><body><p>Conteúdo HTML nativo</p></body></html>';
      final output = EmailHtmlSanitizer.markdownToCleanHtml(rawHtml);
      expect(output, contains('Conteúdo HTML nativo'));
      expect(output, isNot(contains('<br>')));
    });

    test('markdownToCleanPlainText strips Markdown formatting without leaving raw asterisks', () {
      const input = '''
# Assunto Importante
Olá **Eduardo**, segue o relatório:
* Item com *ênfase*
__Aviso urgente__
Veja em [Portal](https://example.com).
''';
      final plainText = EmailHtmlSanitizer.markdownToCleanPlainText(input);

      expect(plainText, isNot(contains('# Assunto')));
      expect(plainText, isNot(contains('**')));
      expect(plainText, isNot(contains('__')));
      expect(plainText, isNot(contains('*ênfase*')));
      expect(plainText, isNot(contains('[Portal]')));
      expect(plainText, contains('Olá Eduardo, segue o relatório:'));
      expect(plainText, contains('ênfase'));
      expect(plainText, contains('Aviso urgente'));
      expect(plainText, contains('Veja em Portal.'));
    });
  });

  group('RichEmailEditingController Tests', () {
    testWidgets(
      'buildTextSpan creates spans with correct styling without crashing',
      (tester) async {
        late BuildContext buildContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (ctx) {
                buildContext = ctx;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        final controller = RichEmailEditingController(
          text: 'Olá **Eduardo** e *Amigos*, vejam __isto__!',
        );

        final span = controller.buildTextSpan(
          context: buildContext,
          style: const TextStyle(fontSize: 14, color: Colors.black),
          withComposing: false,
        );

        expect(span.children, isNotNull);
        expect(span.children!.isNotEmpty, isTrue);

        controller.dispose();
      },
    );
  });
}
