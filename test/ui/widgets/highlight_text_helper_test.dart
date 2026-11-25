import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/ui/widgets/highlight_text_helper.dart';

void main() {
  group('HighlightTextHelper (Sublinhado JW Library & Mapeamento de Seleção)', () {
    test('define 6 cores inspiradas no JW Library', () {
      expect(HighlightTextHelper.colors.length, equals(6));
      final ids = HighlightTextHelper.colors.map((c) => c.id).toSet();
      expect(
        ids,
        containsAll({'yellow', 'green', 'blue', 'pink', 'orange', 'purple'}),
      );
    });

    test('applyUnderlineToDisplaySelection atinge exatamente a segunda ocorrência sem vazar', () {
      const raw = '### Estudo\n**Fé** em Jeová fortalece a fé no dia a dia.';
      final mapped = HighlightTextHelper.buildMappedSpans(
        raw,
        const TextStyle(fontSize: 14),
      );

      // O prefixo "### " e os asteriscos "**" somem do texto visível
      expect(
        mapped.plainDisplayText,
        equals('Estudo\nFé em Jeová fortalece a fé no dia a dia.'),
      );

      final secondStart = mapped.plainDisplayText.indexOf('fé no dia');
      final secondEnd = secondStart + 2; // "fé"

      final updated = HighlightTextHelper.applyUnderlineToDisplaySelection(
        rawText: raw,
        selectionStart: secondStart,
        selectionEnd: secondEnd,
        colorHex: '#10B981',
      );

      expect(
        updated,
        equals(
          '### Estudo\n**Fé** em Jeová fortalece a <u style="color:#10B981">fé</u> no dia a dia.',
        ),
      );
    });

    test('substitui cor de sublinhado existente sem aninhar tags e remove destaque corretamente', () {
      const raw = 'Leia o texto <u style="color:#EAB308">amor leal</u> hoje.';
      final mapped = HighlightTextHelper.buildMappedSpans(
        raw,
        const TextStyle(fontSize: 14),
      );
      expect(mapped.plainDisplayText, equals('Leia o texto amor leal hoje.'));

      final start = mapped.plainDisplayText.indexOf('amor leal');
      final end = start + 'amor leal'.length;

      final recolored = HighlightTextHelper.applyUnderlineToDisplaySelection(
        rawText: raw,
        selectionStart: start,
        selectionEnd: end,
        colorHex: '#3B82F6',
      );
      expect(
        recolored,
        equals('Leia o texto <u style="color:#3B82F6">amor leal</u> hoje.'),
      );

      final cleared = HighlightTextHelper.removeHighlightFromDisplaySelection(
        rawText: recolored,
        selectionStart: start,
        selectionEnd: end,
      );
      expect(cleared, equals('Leia o texto amor leal hoje.'));
    });

    test('renderiza estilo de sublinhado colorido e links clicáveis descartando recognizers', () {
      final disposables = <TapGestureRecognizer>[];
      String? tappedUrl;

      const raw =
          '<u style="color:#8B5CF6">Texto sublinhado</u> e [📖 João 3:16 (TNM)](app://ref/bible/43/3/16)';
      final res = HighlightTextHelper.buildMappedSpans(
        raw,
        const TextStyle(fontSize: 14),
        onLinkTap: (url) => tappedUrl = url,
        disposables: disposables,
      );

      final underlineSpan = res.spans.whereType<TextSpan>().firstWhere(
        (s) => s.text == 'Texto sublinhado',
      );
      expect(underlineSpan.style?.decoration, equals(TextDecoration.underline));
      expect(
        underlineSpan.style?.decorationColor,
        equals(const Color(0xFF8B5CF6)),
      );
      expect(underlineSpan.style?.decorationThickness, equals(2.5));

      expect(disposables.length, equals(1));
      disposables.first.onTap?.call();
      expect(tappedUrl, equals('app://ref/bible/43/3/16'));

      for (final d in disposables) {
        d.dispose();
      }
    });
  });
}
