import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/app_logger.dart';
import '../core/sync_timestamp.dart';
import '../database/app_database.dart';
import '../ui/providers.dart';
import 'photo_file_store.dart';

class PersonPhotoItem {
  final String id;
  final String personId;
  final String photoType; // 'person', 'house', 'study', 'notes', 'general'
  final String imageData;
  final String? filePath;
  final DateTime createdAt;

  PersonPhotoItem({
    required this.id,
    required this.personId,
    required this.photoType,
    required this.imageData,
    this.filePath,
    required this.createdAt,
  });

  String get effectiveImageSource =>
      (filePath != null && filePath!.isNotEmpty) ? filePath! : imageData;

  Map<String, dynamic> toMap() => {
    'id': id,
    'person_id': personId,
    'photo_type': photoType,
    'file_path': filePath,
    'image_data': imageData,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  factory PersonPhotoItem.fromEntry(PersonPhotoEntry e) {
    final effective =
        (e.filePath != null && e.filePath!.isNotEmpty) ? e.filePath! : e.imageData;
    return PersonPhotoItem(
      id: e.id,
      personId: e.personId,
      photoType: e.photoType,
      imageData: effective,
      filePath: e.filePath,
      createdAt: e.createdAt,
    );
  }

  factory PersonPhotoItem.fromMap(Map<String, dynamic> map) {
    final fp = (map['file_path'] ?? map['filePath']) as String?;
    final rawImg = (map['image_data'] ?? map['imageData']) as String? ?? '';
    return PersonPhotoItem(
      id: map['id'] as String,
      personId: (map['person_id'] ?? map['personId']) as String,
      photoType: (map['photo_type'] ?? map['photoType']) as String,
      imageData: (fp != null && fp.isNotEmpty) ? fp : rawImg,
      filePath: fp,
      createdAt:
          SyncTimestamp.parse(map['created_at'] ?? map['createdAt']) ??
          DateTime.now(),
    );
  }
}

class PersonPhotosManager {
  final AppDatabase db;
  final Future<String> Function()? documentsDirectoryProvider;
  final Uuid _uuid = const Uuid();

  PersonPhotosManager(this.db, {this.documentsDirectoryProvider});

  Future<({String? filePath, String storedImageData})> _prepareStoredMedia(
    String photoId,
    String rawInput,
  ) async {
    final clean = rawInput.trim();
    if (clean.isEmpty) {
      return (filePath: null, storedImageData: '');
    }

    if (!kIsWeb) {
      List<int>? decodedBytes;
      String ext = 'jpg';
      if (clean.startsWith('data:image/')) {
        final headerEnd = clean.indexOf(',');
        if (headerEnd != -1) {
          final header = clean.substring(0, headerEnd).toLowerCase();
          if (header.contains('png')) {
            ext = 'png';
          } else if (header.contains('webp')) {
            ext = 'webp';
          }
          try {
            decodedBytes = base64Decode(clean.substring(headerEnd + 1));
          } catch (e, st) {
            AppLogger.warning('Falha ao decodificar data URI da foto $photoId', e, st);
          }
        }
      }

      if (decodedBytes != null && decodedBytes.isNotEmpty) {
        final savedPath = await savePhotoBytesToDisk(
          photoId: photoId,
          bytes: decodedBytes,
          extension: ext,
          documentsDirectoryProvider: documentsDirectoryProvider,
        );
        if (savedPath != null && savedPath.isNotEmpty) {
          return (filePath: savedPath, storedImageData: '');
        }
      } else if (clean.startsWith('/') ||
          RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(clean)) {
        return (filePath: clean, storedImageData: '');
      }
    }

    return (filePath: null, storedImageData: clean);
  }

  /// Migra fotos legadas com base64 embutido no SQLite para arquivos físicos no disco (A3).
  Future<int> migrateLegacyInlinePhotosToFiles() async {
    if (kIsWeb) return 0;
    int migrated = 0;
    final rows = await (db.select(db.personPhotos)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    for (final row in rows) {
      if ((row.filePath == null || row.filePath!.isEmpty) &&
          row.imageData.startsWith('data:image/')) {
        final stored = await _prepareStoredMedia(row.id, row.imageData);
        if (stored.filePath != null && stored.filePath!.isNotEmpty) {
          await (db.update(db.personPhotos)..where((t) => t.id.equals(row.id)))
              .write(
            PersonPhotosCompanion(
              filePath: Value(stored.filePath),
              imageData: const Value(''),
              updatedAt: Value(DateTime.now()),
            ),
          );
          migrated++;
        }
      }
    }
    return migrated;
  }

  Future<List<PersonPhotoItem>> getAllPhotos() async {
    final rows =
        await (db.select(db.personPhotos)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();
    return rows.map(PersonPhotoItem.fromEntry).toList();
  }

  Stream<List<PersonPhotoItem>> watchAllPhotos() {
    return (db.select(db.personPhotos)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map(PersonPhotoItem.fromEntry).toList());
  }

  Future<List<PersonPhotoItem>> getPhotosForPerson(String personId) async {
    final rows =
        await (db.select(db.personPhotos)
              ..where(
                (t) => t.personId.equals(personId) & t.deletedAt.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();
    return rows.map(PersonPhotoItem.fromEntry).toList();
  }

  Future<PersonPhotoItem?> getPhoto(String personId, String photoType) async {
    final rows =
        await (db.select(db.personPhotos)
              ..where(
                (t) =>
                    t.personId.equals(personId) &
                    t.photoType.equals(photoType) &
                    t.deletedAt.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(1))
            .get();
    return rows.isNotEmpty ? PersonPhotoItem.fromEntry(rows.first) : null;
  }

  /// Adiciona uma nova foto à galeria da pessoa com ID exclusivo
  Future<PersonPhotoItem> addPhoto({
    required String personId,
    required String photoType,
    required String imageData,
  }) async {
    final photoId = _uuid.v4();
    final now = DateTime.now();
    final stored = await _prepareStoredMedia(photoId, imageData);

    final entry = PersonPhotoEntry(
      id: photoId,
      personId: personId,
      photoType: photoType,
      filePath: stored.filePath,
      imageData: stored.storedImageData,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      revision: 1,
    );

    await db.transaction(() async {
      await db.into(db.personPhotos).insert(entry);
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'person_photos',
          entityId: photoId,
          operation: 'INSERT',
          payload: jsonEncode(SyncTimestamp.normalizeMapDates(entry.toJson())),
          createdAt: now,
          status: const Value('pending'),
        ),
      );
    });

    return PersonPhotoItem.fromEntry(entry);
  }

  Future<void> setPhoto({
    required String personId,
    required String photoType,
    required String imageData,
  }) async {
    final now = DateTime.now();
    final existingRows =
        await (db.select(db.personPhotos)
              ..where(
                (t) =>
                    t.personId.equals(personId) &
                    t.photoType.equals(photoType) &
                    t.deletedAt.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(1))
            .get();

    if (existingRows.isNotEmpty) {
      final existing = existingRows.first;
      final stored = await _prepareStoredMedia(existing.id, imageData);
      final updated = existing.copyWith(
        filePath: Value(stored.filePath),
        imageData: stored.storedImageData,
        updatedAt: Value(now),
        revision: existing.revision + 1,
      );
      await db.transaction(() async {
        await db.update(db.personPhotos).replace(updated);
        final payload = SyncTimestamp.normalizeMapDates(updated.toJson());
        payload['_base'] = SyncTimestamp.normalizeMapDates(existing.toJson());
        await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: _uuid.v4(),
            entityType: 'person_photos',
            entityId: existing.id,
            operation: 'UPDATE',
            payload: jsonEncode(payload),
            createdAt: now,
            status: const Value('pending'),
          ),
        );
      });
    } else {
      final newId = _uuid.v4();
      final stored = await _prepareStoredMedia(newId, imageData);
      final entry = PersonPhotoEntry(
        id: newId,
        personId: personId,
        photoType: photoType,
        filePath: stored.filePath,
        imageData: stored.storedImageData,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
        revision: 1,
      );
      await db.transaction(() async {
        await db.into(db.personPhotos).insert(entry);
        await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: _uuid.v4(),
            entityType: 'person_photos',
            entityId: newId,
            operation: 'INSERT',
            payload: jsonEncode(SyncTimestamp.normalizeMapDates(entry.toJson())),
            createdAt: now,
            status: const Value('pending'),
          ),
        );
      });
    }
  }

  Future<void> savePersonPhoto(String personId, String imageData) =>
      setPhoto(personId: personId, photoType: 'person', imageData: imageData);

  Future<void> saveHousePhoto(String personId, String imageData) =>
      setPhoto(personId: personId, photoType: 'house', imageData: imageData);

  Future<void> deletePhoto(String personId, String photoType) async {
    final now = DateTime.now();
    final rows = await (db.select(db.personPhotos)
          ..where(
            (t) =>
                t.personId.equals(personId) &
                t.photoType.equals(photoType) &
                t.deletedAt.isNull(),
          ))
        .get();

    await db.transaction(() async {
      for (final existing in rows) {
        final nextRev = existing.revision + 1;
        await (db.update(db.personPhotos)
              ..where((t) => t.id.equals(existing.id)))
            .write(
          PersonPhotosCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            revision: Value(nextRev),
          ),
        );
        await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: _uuid.v4(),
            entityType: 'person_photos',
            entityId: existing.id,
            operation: 'DELETE',
            payload: jsonEncode({
              'id': existing.id,
              'deleted_at': now.toUtc().toIso8601String(),
              'updated_at': now.toUtc().toIso8601String(),
              'revision': nextRev,
            }),
            createdAt: now,
            status: const Value('pending'),
          ),
        );
      }
    });

    for (final existing in rows) {
      await deletePhotoFileFromDisk(existing.filePath);
    }
  }

  Future<void> deletePhotoById(String photoId) async {
    final now = DateTime.now();
    final existing = await (db.select(db.personPhotos)
          ..where((t) => t.id.equals(photoId)))
        .getSingleOrNull();
    if (existing == null) return;

    final nextRev = existing.revision + 1;
    await db.transaction(() async {
      await (db.update(db.personPhotos)..where((t) => t.id.equals(photoId)))
          .write(
        PersonPhotosCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          revision: Value(nextRev),
        ),
      );
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'person_photos',
          entityId: photoId,
          operation: 'DELETE',
          payload: jsonEncode({
            'id': photoId,
            'deleted_at': now.toUtc().toIso8601String(),
            'updated_at': now.toUtc().toIso8601String(),
            'revision': nextRev,
          }),
          createdAt: now,
          status: const Value('pending'),
        ),
      );
    });

    await deletePhotoFileFromDisk(existing.filePath);
  }
}

final personPhotosManagerProvider = Provider<PersonPhotosManager>((ref) {
  final repo = ref.watch(repositoryProvider);
  final mgr = PersonPhotosManager(repo.db);
  if (!kIsWeb) {
    mgr.migrateLegacyInlinePhotosToFiles().catchError((Object e, StackTrace st) {
      AppLogger.warning('Falha na migração de fotos inline legadas', e, st);
      return 0;
    });
  }
  return mgr;
});

final personPhotosStreamProvider = StreamProvider<List<PersonPhotoItem>>((ref) {
  final mgr = ref.watch(personPhotosManagerProvider);
  return mgr.watchAllPhotos();
});
