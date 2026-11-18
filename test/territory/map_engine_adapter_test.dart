import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/territory/map_engine/maplibre_native_adapter.dart';
import 'package:ministerio_pessoal/territory/map_engine/offline_tile_server.dart';
import 'package:ministerio_pessoal/territory/map_engine/raster_fallback_adapter.dart';
import 'package:ministerio_pessoal/territory/map_engine_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeoBoundingBox Model Tests', () {
    test('Valid bounding box within normal WGS-84 ranges', () {
      const bbox = GeoBoundingBox(
        minLat: -23.6,
        minLon: -46.7,
        maxLat: -23.4,
        maxLon: -46.5,
      );
      expect(bbox.isValid, isTrue);
      expect(bbox.contains(-23.5, -46.6), isTrue);
      expect(bbox.contains(-24.0, -46.6), isFalse);

      final json = bbox.toJson();
      final restored = GeoBoundingBox.fromJson(json);
      expect(restored.minLat, equals(bbox.minLat));
      expect(restored.maxLat, equals(bbox.maxLat));
    });

    test('Rejects inverted or out-of-range bounds', () {
      const invertedLat = GeoBoundingBox(
        minLat: 10.0,
        minLon: 0.0,
        maxLat: 5.0,
        maxLon: 10.0,
      );
      expect(invertedLat.isValid, isFalse);

      expect(
        () => GeoBoundingBox.fromJson({
          'minLat': 100.0,
          'minLon': 0.0,
          'maxLat': 120.0,
          'maxLon': 10.0,
        }),
        throwsFormatException,
      );
    });
  });

  group('OfflineMapPackageManifest Integrity Tests', () {
    final validBbox = const GeoBoundingBox(
      minLat: -3.5,
      minLon: -60.5,
      maxLat: -2.8,
      maxLon: -59.8,
    );
    const validSha256 =
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

    test('Valid manifest instantiation and serialization', () {
      final manifest = OfflineMapPackageManifest(
        id: 'manaus-am-br',
        regionName: 'Manaus e Região',
        downloadUrl: Uri.parse('https://example.com/maps/manaus-v1.pmtiles'),
        sizeBytes: 10485760,
        sha256: validSha256,
        bbox: validBbox,
        minZoom: 6,
        maxZoom: 16,
        generatedAt: DateTime.utc(2026, 11, 1),
        version: '1.0.0',
        license: 'ODbL-1.0',
        attribution: '© OpenStreetMap contributors',
        format: OfflineMapFormat.pmtiles,
      );

      expect(manifest.id, equals('manaus-am-br'));
      expect(manifest.format, equals(OfflineMapFormat.pmtiles));

      final json = manifest.toJson();
      final restored = OfflineMapPackageManifest.fromJson(json);
      expect(restored.id, equals(manifest.id));
      expect(restored.sizeBytes, equals(manifest.sizeBytes));
      expect(restored.sha256, equals(validSha256));
    });

    test('Rejects insecure HTTP URLs or mutable branches (@master/@main)', () {
      expect(
        () => OfflineMapPackageManifest(
          id: 'test-insecure',
          regionName: 'Test',
          downloadUrl: Uri.parse('http://example.com/insecure.pmtiles'),
          sizeBytes: 1000,
          sha256: validSha256,
          bbox: validBbox,
          minZoom: 6,
          maxZoom: 16,
          generatedAt: DateTime.utc(2026, 11, 1),
          version: '1.0.0',
          license: 'ODbL-1.0',
          attribution: '© OSM',
          format: OfflineMapFormat.pmtiles,
        ),
        throwsFormatException,
      );

      expect(
        () => OfflineMapPackageManifest(
          id: 'test-mutable',
          regionName: 'Test',
          downloadUrl: Uri.parse(
            'https://raw.githubusercontent.com/user/repo@master/map.pmtiles',
          ),
          sizeBytes: 1000,
          sha256: validSha256,
          bbox: validBbox,
          minZoom: 6,
          maxZoom: 16,
          generatedAt: DateTime.utc(2026, 11, 1),
          version: '1.0.0',
          license: 'ODbL-1.0',
          attribution: '© OSM',
          format: OfflineMapFormat.pmtiles,
        ),
        throwsFormatException,
      );
    });

    test('Verifies bytes integrity against SHA-256', () {
      // SHA-256 de vazio = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
      final manifest = OfflineMapPackageManifest(
        id: 'empty-package',
        regionName: 'Empty',
        downloadUrl: Uri.parse('https://example.com/empty.pmtiles'),
        sizeBytes: 0 + 1, // força erro se bytes não baterem com sizeBytes
        sha256: validSha256,
        bbox: validBbox,
        minZoom: 0,
        maxZoom: 14,
        generatedAt: DateTime.utc(2026, 11, 1),
        version: '1.0.0',
        license: 'ODbL-1.0',
        attribution: '© OSM',
        format: OfflineMapFormat.pmtiles,
      );

      expect(manifest.verifyBytesIntegrity(Uint8List(0)), isFalse);
    });
  });

  group('MaplibreNativeAdapter Contract Tests', () {
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

    test('Capabilities reflect genuine vector rendering and honest routing', () {
      expect(adapter.engineName, equals('MapLibre Native'));
      final caps = adapter.capabilities;
      expect(caps.vectorRendering, isTrue);
      expect(caps.supportsRotation, isTrue);
      expect(caps.supportsTilt, isTrue);
      expect(caps.supportsOfflinePackages, isTrue);
      expect(caps.supportsOfflineContactsOverlay, isTrue);
      // Honesto: sem Valhalla ou GraphHopper nativo, roteamento offline é false
      expect(caps.supportsOfflineRouting, isFalse);
    });

    test('Throws StateError if moveCamera is called before initialize', () {
      expect(
        () => adapter.moveCamera(
          const MapViewportState(latitude: -23.5, longitude: -46.6, zoom: 12),
        ),
        throwsStateError,
      );
    });

    test('Initializes tile server and tracks camera movements', () async {
      await adapter.initialize();
      expect(adapter.isInitialized, isTrue);
      expect(tileServer.isRunning, isTrue);

      const target = MapViewportState(
        latitude: -3.1,
        longitude: -60.0,
        zoom: 13.5,
        bearingDegrees: 45.0,
        tiltDegrees: 30.0,
      );
      await adapter.moveCamera(target);

      expect(adapter.currentViewport.latitude, equals(-3.1));
      expect(adapter.currentViewport.longitude, equals(-60.0));
      expect(adapter.currentViewport.zoom, equals(13.5));
      expect(adapter.currentViewport.bearingDegrees, equals(45.0));
      expect(adapter.currentViewport.tiltDegrees, equals(30.0));
    });

    test('Generates local Style JSON specification pointing to loopback server', () async {
      await adapter.initialize();

      final style = adapter.generateStyleSpecification();
      expect(style['version'], equals(8));
      expect(style['sources'], isA<Map>());
      final source =
          (style['sources'] as Map)['offline-source'] as Map<String, dynamic>;
      expect(source['type'], equals('vector'));
      final tiles = source['tiles'] as List;
      expect(
        tiles.first,
        contains('http://127.0.0.1:${tileServer.port}/tiles/mbtiles'),
      );

      final jsonStr = adapter.generateStyleJsonString();
      expect(jsonStr, contains('Field Assistant Local Vector Style'));

      final pmtilesStyle = adapter.generateStyleSpecification(
        packageId: 'br_am_solimoes',
        packageFormat: OfflineMapFormat.pmtiles,
      );
      final pmtilesSource =
          (pmtilesStyle['sources'] as Map)['offline-source']
              as Map<String, dynamic>;
      expect(
        (pmtilesSource['tiles'] as List).first,
        equals(
          'http://127.0.0.1:${tileServer.port}/pmtiles/br_am_solimoes/{z}/{x}/{y}.pbf',
        ),
      );

      final mbtilesStyle = adapter.generateStyleSpecification(
        packageId: 'br_am_solimoes',
        packageFormat: OfflineMapFormat.mbtiles,
      );
      final mbtilesSource =
          (mbtilesStyle['sources'] as Map)['offline-source']
              as Map<String, dynamic>;
      expect(
        (mbtilesSource['tiles'] as List).first,
        equals(
          'http://127.0.0.1:${tileServer.port}/mbtiles/br_am_solimoes/{z}/{x}/{y}.pbf',
        ),
      );
    });
  });

  group('RasterFallbackAdapter Contract Tests', () {
    late RasterFallbackAdapter adapter;

    setUp(() {
      adapter = RasterFallbackAdapter();
    });

    tearDown(() {
      adapter.dispose();
    });

    test('Capabilities reflect raster rendering limits', () {
      expect(adapter.engineName, contains('Raster Fallback'));
      final caps = adapter.capabilities;
      expect(caps.vectorRendering, isFalse);
      expect(caps.supportsRotation, isFalse);
      expect(caps.supportsTilt, isFalse);
      expect(caps.supportsOfflinePackages, isTrue);
      expect(caps.supportsOfflineContactsOverlay, isTrue);
      expect(caps.supportsOfflineRouting, isFalse);
    });

    test('Tracks camera position and initialization lifecycle', () async {
      expect(adapter.isInitialized, isFalse);
      await adapter.initialize();
      expect(adapter.isInitialized, isTrue);

      const target = MapViewportState(
        latitude: -22.9,
        longitude: -43.2,
        zoom: 11,
      );
      await adapter.moveCamera(target);
      expect(adapter.currentViewport.latitude, equals(-22.9));

      adapter.dispose();
      expect(adapter.isInitialized, isFalse);
    });
  });
}
