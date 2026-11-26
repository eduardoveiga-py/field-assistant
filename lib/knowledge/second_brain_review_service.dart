import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../core/app_logger.dart';
import '../core/sync_timestamp.dart';
import '../database/app_database.dart';
import 'knowledge_backlink_indexer.dart';
import 'knowledge_search_index.dart';
import 'notion_import_parser.dart';

/// Qualidade de recordação na Revisão Espaçada (SM-2 adaptado).
enum ReviewQuality {
  again('Revisar Novamente'),
  hard('Difícil'),
  good('Bom'),
  easy('Fácil');

  final String label;
  const ReviewQuality(this.label);
}

/// Instantâneo consolidado da Revisão Semanal (GTD + P.A.R.A. + SM-2).
class WeeklyReviewSnapshot {
  final List<InboxEntry> unprocessedInbox;
  final List<KnowledgeNoteEntry> dueReviewNotes;
  final List<KnowledgeQuestionEntry> dueReviewQuestions;
  final List<KnowledgeQuestionEntry> unansweredQuestions;
  final List<ProjectEntry> stalledActiveProjects;
  final List<AppointmentEntry> upcomingAppointments;

  const WeeklyReviewSnapshot({
    required this.unprocessedInbox,
    required this.dueReviewNotes,
    required this.dueReviewQuestions,
    required this.unansweredQuestions,
    required this.stalledActiveProjects,
    required this.upcomingAppointments,
  });

  int get totalDueSpacedReviews =>
      dueReviewNotes.length + dueReviewQuestions.length;

  int get totalActionableItems =>
      unprocessedInbox.length +
      dueReviewNotes.length +
      dueReviewQuestions.length +
      unansweredQuestions.length +
      stalledActiveProjects.length;
}

class NotionImportCommitResult {
  final int createdAreas;
  final int reusedAreas;
  final int importedNotes;
  final int rewrittenLinksCount;
  final List<String> warnings;

  const NotionImportCommitResult({
    required this.createdAreas,
    required this.reusedAreas,
    required this.importedNotes,
    required this.rewrittenLinksCount,
    this.warnings = const [],
  });
}

/// Serviço de Revisão Semanal, Revisão Espaçada (SM-2 Lite) e Importação em Lote do Notion.
class SecondBrainReviewService {
  SecondBrainReviewService._();

  static const Uuid _uuid = Uuid();
  static const List<int> spacedIntervalsDays = [1, 3, 7, 14, 30, 60];

  static ({int nextLevel, int intervalDays, DateTime nextReviewAt})
  computeNextSchedule(
    int currentLevel,
    ReviewQuality quality, {
    DateTime? now,
  }) {
    final baseNow = (now ?? DateTime.now()).toUtc();
    final safeCurrent = currentLevel.clamp(0, spacedIntervalsDays.length - 1);
    final int nextLevel;
    final int days;

    switch (quality) {
      case ReviewQuality.again:
        nextLevel = 0;
        days = 1;
        break;
      case ReviewQuality.hard:
        nextLevel = safeCurrent;
        days = math.max(1, (spacedIntervalsDays[safeCurrent] / 2).round());
        break;
      case ReviewQuality.good:
        nextLevel = math.min(safeCurrent + 1, spacedIntervalsDays.length - 1);
        days = spacedIntervalsDays[nextLevel];
        break;
      case ReviewQuality.easy:
        nextLevel = math.min(safeCurrent + 2, spacedIntervalsDays.length - 1);
        days = spacedIntervalsDays[nextLevel];
        break;
    }

    return (
      nextLevel: nextLevel,
      intervalDays: days,
      nextReviewAt: baseNow.add(Duration(days: days)),
    );
  }

  /// Registra avaliação SM-2 de uma Nota e agenda a próxima revisão com fila de sync.
  static Future<({int nextLevel, DateTime nextReviewAt})?> recordNoteReview(
    AppDatabase db,
    String noteId,
    ReviewQuality quality, {
    DateTime? now,
  }) async {
    final ts = (now ?? DateTime.now()).toUtc();
    return db.transaction(() async {
      final existing =
          await (db.select(db.knowledgeNotes)
                ..where((t) => t.id.equals(noteId) & t.deletedAt.isNull()))
              .getSingleOrNull();
      if (existing == null) return null;

      final schedule = computeNextSchedule(
        existing.reviewLevel,
        quality,
        now: ts,
      );
      await (db.update(
        db.knowledgeNotes,
      )..where((t) => t.id.equals(noteId))).write(
        KnowledgeNotesCompanion(
          reviewLevel: drift.Value(schedule.nextLevel),
          lastReviewedAt: drift.Value(ts),
          nextReviewAt: drift.Value(schedule.nextReviewAt),
          updatedAt: drift.Value(ts),
          revision: drift.Value(existing.revision + 1),
        ),
      );
      final updated = await (db.select(
        db.knowledgeNotes,
      )..where((t) => t.id.equals(noteId))).getSingle();
      await _enqueueRowSync(
        db,
        entityType: 'knowledge_notes',
        entityId: noteId,
        operation: 'UPDATE',
        rowJson: updated.toJson(),
        baseJson: existing.toJson(),
      );
      return (
        nextLevel: schedule.nextLevel,
        nextReviewAt: schedule.nextReviewAt,
      );
    });
  }

  /// Registra avaliação SM-2 de uma Dúvida Bíblica e agenda a próxima revisão.
  static Future<({int nextLevel, DateTime nextReviewAt})?> recordQuestionReview(
    AppDatabase db,
    String questionId,
    ReviewQuality quality, {
    DateTime? now,
  }) async {
    final ts = (now ?? DateTime.now()).toUtc();
    return db.transaction(() async {
      final existing =
          await (db.select(db.knowledgeQuestions)
                ..where((t) => t.id.equals(questionId) & t.deletedAt.isNull()))
              .getSingleOrNull();
      if (existing == null) return null;

      final schedule = computeNextSchedule(
        existing.reviewLevel,
        quality,
        now: ts,
      );
      await (db.update(
        db.knowledgeQuestions,
      )..where((t) => t.id.equals(questionId))).write(
        KnowledgeQuestionsCompanion(
          reviewLevel: drift.Value(schedule.nextLevel),
          lastReviewedAt: drift.Value(ts),
          nextReviewAt: drift.Value(schedule.nextReviewAt),
          updatedAt: drift.Value(ts),
          revision: drift.Value(existing.revision + 1),
        ),
      );
      final updated = await (db.select(
        db.knowledgeQuestions,
      )..where((t) => t.id.equals(questionId))).getSingle();
      await _enqueueRowSync(
        db,
        entityType: 'knowledge_questions',
        entityId: questionId,
        operation: 'UPDATE',
        rowJson: updated.toJson(),
        baseJson: existing.toJson(),
      );
      return (
        nextLevel: schedule.nextLevel,
        nextReviewAt: schedule.nextReviewAt,
      );
    });
  }

  /// Ativa ou pausa a revisão espaçada de uma Nota ou Dúvida.
  static Future<void> setSpacedReviewEnabled(
    AppDatabase db, {
    required String entityType,
    required String entityId,
    required bool enabled,
    DateTime? firstReviewAt,
  }) async {
    final now = DateTime.now().toUtc();
    final nextDue = enabled ? (firstReviewAt ?? now).toUtc() : null;

    await db.transaction(() async {
      if (entityType == 'note' || entityType == 'knowledge_notes') {
        final existing =
            await (db.select(db.knowledgeNotes)
                  ..where((t) => t.id.equals(entityId) & t.deletedAt.isNull()))
                .getSingleOrNull();
        if (existing == null) return;
        await (db.update(
          db.knowledgeNotes,
        )..where((t) => t.id.equals(entityId))).write(
          KnowledgeNotesCompanion(
            nextReviewAt: drift.Value(nextDue),
            updatedAt: drift.Value(now),
            revision: drift.Value(existing.revision + 1),
          ),
        );
        final updated = await (db.select(
          db.knowledgeNotes,
        )..where((t) => t.id.equals(entityId))).getSingle();
        await _enqueueRowSync(
          db,
          entityType: 'knowledge_notes',
          entityId: entityId,
          operation: 'UPDATE',
          rowJson: updated.toJson(),
          baseJson: existing.toJson(),
        );
      } else if (entityType == 'question' ||
          entityType == 'knowledge_questions') {
        final existing =
            await (db.select(db.knowledgeQuestions)
                  ..where((t) => t.id.equals(entityId) & t.deletedAt.isNull()))
                .getSingleOrNull();
        if (existing == null) return;
        await (db.update(
          db.knowledgeQuestions,
        )..where((t) => t.id.equals(entityId))).write(
          KnowledgeQuestionsCompanion(
            nextReviewAt: drift.Value(nextDue),
            updatedAt: drift.Value(now),
            revision: drift.Value(existing.revision + 1),
          ),
        );
        final updated = await (db.select(
          db.knowledgeQuestions,
        )..where((t) => t.id.equals(entityId))).getSingle();
        await _enqueueRowSync(
          db,
          entityType: 'knowledge_questions',
          entityId: entityId,
          operation: 'UPDATE',
          rowJson: updated.toJson(),
          baseJson: existing.toJson(),
        );
      }
    });
  }

  /// Carrega o painel completo da Revisão Semanal (Inbox pendente, revisões SM-2 vencidas,
  /// dúvidas em aberto, projetos ativos sem próxima ação e agenda de 7 dias).
  static Future<WeeklyReviewSnapshot> loadWeeklyReview(
    AppDatabase db, {
    DateTime? now,
  }) async {
    final currentNow = (now ?? DateTime.now()).toUtc();
    final localNow = currentNow.toLocal();
    final startOfToday = DateTime(localNow.year, localNow.month, localNow.day);
    final next7Days = startOfToday.add(const Duration(days: 7));

    final unprocessedInbox =
        await (db.select(db.inboxEntries)
              ..where(
                (t) =>
                    t.deletedAt.isNull() &
                    t.status.isIn(['unprocessed', 'in_review']),
              )
              ..orderBy([
                (t) => drift.OrderingTerm(
                  expression: t.capturedAt,
                  mode: drift.OrderingMode.desc,
                ),
              ]))
            .get();

    final dueNotesRaw =
        await (db.select(db.knowledgeNotes)
              ..where(
                (t) =>
                    t.deletedAt.isNull() &
                    t.nextReviewAt.isNotNull() &
                    t.nextReviewAt.isSmallerOrEqualValue(currentNow) &
                    t.category.like('official_%').not(),
              )
              ..orderBy([
                (t) => drift.OrderingTerm(
                  expression: t.nextReviewAt,
                  mode: drift.OrderingMode.asc,
                ),
              ]))
            .get();

    final dueQuestions =
        await (db.select(db.knowledgeQuestions)
              ..where(
                (t) =>
                    t.deletedAt.isNull() &
                    t.nextReviewAt.isNotNull() &
                    t.nextReviewAt.isSmallerOrEqualValue(currentNow),
              )
              ..orderBy([
                (t) => drift.OrderingTerm(
                  expression: t.nextReviewAt,
                  mode: drift.OrderingMode.asc,
                ),
              ]))
            .get();

    final unansweredQuestions =
        await (db.select(db.knowledgeQuestions)
              ..where(
                (t) =>
                    t.deletedAt.isNull() &
                    t.status.isIn(['unanswered', 'researching']) &
                    t.category.like('official_%').not(),
              )
              ..orderBy([
                (t) => drift.OrderingTerm(
                  expression: t.updatedAt,
                  mode: drift.OrderingMode.desc,
                ),
              ]))
            .get();

    final activeProjects =
        await (db.select(db.projects)..where(
              (t) =>
                  t.deletedAt.isNull() & t.status.isIn(['planning', 'active']),
            ))
            .get();
    final activeTasks =
        await (db.select(db.tasks)..where(
              (t) =>
                  t.deletedAt.isNull() &
                  t.projectId.isNotNull() &
                  t.status.isIn(['completed', 'cancelled']).not(),
            ))
            .get();
    final projectsWithPendingTask = <String>{
      for (final task in activeTasks)
        if (task.projectId != null) task.projectId!,
    };
    final stalledProjects = activeProjects
        .where((p) => !projectsWithPendingTask.contains(p.id))
        .toList();

    final upcomingAppointments =
        await (db.select(db.appointments)
              ..where(
                (t) =>
                    t.deletedAt.isNull() &
                    t.status.isIn(['cancelado', 'cancelled']).not() &
                    t.startTime.isBiggerOrEqualValue(startOfToday) &
                    t.startTime.isSmallerOrEqualValue(next7Days),
              )
              ..orderBy([
                (t) => drift.OrderingTerm(
                  expression: t.startTime,
                  mode: drift.OrderingMode.asc,
                ),
              ]))
            .get();

    return WeeklyReviewSnapshot(
      unprocessedInbox: unprocessedInbox,
      dueReviewNotes: dueNotesRaw,
      dueReviewQuestions: dueQuestions,
      unansweredQuestions: unansweredQuestions,
      stalledActiveProjects: stalledProjects,
      upcomingAppointments: upcomingAppointments,
    );
  }

  /// Persiste atomicamente um pacote analisado do Notion (Áreas + Subpáginas + Links + FTS5 + SyncQueue).
  static Future<NotionImportCommitResult> commitNotionPackage(
    AppDatabase db,
    ParsedNotionPackage package, {
    String? fallbackAreaId,
  }) async {
    final now = DateTime.now().toUtc();
    var createdAreas = 0;
    var reusedAreas = 0;
    var importedNotes = 0;

    final areaIdMap = <String, String>{};
    final insertedNoteIds = <String>[];

    await db.transaction(() async {
      final existingAreas = await (db.select(
        db.knowledgeAreas,
      )..where((t) => t.deletedAt.isNull())).get();
      final existingByLowerName = <String, KnowledgeAreaEntry>{
        for (final a in existingAreas) a.name.trim().toLowerCase(): a,
      };
      var nextSortOrder = existingAreas.length;

      for (final parsedArea in package.areas) {
        final key = parsedArea.name.trim().toLowerCase();
        final match = existingByLowerName[key];
        if (match != null) {
          areaIdMap[parsedArea.id] = match.id;
          reusedAreas++;
        } else {
          await db
              .into(db.knowledgeAreas)
              .insert(
                KnowledgeAreasCompanion.insert(
                  id: parsedArea.id,
                  name: parsedArea.name.trim(),
                  colorHex: drift.Value(parsedArea.colorHex),
                  iconName: const drift.Value('layers'),
                  sortOrder: drift.Value(nextSortOrder++),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          final row = await (db.select(
            db.knowledgeAreas,
          )..where((t) => t.id.equals(parsedArea.id))).getSingle();
          await _enqueueRowSync(
            db,
            entityType: 'knowledge_areas',
            entityId: parsedArea.id,
            operation: 'INSERT',
            rowJson: row.toJson(),
          );
          areaIdMap[parsedArea.id] = parsedArea.id;
          existingByLowerName[key] = row;
          createdAreas++;
        }
      }

      // Garante ordem topológica pai -> filho caso o parser venha em outra ordem
      final insertedIds = <String>{};
      final pending = List<ParsedNotionNote>.from(package.notes);
      var guard = 0;
      while (pending.isNotEmpty && guard < package.notes.length * 2) {
        guard++;
        final batch = List<ParsedNotionNote>.from(pending);
        for (final note in batch) {
          final parentReady =
              note.parentNoteId == null ||
              insertedIds.contains(note.parentNoteId) ||
              !pending.any((other) => other.id == note.parentNoteId);
          if (!parentReady) continue;

          final resolvedAreaId = note.areaId != null
              ? (areaIdMap[note.areaId!] ?? note.areaId)
              : fallbackAreaId;

          await db
              .into(db.knowledgeNotes)
              .insertOnConflictUpdate(
                KnowledgeNotesCompanion.insert(
                  id: note.id,
                  title: note.title.trim().isEmpty
                      ? 'Nota Importada'
                      : note.title.trim(),
                  content: note.content,
                  category: drift.Value(note.category),
                  tags: drift.Value(jsonEncode(note.tags)),
                  areaId: drift.Value(resolvedAreaId),
                  parentNoteId: drift.Value(note.parentNoteId),
                  propertiesJson: drift.Value(jsonEncode(note.properties)),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          final insertedRow = await (db.select(
            db.knowledgeNotes,
          )..where((t) => t.id.equals(note.id))).getSingle();
          await _enqueueRowSync(
            db,
            entityType: 'knowledge_notes',
            entityId: note.id,
            operation: 'INSERT',
            rowJson: insertedRow.toJson(),
          );

          insertedIds.add(note.id);
          insertedNoteIds.add(note.id);
          pending.remove(note);
          importedNotes++;
        }
      }
    });

    // Atualiza backlinks e FTS5 para todas as notas importadas
    for (final noteId in insertedNoteIds) {
      final note = await (db.select(
        db.knowledgeNotes,
      )..where((t) => t.id.equals(noteId))).getSingleOrNull();
      if (note != null) {
        await KnowledgeBacklinkIndexer.reindexLinksForSource(
          db,
          sourceType: 'note',
          sourceId: note.id,
          textFields: [note.content],
        );
        await KnowledgeSearchIndex.syncEntity(
          db,
          entityType: 'note',
          entityId: note.id,
        );
      }
    }

    return NotionImportCommitResult(
      createdAreas: createdAreas,
      reusedAreas: reusedAreas,
      importedNotes: importedNotes,
      rewrittenLinksCount: package.rewrittenLinksCount,
      warnings: package.warnings,
    );
  }

  static Future<void> _enqueueRowSync(
    AppDatabase db, {
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> rowJson,
    Map<String, dynamic>? baseJson,
  }) async {
    try {
      final payloadMap = SyncTimestamp.normalizeMapDates(rowJson);
      if (baseJson != null) {
        payloadMap['_base'] = SyncTimestamp.normalizeMapDates(baseJson);
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
              createdAt: DateTime.now().toUtc(),
            ),
          );
    } catch (e, st) {
      AppLogger.error(
        'Erro ao enfileirar mutação de Revisão/Notion ($entityType/$entityId)',
        e,
        st,
      );
    }
  }
}
