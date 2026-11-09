import 'dart:typed_data';

abstract class MBTilesBackend {
  Future<void> init();
  Future<Uint8List?> getTile(int z, int x, int y);
  void dispose();
}
