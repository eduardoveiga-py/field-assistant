import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../database/app_database.dart';
import '../../projects/project_manager.dart';
import '../../tasks/task_manager.dart';
import '../providers.dart';
import '../widgets/adaptive_ministry_sheet.dart';
import 'person_detail_screen.dart';
import 'project_detail_screen.dart';

/// Tela unificada do Módulo B — Tarefas e Projetos do Field Assistant.
/// Centraliza tarefas ministeriais, projetos pessoais/teocráticos, prazos e ações rápidas.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.task_alt_rounded, color: AppTheme.primaryBlue, size: 24),
            SizedBox(width: 8),
            Text('Tarefas & Projetos', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          indicatorColor: AppTheme.primaryBlue,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: '⚡ Hoje & Urgentes'),
            Tab(text: '📋 Minhas Tarefas'),
            Tab(text: '📁 Projetos'),
            Tab(text: '👥 Ações de Contatos'),
            Tab(text: '✅ Concluídas'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTaskOrProjectMenu,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTodayAndOverdueTab(isDark),
          _buildAllTasksTab(isDark),
          _buildProjectsTab(isDark),
          _buildContactActionsTab(isDark),
          _buildCompletedTasksTab(isDark),
        ],
      ),
    );
  }

  // ==========================================
  // ABA 1: HOJE & URGENTES
  // ==========================================

  Widget _buildTodayAndOverdueTab(bool isDark) {
    final taskMgr = ref.watch(taskManagerProvider);

    return StreamBuilder<List<TaskEntry>>(
      stream: taskMgr.watchTasksForToday(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final tasks = snapshot.data ?? [];
        if (tasks.isEmpty) {
          return _buildEmptyState(
            icon: Icons.done_all_rounded,
            title: 'Tudo em dia para hoje!',
            subtitle: 'Nenhuma tarefa pendente ou atrasada no momento.',
            isDark: isDark,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) => _buildTaskTile(tasks[i], taskMgr, isDark),
        );
      },
    );
  }

  // ==========================================
  // ABA 2: TODAS AS TAREFAS PENDENTES
  // ==========================================

  Widget _buildAllTasksTab(bool isDark) {
    final taskMgr = ref.watch(taskManagerProvider);

    return StreamBuilder<List<TaskEntry>>(
      stream: taskMgr.watchPendingTasks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final tasks = snapshot.data ?? [];
        if (tasks.isEmpty) {
          return _buildEmptyState(
            icon: Icons.checklist_rounded,
            title: 'Nenhuma tarefa pendente',
            subtitle: 'Toque no botão Adicionar para criar uma nova tarefa ou converta a partir da Inbox.',
            isDark: isDark,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) => _buildTaskTile(tasks[i], taskMgr, isDark),
        );
      },
    );
  }

  // ==========================================
  // ABA 3: PROJETOS ATIVOS COM % DE PROGRESSO
  // ==========================================

  Widget _buildProjectsTab(bool isDark) {
    final projectMgr = ref.watch(projectManagerProvider);

    return StreamBuilder<List<ProjectEntry>>(
      stream: projectMgr.watchActiveProjects(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final projects = snapshot.data ?? [];
        if (projects.isEmpty) {
          return _buildEmptyState(
            icon: Icons.folder_open_rounded,
            title: 'Nenhum projeto ativo',
            subtitle: 'Crie projetos para agrupar tarefas maiores, metas pessoais ou alvos teocráticos.',
            isDark: isDark,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: projects.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) => _buildProjectCard(projects[i], projectMgr, isDark),
        );
      },
    );
  }

  Widget _buildProjectCard(ProjectEntry project, ProjectManager projectMgr, bool isDark) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: project.id)),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder_special, color: AppTheme.primaryBlue, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    project.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _categoryLabel(project.category),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                  ),
                ),
              ],
            ),
            if (project.objective != null && project.objective!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                project.objective!,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 14),

            // Progresso em tempo real
            StreamBuilder<ProjectProgress>(
              stream: projectMgr.watchProjectProgress(project.id),
              builder: (ctx, progSnap) {
                final prog = progSnap.data ?? ProjectProgress.empty();
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${prog.completedTasks} de ${prog.totalTasks} tarefas',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          '${prog.progressPercent.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: prog.totalTasks > 0 ? prog.completedTasks / prog.totalTasks : 0.0,
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ABA 4: AÇÕES DE CONTATOS (REVISITAS/NOTAS)
  // ==========================================

  Widget _buildContactActionsTab(bool isDark) {
    final peopleAsync = ref.watch(peopleStreamProvider);

    return peopleAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Erro ao carregar pessoas: $e')),
      data: (people) {
        final actions = <_ContactActionRow>[];

        for (final p in people) {
          if (p.nextActionAt != null && p.nextActionNote != null && p.nextActionNote!.isNotEmpty) {
            actions.add(_ContactActionRow(
              person: p,
              note: p.nextActionNote!,
              date: p.nextActionAt!,
            ));
          }
        }

        actions.sort((a, b) => a.date.compareTo(b.date));

        if (actions.isEmpty) {
          return _buildEmptyState(
            icon: Icons.people_outline,
            title: 'Nenhuma ação de contato agendada',
            subtitle: 'Defina lembretes de revisitas ou ações de retorno nos detalhes das pessoas.',
            isDark: isDark,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: actions.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final item = actions[i];
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
                  child: Text(
                    item.person.name.isNotEmpty ? item.person.name[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                  ),
                ),
                title: Text(item.person.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${item.note}\nData: ${_formatDate(item.date)}'),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PersonDetailScreen(personId: item.person.id)),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // ABA 5: TAREFAS CONCLUÍDAS
  // ==========================================

  Widget _buildCompletedTasksTab(bool isDark) {
    final taskMgr = ref.watch(taskManagerProvider);

    return StreamBuilder<List<TaskEntry>>(
      stream: taskMgr.watchCompletedTasks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final tasks = snapshot.data ?? [];
        if (tasks.isEmpty) {
          return _buildEmptyState(
            icon: Icons.check_circle_outline,
            title: 'Nenhuma tarefa concluída recentemente',
            subtitle: 'Conclua tarefas ativas para visualizar o histórico aqui.',
            isDark: isDark,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) => _buildTaskTile(tasks[i], taskMgr, isDark),
        );
      },
    );
  }

  // ==========================================
  // COMPONENTES AUXILIARES
  // ==========================================

  Widget _buildTaskTile(TaskEntry task, TaskManager taskMgr, bool isDark) {
    final isOverdue = task.dueDate != null &&
        task.dueDate!.isBefore(DateTime.now().subtract(const Duration(hours: 1))) &&
        !task.isCompleted;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue
              ? Colors.redAccent.withValues(alpha: 0.5)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: CheckboxListTile(
        value: task.isCompleted,
        activeColor: AppTheme.primaryBlue,
        onChanged: (val) => taskMgr.toggleTaskComplete(task.id, completed: val),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.w600,
            color: task.isCompleted ? Colors.grey : null,
          ),
        ),
        subtitle: Row(
          children: [
            if (task.dueDate != null) ...[
              Icon(
                Icons.calendar_today,
                size: 12,
                color: isOverdue ? Colors.redAccent : Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                _formatDate(task.dueDate!),
                style: TextStyle(
                  fontSize: 11,
                  color: isOverdue ? Colors.redAccent : Colors.grey,
                  fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (task.recurrenceRule != null && task.recurrenceRule != 'none' && task.recurrenceRule!.isNotEmpty) ...[
              const Icon(Icons.repeat, size: 12, color: AppTheme.primaryBlue),
              const SizedBox(width: 2),
              Text(
                task.recurrenceRule!,
                style: const TextStyle(fontSize: 11, color: AppTheme.primaryBlue),
              ),
            ],
          ],
        ),
        secondary: _priorityIcon(task.priority),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateTaskOrProjectMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF10B981),
                  child: Icon(Icons.check, color: Colors.white),
                ),
                title: const Text('Nova Tarefa', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Criar uma tarefa avulsa ou ministerial'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showCreateTaskModal();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF3B82F6),
                  child: Icon(Icons.folder, color: Colors.white),
                ),
                title: const Text('Novo Projeto', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Criar um projeto para agrupar tarefas e notas'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showCreateProjectModal();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateTaskModal() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String priority = 'normal';
    String category = 'ministry';
    String recurrence = 'none';
    DateTime? dueDate;

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Nova Tarefa',
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
                    decoration: const InputDecoration(labelText: 'O que precisa ser feito?', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Descrição ou detalhes (opcional)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
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
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: recurrence,
                          decoration: const InputDecoration(labelText: 'Recorrência', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'none', child: Text('Nenhuma')),
                            DropdownMenuItem(value: 'daily', child: Text('Diária')),
                            DropdownMenuItem(value: 'weekly', child: Text('Semanal')),
                            DropdownMenuItem(value: 'monthly', child: Text('Mensal')),
                          ],
                          onChanged: (v) => setModalState(() => recurrence = v ?? 'none'),
                        ),
                      ),
                    ],
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
                        description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                        priority: priority,
                        category: category,
                        recurrenceRule: recurrence,
                        dueDate: dueDate,
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    child: const Text('Criar Tarefa', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCreateProjectModal() {
    final nameCtrl = TextEditingController();
    final objCtrl = TextEditingController();
    String category = 'ministry';
    DateTime? targetDate;

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Novo Projeto',
      titleLeading: const Icon(Icons.folder_special, color: Color(0xFF3B82F6)),
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
                    controller: nameCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Nome do Projeto', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: objCtrl,
                    decoration: const InputDecoration(labelText: 'Objetivo Principal', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
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
                    title: Text(targetDate == null ? 'Definir Data Alvo / Meta' : 'Meta: ${_formatDate(targetDate!)}'),
                    trailing: const Icon(Icons.flag_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 30)),
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
                      final projMgr = ref.read(projectManagerProvider);
                      await projMgr.createProject(
                        name: name,
                        objective: objCtrl.text.trim().isNotEmpty ? objCtrl.text.trim() : null,
                        category: category,
                        targetDate: targetDate,
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    child: const Text('Criar Projeto', style: TextStyle(fontWeight: FontWeight.bold)),
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

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }
}

class _ContactActionRow {
  final PersonEntry person;
  final String note;
  final DateTime date;

  _ContactActionRow({required this.person, required this.note, required this.date});
}
