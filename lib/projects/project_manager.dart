import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

/// Estatísticas de progresso e execução de um projeto
class ProjectProgress {
  final int totalTasks;
  final int completedTasks;
  final double progressPercent;

  const ProjectProgress({
    required this.totalTasks,
    required this.completedTasks,
    required this.progressPercent,
  });

  factory ProjectProgress.empty() => const ProjectProgress(
        totalTasks: 0,
        completedTasks: 0,
        progressPercent: 0.0,
      );
}

/// Gerenciador do Módulo B — Projetos do Field Assistant.
/// Permite agrupar tarefas, notas, documentos e dúvidas teocráticas/pessoais
/// com metas claras e cálculo automático de progresso.
class ProjectManager {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();

  ProjectManager({required this.db});

  // ==========================================
  // CRIAÇÃO E EDIÇÃO DE PROJETOS
  // ==========================================

  Future<ProjectEntry> createProject({
    required String name,
    String? objective,
    String? description,
    String category = 'ministry',
    String status = 'planning',
    String? colorHex,
    String? iconName,
    String? originInboxId,
    DateTime? targetDate,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    final companion = ProjectsCompanion.insert(
      id: id,
      name: name.trim(),
      objective: drift.Value(objective?.trim()),
      description: drift.Value(description?.trim()),
      category: drift.Value(category),
      status: drift.Value(status),
      colorHex: drift.Value(colorHex ?? '#2563EB'),
      iconName: drift.Value(iconName ?? 'folder'),
      originInboxId: drift.Value(originInboxId),
      targetDate: drift.Value(targetDate),
      createdAt: now,
      updatedAt: now,
    );

    await db.into(db.projects).insert(companion);
    await _recordSyncQueue(id, 'INSERT');

    return (await (db.select(db.projects)..where((t) => t.id.equals(id))).getSingle());
  }

  Future<void> updateProject(
    String id, {
    String? name,
    String? objective,
    String? description,
    String? category,
    String? status,
    String? colorHex,
    String? iconName,
    DateTime? targetDate,
  }) async {
    final now = DateTime.now();
    final companion = ProjectsCompanion(
      name: name != null ? drift.Value(name.trim()) : const drift.Value.absent(),
      objective: objective != null ? drift.Value(objective.trim()) : const drift.Value.absent(),
      description: description != null ? drift.Value(description.trim()) : const drift.Value.absent(),
      category: category != null ? drift.Value(category) : const drift.Value.absent(),
      status: status != null ? drift.Value(status) : const drift.Value.absent(),
      colorHex: colorHex != null ? drift.Value(colorHex) : const drift.Value.absent(),
      iconName: iconName != null ? drift.Value(iconName) : const drift.Value.absent(),
      targetDate: targetDate != null ? drift.Value(targetDate) : const drift.Value.absent(),
      updatedAt: drift.Value(now),
    );

    await (db.update(db.projects)..where((t) => t.id.equals(id))).write(companion);
    await _recordSyncQueue(id, 'UPDATE');
  }

  Future<void> updateProjectStatus(String id, String status) async {
    final now = DateTime.now();
    await (db.update(db.projects)..where((t) => t.id.equals(id))).write(
      ProjectsCompanion(
        status: drift.Value(status),
        updatedAt: drift.Value(now),
      ),
    );
    await _recordSyncQueue(id, 'UPDATE');
  }

  Future<void> softDeleteProject(String id) async {
    final now = DateTime.now();
    await (db.update(db.projects)..where((t) => t.id.equals(id))).write(
      ProjectsCompanion(
        deletedAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
    await _recordSyncQueue(id, 'DELETE');
  }

  // ==========================================
  // CONSULTAS REATIVAS (STREAMS)
  // ==========================================

  Stream<List<ProjectEntry>> watchActiveProjects() {
    return (db.select(db.projects)
          ..where((t) =>
              t.status.isIn(['planning', 'active']) & t.deletedAt.isNull())
          ..orderBy([
            (t) => drift.OrderingTerm(expression: t.targetDate, mode: drift.OrderingMode.asc, nulls: drift.NullsOrder.last),
            (t) => drift.OrderingTerm(expression: t.createdAt, mode: drift.OrderingMode.desc),
          ]))
        .watch();
  }

  Stream<List<ProjectEntry>> watchAllProjects({String? category, String? status}) {
    final q = db.select(db.projects)
      ..where((t) => t.deletedAt.isNull());

    if (category != null && category.isNotEmpty && category != 'all') {
      q.where((t) => t.category.equals(category));
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      q.where((t) => t.status.equals(status));
    }

    q.orderBy([
      (t) => drift.OrderingTerm(expression: t.targetDate, mode: drift.OrderingMode.asc, nulls: drift.NullsOrder.last),
      (t) => drift.OrderingTerm(expression: t.createdAt, mode: drift.OrderingMode.desc),
    ]);

    return q.watch();
  }

  Stream<ProjectEntry?> watchProject(String id) {
    return (db.select(db.projects)..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  Future<ProjectEntry?> getProjectById(String id) {
    return (db.select(db.projects)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Observa o progresso percentual e contagem de tarefas de um projeto
  Stream<ProjectProgress> watchProjectProgress(String projectId) {
    return (db.select(db.tasks)
          ..where((t) => t.projectId.equals(projectId) & t.deletedAt.isNull()))
        .watch()
        .map((tasks) {
      if (tasks.isEmpty) return ProjectProgress.empty();
      final total = tasks.length;
      final completed = tasks.where((t) => t.status == "completed").length;
      final percent = (completed / total) * 100.0;
      return ProjectProgress(
        totalTasks: total,
        completedTasks: completed,
        progressPercent: percent,
      );
    });
  }

  Future<void> _recordSyncQueue(String entityId, String operation) async {
    try {
      final now = DateTime.now();
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'projects',
          entityId: entityId,
          operation: operation,
          payload: jsonEncode({'id': entityId, 'created_at': now.toIso8601String()}),
          createdAt: now,
        ),
      );
    } catch (_) {}
  }
}
