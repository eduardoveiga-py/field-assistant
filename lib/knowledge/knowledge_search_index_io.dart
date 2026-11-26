import 'package:drift/drift.dart' as drift;

import '../core/app_logger.dart';
import '../database/app_database.dart';
import 'knowledge_search_common.dart';

final Expando<bool> _ftsReady = Expando<bool>('kb_fts_ready');
final Expando<bool> _ftsUnavailable = Expando<bool>('kb_fts_unavailable');

Future<bool> _ensureFtsReady(AppDatabase db) async {
  if (_ftsUnavailable[db] == true) return false;
  if (_ftsReady[db] == true) return true;

  try {
    await db.customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS kb_fts USING fts5(
        entity_type UNINDEXED,
        entity_id UNINDEXED,
        area_id UNINDEXED,
        category UNINDEXED,
        title,
        body,
        tags_text,
        tokenize='unicode61 remove_diacritics 2'
      )
    ''');

    final countRow = await db
        .customSelect('SELECT COUNT(*) AS c FROM kb_fts')
        .getSingle();
    final existingCount = countRow.read<int>('c');
    if (existingCount == 0) {
      await _populateAllRows(db);
    }

    _ftsReady[db] = true;
    return true;
  } catch (e, st) {
    AppLogger.debug(
      'FTS5 indisponível neste runtime SQLite; alternando para busca Dart pura: $e',
      st,
    );
    _ftsUnavailable[db] = true;
    return false;
  }
}

Future<void> _populateAllRows(AppDatabase db) async {
  await db.customStatement('DELETE FROM kb_fts');

  final notes = await (db.select(
    db.knowledgeNotes,
  )..where((t) => t.deletedAt.isNull())).get();
  for (final n in notes) {
    if (n.category == 'official_profile_bundle' ||
        n.category == 'official_template') {
      continue;
    }
    await _insertFtsRow(
      db,
      entityType: 'note',
      entityId: n.id,
      areaId: n.areaId ?? '',
      category: n.category,
      title: n.title,
      body: '${KnowledgeSearchCommon.extractNoteBody(n)} ${n.propertiesJson}',
      tagsText: KnowledgeSearchCommon.decodeTagsText(n.tags),
    );
  }

  final questions = await (db.select(
    db.knowledgeQuestions,
  )..where((t) => t.deletedAt.isNull())).get();
  for (final q in questions) {
    await _insertFtsRow(
      db,
      entityType: 'question',
      entityId: q.id,
      areaId: q.areaId ?? '',
      category: q.category,
      title: q.question,
      body: '${q.context ?? ''} ${q.answer ?? ''}',
      tagsText: '${q.category} ${q.status}',
    );
  }

  final docs = await (db.select(
    db.knowledgeDocuments,
  )..where((t) => t.deletedAt.isNull())).get();
  for (final d in docs) {
    await _insertFtsRow(
      db,
      entityType: 'document',
      entityId: d.id,
      areaId: d.areaId ?? '',
      category: d.category,
      title: d.title,
      body: '${d.fileName} ${d.description ?? ''} ${d.extractedText ?? ''}',
      tagsText: KnowledgeSearchCommon.decodeTagsText(d.tags),
    );
  }

  final resources = await (db.select(
    db.knowledgeResources,
  )..where((t) => t.deletedAt.isNull())).get();
  for (final r in resources) {
    await _insertFtsRow(
      db,
      entityType: 'resource',
      entityId: r.id,
      areaId: r.areaId ?? '',
      category: r.category,
      title: r.title,
      body: '${r.url ?? ''} ${r.description ?? ''} ${r.resourceType}',
      tagsText: KnowledgeSearchCommon.decodeTagsText(r.tags),
    );
  }
}

Future<void> _insertFtsRow(
  AppDatabase db, {
  required String entityType,
  required String entityId,
  required String areaId,
  required String category,
  required String title,
  required String body,
  required String tagsText,
}) async {
  await db.customStatement(
    'INSERT INTO kb_fts (entity_type, entity_id, area_id, category, title, body, tags_text) '
    'VALUES (?, ?, ?, ?, ?, ?, ?)',
    [entityType, entityId, areaId, category, title, body, tagsText],
  );
}

Future<void> syncEntityInIndex(
  AppDatabase db, {
  required String entityType,
  required String entityId,
}) async {
  final ready = await _ensureFtsReady(db);
  if (!ready) return;

  final normalizedType = switch (entityType) {
    'knowledge_notes' || 'note' => 'note',
    'knowledge_questions' || 'question' => 'question',
    'knowledge_documents' || 'document' => 'document',
    'knowledge_resources' || 'resource' => 'resource',
    _ => entityType,
  };

  try {
    await db.customStatement(
      'DELETE FROM kb_fts WHERE entity_type = ? AND entity_id = ?',
      [normalizedType, entityId],
    );

    switch (normalizedType) {
      case 'note':
        final n = await (db.select(
          db.knowledgeNotes,
        )..where((t) => t.id.equals(entityId))).getSingleOrNull();
        if (n != null &&
            n.deletedAt == null &&
            n.category != 'official_profile_bundle' &&
            n.category != 'official_template') {
          await _insertFtsRow(
            db,
            entityType: 'note',
            entityId: n.id,
            areaId: n.areaId ?? '',
            category: n.category,
            title: n.title,
            body:
                '${KnowledgeSearchCommon.extractNoteBody(n)} ${n.propertiesJson}',
            tagsText: KnowledgeSearchCommon.decodeTagsText(n.tags),
          );
        }
        break;
      case 'question':
        final q = await (db.select(
          db.knowledgeQuestions,
        )..where((t) => t.id.equals(entityId))).getSingleOrNull();
        if (q != null && q.deletedAt == null) {
          await _insertFtsRow(
            db,
            entityType: 'question',
            entityId: q.id,
            areaId: q.areaId ?? '',
            category: q.category,
            title: q.question,
            body: '${q.context ?? ''} ${q.answer ?? ''}',
            tagsText: '${q.category} ${q.status}',
          );
        }
        break;
      case 'document':
        final d = await (db.select(
          db.knowledgeDocuments,
        )..where((t) => t.id.equals(entityId))).getSingleOrNull();
        if (d != null && d.deletedAt == null) {
          await _insertFtsRow(
            db,
            entityType: 'document',
            entityId: d.id,
            areaId: d.areaId ?? '',
            category: d.category,
            title: d.title,
            body:
                '${d.fileName} ${d.description ?? ''} ${d.extractedText ?? ''}',
            tagsText: KnowledgeSearchCommon.decodeTagsText(d.tags),
          );
        }
        break;
      case 'resource':
        final r = await (db.select(
          db.knowledgeResources,
        )..where((t) => t.id.equals(entityId))).getSingleOrNull();
        if (r != null && r.deletedAt == null) {
          await _insertFtsRow(
            db,
            entityType: 'resource',
            entityId: r.id,
            areaId: r.areaId ?? '',
            category: r.category,
            title: r.title,
            body: '${r.url ?? ''} ${r.description ?? ''} ${r.resourceType}',
            tagsText: KnowledgeSearchCommon.decodeTagsText(r.tags),
          );
        }
        break;
    }
  } catch (e, st) {
    AppLogger.debug(
      'Falha ao atualizar entidade no índice FTS5 ($normalizedType/$entityId): $e',
      st,
    );
  }
}

Future<void> rebuildKnowledgeIndex(AppDatabase db) async {
  _ftsReady[db] = null;
  _ftsUnavailable[db] = null;
  final ready = await _ensureFtsReady(db);
  if (ready) {
    await _populateAllRows(db);
  }
}

String _buildFtsMatchExpr(List<String> tokens) {
  return tokens.map((t) => '"${t.replaceAll('"', '')}"*').join(' AND ');
}

Future<List<KnowledgeSearchResult>> searchKnowledgeIndexed(
  AppDatabase db,
  String query, {
  int limit = 30,
  String? areaId,
}) async {
  final tokens = KnowledgeSearchCommon.tokenizeQuery(query);
  if (tokens.isEmpty) return const [];

  final ready = await _ensureFtsReady(db);
  if (!ready) {
    return KnowledgeSearchCommon.fallbackSearch(
      db,
      query,
      limit: limit,
      areaId: areaId,
    );
  }

  try {
    final matchExpr = _buildFtsMatchExpr(tokens);
    final sql = StringBuffer(
      'SELECT entity_type, entity_id, area_id, category, title, body, '
      'bm25(kb_fts, 4.0, 1.0, 2.5) AS rank '
      'FROM kb_fts WHERE kb_fts MATCH ? ',
    );
    final vars = <drift.Variable<Object>>[drift.Variable.withString(matchExpr)];
    if (areaId != null && areaId.isNotEmpty) {
      sql.write('AND area_id = ? ');
      vars.add(drift.Variable.withString(areaId));
    }
    sql.write('ORDER BY rank LIMIT ?');
    vars.add(drift.Variable.withInt(limit));

    final rows = await db.customSelect(sql.toString(), variables: vars).get();
    final ftsResults = <KnowledgeSearchResult>[];
    final seen = <String>{};

    // Hidrata timestamps atualizados diretamente da linha para manter ordenação/exibição fidedignas.
    for (final row in rows) {
      final type = row.read<String>('entity_type');
      final id = row.read<String>('entity_id');
      final rowAreaId = row.read<String>('area_id');
      final category = row.read<String>('category');
      final title = row.read<String>('title');
      final body = row.read<String>('body');
      final bm25Score = row.read<double>('rank');
      final key = '$type|$id';
      if (!seen.add(key)) continue;

      final updatedAt = await _lookupUpdatedAt(db, type, id);
      if (updatedAt == null) continue; // já foi deletado

      ftsResults.add(
        KnowledgeSearchResult(
          id: id,
          title: title,
          snippet: KnowledgeSearchCommon.buildSnippet(
            body,
            queryTokens: tokens,
          ),
          entityType: type,
          category: category,
          updatedAt: updatedAt,
          areaId: rowAreaId.isEmpty ? null : rowAreaId,
          // FTS5 bm25 retorna valores mais negativos para melhores correspondências.
          score: -bm25Score + 100.0,
        ),
      );
    }

    if (ftsResults.isNotEmpty) {
      return ftsResults;
    }

    // Fallback substring se FTS5 prefix não encontrou parte interna do token (ex: números ou extensões)
    return await KnowledgeSearchCommon.fallbackSearch(
      db,
      query,
      limit: limit,
      areaId: areaId,
    );
  } catch (e, st) {
    AppLogger.debug('Consulta FTS5 alternada para busca Dart pura: $e', st);
    return KnowledgeSearchCommon.fallbackSearch(
      db,
      query,
      limit: limit,
      areaId: areaId,
    );
  }
}

Future<DateTime?> _lookupUpdatedAt(
  AppDatabase db,
  String entityType,
  String entityId,
) async {
  switch (entityType) {
    case 'note':
      final row =
          await (db.select(db.knowledgeNotes)
                ..where((t) => t.id.equals(entityId) & t.deletedAt.isNull()))
              .getSingleOrNull();
      return row?.updatedAt;
    case 'question':
      final row =
          await (db.select(db.knowledgeQuestions)
                ..where((t) => t.id.equals(entityId) & t.deletedAt.isNull()))
              .getSingleOrNull();
      return row?.updatedAt;
    case 'document':
      final row =
          await (db.select(db.knowledgeDocuments)
                ..where((t) => t.id.equals(entityId) & t.deletedAt.isNull()))
              .getSingleOrNull();
      return row?.updatedAt;
    case 'resource':
      final row =
          await (db.select(db.knowledgeResources)
                ..where((t) => t.id.equals(entityId) & t.deletedAt.isNull()))
              .getSingleOrNull();
      return row?.updatedAt;
    default:
      return null;
  }
}
