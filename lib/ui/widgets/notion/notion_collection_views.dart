import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

/// Modos de visualização reutilizáveis em todos os módulos (Lista, Tabela, Kanban, Galeria).
enum NotionViewMode {
  list('Lista', Icons.view_list_rounded),
  table('Tabela', Icons.table_chart_outlined),
  kanban('Kanban', Icons.view_kanban_outlined),
  gallery('Galeria', Icons.grid_view_rounded);

  final String label;
  final IconData icon;
  const NotionViewMode(this.label, this.icon);
}

/// Barra compacta de alternância de modos (Lista | Tabela | Kanban | Galeria).
class NotionViewModeBar extends StatelessWidget {
  final NotionViewMode mode;
  final List<NotionViewMode> availableModes;
  final ValueChanged<NotionViewMode> onChanged;
  final bool isDark;
  final String keyPrefix;
  final Widget? trailing;

  const NotionViewModeBar({
    super.key,
    required this.mode,
    required this.availableModes,
    required this.onChanged,
    required this.isDark,
    this.keyPrefix = 'notion_view',
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.72)
            : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: availableModes.map((m) {
                  final selected = mode == m;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: Key('${keyPrefix}_${m.name}'),
                      selected: selected,
                      onSelected: (_) => onChanged(m),
                      visualDensity: VisualDensity.compact,
                      selectedColor: AppTheme.primaryBlue.withValues(
                        alpha: 0.16,
                      ),
                      side: BorderSide(
                        color: selected
                            ? AppTheme.primaryBlue
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : const Color(0xFFCBD5E1)),
                      ),
                      avatar: Icon(
                        m.icon,
                        size: 15,
                        color: selected
                            ? AppTheme.primaryBlue
                            : (isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B)),
                      ),
                      label: Text(
                        m.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? AppTheme.primaryBlue
                              : (isDark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF334155)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Definição de coluna para [NotionKanbanBoard].
class NotionKanbanColumnSpec<T> {
  final String statusKey;
  final String label;
  final Color accentColor;
  final IconData? icon;
  final VoidCallback? onQuickAdd;

  const NotionKanbanColumnSpec({
    required this.statusKey,
    required this.label,
    required this.accentColor,
    this.icon,
    this.onQuickAdd,
  });
}

class _KanbanDragPayload<T> {
  final String id;
  final String fromColumn;
  final T item;

  const _KanbanDragPayload({
    required this.id,
    required this.fromColumn,
    required this.item,
  });
}

/// Quadro Kanban genérico e responsivo com drag-and-drop fluido entre colunas
/// para Tarefas, Projetos, Dúvidas, Estudos Bíblicos e Inbox.
class NotionKanbanBoard<T extends Object> extends StatelessWidget {
  final List<NotionKanbanColumnSpec<T>> columns;
  final Map<String, List<T>> itemsByColumn;
  final String Function(T item) itemId;
  final Future<void> Function(T item, String targetColumn) onMoveToColumn;
  final Widget Function(
    BuildContext context,
    T item,
    String columnKey, {
    required bool isFeedback,
  })
  cardBuilder;
  final bool isDark;
  final String keyPrefix;

  const NotionKanbanBoard({
    super.key,
    required this.columns,
    required this.itemsByColumn,
    required this.itemId,
    required this.onMoveToColumn,
    required this.cardBuilder,
    required this.isDark,
    this.keyPrefix = 'kanban',
  });

  @override
  Widget build(BuildContext context) {
    final colBg = isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC);

    return LayoutBuilder(
      builder: (context, constraints) {
        final colHeight = (constraints.maxHeight - 24).clamp(300.0, 920.0);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 84),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: columns.map((col) {
              final colItems = itemsByColumn[col.statusKey] ?? const [];
              final colColor = col.accentColor;

              return DragTarget<_KanbanDragPayload<T>>(
                key: Key('${keyPrefix}_col_${col.statusKey}'),
                onWillAcceptWithDetails: (details) =>
                    details.data.fromColumn != col.statusKey,
                onAcceptWithDetails: (details) {
                  unawaited(onMoveToColumn(details.data.item, col.statusKey));
                },
                builder: (ctx, candidateData, _) {
                  final isHovering = candidateData.isNotEmpty;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 288,
                    height: colHeight,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isHovering
                          ? colColor.withValues(alpha: isDark ? 0.16 : 0.09)
                          : colBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isHovering
                            ? colColor
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFFE2E8F0)),
                        width: isHovering ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: colColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${col.label} (${colItems.length})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                              if (col.onQuickAdd != null)
                                IconButton(
                                  icon: const Icon(Icons.add, size: 18),
                                  tooltip: 'Adicionar em ${col.label}',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: col.onQuickAdd,
                                ),
                            ],
                          ),
                        ),
                        if (isHovering)
                          Container(
                            margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: colColor.withValues(
                                alpha: isDark ? 0.24 : 0.14,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: colColor.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.move_to_inbox_rounded,
                                  size: 14,
                                  color: colColor,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Soltar em ${col.label}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: colColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const Divider(height: 1),
                        Expanded(
                          child: colItems.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isHovering
                                              ? Icons.add_circle_outline_rounded
                                              : Icons.drag_indicator_rounded,
                                          size: 22,
                                          color: isHovering
                                              ? colColor
                                              : (isDark
                                                    ? const Color(0xFF475569)
                                                    : const Color(0xFF94A3B8)),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          isHovering ? 'Solte aqui para mover' : 'Nenhum item\n(arraste para cá)',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isHovering
                                                ? colColor
                                                : (isDark
                                                      ? const Color(0xFF64748B)
                                                      : const Color(
                                                          0xFF94A3B8,
                                                        )),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(10),
                                  itemCount: colItems.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (ctx, i) {
                                    final item = colItems[i];
                                    final id = itemId(item);
                                    final card = cardBuilder(
                                      ctx,
                                      item,
                                      col.statusKey,
                                      isFeedback: false,
                                    );
                                    final feedbackCard = Material(
                                      color: Colors.transparent,
                                      child: SizedBox(
                                        width: 266,
                                        child: Opacity(
                                          opacity: 0.94,
                                          child: cardBuilder(
                                            ctx,
                                            item,
                                            col.statusKey,
                                            isFeedback: true,
                                          ),
                                        ),
                                      ),
                                    );
                                    return Draggable<_KanbanDragPayload<T>>(
                                      key: Key('${keyPrefix}_card_$id'),
                                      data: _KanbanDragPayload<T>(
                                        id: id,
                                        fromColumn: col.statusKey,
                                        item: item,
                                      ),
                                      maxSimultaneousDrags: 1,
                                      feedback: feedbackCard,
                                      childWhenDragging: Opacity(
                                        opacity: 0.35,
                                        child: card,
                                      ),
                                      child: card,
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

/// Definição de coluna da tabela estilo Notion.
class NotionTableColumnDef {
  final String label;
  final double width;

  const NotionTableColumnDef({required this.label, required this.width});
}

/// Linha tipada da tabela responsiva.
class NotionTableRowItem {
  final List<Widget> cells;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const NotionTableRowItem({required this.cells, this.onTap, this.onLongPress});
}

/// Tabela estilo Banco de Dados do Notion com rolagem horizontal segura para mobile/tablet/desktop.
class NotionResponsiveTable extends StatelessWidget {
  final List<NotionTableColumnDef> columns;
  final List<NotionTableRowItem> rows;
  final bool isDark;

  const NotionResponsiveTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF131B2E) : Colors.white;
    final headerBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);
    final totalWidth =
        columns.fold<double>(0, (acc, c) => acc + c.width) + 28.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: headerBg,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  child: Row(
                    children: columns
                        .map(
                          (col) => SizedBox(
                            width: col.width,
                            child: Text(
                              col.label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                Divider(height: 1, color: borderColor),
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: borderColor),
                  InkWell(
                    onTap: rows[i].onTap,
                    onLongPress: rows[i].onLongPress,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      child: Row(
                        children: List.generate(columns.length, (cIdx) {
                          final w = cIdx < rows[i].cells.length
                              ? rows[i].cells[cIdx]
                              : const SizedBox.shrink();
                          return SizedBox(width: columns[cIdx].width, child: w);
                        }),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grade de Galeria estilo Banco de Dados do Notion reutilizável em todos os módulos.
class NotionGalleryGrid<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final double maxCrossAxisExtent;
  final double childAspectRatio;

  const NotionGalleryGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.maxCrossAxisExtent = 310,
    this.childAspectRatio = 1.15,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxCrossAxisExtent,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, idx) => itemBuilder(ctx, items[idx]),
    );
  }
}
