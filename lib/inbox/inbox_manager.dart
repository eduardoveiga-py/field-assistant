import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

/// Gerenciador do Módulo A — Inbox Universal do Field Assistant.
/// Ponto central e desconectado para captura rápida sem perda de dados,
/// com suporte a texto, ditado/áudio de voz, arquivos e conversão rastreável.
class InboxManager {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();

  InboxManager({required this.db});

  // ==========================================
  // CAPTURA RÁPIDA (INGESTÃO)
  // ==========================================

  /// Captura rápida de ideia, nota ou texto livre
  Future<InboxEntry> captureText({
    required String content,
    String? suggestedCategory,
    Map<String, dynamic>? metadata,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    final companion = InboxEntriesCompanion.insert(
      id: id,
      content: content.trim(),
      sourceType: const drift.Value('text'),
      suggestedCategory: drift.Value(suggestedCategory),
      capturedAt: now,
      metadata: drift.Value(metadata != null ? jsonEncode(metadata) : '{}'),
      createdAt: now,
      updatedAt: now,
    );

    await db.into(db.inboxEntries).insert(companion);
    await _recordSyncQueue(id, 'INSERT', companion);

    return (await (db.select(db.inboxEntries)..where((t) => t.id.equals(id))).getSingle());
  }

  /// Captura rápida de áudio ou ditado por voz
  Future<InboxEntry> captureAudio({
    required String content,
    required String audioPath,
    required int durationSeconds,
    String? suggestedCategory,
    Map<String, dynamic>? metadata,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    final companion = InboxEntriesCompanion.insert(
      id: id,
      content: content.trim().isEmpty ? 'Nota de voz gravada' : content.trim(),
      sourceType: const drift.Value('audio'),
      mediaPath: drift.Value(audioPath),
      mediaDurationSeconds: drift.Value(durationSeconds),
      suggestedCategory: drift.Value(suggestedCategory),
      capturedAt: now,
      metadata: drift.Value(metadata != null ? jsonEncode(metadata) : '{}'),
      createdAt: now,
      updatedAt: now,
    );

    await db.into(db.inboxEntries).insert(companion);
    await _recordSyncQueue(id, 'INSERT', companion);

    return (await (db.select(db.inboxEntries)..where((t) => t.id.equals(id))).getSingle());
  }

  /// Captura rápida com anexo (documento ou imagem)
  Future<InboxEntry> captureAttachment({
    required String content,
    required String filePath,
    required String fileName,
    required String fileType,
    String? suggestedCategory,
    Map<String, dynamic>? metadata,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    final attachmentsList = [
      {
        'path': filePath,
        'name': fileName,
        'type': fileType,
        'added_at': now.toIso8601String(),
      }
    ];

    final companion = InboxEntriesCompanion.insert(
      id: id,
      content: content.trim().isEmpty ? 'Arquivo anexado: $fileName' : content.trim(),
      sourceType: drift.Value(fileType == 'image' ? 'image' : 'file'),
      mediaPath: drift.Value(filePath),
      attachments: drift.Value(jsonEncode(attachmentsList)),
      suggestedCategory: drift.Value(suggestedCategory),
      capturedAt: now,
      metadata: drift.Value(metadata != null ? jsonEncode(metadata) : '{}'),
      createdAt: now,
      updatedAt: now,
    );

    await db.into(db.inboxEntries).insert(companion);
    await _recordSyncQueue(id, 'INSERT', companion);

    return (await (db.select(db.inboxEntries)..where((t) => t.id.equals(id))).getSingle());
  }

  /// Edição de uma entrada da Inbox existente
  Future<void> updateEntry(
    String id, {
    String? content,
    String? suggestedCategory,
    List<Map<String, dynamic>>? attachments,
    String? status,
    Map<String, dynamic>? metadata,
  }) async {
    final now = DateTime.now();
    final companion = InboxEntriesCompanion(
      content: content != null ? drift.Value(content.trim()) : const drift.Value.absent(),
      suggestedCategory: suggestedCategory != null ? drift.Value(suggestedCategory) : const drift.Value.absent(),
      attachments: attachments != null ? drift.Value(jsonEncode(attachments)) : const drift.Value.absent(),
      status: status != null ? drift.Value(status) : const drift.Value.absent(),
      metadata: metadata != null ? drift.Value(jsonEncode(metadata)) : const drift.Value.absent(),
      updatedAt: drift.Value(now),
    );

    await (db.update(db.inboxEntries)..where((t) => t.id.equals(id))).write(companion);
    await _recordSyncQueue(id, 'UPDATE', companion);
  }

  // ==========================================
  // CONSULTAS REATIVAS (STREAMS)
  // ==========================================

  /// Observa itens não processados (Inbox Ativa)
  Stream<List<InboxEntry>> watchUnprocessedEntries() {
    return (db.select(db.inboxEntries)
          ..where((t) => t.status.equals('unprocessed') & t.deletedAt.isNull())
          ..orderBy([(t) => drift.OrderingTerm.desc(t.capturedAt)]))
        .watch();
  }

  /// Observa contagem de itens pendentes no Inbox (para Badge do AppBar)
  Stream<int> watchUnprocessedCount() {
    final query = db.selectOnly(db.inboxEntries)
      ..addColumns([db.inboxEntries.id.count()])
      ..where(db.inboxEntries.status.equals('unprocessed') & db.inboxEntries.deletedAt.isNull());
    return query.map((row) => row.read(db.inboxEntries.id.count()) ?? 0).watchSingle();
  }

  /// Observa todas as entradas com filtro opcional por status
  Stream<List<InboxEntry>> watchEntries({String? statusFilter}) {
    final q = db.select(db.inboxEntries)
      ..where((t) => t.deletedAt.isNull());
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'all') {
      q.where((t) => t.status.equals(statusFilter));
    }
    q.orderBy([(t) => drift.OrderingTerm.desc(t.capturedAt)]);
    return q.watch();
  }

  Future<InboxEntry?> getEntryById(String id) {
    return (db.select(db.inboxEntries)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // ==========================================
  // GESTÃO DE STATUS E TRIAGEM
  // ==========================================

  Future<void> markInReview(String id) async {
    final now = DateTime.now();
    await (db.update(db.inboxEntries)..where((t) => t.id.equals(id))).write(
      InboxEntriesCompanion(
        status: const drift.Value('in_review'),
        updatedAt: drift.Value(now),
      ),
    );
  }

  Future<void> archiveEntry(String id) async {
    final now = DateTime.now();
    await (db.update(db.inboxEntries)..where((t) => t.id.equals(id))).write(
      InboxEntriesCompanion(
        status: const drift.Value('archived'),
        processedAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
  }

  Future<void> softDeleteEntry(String id) async {
    final now = DateTime.now();
    await (db.update(db.inboxEntries)..where((t) => t.id.equals(id))).write(
      InboxEntriesCompanion(
        deletedAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
  }

  // ==========================================
  // PIPELINE DE CONVERSÃO NÃO-DESTRUTIVA
  // ==========================================

  /// Converte uma entrada de Inbox em Tarefa formal
  Future<TaskEntry> convertToTask(
    String inboxId, {
    required String title,
    String? description,
    String priority = 'normal',
    String category = 'ministry',
    String? projectId,
    String? personId,
    String? studyId,
    DateTime? dueDate,
    DateTime? scheduledAt,
  }) async {
    final inbox = await getEntryById(inboxId);
    if (inbox == null) throw Exception('Entrada de Inbox não encontrada: $inboxId');

    final taskId = _uuid.v4();
    final now = DateTime.now();

    final taskCompanion = TasksCompanion.insert(
      id: taskId,
      title: title.trim(),
      description: drift.Value(description ?? inbox.content),
      priority: drift.Value(priority),
      category: drift.Value(category),
      projectId: drift.Value(projectId),
      personId: drift.Value(personId),
      studyId: drift.Value(studyId),
      originInboxId: drift.Value(inboxId),
      dueDate: drift.Value(dueDate),
      scheduledAt: drift.Value(scheduledAt),
      attachments: drift.Value(inbox.attachments),
      createdAt: now,
      updatedAt: now,
    );

    await db.into(db.tasks).insert(taskCompanion);
    await _recordSyncQueue(taskId, 'INSERT', taskCompanion);

    // Atualiza status da entrada no Inbox sem perda de dados
    await (db.update(db.inboxEntries)..where((t) => t.id.equals(inboxId))).write(
      InboxEntriesCompanion(
        status: const drift.Value('converted'),
        convertedEntityType: const drift.Value('task'),
        convertedEntityId: drift.Value(taskId),
        processedAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );

    return (await (db.select(db.tasks)..where((t) => t.id.equals(taskId))).getSingle());
  }

  /// Converte uma entrada de Inbox em Projeto
  Future<ProjectEntry> convertToProject(
    String inboxId, {
    required String name,
    String? objective,
    String? description,
    String category = 'ministry',
    String? colorHex,
    String? iconName,
    DateTime? targetDate,
  }) async {
    final inbox = await getEntryById(inboxId);
    if (inbox == null) throw Exception('Entrada de Inbox não encontrada: $inboxId');

    final projectId = _uuid.v4();
    final now = DateTime.now();

    final projectCompanion = ProjectsCompanion.insert(
      id: projectId,
      name: name.trim(),
      objective: drift.Value(objective),
      description: drift.Value(description ?? inbox.content),
      category: drift.Value(category),
      colorHex: drift.Value(colorHex),
      iconName: drift.Value(iconName),
      targetDate: drift.Value(targetDate),
      originInboxId: drift.Value(inboxId),
      createdAt: now,
      updatedAt: now,
    );

    await db.into(db.projects).insert(projectCompanion);
    await _recordSyncQueue(projectId, 'INSERT', projectCompanion);

    await (db.update(db.inboxEntries)..where((t) => t.id.equals(inboxId))).write(
      InboxEntriesCompanion(
        status: const drift.Value('converted'),
        convertedEntityType: const drift.Value('project'),
        convertedEntityId: drift.Value(projectId),
        processedAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );

    return (await (db.select(db.projects)..where((t) => t.id.equals(projectId))).getSingle());
  }

  /// Converte uma entrada de Inbox em Nota de Conhecimento
  Future<KnowledgeNoteEntry> convertToNote(
    String inboxId, {
    required String title,
    String? content,
    String category = 'general',
    String? projectId,
    String? personId,
    String? studyId,
    List<String> tags = const [],
  }) async {
    final inbox = await getEntryById(inboxId);
    if (inbox == null) throw Exception('Entrada de Inbox não encontrada: $inboxId');

    final noteId = _uuid.v4();
    final now = DateTime.now();

    final noteCompanion = KnowledgeNotesCompanion.insert(
      id: noteId,
      title: title.trim(),
      content: content ?? inbox.content,
      category: drift.Value(category),
      projectId: drift.Value(projectId),
      personId: drift.Value(personId),
      studyId: drift.Value(studyId),
      originInboxId: drift.Value(inboxId),
      tags: drift.Value(jsonEncode(tags)),
      attachments: drift.Value(inbox.attachments),
      createdAt: now,
      updatedAt: now,
    );

    await db.into(db.knowledgeNotes).insert(noteCompanion);
    await _recordSyncQueue(noteId, 'INSERT', noteCompanion);

    await (db.update(db.inboxEntries)..where((t) => t.id.equals(inboxId))).write(
      InboxEntriesCompanion(
        status: const drift.Value('converted'),
        convertedEntityType: const drift.Value('note'),
        convertedEntityId: drift.Value(noteId),
        processedAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );

    return (await (db.select(db.knowledgeNotes)..where((t) => t.id.equals(noteId))).getSingle());
  }

  /// Converte uma entrada de Inbox em Pergunta / Dúvida Teocrática
  Future<KnowledgeQuestionEntry> convertToQuestion(
    String inboxId, {
    required String question,
    String? context,
    String category = 'biblical',
    String? projectId,
    String? personId,
    String? studyId,
  }) async {
    final inbox = await getEntryById(inboxId);
    if (inbox == null) throw Exception('Entrada de Inbox não encontrada: $inboxId');

    final questionId = _uuid.v4();
    final now = DateTime.now();

    final questionCompanion = KnowledgeQuestionsCompanion.insert(
      id: questionId,
      question: question.trim(),
      context: drift.Value(context ?? inbox.content),
      category: drift.Value(category),
      projectId: drift.Value(projectId),
      personId: drift.Value(personId),
      studyId: drift.Value(studyId),
      originInboxId: drift.Value(inboxId),
      createdAt: now,
      updatedAt: now,
    );

    await db.into(db.knowledgeQuestions).insert(questionCompanion);
    await _recordSyncQueue(questionId, 'INSERT', questionCompanion);

    await (db.update(db.inboxEntries)..where((t) => t.id.equals(inboxId))).write(
      InboxEntriesCompanion(
        status: const drift.Value('converted'),
        convertedEntityType: const drift.Value('question'),
        convertedEntityId: drift.Value(questionId),
        processedAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );

    return (await (db.select(db.knowledgeQuestions)..where((t) => t.id.equals(questionId))).getSingle());
  }

  // ==========================================
  // AUXILIARES DE SINCRONIZAÇÃO OFFLINE-FIRST
  // ==========================================

  Future<void> _recordSyncQueue(
    String entityId,
    String operation,
    drift.UpdateCompanion companion,
  ) async {
    try {
      final now = DateTime.now();
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'inbox_entries',
          entityId: entityId,
          operation: operation,
          payload: jsonEncode({'id': entityId, 'created_at': now.toIso8601String()}),
          createdAt: now,
        ),
      );
    } catch (_) {}
  }
}
