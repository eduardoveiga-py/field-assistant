import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/ui/widgets/markdown_preview_text.dart';

void main() {
  group('MarkdownPreviewText & cleanMarkdown Tests', () {
    test('cleanMarkdown strips bold, italic, code and markdown headers', () {
      const input = '### Título Principal\n**Importante:** Este é um *exemplo* com `código` e ~~tachado~~.';
      final cleaned = MarkdownPreviewText.cleanMarkdown(input);

      expect(cleaned, isNot(contains('**')));
      expect(cleaned, isNot(contains('###')));
      expect(cleaned, isNot(contains('`')));
      expect(cleaned, isNot(contains('~~')));
      expect(cleaned, contains('Importante: Este é um exemplo com código e tachado.'));
    });

    test('parseSpans parses bold text without asterisks', () {
      const input = 'Texto com **conteudo** em destaque';
      const baseStyle = TextStyle(fontSize: 14);
      final spans = MarkdownPreviewText.parseSpans(input, baseStyle);

      expect(spans.length, equals(3));
      expect((spans[0] as TextSpan).text, equals('Texto com '));
      expect((spans[1] as TextSpan).text, equals('conteudo'));
      expect((spans[1] as TextSpan).style?.fontWeight, equals(FontWeight.bold));
      expect((spans[2] as TextSpan).text, equals(' em destaque'));
    });

    test('parseSpans parses italic, code, and links correctly', () {
      const input = 'Veja *aqui* e [link teste](https://jw.org)';
      const baseStyle = TextStyle(fontSize: 14);
      final spans = MarkdownPreviewText.parseSpans(input, baseStyle);

      expect(spans.any((s) => (s as TextSpan).text == 'aqui' && s.style?.fontStyle == FontStyle.italic), isTrue);
      expect(spans.any((s) => (s as TextSpan).text == 'link teste'), isTrue);
      expect(spans.any((s) => (s as TextSpan).text?.contains('**') ?? false), isFalse);
    });

    testWidgets('MarkdownPreviewText renders formatted text cleanly in widget tree', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MarkdownPreviewText(
              text: '**Tema:** O Reino de Deus\n*Pontos:* Amor leal',
              maxLines: 3,
            ),
          ),
        ),
      );

      expect(find.byType(MarkdownPreviewText), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);

      final richText = tester.widget<RichText>(find.byType(RichText));
      final rootSpan = richText.text as TextSpan;
      final textString = rootSpan.toPlainText();

      // Sem asteriscos visíveis no texto renderizado
      expect(textString, isNot(contains('**')));
      expect(textString, contains('Tema: O Reino de Deus'));
      expect(textString, contains('Pontos: Amor leal'));
    });

    test('preserves snake_case identifiers and unattached math asterisks', () {
      const input = 'Verifique app_kv_store e CIN_Eduardo_Veiga.pdf com 5 * 4 = 20';
      final cleaned = MarkdownPreviewText.cleanMarkdown(input);

      expect(cleaned, contains('app_kv_store'));
      expect(cleaned, contains('CIN_Eduardo_Veiga.pdf'));
      expect(cleaned, contains('5 * 4 = 20'));

      const baseStyle = TextStyle(fontSize: 14);
      final spans = MarkdownPreviewText.parseSpans(input, baseStyle);
      final fullText = spans.map((s) => (s as TextSpan).text ?? '').join();
      expect(fullText, contains('app_kv_store'));
      expect(fullText, contains('CIN_Eduardo_Veiga.pdf'));
    });
  });
}
