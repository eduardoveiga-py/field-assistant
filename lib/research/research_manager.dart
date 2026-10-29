import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../ui/providers.dart';

class ResearchArticleItem {
  final String id;
  final String title;
  final String summary; // Pequeno resumo exibido no bloco
  final String content; // Conteúdo completo do artigo
  final List<String> tags;
  final List<String> attachments; // URLs / Data URIs
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
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ResearchArticleItem.fromMap(Map<String, dynamic> map) {
    List<String> parsedTags = [];
    try {
      final raw = map['tags'];
      if (raw != null) {
        final decoded = jsonDecode(raw as String);
        if (decoded is List) {
          parsedTags = decoded.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {}

    List<String> parsedAttach = [];
    try {
      final raw = map['attachments'];
      if (raw != null) {
        final decoded = jsonDecode(raw as String);
        if (decoded is List) {
          parsedAttach = decoded.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {}

    return ResearchArticleItem(
      id: map['id'] as String,
      title: map['title'] as String,
      summary: map['summary'] as String,
      content: map['content'] as String,
      tags: parsedTags,
      attachments: parsedAttach,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
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

  factory ResearchTagItem.fromMap(Map<String, dynamic> map) => ResearchTagItem(
        id: map['id'] as String,
        name: map['name'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class ResearchManager {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();
  final StreamController<List<ResearchArticleItem>> _articlesController = StreamController<List<ResearchArticleItem>>.broadcast();
  final StreamController<List<ResearchTagItem>> _tagsController = StreamController<List<ResearchTagItem>>.broadcast();
  Future<void>? _initFuture;

  ResearchManager(this.db) {
    _initTable();
  }

  Future<void> _initTable() {
    _initFuture ??= _doInitTable();
    return _initFuture!;
  }

  Future<void> _doInitTable() async {
    try {
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS research_articles (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          summary TEXT NOT NULL,
          content TEXT NOT NULL,
          tags TEXT NOT NULL DEFAULT '[]',
          attachments TEXT NOT NULL DEFAULT '[]',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
      ''');

      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS research_tags (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          created_at TEXT NOT NULL
        );
      ''');

      // Inicializa tags padrão se a tabela estiver vazia
      final existingCount = await db.customSelect('SELECT COUNT(*) AS count FROM research_tags').getSingle();
      if (existingCount.read<int>('count') == 0) {
        final now = DateTime.now();
        final defaultTags = [
          'Criação',
          'Trindade',
          'Alma e Morte',
          'Reino de Deus',
          'Profecias Bíblicas',
          'Por que Deus permite o sofrimento',
          'Cruz ou Estaca',
        ];
        for (final tag in defaultTags) {
          await db.customInsert(
            'INSERT INTO research_tags (id, name, created_at) VALUES (?, ?, ?)',
            variables: [Variable.withString(_uuid.v4()), Variable.withString(tag), Variable.withString(now.toIso8601String())],
          );
        }
      }

      _refreshArticles();
      _refreshTags();
    } catch (_) {}
  }

  Future<void> _refreshArticles() async {
    try {
      final list = await getAllArticles();
      if (!_articlesController.isClosed) {
        _articlesController.add(list);
      }
    } catch (_) {}
  }

  Future<void> _refreshTags() async {
    try {
      final list = await getAllTags();
      if (!_tagsController.isClosed) {
        _tagsController.add(list);
      }
    } catch (_) {}
  }

  Future<List<ResearchArticleItem>> getAllArticles() async {
    await _initTable();
    try {
      final rows = await db.customSelect('SELECT * FROM research_articles ORDER BY created_at DESC').get();
      return rows.map((r) => ResearchArticleItem.fromMap(r.data)).toList();
    } catch (_) {
      return [];
    }
  }

  Stream<List<ResearchArticleItem>> watchArticles() async* {
    yield await getAllArticles();
    yield* _articlesController.stream;
  }

  Future<List<ResearchTagItem>> getAllTags() async {
    await _initTable();
    try {
      final rows = await db.customSelect('SELECT * FROM research_tags ORDER BY name ASC').get();
      return rows.map((r) => ResearchTagItem.fromMap(r.data)).toList();
    } catch (_) {
      return [];
    }
  }

  Stream<List<ResearchTagItem>> watchTags() async* {
    yield await getAllTags();
    yield* _tagsController.stream;
  }

  Future<ResearchArticleItem> addArticle({
    required String title,
    required String summary,
    required String content,
    List<String> tags = const [],
    List<String> attachments = const [],
  }) async {
    await _initTable();
    final now = DateTime.now();
    final id = _uuid.v4();

    await db.customInsert(
      'INSERT INTO research_articles (id, title, summary, content, tags, attachments, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(id),
        Variable.withString(title.trim()),
        Variable.withString(summary.trim()),
        Variable.withString(content.trim()),
        Variable.withString(jsonEncode(tags)),
        Variable.withString(jsonEncode(attachments)),
        Variable.withString(now.toIso8601String()),
        Variable.withString(now.toIso8601String()),
      ],
    );

    final item = ResearchArticleItem(
      id: id,
      title: title.trim(),
      summary: summary.trim(),
      content: content.trim(),
      tags: tags,
      attachments: attachments,
      createdAt: now,
      updatedAt: now,
    );

    await _refreshArticles();
    return item;
  }

  Future<void> updateArticle(ResearchArticleItem item) async {
    await _initTable();
    final now = DateTime.now();
    await db.customUpdate(
      'UPDATE research_articles SET title = ?, summary = ?, content = ?, tags = ?, attachments = ?, updated_at = ? WHERE id = ?',
      variables: [
        Variable.withString(item.title.trim()),
        Variable.withString(item.summary.trim()),
        Variable.withString(item.content.trim()),
        Variable.withString(jsonEncode(item.tags)),
        Variable.withString(jsonEncode(item.attachments)),
        Variable.withString(now.toIso8601String()),
        Variable.withString(item.id),
      ],
    );
    await _refreshArticles();
  }

  Future<void> deleteArticle(String id) async {
    await _initTable();
    await db.customUpdate('DELETE FROM research_articles WHERE id = ?', variables: [Variable.withString(id)]);
    await _refreshArticles();
  }

  // GERENCIAMENTO DE TAGS
  Future<ResearchTagItem> addTag(String name) async {
    await _initTable();
    final trimmed = name.trim();
    final id = _uuid.v4();
    final now = DateTime.now();

    await db.customInsert(
      'INSERT OR IGNORE INTO research_tags (id, name, created_at) VALUES (?, ?, ?)',
      variables: [Variable.withString(id), Variable.withString(trimmed), Variable.withString(now.toIso8601String())],
    );

    final item = ResearchTagItem(id: id, name: trimmed, createdAt: now);
    await _refreshTags();
    return item;
  }

  Future<void> updateTag(String id, String newName) async {
    await _initTable();
    final trimmed = newName.trim();
    final old = await db.customSelect('SELECT name FROM research_tags WHERE id = ?', variables: [Variable.withString(id)]).getSingleOrNull();
    final oldName = old?.read<String>('name');

    await db.customUpdate(
      'UPDATE research_tags SET name = ? WHERE id = ?',
      variables: [Variable.withString(trimmed), Variable.withString(id)],
    );

    // Se o nome mudou, atualiza nos artigos que possuem essa tag
    if (oldName != null && oldName != trimmed) {
      final articles = await getAllArticles();
      for (final a in articles) {
        if (a.tags.contains(oldName)) {
          final newTags = a.tags.map((t) => t == oldName ? trimmed : t).toList();
          await updateArticle(ResearchArticleItem(
            id: a.id,
            title: a.title,
            summary: a.summary,
            content: a.content,
            tags: newTags,
            attachments: a.attachments,
            createdAt: a.createdAt,
            updatedAt: a.updatedAt,
          ));
        }
      }
    }

    await _refreshTags();
  }

  Future<void> deleteTag(String id) async {
    await _initTable();
    final old = await db.customSelect('SELECT name FROM research_tags WHERE id = ?', variables: [Variable.withString(id)]).getSingleOrNull();
    final oldName = old?.read<String>('name');

    await db.customUpdate('DELETE FROM research_tags WHERE id = ?', variables: [Variable.withString(id)]);

    if (oldName != null) {
      final articles = await getAllArticles();
      for (final a in articles) {
        if (a.tags.contains(oldName)) {
          final newTags = a.tags.where((t) => t != oldName).toList();
          await updateArticle(ResearchArticleItem(
            id: a.id,
            title: a.title,
            summary: a.summary,
            content: a.content,
            tags: newTags,
            attachments: a.attachments,
            createdAt: a.createdAt,
            updatedAt: a.updatedAt,
          ));
        }
      }
    }

    await _refreshTags();
  }
}

final researchManagerProvider = Provider<ResearchManager>((ref) {
  final repo = ref.watch(repositoryProvider);
  return ResearchManager(repo.db);
});

final researchArticlesStreamProvider = StreamProvider<List<ResearchArticleItem>>((ref) {
  final mgr = ref.watch(researchManagerProvider);
  return mgr.watchArticles();
});

final researchTagsStreamProvider = StreamProvider<List<ResearchTagItem>>((ref) {
  final mgr = ref.watch(researchManagerProvider);
  return mgr.watchTags();
});
