import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../references/app_reference.dart';
import 'app_reference_viewer.dart';
import 'highlight_text_helper.dart';
import 'universal_attachment_viewer.dart';

/// Abre a janela dedicada para leitura completa e imersiva de itens do aplicativo,
/// com suporte a links/referências cruzadas e sublinhado colorido estilo JW Library.
Future<void> showKnowledgeItemReader(
  BuildContext context, {
  required String title,
  required String content,
  required String category,
  required String itemType, // 'Nota', 'Dúvida', 'Documento', 'Recurso', ...
  DateTime? updatedAt,
  List<String> tags = const [],
  List<Map<String, dynamic>> attachments = const [],
  String? url,
  String? subtitle,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
  VoidCallback? onExport,
  bool allowHighlights = false,
  Future<void> Function(String updatedContent)? onContentUpdated,
  VoidCallback? onJumpToTab,
  String jumpToTabLabel = 'Ir para a aba',
}) async {
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => KnowledgeItemReaderDialog(
      title: title,
      content: content,
      category: category,
      itemType: itemType,
      updatedAt: updatedAt,
      tags: tags,
      attachments: attachments,
      url: url,
      subtitle: subtitle,
      onEdit: onEdit,
      onDelete: onDelete,
      onExport: onExport,
      allowHighlights: allowHighlights,
      onContentUpdated: onContentUpdated,
      onJumpToTab: onJumpToTab,
      jumpToTabLabel: jumpToTabLabel,
    ),
  );
}

class _ContentSegment {
  final bool isImage;
  final int rawStart;
  final int rawEnd;
  final String text;
  final String? imageAlt;
  final String? imageSrc;

  const _ContentSegment.text({
    required this.rawStart,
    required this.rawEnd,
    required this.text,
  }) : isImage = false,
       imageAlt = null,
       imageSrc = null;

  const _ContentSegment.image({
    required this.rawStart,
    required this.rawEnd,
    required this.imageAlt,
    required this.imageSrc,
  }) : isImage = true,
       text = '';
}

/// Diálogo imersivo com leitor rico em Markdown, imagens inline, referências cruzadas,
/// textos bíblicos TNM e sublinhado direto em seleção no estilo JW Library.
class KnowledgeItemReaderDialog extends StatefulWidget {
  final String title;
  final String content;
  final String category;
  final String itemType;
  final DateTime? updatedAt;
  final List<String> tags;
  final List<Map<String, dynamic>> attachments;
  final String? url;
  final String? subtitle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onExport;
  final bool allowHighlights;
  final Future<void> Function(String updatedContent)? onContentUpdated;
  final VoidCallback? onJumpToTab;
  final String jumpToTabLabel;

  const KnowledgeItemReaderDialog({
    super.key,
    required this.title,
    required this.content,
    required this.category,
    required this.itemType,
    this.updatedAt,
    this.tags = const [],
    this.attachments = const [],
    this.url,
    this.subtitle,
    this.onEdit,
    this.onDelete,
    this.onExport,
    this.allowHighlights = false,
    this.onContentUpdated,
    this.onJumpToTab,
    this.jumpToTabLabel = 'Ir para a aba',
  });

  @override
  State<KnowledgeItemReaderDialog> createState() =>
      _KnowledgeItemReaderDialogState();
}

class _KnowledgeItemReaderDialogState extends State<KnowledgeItemReaderDialog> {
  late String _content;
  final List<GestureRecognizer> _recognizers = [];

  // Rastreia seleção ativa em algum segmento de texto para aplicar cor em 1 toque pela barra JW.
  MappedRichTextResult? _activeSegMap;
  int _activeSegRawStart = 0;
  int _activeSegRawEnd = 0;
  TextSelection? _activeSelection;

  @override
  void initState() {
    super.initState();
    _content = widget.content;
  }

  @override
  void didUpdateWidget(covariant KnowledgeItemReaderDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _content = widget.content;
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

  bool get _canInteractiveHighlight =>
      widget.allowHighlights && widget.onContentUpdated != null;

  IconData _getTypeIcon() {
    switch (widget.itemType.toLowerCase()) {
      case 'nota':
        return Icons.note_outlined;
      case 'dúvida':
      case 'duvida':
      case 'pergunta':
        return Icons.help_outline_rounded;
      case 'documento':
        return Icons.description_outlined;
      case 'recurso':
        return Icons.link_rounded;
      case 'tarefa':
        return Icons.task_alt_outlined;
      case 'projeto':
        return Icons.folder_special_outlined;
      case 'captura':
        return Icons.inbox_outlined;
      case 'pesquisa':
        return Icons.auto_stories_outlined;
      case 'experiência':
      case 'experiencia':
        return Icons.auto_awesome_outlined;
      default:
        return Icons.menu_book_rounded;
    }
  }

  Color _getTypeColor() {
    switch (widget.itemType.toLowerCase()) {
      case 'nota':
        return const Color(0xFF8B5CF6);
      case 'dúvida':
      case 'duvida':
      case 'pergunta':
        return const Color(0xFFF59E0B);
      case 'documento':
        return AppTheme.primaryBlue;
      case 'recurso':
        return Colors.teal;
      case 'tarefa':
      case 'projeto':
        return const Color(0xFF10B981);
      default:
        return AppTheme.primaryBlue;
    }
  }

  Future<void> _openUrlOrReference(BuildContext context, String urlStr) async {
    if (AppReferenceHelper.isAppReferenceUrl(urlStr)) {
      await AppReferenceViewer.openUrl(context, urlStr);
      return;
    }
    try {
      final uri = Uri.parse(urlStr);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível abrir o link: $urlStr')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao abrir link: $e')));
      }
    }
  }

  List<_ContentSegment> _splitSegments(String rawText) {
    final imageRegex = RegExp(
      r'^!\[([^\]]*)\]\(([^\)]+)\)\s*$',
      multiLine: true,
    );
    final matches = imageRegex.allMatches(rawText).toList();
    if (matches.isEmpty) {
      return [
        _ContentSegment.text(
          rawStart: 0,
          rawEnd: rawText.length,
          text: rawText,
        ),
      ];
    }

    final segments = <_ContentSegment>[];
    var cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        final slice = rawText.substring(cursor, m.start);
        if (slice.trim().isNotEmpty) {
          segments.add(
            _ContentSegment.text(
              rawStart: cursor,
              rawEnd: m.start,
              text: slice,
            ),
          );
        }
      }
      segments.add(
        _ContentSegment.image(
          rawStart: m.start,
          rawEnd: m.end,
          imageAlt: m.group(1) ?? 'Imagem',
          imageSrc: m.group(2) ?? '',
        ),
      );
      cursor = m.end;
      while (cursor < rawText.length &&
          (rawText[cursor] == '\n' || rawText[cursor] == '\r')) {
        cursor++;
      }
    }
    if (cursor < rawText.length) {
      final tail = rawText.substring(cursor);
      if (tail.trim().isNotEmpty) {
        segments.add(
          _ContentSegment.text(
            rawStart: cursor,
            rawEnd: rawText.length,
            text: tail,
          ),
        );
      }
    }
    return segments;
  }

  Future<void> _applyColorToSelection({
    required _ContentSegment segment,
    required MappedRichTextResult mapped,
    required int selStart,
    required int selEnd,
    required String? colorHex,
  }) async {
    final updatedSegText = HighlightTextHelper.applyUnderlineWithMap(
      rawText: segment.text,
      map: mapped,
      selectionStart: selStart,
      selectionEnd: selEnd,
      colorHex: colorHex,
    );
    if (updatedSegText == segment.text) return;

    final updatedFull = _content.replaceRange(
      segment.rawStart,
      segment.rawEnd,
      updatedSegText,
    );

    setState(() {
      _content = updatedFull;
      _activeSelection = null;
      _activeSegMap = null;
    });

    if (widget.onContentUpdated != null) {
      await widget.onContentUpdated!(updatedFull);
    }
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeColor = _getTypeColor();
    final hasActiveSelection =
        _canInteractiveHighlight &&
        _activeSelection != null &&
        _activeSelection!.isValid &&
        !_activeSelection!.isCollapsed &&
        _activeSegMap != null;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 780,
          height: 680,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra Superior / Cabeçalho
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF8FAFC),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_getTypeIcon(), color: typeColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.itemType.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: typeColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white10
                                        : Colors.black.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    widget.category,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? const Color(0xFFCBD5E1)
                                          : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ),
                              if (widget.updatedAt != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '${widget.updatedAt!.day.toString().padLeft(2, '0')}/${widget.updatedAt!.month.toString().padLeft(2, '0')}/${widget.updatedAt!.year}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.25,
                            ),
                          ),
                          if (widget.subtitle != null &&
                              widget.subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle!,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.onJumpToTab != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: TextButton.icon(
                          key: const Key('btn_reader_jump_to_tab'),
                          icon: const Icon(Icons.open_in_browser, size: 17),
                          label: Text(
                            widget.jumpToTabLabel,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onJumpToTab!();
                          },
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Fechar Leitor',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Barra de Sublinhado JW Library (quando habilitado no módulo)
              if (_canInteractiveHighlight)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F1A2E)
                        : const Color(0xFFF8FAFC),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.border_color_outlined,
                            size: 14,
                            color: hasActiveSelection
                                ? AppTheme.primaryBlue
                                : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hasActiveSelection
                                ? 'Sublinhar seleção:'
                                : 'Selecione um trecho abaixo para sublinhar:',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: hasActiveSelection
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isDark
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final c in HighlightTextHelper.colors)
                            Tooltip(
                              message: 'Sublinhar (${c.label})',
                              child: InkWell(
                                key: Key('btn_reader_hl_${c.id}'),
                                borderRadius: BorderRadius.circular(14),
                                onTap: hasActiveSelection
                                    ? () => _applyColorToSelection(
                                        segment: _ContentSegment.text(
                                          rawStart: _activeSegRawStart,
                                          rawEnd: _activeSegRawEnd,
                                          text: _content.substring(
                                            _activeSegRawStart,
                                            _activeSegRawEnd,
                                          ),
                                        ),
                                        mapped: _activeSegMap!,
                                        selStart: _activeSelection!.start,
                                        selEnd: _activeSelection!.end,
                                        colorHex: c.hex,
                                      )
                                    : () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Selecione primeiro um trecho do texto para sublinhar.',
                                                ),
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                      },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 4,
                                  ),
                                  child: CircleAvatar(
                                    radius: 9,
                                    backgroundColor: c.color.withValues(
                                      alpha: hasActiveSelection ? 1.0 : 0.45,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Tooltip(
                            message: 'Remover sublinhado da seleção',
                            child: IconButton(
                              key: const Key('btn_reader_hl_clear'),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              icon: Icon(
                                Icons.format_clear,
                                size: 17,
                                color: hasActiveSelection
                                    ? Colors.redAccent
                                    : Colors.grey,
                              ),
                              onPressed: hasActiveSelection
                                  ? () => _applyColorToSelection(
                                      segment: _ContentSegment.text(
                                        rawStart: _activeSegRawStart,
                                        rawEnd: _activeSegRawEnd,
                                        text: _content.substring(
                                          _activeSegRawStart,
                                          _activeSegRawEnd,
                                        ),
                                      ),
                                      mapped: _activeSegMap!,
                                      selStart: _activeSelection!.start,
                                      selEnd: _activeSelection!.end,
                                      colorHex: null,
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // Barra de Tags e Ações Rápidas
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: isDark
                    ? const Color(0xFF131D31)
                    : const Color(0xFFF1F5F9),
                child: Row(
                  children: [
                    Expanded(
                      child: widget.tags.isNotEmpty
                          ? SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: widget.tags.map((t) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Chip(
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      avatar: const Icon(
                                        Icons.tag,
                                        size: 12,
                                        color: AppTheme.primaryBlue,
                                      ),
                                      label: Text(
                                        t,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      backgroundColor: AppTheme.primaryBlue
                                          .withValues(alpha: 0.1),
                                      side: BorderSide.none,
                                    ),
                                  );
                                }).toList(),
                              ),
                            )
                          : Text(
                              'Sem tags vinculadas',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                    ),
                    if (widget.url != null && widget.url!.isNotEmpty)
                      IconButton(
                        icon: const Icon(
                          Icons.open_in_new,
                          size: 18,
                          color: Colors.teal,
                        ),
                        tooltip: 'Abrir link original',
                        onPressed: () =>
                            _openUrlOrReference(context, widget.url!),
                      ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'Copiar conteúdo',
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: '${widget.title}\n\n$_content'),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Conteúdo copiado para a área de transferência!',
                            ),
                          ),
                        );
                      },
                    ),
                    if (widget.onExport != null)
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 18),
                        tooltip: 'Exportar',
                        onPressed: widget.onExport,
                      ),
                    if (widget.onEdit != null)
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: AppTheme.primaryBlue,
                        ),
                        tooltip: 'Editar',
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onEdit!();
                        },
                      ),
                    if (widget.onDelete != null)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                        tooltip: 'Excluir',
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onDelete!();
                        },
                      ),
                  ],
                ),
              ),

              // Conteúdo Formatado em Markdown com Referências Clicáveis e Sublinhado Direto
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildRichMarkdownBody(context, _content, isDark),
                      if (widget.attachments.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Divider(),
                        const Text(
                          'Anexos & Documentos:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.attachments.map((att) {
                            final name = att['name']?.toString() ?? 'anexo';
                            final path =
                                att['path']?.toString() ??
                                att['filePath']?.toString() ??
                                '';
                            final type = att['type']?.toString() ?? 'file';

                            return ActionChip(
                              avatar: const Icon(
                                Icons.attachment,
                                size: 16,
                                color: AppTheme.primaryBlue,
                              ),
                              label: Text(name),
                              onPressed: () {
                                if (path.isNotEmpty) {
                                  showUniversalAttachmentViewer(
                                    context,
                                    filePath: path,
                                    title: name,
                                    fileType: type,
                                  );
                                }
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRichMarkdownBody(
    BuildContext context,
    String rawText,
    bool isDark,
  ) {
    if (rawText.trim().isEmpty) {
      return Text(
        'Nenhum conteúdo adicional registrado.',
        style: TextStyle(
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final baseStyle = TextStyle(
      fontSize: 14.5,
      height: 1.55,
      color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
    );

    final segments = _splitSegments(rawText);
    final widgets = <Widget>[];

    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      if (seg.isImage) {
        widgets.add(
          _buildInlineImage(
            context,
            seg.imageSrc ?? '',
            seg.imageAlt ?? 'Imagem',
            isDark,
          ),
        );
        widgets.add(const SizedBox(height: 12));
        continue;
      }

      final mapped = HighlightTextHelper.buildMappedSpans(
        seg.text,
        baseStyle,
        onLinkTap: (url) => _openUrlOrReference(context, url),
        disposables: _recognizers,
      );
      if (mapped.spans.isEmpty) continue;

      widgets.add(
        SelectableText.rich(
          TextSpan(children: mapped.spans),
          onSelectionChanged: _canInteractiveHighlight
              ? (sel, cause) {
                  setState(() {
                    _activeSegMap = mapped;
                    _activeSegRawStart = seg.rawStart;
                    _activeSegRawEnd = seg.rawEnd;
                    _activeSelection = sel;
                  });
                }
              : null,
          contextMenuBuilder: (ctx, editableTextState) {
            final sel = editableTextState.textEditingValue.selection;
            final canHighlight =
                _canInteractiveHighlight && sel.isValid && !sel.isCollapsed;
            final items = <ContextMenuButtonItem>[
              ...editableTextState.contextMenuButtonItems,
              if (canHighlight) ...[
                for (final c in HighlightTextHelper.colors)
                  ContextMenuButtonItem(
                    label: 'Sublinhar (${c.label})',
                    onPressed: () {
                      ContextMenuController.removeAny();
                      _applyColorToSelection(
                        segment: seg,
                        mapped: mapped,
                        selStart: sel.start,
                        selEnd: sel.end,
                        colorHex: c.hex,
                      );
                    },
                  ),
                ContextMenuButtonItem(
                  label: 'Remover Sublinhado',
                  onPressed: () {
                    ContextMenuController.removeAny();
                    _applyColorToSelection(
                      segment: seg,
                      mapped: mapped,
                      selStart: sel.start,
                      selEnd: sel.end,
                      colorHex: null,
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
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }

  Widget _buildInlineImage(
    BuildContext context,
    String src,
    String alt,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: InkWell(
              onTap: () => showUniversalAttachmentViewer(
                context,
                filePath: src,
                title: alt,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: src.startsWith('http')
                    ? Image.network(src, fit: BoxFit.cover)
                    : !kIsWeb && File(src).existsSync()
                    ? Image.file(File(src), fit: BoxFit.cover)
                    : Container(
                        height: 120,
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.image,
                              color: Colors.grey,
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              alt,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          if (alt.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.photo_outlined,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      alt,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Text(
                    'Toque para expandir',
                    style: TextStyle(fontSize: 11, color: AppTheme.primaryBlue),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
