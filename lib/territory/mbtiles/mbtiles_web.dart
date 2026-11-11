import 'dart:typed_data';

import 'mbtiles_backend.dart';

MBTilesBackend getMBTilesBackend() => MBTilesWeb();

/// Implementação Web do backend MBTiles (operação segura sem acesso a sistema de arquivos).
class MBTilesWeb implements MBTilesBackend {
  @override
  Future<void> init() async {}

  @override
  Future<Uint8List?> getTile(int z, int x, int y) async => null;

  @override
  bool isRegionInstalled(String regionId) => false;

  @override
  String getRegionFilePath(String regionId) => '';

  @override
  int? getRegionFileSize(String regionId) => null;

  @override
  Set<String> getInstalledRegionIds() => {};

  @override
  Future<void> saveRegionStream({
    required String regionId,
    required Stream<List<int>> byteStream,
    int? totalBytes,
    void Function(double progress, int downloadedBytes)? onProgress,
    bool Function()? isCancelled,
  }) async {
    throw UnsupportedError('Armazenamento offline de MBTiles não é suportado no navegador Web.');
  }

  @override
  Future<void> importRegionFile({
    required String regionId,
    required String sourceFilePath,
    void Function(double progress, int copiedBytes)? onProgress,
  }) async {
    throw UnsupportedError('Importação local de arquivo .mbtiles não é suportada no navegador Web.');
  }

  @override
  Future<Map<String, dynamic>> loadUrlConfig() async => const <String, dynamic>{};

  @override
  Future<void> saveUrlConfig(Map<String, dynamic> config) async {}

  @override
  Future<void> deleteRegion(String regionId) async {}

  @override
  Future<void> reload() async {}

  @override
  void dispose() {}
}
