import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../app_inline_image_view.dart';
import '../app_reference_viewer.dart';
import '../highlight_text_helper.dart';
import '../markdown_preview_text.dart';

/// Blocos estruturados suportados no Segundo Cérebro estilo Notion:
/// - `<details><summary>...</summary>...</details>` ou `:::toggle ... :::`
/// - Callouts GFM/Notion: `> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`
/// - Tabelas Markdown GFM (`| a | b |\n|---|---|\n| 1 | 2 |`)
/// - Checklists interativos clicáveis (`- [ ] ...` / `- [x] ...`)
/// - Texto Markdown rico com imagens e destaques JW Library
sealed class SecondBrainBlock {
  const SecondBrainBlock();
}

class ToggleSecondBrainBlock extends SecondBrainBlock {
  final String summary;
  final String bodyMarkdown;
  const ToggleSecondBrainBlock({
    required this.summary,
    required this.bodyMarkdown,
  });
}

class CalloutSecondBrainBlock extends SecondBrainBlock {
  final String kind; // NOTE, TIP, IMPORTANT, WARNING
  final String bodyMarkdown;
  const CalloutSecondBrainBlock({
    required this.kind,
    required this.bodyMarkdown,
  });
}

class TableSecondBrainBlock extends SecondBrainBlock {
  final List<String> headers;
  final List<List<String>> rows;
  const TableSecondBrainBlock({required this.headers, required this.rows});
}

class ChecklistSecondBrainBlock extends SecondBrainBlock {
  final int sourceLineIndex;
  final bool checked;
  final String text;
  const ChecklistSecondBrainBlock({
    required this.sourceLineIndex,
    required this.checked,
    required this.text,
  });
}

class RichTextSecondBrainBlock extends SecondBrainBlock {
  final String markdown;
  const RichTextSecondBrainBlock(this.markdown);
}

/// Parser puro e determinístico para dividir Markdown em blocos estilo Notion
/// sem quebrar trechos com marcações JW (`<u>`/`<mark>`) nem links `app://ref/...`.
class SecondBrainBlockParser {
  SecondBrainBlockParser._();

  static final RegExp _checklistRegex = RegExp(
    r'^\s*(?:-\s+\[([ xX])\]|([☐☑]))\s+(.*)$',
  );
  static final RegExp _calloutStartRegex = RegExp(
    r'^>\s*\[!(NOTE|TIP|IMPORTANT|WARNING)\]\s*(.*)$',
    caseSensitive: false,
  );
  static final RegExp _toggleDirectiveStartRegex = RegExp(
    r'^:::toggle\s+(.+)$',
    caseSensitive: false,
  );
  static final RegExp _tableDividerRegex = RegExp(
    r'^\s*\|?\s*:?-{2,}:?(?:\s*\|\s*:?-{2,}:?)*\s*\|?\s*$',
  );

  static bool containsRichBlocks(String raw) {
    if (raw.trim().isEmpty) return false;
    final norm = raw.replaceAll('\r\n', '\n');
    if (norm.contains('<details>') ||
        norm.contains(':::toggle') ||
        RegExp(
          r'^>\s*\[!(NOTE|TIP|IMPORTANT|WARNING)\]',
          multiLine: true,
          caseSensitive: false,
        ).hasMatch(norm) ||
        RegExp(
          r'^\s*(?:-\s+\[[ xX]\]|[☐☑])\s+',
          multiLine: true,
        ).hasMatch(norm)) {
      return true;
    }
    return parse(norm).any((b) => b is TableSecondBrainBlock);
  }

  /// Normaliza diretivas de bloco (`:::toggle`, `<details>`, `[!TIP]`, separadores GFM `|---|`, `[[wikilink]]`)
  /// para pré-visualização inline em cartões sem perder tags `<u>`/`<mark>` nem links `[rótulo](url)`.
  static String toInlinePreviewMarkup(String raw) {
    if (raw.trim().isEmpty) return '';
    var out = raw.replaceAll('\r\n', '\n');
    out = out.replaceAllMapped(
      RegExp(
        r'<details\b[^>]*>\s*<summary\b[^>]*>([\s\S]*?)</summary>\s*([\s\S]*?)\s*</details>',
        caseSensitive: false,
      ),
      (m) => '▸ **${(m.group(1) ?? '').trim()}**\n${(m.group(2) ?? '').trim()}',
    );
    out = out.replaceAllMapped(
      RegExp(r'^:::toggle\s+(.+)$', multiLine: true, caseSensitive: false),
      (m) => '▸ **${(m.group(1) ?? '').trim()}**',
    );
    out = out.replaceAll(RegExp(r'^:::\s*$', multiLine: true), '');
    out = out.replaceAllMapped(
      RegExp(
        r'^>\s*\[!(NOTE|TIP|IMPORTANT|WARNING)\]\s*',
        multiLine: true,
        caseSensitive: false,
      ),
      (m) {
        final label = switch ((m.group(1) ?? '').toUpperCase()) {
          'TIP' => 'Dica',
          'IMPORTANT' => 'Importante',
          'WARNING' => 'Atenção',
          _ => 'Nota',
        };
        return '**$label:** ';
      },
    );
    out = out.replaceAll(
      RegExp(
        r'^\s*\|?\s*:?-{2,}:?(?:\s*\|\s*:?-{2,}:?)*\s*\|?\s*$',
        multiLine: true,
      ),
      '',
    );
    out = out.replaceAllMapped(
      RegExp(r'!\[([^\]]*)\]\([^\)]+\)'),
      (m) => (m.group(1) ?? '').trim(),
    );
    out = out.replaceAllMapped(
      RegExp(r'\[\[([^\[\]\n|]+)(?:\|([^\[\]\n]+))?\]\]'),
      (m) => (m.group(2) ?? m.group(1) ?? '').trim(),
    );
    return out.replaceAll(RegExp(r'\n{2,}'), '\n').trim();
  }

  static List<SecondBrainBlock> parse(String raw) {
    if (raw.trim().isEmpty) return const [];
    final lines = raw.replaceAll('\r\n', '\n').split('\n');
    final blocks = <SecondBrainBlock>[];
    final textBuffer = <String>[];

    void flushTextBuffer() {
      if (textBuffer.isEmpty) return;
      final joined = textBuffer.join('\n').trim();
      textBuffer.clear();
      if (joined.isNotEmpty) {
        blocks.add(RichTextSecondBrainBlock(joined));
      }
    }

    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      // 1. Bloco expansível HTML <details><summary>...</summary> ... </details>
      if (trimmed.toLowerCase().startsWith('<details>')) {
        var endIdx = -1;
        for (var j = i; j < lines.length; j++) {
          if (lines[j].toLowerCase().contains('</details>')) {
            endIdx = j;
            break;
          }
        }
        if (endIdx != -1) {
          flushTextBuffer();
          final chunk = lines.sublist(i, endIdx + 1).join('\n');
          final sumMatch = RegExp(
            r'<summary>([\s\S]*?)</summary>',
            caseSensitive: false,
          ).firstMatch(chunk);
          final summary = sumMatch?.group(1)?.trim() ?? 'Detalhes';
          var body = chunk
              .replaceFirst(
                RegExp(r'^[\s\S]*?</summary>', caseSensitive: false),
                '',
              )
              .replaceFirst(RegExp(r'<details>', caseSensitive: false), '')
              .replaceFirst(RegExp(r'</details>\s*$', caseSensitive: false), '')
              .trim();
          blocks.add(
            ToggleSecondBrainBlock(summary: summary, bodyMarkdown: body),
          );
          i = endIdx + 1;
          continue;
        }
      }

      // 2. Bloco expansível :::toggle Título ... :::
      final dirMatch = _toggleDirectiveStartRegex.firstMatch(trimmed);
      if (dirMatch != null) {
        var endIdx = -1;
        for (var j = i + 1; j < lines.length; j++) {
          if (lines[j].trim() == ':::') {
            endIdx = j;
            break;
          }
        }
        if (endIdx != -1) {
          flushTextBuffer();
          final summary = dirMatch.group(1)!.trim();
          final body = lines.sublist(i + 1, endIdx).join('\n').trim();
          blocks.add(
            ToggleSecondBrainBlock(summary: summary, bodyMarkdown: body),
          );
          i = endIdx + 1;
          continue;
        }
      }

      // 3. Callout Notion / GFM: > [!NOTE] ...
      final calloutMatch = _calloutStartRegex.firstMatch(trimmed);
      if (calloutMatch != null) {
        flushTextBuffer();
        final kind = calloutMatch.group(1)!.toUpperCase();
        final bodyLines = <String>[];
        final firstRest = calloutMatch.group(2)?.trim() ?? '';
        if (firstRest.isNotEmpty) bodyLines.add(firstRest);
        var j = i + 1;
        while (j < lines.length && lines[j].trimLeft().startsWith('>')) {
          final stripped = lines[j].trimLeft().replaceFirst(
            RegExp(r'^>\s?'),
            '',
          );
          bodyLines.add(stripped);
          j++;
        }
        blocks.add(
          CalloutSecondBrainBlock(
            kind: kind,
            bodyMarkdown: bodyLines.join('\n').trim(),
          ),
        );
        i = j;
        continue;
      }

      // 4. Tabela GFM (`| h1 | h2 |\n|---|---|\n| v1 | v2 |`)
      if (trimmed.contains('|') &&
          i + 1 < lines.length &&
          _tableDividerRegex.hasMatch(lines[i + 1].trim())) {
        final headers = _splitTableRow(trimmed);
        if (headers.isNotEmpty) {
          flushTextBuffer();
          final rows = <List<String>>[];
          var j = i + 2;
          while (j < lines.length) {
            final rowLine = lines[j].trim();
            if (!rowLine.contains('|') || rowLine.isEmpty) break;
            rows.add(_splitTableRow(rowLine, expectedCols: headers.length));
            j++;
          }
          blocks.add(TableSecondBrainBlock(headers: headers, rows: rows));
          i = j;
          continue;
        }
      }

      // 5. Checklist interativa (`- [ ] tarefa` / `- [x] tarefa`)
      final checkMatch = _checklistRegex.firstMatch(line);
      if (checkMatch != null) {
        flushTextBuffer();
        final bracketMark = checkMatch.group(1);
        final unicodeMark = checkMatch.group(2);
        final checked = bracketMark != null
            ? bracketMark.toLowerCase() == 'x'
            : unicodeMark == '☑';
        blocks.add(
          ChecklistSecondBrainBlock(
            sourceLineIndex: i,
            checked: checked,
            text: (checkMatch.group(3) ?? '').trim(),
          ),
        );
        i++;
        continue;
      }

      textBuffer.add(line);
      i++;
    }

    flushTextBuffer();
    return blocks;
  }

  /// Alterna `[ ]` <-> `[x]` na linha [sourceLineIndex] preservando exatamente o restante do texto.
  static String toggleChecklistLine(String rawMarkdown, int sourceLineIndex) {
    final norm = rawMarkdown.replaceAll('\r\n', '\n');
    final lines = norm.split('\n');
    if (sourceLineIndex < 0 || sourceLineIndex >= lines.length) {
      return rawMarkdown;
    }
    final line = lines[sourceLineIndex];
    final m = _checklistRegex.firstMatch(line);
    if (m == null) return rawMarkdown;
    final bracketMark = m.group(1);
    if (bracketMark != null) {
      final isChecked = bracketMark.toLowerCase() == 'x';
      lines[sourceLineIndex] = line.replaceFirst(
        RegExp(r'-\s+\[[ xX]\]'),
        isChecked ? '- [ ]' : '- [x]',
      );
    } else {
      final isChecked = m.group(2) == '☑';
      lines[sourceLineIndex] = line.replaceFirst(
        RegExp(r'[☐☑]'),
        isChecked ? '☐' : '☑',
      );
    }
    return lines.join('\n');
  }

  static List<String> _splitTableRow(String row, {int? expectedCols}) {
    var trimmed = row.trim();
    if (trimmed.startsWith('|')) trimmed = trimmed.substring(1);
    if (trimmed.endsWith('|')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    final cells = trimmed.split('|').map((c) => c.trim()).toList();
    if (expectedCols != null) {
      while (cells.length < expectedCols) {
        cells.add('');
      }
      if (cells.length > expectedCols) {
        return cells.sublist(0, expectedCols);
      }
    }
    return cells;
  }
}

/// Visualizador rico unificado estilo Notion com blocos interativos (toggles, callouts,
/// tabelas, checklists clicáveis), imagens inline, links internos `app://ref/...` e
/// sublinhado colorido JW Library em texto corrido.
class RichBlockMarkdownView extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final bool isDark;
  final bool allowHighlights;
  final ValueChanged<String>? onLinkTap;
  final Future<void> Function(String updatedMarkdown)? onContentUpdated;

  const RichBlockMarkdownView({
    super.key,
    required this.text,
    this.style,
    required this.isDark,
    this.allowHighlights = false,
    this.onLinkTap,
    this.onContentUpdated,
  });

  @override
  State<RichBlockMarkdownView> createState() => _RichBlockMarkdownViewState();
}

class _RichBlockMarkdownViewState extends State<RichBlockMarkdownView> {
  late String _liveText;

  @override
  void initState() {
    super.initState();
    _liveText = widget.text;
  }

  @override
  void didUpdateWidget(covariant RichBlockMarkdownView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _liveText = widget.text;
    }
  }

  Future<void> _handleChecklistToggle(int lineIdx) async {
    final updated = SecondBrainBlockParser.toggleChecklistLine(
      _liveText,
      lineIdx,
    );
    if (updated == _liveText) return;
    setState(() => _liveText = updated);
    await widget.onContentUpdated?.call(updated);
  }

  Future<void> _handleTextChunkUpdate(String oldChunk, String newChunk) async {
    final updated = _liveText.replaceFirst(oldChunk, newChunk);
    if (updated == _liveText) return;
    setState(() => _liveText = updated);
    await widget.onContentUpdated?.call(updated);
  }

  @override
  Widget build(BuildContext context) {
    final blocks = SecondBrainBlockParser.parse(_liveText);
    if (blocks.isEmpty) {
      return Text('Sem conteúdo.', style: widget.style);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var idx = 0; idx < blocks.length; idx++) ...[
          _buildBlock(context, blocks[idx]),
          if (idx < blocks.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildBlock(BuildContext context, SecondBrainBlock block) {
    switch (block) {
      case ToggleSecondBrainBlock(:final summary, :final bodyMarkdown):
        return Material(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.04)
              : const Color(0xFFF8FAFC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 2,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 14, 14),
              leading: Icon(
                Icons.arrow_right_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                summary,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  color: widget.isDark
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFF0F172A),
                ),
              ),
              children: [
                if (bodyMarkdown.isNotEmpty)
                  RichBlockMarkdownView(
                    text: bodyMarkdown,
                    style: widget.style,
                    isDark: widget.isDark,
                    allowHighlights: false,
                    onLinkTap: widget.onLinkTap,
                  ),
              ],
            ),
          ),
        );

      case CalloutSecondBrainBlock(:final kind, :final bodyMarkdown):
        final styleInfo = _calloutTheme(kind);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: styleInfo.color.withValues(
                alpha: widget.isDark ? 0.14 : 0.09,
              ),
              border: Border(
                left: BorderSide(color: styleInfo.color, width: 4),
                top: BorderSide(color: styleInfo.color.withValues(alpha: 0.25)),
                right: BorderSide(
                  color: styleInfo.color.withValues(alpha: 0.25),
                ),
                bottom: BorderSide(
                  color: styleInfo.color.withValues(alpha: 0.25),
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(styleInfo.icon, color: styleInfo.color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        styleInfo.label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: styleInfo.color,
                        ),
                      ),
                      if (bodyMarkdown.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        MarkdownPreviewText(
                          text: bodyMarkdown,
                          overflow: TextOverflow.clip,
                          selectable: true,
                          onLinkTap: widget.onLinkTap,
                          style: widget.style,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

      case TableSecondBrainBlock(:final headers, :final rows):
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : const Color(0xFFCBD5E1),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder.symmetric(
                inside: BorderSide(
                  color: widget.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : const Color(0xFFF1F5F9),
                  ),
                  children: headers
                      .map(
                        (h) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Text(
                            h,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: widget.isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                for (var rIdx = 0; rIdx < rows.length; rIdx++)
                  TableRow(
                    decoration: BoxDecoration(
                      color: rIdx.isOdd
                          ? (widget.isDark
                                ? Colors.white.withValues(alpha: 0.025)
                                : const Color(0xFFFAFAFC))
                          : Colors.transparent,
                    ),
                    children: rows[rIdx]
                        .map(
                          (cell) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 280),
                              child: MarkdownPreviewText(
                                text: cell,
                                maxLines: 20,
                                overflow: TextOverflow.clip,
                                onLinkTap: widget.onLinkTap,
                                style: widget.style?.copyWith(fontSize: 13),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        );

      case ChecklistSecondBrainBlock(
        :final sourceLineIndex,
        :final checked,
        :final text,
      ):
        final canToggle = widget.onContentUpdated != null;
        return Semantics(
          toggled: checked,
          label: text,
          child: InkWell(
            onTap: canToggle
                ? () => _handleChecklistToggle(sourceLineIndex)
                : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      checked
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 20,
                      color: checked
                          ? const Color(0xFF10B981)
                          : (widget.isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MarkdownPreviewText(
                      text: text,
                      maxLines: 30,
                      overflow: TextOverflow.clip,
                      onLinkTap: widget.onLinkTap,
                      style: (widget.style ?? const TextStyle(fontSize: 14.5))
                          .copyWith(
                            decoration: checked
                                ? TextDecoration.lineThrough
                                : null,
                            color: checked
                                ? (widget.isDark
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF94A3B8))
                                : widget.style?.color,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

      case RichTextSecondBrainBlock(:final markdown):
        return _RichTextWithImagesSegment(
          markdown: markdown,
          style: widget.style,
          allowHighlights: widget.allowHighlights,
          onLinkTap: widget.onLinkTap,
          onChunkUpdated: widget.onContentUpdated != null
              ? (updated) => _handleTextChunkUpdate(markdown, updated)
              : null,
        );
    }
  }

  static ({String label, Color color, IconData icon}) _calloutTheme(
    String kind,
  ) {
    switch (kind.toUpperCase()) {
      case 'TIP':
        return (
          label: 'DICA',
          color: const Color(0xFF10B981),
          icon: Icons.lightbulb_outline_rounded,
        );
      case 'IMPORTANT':
        return (
          label: 'IMPORTANTE',
          color: const Color(0xFF8B5CF6),
          icon: Icons.bolt_rounded,
        );
      case 'WARNING':
        return (
          label: 'ATENÇÃO',
          color: const Color(0xFFF59E0B),
          icon: Icons.warning_amber_rounded,
        );
      case 'NOTE':
      default:
        return (
          label: 'NOTA',
          color: const Color(0xFF3B82F6),
          icon: Icons.info_outline_rounded,
        );
    }
  }
}

class _RichTextWithImagesSegment extends StatefulWidget {
  final String markdown;
  final TextStyle? style;
  final bool allowHighlights;
  final ValueChanged<String>? onLinkTap;
  final Future<void> Function(String updatedMarkdown)? onChunkUpdated;

  const _RichTextWithImagesSegment({
    required this.markdown,
    this.style,
    this.allowHighlights = false,
    this.onLinkTap,
    this.onChunkUpdated,
  });

  @override
  State<_RichTextWithImagesSegment> createState() =>
      _RichTextWithImagesSegmentState();
}

class _RichTextWithImagesSegmentState
    extends State<_RichTextWithImagesSegment> {
  final List<GestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final mediaRegex = RegExp(
      r'!\[([^\]]*)\]\(([^\)]+)\)|(?:<u\b[^>]*>)?\[([^\]]*)\]\((app://ref/picture/[^)\s]+)\)(?:</u>)?',
      multiLine: true,
      caseSensitive: false,
    );
    final matches = mediaRegex.allMatches(widget.markdown).toList();
    if (matches.isEmpty) {
      return MarkdownPreviewText(
        text: widget.markdown,
        overflow: TextOverflow.clip,
        selectable: true,
        allowHighlights: widget.allowHighlights,
        onContentUpdated: widget.onChunkUpdated,
        onLinkTap: widget.onLinkTap,
        style: widget.style,
      );
    }

    final children = <Widget>[];
    var cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        final slice = widget.markdown.substring(cursor, m.start).trim();
        if (slice.isNotEmpty) {
          children.add(
            MarkdownPreviewText(
              text: slice,
              overflow: TextOverflow.clip,
              selectable: true,
              allowHighlights: widget.allowHighlights,
              onContentUpdated: (updatedSlice) async {
                final full = widget.markdown.replaceRange(
                  cursor,
                  m.start,
                  updatedSlice,
                );
                await widget.onChunkUpdated?.call(full);
              },
              onLinkTap: widget.onLinkTap,
              style: widget.style,
            ),
          );
        }
      }
      final alt = HighlightTextHelper.stripHighlightTags(
        m.group(1) ?? m.group(3) ?? '',
      ).trim();
      final src = (m.group(2) ?? m.group(4) ?? '').trim();
      if (src.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: InkWell(
              onTap: src.startsWith('app://ref/')
                  ? () => AppReferenceViewer.openUrl(context, src)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AppInlineImageView(
                      src: src,
                      alt: alt.isEmpty ? 'Imagem' : alt,
                    ),
                  ),
                  if (alt.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        alt,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }
      cursor = m.end;
    }

    if (cursor < widget.markdown.length) {
      final tail = widget.markdown.substring(cursor).trim();
      if (tail.isNotEmpty) {
        children.add(
          MarkdownPreviewText(
            text: tail,
            overflow: TextOverflow.clip,
            selectable: true,
            allowHighlights: widget.allowHighlights,
            onContentUpdated: (updatedTail) async {
              final full = widget.markdown.replaceRange(
                cursor,
                widget.markdown.length,
                updatedTail,
              );
              await widget.onChunkUpdated?.call(full);
            },
            onLinkTap: widget.onLinkTap,
            style: widget.style,
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
