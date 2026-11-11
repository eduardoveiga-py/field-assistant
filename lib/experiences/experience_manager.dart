import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/app_logger.dart';
import '../core/sync_timestamp.dart';
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
    'date_time': dateTime.toUtc().toIso8601String(),
    'location_or_modality': locationOrModality,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory MinistryExperienceItem.fromEntry(MinistryExperienceEntry e) {
    return MinistryExperienceItem(
      id: e.id,
      title: e.title,
      content: e.content,
      mediaUrls: _decodeStringList(e.mediaUrls),
      tags: _decodeStringList(e.tags),
      dateTime: e.dateTimeField,
      locationOrModality: e.locationOrModality,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
    );
  }

  factory MinistryExperienceItem.fromMap(Map<String, dynamic> map) {
    return MinistryExperienceItem(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      mediaUrls: _decodeStringList(map['media_urls']),
      tags: _decodeStringList(map['tags']),
      dateTime:
          SyncTimestamp.parse(map['date_time'] ?? map['dateTimeField']) ??
          DateTime.now(),
      locationOrModality:
          (map['location_or_modality'] ?? map['locationOrModality']) as String?,
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
        AppLogger.warning('Falha ao decodificar lista JSON em MinistryExperience', e, st);
      }
    }
    return [];
  }
}

class ExperienceManager {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();

  ExperienceManager(this.db);

  Future<List<MinistryExperienceItem>> getAllExperiences() async {
    final rows =
        await (db.select(db.ministryExperiences)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.dateTimeField)]))
            .get();
    return rows.map(MinistryExperienceItem.fromEntry).toList();
  }

  Stream<List<MinistryExperienceItem>> watchExperiences() {
    return (db.select(db.ministryExperiences)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.dateTimeField)]))
        .watch()
        .map((rows) => rows.map(MinistryExperienceItem.fromEntry).toList());
  }

  Future<MinistryExperienceItem> addExperience({
    required String title,
    required String content,
    List<String> mediaUrls = const [],
    List<String> tags = const [],
    DateTime? dateTime,
    String? locationOrModality,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final dt = dateTime ?? now;
    final cleanModality =
        locationOrModality != null && locationOrModality.trim().isNotEmpty
            ? locationOrModality.trim()
            : null;

    final entry = MinistryExperienceEntry(
      id: id,
      title: title.trim(),
      content: content.trim(),
      mediaUrls: jsonEncode(mediaUrls),
      tags: jsonEncode(tags),
      dateTimeField: dt,
      locationOrModality: cleanModality,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      revision: 1,
    );

    await db.transaction(() async {
      await db.into(db.ministryExperiences).insert(entry);
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'ministry_experiences',
          entityId: id,
          operation: 'INSERT',
          payload: jsonEncode(SyncTimestamp.normalizeMapDates(entry.toJson())),
          createdAt: now,
          status: const Value('pending'),
        ),
      );
    });

    return MinistryExperienceItem.fromEntry(entry);
  }

  Future<void> updateExperience(MinistryExperienceItem item) async {
    final now = DateTime.now();
    final existing = await (db.select(db.ministryExperiences)
          ..where((t) => t.id.equals(item.id)))
        .getSingleOrNull();
    final cleanModality = item.locationOrModality != null &&
            item.locationOrModality!.trim().isNotEmpty
        ? item.locationOrModality!.trim()
        : null;
    final updated = MinistryExperienceEntry(
      id: item.id,
      title: item.title.trim(),
      content: item.content.trim(),
      mediaUrls: jsonEncode(item.mediaUrls),
      tags: jsonEncode(item.tags),
      dateTimeField: item.dateTime,
      locationOrModality: cleanModality,
      createdAt: existing?.createdAt ?? item.createdAt,
      updatedAt: now,
      deletedAt: existing?.deletedAt,
      revision: (existing?.revision ?? 1) + 1,
    );

    await db.transaction(() async {
      await db.update(db.ministryExperiences).replace(updated);
      final payload = SyncTimestamp.normalizeMapDates(updated.toJson());
      if (existing != null) {
        payload['_base'] = SyncTimestamp.normalizeMapDates(existing.toJson());
      }
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'ministry_experiences',
          entityId: item.id,
          operation: 'UPDATE',
          payload: jsonEncode(payload),
          createdAt: now,
          status: const Value('pending'),
        ),
      );
    });
  }

  Future<void> deleteExperience(String id) async {
    final now = DateTime.now();
    final existing = await (db.select(db.ministryExperiences)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) return;

    final nextRev = existing.revision + 1;
    await db.transaction(() async {
      await (db.update(db.ministryExperiences)..where((t) => t.id.equals(id)))
          .write(
        MinistryExperiencesCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          revision: Value(nextRev),
        ),
      );
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'ministry_experiences',
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
}

final experienceManagerProvider = Provider<ExperienceManager>((ref) {
  final repo = ref.watch(repositoryProvider);
  return ExperienceManager(repo.db);
});

final experiencesStreamProvider = StreamProvider<List<MinistryExperienceItem>>((
  ref,
) {
  final mgr = ref.watch(experienceManagerProvider);
  return mgr.watchExperiences();
});
