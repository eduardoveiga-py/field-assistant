import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/app_logger.dart';
import '../../../territory/map_engine/maplibre_native_adapter.dart';
import '../../../territory/map_engine_adapter.dart';

/// Renderizador vetorial nativo MapLibre GL (Nível 2 — FA-MAP-01/02).
/// Conecta o [MaplibreNativeAdapter], o [OfflineTileServer] loopback e os ativos
/// offline (fontes SDF `.pbf` e sprites RGBA) ao widget nativo [MapLibreMap]
/// em iOS (Metal), Android (OpenGL/Vulkan) e Web (WebGL).
///
/// Em desktop (Windows/macOS/Linux) ou ambientes sem suporte de plataforma,
/// [isSupportedOnCurrentPlatform] retorna `false` para manter fallback seguro
/// ao [RasterFallbackAdapter].
class MapLibreVectorMapView extends StatefulWidget {
  final MaplibreNativeAdapter adapter;
  final double initialLat;
  final double initialLng;
  final double initialZoom;
  final double initialBearing;
  final double initialTilt;
  final bool isDarkMode;
  final String? packageId;
  final OfflineMapFormat packageFormat;
  final List<Map<String, dynamic>> contacts;
  final List<Map<String, dynamic>> landmarks;
  final List<Map<String, dynamic>> sectors;
  final ValueChanged<MapViewportState>? onCameraChanged;
  final ValueChanged<String>? onContactTapped;
  final ValueChanged<String>? onLandmarkTapped;
  final VoidCallback? onSwitchToRaster;

  const MapLibreVectorMapView({
    super.key,
    required this.adapter,
    required this.initialLat,
    required this.initialLng,
    required this.initialZoom,
    this.initialBearing = 0.0,
    this.initialTilt = 0.0,
    this.isDarkMode = false,
    this.packageId,
    this.packageFormat = OfflineMapFormat.pmtiles,
    this.contacts = const [],
    this.landmarks = const [],
    this.sectors = const [],
    this.onCameraChanged,
    this.onContactTapped,
    this.onLandmarkTapped,
    this.onSwitchToRaster,
  });

  /// Indica se o plugin `maplibre_gl` possui implementação nativa na plataforma atual.
  static bool get isSupportedOnCurrentPlatform {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  @override
  State<MapLibreVectorMapView> createState() => _MapLibreVectorMapViewState();
}

class _MapLibreVectorMapViewState extends State<MapLibreVectorMapView> {
  MapLibreMapController? _controller;
  String? _styleJson;
  bool _styleLoaded = false;
  Object? _initError;
  int _styleGeneration = 0;

  @override
  void initState() {
    super.initState();
    if (!_hasNoSource) unawaited(_prepareStyle());
  }

  bool get _hasNoSource => kIsWeb || widget.packageId == null;

  @override
  void didUpdateWidget(covariant MapLibreVectorMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final styleChanged =
        oldWidget.isDarkMode != widget.isDarkMode ||
        oldWidget.packageId != widget.packageId ||
        oldWidget.packageFormat != widget.packageFormat ||
        oldWidget.adapter != widget.adapter;
    if (styleChanged) {
      _styleLoaded = false;
      _styleGeneration++;
      if (!_hasNoSource) unawaited(_prepareStyle());
      return;
    }

    if (oldWidget.contacts != widget.contacts ||
        oldWidget.landmarks != widget.landmarks ||
        oldWidget.sectors != widget.sectors) {
      unawaited(_syncGeoJsonOverlays());
    }
  }

  Future<void> _prepareStyle() async {
    final generation = ++_styleGeneration;
    final adapter = widget.adapter;
    bool current() => mounted && generation == _styleGeneration && identical(adapter, widget.adapter);
    try {
      if (!adapter.isInitialized) {
        await adapter.initialize();
      }
      if (!current()) return;
      await adapter.updateContactsOverlay(widget.contacts);
      if (!current()) return;
      await adapter.updateLandmarksOverlay(widget.landmarks);
      if (!current()) return;
      await adapter.updateSectorsOverlay(widget.sectors);
      if (!current()) return;

      final styleJson = adapter.generateStyleJsonString(
        packageId: widget.packageId,
        packageFormat: widget.packageFormat,
        isDarkMode: widget.isDarkMode,
      );
      if (!current()) return;
      setState(() {
        _styleJson = styleJson;
        _initError = null;
      });
    } catch (e, st) {
      AppLogger.warning(
        'MapLibreVectorMapView: falha ao preparar estilo offline',
        e,
        st,
      );
      if (!current()) return;
      setState(() => _initError = e);
    }
  }

  Future<void> _syncGeoJsonOverlays() async {
    await widget.adapter.updateContactsOverlay(widget.contacts);
    await widget.adapter.updateLandmarksOverlay(widget.landmarks);
    await widget.adapter.updateSectorsOverlay(widget.sectors);

    final controller = _controller;
    if (!_styleLoaded || controller == null) return;

    try {
      if (widget.adapter.contactsGeoJson != null) {
        await controller.setGeoJsonSource(
          'contacts-source',
          widget.adapter.contactsGeoJson!,
        );
      }
      if (widget.adapter.landmarksGeoJson != null) {
        await controller.setGeoJsonSource(
          'landmarks-source',
          widget.adapter.landmarksGeoJson!,
        );
      }
      if (widget.adapter.sectorsGeoJson != null) {
        await controller.setGeoJsonSource(
          'sectors-source',
          widget.adapter.sectorsGeoJson!,
        );
      }
    } catch (e, st) {
      AppLogger.debug(
        'MapLibreVectorMapView: falha não-bloqueante ao sincronizar GeoJSON: $e',
        st,
      );
    }
  }

  void _handleFeatureTapped(
    math.Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (layerId == 'contacts-layer') {
      widget.onContactTapped?.call(id);
    } else if (layerId == 'landmarks-layer') {
      widget.onLandmarkTapped?.call(id);
    }
  }

  void _handleCameraIdle() {
    final pos = _controller?.cameraPosition;
    if (pos == null) return;
    final viewport = MapViewportState(
      latitude: pos.target.latitude,
      longitude: pos.target.longitude,
      zoom: pos.zoom,
      bearingDegrees: pos.bearing,
      tiltDegrees: pos.tilt,
    );
    if (widget.adapter.isInitialized) {
      unawaited(widget.adapter.moveCamera(viewport));
    }
    widget.onCameraChanged?.call(viewport);
  }

  @override
  void dispose() {
    _controller?.onFeatureTapped.remove(_handleFeatureTapped);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasNoSource) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                kIsWeb
                    ? 'Mapa vetorial offline ainda não está disponível no navegador. Use o mapa raster enquanto o suporte é concluído.'
                    : 'Nenhum pacote vetorial offline está disponível. Use o mapa raster ou instale um pacote compatível.',
                textAlign: TextAlign.center,
              ),
              if (widget.onSwitchToRaster != null) ...[
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: widget.onSwitchToRaster,
                  child: const Text('Voltar ao mapa raster'),
                ),
              ],
            ],
          ),
        ),
      );
    }
    if (_initError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Não foi possível inicializar o motor vetorial MapLibre.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final styleJson = _styleJson;
    if (styleJson == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Semantics(
      label: 'Mapa vetorial offline MapLibre',
      container: true,
      child: MapLibreMap(
        key: ValueKey<String>(
          'maplibre_${widget.isDarkMode}_${widget.packageId ?? 'default'}',
        ),
        styleString: styleJson,
        initialCameraPosition: CameraPosition(
          target: LatLng(widget.initialLat, widget.initialLng),
          zoom: widget.initialZoom,
          bearing: widget.initialBearing,
          tilt: widget.initialTilt,
        ),
        rotateGesturesEnabled: true,
        tiltGesturesEnabled: true,
        trackCameraPosition: true,
        compassEnabled: true,
        onMapCreated: (controller) {
          _controller = controller;
          controller.onFeatureTapped.add(_handleFeatureTapped);
        },
        onStyleLoadedCallback: () {
          _styleLoaded = true;
          unawaited(_syncGeoJsonOverlays());
        },
        onCameraIdle: _handleCameraIdle,
      ),
    );
  }
}
