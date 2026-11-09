import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// Widget de exibição de texto formatado para pré-visualização em cards e listas.
/// Converte delimitadores Markdown (negrito `**`, itálico `*`, tachado `~~`, código `` ` ``,
/// links e marcações `<mark>`) em spans visualmente estilizados e limpa marcadores de bloco,
/// impedindo que caracteres crus como `**` apareçam para o usuário.
class MarkdownPreviewText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;
  final TextAlign textAlign;

  const MarkdownPreviewText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign = TextAlign.start,
  });

  /// Remove marcadores Markdown e retorna apenas o texto limpo puro.
  static String cleanMarkdown(String raw) {
    if (raw.isEmpty) return '';

    String cleaned = raw;
    // Remove imagens: ![alt](url) -> alt
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'!\[([^\]]*)\]\([^\)]+\)'),
      (m) => m.group(1) ?? '',
    );
    // Transforma links: [label](url) -> label
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^\)]+\)'),
      (m) => m.group(1) ?? '',
    );
    // Remove tags HTML como <mark...>...</mark>
    cleaned = cleaned.replaceAll(RegExp(r'<[^>]+>'), '');
    // Remove negrito e itálico: ***text***, **text**, *text*, __text__, _text_
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\*\*\*([^\*]+?)\*\*\*'),
      (m) => m.group(1) ?? '',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\*\*([^\*]+?)\*\*'),
      (m) => m.group(1) ?? '',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(?<!\*)\*([^\*\s\n](?:[^\*\n]*?[^\*\s\n])?)\*(?!\*)'),
      (m) => m.group(1) ?? '',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(?<!\w)___([^_]+?)___(?!\w)'),
      (m) => m.group(1) ?? '',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(?<!\w)__([^_]+?)__(?!\w)'),
      (m) => m.group(1) ?? '',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(?<!\w)_([^_ \n\t]+(?:\s+[^_ \n\t]+)*)_(?!\w)'),
      (m) => m.group(1) ?? '',
    );
    // Remove código em linha
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'`([^`]+?)`'),
      (m) => m.group(1) ?? '',
    );
    // Remove tachado
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'~~([^~]+?)~~'),
      (m) => m.group(1) ?? '',
    );
    // Limpa prefixos de cabeçalho: # , ## , ### 
    cleaned = cleaned.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    // Limpa prefixos de citação: > 
    cleaned = cleaned.replaceAll(RegExp(r'^>\s+', multiLine: true), '');
    // Substitui checkboxes
    cleaned = cleaned.replaceAll(RegExp(r'^-\s+\[\s*\]\s+', multiLine: true), '☐ ');
    cleaned = cleaned.replaceAll(RegExp(r'^-\s+\[x\]\s+', multiLine: true), '☑ ');
    // Substitui marcadores de lista por bullet
    cleaned = cleaned.replaceAll(RegExp(r'^[-*]\s+', multiLine: true), '• ');
    // Remove quebras de linha excessivas
    cleaned = cleaned.replaceAll(RegExp(r'\n{2,}'), '\n');

    return cleaned.trim();
  }

  /// Limpa e prepara o texto preservando a intenção de formatação para os spans.
  static String _preprocess(String raw) {
    if (raw.isEmpty) return '';

    String cleaned = raw;
    // Imagens: ![alt](url) -> [alt]
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'!\[([^\]]*)\]\([^\)]+\)'),
      (m) => (m.group(1)?.isNotEmpty ?? false) ? '[${m.group(1)}]' : '',
    );
    // Limpa cabeçalhos Markdown de início de linha
    cleaned = cleaned.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    // Limpa citações
    cleaned = cleaned.replaceAll(RegExp(r'^>\s+', multiLine: true), '');
    // Checkboxes
    cleaned = cleaned.replaceAll(RegExp(r'^-\s+\[\s*\]\s+', multiLine: true), '☐ ');
    cleaned = cleaned.replaceAll(RegExp(r'^-\s+\[x\]\s+', multiLine: true), '☑ ');
    // Marcador de tópicos
    cleaned = cleaned.replaceAll(RegExp(r'^[-*]\s+', multiLine: true), '• ');
    // Reduz linhas em branco múltiplas
    cleaned = cleaned.replaceAll(RegExp(r'\n{2,}'), '\n');

    return cleaned.trim();
  }

  static List<InlineSpan> parseSpans(String rawText, TextStyle baseStyle) {
    final preprocessed = _preprocess(rawText);
    if (preprocessed.isEmpty) return [];

    final spans = <InlineSpan>[];

    // Regex abrangente para formatos inline comuns
    final tokenRegex = RegExp(
      r'(?:<mark(?:\s+style="background:(#[a-fA-F0-9]{6})")?>([\s\S]*?)</mark>)'
      r'|(?:\*\*\*([^\*]+?)\*\*\*)'
      r'|(?:\*\*([^\*]+?)\*\*)'
      r'|(?<!\*)\*([^\*\s\n](?:[^\*\n]*?[^\*\s\n])?)\*(?!\*)'
      r'|(?<!\w)___([^_]+?)___(?!\w)'
      r'|(?<!\w)__([^_]+?)__(?!\w)'
      r'|(?<!\w)_([^_ \n\t]+(?:\s+[^_ \n\t]+)*)_(?!\w)'
      r'|(?:`([^`]+?)`)'
      r'|(?:~~([^~]+?)~~)'
      r'|(?:\[([^\]]+)\]\([^\)]+\))',
    );

    final matches = tokenRegex.allMatches(preprocessed).toList();
    if (matches.isEmpty) {
      spans.add(TextSpan(text: preprocessed, style: baseStyle));
      return spans;
    }

    int lastEnd = 0;
    for (final m in matches) {
      if (m.start > lastEnd) {
        spans.add(TextSpan(
          text: preprocessed.substring(lastEnd, m.start),
          style: baseStyle,
        ));
      }

      if (m.group(2) != null) {
        // <mark...>text</mark>
        final hex = m.group(1);
        final markText = m.group(2)!;
        Color markBg = Colors.amber.withValues(alpha: 0.3);
        if (hex != null) {
          try {
            markBg = Color(int.parse(hex.replaceFirst('#', '0xFF'))).withValues(alpha: 0.35);
          } catch (_) {}
        }
        spans.add(TextSpan(
          text: markText,
          style: baseStyle.copyWith(
            backgroundColor: markBg,
            fontWeight: FontWeight.w600,
          ),
        ));
      } else if (m.group(3) != null) {
        // ***bold italic***
        spans.add(TextSpan(
          text: m.group(3)!,
          style: baseStyle.copyWith(
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ));
      } else if (m.group(4) != null) {
        // **bold**
        spans.add(TextSpan(
          text: m.group(4)!,
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      } else if (m.group(5) != null) {
        // *italic*
        spans.add(TextSpan(
          text: m.group(5)!,
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (m.group(6) != null) {
        // ___bold italic___
        spans.add(TextSpan(
          text: m.group(6)!,
          style: baseStyle.copyWith(
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ));
      } else if (m.group(7) != null) {
        // __bold__
        spans.add(TextSpan(
          text: m.group(7)!,
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      } else if (m.group(8) != null) {
        // _italic_
        spans.add(TextSpan(
          text: m.group(8)!,
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (m.group(9) != null) {
        // `code`
        spans.add(TextSpan(
          text: m.group(9)!,
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            backgroundColor: (baseStyle.color ?? Colors.black).withValues(alpha: 0.08),
          ),
        ));
      } else if (m.group(10) != null) {
        // ~~strikethrough~~
        spans.add(TextSpan(
          text: m.group(10)!,
          style: baseStyle.copyWith(decoration: TextDecoration.lineThrough),
        ));
      } else if (m.group(11) != null) {
        // [link](url)
        spans.add(TextSpan(
          text: m.group(11)!,
          style: baseStyle.copyWith(
            color: AppTheme.primaryBlue,
            fontWeight: FontWeight.w600,
          ),
        ));
      }

      lastEnd = m.end;
    }

    if (lastEnd < preprocessed.length) {
      spans.add(TextSpan(
        text: preprocessed.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = DefaultTextStyle.of(context).style;
    final effectiveStyle = style != null ? defaultStyle.merge(style) : defaultStyle;

    final spans = parseSpans(text, effectiveStyle);
    if (spans.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
