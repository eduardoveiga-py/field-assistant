import '../database/app_database.dart';
import 'knowledge_search_common.dart';

/// Implementação Web PWA do índice de busca do Segundo Cérebro (sem `dart:io` nem FTS5 nativo).
Future<List<KnowledgeSearchResult>> searchKnowledgeIndexed(
  AppDatabase db,
  String query, {
  int limit = 30,
  String? areaId,
}) {
  return KnowledgeSearchCommon.fallbackSearch(
    db,
    query,
    limit: limit,
    areaId: areaId,
  );
}

Future<void> syncEntityInIndex(
  AppDatabase db, {
  required String entityType,
  required String entityId,
}) async {
  // Na Web PWA a pesquisa consulta diretamente as tabelas em memória / IndexedDB via fallbackSearch.
}

Future<void> rebuildKnowledgeIndex(AppDatabase db) async {
  // No-op na Web PWA.
}
