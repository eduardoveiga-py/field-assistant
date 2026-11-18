import 'dart:async';

import '../../core/app_logger.dart';
import '../map_engine_adapter.dart';
import '../mbtiles/mbtiles_backend.dart';

/// Adaptador cartográfico de contingência / compatibilidade baseado em Raster
/// (OpenStreetMap online e pacotes locais raster MBTiles) (FA-MAP-01).
/// Utilizado quando aceleração de hardware OpenGL/Metal para MapLibre Native
/// não estiver disponível na plataforma (Web, emuladores sem GPU).
class RasterFallbackAdapter implements MapEngineAdapter {
  final MBTilesBackend? mbtilesBackend;

  bool _isInitialized = false;
  MapViewportState _viewport = const MapViewportState(
    latitude: 0.0,
    longitude: 0.0,
    zoom: 2.0,
    bearingDegrees: 0.0,
    tiltDegrees: 0.0,
  );
  List<OfflineMapPackageManifest> _offlinePackages = [];
  List<Map<String, dynamic>> _contacts = [];

  RasterFallbackAdapter({this.mbtilesBackend});

  @override
  String get engineName => 'Raster Fallback (OpenStreetMap / MBTiles)';

  @override
  MapEngineCapabilities get capabilities => const MapEngineCapabilities(
    vectorRendering: false,
    supportsRotation: false,
    supportsTilt: false,
    supportsOfflinePackages: true,
    supportsOfflineContactsOverlay: true,
    supportsOfflineRouting: false,
  );

  bool get isInitialized => _isInitialized;
  MapViewportState get currentViewport => _viewport;
  List<OfflineMapPackageManifest> get offlinePackages =>
      List.unmodifiable(_offlinePackages);
  List<Map<String, dynamic>> get contacts => List.unmodifiable(_contacts);

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (mbtilesBackend != null) {
      await mbtilesBackend!.init();
      AppLogger.info('RasterFallbackAdapter: MBTiles backend inicializado.');
    }

    _isInitialized = true;
    AppLogger.info('RasterFallbackAdapter: Inicializado com sucesso.');
  }

  @override
  Future<void> moveCamera(MapViewportState viewport) async {
    if (!_isInitialized) {
      throw StateError(
        'RasterFallbackAdapter deve ser inicializado antes de mover a câmera.',
      );
    }
    // No motor raster, zoom é truncado para degraus inteiros e rotação/tilt são nulos
    _viewport = MapViewportState(
      latitude: viewport.latitude.clamp(-85.0511, 85.0511),
      longitude: viewport.longitude.clamp(-180.0, 180.0),
      zoom: viewport.zoom.roundToDouble().clamp(0.0, 19.0),
      bearingDegrees: 0.0,
      tiltDegrees: 0.0,
    );
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
      'RasterFallbackAdapter: ${_offlinePackages.length} pacote(s) offline configurado(s).',
    );
  }

  Future<void> updateContactsOverlay(
    List<Map<String, dynamic>> contacts,
  ) async {
    _contacts = List.from(contacts);
  }

  @override
  void dispose() {
    _isInitialized = false;
    _contacts.clear();
    AppLogger.info('RasterFallbackAdapter descartado.');
  }
}
