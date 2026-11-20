import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ministerio_pessoal/ui/widgets/markdown_preview_text.dart';

void main() {
  group('Professional Email Formatting & Markdown Cleanup Tests', () {
    test('cleanMarkdown strips ** bold markers without leaving raw asterisks', () {
      const input =
          'Prezado irmão, veja o **relatório mensal** anexo com **atenção especial**.';
      final cleaned = MarkdownPreviewText.cleanMarkdown(input);

      expect(cleaned, isNot(contains('**')));
      expect(
        cleaned,
        equals(
          'Prezado irmão, veja o relatório mensal anexo com atenção especial.',
        ),
      );
    });

    test('cleanMarkdown strips headers, blockquotes and code markers cleanly', () {
      const input =
          '# Relatório de Serviço\n> Mensagem importante\nConsulte o código `jw123` e [site](https://jw.org).';
      final cleaned = MarkdownPreviewText.cleanMarkdown(input);

      expect(cleaned, isNot(contains('# ')));
      expect(cleaned, isNot(contains('> ')));
      expect(cleaned, isNot(contains('`')));
      expect(cleaned, contains('Relatório de Serviço'));
      expect(cleaned, contains('Mensagem importante'));
      expect(cleaned, contains('jw123'));
      expect(cleaned, contains('site'));
    });

    test('parseSpans creates bold spans for ** delimiters without raw asterisks in TextSpan', () {
      const input = 'Olá **irmão**, seja bem-vindo.';
      const baseStyle = TextStyle(fontSize: 14);
      final spans = MarkdownPreviewText.parseSpans(input, baseStyle);

      expect(spans.isNotEmpty, isTrue);
      // Nenhum span de texto deve conter os caracteres **
      for (final span in spans) {
        if (span is TextSpan && span.text != null) {
          expect(span.text, isNot(contains('**')));
        }
      }
      // Pelo menos um span deve ter fontWeight bold
      final hasBold = spans.any(
        (s) => s is TextSpan && s.style?.fontWeight == FontWeight.bold,
      );
      expect(hasBold, isTrue);
    });

    test(
      'cleanMarkdown removes HTML tags without corrupting surrounding text',
      () {
        const input = '<p>Olá mundo</p><br><div>Novo parágrafo</div>';
        final cleaned = MarkdownPreviewText.cleanMarkdown(input);

        expect(cleaned, isNot(contains('<p>')));
        expect(cleaned, isNot(contains('</p>')));
        expect(cleaned, isNot(contains('<br>')));
        expect(cleaned, isNot(contains('<div>')));
        expect(cleaned, contains('Olá mundo'));
        expect(cleaned, contains('Novo parágrafo'));
      },
    );
  });
}
