library;

/// Fachada de exportação condicional para [OfflineTileServer].
///
/// Seleciona a implementação completa baseada em Shelf e `dart:io` para plataformas nativas,
/// e um stub seguro sem dependências de `dart:ffi` ou `HttpServer` para Flutter Web.
export 'offline_tile_server_web.dart'
    if (dart.library.io) 'offline_tile_server_io.dart';
