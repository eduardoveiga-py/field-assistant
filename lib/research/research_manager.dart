import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/app_logger.dart';
import '../core/sync_timestamp.dart';
import '../database/app_database.dart';
import '../ui/providers.dart';

class ResearchArticleItem {
  final String id;
  final String title;
  final String summary;
  final String content;
  final List<String> tags;
  final List<String> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;

  ResearchArticleItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.tags,
    required this.attachments,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'summary': summary,
    'content': content,
    'tags': jsonEncode(tags),
    'attachments': jsonEncode(attachments),
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory ResearchArticleItem.fromEntry(ResearchArticleEntry e) {
    return ResearchArticleItem(
      id: e.id,
      title: e.title,
      summary: e.summary,
      content: e.content,
      tags: _decodeStringList(e.tags),
      attachments: _decodeStringList(e.attachments),
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
    );
  }

  factory ResearchArticleItem.fromMap(Map<String, dynamic> map) {
    return ResearchArticleItem(
      id: map['id'] as String,
      title: map['title'] as String,
      summary: map['summary'] as String,
      content: map['content'] as String,
      tags: _decodeStringList(map['tags']),
      attachments: _decodeStringList(map['attachments']),
      createdAt:
          SyncTimestamp.parse(map['created_at'] ?? map['createdAt']) ??
          DateTime.now(),
      updatedAt:
          SyncTimestamp.parse(map['updated_at'] ?? map['updatedAt']) ??
          DateTime.now(),
    );
  }

  static List<String> _decodeStringList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (e, st) {
        AppLogger.warning('Falha ao decodificar lista JSON em ResearchArticle', e, st);
      }
    }
    return [];
  }
}

class ResearchTagItem {
  final String id;
  final String name;
  final DateTime createdAt;

  ResearchTagItem({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory ResearchTagItem.fromEntry(ResearchTagEntry e) => ResearchTagItem(
    id: e.id,
    name: e.name,
    createdAt: e.createdAt,
  );

  factory ResearchTagItem.fromMap(Map<String, dynamic> map) => ResearchTagItem(
    id: map['id'] as String,
    name: map['name'] as String,
    createdAt:
        SyncTimestamp.parse(map['created_at'] ?? map['createdAt']) ??
        DateTime.now(),
  );
}

class ResearchManager {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();
  bool _tagsSeedChecked = false;

  ResearchManager(this.db);

  Future<void> _ensureDefaultTags() async {
    if (_tagsSeedChecked) return;
    _tagsSeedChecked = true;
    final existing = await db.select(db.researchTags).get();
    if (existing.isEmpty) {
      final now = DateTime.now();
      const defaultTags = [
        'Criação',
        'Trindade',
        'Alma e Morte',
        'Reino de Deus',
        'Profecias Bíblicas',
        'Por que Deus permite o sofrimento',
        'Cruz ou Estaca',
      ];
      await db.transaction(() async {
        for (final tag in defaultTags) {
          await db.into(db.researchTags).insert(
            ResearchTagsCompanion.insert(
              id: _uuid.v4(),
              name: tag,
              createdAt: now,
              updatedAt: Value(now),
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      });
    }
  }

  Future<List<ResearchArticleItem>> getAllArticles() async {
    final rows =
        await (db.select(db.researchArticles)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();
    return rows.map(ResearchArticleItem.fromEntry).toList();
  }

  Stream<List<ResearchArticleItem>> watchArticles() {
    return (db.select(db.researchArticles)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map(ResearchArticleItem.fromEntry).toList());
  }

  Future<List<ResearchTagItem>> getAllTags() async {
    await _ensureDefaultTags();
    final rows =
        await (db.select(db.researchTags)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .get();
    return rows.map(ResearchTagItem.fromEntry).toList();
  }

  Stream<List<ResearchTagItem>> watchTags() async* {
    await _ensureDefaultTags();
    yield* (db.select(db.researchTags)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch()
        .map((rows) => rows.map(ResearchTagItem.fromEntry).toList());
  }

  Future<ResearchArticleItem> addArticle({
    required String title,
    required String summary,
    required String content,
    List<String> tags = const [],
    List<String> attachments = const [],
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();

    final entry = ResearchArticleEntry(
      id: id,
      title: title.trim(),
      summary: summary.trim(),
      content: content.trim(),
      tags: jsonEncode(tags),
      attachments: jsonEncode(attachments),
      objective: null,
      status: 'active',
      conclusion: null,
      projectId: null,
      mainQuestionId: null,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      revision: 1,
    );

    await db.transaction(() async {
      await db.into(db.researchArticles).insert(entry);
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'research_articles',
          entityId: id,
          operation: 'INSERT',
          payload: jsonEncode(SyncTimestamp.normalizeMapDates(entry.toJson())),
          createdAt: now,
          status: const Value('pending'),
        ),
      );
    });

    return ResearchArticleItem.fromEntry(entry);
  }

  Future<void> updateArticle(ResearchArticleItem item) async {
    final now = DateTime.now();
    final existing = await (db.select(db.researchArticles)
          ..where((t) => t.id.equals(item.id)))
        .getSingleOrNull();
    final updated = ResearchArticleEntry(
      id: item.id,
      title: item.title.trim(),
      summary: item.summary.trim(),
      content: item.content.trim(),
      tags: jsonEncode(item.tags),
      attachments: jsonEncode(item.attachments),
      objective: existing?.objective,
      status: existing?.status ?? 'active',
      conclusion: existing?.conclusion,
      projectId: existing?.projectId,
      mainQuestionId: existing?.mainQuestionId,
      createdAt: existing?.createdAt ?? item.createdAt,
      updatedAt: now,
      deletedAt: existing?.deletedAt,
      revision: (existing?.revision ?? 1) + 1,
    );

    await db.transaction(() async {
      await db.update(db.researchArticles).replace(updated);
      final payload = SyncTimestamp.normalizeMapDates(updated.toJson());
      if (existing != null) {
        payload['_base'] = SyncTimestamp.normalizeMapDates(existing.toJson());
      }
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'research_articles',
          entityId: item.id,
          operation: 'UPDATE',
          payload: jsonEncode(payload),
          createdAt: now,
          status: const Value('pending'),
        ),
      );
    });
  }

  Future<void> deleteArticle(String id) async {
    final now = DateTime.now();
    final existing = await (db.select(db.researchArticles)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) return;

    final nextRev = existing.revision + 1;
    await db.transaction(() async {
      await (db.update(db.researchArticles)..where((t) => t.id.equals(id)))
          .write(
        ResearchArticlesCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          revision: Value(nextRev),
        ),
      );
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'research_articles',
          entityId: id,
          operation: 'DELETE',
          payload: jsonEncode({
            'id': id,
            'deleted_at': now.toUtc().toIso8601String(),
            'updated_at': now.toUtc().toIso8601String(),
            'revision': nextRev,
          }),
          createdAt: now,
          status: const Value('pending'),
        ),
      );
    });
  }

  // GERENCIAMENTO DE TAGS
  Future<ResearchTagItem> addTag(String name) async {
    final trimmed = name.trim();
    final now = DateTime.now();
    final existingActive = await (db.select(db.researchTags)
          ..where((t) => t.name.equals(trimmed) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (existingActive != null) {
      return ResearchTagItem.fromEntry(existingActive);
    }

    final id = _uuid.v4();
    final entry = ResearchTagEntry(
      id: id,
      name: trimmed,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      revision: 1,
    );

    await db.transaction(() async {
      await db.into(db.researchTags).insert(entry);
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'research_tags',
          entityId: id,
          operation: 'INSERT',
          payload: jsonEncode(SyncTimestamp.normalizeMapDates(entry.toJson())),
          createdAt: now,
          status: const Value('pending'),
        ),
      );
    });

    return ResearchTagItem.fromEntry(entry);
  }

  Future<void> updateTag(String id, String newName) async {
    final trimmed = newName.trim();
    final now = DateTime.now();
    final existing = await (db.select(db.researchTags)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) return;
    final oldName = existing.name;

    final updated = existing.copyWith(
      name: trimmed,
      updatedAt: Value(now),
      revision: existing.revision + 1,
    );

    await db.transaction(() async {
      await db.update(db.researchTags).replace(updated);
      final payload = SyncTimestamp.normalizeMapDates(updated.toJson());
      payload['_base'] = SyncTimestamp.normalizeMapDates(existing.toJson());
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'research_tags',
          entityId: id,
          operation: 'UPDATE',
          payload: jsonEncode(payload),
          createdAt: now,
          status: const Value('pending'),
        ),
      );
    });

    if (oldName != trimmed) {
      final articles = await getAllArticles();
      for (final a in articles) {
        if (a.tags.contains(oldName)) {
          final newTags = a.tags
              .map((t) => t == oldName ? trimmed : t)
              .toList();
          await updateArticle(
            ResearchArticleItem(
              id: a.id,
              title: a.title,
              summary: a.summary,
              content: a.content,
              tags: newTags,
              attachments: a.attachments,
              createdAt: a.createdAt,
              updatedAt: a.updatedAt,
            ),
          );
        }
      }
    }
  }

  Future<void> deleteTag(String id) async {
    final now = DateTime.now();
    final existing = await (db.select(db.researchTags)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) return;
    final oldName = existing.name;

    final nextRev = existing.revision + 1;
    await db.transaction(() async {
      await (db.update(db.researchTags)..where((t) => t.id.equals(id))).write(
        ResearchTagsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          revision: Value(nextRev),
        ),
      );
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'research_tags',
          entityId: id,
          operation: 'DELETE',
          payload: jsonEncode({
            'id': id,
            'deleted_at': now.toUtc().toIso8601String(),
            'updated_at': now.toUtc().toIso8601String(),
            'revision': nextRev,
          }),
          createdAt: now,
          status: const Value('pending'),
        ),
      );
    });

    final articles = await getAllArticles();
    for (final a in articles) {
      if (a.tags.contains(oldName)) {
        final newTags = a.tags.where((t) => t != oldName).toList();
        await updateArticle(
          ResearchArticleItem(
            id: a.id,
            title: a.title,
            summary: a.summary,
            content: a.content,
            tags: newTags,
            attachments: a.attachments,
            createdAt: a.createdAt,
            updatedAt: a.updatedAt,
          ),
        );
      }
    }
  }
}

final researchManagerProvider = Provider<ResearchManager>((ref) {
  final repo = ref.watch(repositoryProvider);
  return ResearchManager(repo.db);
});

final researchArticlesStreamProvider =
    StreamProvider<List<ResearchArticleItem>>((ref) {
      final mgr = ref.watch(researchManagerProvider);
      return mgr.watchArticles();
    });

final researchTagsStreamProvider = StreamProvider<List<ResearchTagItem>>((ref) {
  final mgr = ref.watch(researchManagerProvider);
  return mgr.watchTags();
});
