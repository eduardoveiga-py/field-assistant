import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/territory/map_engine/maplibre_native_adapter.dart';
import 'package:ministerio_pessoal/territory/map_engine/offline_tile_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OfflineTileServer tileServer;
  late MaplibreNativeAdapter adapter;

  setUp(() {
    tileServer = OfflineTileServer();
    adapter = MaplibreNativeAdapter(
      tileServer: tileServer,
      ownsTileServer: true,
    );
  });

  tearDown(() {
    adapter.dispose();
  });

  group('MaplibreNativeAdapter Advanced Features Tests', () {
    test('Continuous fractional zoom and pitch 3D clamping', () async {
      await adapter.initialize();

      // Zoom fracionário (ex: 14.375)
      await adapter.setZoom(14.375);
      expect(adapter.currentZoom, equals(14.375));

      // Pitch dentro dos limites permitidos (0° a 60°)
      await adapter.setTilt(45.0);
      expect(adapter.currentTilt, equals(45.0));

      // Pitch com clamp superior em 60°
      await adapter.setTilt(85.0);
      expect(adapter.currentTilt, equals(60.0));

      // Pitch com clamp inferior em 0°
      await adapter.setTilt(-10.0);
      expect(adapter.currentTilt, equals(0.0));
    });

    test('360° rotation and auto-counter-rotation formula', () async {
      await adapter.initialize();

      // Rotação 90°
      await adapter.setBearing(90.0);
      expect(adapter.currentBearing, equals(90.0));
      expect(
        MaplibreNativeAdapter.calculateCounterRotationDegrees(90.0),
        equals(270.0),
      );

      // Rotação 180° (Sul) -> contra-rotação deve ser 180° (pi rad)
      await adapter.setBearing(180.0);
      expect(adapter.currentBearing, equals(180.0));
      expect(
        MaplibreNativeAdapter.calculateCounterRotationDegrees(180.0),
        equals(180.0),
      );
      expect(
        MaplibreNativeAdapter.calculateCounterRotationRadians(180.0),
        closeTo(math.pi, 1e-5),
      );

      // Rotação 350° -> contra-rotação 10°
      expect(
        MaplibreNativeAdapter.calculateCounterRotationDegrees(350.0),
        equals(10.0),
      );
    });

    test('Builds and updates GeoJSON FeatureCollections for contacts, landmarks, sectors', () async {
      await adapter.initialize();

      final contacts = [
        {
          'id': 'p1',
          'name': 'João Silva',
          'latitude': -23.5505,
          'longitude': -46.6333,
          'status': 'interessado',
        },
        {
          'id': 'p2',
          'name': 'Maria Santos',
          'latitude': -23.5510,
          'longitude': -46.6340,
          'status': 'revisita',
        },
      ];

      await adapter.updateContactsOverlay(contacts);
      final contactsGeo = adapter.contactsGeoJson;
      expect(contactsGeo, isNotNull);
      expect(contactsGeo!['type'], equals('FeatureCollection'));
      final features = contactsGeo['features'] as List;
      expect(features.length, equals(2));
      expect(
        features[0]['geometry']['coordinates'],
        equals([-46.6333, -23.5505]),
      );
      expect(features[0]['properties']['name'], equals('João Silva'));

      final landmarks = [
        {
          'id': 'lm1',
          'title': 'Padaria Central',
          'latitude': -23.5520,
          'longitude': -46.6350,
          'category': 'comercio',
        },
      ];
      await adapter.updateLandmarksOverlay(landmarks);
      expect(adapter.landmarksGeoJson!['features'].length, equals(1));

      final sectors = [
        {
          'id': 'sec1',
          'name': 'Setor 01',
          'color': '#ff0000',
          'coordinates': [
            [
              [-46.63, -23.55],
              [-46.64, -23.55],
              [-46.64, -23.56],
              [-46.63, -23.56],
              [-46.63, -23.55],
            ],
          ],
        },
      ];
      await adapter.updateSectorsOverlay(sectors);
      expect(adapter.sectorsGeoJson!['features'].length, equals(1));
      expect(
        adapter.sectorsGeoJson!['features'][0]['geometry']['type'],
        equals('Polygon'),
      );
    });

    test(
      'Generates local Style JSON with viewport rotation alignment on symbols',
      () async {
        await adapter.initialize();

        await adapter.updateContactsOverlay([
          {'id': 'p1', 'name': 'Lucas', 'latitude': -3.1, 'longitude': -60.0},
        ]);
        await adapter.updateLandmarksOverlay([
          {
            'id': 'lm1',
            'title': 'Praça Central',
            'latitude': -3.11,
            'longitude': -60.01,
            'category': 'poi',
          },
        ]);

        final spec = adapter.generateStyleSpecification(isDarkMode: true);
        expect(spec['version'], equals(8));
        expect(spec['sprite'], contains('/assets/sprites/sprite'));
        expect(
          spec['glyphs'],
          contains('/assets/fonts/{fontstack}/{range}.pbf'),
        );

        final layers = spec['layers'] as List;
        final contactLayer = layers.firstWhere(
          (l) => l['id'] == 'contacts-layer',
          orElse: () => <String, dynamic>{},
        );
        final landmarkLayer = layers.firstWhere(
          (l) => l['id'] == 'landmarks-layer',
          orElse: () => <String, dynamic>{},
        );

        expect(contactLayer, isNotEmpty);
        final layout = contactLayer['layout'] as Map<String, dynamic>;
        // Invariante essencial para rotação: pinos e nomes de contatos não invertem!
        expect(layout['icon-rotation-alignment'], equals('viewport'));
        expect(layout['text-rotation-alignment'], equals('viewport'));

        expect(landmarkLayer, isNotEmpty);
        final lmLayout = landmarkLayer['layout'] as Map<String, dynamic>;
        expect(lmLayout['icon-image'], equals('landmark-15'));
        expect(lmLayout['icon-rotation-alignment'], equals('viewport'));
        expect(lmLayout['text-rotation-alignment'], equals('viewport'));
      },
    );
  });
}
