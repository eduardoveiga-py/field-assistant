import 'dart:typed_data';

import 'mbtiles_backend.dart';

MBTilesBackend getMBTilesBackend() => MBTilesWeb();

class MBTilesWeb implements MBTilesBackend {
  @override
  Future<void> init() async {}

  @override
  Future<Uint8List?> getTile(int z, int x, int y) async => null;

  @override
  void dispose() {}
}
