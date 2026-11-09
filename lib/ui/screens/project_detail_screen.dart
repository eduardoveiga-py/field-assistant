import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../database/app_database.dart';
import '../../projects/project_manager.dart';
import '../providers.dart';
import '../widgets/adaptive_ministry_sheet.dart';

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
                            value: task.status == "completed",
                            activeColor: AppTheme.primaryBlue,
                            onChanged: (val) => taskMgr.toggleTaskComplete(task.id, completed: val),
                            title: Text(
                              task.title,
                              style: TextStyle(
                                decoration: task.status == "completed" ? TextDecoration.lineThrough : null,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: task.dueDate != null
                                ? Text(
                                    'Vencimento: ${_formatDate(task.dueDate!)}',
                                    style: const TextStyle(fontSize: 11),
                                  )
                                : null,
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
    String priority = 'normal';
    DateTime? dueDate;

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Nova Tarefa no Projeto',
      titleLeading: const Icon(Icons.add_task, color: AppTheme.primaryBlue),
      builder: (ctx, scroll) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
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
                      final taskMgr = ref.read(taskManagerProvider);
                      await taskMgr.createTask(
                        title: title,
                        projectId: project.id,
                        category: project.category,
                        priority: priority,
                        dueDate: dueDate,
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
    if (action == 'complete') {
      await projectMgr.updateProjectStatus(project.id, 'completed');
    } else if (action == 'delete') {
      await projectMgr.softDeleteProject(project.id);
      if (mounted) Navigator.of(context).pop();
    }
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
