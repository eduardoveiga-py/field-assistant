import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../references/app_reference.dart';

/// Paleta oficial inspirada no estilo do aplicativo JW Library.
class JwHighlightColor {
  final String id;
  final String label;
  final String hex;
  final Color color;

  const JwHighlightColor({
    required this.id,
    required this.label,
    required this.hex,
    required this.color,
  });
}

/// Resultado da renderização de um texto rico com mapeamento exato
/// dos deslocamentos visuais de volta ao texto-fonte Markdown.
class MappedRichTextResult {
  final List<InlineSpan> spans;
  final String plainDisplayText;
  final List<int> displayToRawStart;
  final List<int> displayToRawEnd;

  const MappedRichTextResult({
    required this.spans,
    required this.plainDisplayText,
    required this.displayToRawStart,
    required this.displayToRawEnd,
  });
}

/// Motor unificado para sublinhado colorido estilo JW Library (`<u style="color:#hex">...</u>`),
/// suporte retrocompatível a marca-texto `<mark style="background:#hex">...</mark>`
/// e mapeamento preciso de seleção visual -> código-fonte para edição direta na leitura.
class HighlightTextHelper {
  HighlightTextHelper._();

  // Normaliza palette garantindo hex válido de 7 caracteres (#RRGGBB).
  static List<JwHighlightColor> get colors => const [
    JwHighlightColor(
      id: 'yellow',
      label: 'Amarelo',
      hex: '#EAB308',
      color: Color(0xFFEAB308),
    ),
    JwHighlightColor(
      id: 'green',
      label: 'Verde',
      hex: '#10B981',
      color: Color(0xFF10B981),
    ),
    JwHighlightColor(
      id: 'blue',
      label: 'Azul',
      hex: '#3B82F6',
      color: Color(0xFF3B82F6),
    ),
    JwHighlightColor(
      id: 'pink',
      label: 'Rosa',
      hex: '#EC4899',
      color: Color(0xFFEC4899),
    ),
    JwHighlightColor(
      id: 'orange',
      label: 'Laranja',
      hex: '#F97316',
      color: Color(0xFFF97316),
    ),
    JwHighlightColor(
      id: 'purple',
      label: 'Roxo',
      hex: '#8B5CF6',
      color: Color(0xFF8B5CF6),
    ),
  ];

  static final RegExp anyHighlightTagRegex = RegExp(
    r'<(?:u|mark)(?:\s+[^>]*)?>([\s\S]*?)</(?:u|mark)>',
    caseSensitive: false,
  );

  static final RegExp inlineTokenRegex = RegExp(
    r'(?:<u(?:\s+style="(?:(?:text-decoration-)?color:\s*)(#[a-fA-F0-9]{6})")?>([\s\S]*?)</u>)'
    r'|(?:<mark(?:\s+style="background:\s*(#[a-fA-F0-9]{6})")?>([\s\S]*?)</mark>)'
    r'|(?:\*\*\*([^\*]+?)\*\*\*)'
    r'|(?:\*\*([^\*]+?)\*\*)'
    r'|(?<!\*)\*([^\*\s\n](?:[^\*\n]*?[^\*\s\n])?)\*(?!\*)'
    r'|(?<!\w)___([^_]+?)___(?!\w)'
    r'|(?<!\w)__([^_]+?)__(?!\w)'
    r'|(?<!\w)_([^_ \n\t]+(?:\s+[^_ \n\t]+)*)_(?!\w)'
    r'|(?:`([^`]+?)`)'
    r'|(?:~~([^~]+?)~~)'
    r'|(?:\[([^\]]+)\]\(([^\)]+)\))',
    caseSensitive: false,
  );

  static Color parseHexColor(
    String? hex, {
    Color fallback = const Color(0xFFEAB308),
  }) {
    if (hex == null || hex.isEmpty) return fallback;
    final clean = hex.trim().replaceFirst('#', '');
    if (clean.length != 6) return fallback;
    final parsed = int.tryParse('0xFF$clean');
    return parsed != null ? Color(parsed) : fallback;
  }

  /// Remove todas as tags de destaque (`<u>` / `<mark>`) de um trecho mantendo o texto interno.
  static String stripHighlightTags(String text) {
    if (text.isEmpty) return text;
    var out = text;
    for (var i = 0; i < 3; i++) {
      final updated = out.replaceAllMapped(
        anyHighlightTagRegex,
        (m) => m.group(1) ?? '',
      );
      if (updated == out) break;
      out = updated;
    }
    return out;
  }

  /// Constroi `InlineSpan`s a partir de [rawText] mantendo mapeamento exato
  /// entre cada caractere exibido e seu intervalo no [rawText].
  static MappedRichTextResult buildMappedSpans(
    String rawText,
    TextStyle baseStyle, {
    ValueChanged<String>? onLinkTap,
    List<GestureRecognizer>? disposables,
    bool stripBlockPrefixes = true,
  }) {
    if (rawText.isEmpty) {
      return const MappedRichTextResult(
        spans: [],
        plainDisplayText: '',
        displayToRawStart: [],
        displayToRawEnd: [],
      );
    }

    final spans = <InlineSpan>[];
    final plainBuf = StringBuffer();
    final mapStart = <int>[];
    final mapEnd = <int>[];

    void emitSpan(
      String visible,
      TextStyle style,
      int rawOffset, {
      GestureRecognizer? recognizer,
    }) {
      if (visible.isEmpty) return;
      spans.add(TextSpan(text: visible, style: style, recognizer: recognizer));
      plainBuf.write(visible);
      for (var k = 0; k < visible.length; k++) {
        mapStart.add(rawOffset + k);
        mapEnd.add(rawOffset + k + 1);
      }
    }

    void emitTransformedSpan(
      String visible,
      TextStyle style,
      int rawStart,
      int rawEnd, {
      GestureRecognizer? recognizer,
    }) {
      if (visible.isEmpty) return;
      spans.add(TextSpan(text: visible, style: style, recognizer: recognizer));
      plainBuf.write(visible);
      final spanLen = (rawEnd - rawStart).clamp(1, 1000000);
      for (var k = 0; k < visible.length; k++) {
        final mappedPos = (rawStart + k).clamp(rawStart, rawEnd - 1);
        mapStart.add(mappedPos);
        mapEnd.add((mappedPos + 1).clamp(rawStart + 1, rawStart + spanLen));
      }
    }

    // Processa linha a linha para mapear cabeçalhos/citações/listas sem perder offsets originais.
    final lines = rawText.split('\n');
    var lineCursor = 0;

    for (var lineIdx = 0; lineIdx < lines.length; lineIdx++) {
      final line = lines[lineIdx];
      final lineStartRaw = lineCursor;
      lineCursor += line.length + 1; // +1 para '\n'

      if (lineIdx > 0) {
        emitSpan('\n', baseStyle, lineStartRaw - 1);
      }

      var contentStartInLine = 0;
      var lineStyle = baseStyle;
      String? syntheticPrefix;

      if (stripBlockPrefixes) {
        final headingMatch = RegExp(r'^(#{1,6}\s+)').firstMatch(line);
        final quoteMatch = RegExp(r'^(>\s+)').firstMatch(line);
        final checkTodo = RegExp(r'^(-\s+\[\s*\]\s+)').firstMatch(line);
        final checkDone = RegExp(r'^(-\s+\[[xX]\]\s+)').firstMatch(line);
        final bulletMatch = RegExp(r'^([-*]\s+)').firstMatch(line);

        if (headingMatch != null) {
          contentStartInLine = headingMatch.end;
          lineStyle = baseStyle.copyWith(fontWeight: FontWeight.bold);
        } else if (quoteMatch != null) {
          contentStartInLine = quoteMatch.end;
          lineStyle = baseStyle.copyWith(fontStyle: FontStyle.italic);
        } else if (checkTodo != null) {
          contentStartInLine = checkTodo.end;
          syntheticPrefix = '☐ ';
        } else if (checkDone != null) {
          contentStartInLine = checkDone.end;
          syntheticPrefix = '☑ ';
        } else if (bulletMatch != null) {
          contentStartInLine = bulletMatch.end;
          syntheticPrefix = '• ';
        }
      }

      if (syntheticPrefix != null) {
        emitTransformedSpan(
          syntheticPrefix,
          lineStyle,
          lineStartRaw,
          lineStartRaw + contentStartInLine,
        );
      }

      final visibleLine = line.substring(contentStartInLine);
      final baseOffset = lineStartRaw + contentStartInLine;

      final matches = inlineTokenRegex.allMatches(visibleLine).toList();
      if (matches.isEmpty) {
        emitSpan(visibleLine, lineStyle, baseOffset);
        continue;
      }

      var lastEnd = 0;
      for (final m in matches) {
        if (m.start > lastEnd) {
          emitSpan(
            visibleLine.substring(lastEnd, m.start),
            lineStyle,
            baseOffset + lastEnd,
          );
        }

        if (m.group(2) != null) {
          // <u style="color:#hex">text</u>
          final underlineColor = parseHexColor(m.group(1));
          final innerText = m.group(2)!;
          final innerStart =
              baseOffset + visibleLine.indexOf(innerText, m.start);
          emitSpan(
            innerText,
            lineStyle.copyWith(
              decoration: TextDecoration.underline,
              decorationColor: underlineColor,
              decorationThickness: 2.5,
              backgroundColor: underlineColor.withValues(alpha: 0.14),
            ),
            innerStart >= baseOffset ? innerStart : baseOffset + m.start,
          );
        } else if (m.group(4) != null) {
          // <mark style="background:#hex">text</mark>
          final markColor = parseHexColor(m.group(3), fallback: Colors.amber);
          final innerText = m.group(4)!;
          final innerStart =
              baseOffset + visibleLine.indexOf(innerText, m.start);
          emitSpan(
            innerText,
            lineStyle.copyWith(
              backgroundColor: markColor.withValues(alpha: 0.35),
              decoration: TextDecoration.underline,
              decorationColor: markColor,
              decorationThickness: 2.0,
              fontWeight: FontWeight.w600,
            ),
            innerStart >= baseOffset ? innerStart : baseOffset + m.start,
          );
        } else if (m.group(5) != null) {
          // ***bold italic***
          emitSpan(
            m.group(5)!,
            lineStyle.copyWith(
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
            baseOffset + m.start + 3,
          );
        } else if (m.group(6) != null) {
          // **bold**
          emitSpan(
            m.group(6)!,
            lineStyle.copyWith(fontWeight: FontWeight.bold),
            baseOffset + m.start + 2,
          );
        } else if (m.group(7) != null) {
          // *italic*
          emitSpan(
            m.group(7)!,
            lineStyle.copyWith(fontStyle: FontStyle.italic),
            baseOffset + m.start + 1,
          );
        } else if (m.group(8) != null) {
          // ___bold italic___
          emitSpan(
            m.group(8)!,
            lineStyle.copyWith(
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
            baseOffset + m.start + 3,
          );
        } else if (m.group(9) != null) {
          // __bold__
          emitSpan(
            m.group(9)!,
            lineStyle.copyWith(fontWeight: FontWeight.bold),
            baseOffset + m.start + 2,
          );
        } else if (m.group(10) != null) {
          // _italic_
          emitSpan(
            m.group(10)!,
            lineStyle.copyWith(fontStyle: FontStyle.italic),
            baseOffset + m.start + 1,
          );
        } else if (m.group(11) != null) {
          // `code`
          emitSpan(
            m.group(11)!,
            lineStyle.copyWith(
              fontFamily: 'monospace',
              backgroundColor: (lineStyle.color ?? Colors.black).withValues(
                alpha: 0.08,
              ),
            ),
            baseOffset + m.start + 1,
          );
        } else if (m.group(12) != null) {
          // ~~strikethrough~~
          emitSpan(
            m.group(12)!,
            lineStyle.copyWith(decoration: TextDecoration.lineThrough),
            baseOffset + m.start + 2,
          );
        } else if (m.group(13) != null) {
          // [label](url)
          final label = m.group(13)!;
          final url = m.group(14) ?? '';
          final isAppRef = AppReferenceHelper.isAppReferenceUrl(url);
          TapGestureRecognizer? recognizer;
          if (onLinkTap != null && url.isNotEmpty) {
            recognizer = TapGestureRecognizer()..onTap = () => onLinkTap(url);
            disposables?.add(recognizer);
          }
          final linkColor = url.contains('/bible/')
              ? const Color(0xFF4338CA)
              : (isAppRef ? AppTheme.accentTeal : AppTheme.primaryBlue);
          emitSpan(
            label,
            lineStyle.copyWith(
              color: linkColor,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: linkColor.withValues(alpha: 0.6),
              backgroundColor: isAppRef
                  ? linkColor.withValues(alpha: 0.09)
                  : null,
            ),
            baseOffset + m.start + 1,
            recognizer: recognizer,
          );
        }

        lastEnd = m.end;
      }

      if (lastEnd < visibleLine.length) {
        emitSpan(
          visibleLine.substring(lastEnd),
          lineStyle,
          baseOffset + lastEnd,
        );
      }
    }

    return MappedRichTextResult(
      spans: spans,
      plainDisplayText: plainBuf.toString(),
      displayToRawStart: mapStart,
      displayToRawEnd: mapEnd,
    );
  }

  /// Aplica ou substitui a cor do sublinhado JW (`#RRGGBB`) sobre a seleção visual
  /// (`selectionStart..selectionEnd`) e retorna o novo texto Markdown bruto.
  static String applyUnderlineToDisplaySelection({
    required String rawText,
    required int selectionStart,
    required int selectionEnd,
    required String colorHex,
    bool stripBlockPrefixes = true,
  }) {
    if (rawText.isEmpty || selectionEnd <= selectionStart) return rawText;
    final mapped = buildMappedSpans(
      rawText,
      const TextStyle(),
      stripBlockPrefixes: stripBlockPrefixes,
    );
    return applyUnderlineWithMap(
      rawText: rawText,
      map: mapped,
      selectionStart: selectionStart,
      selectionEnd: selectionEnd,
      colorHex: colorHex,
    );
  }

  /// Remove o sublinhado/destaque sobre a seleção visual (`selectionStart..selectionEnd`).
  static String removeHighlightFromDisplaySelection({
    required String rawText,
    required int selectionStart,
    required int selectionEnd,
    bool stripBlockPrefixes = true,
  }) {
    if (rawText.isEmpty || selectionEnd <= selectionStart) return rawText;
    final mapped = buildMappedSpans(
      rawText,
      const TextStyle(),
      stripBlockPrefixes: stripBlockPrefixes,
    );
    return applyUnderlineWithMap(
      rawText: rawText,
      map: mapped,
      selectionStart: selectionStart,
      selectionEnd: selectionEnd,
      colorHex: null,
    );
  }

  /// Executa aplicação (`colorHex != null`) ou remoção (`colorHex == null`)
  /// usando um [MappedRichTextResult] previamente calculado.
  static String applyUnderlineWithMap({
    required String rawText,
    required MappedRichTextResult map,
    required int selectionStart,
    required int selectionEnd,
    required String? colorHex,
  }) {
    final len = map.displayToRawStart.length;
    if (len == 0) return rawText;
    final safeStart = selectionStart.clamp(0, len - 1);
    final safeEnd = selectionEnd.clamp(safeStart + 1, len);
    if (safeEnd <= safeStart) return rawText;

    var rawStart = map.displayToRawStart[safeStart].clamp(0, rawText.length);
    var rawEnd = map.displayToRawEnd[safeEnd - 1].clamp(
      rawStart,
      rawText.length,
    );
    if (rawEnd <= rawStart) return rawText;

    // Se a seleção tocou qualquer tag <u ...>...</u> / <mark ...>...</mark>, expande ao envoltório completo
    // ou remove tags parciais dentro do recorte sem corromper marcações vizinhas.
    for (final m in anyHighlightTagRegex.allMatches(rawText)) {
      final overlapsStart = rawStart >= m.start && rawStart < m.end;
      final overlapsEnd = rawEnd > m.start && rawEnd <= m.end;
      if (colorHex == null) {
        if (overlapsStart ||
            overlapsEnd ||
            (rawStart <= m.start && rawEnd >= m.end)) {
          rawStart = rawStart < m.start ? rawStart : m.start;
          rawEnd = rawEnd > m.end ? rawEnd : m.end;
        }
      } else {
        // Caso o usuário selecione exatamente todo o trecho já sublinhado, substitui a cor inteira
        final inner = m.group(1) ?? '';
        final innerStart = rawText.indexOf(inner, m.start);
        final innerEnd = innerStart + inner.length;
        if (innerStart >= 0 && rawStart <= innerStart && rawEnd >= innerEnd) {
          rawStart = rawStart < m.start ? rawStart : m.start;
          rawEnd = rawEnd > m.end ? rawEnd : m.end;
        } else if (rawStart > m.start && rawEnd < m.end) {
          // Seleção parcial dentro de uma marca já existente: expande para recolorir a marca sem aninhar tag
          rawStart = m.start;
          rawEnd = m.end;
        } else if (overlapsStart && !overlapsEnd) {
          rawStart = m.start;
        } else if (overlapsEnd && !overlapsStart) {
          rawEnd = m.end;
        }
      }
    }

    final targetSlice = rawText.substring(rawStart, rawEnd);
    final cleanedInner = stripHighlightTags(targetSlice);
    if (cleanedInner.trim().isEmpty) return rawText;

    if (colorHex == null) {
      return rawText.replaceRange(rawStart, rawEnd, cleanedInner);
    }

    final normalizedHex = colorHex.startsWith('#') ? colorHex : '#$colorHex';
    final wrapped = '<u style="color:$normalizedHex">$cleanedInner</u>';
    return rawText.replaceRange(rawStart, rawEnd, wrapped);
  }
}
