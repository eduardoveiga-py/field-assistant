import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../ui/providers.dart';

class PersonPublicationItem {
  final String id;
  final String personId;
  final String publicationTitle;
  final String itemType; // 'entregue' ou 'pedido'
  final String status; // 'entregue', 'a_pedir', 'conseguido'
  final DateTime date;
  final String? notes;
  final DateTime createdAt;

  PersonPublicationItem({
    required this.id,
    required this.personId,
    required this.publicationTitle,
    required this.itemType,
    required this.status,
    required this.date,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'person_id': personId,
        'publication_title': publicationTitle,
        'item_type': itemType,
        'status': status,
        'date': date.toIso8601String(),
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory PersonPublicationItem.fromMap(Map<String, dynamic> map) => PersonPublicationItem(
        id: map['id'] as String,
        personId: map['person_id'] as String,
        publicationTitle: map['publication_title'] as String,
        itemType: map['item_type'] as String,
        status: map['status'] as String,
        date: DateTime.parse(map['date'] as String),
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class PersonPublicationsManager {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();
  final StreamController<List<PersonPublicationItem>> _controller = StreamController<List<PersonPublicationItem>>.broadcast();
  Future<void>? _initFuture;

  PersonPublicationsManager(this.db) {
    _initTable();
  }

  Future<void> _initTable() {
    _initFuture ??= _doInitTable();
    return _initFuture!;
  }

  Future<void> _doInitTable() async {
    try {
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS person_publications (
          id TEXT PRIMARY KEY,
          person_id TEXT NOT NULL,
          publication_title TEXT NOT NULL,
          item_type TEXT NOT NULL,
          status TEXT NOT NULL,
          date TEXT NOT NULL,
          notes TEXT,
          created_at TEXT NOT NULL
        );
      ''');
      _refresh();
    } catch (_) {}
  }

  Future<void> _refresh() async {
    try {
      final list = await getAllPublications();
      if (!_controller.isClosed) {
        _controller.add(list);
      }
    } catch (_) {}
  }

  Future<List<PersonPublicationItem>> getAllPublications() async {
    await _initTable();
    try {
      final rows = await db.customSelect('SELECT * FROM person_publications ORDER BY date DESC').get();
      return rows.map((r) => PersonPublicationItem.fromMap(r.data)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<PersonPublicationItem>> getPublicationsForPerson(String personId) async {
    await _initTable();
    try {
      final rows = await db.customSelect(
        'SELECT * FROM person_publications WHERE person_id = ? ORDER BY date DESC',
        variables: [Variable.withString(personId)],
      ).get();
      return rows.map((r) => PersonPublicationItem.fromMap(r.data)).toList();
    } catch (_) {
      return [];
    }
  }

  Stream<List<PersonPublicationItem>> watchAllPublications() async* {
    yield await getAllPublications();
    yield* _controller.stream;
  }

  Future<PersonPublicationItem> addDeliveredPublication({
    required String personId,
    required String title,
    DateTime? date,
    String? notes,
  }) =>
      addPlacedPublication(
        personId: personId,
        title: title,
        date: date,
        notes: notes,
      );

  Future<PersonPublicationItem> addPlacedPublication({
    required String personId,
    required String title,
    DateTime? date,
    String? notes,
  }) async {
    await _initTable();
    final now = DateTime.now();
    final id = _uuid.v4();
    final d = date ?? now;

    await db.customInsert(
      'INSERT INTO person_publications (id, person_id, publication_title, item_type, status, date, notes, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(id),
        Variable.withString(personId),
        Variable.withString(title.trim()),
        Variable.withString('entregue'),
        Variable.withString('entregue'),
        Variable.withString(d.toIso8601String()),
        Variable.withString(notes ?? ''),
        Variable.withString(now.toIso8601String()),
      ],
    );

    final item = PersonPublicationItem(
      id: id,
      personId: personId,
      publicationTitle: title.trim(),
      itemType: 'entregue',
      status: 'entregue',
      date: d,
      notes: notes,
      createdAt: now,
    );

    await _refresh();
    return item;
  }

  Future<PersonPublicationItem> addStudentRequest({
    required String personId,
    required String title,
    String? notes,
    DateTime? targetDate,
  }) async {
    await _initTable();
    final now = DateTime.now();
    final id = _uuid.v4();
    final d = targetDate ?? now;

    await db.customInsert(
      'INSERT INTO person_publications (id, person_id, publication_title, item_type, status, date, notes, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(id),
        Variable.withString(personId),
        Variable.withString(title.trim()),
        Variable.withString('pedido'),
        Variable.withString('a_pedir'),
        Variable.withString(d.toIso8601String()),
        Variable.withString(notes ?? ''),
        Variable.withString(now.toIso8601String()),
      ],
    );

    final item = PersonPublicationItem(
      id: id,
      personId: personId,
      publicationTitle: title.trim(),
      itemType: 'pedido',
      status: 'a_pedir',
      date: d,
      notes: notes,
      createdAt: now,
    );

    await _refresh();
    return item;
  }

  Future<void> updatePublicationStatus({
    required String id,
    required String newStatus,
    String? notes,
  }) async {
    await _initTable();
    if (notes != null) {
      await db.customUpdate(
        'UPDATE person_publications SET status = ?, notes = ? WHERE id = ?',
        variables: [
          Variable.withString(newStatus),
          Variable.withString(notes),
          Variable.withString(id),
        ],
      );
    } else {
      await db.customUpdate(
        'UPDATE person_publications SET status = ? WHERE id = ?',
        variables: [
          Variable.withString(newStatus),
          Variable.withString(id),
        ],
      );
    }
    await _refresh();
  }

  Future<void> deletePublication(String id) async {
    await _initTable();
    await db.customUpdate(
      'DELETE FROM person_publications WHERE id = ?',
      variables: [Variable.withString(id)],
    );
    await _refresh();
  }
}

final personPublicationsManagerProvider = Provider<PersonPublicationsManager>((ref) {
  final repo = ref.watch(repositoryProvider);
  return PersonPublicationsManager(repo.db);
});

final personPublicationsStreamProvider = StreamProvider<List<PersonPublicationItem>>((ref) {
  final mgr = ref.watch(personPublicationsManagerProvider);
  return mgr.watchAllPublications();
});
