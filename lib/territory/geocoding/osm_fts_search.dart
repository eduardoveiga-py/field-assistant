library;

/// Fachada de exportação condicional para busca FTS5 offline em bases OSM (*.search.db).
///
/// Seleciona a implementação completa com sqlite3 e `dart:io` para plataformas nativas,
/// e um stub seguro sem dependências de `dart:ffi` ou `sqlite3` para Flutter Web.
export 'osm_fts_search_web.dart' if (dart.library.io) 'osm_fts_search_io.dart';
