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
import '../widgets/universal_attachment_viewer.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'todas';
  String _selectedPriority = 'todas';
  String? _selectedTag;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _searchController.addListener(() {
      final text = _searchController.text.trim();
      if (_searchQuery != text && mounted) {
        setState(() => _searchQuery = text);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<String> _extractTags(String metadataJson) {
    try {
      if (metadataJson.isNotEmpty) {
        final decoded = jsonDecode(metadataJson);
        if (decoded is Map && decoded['tags'] is List) {
          return List<String>.from(decoded['tags'].map((e) => e.toString()));
        }
      }
    } catch (_) {}
    return [];
  }

  List<Map<String, dynamic>> _extractAttachments(String attachmentsJson) {
    try {
      if (attachmentsJson.isNotEmpty) {
        final decoded = jsonDecode(attachmentsJson);
        if (decoded is List) {
          return List<Map<String, dynamic>>.from(decoded.whereType<Map>());
        }
      }
    } catch (_) {}
    return [];
  }

  List<TaskEntry> _filterTasks(List<TaskEntry> raw) {
    return raw.where((t) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final titleMatch = t.title.toLowerCase().contains(q);
        final descMatch = (t.description ?? '').toLowerCase().contains(q);
        final catMatch = t.category.toLowerCase().contains(q);
        final tags = _extractTags(t.metadata);
        final tagMatch = tags.any((tag) => tag.toLowerCase().contains(q));
        if (!titleMatch && !descMatch && !catMatch && !tagMatch) return false;
      }
      if (_selectedCategory != 'todas' && t.category != _selectedCategory) {
        return false;
      }
      if (_selectedPriority != 'todas' && t.priority != _selectedPriority) {
        return false;
      }
      if (_selectedTag != null && _selectedTag!.isNotEmpty) {
        final tags = _extractTags(t.metadata);
        if (!tags.contains(_selectedTag)) return false;
      }
      return true;
    }).toList();
  }

  List<ProjectEntry> _filterProjects(List<ProjectEntry> raw) {
    return raw.where((p) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatch = p.name.toLowerCase().contains(q);
        final objMatch = (p.objective ?? '').toLowerCase().contains(q);
        final descMatch = (p.description ?? '').toLowerCase().contains(q);
        final catMatch = p.category.toLowerCase().contains(q);
        final tags = _extractTags(p.metadata);
        final tagMatch = tags.any((tag) => tag.toLowerCase().contains(q));
        if (!nameMatch && !objMatch && !descMatch && !catMatch && !tagMatch) return false;
      }
      if (_selectedCategory != 'todas' && p.category != _selectedCategory) {
        return false;
      }
      if (_selectedTag != null && _selectedTag!.isNotEmpty) {
        final tags = _extractTags(p.metadata);
        if (!tags.contains(_selectedTag)) return false;
      }
      return true;
    }).toList();
  }

  Widget _buildSearchAndFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Pesquisar tarefas, projetos, tags...',
              prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.primaryBlue),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Filtro Categoria
                FilterChip(
                  label: Text(_selectedCategory == 'todas' ? 'Todas Categorias' : _categoryLabel(_selectedCategory)),
                  selected: _selectedCategory != 'todas',
                  onSelected: (_) {
                    _showCategoryFilterMenu();
                  },
                ),
                const SizedBox(width: 8),
                // Filtro Prioridade
                FilterChip(
                  label: Text(_selectedPriority == 'todas' ? 'Todas Prioridades' : _priorityLabel(_selectedPriority)),
                  selected: _selectedPriority != 'todas',
                  onSelected: (_) {
                    _showPriorityFilterMenu();
                  },
                ),
                if (_selectedTag != null) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('#$_selectedTag'),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => setState(() => _selectedTag = null),
                  ),
                ],
                if (_selectedCategory != 'todas' || _selectedPriority != 'todas' || _selectedTag != null) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.filter_alt_off, size: 16),
                    label: const Text('Limpar', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      setState(() {
                        _selectedCategory = 'todas';
                        _selectedPriority = 'todas';
                        _selectedTag = null;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryFilterMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Filtrar por Categoria', style: TextStyle(fontWeight: FontWeight.bold))),
            const Divider(height: 1),
            ListTile(
              title: const Text('Todas as categorias'),
              trailing: _selectedCategory == 'todas' ? const Icon(Icons.check, color: AppTheme.primaryBlue) : null,
              onTap: () {
                setState(() => _selectedCategory = 'todas');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('Ministério'),
              trailing: _selectedCategory == 'ministry' ? const Icon(Icons.check, color: AppTheme.primaryBlue) : null,
              onTap: () {
                setState(() => _selectedCategory = 'ministry');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('Pessoal'),
              trailing: _selectedCategory == 'personal' ? const Icon(Icons.check, color: AppTheme.primaryBlue) : null,
              onTap: () {
                setState(() => _selectedCategory = 'personal');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('Estudo'),
              trailing: _selectedCategory == 'study' ? const Icon(Icons.check, color: AppTheme.primaryBlue) : null,
              onTap: () {
                setState(() => _selectedCategory = 'study');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('Tecnologia'),
              trailing: _selectedCategory == 'tech' ? const Icon(Icons.check, color: AppTheme.primaryBlue) : null,
              onTap: () {
                setState(() => _selectedCategory = 'tech');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPriorityFilterMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Filtrar por Prioridade', style: TextStyle(fontWeight: FontWeight.bold))),
            const Divider(height: 1),
            ListTile(
              title: const Text('Todas as prioridades'),
              trailing: _selectedPriority == 'todas' ? const Icon(Icons.check, color: AppTheme.primaryBlue) : null,
              onTap: () {
                setState(() => _selectedPriority = 'todas');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('Urgente'),
              leading: const Icon(Icons.error_outline, color: Colors.redAccent),
              trailing: _selectedPriority == 'urgent' ? const Icon(Icons.check, color: AppTheme.primaryBlue) : null,
              onTap: () {
                setState(() => _selectedPriority = 'urgent');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('Alta'),
              leading: const Icon(Icons.arrow_upward, color: Colors.orange),
              trailing: _selectedPriority == 'high' ? const Icon(Icons.check, color: AppTheme.primaryBlue) : null,
              onTap: () {
                setState(() => _selectedPriority = 'high');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('Normal'),
              leading: const Icon(Icons.remove, color: AppTheme.primaryBlue),
              trailing: _selectedPriority == 'normal' ? const Icon(Icons.check, color: AppTheme.primaryBlue) : null,
              onTap: () {
                setState(() => _selectedPriority = 'normal');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('Baixa'),
              leading: const Icon(Icons.arrow_downward, color: Colors.grey),
              trailing: _selectedPriority == 'low' ? const Icon(Icons.check, color: AppTheme.primaryBlue) : null,
              onTap: () {
                setState(() => _selectedPriority = 'low');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _priorityLabel(String prio) {
    switch (prio) {
      case 'urgent': return 'Urgente';
      case 'high': return 'Alta';
      case 'normal': return 'Normal';
      case 'low': return 'Baixa';
      default: return prio;
    }
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
      floatingActionButton: _buildTabAwareFab(),
      body: Column(
        children: [
          _buildSearchAndFilterBar(isDark),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTodayAndOverdueTab(isDark),
                _buildAllTasksTab(isDark),
                _buildProjectsTab(isDark),
                _buildContactActionsTab(isDark),
                _buildCompletedTasksTab(isDark),
              ],
            ),
          ),
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

        final rawTasks = snapshot.data ?? [];
        final tasks = _filterTasks(rawTasks);
        if (tasks.isEmpty) {
          return _buildEmptyState(
            icon: Icons.done_all_rounded,
            title: rawTasks.isEmpty ? 'Tudo em dia para hoje!' : 'Nenhuma tarefa corresponde aos filtros',
            subtitle: rawTasks.isEmpty
                ? 'Nenhuma tarefa pendente ou atrasada no momento.'
                : 'Ajuste os filtros ou a pesquisa para ver mais itens.',
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

        final rawTasks = snapshot.data ?? [];
        final tasks = _filterTasks(rawTasks);
        if (tasks.isEmpty) {
          return _buildEmptyState(
            icon: Icons.checklist_rounded,
            title: rawTasks.isEmpty ? 'Nenhuma tarefa pendente' : 'Nenhuma tarefa corresponde aos filtros',
            subtitle: rawTasks.isEmpty
                ? 'Toque no botão Adicionar para criar uma nova tarefa ou converta a partir da Inbox.'
                : 'Ajuste os filtros ou a pesquisa para ver mais itens.',
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

        final rawProjects = snapshot.data ?? [];
        final projects = _filterProjects(rawProjects);
        if (projects.isEmpty) {
          return _buildEmptyState(
            icon: Icons.folder_open_rounded,
            title: rawProjects.isEmpty ? 'Nenhum projeto ativo' : 'Nenhum projeto corresponde aos filtros',
            subtitle: rawProjects.isEmpty
                ? 'Crie projetos para agrupar tarefas maiores, metas pessoais ou alvos teocráticos.'
                : 'Ajuste os filtros ou a pesquisa para ver mais itens.',
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
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (val) {
                    if (val == 'edit') _showEditProjectModal(project);
                    if (val == 'delete') _confirmDeleteProject(project);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar Projeto')),
                    const PopupMenuItem(value: 'delete', child: Text('Excluir Projeto', style: TextStyle(color: Colors.redAccent))),
                  ],
                ),
              ],
            ),
            if (project.targetDate != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.flag_outlined, size: 13, color: AppTheme.primaryBlue),
                  const SizedBox(width: 4),
                  Text(
                    'Prazo / Meta: ${_formatDate(project.targetDate!)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                  ),
                ],
              ),
            ],
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
            // Tags do Projeto
            Builder(
              builder: (ctx) {
                final pTags = _extractTags(project.metadata);
                if (pTags.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: pTags.map((t) => InkWell(
                      onTap: () => setState(() => _selectedTag = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#$t',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                        ),
                      ),
                    )).toList(),
                  ),
                );
              },
            ),
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

        final rawTasks = snapshot.data ?? [];
        final tasks = _filterTasks(rawTasks);
        if (tasks.isEmpty) {
          return _buildEmptyState(
            icon: Icons.check_circle_outline,
            title: rawTasks.isEmpty ? 'Nenhuma tarefa concluída recentemente' : 'Nenhuma tarefa corresponde aos filtros',
            subtitle: rawTasks.isEmpty
                ? 'Conclua tarefas ativas para visualizar o histórico aqui.'
                : 'Ajuste os filtros ou a pesquisa para ver mais itens.',
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
    final tags = _extractTags(task.metadata);
    final attachments = _extractAttachments(task.attachments);

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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        leading: Checkbox(
          value: task.isCompleted,
          activeColor: AppTheme.primaryBlue,
          onChanged: (val) => taskMgr.toggleTaskComplete(task.id, completed: val),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.w600,
            color: task.isCompleted ? Colors.grey : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Descrição da Tarefa — corrigido para exibir na listagem
            if (task.description != null && task.description!.isNotEmpty) ...[
              const SizedBox(height: 3),
              MarkdownPreviewText(
                text: task.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                _priorityIcon(task.priority),
                const SizedBox(width: 6),
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
                if (task.recurrenceRule != null &&
                    task.recurrenceRule != 'none' &&
                    task.recurrenceRule!.isNotEmpty) ...[
                  const Icon(Icons.repeat, size: 12, color: AppTheme.primaryBlue),
                  const SizedBox(width: 2),
                  Text(
                    task.recurrenceRule!,
                    style: const TextStyle(fontSize: 11, color: AppTheme.primaryBlue),
                  ),
                ],
              ],
            ),
            if (tags.isNotEmpty || attachments.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final t in tags)
                    InkWell(
                      onTap: () => setState(() => _selectedTag = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#$t',
                          style: const TextStyle(fontSize: 11, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  for (final att in attachments)
                    InkWell(
                      onTap: () {
                        final path = att['path'] as String? ?? '';
                        final name = att['name'] as String? ?? 'Anexo';
                        final type = att['type'] as String? ?? 'file';
                        showUniversalAttachmentViewer(context, filePath: path, title: name, fileType: type);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.attach_file, size: 12, color: Colors.purple),
                            const SizedBox(width: 2),
                            Text(
                              att['name'] ?? 'Anexo',
                              style: const TextStyle(fontSize: 11, color: Colors.purple),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          onSelected: (val) {
            if (val == 'edit') _showEditTaskModal(task);
            if (val == 'delete') _confirmDeleteTask(task);
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar Tarefa')),
            const PopupMenuItem(value: 'delete', child: Text('Excluir Tarefa', style: TextStyle(color: Colors.redAccent))),
          ],
        ),
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



  void _showCreateTaskModal() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
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
                    decoration: const InputDecoration(labelText: 'O que precisa ser feito?', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  RichMarkdownToolbar(controller: descCtrl),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Descrição ou detalhes (Markdown e imagens)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tagsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tags (separadas por vírgula)',
                      hintText: 'ex: ministério, revisita, prioridade',
                      prefixIcon: Icon(Icons.tag, size: 18),
                      border: OutlineInputBorder(),
                    ),
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
                    title: Text(dueDate == null ? 'Definir Prazo / Vencimento (Opcional)' : 'Vencimento: ${_formatDate(dueDate!)}'),
                    trailing: dueDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setModalState(() => dueDate = null),
                          )
                        : const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate ?? DateTime.now(),
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
                      final tags = tagsCtrl.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList();
                      await taskMgr.createTask(
                        title: title,
                        description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                        priority: priority,
                        category: category,
                        recurrenceRule: recurrence,
                        dueDate: dueDate,
                        tags: tags,
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

  void _showEditTaskModal(TaskEntry task) {
    final titleCtrl = TextEditingController(text: task.title);
    final descCtrl = TextEditingController(text: task.description ?? '');
    final initialTags = _extractTags(task.metadata);
    final tagsCtrl = TextEditingController(text: initialTags.join(', '));
    String priority = task.priority;
    String category = task.category;
    String recurrence = task.recurrenceRule ?? 'none';
    DateTime? dueDate = task.dueDate;

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Editar Tarefa',
      titleLeading: const Icon(Icons.edit_note, color: AppTheme.primaryBlue),
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
                    decoration: const InputDecoration(labelText: 'O que precisa ser feito?', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  RichMarkdownToolbar(controller: descCtrl),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Descrição ou detalhes (Markdown e imagens)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tagsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tags (separadas por vírgula)',
                      prefixIcon: Icon(Icons.tag, size: 18),
                      border: OutlineInputBorder(),
                    ),
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
                          initialValue: ['none', 'daily', 'weekly', 'monthly'].contains(recurrence) ? recurrence : 'none',
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
                    title: Text(dueDate == null ? 'Definir Prazo / Vencimento (Opcional)' : 'Vencimento: ${_formatDate(dueDate!)}'),
                    trailing: dueDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setModalState(() => dueDate = null),
                          )
                        : const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate ?? DateTime.now(),
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
                      final tags = tagsCtrl.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList();
                      await taskMgr.updateTask(
                        task.id,
                        title: title,
                        description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                        priority: priority,
                        category: category,
                        recurrenceRule: recurrence,
                        dueDate: dueDate,
                        tags: tags,
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

  void _confirmDeleteTask(TaskEntry task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Tarefa'),
        content: Text('Tem certeza que deseja excluir "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              final taskMgr = ref.read(taskManagerProvider);
              await taskMgr.softDeleteTask(task.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void _showCreateProjectModal() {
    final nameCtrl = TextEditingController();
    final objCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    String category = 'ministry';
    DateTime? targetDate;

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Novo Projeto',
      titleLeading: const Icon(Icons.folder_special, color: Color(0xFF3B82F6)),
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
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Nome do Projeto', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  RichMarkdownToolbar(controller: objCtrl),
                  const SizedBox(height: 6),
                  TextField(
                    controller: objCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Objetivo Principal (Markdown e imagens)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tagsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tags (separadas por vírgula)',
                      hintText: 'ex: pioneiro, alvo, congregação',
                      prefixIcon: Icon(Icons.tag, size: 18),
                      border: OutlineInputBorder(),
                    ),
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
                      final projMgr = ref.read(projectManagerProvider);
                      final tags = tagsCtrl.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList();
                      await projMgr.createProject(
                        name: name,
                        objective: objCtrl.text.trim().isNotEmpty ? objCtrl.text.trim() : null,
                        category: category,
                        targetDate: targetDate,
                        tags: tags,
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

  void _showEditProjectModal(ProjectEntry project) {
    final nameCtrl = TextEditingController(text: project.name);
    final objCtrl = TextEditingController(text: project.objective ?? '');
    final initialTags = _extractTags(project.metadata);
    final tagsCtrl = TextEditingController(text: initialTags.join(', '));
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
                  RichMarkdownToolbar(controller: objCtrl),
                  const SizedBox(height: 6),
                  TextField(
                    controller: objCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Objetivo Principal (Markdown e imagens)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tagsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tags (separadas por vírgula)',
                      prefixIcon: Icon(Icons.tag, size: 18),
                      border: OutlineInputBorder(),
                    ),
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
                      final projMgr = ref.read(projectManagerProvider);
                      final tags = tagsCtrl.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList();
                      await projMgr.updateProject(
                        project.id,
                        name: name,
                        objective: objCtrl.text.trim().isNotEmpty ? objCtrl.text.trim() : null,
                        category: category,
                        targetDate: targetDate,
                        tags: tags,
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

  void _confirmDeleteProject(ProjectEntry project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Projeto'),
        content: Text('Tem certeza que deseja excluir "${project.name}"? As tarefas vinculadas serão preservadas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              final projMgr = ref.read(projectManagerProvider);
              await projMgr.softDeleteProject(project.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabAwareFab() {
    if (_tabController.index == 2) {
      return FloatingActionButton.extended(
        heroTag: 'fab_tasks_proj',
        onPressed: _showCreateProjectModal,
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.create_new_folder),
        label: const Text('Novo Projeto', style: TextStyle(fontWeight: FontWeight.bold)),
      );
    }
    return FloatingActionButton.extended(
      heroTag: 'fab_tasks_task',
      onPressed: _showCreateTaskModal,
      backgroundColor: AppTheme.primaryBlue,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add_task),
      label: const Text('Nova Tarefa', style: TextStyle(fontWeight: FontWeight.bold)),
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
