import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ministerio_pessoal/territory/map_engine/map_asset_manager.dart';
import 'package:ministerio_pessoal/territory/map_engine/maplibre_native_adapter.dart';
import 'package:ministerio_pessoal/territory/map_engine/offline_tile_server.dart';
import 'package:ministerio_pessoal/ui/widgets/map/maplibre_vector_map_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'MapLibreVectorMapView Platform Support & Offline Stack Integration',
    () {
      test(
        'isSupportedOnCurrentPlatform matches maplibre_gl target platforms',
        () {
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          expect(MapLibreVectorMapView.isSupportedOnCurrentPlatform, isTrue);

          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          expect(MapLibreVectorMapView.isSupportedOnCurrentPlatform, isTrue);

          debugDefaultTargetPlatformOverride = TargetPlatform.windows;
          expect(MapLibreVectorMapView.isSupportedOnCurrentPlatform, isFalse);

          debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
          expect(MapLibreVectorMapView.isSupportedOnCurrentPlatform, isFalse);

          debugDefaultTargetPlatformOverride = TargetPlatform.linux;
          expect(MapLibreVectorMapView.isSupportedOnCurrentPlatform, isFalse);

          debugDefaultTargetPlatformOverride = null;
        },
      );

      test('MaplibreNativeAdapter + OfflineTileServer serve complete offline Style JSON, SDF font, and RGBA sprites', () async {
        HttpOverrides.global = null;
        final tileServer = OfflineTileServer(
          assetsDir: Directory('assets/map'),
        );
        final adapter = MaplibreNativeAdapter(
          tileServer: tileServer,
          ownsTileServer: true,
        );

        try {
          await adapter.initialize();
          await adapter.updateContactsOverlay([
            {
              'id': 'c1',
              'name': 'Ana Costa',
              'latitude': -3.1019,
              'longitude': -60.025,
            },
          ]);
          await adapter.updateLandmarksOverlay([
            {
              'id': 'lm1',
              'title': 'Escola Municipal',
              'latitude': -3.1025,
              'longitude': -60.026,
            },
          ]);

          final spec = adapter.generateStyleSpecification(
            packageId: 'br_am_solimoes',
          );
          final spriteBase = spec['sprite'] as String;
          final glyphsTemplate = spec['glyphs'] as String;

          // Fetch sprite JSON & PNG directly from URLs generated inside Style JSON
          final spriteJsonRes = await http.get(Uri.parse('$spriteBase.json'));
          expect(spriteJsonRes.statusCode, equals(200));
          expect(spriteJsonRes.body, contains('marker-15'));
          expect(spriteJsonRes.body, contains('landmark-15'));

          final spritePngRes = await http.get(Uri.parse('$spriteBase.png'));
          expect(spritePngRes.statusCode, equals(200));

          // Fetch Noto Sans Regular 0-255 SDF font PBF directly from glyphs template
          final fontUrl = glyphsTemplate
              .replaceAll(
                '{fontstack}',
                Uri.encodeComponent('Noto Sans Regular'),
              )
              .replaceAll('{range}', '0-255');
          final fontRes = await http.get(Uri.parse(fontUrl));
          expect(fontRes.statusCode, equals(200));
          expect(fontRes.bodyBytes.length, greaterThan(40000));
        } finally {
          adapter.dispose();
        }
      });

      test('MapAssetManager copies real assets into temp dir and serves via OfflineTileServer', () async {
        final tempDir = Directory.systemTemp.createTempSync('maplibre_assets_');
        final tileServer = OfflineTileServer();
        final assetManager = MapAssetManager(targetDir: tempDir);
        final adapter = MaplibreNativeAdapter(
          tileServer: tileServer,
          ownsTileServer: true,
          assetManager: assetManager,
        );

        try {
          await adapter.initialize();
          expect(tileServer.assetsDir, isNotNull);
          expect(tileServer.assetsDir!.existsSync(), isTrue);
        } finally {
          adapter.dispose();
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        }
      });
    },
  );
}
