import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../ui/providers.dart';

class MinistryExperienceItem {
  final String id;
  final String title;
  final String content;
  final List<String> mediaUrls;
  final List<String> tags;
  final DateTime dateTime;
  final String? locationOrModality;
  final DateTime createdAt;
  final DateTime updatedAt;

  MinistryExperienceItem({
    required this.id,
    required this.title,
    required this.content,
    required this.mediaUrls,
    required this.tags,
    required this.dateTime,
    this.locationOrModality,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'media_urls': jsonEncode(mediaUrls),
        'tags': jsonEncode(tags),
        'date_time': dateTime.toIso8601String(),
        'location_or_modality': locationOrModality,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory MinistryExperienceItem.fromMap(Map<String, dynamic> map) {
    List<String> parsedMedia = [];
    try {
      final raw = map['media_urls'];
      if (raw != null) {
        final decoded = jsonDecode(raw as String);
        if (decoded is List) {
          parsedMedia = decoded.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {}

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

    return MinistryExperienceItem(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      mediaUrls: parsedMedia,
      tags: parsedTags,
      dateTime: DateTime.parse(map['date_time'] as String),
      locationOrModality: map['location_or_modality'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

class ExperienceManager {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();
  final StreamController<List<MinistryExperienceItem>> _controller = StreamController<List<MinistryExperienceItem>>.broadcast();
  Future<void>? _initFuture;

  ExperienceManager(this.db) {
    _initTable();
  }

  Future<void> _initTable() {
    _initFuture ??= _doInitTable();
    return _initFuture!;
  }

  Future<void> _doInitTable() async {
    try {
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS ministry_experiences (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          media_urls TEXT NOT NULL DEFAULT '[]',
          tags TEXT NOT NULL DEFAULT '[]',
          date_time TEXT NOT NULL,
          location_or_modality TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
      ''');
      _refresh();
    } catch (_) {}
  }

  Future<void> _refresh() async {
    try {
      final list = await getAllExperiences();
      if (!_controller.isClosed) {
        _controller.add(list);
      }
    } catch (_) {}
  }

  Future<List<MinistryExperienceItem>> getAllExperiences() async {
    await _initTable();
    try {
      final rows = await db.customSelect('SELECT * FROM ministry_experiences ORDER BY date_time DESC').get();
      return rows.map((r) => MinistryExperienceItem.fromMap(r.data)).toList();
    } catch (_) {
      return [];
    }
  }

  Stream<List<MinistryExperienceItem>> watchExperiences() async* {
    yield await getAllExperiences();
    yield* _controller.stream;
  }

  Future<MinistryExperienceItem> addExperience({
    required String title,
    required String content,
    List<String> mediaUrls = const [],
    List<String> tags = const [],
    DateTime? dateTime,
    String? locationOrModality,
  }) async {
    await _initTable();
    final now = DateTime.now();
    final id = _uuid.v4();
    final dt = dateTime ?? now;

    await db.customInsert(
      'INSERT INTO ministry_experiences (id, title, content, media_urls, tags, date_time, location_or_modality, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(id),
        Variable.withString(title.trim()),
        Variable.withString(content.trim()),
        Variable.withString(jsonEncode(mediaUrls)),
        Variable.withString(jsonEncode(tags)),
        Variable.withString(dt.toIso8601String()),
        Variable.withString(locationOrModality?.trim() ?? ''),
        Variable.withString(now.toIso8601String()),
        Variable.withString(now.toIso8601String()),
      ],
    );

    final item = MinistryExperienceItem(
      id: id,
      title: title.trim(),
      content: content.trim(),
      mediaUrls: mediaUrls,
      tags: tags,
      dateTime: dt,
      locationOrModality: locationOrModality?.trim(),
      createdAt: now,
      updatedAt: now,
    );

    await _refresh();
    return item;
  }

  Future<void> updateExperience(MinistryExperienceItem item) async {
    await _initTable();
    final now = DateTime.now();
    await db.customUpdate(
      'UPDATE ministry_experiences SET title = ?, content = ?, media_urls = ?, tags = ?, date_time = ?, location_or_modality = ?, updated_at = ? WHERE id = ?',
      variables: [
        Variable.withString(item.title.trim()),
        Variable.withString(item.content.trim()),
        Variable.withString(jsonEncode(item.mediaUrls)),
        Variable.withString(jsonEncode(item.tags)),
        Variable.withString(item.dateTime.toIso8601String()),
        Variable.withString(item.locationOrModality?.trim() ?? ''),
        Variable.withString(now.toIso8601String()),
        Variable.withString(item.id),
      ],
    );
    await _refresh();
  }

  Future<void> deleteExperience(String id) async {
    await _initTable();
    await db.customUpdate('DELETE FROM ministry_experiences WHERE id = ?', variables: [Variable.withString(id)]);
    await _refresh();
  }
}

final experienceManagerProvider = Provider<ExperienceManager>((ref) {
  final repo = ref.watch(repositoryProvider);
  return ExperienceManager(repo.db);
});

final experiencesStreamProvider = StreamProvider<List<MinistryExperienceItem>>((ref) {
  final mgr = ref.watch(experienceManagerProvider);
  return mgr.watchExperiences();
});
