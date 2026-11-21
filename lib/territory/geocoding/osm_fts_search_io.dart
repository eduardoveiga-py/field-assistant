import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sql;

import '../../core/app_logger.dart';
import 'offline_geocoding_service.dart';

/// Implementação nativa (IO / Desktop / Mobile) para busca FTS5 em bases OSM (*.search.db).
///
/// Utiliza `dart:io` e `package:sqlite3` nativo com FTS5 (`unicode61 remove_diacritics 2`)
/// para consultar pacotes cartográficos locais sem requisições de rede.
class OsmFtsSearch {
  /// Define o diretório padrão de pacotes cartográficos.
  static void setPackagesDirectory(dynamic dir) {
    if (dir == null) {
      OfflineGeocodingService.packagesDirectoryPath = null;
    } else if (dir is Directory) {
      OfflineGeocodingService.packagesDirectoryPath = dir.path;
    } else if (dir is String) {
      OfflineGeocodingService.packagesDirectoryPath = dir;
    }
  }

  /// Retorna o diretório padrão de pacotes como [Directory], se configurado.
  static Directory? get packagesDirectory {
    final path = OfflineGeocodingService.packagesDirectoryPath;
    if (path == null || path.trim().isEmpty) return null;
    return Directory(path);
  }

  /// Localiza arquivos `*.search.db` no diretório informado ou na lista direta.
  static List<File> resolveSearchFiles({
    dynamic packagesDir,
    String? packagesDirectoryPath,
    dynamic searchDatabases,
  }) {
    if (searchDatabases != null) {
      if (searchDatabases is List<File>) {
        return searchDatabases.where((f) => f.existsSync()).toList();
      }
      if (searchDatabases is Iterable) {
        final result = <File>[];
        for (final item in searchDatabases) {
          if (item is File) {
            if (item.existsSync()) result.add(item);
          } else if (item is String) {
            final f = File(item);
            if (f.existsSync()) result.add(f);
          }
        }
        return result;
      }
    }

    Directory? dir;
    if (packagesDir is Directory) {
      dir = packagesDir;
    } else if (packagesDir is String && packagesDir.trim().isNotEmpty) {
      dir = Directory(packagesDir);
    } else if (packagesDirectoryPath != null &&
        packagesDirectoryPath.trim().isNotEmpty) {
      dir = Directory(packagesDirectoryPath);
    } else if (OfflineGeocodingService.packagesDirectoryPath != null &&
        OfflineGeocodingService.packagesDirectoryPath!.trim().isNotEmpty) {
      dir = Directory(OfflineGeocodingService.packagesDirectoryPath!);
    }

    if (dir == null || !dir.existsSync()) {
      return const [];
    }

    try {
      return dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.search.db'))
          .toList();
    } catch (e, st) {
      AppLogger.warning(
        'Erro ao listar índices de busca em ${dir.path}',
        e,
        st,
      );
      return const [];
    }
  }

  /// Sanitiza e formata a query para matching de prefixo no FTS5.
  static String sanitizeFtsQuery(String input, {bool stripNumbers = false}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    // Substitui pontuações, hífens, apóstrofos e caracteres especiais por espaço
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

  /// Executa consulta FTS5 direta em um arquivo `.search.db`.
  static List<LocalSearchResult> searchOsmDatabase(
    File file,
    String rawQuery,
    int limit,
  ) {
    final results = <LocalSearchResult>[];
    sql.Database? osmDb;
    try {
      osmDb = sql.sqlite3.open(file.path, mode: sql.OpenMode.readOnly);
      final check = osmDb.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='osm_places_fts';",
      );
      if (check.isEmpty) return const [];

      final sanitized = sanitizeFtsQuery(rawQuery);
      if (sanitized.isEmpty) return const [];

      final originName = p.basename(file.path);
      final stmt = osmDb.prepare(
        'SELECT rowid, name, category, subtitle, lat, lng FROM osm_places_fts WHERE osm_places_fts MATCH ? LIMIT ?;',
      );
      try {
        var rows = stmt.select([sanitized, limit]);
        if (rows.isEmpty) {
          final fallbackQuery = sanitizeFtsQuery(rawQuery, stripNumbers: true);
          if (fallbackQuery.isNotEmpty && fallbackQuery != sanitized) {
            rows = stmt.select([fallbackQuery, limit]);
          }
        }
        for (final row in rows) {
          final rawCat = (row['category']?.toString() ?? 'poi').trim();
          final type = mapCategoryToResultType(rawCat);
          final title = row['name']?.toString() ?? '';
          final subtitle = row['subtitle']?.toString();
          final lat = double.tryParse(row['lat']?.toString() ?? '');
          final lng = double.tryParse(row['lng']?.toString() ?? '');
          final rowid = row['rowid']?.toString() ?? '';

          results.add(
            LocalSearchResult(
              id: 'osm_${originName}_$rowid',
              type: type,
              title: title,
              subtitle: subtitle,
              latitude: lat,
              longitude: lng,
              metadata: {'category': rawCat, 'origin': originName},
              origin: originName,
            ),
          );
        }
      } finally {
        stmt.close();
      }
    } catch (e, st) {
      AppLogger.warning(
        'Erro ao consultar índice FTS5 no arquivo ${file.path}',
        e,
        st,
      );
    } finally {
      try {
        osmDb?.close();
      } catch (_) {}
    }
    return results;
  }

  /// Ponto de entrada unificado para consulta em todas as bases `.search.db` encontradas.
  static List<LocalSearchResult> search({
    required String query,
    dynamic packagesDir,
    String? packagesDirectoryPath,
    dynamic searchDatabases,
    int limit = 50,
  }) {
    final osmResults = <LocalSearchResult>[];
    final searchFiles = resolveSearchFiles(
      packagesDir: packagesDir,
      packagesDirectoryPath: packagesDirectoryPath,
      searchDatabases: searchDatabases,
    );

    for (final file in searchFiles) {
      final fileResults = searchOsmDatabase(file, query, limit);
      osmResults.addAll(fileResults);
    }
    return osmResults;
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
  return OsmFtsSearch.search(
    query: query,
    packagesDir: packagesDir,
    packagesDirectoryPath: packagesDirectoryPath,
    searchDatabases: searchDatabases,
    limit: limit,
  );
}
