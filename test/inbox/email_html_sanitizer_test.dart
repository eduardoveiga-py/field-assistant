import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/inbox/email_html_sanitizer.dart';

void main() {
  group('EmailHtmlSanitizer Tests', () {
    group('extractPlainText', () {
      test('strips style, script, head blocks and comments entirely', () {
        const raw = '''
<!DOCTYPE html>
<html>
<head>
  <title>Teste</title>
  <style type="text/css">
    a, u + div center > a > span > span {
      background: #000000;
      mix-blend-mode: screen;
    }
  </style>
</head>
<body>
  <!-- Comentário interno -->
  <script>alert('malicious');</script>
  <p>Olá, <b>Eduardo</b>!</p>
  <p>Suas lembranças desse dia estão disponíveis.</p>
</body>
</html>
''';
        final text = EmailHtmlSanitizer.extractPlainText(raw);
        expect(text, isNot(contains('background: #000000')));
        expect(text, isNot(contains('mix-blend-mode')));
        expect(text, isNot(contains('alert(')));
        expect(text, isNot(contains('Comentário interno')));
        expect(text, contains('Olá, Eduardo!'));
        expect(text, contains('Suas lembranças desse dia estão disponíveis.'));
      });

      test(
        'converts break and block tags to newlines without gluing words',
        () {
          const raw = 'Primeira linha<br/>Segunda linha<br/>Terceira linha';
          final text = EmailHtmlSanitizer.extractPlainText(raw);
          expect(
            text,
            contains('Primeira linha\nSegunda linha\nTerceira linha'),
          );

          const blocks =
              '<div>Primeiro parágrafo</div><p>Segundo parágrafo</p>';
          final blockText = EmailHtmlSanitizer.extractPlainText(blocks);
          expect(
            blockText,
            contains('Primeiro parágrafo\n\nSegundo parágrafo'),
          );
        },
      );

      test('decodes named, decimal and hex HTML entities', () {
        const raw =
            '&quot;Citando&quot; &amp; &lt;Marcadores&gt; com espa&ccedil;o&nbsp;&#8212;&#x2014; &#39;aspas&#39;';
        final text = EmailHtmlSanitizer.extractPlainText(raw);
        expect(text, contains('"Citando" & <Marcadores>'));
        expect(text, contains("'aspas'"));
      });

      test('handles empty or null safely', () {
        expect(EmailHtmlSanitizer.extractPlainText(null), '');
        expect(EmailHtmlSanitizer.extractPlainText(''), '');
        expect(EmailHtmlSanitizer.extractPlainText('   '), '');
      });

      test(
        'removes loose multi-line CSS rules and stray HTML comment ends',
        () {
          const raw = '''
Suas lembranças desse dia
a, u + div center > a > span > span
{}
u + div center > a > span
{background:#000000;
mix-blend-mode:screen}
u + div center > a > span > span
{background:#000000;
mix-blend-mode:difference}
-->
novembro 23 Ao longo dos anos
''';
          final text = EmailHtmlSanitizer.extractPlainText(raw);
          expect(text, isNot(contains('mix-blend-mode')));
          expect(text, isNot(contains('background:#000000')));
          expect(text, isNot(contains('-->')));
          expect(text, contains('Suas lembranças desse dia'));
          expect(text, contains('novembro 23 Ao longo dos anos'));
        },
      );

      test('cleans Markdown syntax when cleanMarkdown is true', () {
        const markdown = '''
# Título da Captura
| Coluna 1 | Coluna 2 |
| --- | --- |
| Dado A | Dado B |
Veja o [link para o site](https://jw.org).
''';
        final cleaned = EmailHtmlSanitizer.extractPlainText(
          markdown,
          cleanMarkdown: true,
        );
        expect(cleaned, isNot(contains('# Título')));
        expect(cleaned, isNot(contains('| --- |')));
        expect(cleaned, isNot(contains('[link para o site]')));
        expect(cleaned, contains('link para o site'));
        expect(cleaned, contains('Título da Captura'));
      });

      test('stripMarkdown removes **, ***, _, `, ~~ and truncated trailing * markers', () {
        const sample =
            'Olá mundo! Sistema **incrível** com ***ênfase***, _itálico_, `código` e ~~risco~~.';
        final clean = EmailHtmlSanitizer.extractPlainText(
          sample,
          cleanMarkdown: true,
        );
        expect(clean, isNot(contains('*')));
        expect(clean, isNot(contains('`')));
        expect(clean, isNot(contains('~')));
        expect(
          clean,
          equals(
            'Olá mundo! Sistema incrível com ênfase, itálico, código e risco.',
          ),
        );

        const truncated = 'Olá mundo! Sistema *';
        expect(
          EmailHtmlSanitizer.extractPlainText(truncated, cleanMarkdown: true),
          equals('Olá mundo! Sistema'),
        );
      });
    });

    group('displaySenderName', () {
      test(
        'extracts clean sender name from quoted or unquoted email headers',
        () {
          expect(
            EmailHtmlSanitizer.displaySenderName(
              '"Eduardo Veiga" <eduveiga@hotmail.com>',
            ),
            'Eduardo Veiga',
          );
          expect(
            EmailHtmlSanitizer.displaySenderName(
              'OneDrive <photos@onedrive.com>',
            ),
            'OneDrive',
          );
          expect(
            EmailHtmlSanitizer.displaySenderName('<contato@empresa.com>'),
            'contato@empresa.com',
          );
          expect(
            EmailHtmlSanitizer.displaySenderName('superintendente@jw.org'),
            'superintendente@jw.org',
          );
          expect(EmailHtmlSanitizer.displaySenderName(''), '(Sem remetente)');
          expect(EmailHtmlSanitizer.displaySenderName(null), '(Sem remetente)');
        },
      );
    });

    group('extractEmailAddress', () {
      test('extracts bare email address from header or fallback', () {
        expect(
          EmailHtmlSanitizer.extractEmailAddress(
            '"Eduardo" <eduveiga@hotmail.com>',
          ),
          'eduveiga@hotmail.com',
        );
        expect(
          EmailHtmlSanitizer.extractEmailAddress('eduveiga@hotmail.com'),
          'eduveiga@hotmail.com',
        );
        expect(EmailHtmlSanitizer.extractEmailAddress(''), '');
      });
    });

    group('senderInitials', () {
      test('generates two uppercase letters for CircleAvatar initials', () {
        expect(
          EmailHtmlSanitizer.senderInitials(
            '"Eduardo Veiga" <eduveiga@hotmail.com>',
          ),
          'EV',
        );
        expect(
          EmailHtmlSanitizer.senderInitials('OneDrive <photos@onedrive.com>'),
          'ON',
        );
        expect(
          EmailHtmlSanitizer.senderInitials('joao.silva@exemplo.com'),
          'JS',
        );
        expect(EmailHtmlSanitizer.senderInitials(null), '?');
      });
    });

    group('sanitizeHtmlForDisplay', () {
      test('removes scripts, iframes, objects and on* event handlers', () {
        const raw = '''
<div onclick="alert(1)">
  <script>evil()</script>
  <p>Conteúdo seguro</p>
  <a href="javascript:steal()">Link Perigoso</a>
  <a href="https://jw.org">Link Seguro</a>
  <img src="https://example.com/foto.jpg" onerror="evil()" />
</div>
''';
        final sanitized = EmailHtmlSanitizer.sanitizeHtmlForDisplay(raw);
        expect(sanitized, isNot(contains('<script>')));
        expect(sanitized, isNot(contains('onclick=')));
        expect(sanitized, isNot(contains('onerror=')));
        expect(sanitized, isNot(contains('javascript:')));
        expect(sanitized, contains('Conteúdo seguro'));
        expect(sanitized, contains('https://jw.org'));
        expect(sanitized, contains('https://example.com/foto.jpg'));
      });
    });
  });
}
