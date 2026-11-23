import 'package:flutter/material.dart';

import '../../inbox/email_html_sanitizer.dart';

/// Controlador de texto com estilização visual rica em tempo real para composição de e-mails.
/// Estiliza negrito (**texto**), itálico (*texto*), sublinhado (__texto__) e títulos
/// suavizando a visibilidade dos marcadores Markdown e exibindo a tipografia real.
class RichEmailEditingController extends TextEditingController {
  RichEmailEditingController({super.text});

  static final RegExp _markdownTokenRegex = RegExp(
    r'(\*\*([^\*\n]+)\*\*)|((?<!\*)\*([^\*\n]+)\*(?!\*))|(__([^_\n]+)__)|(^(#{1,3})\s+(.*)$)',
    multiLine: true,
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    final plainText = text;
    if (plainText.isEmpty) {
      return TextSpan(style: baseStyle, text: '');
    }

    final delimiterStyle = baseStyle.copyWith(
      color: (baseStyle.color ?? const Color(0xFF64748B)).withValues(
        alpha: 0.25,
      ),
      fontSize: (baseStyle.fontSize ?? 14) * 0.9,
      fontWeight: FontWeight.normal,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
    );

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in _markdownTokenRegex.allMatches(plainText)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: plainText.substring(lastEnd, match.start),
            style: baseStyle,
          ),
        );
      }

      if (match.group(1) != null) {
        // **negrito**
        spans.add(TextSpan(text: '**', style: delimiterStyle));
        spans.add(
          TextSpan(
            text: match.group(2)!,
            style: baseStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        );
        spans.add(TextSpan(text: '**', style: delimiterStyle));
      } else if (match.group(3) != null) {
        // *itálico*
        spans.add(TextSpan(text: '*', style: delimiterStyle));
        spans.add(
          TextSpan(
            text: match.group(4)!,
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
        spans.add(TextSpan(text: '*', style: delimiterStyle));
      } else if (match.group(5) != null) {
        // __sublinhado__
        spans.add(TextSpan(text: '__', style: delimiterStyle));
        spans.add(
          TextSpan(
            text: match.group(6)!,
            style: baseStyle.copyWith(decoration: TextDecoration.underline),
          ),
        );
        spans.add(TextSpan(text: '__', style: delimiterStyle));
      } else if (match.group(7) != null) {
        // # Título
        final hashes = match.group(8)!;
        final title = match.group(9)!;
        spans.add(TextSpan(text: '$hashes ', style: delimiterStyle));
        spans.add(
          TextSpan(
            text: title,
            style: baseStyle.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: (baseStyle.fontSize ?? 14) + (4 - hashes.length),
            ),
          ),
        );
      }
      lastEnd = match.end;
    }

    if (lastEnd < plainText.length) {
      spans.add(TextSpan(text: plainText.substring(lastEnd), style: baseStyle));
    }

    return TextSpan(style: baseStyle, children: spans);
  }

  /// Converte o conteúdo para HTML limpo semanticamente formatado.
  String toCleanHtml() {
    return EmailHtmlSanitizer.markdownToCleanHtml(text);
  }

  /// Converte o conteúdo para texto puro sem asteriscos ou marcadores crus.
  String toCleanPlainText() {
    return EmailHtmlSanitizer.markdownToCleanPlainText(text);
  }
}
