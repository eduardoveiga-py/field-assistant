import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/app_logger.dart';
import '../../../core/app_theme.dart';
import '../../../database/app_database.dart';
import '../../../knowledge/knowledge_manager.dart';
import '../../../knowledge/notion_import_parser.dart';
import '../../../knowledge/second_brain_review_service.dart';
import '../../../sync/media_bytes.dart';
import '../markdown_preview_text.dart';
import 'rich_block_markdown_view.dart';

/// Abre o gerenciador de Áreas P.A.R.A. (criar, editar cor/nome e excluir).
Future<void> showManageAreasDialog(
  BuildContext context, {
  required KnowledgeManager km,
  String? currentAreaId,
  ValueChanged<String?>? onAreaSelected,
}) async {
  const palette = [
    '#6366F1',
    '#0EA5E9',
    '#10B981',
    '#F59E0B',
    '#EC4899',
    '#8B5CF6',
  ];

  final nameCtrl = TextEditingController();
  try {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        var selectedColor = palette.first;
        return StatefulBuilder(
          builder: (ctx, setDlgState) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.layers_rounded, color: Color(0xFF6366F1)),
                SizedBox(width: 8),
                Expanded(child: Text('Áreas P.A.R.A.')),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Organize Notas, Dúvidas, Documentos, Recursos e Projetos por grandes responsabilidades contínuas (ex: Ministério, Família, Idiomas).',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nova Área',
                              hintText: 'Ex: Tradução Ticuna',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) return;
                            await km.createArea(
                              name: name,
                              colorHex: selectedColor,
                            );
                            nameCtrl.clear();
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Criar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final hex in palette)
                          GestureDetector(
                            onTap: () => setDlgState(() => selectedColor = hex),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Color(
                                  int.parse(
                                    'FF${hex.replaceFirst('#', '')}',
                                    radix: 16,
                                  ),
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selectedColor == hex
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(),
                    StreamBuilder<List<KnowledgeAreaEntry>>(
                      stream: km.watchAreas(),
                      builder: (ctx, snap) {
                        final areas = snap.data ?? const <KnowledgeAreaEntry>[];
                        if (areas.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'Nenhuma área criada ainda.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }
                        return Column(
                          children: [
                            for (final area in areas)
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Color(
                                    int.tryParse(
                                          'FF${(area.colorHex ?? '#6366F1').replaceFirst('#', '')}',
                                          radix: 16,
                                        ) ??
                                        0xFF6366F1,
                                  ),
                                ),
                                title: Text(
                                  area.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (onAreaSelected != null)
                                      TextButton(
                                        onPressed: () {
                                          onAreaSelected(area.id);
                                          Navigator.pop(ctx);
                                        },
                                        child: Text(
                                          currentAreaId == area.id
                                              ? 'Selecionada'
                                              : 'Filtrar',
                                        ),
                                      ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: Colors.redAccent,
                                      ),
                                      tooltip: 'Excluir área',
                                      onPressed: () async {
                                        await km.softDeleteArea(area.id);
                                        if (currentAreaId == area.id) {
                                          onAreaSelected?.call(null);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fechar'),
              ),
            ],
          ),
        );
      },
    );
  } finally {
    nameCtrl.dispose();
  }
}

/// Fluxo guiado de Revisão Semanal (GTD) + Revisão Espaçada (SM-2 Lite).
Future<void> showWeeklyReviewDialog(
  BuildContext context, {
  required AppDatabase db,
  required KnowledgeManager km,
  required void Function(KnowledgeQuestionEntry q) onAnswerQuestion,
  required void Function(String projectId) onOpenProject,
  VoidCallback? onOpenInbox,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => _WeeklyReviewModal(
      db: db,
      km: km,
      onAnswerQuestion: onAnswerQuestion,
      onOpenProject: onOpenProject,
      onOpenInbox: onOpenInbox,
    ),
  );
}

class _WeeklyReviewModal extends StatefulWidget {
  final AppDatabase db;
  final KnowledgeManager km;
  final void Function(KnowledgeQuestionEntry q) onAnswerQuestion;
  final void Function(String projectId) onOpenProject;
  final VoidCallback? onOpenInbox;

  const _WeeklyReviewModal({
    required this.db,
    required this.km,
    required this.onAnswerQuestion,
    required this.onOpenProject,
    this.onOpenInbox,
  });

  @override
  State<_WeeklyReviewModal> createState() => _WeeklyReviewModalState();
}

class _WeeklyReviewModalState extends State<_WeeklyReviewModal> {
  WeeklyReviewSnapshot? _snapshot;
  bool _loading = true;
  final Set<String> _revealedIds = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final snap = await SecondBrainReviewService.loadWeeklyReview(widget.db);
    if (!mounted) return;
    setState(() {
      _snapshot = snap;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snapshot;
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.psychology_alt_rounded, color: Color(0xFF10B981)),
          SizedBox(width: 8),
          Expanded(child: Text('Revisão Semanal & Espaçada')),
        ],
      ),
      content: SizedBox(
        width: 580,
        child: _loading || snap == null
            ? const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatChip(
                          label: 'SM-2 Pendentes',
                          count: snap.totalDueSpacedReviews,
                          color: const Color(0xFF10B981),
                        ),
                        _StatChip(
                          label: 'Inbox sem triagem',
                          count: snap.unprocessedInbox.length,
                          color: AppTheme.primaryBlue,
                        ),
                        _StatChip(
                          label: 'Dúvidas em aberto',
                          count: snap.unansweredQuestions.length,
                          color: const Color(0xFFF59E0B),
                        ),
                        _StatChip(
                          label: 'Projetos sem tarefa',
                          count: snap.stalledActiveProjects.length,
                          color: const Color(0xFFEC4899),
                        ),
                        _StatChip(
                          label: 'Agenda (7 dias)',
                          count: snap.upcomingAppointments.length,
                          color: const Color(0xFF6366F1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 1. Revisão Espaçada (SM-2)
                    const Text(
                      '1. REVISÃO ESPAÇADA (SM-2)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (snap.totalDueSpacedReviews == 0)
                      const Text(
                        'Tudo em dia! Ative a Revisão Espaçada nas propriedades de uma Nota quando quiser memorizar pontos-chave.',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey),
                      )
                    else ...[
                      for (final note in snap.dueReviewNotes)
                        _buildSm2Card(
                          id: 'note_${note.id}',
                          title: note.title,
                          level: note.reviewLevel,
                          revealBody: note.content,
                          onGrade: (q) async {
                            await SecondBrainReviewService.recordNoteReview(
                              widget.db,
                              note.id,
                              q,
                            );
                            await _reload();
                          },
                        ),
                      for (final question in snap.dueReviewQuestions)
                        _buildSm2Card(
                          id: 'question_${question.id}',
                          title: question.question,
                          level: question.reviewLevel,
                          revealBody: question.answer ?? question.context ?? '',
                          onGrade: (q) async {
                            await SecondBrainReviewService.recordQuestionReview(
                              widget.db,
                              question.id,
                              q,
                            );
                            await _reload();
                          },
                        ),
                    ],
                    const SizedBox(height: 14),

                    // 2. Inbox Pendente
                    const Text(
                      '2. INBOX PENDENTE DE TRIAGEM',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (snap.unprocessedInbox.isEmpty)
                      const Text(
                        'Inbox zerada!',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey),
                      )
                    else ...[
                      for (final item in snap.unprocessedInbox.take(4))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.inbox_outlined, size: 18),
                          title: Text(
                            MarkdownPreviewText.cleanMarkdown(item.content)
                                .replaceAll('\n', ' '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (widget.onOpenInbox != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onOpenInbox!();
                            },
                            icon: const Icon(Icons.open_in_new, size: 15),
                            label: const Text('Processar na Caixa de Entrada'),
                          ),
                        ),
                    ],
                    const SizedBox(height: 14),

                    // 3. Dúvidas em Aberto
                    const Text(
                      '3. DÚVIDAS BÍBLICAS EM ABERTO',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (snap.unansweredQuestions.isEmpty)
                      const Text(
                        'Nenhuma dúvida pendente.',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey),
                      )
                    else
                      for (final q in snap.unansweredQuestions.take(5))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.help_outline,
                            size: 18,
                            color: Color(0xFFF59E0B),
                          ),
                          title: Text(
                            q.question,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onAnswerQuestion(q);
                            },
                            child: const Text('Responder'),
                          ),
                        ),
                    const SizedBox(height: 14),

                    // 4. Projetos Estagnados
                    const Text(
                      '4. PROJETOS ATIVOS SEM PRÓXIMA TAREFA',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (snap.stalledActiveProjects.isEmpty)
                      const Text(
                        'Todos os projetos ativos têm próximas ações.',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey),
                      )
                    else
                      for (final p in snap.stalledActiveProjects.take(5))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: Color(0xFFEC4899),
                          ),
                          title: Text(p.name),
                          trailing: TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onOpenProject(p.id);
                            },
                            child: const Text('Definir tarefa'),
                          ),
                        ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _reload,
          icon: const Icon(Icons.refresh, size: 17),
          label: const Text('Atualizar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Concluir'),
        ),
      ],
    );
  }

  Widget _buildSm2Card({
    required String id,
    required String title,
    required int level,
    required String revealBody,
    required Future<void> Function(ReviewQuality q) onGrade,
  }) {
    final revealed = _revealedIds.contains(id);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Chip(
                  label: Text(
                    'Nível $level',
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (!revealed)
              TextButton.icon(
                onPressed: () => setState(() => _revealedIds.add(id)),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Mostrar resposta / notas'),
              )
            else ...[
              const SizedBox(height: 6),
              if (revealBody.trim().isEmpty)
                const Text(
                  '(Sem corpo detalhado)',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SingleChildScrollView(
                    child: RichBlockMarkdownView(
                      text: revealBody,
                      isDark: Theme.of(context).brightness == Brightness.dark,
                      allowHighlights: false,
                      style: const TextStyle(fontSize: 12.5, height: 1.45),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final q in ReviewQuality.values)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => onGrade(q),
                      child: Text(
                        q.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Diálogo de importação de pacotes do Notion (`.zip`, `.md` ou `.csv`) preservando Áreas, Subpáginas e Links.
Future<void> showNotionImportDialog(
  BuildContext context, {
  required AppDatabase db,
  String? fallbackAreaId,
}) async {
  ParsedNotionPackage? parsed;
  bool loading = false;
  String? errorMsg;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome_mosaic_outlined, color: Color(0xFF8B5CF6)),
            SizedBox(width: 8),
            Expanded(child: Text('Importar do Notion (.zip / .md / .csv)')),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Selecione a exportação em Markdown/CSV (.zip) gerada no Notion ou arquivos soltos. '
                  'As pastas de topo viram Áreas P.A.R.A., subpastas viram subpáginas e links internos são convertidos para app://ref/note.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: loading
                      ? null
                      : () async {
                          setDlgState(() {
                            loading = true;
                            errorMsg = null;
                          });
                          try {
                            final picked = await FilePicker.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: [
                                'zip',
                                'md',
                                'markdown',
                                'csv',
                              ],
                            );
                            if (picked.isEmpty) {
                              setDlgState(() => loading = false);
                              return;
                            }

                            final zipFiles = picked
                                .where(
                                  (f) => f.name.toLowerCase().endsWith('.zip'),
                                )
                                .toList();
                            ParsedNotionPackage pkg;
                            if (zipFiles.isNotEmpty) {
                              final f = zipFiles.first;
                              Uint8List? bytes;
                              try {
                                bytes = await f.readAsBytes();
                              } catch (_) {}
                              if ((bytes == null || bytes.isEmpty) &&
                                  f.path != null &&
                                  f.path!.isNotEmpty) {
                                bytes = await readMediaBytes(f.path!);
                              }
                              if (bytes == null || bytes.isEmpty) {
                                throw StateError(
                                  'Arquivo .zip vazio ou ilegível.',
                                );
                              }
                              pkg = NotionImportParser.parseZipBytes(bytes);
                            } else {
                              final map = <String, Uint8List>{};
                              for (final f in picked) {
                                Uint8List? bytes;
                                try {
                                  bytes = await f.readAsBytes();
                                } catch (_) {}
                                if ((bytes == null || bytes.isEmpty) &&
                                    f.path != null &&
                                    f.path!.isNotEmpty) {
                                  bytes = await readMediaBytes(f.path!);
                                }
                                if (bytes != null && bytes.isNotEmpty) {
                                  map[f.name] = bytes;
                                }
                              }
                              pkg = NotionImportParser.parseFiles(map);
                            }
                            setDlgState(() {
                              parsed = pkg;
                              loading = false;
                            });
                          } catch (e, st) {
                            AppLogger.warning(
                              'Falha ao analisar exportação do Notion',
                              e,
                              st,
                            );
                            setDlgState(() {
                              errorMsg = 'Falha ao ler pacote do Notion: $e';
                              loading = false;
                            });
                          }
                        },
                  icon: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.folder_zip_outlined),
                  label: Text(
                    loading
                        ? 'Analisando arquivos...'
                        : 'Selecionar Arquivo do Notion',
                  ),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMsg!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                if (parsed != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pré-visualização pronta:',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• ${parsed!.areas.length} Área(s) P.A.R.A. identificada(s)',
                        ),
                        Text(
                          '• ${parsed!.notes.length} Nota(s) e subpágina(s)',
                        ),
                        Text(
                          '• ${parsed!.rewrittenLinksCount} Link(s) interno(s) preservado(s)',
                        ),
                        for (final w in parsed!.warnings.take(3))
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '⚠ $w',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: loading ? null : () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          if (parsed != null && parsed!.notes.isNotEmpty)
            FilledButton.icon(
              onPressed: loading
                  ? null
                  : () async {
                      setDlgState(() => loading = true);
                      try {
                        final res =
                            await SecondBrainReviewService.commitNotionPackage(
                              db,
                              parsed!,
                              fallbackAreaId: fallbackAreaId,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Notion importado: ${res.importedNotes} nota(s) em '
                                '${res.createdAreas + res.reusedAreas} área(s)!',
                              ),
                              backgroundColor: AppTheme.successGreen,
                            ),
                          );
                        }
                      } catch (e, st) {
                        AppLogger.warning(
                          'Erro ao importar notas do Notion no banco',
                          e,
                          st,
                        );
                        setDlgState(() {
                          errorMsg = 'Erro ao gravar notas: $e';
                          loading = false;
                        });
                      }
                    },
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text('Importar (${parsed!.notes.length})'),
            ),
        ],
      ),
    ),
  );
}
