import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../database/app_database.dart';
import '../../../knowledge/knowledge_backlink_indexer.dart';
import '../../../knowledge/note_cover_config.dart';
import '../../../references/app_reference.dart';
import '../markdown_preview_text.dart';
import 'note_cover_picker_dialog.dart';
import 'rich_block_markdown_view.dart';

/// Identidade visual (cor + ícone + rótulo amigável) para itens da Base de Conhecimento.
class KnowledgeBadgeStyle {
  final Color accent;
  final IconData icon;
  final String label;

  const KnowledgeBadgeStyle({
    required this.accent,
    required this.icon,
    required this.label,
  });
}

/// Link extraído de um texto Markdown (`[label](url)`) para exibição interativa em chips.
class KnowledgeExtractedLink {
  final String label;
  final String url;
  final bool isBible;
  final bool isInternal;

  const KnowledgeExtractedLink({
    required this.label,
    required this.url,
    required this.isBible,
    required this.isInternal,
  });
}

/// Resolve identidade visual de notas conforme categoria e tags.
KnowledgeBadgeStyle resolveNoteCategoryStyle(String rawCategory, String tags) {
  final c = rawCategory.trim().toLowerCase();
  if (tags.contains('research:') || c.contains('pesquisa')) {
    return const KnowledgeBadgeStyle(
      accent: Color(0xFF8B5CF6),
      icon: Icons.auto_stories_rounded,
      label: 'Pesquisa',
    );
  }
  switch (c) {
    case 'ministry':
    case 'pregação':
    case 'pregacao':
    case 'campo':
      return const KnowledgeBadgeStyle(
        accent: Color(0xFF10B981),
        icon: Icons.record_voice_over_outlined,
        label: 'Ministério',
      );
    case 'study':
    case 'estudo':
    case 'biblical':
      return const KnowledgeBadgeStyle(
        accent: Color(0xFF0EA5E9),
        icon: Icons.menu_book_rounded,
        label: 'Estudo',
      );
    case 'pastoral':
    case 'personal':
    case 'pessoal':
      return const KnowledgeBadgeStyle(
        accent: Color(0xFFF59E0B),
        icon: Icons.favorite_outline_rounded,
        label: 'Pastoral',
      );
    case 'general':
    case 'geral':
    case '':
      return const KnowledgeBadgeStyle(
        accent: Color(0xFF6366F1),
        icon: Icons.sticky_note_2_outlined,
        label: 'Geral',
      );
    default:
      return KnowledgeBadgeStyle(
        accent: AppTheme.primaryBlue,
        icon: Icons.sticky_note_2_outlined,
        label: rawCategory.trim(),
      );
  }
}

/// Resolve identidade visual de documentos locais por extensão e categoria.
KnowledgeBadgeStyle resolveDocumentVisualStyle(
  String fileType,
  String category,
) {
  switch (fileType.trim().toLowerCase()) {
    case 'pdf':
      return const KnowledgeBadgeStyle(
        accent: Color(0xFFEF4444),
        icon: Icons.picture_as_pdf_rounded,
        label: 'PDF',
      );
    case 'epub':
      return const KnowledgeBadgeStyle(
        accent: Color(0xFF8B5CF6),
        icon: Icons.auto_stories_rounded,
        label: 'EPUB',
      );
    case 'png':
    case 'jpg':
    case 'jpeg':
    case 'webp':
      return const KnowledgeBadgeStyle(
        accent: Color(0xFF14B8A6),
        icon: Icons.image_outlined,
        label: 'IMG',
      );
    default:
      return KnowledgeBadgeStyle(
        accent: AppTheme.primaryBlue,
        icon: Icons.description_rounded,
        label: fileType.trim().isEmpty ? 'DOC' : fileType.trim().toUpperCase(),
      );
  }
}

/// Resolve identidade visual de recursos externos.
KnowledgeBadgeStyle resolveResourceVisualStyle(String resourceType) {
  switch (resourceType.trim().toLowerCase()) {
    case 'video':
      return const KnowledgeBadgeStyle(
        accent: Color(0xFFF43F5E),
        icon: Icons.play_circle_filled_rounded,
        label: 'Vídeo',
      );
    case 'jw_pub':
      return const KnowledgeBadgeStyle(
        accent: Color(0xFF3B82F6),
        icon: Icons.menu_book_rounded,
        label: 'Publicação JW',
      );
    default:
      return const KnowledgeBadgeStyle(
        accent: Color(0xFF0D9488),
        icon: Icons.language_rounded,
        label: 'Link / Artigo',
      );
  }
}

/// Extrai links Markdown e referências `app://ref/...` preservando texto limpo no chip.
List<KnowledgeExtractedLink> extractMarkdownLinks(String raw) {
  if (raw.trim().isEmpty) return const [];
  final regex = RegExp(r'\[([^\]]+)\]\(([^)\s]+)\)');
  final seen = <String>{};
  final out = <KnowledgeExtractedLink>[];
  for (final m in regex.allMatches(raw)) {
    final rawLabel = m.group(1) ?? '';
    final url = (m.group(2) ?? '').trim();
    if (url.isEmpty) continue;
    final cleanLabel = rawLabel
        .replaceAll(
          RegExp(r'</?(?:u|mark)(?:\s+[^>]*)?>', caseSensitive: false),
          '',
        )
        .trim();
    if (cleanLabel.isEmpty) continue;
    final key = '$cleanLabel|$url';
    if (!seen.add(key)) continue;
    final isInternal = AppReferenceHelper.isAppReferenceUrl(url);
    out.add(
      KnowledgeExtractedLink(
        label: cleanLabel,
        url: url,
        isBible: url.contains('/bible/'),
        isInternal: isInternal,
      ),
    );
  }
  return out;
}

/// Cartão de nota com altura natural, faixa lateral por categoria e realce de seleção.
class KnowledgeNoteListCard extends StatelessWidget {
  final KnowledgeNoteEntry note;
  final List<String> tags;
  final String formattedDate;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;
  final Widget trailingMenu;

  const KnowledgeNoteListCard({
    super.key,
    required this.note,
    required this.tags,
    required this.formattedDate,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
    required this.trailingMenu,
  });

  @override
  Widget build(BuildContext context) {
    final style = resolveNoteCategoryStyle(note.category, note.tags);
    final accent = note.isPinned ? const Color(0xFFF59E0B) : style.accent;
    final surfaceBg = isDark
        ? (isSelected ? const Color(0xFF17223B) : const Color(0xFF131B2E))
        : (isSelected ? const Color(0xFFF0F6FF) : Colors.white);
    final borderColor = isSelected
        ? AppTheme.primaryColor(context)
        : (isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0));

    return Semantics(
      container: true,
      selected: isSelected,
      label: 'Nota ${note.title}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: surfaceBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isSelected ? 1.8 : 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor(context)
                        .withValues(alpha: isDark ? 0.22 : 0.14),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [accent, accent.withValues(alpha: 0.45)],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  note.isPinned
                                      ? Icons.push_pin_rounded
                                      : style.icon,
                                  size: 15,
                                  color: accent,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  note.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    letterSpacing: -0.15,
                                    color: isDark
                                        ? const Color(0xFFF8FAFC)
                                        : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              trailingMenu,
                            ],
                          ),
                          const SizedBox(height: 8),
                          MarkdownPreviewText(
                            text: SecondBrainBlockParser.toInlinePreviewMarkup(
                              note.content,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.2,
                              height: 1.45,
                              color: isDark
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    KnowledgePillBadge(
                                      label: style.label,
                                      color: style.accent,
                                      isDark: isDark,
                                    ),
                                    if (note.isPinned)
                                      KnowledgePillBadge(
                                        label: 'Fixada',
                                        color: const Color(0xFFF59E0B),
                                        isDark: isDark,
                                      ),
                                    if (tags.isNotEmpty)
                                      KnowledgePillBadge(
                                        label: '#${tags.first}',
                                        color: const Color(0xFF14B8A6),
                                        isDark: isDark,
                                      ),
                                    if (note.tags.contains('research:'))
                                      KnowledgePillBadge(
                                        icon: Icons.auto_stories,
                                        label: 'Pesquisa',
                                        color: const Color(0xFFA855F7),
                                        isDark: isDark,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    size: 12,
                                    color: isDark
                                        ? const Color(0xFF64748B)
                                        : const Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    formattedDate,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Folha editorial moderna exibida à direita quando uma nota é selecionada em telas amplas.
class KnowledgeNoteDetailPane extends StatelessWidget {
  final KnowledgeNoteEntry note;
  final List<String> tags;
  final String formattedDate;
  final bool isDark;
  final VoidCallback onEdit;
  final Future<void> Function() onExportPdf;
  final VoidCallback onShare;
  final VoidCallback onTogglePin;
  final VoidCallback onTransformResearch;
  final VoidCallback? onCustomizeCover;
  final Future<void> Function(String updatedContent) onContentUpdated;
  final ValueChanged<String> onOpenLink;
  final String? areaName;
  final String? areaColorHex;
  final List<KnowledgeNoteEntry> breadcrumbAncestors;
  final List<KnowledgeNoteEntry> subpages;
  final List<ResolvedBacklink> backlinks;
  final void Function(KnowledgeNoteEntry note)? onSelectNote;
  final VoidCallback? onCreateSubpage;
  final void Function(ResolvedBacklink link)? onOpenBacklink;
  final VoidCallback? onToggleSpacedReview;

  const KnowledgeNoteDetailPane({
    super.key,
    required this.note,
    required this.tags,
    required this.formattedDate,
    required this.isDark,
    required this.onEdit,
    required this.onExportPdf,
    required this.onShare,
    required this.onTogglePin,
    required this.onTransformResearch,
    this.onCustomizeCover,
    required this.onContentUpdated,
    required this.onOpenLink,
    this.areaName,
    this.areaColorHex,
    this.breadcrumbAncestors = const [],
    this.subpages = const [],
    this.backlinks = const [],
    this.onSelectNote,
    this.onCreateSubpage,
    this.onOpenBacklink,
    this.onToggleSpacedReview,
  });

  static Map<String, dynamic> _decodeProperties(String raw) {
    try {
      final d = jsonDecode(raw);
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (_) {}
    return const {};
  }

  static Color _parseHex(String? hex, Color fallback) {
    if (hex == null || hex.trim().isEmpty) return fallback;
    final clean = hex.trim().replaceFirst('#', '');
    final v = int.tryParse(clean.length == 6 ? 'FF$clean' : clean, radix: 16);
    return v != null ? Color(v) : fallback;
  }

  static String _statusLabel(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'em_estudo':
        return 'Em Estudo';
      case 'revisar':
        return 'Para Revisar';
      case 'concluido':
      case 'concluído':
        return 'Concluído';
      case 'rascunho':
      default:
        return raw.trim().isEmpty ? 'Rascunho' : raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = resolveNoteCategoryStyle(note.category, note.tags);
    final extractedLinks = extractMarkdownLinks(note.content);
    final props = _decodeProperties(note.propertiesJson);
    final cover = NoteCoverConfig.fromPropertiesJson(note.propertiesJson);
    final hasCustomCover = cover != null && cover.hasCustomCover;
    final areaColor = _parseHex(areaColorHex, const Color(0xFF6366F1));
    final sheetBg = isDark ? const Color(0xFF111827) : Colors.white;
    final headerGradStart = style.accent.withValues(
      alpha: isDark ? 0.16 : 0.08,
    );
    final headerGradEnd = isDark
        ? const Color(0xFF111827)
        : const Color(0xFFF8FAFC);

    final headerContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (breadcrumbAncestors.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Icon(
                  Icons.account_tree_outlined,
                  size: 14,
                  color: hasCustomCover
                      ? Colors.white70
                      : (isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B)),
                ),
                const SizedBox(width: 6),
                for (final anc in breadcrumbAncestors) ...[
                  InkWell(
                    onTap: onSelectNote != null
                        ? () => onSelectNote!(anc)
                        : null,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        anc.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: hasCustomCover
                              ? Colors.white
                              : AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    ' / ',
                    style: TextStyle(
                      fontSize: 12,
                      color: hasCustomCover ? Colors.white60 : Colors.grey,
                    ),
                  ),
                ],
                Text(
                  note.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: hasCustomCover
                        ? Colors.white70
                        : (isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: hasCustomCover
                    ? Colors.white.withValues(alpha: 0.16)
                    : style.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasCustomCover
                      ? Colors.white.withValues(alpha: 0.30)
                      : style.accent.withValues(alpha: 0.35),
                ),
              ),
              child: Icon(
                style.icon,
                color: hasCustomCover ? Colors.white : style.accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      note.title,
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: hasCustomCover
                            ? Colors.white
                            : (isDark
                                  ? const Color(0xFFF8FAFC)
                                  : const Color(0xFF0F172A)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      KnowledgePillBadge(
                        label: style.label,
                        color: style.accent,
                        isDark: hasCustomCover || isDark,
                      ),
                      if (note.isPinned)
                        KnowledgePillBadge(
                          icon: Icons.push_pin_rounded,
                          label: 'Fixada',
                          color: const Color(0xFFF59E0B),
                          isDark: hasCustomCover || isDark,
                        ),
                      if (areaName != null && areaName!.trim().isNotEmpty)
                        KnowledgePillBadge(
                          icon: Icons.layers_outlined,
                          label: areaName!,
                          color: areaColor,
                          isDark: hasCustomCover || isDark,
                        ),
                      if (props['status'] != null &&
                          props['status'].toString().trim().isNotEmpty)
                        KnowledgePillBadge(
                          icon: Icons.flag_outlined,
                          label: _statusLabel(props['status'].toString()),
                          color: const Color(0xFF0EA5E9),
                          isDark: hasCustomCover || isDark,
                        ),
                      if (props['priority'] != null &&
                          props['priority'].toString().trim().isNotEmpty)
                        KnowledgePillBadge(
                          label: 'Prioridade: ${props['priority']}',
                          color: const Color(0xFFEC4899),
                          isDark: hasCustomCover || isDark,
                        ),
                      if (note.nextReviewAt != null)
                        KnowledgePillBadge(
                          icon: Icons.replay_rounded,
                          label: 'SM-2 Nível ${note.reviewLevel}',
                          color: const Color(0xFF10B981),
                          isDark: hasCustomCover || isDark,
                        ),
                      for (final tag in tags)
                        KnowledgePillBadge(
                          label: '#$tag',
                          color: const Color(0xFF14B8A6),
                          isDark: hasCustomCover || isDark,
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.update_rounded,
                            size: 13,
                            color: hasCustomCover
                                ? Colors.white70
                                : (isDark
                                      ? const Color(0xFF94A3B8)
                                      : AppTheme.textMuted),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Atualizado em $formattedDate',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: hasCustomCover
                                    ? Colors.white70
                                    : (isDark
                                          ? const Color(0xFF94A3B8)
                                          : AppTheme.textMuted),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Semantics(
              button: true,
              label: 'Editar nota ${note.title}',
              child: FilledButton.tonalIcon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Editar'),
              ),
            ),
            if (onCustomizeCover != null)
              Semantics(
                button: true,
                label: 'Personalizar capa da nota ${note.title}',
                child: FilledButton.tonalIcon(
                  key: const Key('btn_note_detail_customize_cover'),
                  onPressed: onCustomizeCover,
                  icon: const Icon(Icons.palette_outlined, size: 16),
                  label: Text(hasCustomCover ? 'Capa' : 'Adicionar Capa'),
                ),
              ),
            Semantics(
              button: true,
              label: 'Exportar nota ${note.title} em PDF',
              child: IconButton.filledTonal(
                key: const Key('btn_note_detail_export_pdf'),
                tooltip: 'Exportar PDF',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444)
                      .withValues(alpha: 0.14),
                  foregroundColor: hasCustomCover || isDark
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFFDC2626),
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 19),
                onPressed: onExportPdf,
              ),
            ),
            Semantics(
              button: true,
              label: 'Exportar nota ${note.title}',
              child: IconButton.filledTonal(
                tooltip: 'Exportar Nota',
                icon: const Icon(Icons.share_outlined, size: 18),
                onPressed: onShare,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Mais ações',
              icon: Icon(
                Icons.more_horiz_rounded,
                color: hasCustomCover ? Colors.white : null,
              ),
              onSelected: (val) {
                if (val == 'pin') onTogglePin();
                if (val == 'cover') onCustomizeCover?.call();
                if (val == 'subpage') onCreateSubpage?.call();
                if (val == 'spaced_review') {
                  onToggleSpacedReview?.call();
                }
                if (val == 'research') {
                  onTransformResearch();
                }
              },
              itemBuilder: (_) => [
                if (onCustomizeCover != null)
                  const PopupMenuItem(
                    value: 'cover',
                    child: Text('Personalizar Capa'),
                  ),
                PopupMenuItem(
                  value: 'pin',
                  child: Text(
                    note.isPinned ? 'Desafixar nota' : 'Fixar no topo',
                  ),
                ),
                if (onCreateSubpage != null)
                  const PopupMenuItem(
                    value: 'subpage',
                    child: Text('Nova Subpágina'),
                  ),
                if (onToggleSpacedReview != null)
                  PopupMenuItem(
                    value: 'spaced_review',
                    child: Text(
                      note.nextReviewAt != null
                          ? 'Pausar Revisão Espaçada'
                          : 'Ativar Revisão Espaçada (SM-2)',
                    ),
                  ),
                const PopupMenuItem(
                  value: 'research',
                  child: Text('Transformar em Pesquisa'),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    return Container(
      color: isDark ? const Color(0xFF090D16) : const Color(0xFFF1F5F9),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 96),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Container(
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.09)
                      : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasCustomCover)
                    Stack(
                      children: [
                        Positioned.fill(
                          child: NoteCoverHeaderBackground(
                            cover: cover,
                            height: 220,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(24, 22, 20, 18),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.white.withValues(alpha: 0.14),
                              ),
                            ),
                          ),
                          child: headerContent,
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 22, 20, 18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [headerGradStart, headerGradEnd],
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      child: headerContent,
                    ),

                  // Corpo da nota com tipografia editorial, blocos Notion e sublinhado JW Library
                  Padding(
                    padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichBlockMarkdownView(
                          text: note.content,
                          isDark: isDark,
                          allowHighlights: true,
                          onLinkTap: onOpenLink,
                          onContentUpdated: onContentUpdated,
                          style: TextStyle(
                            fontSize: 15.8,
                            height: 1.68,
                            color: isDark
                                ? const Color(0xFFE2E8F0)
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        if (subpages.isNotEmpty || onCreateSubpage != null) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF151E32)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.subdirectory_arrow_right_rounded,
                                      size: 16,
                                      color: Color(0xFF6366F1),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'SUBPÁGINAS (${subpages.length})',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.7,
                                          color: isDark
                                              ? const Color(0xFF94A3B8)
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                    if (onCreateSubpage != null)
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                        ),
                                        onPressed: onCreateSubpage,
                                        icon: const Icon(Icons.add, size: 15),
                                        label: const Text(
                                          'Nova Subpágina',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                  ],
                                ),
                                if (subpages.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final sub in subpages)
                                        ActionChip(
                                          avatar: const Icon(
                                            Icons.article_outlined,
                                            size: 15,
                                            color: Color(0xFF6366F1),
                                          ),
                                          label: Text(
                                            sub.title,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          onPressed: onSelectNote != null
                                              ? () => onSelectNote!(sub)
                                              : null,
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Icon(
                              Icons.highlight_rounded,
                              size: 14,
                              color: isDark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Selecione qualquer trecho do texto acima para marcar com cores estilo JW Library.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Barra interativa de referências citadas e Backlinks bidirecionais
                  if (extractedLinks.isNotEmpty || backlinks.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0E1525)
                            : const Color(0xFFF8FAFC),
                        border: Border(
                          top: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.07)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (extractedLinks.isNotEmpty) ...[
                            Text(
                              'REFERÊNCIAS E LINKS CITADOS (${extractedLinks.length})',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final link in extractedLinks)
                                  ActionChip(
                                    avatar: Icon(
                                      link.isBible
                                          ? Icons.menu_book_rounded
                                          : (link.isInternal
                                                ? Icons.link_rounded
                                                : Icons.open_in_new_rounded),
                                      size: 16,
                                      color: link.isBible
                                          ? (isDark
                                                ? const Color(0xFFA5B4FC)
                                                : const Color(0xFF4338CA))
                                          : AppTheme.accentTeal,
                                    ),
                                    backgroundColor: isDark
                                        ? const Color(0xFF182238)
                                        : Colors.white,
                                    side: BorderSide(
                                      color:
                                          (link.isBible
                                                  ? const Color(0xFF6366F1)
                                                  : AppTheme.accentTeal)
                                              .withValues(
                                                alpha: isDark ? 0.35 : 0.28,
                                              ),
                                    ),
                                    label: Text(
                                      link.label,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: link.isBible
                                            ? (isDark
                                                  ? const Color(0xFFC7D2FE)
                                                  : const Color(0xFF3730A3))
                                            : (isDark
                                                  ? const Color(0xFF99F6E4)
                                                  : const Color(0xFF0F766E)),
                                      ),
                                    ),
                                    onPressed: () => onOpenLink(link.url),
                                  ),
                              ],
                            ),
                          ],
                          if (extractedLinks.isNotEmpty && backlinks.isNotEmpty)
                            const SizedBox(height: 16),
                          if (backlinks.isNotEmpty) ...[
                            Text(
                              'MENCIONADO EM (${backlinks.length})',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final b in backlinks)
                                  ActionChip(
                                    avatar: const Icon(
                                      Icons.call_received_rounded,
                                      size: 15,
                                      color: Color(0xFF10B981),
                                    ),
                                    backgroundColor: isDark
                                        ? const Color(0xFF13222B)
                                        : Colors.white,
                                    side: BorderSide(
                                      color: const Color(0xFF10B981)
                                          .withValues(alpha: 0.38),
                                    ),
                                    label: Text(
                                      '${b.sourceTitle} (${b.sourceSubtitle})',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onPressed: onOpenBacklink != null
                                        ? () => onOpenBacklink!(b)
                                        : null,
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card moderno para Perguntas & Dúvidas com destaque visual para Em Aberto vs Respondida.
class KnowledgeQuestionCard extends StatelessWidget {
  final KnowledgeQuestionEntry question;
  final String formattedDate;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onQuickAnswer;
  final Widget trailingMenu;

  const KnowledgeQuestionCard({
    super.key,
    required this.question,
    required this.formattedDate,
    required this.isDark,
    required this.onTap,
    required this.onQuickAnswer,
    required this.trailingMenu,
  });

  @override
  Widget build(BuildContext context) {
    final isAnswered = question.status == 'answered';
    final accent = isAnswered
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);
    final hasAnswer =
        question.answer != null && question.answer!.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4.5, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isAnswered
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.help_outline_rounded,
                                color: accent,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                question.question,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  height: 1.3,
                                  color: isDark
                                      ? const Color(0xFFF8FAFC)
                                      : const Color(0xFF0F172A),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            trailingMenu,
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0E1525)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: MarkdownPreviewText(
                            text: hasAnswer
                                ? SecondBrainBlockParser.toInlinePreviewMarkup(
                                    question.answer!,
                                  )
                                : (question.context?.trim().isNotEmpty == true
                                      ? SecondBrainBlockParser.toInlinePreviewMarkup(
                                          question.context!,
                                        )
                                      : 'Toque para ler detalhes ou registrar resposta bíblica.'),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.2,
                              height: 1.45,
                              color: isDark
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  KnowledgePillBadge(
                                    label: isAnswered
                                        ? 'Respondida'
                                        : 'Em Aberto',
                                    color: accent,
                                    isDark: isDark,
                                  ),
                                  if (question.category.trim().isNotEmpty)
                                    KnowledgePillBadge(
                                      label: question.category.trim(),
                                      color: AppTheme.primaryBlue,
                                      isDark: isDark,
                                    ),
                                  if (!isAnswered)
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        foregroundColor: accent,
                                      ),
                                      onPressed: onQuickAnswer,
                                      icon: const Icon(
                                        Icons.edit_note_rounded,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Responder',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Card moderno para Documentos locais com ações diretas e emblema por tipo de arquivo.
class KnowledgeDocumentCard extends StatelessWidget {
  final KnowledgeDocumentEntry doc;
  final List<String> tags;
  final bool isDark;
  final VoidCallback onOpen;
  final VoidCallback onOpenDetails;
  final VoidCallback onExportPdf;
  final Widget trailingMenu;

  const KnowledgeDocumentCard({
    super.key,
    required this.doc,
    required this.tags,
    required this.isDark,
    required this.onOpen,
    required this.onOpenDetails,
    required this.onExportPdf,
    required this.trailingMenu,
  });

  @override
  Widget build(BuildContext context) {
    final badge = resolveDocumentVisualStyle(doc.fileType, doc.category);
    final sizeKb = (doc.fileSize / 1024).toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            badge.accent.withValues(alpha: 0.22),
                            badge.accent.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: badge.accent.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Icon(badge.icon, color: badge.accent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: isDark
                                  ? const Color(0xFFF8FAFC)
                                  : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${doc.fileName} • $sizeKb KB',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    trailingMenu,
                  ],
                ),
                if (doc.description != null &&
                    doc.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  MarkdownPreviewText(
                    text: SecondBrainBlockParser.toInlinePreviewMarkup(
                      doc.description!,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF475569),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          KnowledgePillBadge(
                            label: badge.label,
                            color: badge.accent,
                            isDark: isDark,
                          ),
                          KnowledgePillBadge(
                            label: doc.category,
                            color: AppTheme.primaryBlue,
                            isDark: isDark,
                          ),
                          for (final t in tags.take(2))
                            KnowledgePillBadge(
                              label: '#$t',
                              color: const Color(0xFF14B8A6),
                              isDark: isDark,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Anotações',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.notes_rounded, size: 18),
                      onPressed: onOpenDetails,
                    ),
                    IconButton(
                      tooltip: 'Exportar Resumo em PDF',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 18,
                        color: isDark
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFFDC2626),
                      ),
                      onPressed: onExportPdf,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Card moderno para Recursos externos com domínio detectado e ações rápidas.
class KnowledgeResourceCard extends StatelessWidget {
  final KnowledgeResourceEntry resource;
  final List<String> tags;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onOpenUrl;
  final VoidCallback onExportPdf;
  final Widget trailingMenu;

  const KnowledgeResourceCard({
    super.key,
    required this.resource,
    required this.tags,
    required this.isDark,
    required this.onTap,
    this.onOpenUrl,
    required this.onExportPdf,
    required this.trailingMenu,
  });

  String? _extractDomain(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || uri.host.isEmpty) return null;
    return uri.host.replaceFirst(RegExp(r'^www\.'), '');
  }

  @override
  Widget build(BuildContext context) {
    final badge = resolveResourceVisualStyle(resource.resourceType);
    final domain = _extractDomain(resource.url);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            badge.accent.withValues(alpha: 0.22),
                            badge.accent.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: badge.accent.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Icon(badge.icon, color: badge.accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resource.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: isDark
                                  ? const Color(0xFFF8FAFC)
                                  : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            domain ?? badge.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: badge.accent,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    trailingMenu,
                  ],
                ),
                const SizedBox(height: 10),
                MarkdownPreviewText(
                  text: SecondBrainBlockParser.toInlinePreviewMarkup(
                    resource.description ??
                        resource.url ??
                        resource.resourceType,
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: isDark
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF475569),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          KnowledgePillBadge(
                            label: badge.label,
                            color: badge.accent,
                            isDark: isDark,
                          ),
                          for (final t in tags.take(2))
                            KnowledgePillBadge(
                              label: '#$t',
                              color: const Color(0xFF14B8A6),
                              isDark: isDark,
                            ),
                        ],
                      ),
                    ),
                    if (onOpenUrl != null)
                      IconButton(
                        tooltip: 'Abrir Link',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        onPressed: onOpenUrl,
                      ),
                    IconButton(
                      tooltip: 'Exportar em PDF',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 18,
                        color: isDark
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFFDC2626),
                      ),
                      onPressed: onExportPdf,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill badge estilizado com alto contraste para categorias, status e tags.
class KnowledgePillBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;
  final IconData? icon;

  const KnowledgePillBadge({
    super.key,
    required this.label,
    required this.color,
    required this.isDark,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDark
        ? Color.lerp(color, Colors.white, 0.35)!
        : Color.lerp(color, Colors.black, 0.18)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.11),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.28 : 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grade adaptativa: 2 colunas em telas >= 900px (PWA/iPad), lista vertical no celular.
class KnowledgeResponsiveCardGrid extends StatelessWidget {
  final List<Widget> children;

  const KnowledgeResponsiveCardGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        if (!isWide) {
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
            itemCount: children.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, idx) => children[idx],
          );
        }
        final cardWidth = ((constraints.maxWidth - 48) / 2).clamp(320.0, 620.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final child in children)
                SizedBox(width: cardWidth, child: child),
            ],
          ),
        );
      },
    );
  }
}
