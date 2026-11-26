import '../database/app_database.dart';
import 'knowledge_search_common.dart';
import 'knowledge_search_index_web.dart'
    if (dart.library.io) 'knowledge_search_index_io.dart'
    as impl;

export 'knowledge_search_common.dart'
    show KnowledgeSearchCommon, KnowledgeSearchResult;

/// Fachada multiplataforma de indexação e busca FTS5 (SQLite no Native IO;
/// índice normalizado em Dart na Web PWA sem `dart:io` nem `sqlite3`).
class KnowledgeSearchIndex {
  static Future<List<KnowledgeSearchResult>> search(
    AppDatabase db,
    String query, {
    int limit = 30,
    String? areaId,
  }) => impl.searchKnowledgeIndexed(db, query, limit: limit, areaId: areaId);

  static Future<void> syncEntity(
    AppDatabase db, {
    required String entityType,
    required String entityId,
  }) => impl.syncEntityInIndex(db, entityType: entityType, entityId: entityId);

  static Future<void> rebuildAll(AppDatabase db) =>
      impl.rebuildKnowledgeIndex(db);
}
