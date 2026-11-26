import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../database/app_database.dart';
import '../markdown_preview_text.dart';
import 'knowledge_ui_components.dart';
import 'rich_block_markdown_view.dart';

/// Modos de visualização estilo Banco de Dados do Notion para Notas.
enum NotesDatabaseViewMode {
  list('Lista', Icons.view_list_rounded),
  table('Tabela', Icons.table_chart_outlined),
  kanban('Kanban', Icons.view_kanban_outlined),
  gallery('Galeria', Icons.grid_view_rounded);

  final String label;
  final IconData icon;
  const NotesDatabaseViewMode(this.label, this.icon);
}

class NotePropertyMeta {
  final String status;
  final String priority;

  const NotePropertyMeta({required this.status, required this.priority});

  static Map<String, dynamic> decodeMap(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  static NotePropertyMeta fromJson(String rawJson) {
    final map = decodeMap(rawJson);
    final rawStatus = (map['status'] ?? map['Status'] ?? 'rascunho')
        .toString()
        .trim()
        .toLowerCase();
    final normalizedStatus = switch (rawStatus) {
      'em_estudo' || 'em estudo' || 'in progress' || 'estudando' => 'em_estudo',
      'revisar' || 'para revisar' || 'review' => 'revisar',
      'concluido' || 'concluído' || 'done' || 'completed' => 'concluido',
      _ => 'rascunho',
    };
    final rawPriority = (map['priority'] ?? map['Prioridade'] ?? 'normal')
        .toString()
        .trim();
    return NotePropertyMeta(
      status: normalizedStatus,
      priority: rawPriority.isEmpty ? 'normal' : rawPriority,
    );
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'em_estudo':
        return 'Em Estudo';
      case 'revisar':
        return 'Revisar';
      case 'concluido':
        return 'Concluído';
      case 'rascunho':
      default:
        return 'Rascunho';
    }
  }

  static Color statusColor(String status) {
    switch (status) {
      case 'em_estudo':
        return const Color(0xFF0EA5E9);
      case 'revisar':
        return const Color(0xFFF59E0B);
      case 'concluido':
        return const Color(0xFF10B981);
      case 'rascunho':
      default:
        return const Color(0xFF6366F1);
    }
  }
}

List<String> _decodeNoteTags(String rawJson) {
  try {
    return (jsonDecode(rawJson) as List)
        .map((e) => e.toString().trim())
        .where((t) => t.isNotEmpty && !t.startsWith('research:'))
        .toList();
  } catch (_) {
    return const [];
  }
}

Color _parseAreaColor(String? hex) {
  if (hex == null || hex.trim().isEmpty) return const Color(0xFF6366F1);
  final clean = hex.trim().replaceFirst('#', '');
  final v = int.tryParse(clean.length == 6 ? 'FF$clean' : clean, radix: 16);
  return v != null ? Color(v) : const Color(0xFF6366F1);
}

/// Visualização em Tabela estilo Notion Database com rolagem responsiva.
class NotesTableView extends StatelessWidget {
  final List<KnowledgeNoteEntry> notes;
  final Map<String, KnowledgeAreaEntry> areasById;
  final bool isDark;
  final String Function(DateTime) formatDate;
  final void Function(KnowledgeNoteEntry note) onOpenNote;

  const NotesTableView({
    super.key,
    required this.notes,
    required this.areasById,
    required this.isDark,
    required this.formatDate,
    required this.onOpenNote,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF111827) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          clipBehavior: Clip.antiAlias,
          child: DataTable(
            showCheckboxColumn: false,
            headingRowColor: WidgetStatePropertyAll(
              isDark ? const Color(0xFF172033) : const Color(0xFFF8FAFC),
            ),
            columns: const [
              DataColumn(label: Text('Título')),
              DataColumn(label: Text('Área P.A.R.A.')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Prioridade')),
              DataColumn(label: Text('Tags')),
              DataColumn(label: Text('Atualizado')),
            ],
            rows: [for (final note in notes) _buildRow(context, note)],
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(BuildContext context, KnowledgeNoteEntry note) {
    final area = note.areaId != null ? areasById[note.areaId!] : null;
    final meta = NotePropertyMeta.fromJson(note.propertiesJson);
    final statusColor = NotePropertyMeta.statusColor(meta.status);
    final tags = _decodeNoteTags(note.tags);

    return DataRow(
      onSelectChanged: (_) => onOpenNote(note),
      cells: [
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (note.parentNoteId != null) ...[
                  const Icon(
                    Icons.subdirectory_arrow_right_rounded,
                    size: 14,
                    color: Color(0xFF6366F1),
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          area == null
              ? const Text('—', style: TextStyle(color: Colors.grey))
              : KnowledgePillBadge(
                  icon: Icons.layers_outlined,
                  label: area.name,
                  color: _parseAreaColor(area.colorHex),
                  isDark: isDark,
                ),
        ),
        DataCell(
          KnowledgePillBadge(
            label: NotePropertyMeta.statusLabel(meta.status),
            color: statusColor,
            isDark: isDark,
          ),
        ),
        DataCell(Text(meta.priority)),
        DataCell(
          tags.isEmpty
              ? const Text('—', style: TextStyle(color: Colors.grey))
              : Text(tags.take(3).map((t) => '#$t').join(' ')),
        ),
        DataCell(Text(formatDate(note.updatedAt))),
      ],
    );
  }
}

/// Quadro Kanban horizontal por Status (`Rascunho`, `Em Estudo`, `Revisar`, `Concluído`).
class NotesKanbanView extends StatelessWidget {
  final List<KnowledgeNoteEntry> notes;
  final Map<String, KnowledgeAreaEntry> areasById;
  final bool isDark;
  final void Function(KnowledgeNoteEntry note) onOpenNote;
  final Future<void> Function(KnowledgeNoteEntry note, String newStatus)
  onChangeStatus;
  final void Function(String status) onCreateInStatus;

  static const List<String> columnsOrder = [
    'rascunho',
    'em_estudo',
    'revisar',
    'concluido',
  ];

  const NotesKanbanView({
    super.key,
    required this.notes,
    required this.areasById,
    required this.isDark,
    required this.onOpenNote,
    required this.onChangeStatus,
    required this.onCreateInStatus,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<KnowledgeNoteEntry>>{
      for (final col in columnsOrder) col: <KnowledgeNoteEntry>[],
    };
    for (final note in notes) {
      final meta = NotePropertyMeta.fromJson(note.propertiesJson);
      grouped[meta.status]!.add(note);
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
      itemCount: columnsOrder.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        final colStatus = columnsOrder[index];
        final colNotes = grouped[colStatus]!;
        final colColor = NotePropertyMeta.statusColor(colStatus);
        final colBg = isDark
            ? const Color(0xFF0E1525)
            : const Color(0xFFF1F5F9);
        final cardBg = isDark ? const Color(0xFF151E32) : Colors.white;

        return DragTarget<KnowledgeNoteEntry>(
          key: Key('kanban_col_$colStatus'),
          onWillAcceptWithDetails: (details) =>
              NotePropertyMeta.fromJson(details.data.propertiesJson).status !=
              colStatus,
          onAcceptWithDetails: (details) {
            unawaited(onChangeStatus(details.data, colStatus));
          },
          builder: (context, candidateData, rejectedData) {
            final isHovering = candidateData.isNotEmpty;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 285,
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
                            '${NotePropertyMeta.statusLabel(colStatus)} (${colNotes.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 18),
                          tooltip: 'Nova nota nesta coluna',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => onCreateInStatus(colStatus),
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
                        color: colColor.withValues(alpha: isDark ? 0.24 : 0.14),
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
                              'Soltar em ${NotePropertyMeta.statusLabel(colStatus)}',
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
                    child: colNotes.isEmpty
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
                                    isHovering
                                        ? 'Solte aqui para mover'
                                        : 'Nenhum cartão\n(arraste para cá)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isHovering
                                          ? colColor
                                          : (isDark
                                                ? const Color(0xFF64748B)
                                                : const Color(0xFF94A3B8)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(10),
                            itemCount: colNotes.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final n = colNotes[i];
                              final area = n.areaId != null
                                  ? areasById[n.areaId!]
                                  : null;
                              final tags = _decodeNoteTags(n.tags);
                              final previewMarkup =
                                  SecondBrainBlockParser.toInlinePreviewMarkup(
                                    n.content,
                                  );

                              Widget buildCard({bool isFeedback = false}) {
                                return Material(
                                  color: cardBg,
                                  elevation: isFeedback ? 8 : 0,
                                  borderRadius: BorderRadius.circular(12),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: isFeedback
                                        ? null
                                        : () => onOpenNote(n),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isFeedback
                                              ? colColor
                                              : (isDark
                                                    ? Colors.white.withValues(
                                                        alpha: 0.08,
                                                      )
                                                    : const Color(0xFFE2E8F0)),
                                          width: isFeedback ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 2,
                                                  right: 6,
                                                ),
                                                child: MouseRegion(
                                                  cursor:
                                                      SystemMouseCursors.grab,
                                                  child: Icon(
                                                    Icons
                                                        .drag_indicator_rounded,
                                                    size: 16,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF64748B,
                                                          )
                                                        : const Color(
                                                            0xFF94A3B8,
                                                          ),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  n.title,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13.5,
                                                  ),
                                                ),
                                              ),
                                              if (!isFeedback)
                                                PopupMenuButton<String>(
                                                  tooltip: 'Mover coluna',
                                                  icon: const Icon(
                                                    Icons.swap_horiz_rounded,
                                                    size: 18,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  onSelected: (target) =>
                                                      onChangeStatus(n, target),
                                                  itemBuilder: (_) => [
                                                    for (final s
                                                        in columnsOrder)
                                                      if (s != colStatus)
                                                        PopupMenuItem(
                                                          value: s,
                                                          child: Text(
                                                            'Mover para ${NotePropertyMeta.statusLabel(s)}',
                                                          ),
                                                        ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                          if (previewMarkup.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            MarkdownPreviewText(
                                              text: previewMarkup,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                height: 1.35,
                                                color: isDark
                                                    ? const Color(0xFF94A3B8)
                                                    : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                          if (area != null ||
                                              tags.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                if (area != null)
                                                  KnowledgePillBadge(
                                                    label: area.name,
                                                    color: _parseAreaColor(
                                                      area.colorHex,
                                                    ),
                                                    isDark: isDark,
                                                  ),
                                                for (final t in tags.take(2))
                                                  KnowledgePillBadge(
                                                    label: '#$t',
                                                    color: AppTheme.primaryBlue,
                                                    isDark: isDark,
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final card = buildCard();
                              return Draggable<KnowledgeNoteEntry>(
                                key: Key('kanban_card_${n.id}'),
                                data: n,
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: SizedBox(
                                    width: 265,
                                    child: Opacity(
                                      opacity: 0.94,
                                      child: buildCard(isFeedback: true),
                                    ),
                                  ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.32,
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
      },
    );
  }
}

/// Galeria visual estilo Notion Gallery com capa colorida por Área/Categoria.
class NotesGalleryView extends StatelessWidget {
  final List<KnowledgeNoteEntry> notes;
  final Map<String, KnowledgeAreaEntry> areasById;
  final bool isDark;
  final String Function(DateTime) formatDate;
  final void Function(KnowledgeNoteEntry note) onOpenNote;

  const NotesGalleryView({
    super.key,
    required this.notes,
    required this.areasById,
    required this.isDark,
    required this.formatDate,
    required this.onOpenNote,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF131B2E) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 310,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        final style = resolveNoteCategoryStyle(note.category, note.tags);
        final area = note.areaId != null ? areasById[note.areaId!] : null;
        final accent = area != null
            ? _parseAreaColor(area.colorHex)
            : style.accent;
        final meta = NotePropertyMeta.fromJson(note.propertiesJson);
        final tags = _decodeNoteTags(note.tags);
        final previewMarkup = SecondBrainBlockParser.toInlinePreviewMarkup(
          note.content,
        );

        return Material(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onOpenNote(note),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: isDark ? 0.35 : 0.22),
                          accent.withValues(alpha: isDark ? 0.14 : 0.08),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(style.icon, size: 16, color: accent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            area?.name ?? style.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ),
                        Text(
                          formatDate(note.updatedAt),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: previewMarkup.isEmpty
                                ? Text(
                                    'Sem conteúdo',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                    ),
                                  )
                                : MarkdownPreviewText(
                                    text: previewMarkup,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              KnowledgePillBadge(
                                label: NotePropertyMeta.statusLabel(
                                  meta.status,
                                ),
                                color: NotePropertyMeta.statusColor(
                                  meta.status,
                                ),
                                isDark: isDark,
                              ),
                              for (final t in tags.take(2))
                                KnowledgePillBadge(
                                  label: '#$t',
                                  color: AppTheme.primaryBlue,
                                  isDark: isDark,
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
        );
      },
    );
  }
}
