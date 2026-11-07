import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../ui/providers.dart';

class PersonPhotoItem {
  final String id;
  final String personId;
  final String photoType; // 'person', 'house', 'study', 'notes', 'general'
  final String imageData;
  final DateTime createdAt;

  PersonPhotoItem({
    required this.id,
    required this.personId,
    required this.photoType,
    required this.imageData,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'person_id': personId,
    'photo_type': photoType,
    'image_data': imageData,
    'created_at': createdAt.toIso8601String(),
  };

  factory PersonPhotoItem.fromMap(Map<String, dynamic> map) => PersonPhotoItem(
    id: map['id'] as String,
    personId: map['person_id'] as String,
    photoType: map['photo_type'] as String,
    imageData: map['image_data'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}

class PersonPhotosManager {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();
  final StreamController<List<PersonPhotoItem>> _photosController =
      StreamController<List<PersonPhotoItem>>.broadcast();
  Future<void>? _initFuture;
  bool _initialized = false;

  PersonPhotosManager(this.db) {
    _initTable();
  }

  Future<void> _initTable() async {
    if (_initialized) return;
    _initFuture ??= _doInitTable();
    await _initFuture;
  }

  Future<void> _doInitTable() async {
    try {
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS person_photos (
          id TEXT PRIMARY KEY,
          person_id TEXT NOT NULL,
          photo_type TEXT NOT NULL,
          image_data TEXT NOT NULL,
          created_at TEXT NOT NULL
        );
      ''');
    } catch (_) {}
    _initialized = true;
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final list = await getAllPhotos();
      if (!_photosController.isClosed) {
        _photosController.add(list);
      }
    } catch (_) {}
  }

  Future<List<PersonPhotoItem>> getAllPhotos() async {
    await _initTable();
    try {
      final rows = await db
          .customSelect('SELECT * FROM person_photos ORDER BY created_at DESC')
          .get();
      return rows.map((r) => PersonPhotoItem.fromMap(r.data)).toList();
    } catch (_) {
      return [];
    }
  }

  Stream<List<PersonPhotoItem>> watchAllPhotos() async* {
    yield await getAllPhotos();
    yield* _photosController.stream;
  }

  Future<List<PersonPhotoItem>> getPhotosForPerson(String personId) async {
    await _initTable();
    try {
      final rows = await db
          .customSelect(
            'SELECT * FROM person_photos WHERE person_id = ? ORDER BY created_at DESC',
            variables: [Variable.withString(personId)],
          )
          .get();
      return rows.map((r) => PersonPhotoItem.fromMap(r.data)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<PersonPhotoItem?> getPhoto(String personId, String photoType) async {
    await _initTable();
    try {
      final row = await db
          .customSelect(
            'SELECT * FROM person_photos WHERE person_id = ? AND photo_type = ? ORDER BY created_at DESC LIMIT 1',
            variables: [
              Variable.withString(personId),
              Variable.withString(photoType),
            ],
          )
          .getSingleOrNull();
      return row != null ? PersonPhotoItem.fromMap(row.data) : null;
    } catch (_) {
      return null;
    }
  }

  /// Adiciona uma nova foto à galeria da pessoa com ID exclusivo
  Future<PersonPhotoItem> addPhoto({
    required String personId,
    required String photoType,
    required String imageData,
  }) async {
    await _initTable();
    final photoId = _uuid.v4();
    final now = DateTime.now();

    await db.customInsert(
      'INSERT INTO person_photos (id, person_id, photo_type, image_data, created_at) VALUES (?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(photoId),
        Variable.withString(personId),
        Variable.withString(photoType),
        Variable.withString(imageData),
        Variable.withString(now.toIso8601String()),
      ],
    );

    final item = PersonPhotoItem(
      id: photoId,
      personId: personId,
      photoType: photoType,
      imageData: imageData,
      createdAt: now,
    );

    try {
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'person_photos',
          entityId: photoId,
          operation: 'INSERT',
          payload: jsonEncode(item.toMap()),
          createdAt: now,
          status: const Value('pending'),
        ),
      );
    } catch (_) {}

    await _refresh();
    return item;
  }

  Future<void> setPhoto({
    required String personId,
    required String photoType,
    required String imageData,
  }) async {
    await _initTable();
    final now = DateTime.now();
    final existing = await getPhoto(personId, photoType);
    if (existing != null) {
      await db.customUpdate(
        'UPDATE person_photos SET image_data = ?, created_at = ? WHERE person_id = ? AND photo_type = ?',
        variables: [
          Variable.withString(imageData),
          Variable.withString(now.toIso8601String()),
          Variable.withString(personId),
          Variable.withString(photoType),
        ],
      );

      try {
        await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: _uuid.v4(),
            entityType: 'person_photos',
            entityId: existing.id,
            operation: 'UPDATE',
            payload: jsonEncode({
              'id': existing.id,
              'person_id': personId,
              'photo_type': photoType,
              'image_data': imageData,
              'updated_at': now.toIso8601String(),
            }),
            createdAt: now,
            status: const Value('pending'),
          ),
        );
      } catch (_) {}
    } else {
      final newId = _uuid.v4();
      await db.customInsert(
        'INSERT INTO person_photos (id, person_id, photo_type, image_data, created_at) VALUES (?, ?, ?, ?, ?)',
        variables: [
          Variable.withString(newId),
          Variable.withString(personId),
          Variable.withString(photoType),
          Variable.withString(imageData),
          Variable.withString(now.toIso8601String()),
        ],
      );

      try {
        await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: _uuid.v4(),
            entityType: 'person_photos',
            entityId: newId,
            operation: 'INSERT',
            payload: jsonEncode({
              'id': newId,
              'person_id': personId,
              'photo_type': photoType,
              'image_data': imageData,
              'created_at': now.toIso8601String(),
            }),
            createdAt: now,
            status: const Value('pending'),
          ),
        );
      } catch (_) {}
    }
    await _refresh();
  }

  Future<void> savePersonPhoto(String personId, String imageData) =>
      setPhoto(personId: personId, photoType: 'person', imageData: imageData);

  Future<void> saveHousePhoto(String personId, String imageData) =>
      setPhoto(personId: personId, photoType: 'house', imageData: imageData);

  Future<void> deletePhoto(String personId, String photoType) async {
    await _initTable();
    final now = DateTime.now();
    final existing = await getPhoto(personId, photoType);
    await db.customUpdate(
      'DELETE FROM person_photos WHERE person_id = ? AND photo_type = ?',
      variables: [
        Variable.withString(personId),
        Variable.withString(photoType),
      ],
    );

    if (existing != null) {
      try {
        await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: _uuid.v4(),
            entityType: 'person_photos',
            entityId: existing.id,
            operation: 'DELETE',
            payload: jsonEncode({
              'id': existing.id,
              'deleted_at': now.toIso8601String(),
            }),
            createdAt: now,
            status: const Value('pending'),
          ),
        );
      } catch (_) {}
    }

    await _refresh();
  }

  Future<void> deletePhotoById(String photoId) async {
    await _initTable();
    final now = DateTime.now();
    await db.customUpdate(
      'DELETE FROM person_photos WHERE id = ?',
      variables: [Variable.withString(photoId)],
    );

    try {
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'person_photos',
          entityId: photoId,
          operation: 'DELETE',
          payload: jsonEncode({
            'id': photoId,
            'deleted_at': now.toIso8601String(),
          }),
          createdAt: now,
          status: const Value('pending'),
        ),
      );
    } catch (_) {}

    await _refresh();
  }
}

final personPhotosManagerProvider = Provider<PersonPhotosManager>((ref) {
  final repo = ref.watch(repositoryProvider);
  return PersonPhotosManager(repo.db);
});

final personPhotosStreamProvider = StreamProvider<List<PersonPhotoItem>>((ref) {
  final mgr = ref.watch(personPhotosManagerProvider);
  return mgr.watchAllPhotos();
});
