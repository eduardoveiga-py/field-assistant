import 'offline_geocoding_service.dart';

/// Stub Web para busca FTS5 em bases cartográficas OSM (*.search.db).
///
/// Em navegadores Web, acesso direto ao sistema de arquivos local (`dart:io`) e
/// vinculações nativas SQLite via FFI (`dart:ffi`) são inviáveis devido ao sandbox
/// e à ausência de FFI nativo. Esta implementação stub retorna coleções vazias
/// com segurança e sem quebrar os contratos de chamada.
class OsmFtsSearch {
  /// Getter stub para compatibilidade com plataformas IO.
  static dynamic get packagesDirectory => null;

  /// Setter stub para compatibilidade com plataformas IO.
  static set packagesDirectory(dynamic dir) {}

  /// Define o diretório padrão de pacotes cartográficos (no-op na Web).
  static void setPackagesDirectory(dynamic dir) {}

  /// Stub para resolução de arquivos de busca na Web (sempre vazio).
  static List<dynamic> resolveSearchFiles({
    dynamic packagesDir,
    String? packagesDirectoryPath,
    dynamic searchDatabases,
  }) {
    return const [];
  }

  /// Sanitiza e formata a query para matching no FTS5 (compatível com Web).
  static String sanitizeFtsQuery(String input, {bool stripNumbers = false}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    final cleanInput = trimmed.replaceAll(
      RegExp(r'[^\p{L}\p{N}]+', unicode: true),
      ' ',
    );
    final words = cleanInput
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .where((w) => !stripNumbers || !RegExp(r'^\d+$').hasMatch(w))
        .map((w) => '"$w"*')
        .toList();
    if (words.isEmpty) return '';
    return words.join(' ');
  }

  /// Mapeia categorias do OpenStreetMap para o enum unificado [LocalResultType].
  static LocalResultType mapCategoryToResultType(String category) {
    final c = category.toLowerCase().trim();
    if (c == 'street' ||
        c == 'highway' ||
        c == 'road' ||
        c == 'rua' ||
        c == 'avenida' ||
        c == 'travessa' ||
        c == 'alameda') {
      return LocalResultType.street;
    }
    if (c == 'place' ||
        c == 'suburb' ||
        c == 'village' ||
        c == 'community' ||
        c == 'comunidade' ||
        c == 'aldeia' ||
        c == 'bairro' ||
        c == 'cidade' ||
        c == 'municipality') {
      return LocalResultType.place;
    }
    if (c == 'contact') return LocalResultType.contact;
    if (c == 'sector') return LocalResultType.sector;
    if (c == 'landmark') return LocalResultType.landmark;
    return LocalResultType.poi;
  }

  /// Stub para busca FTS5 em banco individual na Web.
  static List<LocalSearchResult> searchOsmDatabase(
    dynamic file,
    String rawQuery,
    int limit,
  ) {
    return const [];
  }

  /// Ponto de entrada unificado para consulta em todas as bases `.search.db`.
  static List<LocalSearchResult> search({
    required String query,
    dynamic packagesDir,
    String? packagesDirectoryPath,
    dynamic searchDatabases,
    int limit = 50,
  }) {
    return const [];
  }
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
