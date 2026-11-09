import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../database/app_database.dart';
import '../../projects/project_manager.dart';
import '../../tasks/task_manager.dart';
import '../providers.dart';
import '../widgets/adaptive_ministry_sheet.dart';
import '../widgets/markdown_preview_text.dart';
import '../widgets/rich_markdown_toolbar.dart';

/// Tela de Detalhes de um Projeto do Módulo B.
/// Exibe objetivos, cálculo de progresso %, tarefas vinculadas, notas e recursos.
class ProjectDetailScreen extends ConsumerStatefulWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final projectMgr = ref.watch(projectManagerProvider);
    final taskMgr = ref.watch(taskManagerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<ProjectEntry?>(
      stream: projectMgr.watchProject(widget.projectId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final project = snapshot.data;
        if (project == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Projeto')),
            body: const Center(child: Text('Projeto não encontrado ou excluído.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(project.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (val) => _handleMenuAction(val, project),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'edit', child: Text('Editar Projeto')),
                  const PopupMenuItem(value: 'complete', child: Text('Marcar como Concluído')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Excluir Projeto', style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddTaskModal(project),
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_task),
            label: const Text('Nova Tarefa'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cartão de Cabeçalho e Progresso
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _categoryLabel(project.category),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor(project.status).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _statusLabel(project.status),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _statusColor(project.status),
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (project.targetDate != null)
                            Row(
                              children: [
                                const Icon(Icons.flag_outlined, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  'Meta: ${_formatDate(project.targetDate!)}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (project.objective != null && project.objective!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          project.objective!,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                      if (project.description != null && project.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          project.description!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Barra de Progresso Reativa
                      StreamBuilder<ProjectProgress>(
                        stream: projectMgr.watchProjectProgress(project.id),
                        builder: (ctx, progSnap) {
                          final prog = progSnap.data ?? ProjectProgress.empty();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Progresso das Tarefas',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                  Text(
                                    '${prog.completedTasks}/${prog.totalTasks} (${prog.progressPercent.toStringAsFixed(0)}%)',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: prog.totalTasks > 0 ? prog.completedTasks / prog.totalTasks : 0.0,
                                backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Lista de Tarefas do Projeto
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tarefas do Projeto',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: () => _showAddTaskModal(project),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Adicionar'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                StreamBuilder<List<TaskEntry>>(
                  stream: taskMgr.watchTasksForProject(project.id),
                  builder: (ctx, taskSnap) {
                    final tasks = taskSnap.data ?? [];
                    if (tasks.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: Text(
                          'Nenhuma tarefa vinculada a este projeto ainda.',
                          style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: tasks.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final task = tasks[i];
                        return Card(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: CheckboxListTile(
                            value: task.isCompleted,
                            activeColor: AppTheme.primaryBlue,
                            onChanged: (val) => taskMgr.toggleTaskComplete(task.id, completed: val),
                            title: Text(
                              task.title,
                              style: TextStyle(
                                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (task.description != null && task.description!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  MarkdownPreviewText(
                                    text: task.description!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                                if (task.dueDate != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Vencimento: ${_formatDate(task.dueDate!)}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ],
                            ),
                            secondary: _priorityIcon(task.priority),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddTaskModal(ProjectEntry project) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    String priority = 'normal';
    DateTime? dueDate;

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Nova Tarefa no Projeto',
      titleLeading: const Icon(Icons.add_task, color: AppTheme.primaryBlue),
      builder: (ctx, scroll) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SingleChildScrollView(
              controller: scroll,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'O que precisa ser feito?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tagsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tags (separadas por vírgula)',
                      hintText: 'Ex: pregação, pioneiro, visita',
                      prefixIcon: Icon(Icons.tag, size: 18),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  RichMarkdownToolbar(controller: descCtrl),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Descrição ou detalhes (Markdown)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: 'Prioridade', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Baixa')),
                      DropdownMenuItem(value: 'normal', child: Text('Normal')),
                      DropdownMenuItem(value: 'high', child: Text('Alta')),
                      DropdownMenuItem(value: 'urgent', child: Text('Urgente')),
                    ],
                    onChanged: (v) => setModalState(() => priority = v ?? 'normal'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: Text(dueDate == null ? 'Definir Data de Vencimento' : 'Vencimento: ${_formatDate(dueDate!)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setModalState(() => dueDate = picked);
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) return;
                      final rawTags = tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
                      final taskMgr = ref.read(taskManagerProvider);
                      await taskMgr.createTask(
                        title: title,
                        description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                        projectId: project.id,
                        category: project.category,
                        priority: priority,
                        dueDate: dueDate,
                        tags: rawTags,
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    child: const Text('Adicionar Tarefa', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleMenuAction(String action, ProjectEntry project) async {
    final projectMgr = ref.read(projectManagerProvider);
    if (action == 'edit') {
      _showEditProjectModal(project);
    } else if (action == 'complete') {
      await projectMgr.updateProjectStatus(project.id, 'completed');
    } else if (action == 'delete') {
      await projectMgr.softDeleteProject(project.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _showEditProjectModal(ProjectEntry project) {
    final nameCtrl = TextEditingController(text: project.name);
    final objCtrl = TextEditingController(text: project.objective ?? '');
    List<String> existingTags = [];
    try {
      final meta = jsonDecode(project.metadata) as Map<String, dynamic>;
      if (meta['tags'] is List) {
        existingTags = (meta['tags'] as List).map((e) => e.toString()).toList();
      }
    } catch (_) {}
    final tagsCtrl = TextEditingController(text: existingTags.join(', '));
    String category = project.category;
    DateTime? targetDate = project.targetDate;

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Editar Projeto',
      titleLeading: const Icon(Icons.edit_note, color: Color(0xFF3B82F6)),
      builder: (ctx, scroll) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SingleChildScrollView(
              controller: scroll,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nome do Projeto', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tagsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tags (separadas por vírgula)',
                      hintText: 'Ex: pregação, pioneiro, reforma',
                      prefixIcon: Icon(Icons.tag, size: 18),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  RichMarkdownToolbar(controller: objCtrl),
                  const SizedBox(height: 6),
                  TextField(
                    controller: objCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Objetivo Principal (Markdown)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: ['ministry', 'personal', 'study'].contains(category) ? category : 'ministry',
                    decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'ministry', child: Text('Ministério')),
                      DropdownMenuItem(value: 'personal', child: Text('Pessoal')),
                      DropdownMenuItem(value: 'study', child: Text('Estudo')),
                    ],
                    onChanged: (v) => setModalState(() => category = v ?? 'ministry'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: Text(targetDate == null ? 'Definir Prazo / Meta (Opcional)' : 'Meta: ${_formatDate(targetDate!)}'),
                    trailing: targetDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setModalState(() => targetDate = null),
                          )
                        : const Icon(Icons.flag_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: targetDate ?? DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (picked != null) setModalState(() => targetDate = picked);
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final rawTags = tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
                      final projMgr = ref.read(projectManagerProvider);
                      await projMgr.updateProject(
                        project.id,
                        name: name,
                        objective: objCtrl.text.trim().isNotEmpty ? objCtrl.text.trim() : null,
                        category: category,
                        targetDate: targetDate,
                        tags: rawTags,
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    child: const Text('Salvar Alterações', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _priorityIcon(String priority) {
    switch (priority) {
      case 'urgent':
        return const Icon(Icons.priority_high, color: Colors.redAccent, size: 20);
      case 'high':
        return const Icon(Icons.arrow_upward, color: Colors.amber, size: 20);
      case 'low':
        return const Icon(Icons.arrow_downward, color: Colors.grey, size: 20);
      default:
        return const Icon(Icons.remove, color: AppTheme.primaryBlue, size: 20);
    }
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'ministry':
        return 'Ministério';
      case 'personal':
        return 'Pessoal';
      case 'study':
        return 'Estudo';
      default:
        return cat;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'planning':
        return 'Planejamento';
      case 'active':
        return 'Em Andamento';
      case 'paused':
        return 'Pausado';
      case 'completed':
        return 'Concluído';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return const Color(0xFF10B981);
      case 'planning':
        return const Color(0xFF3B82F6);
      case 'paused':
        return const Color(0xFFF59E0B);
      case 'completed':
        return const Color(0xFF6B7280);
      default:
        return AppTheme.primaryBlue;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
