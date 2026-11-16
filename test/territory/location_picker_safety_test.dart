import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/territory/geocoding_service.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_service.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_web.dart';
import 'package:ministerio_pessoal/territory/tile_cache/tile_cache_service.dart';
import 'package:ministerio_pessoal/ui/widgets/map_location_picker_dialog.dart';

class EmptyTileCache implements TileCacheBackend {
  @override
  Future<Uint8List?> getTile(int z, int x, int y, [MapLayerStyle? style]) async => null;
  @override
  Future<void> saveTile(int z, int x, int y, Uint8List bytes, [MapLayerStyle? style]) async {}
  @override
  Future<bool> isTileCached(int z, int x, int y, [MapLayerStyle? style]) async => false;
  @override
  Future<int> getCachedTileCount([MapLayerStyle? style]) async => 0;
}

void main() {
  testWidgets('confirmar usa o último ponto mesmo se resposta antiga chega depois', (tester) async {
    final original = MBTilesService.instance;
    final mock = MBTilesService.custom(backend: MBTilesWeb());
    MBTilesService.setMockInstance(mock);
    TileCacheService.instance.backend = EmptyTileCache();
    final requests = <Completer<ReverseGeocodingResult?>>[];
    ReverseGeocodingResult? selected;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(onPressed: () async {
        selected = await showDialog<ReverseGeocodingResult>(
          context: context,
          builder: (_) => MapLocationPickerDialog(
            initialLat: -3, initialLng: -60,
            reverseGeocode: (lat, lng) {
              final request = Completer<ReverseGeocodingResult?>();
              requests.add(request);
              return request.future;
            },
          ),
        );
      }, child: const Text('Abrir')),
    ))));
    await tester.tap(find.text('Abrir'));
    // Há um indicador animado enquanto a consulta simulada permanece pendente.
    await tester.pump(const Duration(milliseconds: 400));
    expect(requests.length, 1);
    // Centro da janela é uma área visível do mapa, longe dos botões.
    await tester.tapAt(tester.getCenter(find.byType(InteractiveViewer)) + const Offset(60, 0));
    // O mesmo gesto também oferece duplo toque: aguarda o prazo de desambiguação.
    await tester.pump(const Duration(milliseconds: 400));
    expect(requests.length, 2);
    requests[0].complete(const ReverseGeocodingResult(latitude: -3, longitude: -60, street: 'Resposta antiga'));
    await tester.pump();
    await tester.tap(find.text('Confirmar Este Ponto'));
    await tester.pumpAndSettle();
    expect(selected, isNotNull);
    expect(selected!.latitude != -3 || selected!.longitude != -60, isTrue);
    expect(selected!.street, isNot('Resposta antiga'));
    requests[1].complete(null);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    MBTilesService.setMockInstance(original);
    mock.dispose();
  });
}
