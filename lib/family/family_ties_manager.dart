import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../ui/providers.dart';

class FamilyTieItem {
  final String id;
  final String personId;
  final String? relatedPersonId;
  final String relatedPersonName;
  final String relationshipType;
  final DateTime createdAt;

  FamilyTieItem({
    required this.id,
    required this.personId,
    this.relatedPersonId,
    required this.relatedPersonName,
    required this.relationshipType,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'person_id': personId,
        'related_person_id': relatedPersonId,
        'related_person_name': relatedPersonName,
        'relationship_type': relationshipType,
        'created_at': createdAt.toIso8601String(),
      };

  factory FamilyTieItem.fromMap(Map<String, dynamic> map) => FamilyTieItem(
        id: map['id'] as String,
        personId: map['person_id'] as String,
        relatedPersonId: map['related_person_id'] as String?,
        relatedPersonName: map['related_person_name'] as String,
        relationshipType: map['relationship_type'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class FamilyTiesManager {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();
  final StreamController<List<FamilyTieItem>> _tiesController = StreamController<List<FamilyTieItem>>.broadcast();
  Future<void>? _initFuture;

  FamilyTiesManager(this.db) {
    _initTable();
  }

  Future<void> _initTable() {
    _initFuture ??= _doInitTable();
    return _initFuture!;
  }

  Future<void> _doInitTable() async {
    try {
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS family_ties (
          id TEXT PRIMARY KEY,
          person_id TEXT NOT NULL,
          related_person_id TEXT,
          related_person_name TEXT NOT NULL,
          relationship_type TEXT NOT NULL,
          created_at TEXT NOT NULL
        );
      ''');
      _refresh();
    } catch (_) {}
  }

  Future<void> _refresh() async {
    try {
      final list = await getAllTies();
      if (!_tiesController.isClosed) {
        _tiesController.add(list);
      }
    } catch (_) {}
  }

  Future<List<FamilyTieItem>> getAllTies() async {
    await _initTable();
    try {
      final rows = await db.customSelect('SELECT * FROM family_ties').get();
      return rows.map((r) => FamilyTieItem.fromMap(r.data)).toList();
    } catch (_) {
      return [];
    }
  }

  Stream<List<FamilyTieItem>> watchAllTies() async* {
    yield await getAllTies();
    yield* _tiesController.stream;
  }

  Future<List<FamilyTieItem>> getTiesForPerson(String personId) async {
    await _initTable();
    try {
      final list = await db.customSelect(
        'SELECT * FROM family_ties WHERE person_id = ? ORDER BY relationship_type ASC',
        variables: [Variable.withString(personId)],
      ).get();
      return list.map((r) => FamilyTieItem.fromMap(r.data)).toList();
    } catch (_) {
      return [];
    }
  }

  static String getReciprocalRelationship(String relationship) {
    final lower = relationship.trim().toLowerCase();
    switch (lower) {
      case 'esposa':
      case 'mulher':
        return 'Marido';
      case 'marido':
      case 'esposo':
        return 'Esposa';
      case 'cônjuge':
      case 'conjuge':
        return 'Cônjuge';
      case 'pai':
      case 'mãe':
      case 'mae':
        return 'Filho(a)';
      case 'filho':
      case 'filha':
      case 'filho(a)':
        return 'Pai/Mãe';
      case 'irmão':
      case 'irmao':
      case 'irmã':
      case 'irma':
      case 'irmão(ã)':
        return 'Irmão(ã)';
      case 'padrasto':
      case 'madrasta':
        return 'Enteado(a)';
      case 'enteado':
      case 'enteada':
      case 'enteado(a)':
        return 'Padrasto/Madrasta';
      case 'avô':
      case 'avo':
      case 'avó':
        return 'Neto(a)';
      case 'neto':
      case 'neta':
      case 'neto(a)':
        return 'Avô/Avó';
      case 'sogro':
      case 'sogra':
        return 'Genro/Nora';
      case 'genro':
      case 'nora':
        return 'Sogro(a)';
      case 'parente':
        return 'Parente';
      default:
        return 'Familiar';
    }
  }

  Future<FamilyTieItem> addFamilyTie({
    required String personId,
    required String personName,
    String? relatedPersonId,
    required String relatedPersonName,
    required String relationshipType,
  }) async {
    await _initTable();
    final now = DateTime.now();
    final tieId = _uuid.v4();

    await db.customInsert(
      'INSERT INTO family_ties (id, person_id, related_person_id, related_person_name, relationship_type, created_at) VALUES (?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(tieId),
        Variable.withString(personId),
        Variable.withString(relatedPersonId ?? ''),
        Variable.withString(relatedPersonName.trim()),
        Variable.withString(relationshipType.trim()),
        Variable.withString(now.toIso8601String()),
      ],
    );

    // VÍNCULO RECÍPROCO AUTOMÁTICO
    // Se a outra pessoa for cadastrada no app, cria ou atualiza automaticamente o vínculo nela também!
    if (relatedPersonId != null && relatedPersonId.isNotEmpty && relatedPersonId != personId) {
      final reciprocalType = getReciprocalRelationship(relationshipType);
      final existingReciprocal = await db.customSelect(
        'SELECT id FROM family_ties WHERE person_id = ? AND related_person_id = ?',
        variables: [Variable.withString(relatedPersonId), Variable.withString(personId)],
      ).getSingleOrNull();

      if (existingReciprocal != null) {
        await db.customUpdate(
          'UPDATE family_ties SET relationship_type = ?, related_person_name = ? WHERE id = ?',
          variables: [
            Variable.withString(reciprocalType),
            Variable.withString(personName.trim()),
            Variable.withString(existingReciprocal.read<String>('id')),
          ],
        );
      } else {
        await db.customInsert(
          'INSERT INTO family_ties (id, person_id, related_person_id, related_person_name, relationship_type, created_at) VALUES (?, ?, ?, ?, ?, ?)',
          variables: [
            Variable.withString(_uuid.v4()),
            Variable.withString(relatedPersonId),
            Variable.withString(personId),
            Variable.withString(personName.trim()),
            Variable.withString(reciprocalType),
            Variable.withString(now.toIso8601String()),
          ],
        );
      }
    }

    final item = FamilyTieItem(
      id: tieId,
      personId: personId,
      relatedPersonId: relatedPersonId,
      relatedPersonName: relatedPersonName.trim(),
      relationshipType: relationshipType.trim(),
      createdAt: now,
    );

    await _refresh();
    return item;
  }

  Future<void> updateFamilyTie({
    required String id,
    required String newRelationshipType,
    String? newRelatedPersonName,
  }) async {
    await _initTable();
    final existing = await db.customSelect(
      'SELECT * FROM family_ties WHERE id = ?',
      variables: [Variable.withString(id)],
    ).getSingleOrNull();

    if (existing == null) return;
    final item = FamilyTieItem.fromMap(existing.data);

    await db.customUpdate(
      'UPDATE family_ties SET relationship_type = ?, related_person_name = ? WHERE id = ?',
      variables: [
        Variable.withString(newRelationshipType.trim()),
        Variable.withString(newRelatedPersonName?.trim() ?? item.relatedPersonName),
        Variable.withString(id),
      ],
    );

    // Atualiza recíproco se vinculado a pessoa cadastrada
    if (item.relatedPersonId != null && item.relatedPersonId!.isNotEmpty) {
      final reciprocalType = getReciprocalRelationship(newRelationshipType);
      await db.customUpdate(
        'UPDATE family_ties SET relationship_type = ? WHERE person_id = ? AND related_person_id = ?',
        variables: [
          Variable.withString(reciprocalType),
          Variable.withString(item.relatedPersonId!),
          Variable.withString(item.personId),
        ],
      );
    }

    await _refresh();
  }

  Future<void> deleteFamilyTie(String id, {bool deleteReciprocal = true}) async {
    await _initTable();
    final existing = await db.customSelect(
      'SELECT * FROM family_ties WHERE id = ?',
      variables: [Variable.withString(id)],
    ).getSingleOrNull();

    if (existing != null) {
      final item = FamilyTieItem.fromMap(existing.data);
      await db.customUpdate('DELETE FROM family_ties WHERE id = ?', variables: [Variable.withString(id)]);

      if (deleteReciprocal && item.relatedPersonId != null && item.relatedPersonId!.isNotEmpty) {
        await db.customUpdate(
          'DELETE FROM family_ties WHERE person_id = ? AND related_person_id = ?',
          variables: [Variable.withString(item.relatedPersonId!), Variable.withString(item.personId)],
        );
      }
    }

    await _refresh();
  }
}

final familyTiesManagerProvider = Provider<FamilyTiesManager>((ref) {
  final repo = ref.watch(repositoryProvider);
  return FamilyTiesManager(repo.db);
});

final familyTiesStreamProvider = StreamProvider<List<FamilyTieItem>>((ref) {
  final mgr = ref.watch(familyTiesManagerProvider);
  return mgr.watchAllTies();
});
