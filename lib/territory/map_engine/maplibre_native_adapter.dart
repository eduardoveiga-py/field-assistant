import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../../core/app_logger.dart';
import '../map_engine_adapter.dart';
import 'map_asset_manager.dart';
import 'offline_tile_server.dart';

/// Implementação do adaptador do motor cartográfico para MapLibre Native (FA-MAP-01/02).
/// Suporta renderização vetorial a 60-120 FPS via Metal/OpenGL, rotação contínua 360° com
/// contra-rotação automática de rótulos/pinos, controle fracionário de zoom, inclinação 3D
/// (pitch 0° a 60°), camadas GeoJSON para contatos, marcos e setores, e orquestração do
/// servidor local de tiles (HTTP 206 Range) para servir pacotes PMTiles/MBTiles offline.
class MaplibreNativeAdapter implements MapEngineAdapter {
  final OfflineTileServer? tileServer;
  final bool ownsTileServer;
  final MapAssetManager? assetManager;

  bool _isInitialized = false;
  MapViewportState _viewport = const MapViewportState(
    latitude: 0.0,
    longitude: 0.0,
    zoom: 2.0,
    bearingDegrees: 0.0,
    tiltDegrees: 0.0,
  );
  List<OfflineMapPackageManifest> _offlinePackages = [];

  // Armazenamento em memória das coleções GeoJSON ativas
  Map<String, dynamic>? _contactsGeoJson;
  Map<String, dynamic>? _landmarksGeoJson;
  Map<String, dynamic>? _sectorsGeoJson;
  Directory? _assetsDir;

  MaplibreNativeAdapter({
    this.tileServer,
    this.ownsTileServer = false,
    this.assetManager,
  });

  @override
  String get engineName => 'MapLibre Native';

  @override
  MapEngineCapabilities get capabilities => const MapEngineCapabilities(
    vectorRendering: true,
    supportsRotation: true,
    supportsTilt: true,
    supportsOfflinePackages: true,
    supportsOfflineContactsOverlay: true,
    supportsOfflineRouting: false, // Honesto: roteamento offline requer motor dedicado (Valhalla/GraphHopper)
  );

  bool get isInitialized => _isInitialized;
  MapViewportState get currentViewport => _viewport;
  List<OfflineMapPackageManifest> get offlinePackages =>
      List.unmodifiable(_offlinePackages);

  double get currentBearing => _viewport.bearingDegrees;
  double get currentTilt => _viewport.tiltDegrees;
  double get currentZoom => _viewport.zoom;

  Map<String, dynamic>? get contactsGeoJson => _contactsGeoJson;
  Map<String, dynamic>? get landmarksGeoJson => _landmarksGeoJson;
  Map<String, dynamic>? get sectorsGeoJson => _sectorsGeoJson;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (tileServer != null && !tileServer!.isRunning) {
      await tileServer!.start();
      AppLogger.info(
        'MaplibreNativeAdapter: Servidor de tiles offline inicializado na porta ${tileServer!.port}',
      );
    }

    if (assetManager != null) {
      try {
        await assetManager!.copyAssetsToDisk();
        _assetsDir = await assetManager!.getAssetsDirectory();
        if (tileServer != null && _assetsDir != null) {
          tileServer!.setAssetsDirectory(_assetsDir!);
        }
        AppLogger.info(
          'MaplibreNativeAdapter: Ativos offline garantidos no disco.',
        );
      } catch (e, st) {
        AppLogger.warning(
          'MaplibreNativeAdapter: Falha não-bloqueante ao sincronizar ativos',
          e,
          st,
        );
      }
    }

    _isInitialized = true;
    AppLogger.info('MaplibreNativeAdapter: Inicializado com sucesso.');
  }

  @override
  Future<void> moveCamera(MapViewportState viewport) async {
    if (!_isInitialized) {
      throw StateError(
        'MaplibreNativeAdapter deve ser inicializado antes de mover a câmera.',
      );
    }
    // Clamping seguro de parâmetros
    final clampedTilt = viewport.tiltDegrees.clamp(0.0, 60.0);
    final normalizedBearing = (viewport.bearingDegrees % 360.0 + 360.0) % 360.0;
    _viewport = MapViewportState(
      latitude: viewport.latitude.clamp(-85.0511, 85.0511),
      longitude: viewport.longitude.clamp(-180.0, 180.0),
      zoom: viewport.zoom.clamp(0.0, 22.0),
      bearingDegrees: normalizedBearing,
      tiltDegrees: clampedTilt,
    );
  }

  /// Ajusta o bearing (rotação em graus 0°–360°).
  Future<void> setBearing(double bearingDegrees) async {
    await moveCamera(
      MapViewportState(
        latitude: _viewport.latitude,
        longitude: _viewport.longitude,
        zoom: _viewport.zoom,
        bearingDegrees: bearingDegrees,
        tiltDegrees: _viewport.tiltDegrees,
      ),
    );
  }

  /// Ajusta a inclinação 3D (pitch) entre 0° (vista superior 2D) e 60° (perspectiva 3D).
  Future<void> setTilt(double tiltDegrees) async {
    await moveCamera(
      MapViewportState(
        latitude: _viewport.latitude,
        longitude: _viewport.longitude,
        zoom: _viewport.zoom,
        bearingDegrees: _viewport.bearingDegrees,
        tiltDegrees: tiltDegrees,
      ),
    );
  }

  /// Ajusta o nível de zoom de forma contínua e fracionária (ex.: 14.35).
  Future<void> setZoom(double zoom) async {
    await moveCamera(
      MapViewportState(
        latitude: _viewport.latitude,
        longitude: _viewport.longitude,
        zoom: zoom,
        bearingDegrees: _viewport.bearingDegrees,
        tiltDegrees: _viewport.tiltDegrees,
      ),
    );
  }

  /// Calcula o ângulo de contra-rotação (em graus ou radianos) para manter pinos
  /// e textos perfeitamente eretos e legíveis na UI independente da rotação do mapa.
  static double calculateCounterRotationDegrees(double mapBearing) {
    return (-mapBearing % 360.0 + 360.0) % 360.0;
  }

  static double calculateCounterRotationRadians(double mapBearingDegrees) {
    final deg = calculateCounterRotationDegrees(mapBearingDegrees);
    return deg * (math.pi / 180.0);
  }

  @override
  Future<void> setOfflinePackages(
    List<OfflineMapPackageManifest> packages,
  ) async {
    for (final pkg in packages) {
      pkg.validate();
    }
    _offlinePackages = List.from(packages);

    AppLogger.info(
      'MaplibreNativeAdapter: ${_offlinePackages.length} pacote(s) offline configurado(s).',
    );
  }

  /// Constrói FeatureCollection GeoJSON para contatos do território.
  Map<String, dynamic> buildContactsGeoJson(
    List<Map<String, dynamic>> contacts,
  ) {
    final features = <Map<String, dynamic>>[];
    for (final contact in contacts) {
      final lat = (contact['latitude'] as num?)?.toDouble();
      final lon = (contact['longitude'] as num?)?.toDouble();
      if (lat != null && lon != null) {
        features.add({
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [lon, lat],
          },
          'properties': {
            'id': contact['id']?.toString() ?? '',
            'name': contact['name']?.toString() ?? '',
            'status': contact['status']?.toString() ?? 'normal',
            'notes': contact['notes']?.toString() ?? '',
          },
        });
      }
    }
    return {'type': 'FeatureCollection', 'features': features};
  }

  /// Atualiza a camada GeoJSON de contatos.
  Future<void> updateContactsOverlay(
    List<Map<String, dynamic>> contacts,
  ) async {
    _contactsGeoJson = buildContactsGeoJson(contacts);
    AppLogger.debug(
      'MaplibreNativeAdapter: Camada GeoJSON de contatos atualizada (${contacts.length} pontos).',
    );
  }

  /// Constrói FeatureCollection GeoJSON para marcos de referência territoriais.
  Map<String, dynamic> buildLandmarksGeoJson(
    List<Map<String, dynamic>> landmarks,
  ) {
    final features = <Map<String, dynamic>>[];
    for (final lm in landmarks) {
      final lat = (lm['latitude'] as num?)?.toDouble();
      final lon = (lm['longitude'] as num?)?.toDouble();
      if (lat != null && lon != null) {
        features.add({
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [lon, lat],
          },
          'properties': {
            'id': lm['id']?.toString() ?? '',
            'title': lm['title']?.toString() ?? '',
            'category': lm['category']?.toString() ?? 'poi',
          },
        });
      }
    }
    return {'type': 'FeatureCollection', 'features': features};
  }

  /// Atualiza a camada GeoJSON de marcos.
  Future<void> updateLandmarksOverlay(
    List<Map<String, dynamic>> landmarks,
  ) async {
    _landmarksGeoJson = buildLandmarksGeoJson(landmarks);
  }

  /// Constrói FeatureCollection GeoJSON para polígonos de setores territoriais.
  Map<String, dynamic> buildSectorsGeoJson(List<Map<String, dynamic>> sectors) {
    final features = <Map<String, dynamic>>[];
    for (final sector in sectors) {
      final polygonCoords = sector['coordinates'] as List?;
      if (polygonCoords != null && polygonCoords.isNotEmpty) {
        features.add({
          'type': 'Feature',
          'geometry': {'type': 'Polygon', 'coordinates': polygonCoords},
          'properties': {
            'id': sector['id']?.toString() ?? '',
            'code': sector['code']?.toString() ?? '',
            'name': sector['name']?.toString() ?? '',
            'color': sector['color']?.toString() ?? '#3388ff',
          },
        });
      }
    }
    return {'type': 'FeatureCollection', 'features': features};
  }

  /// Atualiza a camada GeoJSON de setores poligonais.
  Future<void> updateSectorsOverlay(List<Map<String, dynamic>> sectors) async {
    _sectorsGeoJson = buildSectorsGeoJson(sectors);
  }

  /// Gera a especificação de estilo MapLibre (Style JSON v8) apontando
  /// para o servidor HTTP local ou para pacotes locais, com auto-counter-rotation
  /// em camadas de símbolos (icon-rotation-alignment: viewport).
  Map<String, dynamic> generateStyleSpecification({
    String? packageId,
    OfflineMapFormat packageFormat = OfflineMapFormat.pmtiles,
    bool isDarkMode = false,
  }) {
    final serverBase = tileServer?.baseUrl;
    final tileUrl = serverBase != null
        ? (packageId != null
              ? (packageFormat == OfflineMapFormat.mbtiles
                    ? '$serverBase/mbtiles/$packageId/{z}/{x}/{y}.pbf'
                    : '$serverBase/pmtiles/$packageId/{z}/{x}/{y}.pbf')
              : '$serverBase/tiles/mbtiles/{z}/{x}/{y}')
        : null;

    final sources = <String, dynamic>{};
    final layers = <Map<String, dynamic>>[];

    if (tileUrl != null) {
      sources['offline-source'] = {
        'type': 'vector',
        'tiles': [tileUrl],
        'minzoom': 0,
        'maxzoom': 18,
      };

      layers.add({
        'id': 'background',
        'type': 'background',
        'paint': {'background-color': isDarkMode ? '#1a1a1a' : '#f8f4f0'},
      });
      layers.add({
        'id': 'water',
        'type': 'fill',
        'source': 'offline-source',
        'source-layer': 'water',
        'paint': {'fill-color': isDarkMode ? '#142d4c' : '#a0c8f0'},
      });
      layers.add({
        'id': 'landuse-residential',
        'type': 'fill',
        'source': 'offline-source',
        'source-layer': 'landuse',
        'filter': ['==', 'class', 'residential'],
        'paint': {
          'fill-color': isDarkMode ? '#242424' : '#e8e6e0',
          'fill-opacity': 0.6,
        },
      });
      layers.add({
        'id': 'building',
        'type': 'fill',
        'source': 'offline-source',
        'source-layer': 'building',
        'paint': {
          'fill-color': isDarkMode ? '#2b2b2b' : '#dcd8d0',
          'fill-outline-color': isDarkMode ? '#383838' : '#c8c4bc',
        },
      });
      layers.add({
        'id': 'transportation',
        'type': 'line',
        'source': 'offline-source',
        'source-layer': 'transportation',
        'layout': {'line-cap': 'round', 'line-join': 'round'},
        'paint': {
          'line-color': isDarkMode ? '#3a3a3a' : '#ffffff',
          'line-width': {
            'base': 1.2,
            'stops': [
              [4, 0.5],
              [8, 1.0],
              [12, 3.0],
              [16, 8.0],
            ],
          },
        },
      });
      layers.add({
        'id': 'place-city',
        'type': 'symbol',
        'source': 'offline-source',
        'source-layer': 'place',
        'filter': ['==', 'class', 'city'],
        'layout': {
          'text-field': '{name}',
          'text-font': ['Noto Sans Regular'],
          'text-size': 14,
          'text-max-width': 8,
          'text-rotation-alignment': 'viewport',
        },
        'paint': {
          'text-color': isDarkMode ? '#e0e0e0' : '#333333',
          'text-halo-color': isDarkMode ? '#1a1a1a' : '#ffffff',
          'text-halo-width': 1.5,
        },
      });
    }

    // Fontes GeoJSON locais para overlays
    if (_sectorsGeoJson != null) {
      sources['sectors-source'] = {'type': 'geojson', 'data': _sectorsGeoJson};
      layers.add({
        'id': 'sectors-fill',
        'type': 'fill',
        'source': 'sectors-source',
        'paint': {
          'fill-color': ['get', 'color'],
          'fill-opacity': 0.25,
        },
      });
      layers.add({
        'id': 'sectors-line',
        'type': 'line',
        'source': 'sectors-source',
        'paint': {
          'line-color': ['get', 'color'],
          'line-width': 2.0,
        },
      });
    }

    if (_landmarksGeoJson != null) {
      sources['landmarks-source'] = {
        'type': 'geojson',
        'data': _landmarksGeoJson,
      };
      layers.add({
        'id': 'landmarks-layer',
        'type': 'symbol',
        'source': 'landmarks-source',
        'layout': {
          'icon-image': 'landmark-15',
          'icon-size': 1.0,
          'icon-rotation-alignment': 'viewport',
          'text-field': '{title}',
          'text-font': ['Noto Sans Regular'],
          'text-size': 11,
          'text-offset': [0, 1.2],
          'text-anchor': 'top',
          'text-rotation-alignment': 'viewport',
        },
        'paint': {
          'text-color': isDarkMode ? '#93c5fd' : '#1d4ed8',
          'text-halo-color': isDarkMode ? '#000000' : '#ffffff',
          'text-halo-width': 1.5,
        },
      });
    }

    if (_contactsGeoJson != null) {
      sources['contacts-source'] = {
        'type': 'geojson',
        'data': _contactsGeoJson,
      };
      // Camada de símbolos com auto-counter-rotation para pinos e rótulos
      layers.add({
        'id': 'contacts-layer',
        'type': 'symbol',
        'source': 'contacts-source',
        'layout': {
          'icon-image': 'marker-15',
          'icon-size': 1.0,
          'icon-rotation-alignment': 'viewport', // Pino sempre ereto na tela
          'text-field': '{name}',
          'text-font': ['Noto Sans Regular'],
          'text-size': 12,
          'text-offset': [0, 1.2],
          'text-anchor': 'top',
          'text-rotation-alignment':
              'viewport', // Nome de rua/contato nunca de cabeça para baixo
        },
        'paint': {
          'text-color': isDarkMode ? '#ffffff' : '#222222',
          'text-halo-color': isDarkMode ? '#000000' : '#ffffff',
          'text-halo-width': 1.5,
        },
      });
    }

    final String? spriteUrl;
    final String? glyphsUrl;
    if (serverBase != null) {
      spriteUrl = '$serverBase/assets/sprites/sprite';
      glyphsUrl = '$serverBase/assets/fonts/{fontstack}/{range}.pbf';
    } else if (_assetsDir != null) {
      final assetsUri = _assetsDir!.uri.toString().replaceAll(
        RegExp(r'/$'),
        '',
      );
      spriteUrl = '$assetsUri/sprites/sprite';
      glyphsUrl = '$assetsUri/fonts/{fontstack}/{range}.pbf';
    } else {
      spriteUrl = null;
      glyphsUrl = null;
    }

    return {
      'version': 8,
      'name': 'Field Assistant Local Vector Style',
      if (spriteUrl != null) 'sprite': spriteUrl,
      if (glyphsUrl != null) 'glyphs': glyphsUrl,
      'sources': sources,
      'layers': layers,
    };
  }

  /// Retorna o Style JSON serializado em UTF-8.
  String generateStyleJsonString({
    String? packageId,
    OfflineMapFormat packageFormat = OfflineMapFormat.pmtiles,
    bool isDarkMode = false,
  }) {
    return jsonEncode(
      generateStyleSpecification(
        packageId: packageId,
        packageFormat: packageFormat,
        isDarkMode: isDarkMode,
      ),
    );
  }

  @override
  void dispose() {
    _isInitialized = false;
    _contactsGeoJson = null;
    _landmarksGeoJson = null;
    _sectorsGeoJson = null;
    if (ownsTileServer && tileServer != null) {
      unawaited(tileServer!.stop());
    }
    AppLogger.info('MaplibreNativeAdapter descartado.');
  }
}
