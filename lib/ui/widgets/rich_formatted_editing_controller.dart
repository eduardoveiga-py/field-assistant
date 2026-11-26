import 'package:flutter/material.dart';

import 'highlight_text_helper.dart';

/// Estilos de bloco por linha mantidos internamente sem exibir `#` ou `>`.
enum RichBlockStyle { h1, h2, h3, quote }

/// Imagem incorporada em um editor rico (exibida visualmente fora do texto cru).
class RichInlineImage {
  final String alt;
  final String src;

  const RichInlineImage({required this.alt, required this.src});

  String toMarkup() => '![$alt]($src)';
}

/// Span de estilização em linha mapeado exatamente para os offsets de texto visível.
class RichStyleSpan {
  final int start;
  final int end;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final bool code;
  final String? highlightHex;
  final String? textColorHex;
  final double? fontSize;
  final String? linkUrl;

  const RichStyleSpan({
    required this.start,
    required this.end,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.code = false,
    this.highlightHex,
    this.textColorHex,
    this.fontSize,
    this.linkUrl,
  });

  bool get isEmptyStyle =>
      !bold &&
      !italic &&
      !underline &&
      !strikethrough &&
      !code &&
      highlightHex == null &&
      textColorHex == null &&
      fontSize == null &&
      linkUrl == null;

  RichStyleSpan copyWith({
    int? start,
    int? end,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    bool? code,
    String? highlightHex,
    bool clearHighlight = false,
    String? textColorHex,
    bool clearTextColor = false,
    double? fontSize,
    bool clearFontSize = false,
    String? linkUrl,
    bool clearLink = false,
  }) {
    return RichStyleSpan(
      start: start ?? this.start,
      end: end ?? this.end,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strikethrough: strikethrough ?? this.strikethrough,
      code: code ?? this.code,
      highlightHex: clearHighlight ? null : (highlightHex ?? this.highlightHex),
      textColorHex: clearTextColor ? null : (textColorHex ?? this.textColorHex),
      fontSize: clearFontSize ? null : (fontSize ?? this.fontSize),
      linkUrl: clearLink ? null : (linkUrl ?? this.linkUrl),
    );
  }
}

/// Controlador WYSIWYG baseado em [TextEditingController]:
/// - Armazena internamente em `text` APENAS texto limpo legível (zero `**`, `###`,
///   `[rótulo](url)`, `<u style=...>`, ou `![alt](src)` visíveis ao digitar);
/// - Renderiza negrito, itálico, títulos, citações, marcação colorida JW Library e
///   links em tempo real via [buildTextSpan] mantendo contagem exata 1:1 com o cursor;
/// - Serializa de volta para Markdown/HTML compatível via [toMarkup].
class RichFormattedEditingController extends TextEditingController {
  final List<RichStyleSpan> _spans = [];
  final Map<int, RichBlockStyle> _lineStyles = {};
  final List<RichInlineImage> _inlineImages = [];

  bool _pendingBold = false;
  bool _pendingItalic = false;
  bool _pendingUnderline = false;
  bool _pendingStrike = false;
  bool _pendingCode = false;
  String? _pendingHighlightHex;
  String? _pendingTextColorHex;
  double? _pendingFontSize;

  RichFormattedEditingController({super.text});

  RichFormattedEditingController._internal({
    required String visibleText,
    required List<RichStyleSpan> spans,
    required Map<int, RichBlockStyle> lineStyles,
    required List<RichInlineImage> inlineImages,
  }) : super(text: visibleText) {
    _spans.addAll(spans);
    _lineStyles.addAll(lineStyles);
    _inlineImages.addAll(inlineImages);
  }

  List<RichStyleSpan> get spans => List.unmodifiable(_spans);
  List<RichInlineImage> get inlineImages => List.unmodifiable(_inlineImages);
  Map<int, RichBlockStyle> get lineStyles => Map.unmodifiable(_lineStyles);

  bool get pendingBold => _pendingBold;
  bool get pendingItalic => _pendingItalic;
  bool get pendingCode => _pendingCode;
  String? get pendingHighlightHex => _pendingHighlightHex;

  bool isStyleAtCursor({
    bool bold = false,
    bool italic = false,
    bool code = false,
  }) {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) {
      if (bold) return _pendingBold;
      if (italic) return _pendingItalic;
      if (code) return _pendingCode;
      return false;
    }
    return _isStyleActiveInRange(
      sel.start.clamp(0, text.length),
      sel.end.clamp(0, text.length),
      bold: bold,
      italic: italic,
      code: code,
    );
  }

  bool isBlockStyleAtCursor(RichBlockStyle style) {
    final sel = selection;
    final cursor = (sel.isValid ? sel.start : text.length).clamp(
      0,
      text.length,
    );
    final lineIndex = '\n'.allMatches(text.substring(0, cursor)).length;
    return _lineStyles[lineIndex] == style;
  }

  /// Constrói o controlador já populado a partir de texto salvo em Markdown/HTML.
  factory RichFormattedEditingController.fromMarkup(String rawMarkup) {
    if (rawMarkup.isEmpty) {
      return RichFormattedEditingController();
    }

    final images = <RichInlineImage>[];
    // Extrai imagens `![alt](src)` e referências visuais do Banco de Gravuras
    // `[🖼️ legenda](app://ref/picture/<id>)` (incluindo tags <u> legadas) para exibição visual fora do campo de texto.
    final mediaRegex = RegExp(
      r'!\[([^\]]*)\]\(([^\)]+)\)|(?:<u\b[^>]*>)?\[([^\]]*)\]\((app://ref/picture/[^)\s]+)\)(?:</u>)?',
      multiLine: true,
      caseSensitive: false,
    );
    final withoutImages = rawMarkup.replaceAllMapped(mediaRegex, (m) {
      final rawAlt = m.group(1) ?? m.group(3) ?? '';
      final cleanAlt = HighlightTextHelper.stripHighlightTags(rawAlt)
          .replaceFirst(RegExp(r'^🖼️\s*'), '')
          .trim();
      final src = (m.group(2) ?? m.group(4) ?? '').trim();
      if (src.isNotEmpty) {
        images.add(
          RichInlineImage(
            alt: cleanAlt.isEmpty ? 'Imagem' : cleanAlt,
            src: src,
          ),
        );
      }
      return '';
    });

    final sanitizedBlocks = withoutImages
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAllMapped(
          RegExp(
            r'<details\b[^>]*>\s*<summary\b[^>]*>([\s\S]*?)</summary>\s*([\s\S]*?)\s*</details>',
            caseSensitive: false,
          ),
          (m) {
            final sum = HighlightTextHelper.stripHighlightTags(m.group(1) ?? '')
                .trim();
            final body = (m.group(2) ?? '').trim();
            return ':::toggle ${sum.isEmpty ? 'Detalhes' : sum}\n$body\n:::';
          },
        );

    final outBuf = StringBuffer();
    final spans = <RichStyleSpan>[];
    final lineStyles = <int, RichBlockStyle>{};

    final lines = sanitizedBlocks.replaceAll('\r\n', '\n').split('\n');
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      if (i > 0) outBuf.write('\n');
      final lineStart = outBuf.length;

      final headingMatch = RegExp(r'^(#{1,6})\s+').firstMatch(line);
      if (headingMatch != null) {
        final lvl = headingMatch.group(1)!.length;
        lineStyles[i] = lvl == 1
            ? RichBlockStyle.h1
            : (lvl == 2 ? RichBlockStyle.h2 : RichBlockStyle.h3);
        line = line.substring(headingMatch.end);
      } else if (line.startsWith('> ')) {
        lineStyles[i] = RichBlockStyle.quote;
        line = line.substring(2);
      } else if (RegExp(r'^-\s+\[\s*\]\s+').hasMatch(line)) {
        line = line.replaceFirst(RegExp(r'^-\s+\[\s*\]\s+'), '☐ ');
      } else if (RegExp(
        r'^-\s+\[x\]\s+',
        caseSensitive: false,
      ).hasMatch(line)) {
        line = line.replaceFirst(
          RegExp(r'^-\s+\[x\]\s+', caseSensitive: false),
          '☑ ',
        );
      } else if (RegExp(r'^[-*]\s+').hasMatch(line)) {
        line = line.replaceFirst(RegExp(r'^[-*]\s+'), '• ');
      }

      _parseInlineMarkupIntoBuffer(
        line,
        baseOffset: lineStart,
        outBuf: outBuf,
        outSpans: spans,
        inherited: const RichStyleSpan(start: 0, end: 0),
      );
    }

    final cleanVisible = outBuf.toString().trimRight();
    final clippedSpans = spans
        .where((s) => s.start < cleanVisible.length)
        .map(
          (s) => s.copyWith(
            end: s.end > cleanVisible.length ? cleanVisible.length : s.end,
          ),
        )
        .where((s) => s.end > s.start && !s.isEmptyStyle)
        .toList();

    return RichFormattedEditingController._internal(
      visibleText: cleanVisible,
      spans: clippedSpans,
      lineStyles: lineStyles,
      inlineImages: images,
    );
  }

  /// Lê com segurança o conteúdo serializado (funciona tanto para [RichFormattedEditingController]
  /// quanto para [TextEditingController] simples).
  static String readMarkup(TextEditingController ctrl) {
    if (ctrl is RichFormattedEditingController) {
      return ctrl.toMarkup();
    }
    return ctrl.text;
  }

  /// Serializa qualquer texto via [RichFormattedEditingController.fromMarkup] se necessário.
  static void _parseInlineMarkupIntoBuffer(
    String input, {
    required int baseOffset,
    required StringBuffer outBuf,
    required List<RichStyleSpan> outSpans,
    required RichStyleSpan inherited,
  }) {
    var lastEnd = 0;
    for (final m in HighlightTextHelper.inlineTokenRegex.allMatches(input)) {
      if (m.start > lastEnd) {
        final rawPlain = HighlightTextHelper.stripHighlightTags(
          input.substring(lastEnd, m.start),
        );
        if (rawPlain.isNotEmpty) {
          final start = outBuf.length;
          outBuf.write(rawPlain);
          if (!inherited.isEmptyStyle) {
            outSpans.add(inherited.copyWith(start: start, end: outBuf.length));
          }
        }
      }

      if (m.group(2) != null) {
        // <u style="color:#hex">inner</u> -> highlight colorido; <u>inner</u> -> sublinhado
        final rawHex = m.group(1);
        final hex = rawHex == null
            ? null
            : (rawHex.startsWith('#') ? rawHex : '#$rawHex');
        final inner = m.group(2) ?? '';
        _parseInlineMarkupIntoBuffer(
          inner,
          baseOffset: baseOffset,
          outBuf: outBuf,
          outSpans: outSpans,
          inherited: hex != null
              ? inherited.copyWith(highlightHex: hex)
              : inherited.copyWith(underline: true),
        );
      } else if (m.group(4) != null) {
        // <mark style="background:#hex">inner</mark>
        final rawHex = m.group(3) ?? '#EAB308';
        final hex = rawHex.startsWith('#') ? rawHex : '#$rawHex';
        final inner = m.group(4) ?? '';
        _parseInlineMarkupIntoBuffer(
          inner,
          baseOffset: baseOffset,
          outBuf: outBuf,
          outSpans: outSpans,
          inherited: inherited.copyWith(highlightHex: hex),
        );
      } else if (m.group(5) != null) {
        // ***bold+italic***
        _parseInlineMarkupIntoBuffer(
          m.group(5)!,
          baseOffset: baseOffset,
          outBuf: outBuf,
          outSpans: outSpans,
          inherited: inherited.copyWith(bold: true, italic: true),
        );
      } else if (m.group(6) != null) {
        // **bold**
        _parseInlineMarkupIntoBuffer(
          m.group(6)!,
          baseOffset: baseOffset,
          outBuf: outBuf,
          outSpans: outSpans,
          inherited: inherited.copyWith(bold: true),
        );
      } else if (m.group(7) != null) {
        // *italic*
        _parseInlineMarkupIntoBuffer(
          m.group(7)!,
          baseOffset: baseOffset,
          outBuf: outBuf,
          outSpans: outSpans,
          inherited: inherited.copyWith(italic: true),
        );
      } else if (m.group(8) != null) {
        // ___bold+italic___
        _parseInlineMarkupIntoBuffer(
          m.group(8)!,
          baseOffset: baseOffset,
          outBuf: outBuf,
          outSpans: outSpans,
          inherited: inherited.copyWith(bold: true, italic: true),
        );
      } else if (m.group(9) != null) {
        // __underline/bold__
        _parseInlineMarkupIntoBuffer(
          m.group(9)!,
          baseOffset: baseOffset,
          outBuf: outBuf,
          outSpans: outSpans,
          inherited: inherited.copyWith(underline: true),
        );
      } else if (m.group(10) != null) {
        // _italic_
        _parseInlineMarkupIntoBuffer(
          m.group(10)!,
          baseOffset: baseOffset,
          outBuf: outBuf,
          outSpans: outSpans,
          inherited: inherited.copyWith(italic: true),
        );
      } else if (m.group(11) != null) {
        // `code`
        final inner = HighlightTextHelper.stripHighlightTags(m.group(11)!);
        final start = outBuf.length;
        outBuf.write(inner);
        outSpans.add(
          inherited.copyWith(start: start, end: outBuf.length, code: true),
        );
      } else if (m.group(12) != null) {
        // ~~strike~~
        _parseInlineMarkupIntoBuffer(
          m.group(12)!,
          baseOffset: baseOffset,
          outBuf: outBuf,
          outSpans: outSpans,
          inherited: inherited.copyWith(strikethrough: true),
        );
      } else if (m.group(13) != null && m.group(14) != null) {
        // [label](url) — limpa inclusive eventuais `<u style="...">` legados dentro de label
        final labelRaw = m.group(13)!;
        final url = m.group(14)!;
        _parseInlineMarkupIntoBuffer(
          labelRaw,
          baseOffset: baseOffset,
          outBuf: outBuf,
          outSpans: outSpans,
          inherited: inherited.copyWith(linkUrl: url),
        );
      }
      lastEnd = m.end;
    }

    if (lastEnd < input.length) {
      final rawTail = HighlightTextHelper.stripHighlightTags(
        input.substring(lastEnd),
      );
      if (rawTail.isNotEmpty) {
        final start = outBuf.length;
        outBuf.write(rawTail);
        if (!inherited.isEmptyStyle) {
          outSpans.add(inherited.copyWith(start: start, end: outBuf.length));
        }
      }
    }
  }

  @override
  set value(TextEditingValue newValue) {
    final oldText = value.text;
    final newText = newValue.text;
    if (oldText != newText) {
      _reconcileTextChange(oldText, newText);
    }
    super.value = newValue;
  }

  void _reconcileTextChange(String oldText, String newText) {
    var prefix = 0;
    final minLen = oldText.length < newText.length
        ? oldText.length
        : newText.length;
    while (prefix < minLen &&
        oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
      prefix++;
    }

    var oldSuffix = oldText.length;
    var newSuffix = newText.length;
    while (oldSuffix > prefix &&
        newSuffix > prefix &&
        oldText.codeUnitAt(oldSuffix - 1) ==
            newText.codeUnitAt(newSuffix - 1)) {
      oldSuffix--;
      newSuffix--;
    }

    final deletedCount = oldSuffix - prefix;
    final insertedCount = newSuffix - prefix;
    final delta = insertedCount - deletedCount;

    // Atualiza índices de linha quando há quebra de linha adicionada/removida
    if (deletedCount > 0 || insertedCount > 0) {
      final lineAtChange = '\n'.allMatches(oldText.substring(0, prefix)).length;
      final deletedNewlines = '\n'
          .allMatches(oldText.substring(prefix, oldSuffix))
          .length;
      final insertedNewlines = '\n'
          .allMatches(newText.substring(prefix, newSuffix))
          .length;
      final lineDelta = insertedNewlines - deletedNewlines;
      if (lineDelta != 0) {
        final updatedLines = <int, RichBlockStyle>{};
        for (final entry in _lineStyles.entries) {
          if (entry.key <= lineAtChange) {
            updatedLines[entry.key] = entry.value;
          } else if (entry.key > lineAtChange + deletedNewlines) {
            updatedLines[entry.key + lineDelta] = entry.value;
          }
        }
        _lineStyles
          ..clear()
          ..addAll(updatedLines);
      }
    }

    final updated = <RichStyleSpan>[];
    for (final s in _spans) {
      var st = s.start;
      var en = s.end;
      if (en <= prefix) {
        updated.add(s);
        continue;
      }
      if (st >= oldSuffix) {
        st += delta;
        en += delta;
        if (en > st && st >= 0) {
          updated.add(s.copyWith(start: st, end: en));
        }
        continue;
      }
      // Sobreposição com o trecho alterado
      if (st < prefix && en > oldSuffix) {
        en += delta;
      } else if (st < prefix) {
        en = prefix;
      } else if (en > oldSuffix) {
        st = newSuffix;
        en += delta;
      } else {
        continue;
      }
      if (en > st) {
        updated.add(s.copyWith(start: st, end: en));
      }
    }

    if (insertedCount > 0 &&
        (_pendingBold ||
            _pendingItalic ||
            _pendingUnderline ||
            _pendingStrike ||
            _pendingCode ||
            _pendingHighlightHex != null ||
            _pendingTextColorHex != null ||
            _pendingFontSize != null)) {
      updated.add(
        RichStyleSpan(
          start: prefix,
          end: prefix + insertedCount,
          bold: _pendingBold,
          italic: _pendingItalic,
          underline: _pendingUnderline,
          strikethrough: _pendingStrike,
          code: _pendingCode,
          highlightHex: _pendingHighlightHex,
          textColorHex: _pendingTextColorHex,
          fontSize: _pendingFontSize,
        ),
      );
    }

    _spans
      ..clear()
      ..addAll(updated);
    _normalizeSpans(newText.length);
  }

  void _normalizeSpans(int maxLen) {
    _spans.removeWhere(
      (s) =>
          s.start >= s.end || s.end <= 0 || s.start >= maxLen || s.isEmptyStyle,
    );
    for (var i = 0; i < _spans.length; i++) {
      final s = _spans[i];
      if (s.start < 0 || s.end > maxLen) {
        _spans[i] = s.copyWith(
          start: s.start.clamp(0, maxLen),
          end: s.end.clamp(0, maxLen),
        );
      }
    }
  }

  /// Aplica ou alterna formatação inline sobre a seleção (sem caracteres Markdown).
  void toggleInlineStyle({
    bool bold = false,
    bool italic = false,
    bool underline = false,
    bool strikethrough = false,
    bool code = false,
    String? fallbackText,
  }) {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) {
      if (bold) _pendingBold = !_pendingBold;
      if (italic) _pendingItalic = !_pendingItalic;
      if (underline) _pendingUnderline = !_pendingUnderline;
      if (strikethrough) _pendingStrike = !_pendingStrike;
      if (code) _pendingCode = !_pendingCode;
      if (fallbackText != null && fallbackText.isNotEmpty) {
        final insertAt = (sel.isValid ? sel.baseOffset : text.length).clamp(
          0,
          text.length,
        );
        final nextText = text.replaceRange(insertAt, insertAt, fallbackText);
        value = TextEditingValue(
          text: nextText,
          selection: TextSelection.collapsed(
            offset: insertAt + fallbackText.length,
          ),
        );
        _applySpanOverRange(
          insertAt,
          insertAt + fallbackText.length,
          bold: bold ? true : null,
          italic: italic ? true : null,
          underline: underline ? true : null,
          strikethrough: strikethrough ? true : null,
          code: code ? true : null,
        );
      }
      notifyListeners();
      return;
    }

    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(0, text.length);
    if (end <= start) return;

    final alreadyActive = _isStyleActiveInRange(
      start,
      end,
      bold: bold,
      italic: italic,
      underline: underline,
      strikethrough: strikethrough,
      code: code,
    );

    _applySpanOverRange(
      start,
      end,
      bold: bold ? !alreadyActive : null,
      italic: italic ? !alreadyActive : null,
      underline: underline ? !alreadyActive : null,
      strikethrough: strikethrough ? !alreadyActive : null,
      code: code ? !alreadyActive : null,
    );
    notifyListeners();
  }

  bool _isStyleActiveInRange(
    int start,
    int end, {
    bool bold = false,
    bool italic = false,
    bool underline = false,
    bool strikethrough = false,
    bool code = false,
  }) {
    for (final s in _spans) {
      if (s.end <= start || s.start >= end) continue;
      if (bold && s.bold) return true;
      if (italic && s.italic) return true;
      if (underline && s.underline) return true;
      if (strikethrough && s.strikethrough) return true;
      if (code && s.code) return true;
    }
    return false;
  }

  /// Aplica ou remove cor de destaque estilo JW Library sobre a seleção atual.
  void applyHighlightColor(String? colorHex, {String? defaultText}) {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) {
      _pendingHighlightHex = colorHex;
      if (colorHex != null && defaultText != null && defaultText.isNotEmpty) {
        final insertAt = (sel.isValid ? sel.baseOffset : text.length).clamp(
          0,
          text.length,
        );
        final nextText = text.replaceRange(insertAt, insertAt, defaultText);
        value = TextEditingValue(
          text: nextText,
          selection: TextSelection.collapsed(
            offset: insertAt + defaultText.length,
          ),
        );
        _applySpanOverRange(
          insertAt,
          insertAt + defaultText.length,
          highlightHex: colorHex,
        );
      }
      notifyListeners();
      return;
    }

    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(0, text.length);
    if (end <= start) return;
    _applySpanOverRange(
      start,
      end,
      highlightHex: colorHex,
      clearHighlight: colorHex == null,
    );
    notifyListeners();
  }

  /// Aplica cor de fonte e/ou tamanho visual sobre a seleção atual (usado em assinaturas HTML WYSIWYG).
  void applyTextDecoration({
    String? textColorHex,
    bool clearTextColor = false,
    double? fontSize,
    bool clearFontSize = false,
  }) {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) {
      if (clearTextColor) {
        _pendingTextColorHex = null;
      } else if (textColorHex != null) {
        _pendingTextColorHex = textColorHex;
      }
      if (clearFontSize) {
        _pendingFontSize = null;
      } else if (fontSize != null) {
        _pendingFontSize = fontSize;
      }
      notifyListeners();
      return;
    }

    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(0, text.length);
    if (end <= start) return;
    _applySpanOverRange(
      start,
      end,
      textColorHex: textColorHex,
      clearTextColor: clearTextColor,
      fontSize: fontSize,
      clearFontSize: clearFontSize,
    );
    notifyListeners();
  }

  /// Insere link ou referência mantendo apenas [label] legível (sem URI visível).
  void insertLink({required String label, required String url}) {
    final cleanLabel = label.trim().isEmpty ? url : label.trim();
    final sel = selection;
    final start = (sel.isValid ? sel.start : text.length).clamp(0, text.length);
    final end = (sel.isValid ? sel.end : text.length).clamp(start, text.length);
    final suffixSpace = (end < text.length && text[end] == ' ') ? '' : ' ';
    final insertText = '$cleanLabel$suffixSpace';
    final nextText = text.replaceRange(start, end, insertText);
    value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: start + insertText.length),
    );
    _applySpanOverRange(start, start + cleanLabel.length, linkUrl: url);
    notifyListeners();
  }

  /// Alterna o estilo visual de parágrafo (Título H1/H2 ou Citação) sem prefixos `#` ou `>`.
  void toggleBlockStyle(RichBlockStyle style) {
    final sel = selection;
    final cursor = (sel.isValid ? sel.start : text.length).clamp(
      0,
      text.length,
    );
    final lineIndex = '\n'.allMatches(text.substring(0, cursor)).length;
    if (_lineStyles[lineIndex] == style) {
      _lineStyles.remove(lineIndex);
    } else {
      _lineStyles[lineIndex] = style;
    }
    notifyListeners();
  }

  /// Insere marcador limpo visual (`• ` ou `☐ `) no início da linha atual.
  void insertVisualLinePrefix(String cleanPrefix) {
    final sel = selection;
    final cursor = (sel.isValid ? sel.baseOffset : text.length).clamp(
      0,
      text.length,
    );
    final lastNl = text.lastIndexOf('\n', cursor > 0 ? cursor - 1 : 0);
    final lineStart = lastNl == -1 ? 0 : (lastNl + 1).clamp(0, text.length);
    final nextText = text.replaceRange(lineStart, lineStart, cleanPrefix);
    value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: cursor + cleanPrefix.length),
    );
    notifyListeners();
  }

  void addInlineImage({required String alt, required String src}) {
    final cleanSrc = src.trim();
    if (cleanSrc.isEmpty) return;
    _inlineImages.add(
      RichInlineImage(
        alt: alt.trim().isEmpty ? 'Imagem' : alt.trim(),
        src: cleanSrc,
      ),
    );
    notifyListeners();
  }

  void removeInlineImageAt(int index) {
    if (index >= 0 && index < _inlineImages.length) {
      _inlineImages.removeAt(index);
      notifyListeners();
    }
  }

  void _applySpanOverRange(
    int start,
    int end, {
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    bool? code,
    String? highlightHex,
    bool clearHighlight = false,
    String? textColorHex,
    bool clearTextColor = false,
    double? fontSize,
    bool clearFontSize = false,
    String? linkUrl,
  }) {
    if (end <= start) return;
    final cuts = <int>{0, text.length, start, end};
    for (final s in _spans) {
      cuts.add(s.start.clamp(0, text.length));
      cuts.add(s.end.clamp(0, text.length));
    }
    final sorted = cuts.toList()..sort();
    final nextSpans = <RichStyleSpan>[];
    for (var i = 0; i < sorted.length - 1; i++) {
      final a = sorted[i];
      final b = sorted[i + 1];
      if (b <= a) continue;
      final base = _mergedStyleAt(a, b);
      final inside = a >= start && b <= end;
      final updated = inside
          ? base.copyWith(
              start: a,
              end: b,
              bold: bold,
              italic: italic,
              underline: underline,
              strikethrough: strikethrough,
              code: code,
              highlightHex: highlightHex,
              clearHighlight: clearHighlight,
              textColorHex: textColorHex,
              clearTextColor: clearTextColor,
              fontSize: fontSize,
              clearFontSize: clearFontSize,
              linkUrl: linkUrl,
            )
          : base.copyWith(start: a, end: b);
      if (!updated.isEmptyStyle) {
        if (nextSpans.isNotEmpty &&
            _sameAttributes(nextSpans.last, updated) &&
            nextSpans.last.end == updated.start) {
          nextSpans[nextSpans.length - 1] = nextSpans.last.copyWith(
            end: updated.end,
          );
        } else {
          nextSpans.add(updated);
        }
      }
    }
    _spans
      ..clear()
      ..addAll(nextSpans);
  }

  RichStyleSpan _mergedStyleAt(int start, int end) {
    var bold = false;
    var italic = false;
    var underline = false;
    var strikethrough = false;
    var code = false;
    String? highlightHex;
    String? textColorHex;
    double? fontSize;
    String? linkUrl;
    for (final s in _spans) {
      if (s.end <= start || s.start >= end) continue;
      if (s.bold) bold = true;
      if (s.italic) italic = true;
      if (s.underline) underline = true;
      if (s.strikethrough) strikethrough = true;
      if (s.code) code = true;
      if (s.highlightHex != null) highlightHex = s.highlightHex;
      if (s.textColorHex != null) textColorHex = s.textColorHex;
      if (s.fontSize != null) fontSize = s.fontSize;
      if (s.linkUrl != null) linkUrl = s.linkUrl;
    }
    return RichStyleSpan(
      start: start,
      end: end,
      bold: bold,
      italic: italic,
      underline: underline,
      strikethrough: strikethrough,
      code: code,
      highlightHex: highlightHex,
      textColorHex: textColorHex,
      fontSize: fontSize,
      linkUrl: linkUrl,
    );
  }

  static bool _sameAttributes(RichStyleSpan a, RichStyleSpan b) =>
      a.bold == b.bold &&
      a.italic == b.italic &&
      a.underline == b.underline &&
      a.strikethrough == b.strikethrough &&
      a.code == b.code &&
      a.highlightHex == b.highlightHex &&
      a.textColorHex == b.textColorHex &&
      a.fontSize == b.fontSize &&
      a.linkUrl == b.linkUrl;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    final plain = text;
    if (plain.isEmpty) {
      return TextSpan(style: baseStyle, text: '');
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boundaries = <int>{0, plain.length};
    for (var i = 0; i < plain.length; i++) {
      if (plain.codeUnitAt(i) == 10) {
        boundaries.add(i);
        boundaries.add(i + 1);
      }
    }
    for (final s in _spans) {
      boundaries.add(s.start.clamp(0, plain.length));
      boundaries.add(s.end.clamp(0, plain.length));
    }
    final sorted = boundaries.toList()..sort();

    final children = <InlineSpan>[];
    var lineIdx = 0;
    for (var i = 0; i < sorted.length - 1; i++) {
      final a = sorted[i];
      final b = sorted[i + 1];
      if (b <= a) continue;
      final chunk = plain.substring(a, b);
      if (chunk == '\n') {
        children.add(TextSpan(text: '\n', style: baseStyle));
        lineIdx++;
        continue;
      }

      final blockStyle = _lineStyles[lineIdx];
      var sliceStyle = baseStyle;
      if (blockStyle == RichBlockStyle.h1) {
        sliceStyle = sliceStyle.copyWith(
          fontSize: (sliceStyle.fontSize ?? 15) + 5,
          fontWeight: FontWeight.bold,
        );
      } else if (blockStyle == RichBlockStyle.h2) {
        sliceStyle = sliceStyle.copyWith(
          fontSize: (sliceStyle.fontSize ?? 15) + 3,
          fontWeight: FontWeight.bold,
        );
      } else if (blockStyle == RichBlockStyle.h3) {
        sliceStyle = sliceStyle.copyWith(
          fontSize: (sliceStyle.fontSize ?? 15) + 1.5,
          fontWeight: FontWeight.bold,
        );
      } else if (blockStyle == RichBlockStyle.quote) {
        sliceStyle = sliceStyle.copyWith(
          fontStyle: FontStyle.italic,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        );
      }

      final run = _mergedStyleAt(a, b);
      if (run.bold) {
        sliceStyle = sliceStyle.copyWith(fontWeight: FontWeight.bold);
      }
      if (run.italic) {
        sliceStyle = sliceStyle.copyWith(fontStyle: FontStyle.italic);
      }

      final decorations = <TextDecoration>[];
      if (run.underline || run.linkUrl != null) {
        decorations.add(TextDecoration.underline);
      }
      if (run.strikethrough) {
        decorations.add(TextDecoration.lineThrough);
      }
      if (decorations.isNotEmpty) {
        sliceStyle = sliceStyle.copyWith(
          decoration: TextDecoration.combine(decorations),
        );
      }
      if (run.linkUrl != null) {
        sliceStyle = sliceStyle.copyWith(
          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF1D4ED8),
          fontWeight: FontWeight.w600,
        );
      }
      if (run.code) {
        sliceStyle = sliceStyle.copyWith(
          fontFamily: 'monospace',
          backgroundColor: isDark
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0),
        );
      }
      if (run.fontSize != null) {
        sliceStyle = sliceStyle.copyWith(fontSize: run.fontSize);
      }
      if (run.textColorHex != null) {
        sliceStyle = sliceStyle.copyWith(
          color: HighlightTextHelper.parseHexColor(run.textColorHex!),
        );
      }
      if (run.highlightHex != null) {
        final parsed = HighlightTextHelper.parseHexColor(run.highlightHex!);
        sliceStyle = sliceStyle.copyWith(
          backgroundColor: parsed.withValues(alpha: isDark ? 0.42 : 0.34),
        );
      }

      children.add(TextSpan(text: chunk, style: sliceStyle));
    }

    return TextSpan(style: baseStyle, children: children);
  }

  /// Serializa texto visível + formatação + destaques JW + links + imagens em Markdown/HTML válido.
  String toMarkup() {
    final plain = text;
    final lines = plain.split('\n');
    final buf = StringBuffer();
    var offset = 0;

    for (var lineIdx = 0; lineIdx < lines.length; lineIdx++) {
      if (lineIdx > 0) buf.write('\n');
      final line = lines[lineIdx];
      final lineStart = offset;
      final lineEnd = lineStart + line.length;

      final bStyle = _lineStyles[lineIdx];
      if (bStyle == RichBlockStyle.h1) {
        buf.write('# ');
      } else if (bStyle == RichBlockStyle.h2) {
        buf.write('## ');
      } else if (bStyle == RichBlockStyle.h3) {
        buf.write('### ');
      } else if (bStyle == RichBlockStyle.quote) {
        buf.write('> ');
      }

      final lineToSerialize = line.startsWith('• ')
          ? '- ${line.substring(2)}'
          : (line.startsWith('☐ ')
                ? '- [ ] ${line.substring(2)}'
                : (line.startsWith('☑ ')
                      ? '- [x] ${line.substring(2)}'
                      : line));

      if (lineToSerialize == line) {
        _writeFormattedSlice(buf, plain, lineStart, lineEnd);
      } else {
        // Ajusta offset após prefixo visual (`• ` / `☐ ` -> `- ` / `- [ ] `)
        final diff = lineToSerialize.length - line.length;
        buf.write(lineToSerialize.substring(0, 2 + diff));
        _writeFormattedSlice(buf, plain, lineStart + 2, lineEnd);
      }

      offset = lineEnd + 1;
    }

    if (_inlineImages.isNotEmpty) {
      if (buf.isNotEmpty && !buf.toString().endsWith('\n')) {
        buf.write('\n');
      }
      for (final img in _inlineImages) {
        buf.writeln(img.toMarkup());
      }
    }

    return buf.toString().trimRight();
  }

  void _writeFormattedSlice(
    StringBuffer buf,
    String plain,
    int rangeStart,
    int rangeEnd,
  ) {
    if (rangeEnd <= rangeStart) return;
    final cuts = <int>{rangeStart, rangeEnd};
    for (final s in _spans) {
      if (s.end <= rangeStart || s.start >= rangeEnd) continue;
      cuts.add(s.start.clamp(rangeStart, rangeEnd));
      cuts.add(s.end.clamp(rangeStart, rangeEnd));
    }
    final sorted = cuts.toList()..sort();

    // Agrupa trechos adjacentes com o mesmo linkUrl para não quebrar `[label](url)`
    var i = 0;
    while (i < sorted.length - 1) {
      final a = sorted[i];
      final b = sorted[i + 1];
      final firstStyle = _mergedStyleAt(a, b);
      if (firstStyle.linkUrl != null) {
        var groupEnd = b;
        var j = i + 1;
        while (j < sorted.length - 1) {
          final nextStyle = _mergedStyleAt(sorted[j], sorted[j + 1]);
          if (nextStyle.linkUrl == firstStyle.linkUrl) {
            groupEnd = sorted[j + 1];
            j++;
          } else {
            break;
          }
        }
        final label = plain
            .substring(a, groupEnd)
            .replaceAll('[', '(')
            .replaceAll(']', ')');
        final linkToken = '[$label](${firstStyle.linkUrl})';
        if (firstStyle.highlightHex != null) {
          buf.write(
            '<u style="color:${firstStyle.highlightHex}">$linkToken</u>',
          );
        } else {
          buf.write(linkToken);
        }
        i = j;
        continue;
      }

      var chunk = plain.substring(a, b);
      if (firstStyle.code) chunk = '`$chunk`';
      if (firstStyle.strikethrough) chunk = '~~$chunk~~';
      if (firstStyle.underline) chunk = '__${chunk}__';
      if (firstStyle.bold && firstStyle.italic) {
        chunk = '***$chunk***';
      } else if (firstStyle.bold) {
        chunk = '**$chunk**';
      } else if (firstStyle.italic) {
        chunk = '*$chunk*';
      }
      if (firstStyle.highlightHex != null) {
        chunk = '<u style="color:${firstStyle.highlightHex}">$chunk</u>';
      }
      buf.write(chunk);
      i++;
    }
  }

  /// Constrói controlador WYSIWYG a partir de HTML (ex.: assinaturas de e-mail / rascunhos HTML),
  /// ocultando todas as tags (`<b>`, `<i>`, `<u>`, `<a href>`, `<span style>`, `<img src>`).
  factory RichFormattedEditingController.fromHtml(String rawHtml) {
    if (rawHtml.trim().isEmpty) {
      return RichFormattedEditingController();
    }
    var work = rawHtml.replaceAll('\r\n', '\n');
    final images = <RichInlineImage>[];
    work = work.replaceAllMapped(
      RegExp(r'<img\b([^>]*)/?>', caseSensitive: false),
      (m) {
        final attrs = m.group(1) ?? '';
        final srcMatch = RegExp(
          r'''src\s*=\s*(?:"([^"]*)"|'([^']*)')''',
          caseSensitive: false,
        ).firstMatch(attrs);
        final altMatch = RegExp(
          r'''alt\s*=\s*(?:"([^"]*)"|'([^']*)')''',
          caseSensitive: false,
        ).firstMatch(attrs);
        final src = (srcMatch?.group(1) ?? srcMatch?.group(2) ?? '').trim();
        final alt = (altMatch?.group(1) ?? altMatch?.group(2) ?? '').trim();
        if (src.isNotEmpty) {
          images.add(
            RichInlineImage(alt: alt.isEmpty ? 'Imagem' : alt, src: src),
          );
        }
        return '';
      },
    );
    work = work
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>\s*<p\b[^>]*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'</?(?:p|div)\b[^>]*>', caseSensitive: false), '\n')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"');

    final outBuf = StringBuffer();
    final spans = <RichStyleSpan>[];
    final stack = <RichStyleSpan>[];

    RichStyleSpan currentStyle() {
      var res = const RichStyleSpan(start: 0, end: 0);
      for (final s in stack) {
        res = res.copyWith(
          bold: s.bold ? true : null,
          italic: s.italic ? true : null,
          underline: s.underline ? true : null,
          strikethrough: s.strikethrough ? true : null,
          textColorHex: s.textColorHex,
          fontSize: s.fontSize,
          linkUrl: s.linkUrl,
        );
      }
      return res;
    }

    final tagRegex = RegExp(r'<([^>]+)>');
    var cursor = 0;
    for (final m in tagRegex.allMatches(work)) {
      if (m.start > cursor) {
        final piece = work.substring(cursor, m.start);
        final st = currentStyle();
        final sIdx = outBuf.length;
        outBuf.write(piece);
        if (!st.isEmptyStyle) {
          spans.add(st.copyWith(start: sIdx, end: outBuf.length));
        }
      }
      final rawTag = (m.group(1) ?? '').trim();
      final lower = rawTag.toLowerCase();
      if (lower.startsWith('/')) {
        if (stack.isNotEmpty) stack.removeLast();
      } else {
        final tagName = lower.split(RegExp(r'[\s/]')).first;
        if (tagName == 'b' || tagName == 'strong') {
          stack.add(const RichStyleSpan(start: 0, end: 0, bold: true));
        } else if (tagName == 'i' || tagName == 'em') {
          stack.add(const RichStyleSpan(start: 0, end: 0, italic: true));
        } else if (tagName == 'u') {
          final colorM = RegExp(r'color\s*:\s*(#[0-9a-fA-F]{6})')
              .firstMatch(rawTag);
          stack.add(
            colorM != null
                ? RichStyleSpan(start: 0, end: 0, highlightHex: colorM.group(1))
                : const RichStyleSpan(start: 0, end: 0, underline: true),
          );
        } else if (tagName == 's' || tagName == 'del') {
          stack.add(const RichStyleSpan(start: 0, end: 0, strikethrough: true));
        } else if (tagName == 'a') {
          final hrefM = RegExp(
            r'''href\s*=\s*(?:"([^"]*)"|'([^']*)')''',
            caseSensitive: false,
          ).firstMatch(rawTag);
          final href = (hrefM?.group(1) ?? hrefM?.group(2) ?? '').trim();
          stack.add(
            RichStyleSpan(
              start: 0,
              end: 0,
              linkUrl: href.isNotEmpty ? href : null,
            ),
          );
        } else if (tagName == 'span') {
          final colorM = RegExp(r'color\s*:\s*(#[0-9a-fA-F]{6})')
              .firstMatch(rawTag);
          final sizeM = RegExp(r'font-size\s*:\s*(\d+)px').firstMatch(rawTag);
          stack.add(
            RichStyleSpan(
              start: 0,
              end: 0,
              textColorHex: colorM?.group(1),
              fontSize: sizeM != null ? double.tryParse(sizeM.group(1)!) : null,
            ),
          );
        } else {
          stack.add(const RichStyleSpan(start: 0, end: 0));
        }
      }
      cursor = m.end;
    }
    if (cursor < work.length) {
      final tail = work.substring(cursor);
      final st = currentStyle();
      final sIdx = outBuf.length;
      outBuf.write(tail);
      if (!st.isEmptyStyle) {
        spans.add(st.copyWith(start: sIdx, end: outBuf.length));
      }
    }

    final clean = outBuf
        .toString()
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    final clipped = spans
        .where((s) => s.start < clean.length)
        .map(
          (s) => s.copyWith(end: s.end > clean.length ? clean.length : s.end),
        )
        .where((s) => s.end > s.start && !s.isEmptyStyle)
        .toList();

    return RichFormattedEditingController._internal(
      visibleText: clean,
      spans: clipped,
      lineStyles: const {},
      inlineImages: images,
    );
  }

  /// Serializa texto visível + formatação + links + imagens como HTML limpo (ideal para assinaturas).
  String toHtml({String imageStyle = 'max-height:64px; height:auto;'}) {
    final plain = text;
    final buf = StringBuffer();
    final lines = plain.split('\n');
    var offset = 0;
    for (var lineIdx = 0; lineIdx < lines.length; lineIdx++) {
      if (lineIdx > 0) buf.write('<br>');
      final line = lines[lineIdx];
      final lineStart = offset;
      final lineEnd = lineStart + line.length;
      if (lineEnd > lineStart) {
        final cuts = <int>{lineStart, lineEnd};
        for (final s in _spans) {
          if (s.end <= lineStart || s.start >= lineEnd) continue;
          cuts.add(s.start.clamp(lineStart, lineEnd));
          cuts.add(s.end.clamp(lineStart, lineEnd));
        }
        final sorted = cuts.toList()..sort();
        for (var i = 0; i < sorted.length - 1; i++) {
          final a = sorted[i];
          final b = sorted[i + 1];
          if (b <= a) continue;
          final st = _mergedStyleAt(a, b);
          var chunk = plain
              .substring(a, b)
              .replaceAll('&', '&amp;')
              .replaceAll('<', '&lt;')
              .replaceAll('>', '&gt;');
          if (st.bold) chunk = '<b>$chunk</b>';
          if (st.italic) chunk = '<i>$chunk</i>';
          if (st.underline) chunk = '<u>$chunk</u>';
          if (st.strikethrough) chunk = '<s>$chunk</s>';
          final styles = <String>[];
          if (st.textColorHex != null) styles.add('color: ${st.textColorHex};');
          if (st.fontSize != null) {
            styles.add('font-size: ${st.fontSize!.toInt()}px;');
          }
          if (styles.isNotEmpty) {
            chunk = '<span style="${styles.join(' ')}">$chunk</span>';
          }
          if (st.linkUrl != null) {
            chunk = '<a href="${st.linkUrl}">$chunk</a>';
          }
          buf.write(chunk);
        }
      }
      offset = lineEnd + 1;
    }
    if (_inlineImages.isNotEmpty) {
      if (buf.isNotEmpty) buf.write('<br>');
      for (final img in _inlineImages) {
        buf.write(
          '<img src="${img.src}" alt="${img.alt}" style="$imageStyle" />',
        );
      }
    }
    return buf.toString();
  }
}
