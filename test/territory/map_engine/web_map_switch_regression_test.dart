import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/territory/map_engine/maplibre_native_adapter.dart';
import 'package:ministerio_pessoal/territory/tile_cache/tile_cache_service.dart';
import 'package:ministerio_pessoal/territory/tile_cache/tile_cache_web.dart';
import 'package:ministerio_pessoal/ui/widgets/map/maplibre_vector_map_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('web cache never labels standard fallback as another style', () async {
    TileCacheWeb.clearCache();
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      if (request.url.host == 'a.tile.openstreetmap.fr') {
        return http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200);
      }
      return http.Response('unavailable', 503);
    });
    addTearDown(client.close);
    addTearDown(TileCacheWeb.clearCache);
    final cache = TileCacheWeb(httpClient: client);
    for (final style in [MapLayerStyle.satellite, MapLayerStyle.topo, MapLayerStyle.dark]) {
      requests.clear();
      expect(await cache.getTile(7, 3, 4, style), isNull);
      expect(requests, hasLength(1));
      expect(await cache.isTileCached(7, 3, 4, style), isFalse);
    }
    requests.clear();
    expect(await cache.getTile(7, 3, 4, MapLayerStyle.standard), [1, 2, 3]);
    expect(requests.map((uri) => uri.host), ['tile.openstreetmap.org', 'a.tile.openstreetmap.fr']);
  });

  testWidgets('missing vector source offers an explicit return to raster', (tester) async {
    final adapter = MaplibreNativeAdapter();
    addTearDown(adapter.dispose);
    var raster = false;
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(
      builder: (context, setState) => Scaffold(body: raster
          ? const Text('Raster ativo')
          : MapLibreVectorMapView(
              adapter: adapter,
              initialLat: -3.1,
              initialLng: -60,
              initialZoom: 12,
              onSwitchToRaster: () => setState(() => raster = true),
            )),
    )));
    expect(find.text('Voltar ao mapa raster'), findsOneWidget);
    expect(find.text('Raster ativo'), findsNothing);
    await tester.tap(find.text('Voltar ao mapa raster'));
    await tester.pump();
    expect(find.text('Raster ativo'), findsOneWidget);
    expect(find.byType(MapLibreVectorMapView), findsNothing);
  });
}
