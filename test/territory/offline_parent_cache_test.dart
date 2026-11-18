import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_service.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_web.dart';
import 'package:ministerio_pessoal/territory/tile_cache/tile_cache_service.dart';

class CountingMap extends MBTilesWeb {
  int calls = 0;
  Completer<Uint8List?>? pending;
  Uint8List bytes = Uint8List.fromList([1, 2, 3]);

  @override
  Future<Uint8List?> getTile(int z, int x, int y) {
    calls++;
    return pending?.future ?? Future.value(bytes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'ancestrais são compartilhados e invalidados ao trocar pacote',
    () async {
      final original = MBTilesService.instance;
      final backend = CountingMap();
      final service = MBTilesService.custom(backend: backend);
      MBTilesService.setMockInstance(service);
      addTearDown(() {
        MBTilesService.setMockInstance(original);
        service.dispose();
      });
      backend.pending = Completer<Uint8List?>();
      final cache = TileCacheService.instance;
      final first = cache.getOfflineTileBytes(16, 100, 150);
      final second = cache.getOfflineTileBytes(16, 100, 150);
      expect(backend.calls, 1);
      backend.pending!.complete(backend.bytes);
      expect(await first, [1, 2, 3]);
      expect(await second, [1, 2, 3]);
      expect(await cache.getOfflineTileBytes(16, 100, 150), [1, 2, 3]);
      expect(backend.calls, 1);

      backend.pending = null;
      backend.bytes = Uint8List.fromList([4, 5]);
      service.tilesRevision.value++;
      expect(await cache.getOfflineTileBytes(16, 100, 150), [4, 5]);
      expect(backend.calls, 2);
    },
  );

  test('resultado de leitura antiga não contamina cache após troca', () async {
    final original = MBTilesService.instance;
    final backend = CountingMap()..pending = Completer<Uint8List?>();
    final service = MBTilesService.custom(backend: backend);
    MBTilesService.setMockInstance(service);
    addTearDown(() {
      MBTilesService.setMockInstance(original);
      service.dispose();
    });
    final cache = TileCacheService.instance;
    final old = cache.getOfflineTileBytes(16, 1, 2);
    final oldPending = backend.pending!;
    backend.pending = null;
    backend.bytes = Uint8List.fromList([9]);
    service.tilesRevision.value++;
    expect(await cache.getOfflineTileBytes(16, 1, 2), [9]);
    oldPending.complete(Uint8List.fromList([1]));
    expect(await old, [1]);
    expect(await cache.getOfflineTileBytes(16, 1, 2), [9]);
    expect(backend.calls, 2);
  });
}
