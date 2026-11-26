import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'app_inline_image_view.dart';
import 'app_reference_viewer.dart';
import 'highlight_text_helper.dart';
import 'jw_highlight_floating_toolbar.dart';

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
  final JwHighlightFloatingController _hlFloating =
      JwHighlightFloatingController();
  late String _liveText;

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
    _hlFloating.dispose();
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
    int segRawStart,
    int segRawEnd,
    String segText,
    MappedRichTextResult mapped,
    int selStart,
    int selEnd,
    String? colorHex,
  ) async {
    final updatedSeg = HighlightTextHelper.applyUnderlineWithMap(
      rawText: segText,
      map: mapped,
      selectionStart: selStart,
      selectionEnd: selEnd,
      colorHex: colorHex,
    );
    if (updatedSeg == segText) return;
    final updated = _liveText.replaceRange(segRawStart, segRawEnd, updatedSeg);
    _hlFloating.hide();
    setState(() {
      _liveText = updated;
    });
    if (widget.onContentUpdated != null) {
      await widget.onContentUpdated!(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();

    final isDark = Theme.of(context).brightness == Brightness.dark;
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

    // Em visualizações sem corte de linhas (maxLines == null), extrai imagens Markdown e referências
    // de gravura (app://ref/picture/<id>) para exibir a foto real inline.
    if (widget.maxLines == null) {
      final mediaRegex = RegExp(
        r'!\[([^\]]*)\]\(([^\)]+)\)|(?:<u\b[^>]*>)?\[([^\]]*)\]\((app://ref/picture/[^)\s]+)\)(?:</u>)?',
        multiLine: true,
        caseSensitive: false,
      );
      final mediaMatches = mediaRegex.allMatches(_liveText).toList();
      if (mediaMatches.isNotEmpty) {
        final children = <Widget>[];
        var cursor = 0;

        void addTextSegment(int start, int end) {
          final rawSlice = _liveText.substring(start, end);
          if (rawSlice.trim().isEmpty) return;
          final mapped = HighlightTextHelper.buildMappedSpans(
            rawSlice,
            effectiveStyle,
            onLinkTap: handleTap,
            disposables: _recognizers,
            isDark: isDark,
          );
          if (mapped.spans.isEmpty) return;
          final canHighlightInline =
              widget.allowHighlights && widget.onContentUpdated != null;
          if (widget.selectable || canHighlightInline) {
            final anchorKey = GlobalKey();
            children.add(
              Listener(
                key: anchorKey,
                onPointerDown: (e) => _hlFloating.recordPointerDown(e.position),
                onPointerUp: (e) => _hlFloating.recordPointerUp(e.position),
                child: SelectableText.rich(
                  TextSpan(children: mapped.spans),
                  textAlign: widget.textAlign,
                  onSelectionChanged: canHighlightInline
                      ? (sel, _) {
                          if (!mounted) return;
                          if (sel.isValid &&
                              !sel.isCollapsed &&
                              sel.end > sel.start) {
                            _hlFloating.show(
                              context: context,
                              keyPrefix: 'inline',
                              anchorKey: anchorKey,
                              onPickColor: (hex) => _applySelectionHighlight(
                                start,
                                end,
                                rawSlice,
                                mapped,
                                sel.start,
                                sel.end,
                                hex,
                              ),
                            );
                          } else {
                            _hlFloating.hide();
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
                            label: 'Marcar (${c.label})',
                            onPressed: () {
                              ContextMenuController.removeAny();
                              _hlFloating.hide();
                              _applySelectionHighlight(
                                start,
                                end,
                                rawSlice,
                                mapped,
                                sel.start,
                                sel.end,
                                c.hex,
                              );
                            },
                          ),
                        ContextMenuButtonItem(
                          label: 'Remover marcação',
                          onPressed: () {
                            ContextMenuController.removeAny();
                            _hlFloating.hide();
                            _applySelectionHighlight(
                              start,
                              end,
                              rawSlice,
                              mapped,
                              sel.start,
                              sel.end,
                              null,
                            );
                          },
                        ),
                      ],
                    ];
                    return AdaptiveTextSelectionToolbar.buttonItems(
                      anchors: editableTextState.contextMenuAnchors,
                      buttonItems: items,
                    );
                  },
                ),
              ),
            );
          } else {
            children.add(
              Text.rich(
                TextSpan(children: mapped.spans),
                textAlign: widget.textAlign,
              ),
            );
          }
        }

        for (final m in mediaMatches) {
          if (m.start > cursor) {
            addTextSegment(cursor, m.start);
          }
          final rawAlt = m.group(1) ?? m.group(3) ?? 'Imagem';
          final cleanAlt = HighlightTextHelper.stripHighlightTags(rawAlt)
              .replaceFirst(RegExp(r'^🖼️\s*'), '')
              .trim();
          final src = m.group(2) ?? m.group(4) ?? '';
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: AppInlineImageView(
                src: src,
                alt: cleanAlt.isEmpty ? 'Imagem' : cleanAlt,
                maxHeight: 220,
              ),
            ),
          );
          cursor = m.end;
          while (cursor < _liveText.length &&
              (_liveText[cursor] == '\n' || _liveText[cursor] == '\r')) {
            cursor++;
          }
        }
        if (cursor < _liveText.length) {
          addTextSegment(cursor, _liveText.length);
        }
        if (children.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: children,
        );
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
      isDark: isDark,
    );

    if (mapped.spans.isEmpty) {
      return const SizedBox.shrink();
    }

    final canHighlightInline =
        widget.allowHighlights && widget.onContentUpdated != null;

    if (widget.selectable || canHighlightInline) {
      final anchorKey = GlobalKey();
      final selectableWidget = Listener(
        key: anchorKey,
        onPointerDown: (e) => _hlFloating.recordPointerDown(e.position),
        onPointerUp: (e) => _hlFloating.recordPointerUp(e.position),
        child: SelectableText.rich(
          TextSpan(children: mapped.spans),
          textAlign: widget.textAlign,
          minLines: widget.maxLines != null && widget.maxLines! > 1 ? 1 : null,
          maxLines: widget.maxLines,
          onSelectionChanged: canHighlightInline
              ? (sel, _) {
                  if (!mounted) return;
                  if (sel.isValid && !sel.isCollapsed && sel.end > sel.start) {
                    _hlFloating.show(
                      context: context,
                      keyPrefix: 'inline',
                      anchorKey: anchorKey,
                      onPickColor: (hex) => _applySelectionHighlight(
                        0,
                        _liveText.length,
                        _liveText,
                        mapped,
                        sel.start,
                        sel.end,
                        hex,
                      ),
                    );
                  } else {
                    _hlFloating.hide();
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
                    label: 'Marcar (${c.label})',
                    onPressed: () {
                      ContextMenuController.removeAny();
                      _hlFloating.hide();
                      _applySelectionHighlight(
                        0,
                        _liveText.length,
                        _liveText,
                        mapped,
                        sel.start,
                        sel.end,
                        c.hex,
                      );
                    },
                  ),
                ContextMenuButtonItem(
                  label: 'Remover marcação',
                  onPressed: () {
                    ContextMenuController.removeAny();
                    _hlFloating.hide();
                    _applySelectionHighlight(
                      0,
                      _liveText.length,
                      _liveText,
                      mapped,
                      sel.start,
                      sel.end,
                      null,
                    );
                  },
                ),
              ],
            ];
            return AdaptiveTextSelectionToolbar.buttonItems(
              anchors: editableTextState.contextMenuAnchors,
              buttonItems: items,
            );
          },
        ),
      );
      return selectableWidget;
    }

    return Text.rich(
      TextSpan(children: mapped.spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      textAlign: widget.textAlign,
    );
  }
}
