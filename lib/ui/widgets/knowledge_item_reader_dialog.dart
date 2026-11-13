import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import 'universal_attachment_viewer.dart';

/// Abre a janela dedicada para leitura completa e imersiva de qualquer item da Base de Conhecimento.
Future<void> showKnowledgeItemReader(
  BuildContext context, {
  required String title,
  required String content,
  required String category,
  required String itemType, // 'Nota', 'Dúvida', 'Documento', 'Recurso'
  DateTime? updatedAt,
  List<String> tags = const [],
  List<Map<String, dynamic>> attachments = const [],
  String? url,
  String? subtitle,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
  VoidCallback? onExport,
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
    ),
  );
}

/// Diálogo imersivo com leitor rico em Markdown, imagens inline, links de publicações/vídeos e tags.
class KnowledgeItemReaderDialog extends StatelessWidget {
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
  });

  IconData _getTypeIcon() {
    switch (itemType.toLowerCase()) {
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
      default:
        return Icons.menu_book_rounded;
    }
  }

  Color _getTypeColor() {
    switch (itemType.toLowerCase()) {
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
      default:
        return AppTheme.primaryBlue;
    }
  }

  Future<void> _launchUrlStr(BuildContext context, String urlStr) async {
    try {
      final uri = Uri.parse(urlStr);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não foi possível abrir o link: $urlStr')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir link: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeColor = _getTypeColor();

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
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
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
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  itemType.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: typeColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                              if (updatedAt != null) ...[
                                const Spacer(),
                                Text(
                                  'Atualizado em ${updatedAt!.day.toString().padLeft(2, '0')}/${updatedAt!.month.toString().padLeft(2, '0')}/${updatedAt!.year}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.25,
                            ),
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
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

              // Barra de Tags e Ações Rápidas
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isDark ? const Color(0xFF131D31) : const Color(0xFFF1F5F9),
                child: Row(
                  children: [
                    Expanded(
                      child: tags.isNotEmpty
                          ? SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: tags.map((t) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Chip(
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      avatar: const Icon(Icons.tag, size: 12, color: AppTheme.primaryBlue),
                                      label: Text(
                                        t,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
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
                                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                              ),
                            ),
                    ),
                    if (url != null && url!.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 18, color: Colors.teal),
                        tooltip: 'Abrir link original',
                        onPressed: () => _launchUrlStr(context, url!),
                      ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'Copiar conteúdo',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: '$title\n\n$content'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Conteúdo copiado para a área de transferência!')),
                        );
                      },
                    ),
                    if (onExport != null)
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 18),
                        tooltip: 'Exportar',
                        onPressed: onExport,
                      ),
                    if (onEdit != null)
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryBlue),
                        tooltip: 'Editar',
                        onPressed: () {
                          Navigator.of(context).pop();
                          onEdit!();
                        },
                      ),
                    if (onDelete != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                        tooltip: 'Excluir',
                        onPressed: () {
                          Navigator.of(context).pop();
                          onDelete!();
                        },
                      ),
                  ],
                ),
              ),

              // Conteúdo Formatado em Markdown com Imagens e Links Inline
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildRichMarkdownBody(context, content, isDark),
                      if (attachments.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Divider(),
                        const Text(
                          'Anexos & Documentos:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: attachments.map((att) {
                            final name = att['name']?.toString() ?? 'anexo';
                            final path = att['path']?.toString() ?? att['filePath']?.toString() ?? '';
                            final type = att['type']?.toString() ?? 'file';

                            return ActionChip(
                              avatar: const Icon(Icons.attachment, size: 16, color: AppTheme.primaryBlue),
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

  Widget _buildRichMarkdownBody(BuildContext context, String rawText, bool isDark) {
    if (rawText.trim().isEmpty) {
      return Text(
        'Nenhum conteúdo adicional registrado.',
        style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontStyle: FontStyle.italic),
      );
    }

    final lines = rawText.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 10));
        continue;
      }

      // Imagem Markdown inline: ![legenda](caminho_ou_url)
      final imgMatch = RegExp(r'^!\[(.*?)\]\((.*?)\)$').firstMatch(trimmed);
      if (imgMatch != null) {
        final alt = imgMatch.group(1) ?? 'Imagem';
        final src = imgMatch.group(2) ?? '';
        widgets.add(_buildInlineImage(context, src, alt, isDark));
        widgets.add(const SizedBox(height: 12));
        continue;
      }

      // Título Grande: ### Título ou ## ou #
      if (trimmed.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(
            trimmed.substring(4),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
          ),
        ));
        continue;
      }
      if (trimmed.startsWith('#### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            trimmed.substring(5),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ));
        continue;
      }
      if (trimmed.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            trimmed.substring(2),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
          ),
        ));
        continue;
      }

      // Citação: > citação
      if (trimmed.startsWith('> ')) {
        widgets.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            border: const Border(
              left: BorderSide(color: AppTheme.primaryBlue, width: 4),
            ),
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
          ),
          child: Text(
            trimmed.substring(2),
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            ),
          ),
        ));
        continue;
      }

      // Item de Lista com Marcador: - ou *
      if (trimmed.startsWith('- [ ] ') || trimmed.startsWith('- [x] ')) {
        final isChecked = trimmed.startsWith('- [x] ');
        final itemText = trimmed.substring(6);
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                size: 18,
                color: isChecked ? AppTheme.primaryBlue : Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  itemText,
                  style: TextStyle(
                    fontSize: 14,
                    decoration: isChecked ? TextDecoration.lineThrough : null,
                    color: isChecked ? Colors.grey : null,
                  ),
                ),
              ),
            ],
          ),
        ));
        continue;
      }

      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryBlue)),
              Expanded(
                child: _buildFormattedSpans(context, trimmed.substring(2), isDark),
              ),
            ],
          ),
        ));
        continue;
      }

      // Linha normal com formatação inline
      widgets.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: _buildFormattedSpans(context, line, isDark),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }

  Widget _buildInlineImage(BuildContext context, String src, String alt, bool isDark) {
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
              onTap: () => showUniversalAttachmentViewer(context, filePath: src, title: alt),
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
                                const Icon(Icons.image, color: Colors.grey, size: 28),
                                const SizedBox(width: 8),
                                Text(alt, style: const TextStyle(color: Colors.grey)),
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
                  const Icon(Icons.photo_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      alt,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Text('Toque para expandir', style: TextStyle(fontSize: 11, color: AppTheme.primaryBlue)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormattedSpans(BuildContext context, String text, bool isDark) {
    final baseStyle = TextStyle(
      fontSize: 14,
      height: 1.5,
      color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
    );

    // Detecta links em Markdown: [Título](url)
    final linkRegex = RegExp(r'\[(.*?)\]\((.*?)\)');
    final matches = linkRegex.allMatches(text).toList();

    if (matches.isEmpty) {
      return RichText(
        text: TextSpan(children: _parseInlineFormatting(text, baseStyle, isDark)),
      );
    }

    final children = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        children.addAll(_parseInlineFormatting(
          text.substring(lastEnd, match.start),
          baseStyle,
          isDark,
        ));
      }

      final label = match.group(1) ?? 'Link';
      final linkUrl = match.group(2) ?? '';
      final isJwPublication = label.contains('📖');
      final isJwVideo = label.contains('🎥');

      children.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: InkWell(
          onTap: () => _launchUrlStr(context, linkUrl),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: isJwPublication
                  ? const Color(0xFF4338CA).withValues(alpha: 0.12)
                  : isJwVideo
                      ? const Color(0xFFDC2626).withValues(alpha: 0.12)
                      : AppTheme.primaryBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isJwPublication
                    ? const Color(0xFF4338CA)
                    : isJwVideo
                        ? const Color(0xFFDC2626)
                        : AppTheme.primaryBlue,
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isJwPublication
                        ? const Color(0xFF4338CA)
                        : isJwVideo
                            ? const Color(0xFFDC2626)
                            : AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.open_in_new, size: 12, color: AppTheme.primaryBlue),
              ],
            ),
          ),
        ),
      ));

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      children.addAll(_parseInlineFormatting(
        text.substring(lastEnd),
        baseStyle,
        isDark,
      ));
    }

    return RichText(
      text: TextSpan(children: children),
    );
  }

  List<InlineSpan> _parseInlineFormatting(String text, TextStyle baseStyle, bool isDark) {
    final spans = <InlineSpan>[];
    final tokenRegex = RegExp(
      r'(?:<mark style="background:(#[a-fA-F0-9]{6})">([\s\S]*?)</mark>)|(?:\*\*(.+?)\*\*)|(?:\*([^\*]+)\*)|(?:`([^`]+)`)',
    );
    final matches = tokenRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      spans.add(TextSpan(text: text, style: baseStyle));
      return spans;
    }

    int lastEnd = 0;
    for (final m in matches) {
      if (m.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, m.start), style: baseStyle));
      }

      if (m.group(1) != null && m.group(2) != null) {
        // Highlight mark: <mark style="background:#hex">text</mark>
        final hexStr = m.group(1)!;
        final markText = m.group(2)!;
        final parsedColor = int.tryParse(hexStr.replaceFirst('#', '0xFF'));
        final Color markColor = parsedColor != null ? Color(parsedColor) : Colors.amber;
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: markColor.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              markText,
              style: baseStyle.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ));
      } else if (m.group(3) != null) {
        // Bold: **text**
        spans.add(TextSpan(
          text: m.group(3)!,
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      } else if (m.group(4) != null) {
        // Italic: *text*
        spans.add(TextSpan(
          text: m.group(4)!,
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (m.group(5) != null) {
        // Code: `text`
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              m.group(5)!,
              style: baseStyle.copyWith(
                fontFamily: 'monospace',
                fontSize: (baseStyle.fontSize ?? 14) * 0.9,
              ),
            ),
          ),
        ));
      }

      lastEnd = m.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }

    return spans;
  }
}
