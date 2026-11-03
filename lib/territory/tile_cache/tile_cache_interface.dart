import 'dart:typed_data';

abstract class TileCacheBackend {
  Future<Uint8List?> getTile(int z, int x, int y);
  Future<void> saveTile(int z, int x, int y, Uint8List bytes);
  Future<bool> isTileCached(int z, int x, int y);
  Future<int> getCachedTileCount();
}

abstract class TileCacheCancellable {
  void cancelTile(int z, int x, int y);
  void cancelZoomExcept(int currentZoom);
}
