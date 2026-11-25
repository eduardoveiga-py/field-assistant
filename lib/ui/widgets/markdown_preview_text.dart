import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'app_reference_viewer.dart';
import 'highlight_text_helper.dart';

/// Widget de exibição de texto formatado para pré-visualização e leitura em cards e painéis.
/// Suporta sublinhado colorido estilo JW Library (`<u style="color:#hex">`), marca-texto `<mark>`,
/// formatação Markdown, referências clicáveis (`app://ref/...`) e destaque direto por seleção de texto.
class MarkdownPreviewText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;
  final TextAlign textAlign;
  final ValueChanged<String>? onLinkTap;
  final bool selectable;
  final bool allowHighlights;
  final Future<void> Function(String updatedText)? onContentUpdated;

  const MarkdownPreviewText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign = TextAlign.start,
    this.onLinkTap,
    this.selectable = false,
    this.allowHighlights = false,
    this.onContentUpdated,
  });

  /// Remove marcadores Markdown e tags de destaque retornando texto limpo puro.
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
    // Remove tags HTML como <mark...>...</mark> e <u...></u>
    cleaned = HighlightTextHelper.stripHighlightTags(cleaned);
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
    cleaned = cleaned.replaceAll(
      RegExp(r'^-\s+\[\s*\]\s+', multiLine: true),
      '☐ ',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'^-\s+\[x\]\s+', multiLine: true),
      '☑ ',
    );
    // Substitui marcadores de lista por bullet
    cleaned = cleaned.replaceAll(RegExp(r'^[-*]\s+', multiLine: true), '• ');
    // Remove quebras de linha excessivas
    cleaned = cleaned.replaceAll(RegExp(r'\n{2,}'), '\n');

    return cleaned.trim();
  }

  /// Mantido para compatibilidade direta com chamadas e testes unitários existentes.
  static List<InlineSpan> parseSpans(
    String rawText,
    TextStyle baseStyle, {
    ValueChanged<String>? onLinkTap,
    List<GestureRecognizer>? disposables,
  }) {
    final res = HighlightTextHelper.buildMappedSpans(
      rawText.replaceAllMapped(
        RegExp(r'!\[([^\]]*)\]\([^\)]+\)'),
        (m) => (m.group(1)?.isNotEmpty ?? false) ? '[${m.group(1)}]' : '',
      ),
      baseStyle,
      onLinkTap: onLinkTap,
      disposables: disposables,
    );
    return res.spans;
  }

  @override
  State<MarkdownPreviewText> createState() => _MarkdownPreviewTextState();
}

class _MarkdownPreviewTextState extends State<MarkdownPreviewText> {
  final List<GestureRecognizer> _recognizers = [];
  late String _liveText;
  TextSelection? _activeSelection;

  @override
  void initState() {
    super.initState();
    _liveText = widget.text;
  }

  @override
  void didUpdateWidget(covariant MarkdownPreviewText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _liveText = widget.text;
    }
    if (oldWidget.text != widget.text ||
        oldWidget.onLinkTap != widget.onLinkTap) {
      _disposeRecognizers();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _applySelectionHighlight(
    MappedRichTextResult mapped,
    int selStart,
    int selEnd,
    String? colorHex,
  ) async {
    final updated = HighlightTextHelper.applyUnderlineWithMap(
      rawText: _liveText,
      map: mapped,
      selectionStart: selStart,
      selectionEnd: selEnd,
      colorHex: colorHex,
    );
    if (updated == _liveText) return;
    setState(() {
      _liveText = updated;
      _activeSelection = null;
    });
    if (widget.onContentUpdated != null) {
      await widget.onContentUpdated!(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();

    final defaultStyle = DefaultTextStyle.of(context).style;
    final effectiveStyle = widget.style != null
        ? defaultStyle.merge(widget.style)
        : defaultStyle;

    void handleTap(String url) {
      if (widget.onLinkTap != null) {
        widget.onLinkTap!(url);
      } else {
        AppReferenceViewer.openUrl(context, url);
      }
    }

    final displaySource = _liveText.replaceAllMapped(
      RegExp(r'!\[([^\]]*)\]\([^\)]+\)'),
      (m) => (m.group(1)?.isNotEmpty ?? false) ? '[${m.group(1)}]' : '',
    );

    final mapped = HighlightTextHelper.buildMappedSpans(
      displaySource,
      effectiveStyle,
      onLinkTap: handleTap,
      disposables: _recognizers,
    );

    if (mapped.spans.isEmpty) {
      return const SizedBox.shrink();
    }

    final canHighlightInline =
        widget.allowHighlights && widget.onContentUpdated != null;

    if (widget.selectable || canHighlightInline) {
      final hasSelection =
          canHighlightInline &&
          _activeSelection != null &&
          !_activeSelection!.isCollapsed &&
          _activeSelection!.end > _activeSelection!.start;
      final isDark = Theme.of(context).brightness == Brightness.dark;

      final selectableWidget = SelectableText.rich(
        TextSpan(children: mapped.spans),
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        onSelectionChanged: canHighlightInline
            ? (sel, _) {
                if (mounted) {
                  setState(() => _activeSelection = sel);
                }
              }
            : null,
        contextMenuBuilder: (ctx, editableTextState) {
          final sel = editableTextState.textEditingValue.selection;
          final canHighlight =
              canHighlightInline && sel.isValid && !sel.isCollapsed;
          final items = <ContextMenuButtonItem>[
            ...editableTextState.contextMenuButtonItems,
            if (canHighlight) ...[
              for (final c in HighlightTextHelper.colors)
                ContextMenuButtonItem(
                  label: 'Sublinhar (${c.label})',
                  onPressed: () {
                    ContextMenuController.removeAny();
                    _applySelectionHighlight(mapped, sel.start, sel.end, c.hex);
                  },
                ),
              ContextMenuButtonItem(
                label: 'Remover Sublinhado',
                onPressed: () {
                  ContextMenuController.removeAny();
                  _applySelectionHighlight(mapped, sel.start, sel.end, null);
                },
              ),
            ],
          ];
          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: editableTextState.contextMenuAnchors,
            buttonItems: items,
          );
        },
      );

      if (!canHighlightInline) {
        return selectableWidget;
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          selectableWidget,
          if (hasSelection) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Sublinhar:',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                  for (final c in HighlightTextHelper.colors)
                    InkWell(
                      key: Key('btn_inline_hl_${c.id}'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _applySelectionHighlight(
                        mapped,
                        _activeSelection!.start,
                        _activeSelection!.end,
                        c.hex,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: CircleAvatar(
                          radius: 8,
                          backgroundColor: c.color,
                        ),
                      ),
                    ),
                  IconButton(
                    key: const Key('btn_inline_hl_clear'),
                    tooltip: 'Remover sublinhado',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 26,
                      minHeight: 26,
                    ),
                    icon: const Icon(
                      Icons.format_clear,
                      size: 16,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => _applySelectionHighlight(
                      mapped,
                      _activeSelection!.start,
                      _activeSelection!.end,
                      null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    return Text.rich(
      TextSpan(children: mapped.spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      textAlign: widget.textAlign,
    );
  }
}
