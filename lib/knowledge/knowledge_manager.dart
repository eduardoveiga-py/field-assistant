import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

/// Item de resultado em busca unificada na Base de Conhecimento
class KnowledgeSearchResult {
  final String id;
  final String title;
  final String snippet;
  final String entityType; // 'note', 'question', 'document', 'resource'
  final String category;
  final DateTime updatedAt;

  const KnowledgeSearchResult({
    required this.id,
    required this.title,
    required this.snippet,
    required this.entityType,
    required this.category,
    required this.updatedAt,
  });
}

/// Gerenciador do Módulo C — Base de Conhecimento do Field Assistant.
/// Centraliza notas formatadas, dúvidas bíblicas/respostas, documentos e recursos
/// com integridade offline-first e relacionamento direto com pessoas, estudos e projetos.
class KnowledgeManager {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();

  KnowledgeManager({required this.db});

  // ==========================================
  // NOTAS DE CONHECIMENTO (KNOWLEDGE NOTES)
  // ==========================================

  Future<KnowledgeNoteEntry> createNote({
    required String title,
    required String content,
    String category = 'general',
    String? projectId,
    String? personId,
    String? studyId,
    String? originInboxId,
    bool isPinned = false,
    List<String> tags = const [],
    List<Map<String, dynamic>>? attachments,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    final companion = KnowledgeNotesCompanion.insert(
      id: id,
      title: title.trim(),
      content: content.trim(),
      category: drift.Value(category),
      projectId: drift.Value(projectId),
      personId: drift.Value(personId),
      studyId: drift.Value(studyId),
      originInboxId: drift.Value(originInboxId),
      isPinned: drift.Value(isPinned),
      tags: drift.Value(jsonEncode(tags)),
      attachments: drift.Value(attachments != null ? jsonEncode(attachments) : '[]'),
      createdAt: now,
      updatedAt: now,
    );

    await db.into(db.knowledgeNotes).insert(companion);
    await _recordSyncQueue(id, 'knowledge_notes', 'INSERT');

    return (await (db.select(db.knowledgeNotes)..where((t) => t.id.equals(id))).getSingle());
  }

  Future<void> updateNote(
    String id, {
    String? title,
    String? content,
    String? category,
    String? projectId,
    String? personId,
    String? studyId,
    List<String>? tags,
  }) async {
    final now = DateTime.now();
    final companion = KnowledgeNotesCompanion(
      title: title != null ? drift.Value(title.trim()) : const drift.Value.absent(),
      content: content != null ? drift.Value(content.trim()) : const drift.Value.absent(),
      category: category != null ? drift.Value(category) : const drift.Value.absent(),
      projectId: projectId != null ? drift.Value(projectId) : const drift.Value.absent(),
      personId: personId != null ? drift.Value(personId) : const drift.Value.absent(),
      studyId: studyId != null ? drift.Value(studyId) : const drift.Value.absent(),
      tags: tags != null ? drift.Value(jsonEncode(tags)) : const drift.Value.absent(),
      updatedAt: drift.Value(now),
    );

    await (db.update(db.knowledgeNotes)..where((t) => t.id.equals(id))).write(companion);
    await _recordSyncQueue(id, 'knowledge_notes', 'UPDATE');
  }

  Future<KnowledgeNoteEntry?> getNoteById(String id) async {
    return (db.select(db.knowledgeNotes)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> togglePinNote(String id) async {
    final current = await (db.select(db.knowledgeNotes)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (current == null) return;
    final now = DateTime.now();

    await (db.update(db.knowledgeNotes)..where((t) => t.id.equals(id))).write(
      KnowledgeNotesCompanion(
        isPinned: drift.Value(!current.isPinned),
        updatedAt: drift.Value(now),
      ),
    );
    await _recordSyncQueue(id, 'knowledge_notes', 'UPDATE');
  }

  Future<void> softDeleteNote(String id) async {
    final now = DateTime.now();
    await (db.update(db.knowledgeNotes)..where((t) => t.id.equals(id))).write(
      KnowledgeNotesCompanion(
        deletedAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
    await _recordSyncQueue(id, 'knowledge_notes', 'DELETE');
  }

  Stream<List<KnowledgeNoteEntry>> watchNotes({
    String? category,
    String? tag,
    String? query,
    String? projectId,
    String? personId,
    String? studyId,
  }) {
    final q = db.select(db.knowledgeNotes)
      ..where((t) => t.deletedAt.isNull());

    if (category != null && category.isNotEmpty && category != 'all') {
      q.where((t) => t.category.equals(category));
    }
    if (projectId != null && projectId.isNotEmpty) {
      q.where((t) => t.projectId.equals(projectId));
    }
    if (personId != null && personId.isNotEmpty) {
      q.where((t) => t.personId.equals(personId));
    }
    if (studyId != null && studyId.isNotEmpty) {
      q.where((t) => t.studyId.equals(studyId));
    }
    if (query != null && query.trim().isNotEmpty) {
      final pattern = '%${query.trim()}%';
      q.where((t) => t.title.like(pattern) | t.content.like(pattern));
    }

    q.orderBy([
      (t) => drift.OrderingTerm(expression: t.isPinned, mode: drift.OrderingMode.desc),
      (t) => drift.OrderingTerm(expression: t.updatedAt, mode: drift.OrderingMode.desc),
    ]);

    return q.watch();
  }

  // ==========================================
  // DÚVIDAS E PESQUISAS (KNOWLEDGE QUESTIONS)
  // ==========================================

  Future<KnowledgeQuestionEntry> createQuestion({
    required String question,
    String? context,
    String? answer,
    String status = 'unanswered',
    String category = 'biblical',
    String? projectId,
    String? personId,
    String? studyId,
    String? originInboxId,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    final companion = KnowledgeQuestionsCompanion.insert(
      id: id,
      question: question.trim(),
      context: drift.Value(context?.trim()),
      answer: drift.Value(answer?.trim()),
      status: drift.Value(status),
      category: drift.Value(category),
      projectId: drift.Value(projectId),
      personId: drift.Value(personId),
      studyId: drift.Value(studyId),
      originInboxId: drift.Value(originInboxId),
      answeredAt: drift.Value(answer != null && answer.trim().isNotEmpty ? now : null),
      createdAt: now,
      updatedAt: now,
    );

    await db.into(db.knowledgeQuestions).insert(companion);
    await _recordSyncQueue(id, 'knowledge_questions', 'INSERT');

    return (await (db.select(db.knowledgeQuestions)..where((t) => t.id.equals(id))).getSingle());
  }

  Future<void> answerQuestion(
    String id, {
    required String answer,
  }) async {
    final now = DateTime.now();
    final companion = KnowledgeQuestionsCompanion(
      answer: drift.Value(answer.trim()),
      status: const drift.Value('answered'),
      answeredAt: drift.Value(now),
      updatedAt: drift.Value(now),
    );

    await (db.update(db.knowledgeQuestions)..where((t) => t.id.equals(id))).write(companion);
    await _recordSyncQueue(id, 'knowledge_questions', 'UPDATE');
  }

  Future<void> updateQuestion(
    String id, {
    String? question,
    String? context,
    String? answer,
    String? status,
    String? category,
  }) async {
    final now = DateTime.now();
    final companion = KnowledgeQuestionsCompanion(
      question: question != null ? drift.Value(question.trim()) : const drift.Value.absent(),
      context: context != null ? drift.Value(context.trim()) : const drift.Value.absent(),
      answer: answer != null ? drift.Value(answer.trim()) : const drift.Value.absent(),
      status: status != null ? drift.Value(status) : const drift.Value.absent(),
      category: category != null ? drift.Value(category) : const drift.Value.absent(),
      answeredAt: answer != null && answer.trim().isNotEmpty ? drift.Value(now) : const drift.Value.absent(),
      updatedAt: drift.Value(now),
    );

    await (db.update(db.knowledgeQuestions)..where((t) => t.id.equals(id))).write(companion);
    await _recordSyncQueue(id, 'knowledge_questions', 'UPDATE');
  }

  Future<void> softDeleteQuestion(String id) async {
    final now = DateTime.now();
    await (db.update(db.knowledgeQuestions)..where((t) => t.id.equals(id))).write(
      KnowledgeQuestionsCompanion(
        deletedAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
    await _recordSyncQueue(id, 'knowledge_questions', 'DELETE');
  }

  Stream<List<KnowledgeQuestionEntry>> watchQuestions({
    String? status,
    String? category,
    String? query,
    String? personId,
    String? studyId,
  }) {
    final q = db.select(db.knowledgeQuestions)
      ..where((t) => t.deletedAt.isNull());

    if (status != null && status.isNotEmpty && status != 'all') {
      q.where((t) => t.status.equals(status));
    }
    if (category != null && category.isNotEmpty && category != 'all') {
      q.where((t) => t.category.equals(category));
    }
    if (personId != null && personId.isNotEmpty) {
      q.where((t) => t.personId.equals(personId));
    }
    if (studyId != null && studyId.isNotEmpty) {
      q.where((t) => t.studyId.equals(studyId));
    }
    if (query != null && query.trim().isNotEmpty) {
      final pattern = '%${query.trim()}%';
      q.where((t) =>
          t.question.like(pattern) |
          t.context.like(pattern) |
          t.answer.like(pattern));
    }

    q.orderBy([(t) => drift.OrderingTerm(expression: t.updatedAt, mode: drift.OrderingMode.desc)]);
    return q.watch();
  }

  // ==========================================
  // DOCUMENTOS (KNOWLEDGE DOCUMENTS)
  // ==========================================

  Future<KnowledgeDocumentEntry> registerDocument({
    required String title,
    required String fileName,
    required String fileType,
    required int fileSize,
    required String filePath,
    String? sha256Checksum,
    String? description,
    String category = 'general',
    String? projectId,
    String? personId,
    String? sectorId,
    String? originInboxId,
    List<String> tags = const [],
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    final companion = KnowledgeDocumentsCompanion.insert(
      id: id,
      title: title.trim(),
      fileName: fileName,
      fileType: fileType,
      fileSize: fileSize,
      filePath: filePath,
      sha256Checksum: drift.Value(sha256Checksum),
      description: drift.Value(description?.trim()),
      category: drift.Value(category),
      projectId: drift.Value(projectId),
      personId: drift.Value(personId),
      sectorId: drift.Value(sectorId),
      originInboxId: drift.Value(originInboxId),
      tags: drift.Value(jsonEncode(tags)),
      createdAt: now,
      updatedAt: now,
    );

    await db.into(db.knowledgeDocuments).insert(companion);
    await _recordSyncQueue(id, 'knowledge_documents', 'INSERT');

    return (await (db.select(db.knowledgeDocuments)..where((t) => t.id.equals(id))).getSingle());
  }

  Future<void> softDeleteDocument(String id) async {
    final now = DateTime.now();
    await (db.update(db.knowledgeDocuments)..where((t) => t.id.equals(id))).write(
      KnowledgeDocumentsCompanion(
        deletedAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
    await _recordSyncQueue(id, 'knowledge_documents', 'DELETE');
  }

  Future<void> updateDocument(
    String id, {
    String? title,
    String? description,
    String? category,
    List<String>? tags,
  }) async {
    final now = DateTime.now();
    final companion = KnowledgeDocumentsCompanion(
      title: title != null ? drift.Value(title.trim()) : const drift.Value.absent(),
      description: description != null ? drift.Value(description.trim()) : const drift.Value.absent(),
      category: category != null ? drift.Value(category) : const drift.Value.absent(),
      tags: tags != null ? drift.Value(jsonEncode(tags)) : const drift.Value.absent(),
      updatedAt: drift.Value(now),
    );

    await (db.update(db.knowledgeDocuments)..where((t) => t.id.equals(id))).write(companion);
    await _recordSyncQueue(id, 'knowledge_documents', 'UPDATE');
  }

  Stream<List<KnowledgeDocumentEntry>> watchDocuments({
    String? category,
    String? query,
    String? projectId,
  }) {
    final q = db.select(db.knowledgeDocuments)
      ..where((t) => t.deletedAt.isNull());

    if (category != null && category.isNotEmpty && category != 'all') {
      q.where((t) => t.category.equals(category));
    }
    if (projectId != null && projectId.isNotEmpty) {
      q.where((t) => t.projectId.equals(projectId));
    }
    if (query != null && query.trim().isNotEmpty) {
      final pattern = '%${query.trim()}%';
      q.where((t) => t.title.like(pattern) | t.fileName.like(pattern));
    }

    q.orderBy([(t) => drift.OrderingTerm(expression: t.createdAt, mode: drift.OrderingMode.desc)]);
    return q.watch();
  }

  // ==========================================
  // RECURSOS EXTERNOS E JW.ORG (KNOWLEDGE RESOURCES)
  // ==========================================

  Future<KnowledgeResourceEntry> createResource({
    required String title,
    required String resourceType,
    String? url,
    String? description,
    String? localAssetPath,
    String category = 'general',
    String? projectId,
    List<String> tags = const [],
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    final companion = KnowledgeResourcesCompanion.insert(
      id: id,
      title: title.trim(),
      resourceType: resourceType,
      url: drift.Value(url?.trim()),
      description: drift.Value(description?.trim()),
      localAssetPath: drift.Value(localAssetPath?.trim()),
      category: drift.Value(category),
      projectId: drift.Value(projectId),
      tags: drift.Value(jsonEncode(tags)),
      createdAt: now,
      updatedAt: now,
    );

    await db.into(db.knowledgeResources).insert(companion);
    await _recordSyncQueue(id, 'knowledge_resources', 'INSERT');

    return (await (db.select(db.knowledgeResources)..where((t) => t.id.equals(id))).getSingle());
  }

  Future<void> softDeleteResource(String id) async {
    final now = DateTime.now();
    await (db.update(db.knowledgeResources)..where((t) => t.id.equals(id))).write(
      KnowledgeResourcesCompanion(
        deletedAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
    await _recordSyncQueue(id, 'knowledge_resources', 'DELETE');
  }

  Future<void> updateResource(
    String id, {
    String? title,
    String? resourceType,
    String? url,
    String? description,
    String? category,
    List<String>? tags,
  }) async {
    final now = DateTime.now();
    final companion = KnowledgeResourcesCompanion(
      title: title != null ? drift.Value(title.trim()) : const drift.Value.absent(),
      resourceType: resourceType != null ? drift.Value(resourceType) : const drift.Value.absent(),
      url: url != null ? drift.Value(url.trim()) : const drift.Value.absent(),
      description: description != null ? drift.Value(description.trim()) : const drift.Value.absent(),
      category: category != null ? drift.Value(category) : const drift.Value.absent(),
      tags: tags != null ? drift.Value(jsonEncode(tags)) : const drift.Value.absent(),
      updatedAt: drift.Value(now),
    );

    await (db.update(db.knowledgeResources)..where((t) => t.id.equals(id))).write(companion);
    await _recordSyncQueue(id, 'knowledge_resources', 'UPDATE');
  }

  Stream<List<KnowledgeResourceEntry>> watchResources({
    String? resourceType,
    String? category,
    String? query,
  }) {
    final q = db.select(db.knowledgeResources)
      ..where((t) => t.deletedAt.isNull());

    if (resourceType != null && resourceType.isNotEmpty && resourceType != 'all') {
      q.where((t) => t.resourceType.equals(resourceType));
    }
    if (category != null && category.isNotEmpty && category != 'all') {
      q.where((t) => t.category.equals(category));
    }
    if (query != null && query.trim().isNotEmpty) {
      final pattern = '%${query.trim()}%';
      q.where((t) => t.title.like(pattern) | t.description.like(pattern));
    }

    q.orderBy([(t) => drift.OrderingTerm(expression: t.createdAt, mode: drift.OrderingMode.desc)]);
    return q.watch();
  }

  // ==========================================
  // BUSCA UNIFICADA (GLOBAL KNOWLEDGE SEARCH)
  // ==========================================

  Future<List<KnowledgeSearchResult>> searchKnowledge(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return [];
    final pattern = '%$query%';
    final results = <KnowledgeSearchResult>[];

    // Notas
    final notes = await (db.select(db.knowledgeNotes)
          ..where((t) => (t.title.like(pattern) | t.content.like(pattern)) & t.deletedAt.isNull())
          ..limit(15))
        .get();
    for (final n in notes) {
      results.add(KnowledgeSearchResult(
        id: n.id,
        title: n.title,
        snippet: n.content.length > 120 ? '${n.content.substring(0, 120)}...' : n.content,
        entityType: 'note',
        category: n.category,
        updatedAt: n.updatedAt,
      ));
    }

    // Perguntas / Dúvidas
    final questions = await (db.select(db.knowledgeQuestions)
          ..where((t) =>
              (t.question.like(pattern) |
                  t.context.like(pattern) |
                  t.answer.like(pattern)) &
              t.deletedAt.isNull())
          ..limit(15))
        .get();
    for (final q in questions) {
      results.add(KnowledgeSearchResult(
        id: q.id,
        title: q.question,
        snippet: q.answer != null && q.answer!.isNotEmpty
            ? (q.answer!.length > 120 ? '${q.answer!.substring(0, 120)}...' : q.answer!)
            : (q.context ?? 'Dúvida em aberto'),
        entityType: 'question',
        category: q.category,
        updatedAt: q.updatedAt,
      ));
    }

    // Documentos
    final docs = await (db.select(db.knowledgeDocuments)
          ..where((t) => (t.title.like(pattern) | t.fileName.like(pattern)) & t.deletedAt.isNull())
          ..limit(10))
        .get();
    for (final d in docs) {
      results.add(KnowledgeSearchResult(
        id: d.id,
        title: d.title,
        snippet: 'Arquivo: ${d.fileName} (${(d.fileSize / 1024).toStringAsFixed(1)} KB)',
        entityType: 'document',
        category: d.category,
        updatedAt: d.updatedAt,
      ));
    }

    // Recursos
    final res = await (db.select(db.knowledgeResources)
          ..where((t) => (t.title.like(pattern) | t.description.like(pattern)) & t.deletedAt.isNull())
          ..limit(10))
        .get();
    for (final r in res) {
      results.add(KnowledgeSearchResult(
        id: r.id,
        title: r.title,
        snippet: r.url ?? r.description ?? r.resourceType,
        entityType: 'resource',
        category: r.category,
        updatedAt: r.updatedAt,
      ));
    }

    results.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return results;
  }

  Future<void> _recordSyncQueue(String entityId, String entityType, String operation) async {
    try {
      final now = DateTime.now();
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: entityType,
          entityId: entityId,
          operation: operation,
          payload: jsonEncode({'id': entityId, 'created_at': now.toIso8601String()}),
          createdAt: now,
        ),
      );
    } catch (_) {}
  }
}
