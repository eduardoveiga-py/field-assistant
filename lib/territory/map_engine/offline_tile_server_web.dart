import 'dart:async';
import 'dart:typed_data';

/// Callback para busca de tile raster ou vetorial por coordenadas z, x, y.
typedef TileLookup = Future<Uint8List?> Function(int z, int x, int y);

/// Stub Web para [OfflineTileServer].
///
/// Em navegadores Web, a execução de servidores HTTP TCP locais (Shelf / HttpServer)
/// e o uso de `dart:ffi` / `sqlite3` nativo são inviáveis por restrições de sandbox.
/// Esta implementação stub permite compilar o aplicativo para Flutter Web
/// mantendo a mesma assinatura pública e contratos sem dependências nativas.
class OfflineTileServer {
  TileLookup? tileLookup;
  dynamic packagesDir;
  dynamic assetsDir;

  OfflineTileServer({this.tileLookup, this.packagesDir, this.assetsDir});

  /// Em ambiente Web, o servidor HTTP de loopback está permanentemente inativo.
  bool get isRunning => false;

  /// Porta TCP nula em ambiente Web.
  int? get port => null;

  /// URL base nula em ambiente Web.
  String? get baseUrl => null;

  void setTileLookup(TileLookup lookup) {
    tileLookup = lookup;
  }

  void setPackagesDirectory(dynamic dir) {
    packagesDir = dir;
  }

  void setAssetsDirectory(dynamic dir) {
    assetsDir = dir;
  }

  void registerPmtilesPackage(String packageId, dynamic file) {}

  void unregisterPmtilesPackage(String packageId) {}

  void registerMbtilesPackage(String packageId, dynamic file) {}

  void unregisterMbtilesPackage(String packageId) {}

  Future<int> start({int desiredPort = 0}) async {
    return 0;
  }

  Future<void> stop({bool force = false}) async {}

  Future<void> dispose() async {}
}
