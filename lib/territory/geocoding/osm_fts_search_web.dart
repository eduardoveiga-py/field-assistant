import 'offline_geocoding_service.dart';

/// Stub Web para busca FTS5 em bases cartográficas OSM (*.search.db).
///
/// Em navegadores Web, acesso direto ao sistema de arquivos local (`dart:io`) e
/// vinculações nativas SQLite via FFI (`dart:ffi`) são inviáveis devido ao sandbox
/// e à ausência de FFI nativo. Esta implementação stub retorna coleções vazias
/// com segurança e sem quebrar os contratos de chamada.
class OsmFtsSearch {
  static List<LocalSearchResult> search({
    required String query,
    dynamic packagesDir,
    String? packagesDirectoryPath,
    dynamic searchDatabases,
    int limit = 50,
  }) {
    return const [];
  }

  static void setPackagesDirectory(dynamic dir) {}
}

/// Helper top-level retrocompatível para busca FTS5 OSM.
List<LocalSearchResult> searchOsmFts({
  required String query,
  dynamic packagesDir,
  String? packagesDirectoryPath,
  dynamic searchDatabases,
  int limit = 50,
}) {
  return const [];
}
