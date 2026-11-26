import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../core/app_logger.dart';
import '../core/sync_timestamp.dart';
import '../database/app_database.dart';
import 'knowledge_backlink_indexer.dart';
import 'knowledge_search_index.dart';
import 'pdf_text_extractor.dart';

export 'knowledge_search_common.dart' show KnowledgeSearchResult;

/// Gerenciador do Módulo C — Base de Conhecimento / Segundo Cérebro do Field Assistant.
/// Centraliza áreas P.A.R.A., notas/subpáginas, backlinks bidirecionais, dúvidas bíblicas,
/// documentos com texto indexado (FTS5/Web) e recursos externos.
class KnowledgeManager {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();

  KnowledgeManager({required this.db});

  static Map<String, dynamic> decodeProperties(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  // ==========================================
  // ÁREAS P.A.R.A. (KNOWLEDGE AREAS)
  // ==========================================

  Future<KnowledgeAreaEntry> createArea({
    String? id,
    required String name,
    String? description,
    String? iconName,
    String? colorHex,
    int sortOrder = 0,
  }) async {
    final areaId = (id != null && id.trim().isNotEmpty)
        ? id.trim()
        : _uuid.v4();
    final now = DateTime.now().toUtc();

    await db
        .into(db.knowledgeAreas)
        .insert(
          KnowledgeAreasCompanion.insert(
            id: areaId,
            name: name.trim(),
            description: drift.Value(description?.trim()),
            iconName: drift.Value(iconName ?? 'layers'),
            colorHex: drift.Value(colorHex ?? '#6366F1'),
            sortOrder: drift.Value(sortOrder),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _recordSyncQueue(areaId, 'knowledge_areas', 'INSERT');

    return (await (db.select(
      db.knowledgeAreas,
    )..where((t) => t.id.equals(areaId))).getSingle());
  }

  Future<void> updateArea(
    String id, {
    String? name,
    String? description,
    String? iconName,
    String? colorHex,
    int? sortOrder,
    bool? isArchived,
  }) async {
    final existing = await (db.select(
      db.knowledgeAreas,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) return;
    final now = DateTime.now().toUtc();

    await (db.update(db.knowledgeAreas)..where((t) => t.id.equals(id))).write(
      KnowledgeAreasCompanion(
        name: name != null
            ? drift.Value(name.trim())
            : const drift.Value.absent(),
        description: description != null
            ? drift.Value(description.trim())
            : const drift.Value.absent(),
        iconName: iconName != null
            ? drift.Value(iconName)
            : const drift.Value.absent(),
        colorHex: colorHex != null
            ? drift.Value(colorHex)
            : const drift.Value.absent(),
        sortOrder: sortOrder != null
            ? drift.Value(sortOrder)
            : const drift.Value.absent(),
        isArchived: isArchived != null
            ? drift.Value(isArchived)
            : const drift.Value.absent(),
        updatedAt: drift.Value(now),
        revision: drift.Value(existing.revision + 1),
      ),
    );
    await _recordSyncQueue(
      id,
      'knowledge_areas',
      'UPDATE',
      baseData: existing.toJson(),
    );
  }

  Future<void> softDeleteArea(String id) async {
    final existing = await (db.select(
      db.knowledgeAreas,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) return;
    final now = DateTime.now().toUtc();

    await (db.update(db.knowledgeAreas)..where((t) => t.id.equals(id))).write(
      KnowledgeAreasCompanion(
        deletedAt: drift.Value(now),
        updatedAt: drift.Value(now),
        revision: drift.Value(existing.revision + 1),
      ),
    );
    await _recordSyncQueue(
      id,
      'knowledge_areas',
      'DELETE',
      baseData: existing.toJson(),
    );
  }

  Stream<List<KnowledgeAreaEntry>> watchAreas({bool includeArchived = false}) {
    final q = db.select(db.knowledgeAreas)..where((t) => t.deletedAt.isNull());
    if (!includeArchived) {
      q.where((t) => t.isArchived.equals(false));
    }
    q.orderBy([
      (t) => drift.OrderingTerm(
        expression: t.sortOrder,
        mode: drift.OrderingMode.asc,
      ),
      (t) =>
          drift.OrderingTerm(expression: t.name, mode: drift.OrderingMode.asc),
    ]);
    return q.watch();
  }

  // ==========================================
  // NOTAS DE CONHECIMENTO (KNOWLEDGE NOTES)
  // ==========================================

  Future<bool> wouldCreateParentCycle(
    String noteId,
    String candidateParentId,
  ) async {
    var cursor = candidateParentId.trim();
    if (cursor.isEmpty) return false;
    if (cursor == noteId) return true;

    final visited = <String>{noteId};
    var depth = 0;
    while (cursor.isNotEmpty && depth < 50) {
      depth++;
      if (!visited.add(cursor)) return true;
      final row =
          await (db.select(db.knowledgeNotes)
                ..where((t) => t.id.equals(cursor) & t.deletedAt.isNull()))
              .getSingleOrNull();
      final nextParent = row?.parentNoteId?.trim() ?? '';
      if (nextParent.isEmpty) return false;
      cursor = nextParent;
    }
    return false;
  }

  Future<List<KnowledgeNoteEntry>> getNoteAncestors(String noteId) async {
    final chain = <KnowledgeNoteEntry>[];
    final visited = <String>{noteId};
    var current = await getNoteById(noteId);
    var depth = 0;
    while (current?.parentNoteId != null &&
        current!.parentNoteId!.trim().isNotEmpty &&
        depth < 30) {
      depth++;
      final pid = current.parentNoteId!.trim();
      if (!visited.add(pid)) break;
      final parent =
          await (db.select(db.knowledgeNotes)
                ..where((t) => t.id.equals(pid) & t.deletedAt.isNull()))
              .getSingleOrNull();
      if (parent == null) break;
      chain.insert(0, parent);
      current = parent;
    }
    return chain;
  }

  Stream<List<KnowledgeNoteEntry>> watchSubpages(String parentNoteId) {
    return (db.select(db.knowledgeNotes)
          ..where(
            (t) =>
                t.parentNoteId.equals(parentNoteId) &
                t.deletedAt.isNull() &
                t.category.like('official_%').not(),
          )
          ..orderBy([
            (t) => drift.OrderingTerm(
              expression: t.isPinned,
              mode: drift.OrderingMode.desc,
            ),
            (t) => drift.OrderingTerm(
              expression: t.updatedAt,
              mode: drift.OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  Future<KnowledgeNoteEntry> createNote({
    String? id,
    required String title,
    required String content,
    String category = 'general',
    String? projectId,
    String? personId,
    String? studyId,
    String? originInboxId,
    String? areaId,
    String? parentNoteId,
    Map<String, dynamic>? properties,
    DateTime? nextReviewAt,
    bool isPinned = false,
    List<String> tags = const [],
    List<Map<String, dynamic>>? attachments,
  }) async {
    final noteId = (id != null && id.trim().isNotEmpty)
        ? id.trim()
        : _uuid.v4();
    final safeParentId =
        (parentNoteId != null &&
            parentNoteId.trim().isNotEmpty &&
            parentNoteId.trim() != noteId)
        ? parentNoteId.trim()
        : null;
    final now = DateTime.now();

    final companion = KnowledgeNotesCompanion.insert(
      id: noteId,
      title: title.trim(),
      content: content.trim(),
      category: drift.Value(category),
      projectId: drift.Value(projectId),
      personId: drift.Value(personId),
      studyId: drift.Value(studyId),
      originInboxId: drift.Value(originInboxId),
      areaId: drift.Value(areaId),
      parentNoteId: drift.Value(safeParentId),
      propertiesJson: drift.Value(
        properties != null ? jsonEncode(properties) : '{}',
      ),
      nextReviewAt: drift.Value(nextReviewAt),
      isPinned: drift.Value(isPinned),
      tags: drift.Value(jsonEncode(tags)),
      attachments: drift.Value(
        attachments != null ? jsonEncode(attachments) : '[]',
      ),
      createdAt: now,
      updatedAt: now,
    );

    await db.into(db.knowledgeNotes).insert(companion);
    await _recordSyncQueue(noteId, 'knowledge_notes', 'INSERT');
    await KnowledgeBacklinkIndexer.reindexLinksForSource(
      db,
      sourceType: 'note',
      sourceId: noteId,
      textFields: [content],
    );
    await KnowledgeSearchIndex.syncEntity(
      db,
      entityType: 'note',
      entityId: noteId,
    );

    return (await (db.select(
      db.knowledgeNotes,
    )..where((t) => t.id.equals(noteId))).getSingle());
  }

  Future<void> updateNote(
    String id, {
    String? title,
    String? content,
    String? category,
    String? projectId,
    String? personId,
    String? studyId,
    String? areaId,
    bool clearAreaId = false,
    String? parentNoteId,
    bool clearParentNoteId = false,
    Map<String, dynamic>? properties,
    DateTime? nextReviewAt,
    bool clearNextReviewAt = false,
    List<String>? tags,
  }) async {
    if (parentNoteId != null &&
        parentNoteId.trim().isNotEmpty &&
        await wouldCreateParentCycle(id, parentNoteId)) {
      throw ArgumentError(
        'Hierarquia circular detectada: uma nota não pode ser subpágina dela mesma.',
      );
    }

    final existing = await getNoteById(id);
    final now = DateTime.now();
    final companion = KnowledgeNotesCompanion(
      title: title != null
          ? drift.Value(title.trim())
          : const drift.Value.absent(),
      content: content != null
          ? drift.Value(content.trim())
          : const drift.Value.absent(),
      category: category != null
          ? drift.Value(category)
          : const drift.Value.absent(),
      projectId: projectId != null
          ? drift.Value(projectId)
          : const drift.Value.absent(),
      personId: personId != null
          ? drift.Value(personId)
          : const drift.Value.absent(),
      studyId: studyId != null
          ? drift.Value(studyId)
          : const drift.Value.absent(),
      areaId: clearAreaId
          ? const drift.Value(null)
          : (areaId != null ? drift.Value(areaId) : const drift.Value.absent()),
      parentNoteId: clearParentNoteId
          ? const drift.Value(null)
          : (parentNoteId != null
                ? drift.Value(
                    parentNoteId.trim().isEmpty ? null : parentNoteId.trim(),
                  )
                : const drift.Value.absent()),
      propertiesJson: properties != null
          ? drift.Value(jsonEncode(properties))
          : const drift.Value.absent(),
      nextReviewAt: clearNextReviewAt
          ? const drift.Value(null)
          : (nextReviewAt != null
                ? drift.Value(nextReviewAt)
                : const drift.Value.absent()),
      tags: tags != null
          ? drift.Value(jsonEncode(tags))
          : const drift.Value.absent(),
      updatedAt: drift.Value(now),
      revision: existing != null
          ? drift.Value(existing.revision + 1)
          : const drift.Value.absent(),
    );

    await (db.update(
      db.knowledgeNotes,
    )..where((t) => t.id.equals(id))).write(companion);
    await _recordSyncQueue(
      id,
      'knowledge_notes',
      'UPDATE',
      baseData: existing?.toJson(),
    );

    final updated = await getNoteById(id);
    if (updated != null && updated.deletedAt == null) {
      await KnowledgeBacklinkIndexer.reindexLinksForSource(
        db,
        sourceType: 'note',
        sourceId: id,
        textFields: [updated.content],
      );
      await KnowledgeSearchIndex.syncEntity(
        db,
        entityType: 'note',
        entityId: id,
      );
    }
  }

  Future<KnowledgeNoteEntry?> getNoteById(String id) async {
    return (db.select(
      db.knowledgeNotes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> togglePinNote(String id) async {
    final current = await (db.select(
      db.knowledgeNotes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
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
    final existing = await getNoteById(id);
    final now = DateTime.now();
    await (db.update(db.knowledgeNotes)..where((t) => t.id.equals(id))).write(
      KnowledgeNotesCompanion(
        deletedAt: drift.Value(now),
        updatedAt: drift.Value(now),
        revision: existing != null
            ? drift.Value(existing.revision + 1)
            : const drift.Value.absent(),
      ),
    );
    await _recordSyncQueue(
      id,
      'knowledge_notes',
      'DELETE',
      baseData: existing?.toJson(),
    );
    await KnowledgeBacklinkIndexer.softDeleteLinksForSource(
      db,
      sourceType: 'note',
      sourceId: id,
    );
    await KnowledgeSearchIndex.syncEntity(db, entityType: 'note', entityId: id);
  }

  Stream<List<KnowledgeNoteEntry>> watchNotes({
    String? category,
    String? tag,
    String? query,
    String? projectId,
    String? personId,
    String? studyId,
    String? areaId,
    String? parentNoteId,
    bool topLevelOnly = false,
  }) {
    final q = db.select(db.knowledgeNotes)..where((t) => t.deletedAt.isNull());

    if (category != null && category.isNotEmpty && category != 'all') {
      q.where((t) => t.category.equals(category));
    } else {
      // Categorias internas de documentos oficiais / templates possuem fluxo próprio
      q.where((t) => t.category.like('official_%').not());
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
    if (areaId != null && areaId.isNotEmpty) {
      q.where((t) => t.areaId.equals(areaId));
    }
    if (parentNoteId != null && parentNoteId.isNotEmpty) {
      q.where((t) => t.parentNoteId.equals(parentNoteId));
    } else if (topLevelOnly) {
      q.where((t) => t.parentNoteId.isNull());
    }
    if (query != null && query.trim().isNotEmpty) {
      final pattern = '%${query.trim()}%';
      q.where(
        (t) =>
            t.title.like(pattern) |
            t.content.like(pattern) |
            t.tags.like(pattern),
      );
    }

    q.orderBy([
      (t) => drift.OrderingTerm(
        expression: t.isPinned,
        mode: drift.OrderingMode.desc,
      ),
      (t) => drift.OrderingTerm(
        expression: t.updatedAt,
        mode: drift.OrderingMode.desc,
      ),
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
    String? areaId,
    DateTime? nextReviewAt,
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
      areaId: drift.Value(areaId),
      nextReviewAt: drift.Value(nextReviewAt),
      answeredAt: drift.Value(
        answer != null && answer.trim().isNotEmpty ? now : null,
      ),
      createdAt: now,
      updatedAt: now,
    );

    await db.into(db.knowledgeQuestions).insert(companion);
    await _recordSyncQueue(id, 'knowledge_questions', 'INSERT');
    await KnowledgeBacklinkIndexer.reindexLinksForSource(
      db,
      sourceType: 'question',
      sourceId: id,
      textFields: [context ?? '', answer ?? ''],
    );
    await KnowledgeSearchIndex.syncEntity(
      db,
      entityType: 'question',
      entityId: id,
    );

    return (await (db.select(
      db.knowledgeQuestions,
    )..where((t) => t.id.equals(id))).getSingle());
  }

  Future<void> answerQuestion(String id, {required String answer}) async {
    final existing = await (db.select(
      db.knowledgeQuestions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    final now = DateTime.now();
    final companion = KnowledgeQuestionsCompanion(
      answer: drift.Value(answer.trim()),
      status: const drift.Value('answered'),
      answeredAt: drift.Value(now),
      updatedAt: drift.Value(now),
      revision: existing != null
          ? drift.Value(existing.revision + 1)
          : const drift.Value.absent(),
    );

    await (db.update(
      db.knowledgeQuestions,
    )..where((t) => t.id.equals(id))).write(companion);
    await _recordSyncQueue(
      id,
      'knowledge_questions',
      'UPDATE',
      baseData: existing?.toJson(),
    );
    await KnowledgeBacklinkIndexer.reindexLinksForSource(
      db,
      sourceType: 'question',
      sourceId: id,
      textFields: [existing?.context ?? '', answer],
    );
    await KnowledgeSearchIndex.syncEntity(
      db,
      entityType: 'question',
      entityId: id,
    );
  }

  Future<void> updateQuestion(
    String id, {
    String? question,
    String? context,
    String? answer,
    String? status,
    String? category,
    String? areaId,
    bool clearAreaId = false,
    DateTime? nextReviewAt,
    bool clearNextReviewAt = false,
  }) async {
    final existing = await (db.select(
      db.knowledgeQuestions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    final now = DateTime.now();
    final companion = KnowledgeQuestionsCompanion(
      question: question != null
          ? drift.Value(question.trim())
          : const drift.Value.absent(),
      context: context != null
          ? drift.Value(context.trim())
          : const drift.Value.absent(),
      answer: answer != null
          ? drift.Value(answer.trim())
          : const drift.Value.absent(),
      status: status != null ? drift.Value(status) : const drift.Value.absent(),
      category: category != null
          ? drift.Value(category)
          : const drift.Value.absent(),
      areaId: clearAreaId
          ? const drift.Value(null)
          : (areaId != null ? drift.Value(areaId) : const drift.Value.absent()),
      nextReviewAt: clearNextReviewAt
          ? const drift.Value(null)
          : (nextReviewAt != null
                ? drift.Value(nextReviewAt)
                : const drift.Value.absent()),
      answeredAt: answer != null && answer.trim().isNotEmpty
          ? drift.Value(now)
          : const drift.Value.absent(),
      updatedAt: drift.Value(now),
      revision: existing != null
          ? drift.Value(existing.revision + 1)
          : const drift.Value.absent(),
    );

    await (db.update(
      db.knowledgeQuestions,
    )..where((t) => t.id.equals(id))).write(companion);
    await _recordSyncQueue(
      id,
      'knowledge_questions',
      'UPDATE',
      baseData: existing?.toJson(),
    );
    final updated = await (db.select(
      db.knowledgeQuestions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (updated != null && updated.deletedAt == null) {
      await KnowledgeBacklinkIndexer.reindexLinksForSource(
        db,
        sourceType: 'question',
        sourceId: id,
        textFields: [updated.context ?? '', updated.answer ?? ''],
      );
      await KnowledgeSearchIndex.syncEntity(
        db,
        entityType: 'question',
        entityId: id,
      );
    }
  }

  Future<void> softDeleteQuestion(String id) async {
    final existing = await (db.select(
      db.knowledgeQuestions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    final now = DateTime.now();
    await (db.update(
      db.knowledgeQuestions,
    )..where((t) => t.id.equals(id))).write(
      KnowledgeQuestionsCompanion(
        deletedAt: drift.Value(now),
        updatedAt: drift.Value(now),
        revision: existing != null
            ? drift.Value(existing.revision + 1)
            : const drift.Value.absent(),
      ),
    );
    await _recordSyncQueue(
      id,
      'knowledge_questions',
      'DELETE',
      baseData: existing?.toJson(),
    );
    await KnowledgeBacklinkIndexer.softDeleteLinksForSource(
      db,
      sourceType: 'question',
      sourceId: id,
    );
    await KnowledgeSearchIndex.syncEntity(
      db,
      entityType: 'question',
      entityId: id,
    );
  }

  Stream<List<KnowledgeQuestionEntry>> watchQuestions({
    String? status,
    String? category,
    String? query,
    String? personId,
    String? studyId,
    String? areaId,
  }) {
    final q = db.select(db.knowledgeQuestions)
      ..where((t) => t.deletedAt.isNull());

    if (status != null && status.isNotEmpty && status != 'all') {
      q.where((t) => t.status.equals(status));
    }
    if (category != null && category.isNotEmpty && category != 'all') {
      q.where((t) => t.category.equals(category));
    } else {
      // Categorias internas de documentos oficiais / templates possuem fluxo próprio
      q.where((t) => t.category.like('official_%').not());
    }
    if (personId != null && personId.isNotEmpty) {
      q.where((t) => t.personId.equals(personId));
    }
    if (studyId != null && studyId.isNotEmpty) {
      q.where((t) => t.studyId.equals(studyId));
    }
    if (areaId != null && areaId.isNotEmpty) {
      q.where((t) => t.areaId.equals(areaId));
    }
    if (query != null && query.trim().isNotEmpty) {
      final pattern = '%${query.trim()}%';
      q.where(
        (t) =>
            t.question.like(pattern) |
            t.context.like(pattern) |
            t.answer.like(pattern),
      );
    }

    q.orderBy([
      (t) => drift.OrderingTerm(
        expression: t.updatedAt,
        mode: drift.OrderingMode.desc,
      ),
    ]);
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
    String? areaId,
    String? extractedText,
    Uint8List? documentBytes,
    List<String> tags = const [],
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    var effectiveExtracted = extractedText?.trim();
    if ((effectiveExtracted == null || effectiveExtracted.isEmpty) &&
        documentBytes != null &&
        fileType.trim().toLowerCase() == 'pdf') {
      final parsed = PdfTextExtractor.extractText(documentBytes).trim();
      if (parsed.isNotEmpty) effectiveExtracted = parsed;
    }

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
      areaId: drift.Value(areaId),
      extractedText: drift.Value(effectiveExtracted),
      tags: drift.Value(jsonEncode(tags)),
      createdAt: now,
      updatedAt: now,
    );

    await db.into(db.knowledgeDocuments).insert(companion);
    await _recordSyncQueue(id, 'knowledge_documents', 'INSERT');
    await KnowledgeSearchIndex.syncEntity(
      db,
      entityType: 'document',
      entityId: id,
    );

    return (await (db.select(
      db.knowledgeDocuments,
    )..where((t) => t.id.equals(id))).getSingle());
  }

  Future<void> softDeleteDocument(String id) async {
    final existing = await (db.select(
      db.knowledgeDocuments,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    final now = DateTime.now();
    await (db.update(
      db.knowledgeDocuments,
    )..where((t) => t.id.equals(id))).write(
      KnowledgeDocumentsCompanion(
        deletedAt: drift.Value(now),
        updatedAt: drift.Value(now),
        revision: existing != null
            ? drift.Value(existing.revision + 1)
            : const drift.Value.absent(),
      ),
    );
    await _recordSyncQueue(
      id,
      'knowledge_documents',
      'DELETE',
      baseData: existing?.toJson(),
    );
    await KnowledgeSearchIndex.syncEntity(
      db,
      entityType: 'document',
      entityId: id,
    );
  }

  Future<void> updateDocument(
    String id, {
    String? title,
    String? description,
    String? category,
    String? areaId,
    bool clearAreaId = false,
    String? extractedText,
    List<String>? tags,
  }) async {
    final existing = await (db.select(
      db.knowledgeDocuments,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    final now = DateTime.now();
    final companion = KnowledgeDocumentsCompanion(
      title: title != null
          ? drift.Value(title.trim())
          : const drift.Value.absent(),
      description: description != null
          ? drift.Value(description.trim())
          : const drift.Value.absent(),
      category: category != null
          ? drift.Value(category)
          : const drift.Value.absent(),
      areaId: clearAreaId
          ? const drift.Value(null)
          : (areaId != null ? drift.Value(areaId) : const drift.Value.absent()),
      extractedText: extractedText != null
          ? drift.Value(extractedText.trim())
          : const drift.Value.absent(),
      tags: tags != null
          ? drift.Value(jsonEncode(tags))
          : const drift.Value.absent(),
      updatedAt: drift.Value(now),
      revision: existing != null
          ? drift.Value(existing.revision + 1)
          : const drift.Value.absent(),
    );

    await (db.update(
      db.knowledgeDocuments,
    )..where((t) => t.id.equals(id))).write(companion);
    await _recordSyncQueue(
      id,
      'knowledge_documents',
      'UPDATE',
      baseData: existing?.toJson(),
    );
    await KnowledgeSearchIndex.syncEntity(
      db,
      entityType: 'document',
      entityId: id,
    );
  }

  Stream<List<KnowledgeDocumentEntry>> watchDocuments({
    String? category,
    String? query,
    String? projectId,
    String? areaId,
  }) {
    final q = db.select(db.knowledgeDocuments)
      ..where((t) => t.deletedAt.isNull());

    if (category != null && category.isNotEmpty && category != 'all') {
      q.where((t) => t.category.equals(category));
    } else {
      // Categorias internas de documentos oficiais / templates possuem fluxo próprio
      q.where((t) => t.category.like('official_%').not());
    }
    if (projectId != null && projectId.isNotEmpty) {
      q.where((t) => t.projectId.equals(projectId));
    }
    if (areaId != null && areaId.isNotEmpty) {
      q.where((t) => t.areaId.equals(areaId));
    }
    if (query != null && query.trim().isNotEmpty) {
      final pattern = '%${query.trim()}%';
      q.where(
        (t) =>
            t.title.like(pattern) |
            t.fileName.like(pattern) |
            t.tags.like(pattern) |
            t.extractedText.like(pattern),
      );
    }

    q.orderBy([
      (t) => drift.OrderingTerm(
        expression: t.createdAt,
        mode: drift.OrderingMode.desc,
      ),
    ]);
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
    String? areaId,
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
      areaId: drift.Value(areaId),
      tags: drift.Value(jsonEncode(tags)),
      createdAt: now,
      updatedAt: now,
    );

    await db.into(db.knowledgeResources).insert(companion);
    await _recordSyncQueue(id, 'knowledge_resources', 'INSERT');
    await KnowledgeBacklinkIndexer.reindexLinksForSource(
      db,
      sourceType: 'resource',
      sourceId: id,
      textFields: [description ?? ''],
    );
    await KnowledgeSearchIndex.syncEntity(
      db,
      entityType: 'resource',
      entityId: id,
    );

    return (await (db.select(
      db.knowledgeResources,
    )..where((t) => t.id.equals(id))).getSingle());
  }

  Future<void> softDeleteResource(String id) async {
    final existing = await (db.select(
      db.knowledgeResources,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    final now = DateTime.now();
    await (db.update(
      db.knowledgeResources,
    )..where((t) => t.id.equals(id))).write(
      KnowledgeResourcesCompanion(
        deletedAt: drift.Value(now),
        updatedAt: drift.Value(now),
        revision: existing != null
            ? drift.Value(existing.revision + 1)
            : const drift.Value.absent(),
      ),
    );
    await _recordSyncQueue(
      id,
      'knowledge_resources',
      'DELETE',
      baseData: existing?.toJson(),
    );
    await KnowledgeBacklinkIndexer.softDeleteLinksForSource(
      db,
      sourceType: 'resource',
      sourceId: id,
    );
    await KnowledgeSearchIndex.syncEntity(
      db,
      entityType: 'resource',
      entityId: id,
    );
  }

  Future<void> updateResource(
    String id, {
    String? title,
    String? resourceType,
    String? url,
    String? description,
    String? category,
    String? areaId,
    bool clearAreaId = false,
    List<String>? tags,
  }) async {
    final existing = await (db.select(
      db.knowledgeResources,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    final now = DateTime.now();
    final companion = KnowledgeResourcesCompanion(
      title: title != null
          ? drift.Value(title.trim())
          : const drift.Value.absent(),
      resourceType: resourceType != null
          ? drift.Value(resourceType)
          : const drift.Value.absent(),
      url: url != null ? drift.Value(url.trim()) : const drift.Value.absent(),
      description: description != null
          ? drift.Value(description.trim())
          : const drift.Value.absent(),
      category: category != null
          ? drift.Value(category)
          : const drift.Value.absent(),
      areaId: clearAreaId
          ? const drift.Value(null)
          : (areaId != null ? drift.Value(areaId) : const drift.Value.absent()),
      tags: tags != null
          ? drift.Value(jsonEncode(tags))
          : const drift.Value.absent(),
      updatedAt: drift.Value(now),
      revision: existing != null
          ? drift.Value(existing.revision + 1)
          : const drift.Value.absent(),
    );

    await (db.update(
      db.knowledgeResources,
    )..where((t) => t.id.equals(id))).write(companion);
    await _recordSyncQueue(
      id,
      'knowledge_resources',
      'UPDATE',
      baseData: existing?.toJson(),
    );
    final updated = await (db.select(
      db.knowledgeResources,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (updated != null && updated.deletedAt == null) {
      await KnowledgeBacklinkIndexer.reindexLinksForSource(
        db,
        sourceType: 'resource',
        sourceId: id,
        textFields: [updated.description ?? ''],
      );
      await KnowledgeSearchIndex.syncEntity(
        db,
        entityType: 'resource',
        entityId: id,
      );
    }
  }

  Stream<List<KnowledgeResourceEntry>> watchResources({
    String? resourceType,
    String? category,
    String? query,
    String? areaId,
  }) {
    final q = db.select(db.knowledgeResources)
      ..where((t) => t.deletedAt.isNull());

    if (resourceType != null &&
        resourceType.isNotEmpty &&
        resourceType != 'all') {
      q.where((t) => t.resourceType.equals(resourceType));
    }
    if (category != null && category.isNotEmpty && category != 'all') {
      q.where((t) => t.category.equals(category));
    } else {
      // Categorias internas de documentos oficiais / templates possuem fluxo próprio
      q.where((t) => t.category.like('official_%').not());
    }
    if (areaId != null && areaId.isNotEmpty) {
      q.where((t) => t.areaId.equals(areaId));
    }
    if (query != null && query.trim().isNotEmpty) {
      final pattern = '%${query.trim()}%';
      q.where(
        (t) =>
            t.title.like(pattern) |
            t.description.like(pattern) |
            t.tags.like(pattern),
      );
    }

    q.orderBy([
      (t) => drift.OrderingTerm(
        expression: t.createdAt,
        mode: drift.OrderingMode.desc,
      ),
    ]);
    return q.watch();
  }

  // ==========================================
  // BUSCA UNIFICADA FTS5 / WEB PWA (GLOBAL KNOWLEDGE SEARCH)
  // ==========================================

  Future<List<KnowledgeSearchResult>> searchKnowledge(
    String rawQuery, {
    String? areaId,
    int limit = 30,
  }) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return [];
    return KnowledgeSearchIndex.search(db, query, limit: limit, areaId: areaId);
  }

  Future<void> _recordSyncQueue(
    String entityId,
    String entityType,
    String operation, {
    Map<String, dynamic>? baseData,
  }) async {
    try {
      final now = DateTime.now();
      Map<String, dynamic>? rowJson;
      switch (entityType) {
        case 'knowledge_areas':
          final row = await (db.select(
            db.knowledgeAreas,
          )..where((t) => t.id.equals(entityId))).getSingleOrNull();
          rowJson = row?.toJson();
          break;
        case 'knowledge_notes':
          final row = await (db.select(
            db.knowledgeNotes,
          )..where((t) => t.id.equals(entityId))).getSingleOrNull();
          rowJson = row?.toJson();
          break;
        case 'knowledge_questions':
          final row = await (db.select(
            db.knowledgeQuestions,
          )..where((t) => t.id.equals(entityId))).getSingleOrNull();
          rowJson = row?.toJson();
          break;
        case 'knowledge_documents':
          final row = await (db.select(
            db.knowledgeDocuments,
          )..where((t) => t.id.equals(entityId))).getSingleOrNull();
          rowJson = row?.toJson();
          break;
        case 'knowledge_resources':
          final row = await (db.select(
            db.knowledgeResources,
          )..where((t) => t.id.equals(entityId))).getSingleOrNull();
          rowJson = row?.toJson();
          break;
      }

      final payloadMap = rowJson != null
          ? SyncTimestamp.normalizeMapDates(rowJson)
          : <String, dynamic>{
              'id': entityId,
              'created_at': now.toUtc().toIso8601String(),
            };
      if (baseData != null) {
        payloadMap['_base'] = SyncTimestamp.normalizeMapDates(baseData);
      }

      await db
          .into(db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: _uuid.v4(),
              entityType: entityType,
              entityId: entityId,
              operation: operation,
              payload: jsonEncode(payloadMap),
              createdAt: now,
            ),
          );
    } catch (e, st) {
      AppLogger.error(
        'Erro ao enfileirar mutação de Conhecimento ($entityType/$entityId)',
        e,
        st,
      );
    }
  }
}
