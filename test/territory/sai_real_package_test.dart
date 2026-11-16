import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final source = Platform.environment['SAI_MBTILES'];
  test('pacote real de SAI é importado e contém tiles raster da sede', () async {
    final temp = await Directory.systemTemp.createTemp('sai_map_import_');
    final backend = MBTilesNative(customDir: temp);
    try {
      await backend.importRegionFile(regionId: 'sai', sourceFilePath: source!);
      for (final tile in [(8, 79, 130), (12, 1274, 2083), (16, 20399, 33332)]) {
        final bytes = await backend.getTile(tile.$1, tile.$2, tile.$3);
        expect(bytes, isNotNull, reason: 'tile da sede no zoom ${tile.$1}');
        final codec = await ui.instantiateImageCodec(bytes!);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 256);
        expect(frame.image.height, 256);
        if (tile.$1 == 16) {
          // Garante que o bloco da sede não seja apenas uma cor de fundo.
          // Não comprova exatidão ou cobertura das comunidades.
          final rgba = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
          expect(rgba, isNotNull);
          final pixels = rgba!.buffer.asUint32List();
          expect(pixels.toSet().length, greaterThan(2));
        }
        frame.image.dispose();
        codec.dispose();
      }
    } finally {
      backend.dispose();
      await temp.delete(recursive: true);
    }
  }, skip: source == null || source.isEmpty ? 'Requer o pacote regional gerado no CI.' : false);
}
