import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

extension TaskEntryExtension on TaskEntry {
  bool get isCompleted => status == 'completed';
}

/// Gerenciador do Módulo B — Tarefas do Field Assistant.
/// Sistema integrado offline-first para planejar, acompanhar e executar
/// responsabilidades ministeriais, pessoais e teocráticas com suporte a recorrência.
class TaskManager {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();

  TaskManager({required this.db});

  // ==========================================
  // CRIAÇÃO E EDIÇÃO DE TAREFAS
  // ==========================================

  Future<TaskEntry> createTask({
    required String title,
    String? description,
    String priority = 'normal',
    String category = 'ministry',
    String? projectId,
    String? personId,
    String? studyId,
    String? sectorId,
    String? originInboxId,
    DateTime? dueDate,
    DateTime? scheduledAt,
    String recurrenceRule = 'none',
    int durationMinutes = 15,
    List<String> tags = const [],
    List<Map<String, dynamic>>? attachments,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final isRec = recurrenceRule != 'none' && recurrenceRule.isNotEmpty;

    final companion = TasksCompanion.insert(
      id: id,
      title: title.trim(),
      description: drift.Value(description?.trim()),
      priority: drift.Value(priority),
      category: drift.Value(category),
      status: const drift.Value('todo'),
      projectId: drift.Value(projectId),
      personId: drift.Value(personId),
      studyId: drift.Value(studyId),
      sectorId: drift.Value(sectorId),
      originInboxId: drift.Value(originInboxId),
      dueDate: drift.Value(dueDate),
      scheduledAt: drift.Value(scheduledAt),
      durationMinutes: drift.Value(durationMinutes),
      isRecurring: drift.Value(isRec),
      recurrenceRule: drift.Value(recurrenceRule),
      attachments: drift.Value(attachments != null ? jsonEncode(attachments) : '[]'),
      metadata: drift.Value(jsonEncode({'tags': tags})),
      createdAt: now,
      updatedAt: now,
    );

    await db.into(db.tasks).insert(companion);
    await _recordSyncQueue(id, 'INSERT');

    return (await (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle());
  }

  Future<void> updateTask(
    String id, {
    String? title,
    String? description,
    String? priority,
    String? category,
    String? status,
    String? projectId,
    String? personId,
    String? studyId,
    String? sectorId,
    DateTime? dueDate,
    DateTime? scheduledAt,
    String? recurrenceRule,
    int? durationMinutes,
  }) async {
    final now = DateTime.now();
    final companion = TasksCompanion(
      title: title != null ? drift.Value(title.trim()) : const drift.Value.absent(),
      description: description != null ? drift.Value(description.trim()) : const drift.Value.absent(),
      priority: priority != null ? drift.Value(priority) : const drift.Value.absent(),
      category: category != null ? drift.Value(category) : const drift.Value.absent(),
      status: status != null ? drift.Value(status) : const drift.Value.absent(),
      projectId: projectId != null ? drift.Value(projectId) : const drift.Value.absent(),
      personId: personId != null ? drift.Value(personId) : const drift.Value.absent(),
      studyId: studyId != null ? drift.Value(studyId) : const drift.Value.absent(),
      sectorId: sectorId != null ? drift.Value(sectorId) : const drift.Value.absent(),
      dueDate: dueDate != null ? drift.Value(dueDate) : const drift.Value.absent(),
      scheduledAt: scheduledAt != null ? drift.Value(scheduledAt) : const drift.Value.absent(),
      recurrenceRule: recurrenceRule != null ? drift.Value(recurrenceRule) : const drift.Value.absent(),
      durationMinutes: durationMinutes != null ? drift.Value(durationMinutes) : const drift.Value.absent(),
      updatedAt: drift.Value(now),
    );

    await (db.update(db.tasks)..where((t) => t.id.equals(id))).write(companion);
    await _recordSyncQueue(id, 'UPDATE');
  }

  /// Alterna o estado de conclusão de uma tarefa.
  /// Se a tarefa for recorrente (daily, weekly, monthly) e estiver sendo concluída,
  /// cria automaticamente a próxima ocorrência para manter o fluxo contínuo.
  Future<void> toggleTaskComplete(String id, {bool? completed}) async {
    final current = await (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (current == null) return;

    final willComplete = completed ?? (current.status != 'completed');
    final now = DateTime.now();

    await (db.update(db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        status: drift.Value(willComplete ? 'completed' : 'todo'),
        completedAt: drift.Value(willComplete ? now : null),
        updatedAt: drift.Value(now),
      ),
    );
    await _recordSyncQueue(id, 'UPDATE');

    // Se completou uma tarefa com recorrência, gera a próxima tarefa automaticamente
    if (willComplete && current.recurrenceRule != null && current.recurrenceRule != 'none' && current.recurrenceRule!.isNotEmpty) {
      await _spawnNextRecurringTask(current);
    }
  }

  Future<void> _spawnNextRecurringTask(TaskEntry current) async {
    DateTime? nextDue;
    DateTime? nextScheduled;

    final baseDue = current.dueDate ?? DateTime.now();
    final rule = (current.recurrenceRule ?? 'none').toLowerCase();

    if (rule == 'daily') {
      nextDue = baseDue.add(const Duration(days: 1));
      if (current.scheduledAt != null) {
        nextScheduled = current.scheduledAt!.add(const Duration(days: 1));
      }
    } else if (rule == 'weekly') {
      nextDue = baseDue.add(const Duration(days: 7));
      if (current.scheduledAt != null) {
        nextScheduled = current.scheduledAt!.add(const Duration(days: 7));
      }
    } else if (rule == 'monthly') {
      nextDue = DateTime(baseDue.year, baseDue.month + 1, baseDue.day, baseDue.hour, baseDue.minute);
      if (current.scheduledAt != null) {
        final s = current.scheduledAt!;
        nextScheduled = DateTime(s.year, s.month + 1, s.day, s.hour, s.minute);
      }
    }

    if (nextDue != null) {
      await createTask(
        title: current.title,
        description: current.description,
        priority: current.priority,
        category: current.category,
        projectId: current.projectId,
        personId: current.personId,
        studyId: current.studyId,
        sectorId: current.sectorId,
        dueDate: nextDue,
        scheduledAt: nextScheduled,
        recurrenceRule: current.recurrenceRule ?? 'none',
        durationMinutes: current.durationMinutes ?? 15,
      );
    }
  }

  Future<void> softDeleteTask(String id) async {
    final now = DateTime.now();
    await (db.update(db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        deletedAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
    await _recordSyncQueue(id, 'DELETE');
  }

  // ==========================================
  // CONSULTAS REATIVAS (STREAMS)
  // ==========================================

  Stream<List<TaskEntry>> watchPendingTasks({
    String? category,
    String? projectId,
    String? priority,
  }) {
    final q = db.select(db.tasks)
      ..where((t) => t.status.isNotIn(['completed', 'cancelled', 'archived']) & t.deletedAt.isNull());

    if (category != null && category.isNotEmpty && category != 'all') {
      q.where((t) => t.category.equals(category));
    }
    if (projectId != null && projectId.isNotEmpty) {
      q.where((t) => t.projectId.equals(projectId));
    }
    if (priority != null && priority.isNotEmpty && priority != 'all') {
      q.where((t) => t.priority.equals(priority));
    }

    q.orderBy([
      (t) => drift.OrderingTerm(expression: t.dueDate, mode: drift.OrderingMode.asc, nulls: drift.NullsOrder.last),
      (t) => drift.OrderingTerm(expression: t.createdAt, mode: drift.OrderingMode.desc),
    ]);

    return q.watch();
  }

  Stream<List<TaskEntry>> watchTasksForToday() {
    final now = DateTime.now();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return (db.select(db.tasks)
          ..where((t) =>
              t.status.isNotIn(['completed', 'cancelled', 'archived']) &
              t.deletedAt.isNull() &
              (t.dueDate.isSmallerOrEqualValue(endOfDay) |
                  t.scheduledAt.isSmallerOrEqualValue(endOfDay)))
          ..orderBy([
            (t) => drift.OrderingTerm(expression: t.dueDate, mode: drift.OrderingMode.asc),
            (t) => drift.OrderingTerm(expression: t.priority, mode: drift.OrderingMode.desc),
          ]))
        .watch();
  }

  Stream<List<TaskEntry>> watchOverdueTasks() {
    final startOfToday = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return (db.select(db.tasks)
          ..where((t) =>
              t.status.isNotIn(['completed', 'cancelled', 'archived']) &
              t.deletedAt.isNull() &
              t.dueDate.isSmallerThanValue(startOfToday))
          ..orderBy([(t) => drift.OrderingTerm(expression: t.dueDate, mode: drift.OrderingMode.asc)]))
        .watch();
  }

  Stream<List<TaskEntry>> watchCompletedTasks({String? projectId, int limit = 50}) {
    final q = db.select(db.tasks)
      ..where((t) => t.status.equals('completed') & t.deletedAt.isNull());

    if (projectId != null && projectId.isNotEmpty) {
      q.where((t) => t.projectId.equals(projectId));
    }

    q.orderBy([(t) => drift.OrderingTerm(expression: t.completedAt, mode: drift.OrderingMode.desc)]);
    q.limit(limit);

    return q.watch();
  }

  Stream<List<TaskEntry>> watchTasksForPerson(String personId) {
    return (db.select(db.tasks)
          ..where((t) => t.personId.equals(personId) & t.deletedAt.isNull())
          ..orderBy([
            (t) => drift.OrderingTerm(expression: t.status, mode: drift.OrderingMode.asc),
            (t) => drift.OrderingTerm(expression: t.dueDate, mode: drift.OrderingMode.asc, nulls: drift.NullsOrder.last),
          ]))
        .watch();
  }

  Stream<List<TaskEntry>> watchTasksForStudy(String studyId) {
    return (db.select(db.tasks)
          ..where((t) => t.studyId.equals(studyId) & t.deletedAt.isNull())
          ..orderBy([
            (t) => drift.OrderingTerm(expression: t.status, mode: drift.OrderingMode.asc),
            (t) => drift.OrderingTerm(expression: t.dueDate, mode: drift.OrderingMode.asc, nulls: drift.NullsOrder.last),
          ]))
        .watch();
  }

  Stream<List<TaskEntry>> watchTasksForProject(String projectId) {
    return (db.select(db.tasks)
          ..where((t) => t.projectId.equals(projectId) & t.deletedAt.isNull())
          ..orderBy([
            (t) => drift.OrderingTerm(expression: t.status, mode: drift.OrderingMode.asc),
            (t) => drift.OrderingTerm(expression: t.dueDate, mode: drift.OrderingMode.asc, nulls: drift.NullsOrder.last),
          ]))
        .watch();
  }

  Stream<int> watchPendingTaskCount() {
    final q = db.selectOnly(db.tasks)
      ..addColumns([db.tasks.id.count()])
      ..where(db.tasks.status.isNotIn(['completed', 'cancelled', 'archived']) & db.tasks.deletedAt.isNull());
    return q.map((r) => r.read(db.tasks.id.count()) ?? 0).watchSingle();
  }

  Future<void> _recordSyncQueue(String entityId, String operation) async {
    try {
      final now = DateTime.now();
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'tasks',
          entityId: entityId,
          operation: operation,
          payload: jsonEncode({'id': entityId, 'created_at': now.toIso8601String()}),
          createdAt: now,
        ),
      );
    } catch (_) {}
  }
}
