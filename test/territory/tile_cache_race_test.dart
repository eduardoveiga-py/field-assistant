import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/territory/tile_cache/tile_cache_service.dart';

class DelayedTiles implements TileCacheBackend {
  final pending = <Completer<Uint8List?>>[];
  @override
  Future<Uint8List?> getTile(int z, int x, int y, [MapLayerStyle? style]) {
    final c = Completer<Uint8List?>();
    pending.add(c);
    return c.future;
  }
  @override
  Future<void> saveTile(int z, int x, int y, Uint8List bytes, [MapLayerStyle? style]) async {}
  @override
  Future<bool> isTileCached(int z, int x, int y, [MapLayerStyle? style]) async => false;
  @override
  Future<int> getCachedTileCount([MapLayerStyle? style]) async => 0;
}

void main() {
  test('resposta antiga não contamina cache nem remove pedido novo', () async {
    final cache = TileCacheService.instance;
    final backend = DelayedTiles();
    cache.backend = backend;
    cache.setLayerStyle(MapLayerStyle.topo);
    addTearDown(() => cache.setLayerStyle(MapLayerStyle.standard));
    final old = cache.getTileBytes(9, 3, 4);
    await Future<void>.delayed(Duration.zero);
    cache.setLayerStyle(MapLayerStyle.dark);
    cache.setLayerStyle(MapLayerStyle.topo);
    final current = cache.getTileBytes(9, 3, 4);
    await Future<void>.delayed(Duration.zero);
    expect(backend.pending, hasLength(2));
    backend.pending[0].complete(Uint8List.fromList([1]));
    expect(await old, [1]);
    final concurrent = cache.getTileBytes(9, 3, 4);
    await Future<void>.delayed(Duration.zero);
    expect(backend.pending, hasLength(2));
    backend.pending[1].complete(Uint8List.fromList([2]));
    expect(await current, [2]);
    expect(await concurrent, [2]);
    expect(await cache.getTileBytes(9, 3, 4), [2]);
  });
}
