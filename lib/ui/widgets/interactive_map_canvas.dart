import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../database/app_database.dart';
import '../../territory/landmark_manager.dart';
import '../../territory/tile_cache/tile_cache_service.dart';

/// Canvas interativo de mapas com projeção Web Mercator, suporte a tiles OSM locais/remotos,
/// pinos estilizados de contatos e marcos e zoom com âncora focal exata (zero drift).
class InteractiveMapCanvas extends StatefulWidget {
  final List<PersonEntry> contacts;
  final List<TerritoryLandmark> landmarks;
  final String? highlightPersonId;
  final PersonEntry? selectedPerson;
  final TerritoryLandmark? selectedLandmark;
  final bool showLandmarks;
  final ValueChanged<PersonEntry> onPersonSelected;
  final ValueChanged<TerritoryLandmark> onLandmarkSelected;
  final ValueChanged<int>? onZoomChanged;
  final VoidCallback? onClearHighlight;

  const InteractiveMapCanvas({
    super.key,
    required this.contacts,
    required this.landmarks,
    this.highlightPersonId,
    this.selectedPerson,
    this.selectedLandmark,
    this.showLandmarks = true,
    required this.onPersonSelected,
    required this.onLandmarkSelected,
    this.onZoomChanged,
    this.onClearHighlight,
  });

  static double lon2pixelX(double lon, int z, double tileSize) =>
      (lon + 180.0) / 360.0 * (tileSize * (1 << z));

  static double lat2pixelY(double lat, int z, double tileSize) {
    final latRad = lat.clamp(-85.0511, 85.0511) * math.pi / 180.0;
    final sinLat = math.sin(latRad).clamp(-0.9999, 0.9999);
    return (0.5 - math.log((1.0 + sinLat) / (1.0 - sinLat)) / (4.0 * math.pi)) *
        (tileSize * (1 << z));
  }

  static double pixelX2lon(double px, int z, double tileSize) =>
      (px / (tileSize * (1 << z))) * 360.0 - 180.0;

  static double pixelY2lat(double py, int z, double tileSize) {
    final n = math.pi - (2.0 * math.pi * py) / (tileSize * (1 << z));
    return 180.0 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
  }

  static int lon2tileX(double lon, int z) =>
      ((lon + 180.0) / 360.0 * (1 << z)).floor();

  static int lat2tileY(double lat, int z) {
    final latRad = lat.clamp(-85.0511, 85.0511) * math.pi / 180.0;
    return ((1.0 -
                math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
            2.0 *
            (1 << z))
        .floor();
  }

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'estudo':
        return const Color(0xFF7C3AED);
      case 'revisita':
        return AppTheme.accentTeal;
      case 'revisita_encerrada':
      case 'encerrado':
      case 'concluido':
        return const Color(0xFF94A3B8);
      case 'interessado':
      default:
        return const Color(0xFF2563EB);
    }
  }

  @override
  State<InteractiveMapCanvas> createState() => InteractiveMapCanvasState();
}

class InteractiveMapCanvasState extends State<InteractiveMapCanvas> {
  final TransformationController _transformationController =
      TransformationController();
  bool _hasCenteredInitialView = false;
  bool _hasCenteredHighlightPerson = false;
  int _zoom = 15;
  static const double _tileSize = 256.0;
  static const int _gridHalfSize = 5; // 11x11 blocos = 2816x2816 px

  double _originPx = 0.0;
  double _originPy = 0.0;
  DateTime? _lastZoomChangeTime;
  Offset? _lastPinchFocalPoint;

  int get zoom => _zoom;
  TransformationController get transformationController =>
      _transformationController;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  // --- Projeções Web Mercator ---

  static double lon2pixelX(double lon, int z, double tileSize) =>
      (lon + 180.0) / 360.0 * (tileSize * (1 << z));

  static double lat2pixelY(double lat, int z, double tileSize) {
    final latRad = lat.clamp(-85.0511, 85.0511) * math.pi / 180.0;
    final sinLat = math.sin(latRad).clamp(-0.9999, 0.9999);
    return (0.5 - math.log((1.0 + sinLat) / (1.0 - sinLat)) / (4.0 * math.pi)) *
        (tileSize * (1 << z));
  }

  static double pixelX2lon(double px, int z, double tileSize) =>
      (px / (tileSize * (1 << z))) * 360.0 - 180.0;

  static double pixelY2lat(double py, int z, double tileSize) {
    final n = math.pi - (2.0 * math.pi * py) / (tileSize * (1 << z));
    return 180.0 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
  }

  static int lon2tileX(double lon, int z) =>
      ((lon + 180.0) / 360.0 * (1 << z)).floor();

  static int lat2tileY(double lat, int z) {
    final latRad = lat.clamp(-85.0511, 85.0511) * math.pi / 180.0;
    return ((1.0 -
                math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
            2.0 *
            (1 << z))
        .floor();
  }

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'estudo':
        return const Color(0xFF7C3AED);
      case 'revisita':
        return AppTheme.accentTeal;
      case 'revisita_encerrada':
      case 'encerrado':
      case 'concluido':
        return const Color(0xFF94A3B8);
      case 'interessado':
      default:
        return const Color(0xFF2563EB);
    }
  }

  /// Ajusta o zoom com âncora focal exata sob a coordenada de tela especificada
  void changeZoom(
    int targetZoom, {
    Offset? screenFocalPoint,
    required BoxConstraints constraints,
    required double centerLng,
    required double centerLat,
  }) {
    final newZoom = targetZoom.clamp(10, 18);
    if (newZoom == _zoom) return;

    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    final effectiveScale = currentScale > 0.01 ? currentScale : 1.0;
    final curDx = currentMatrix.storage[12];
    final curDy = currentMatrix.storage[13];

    final viewportW = constraints.maxWidth > 0 ? constraints.maxWidth : 400.0;
    final viewportH = constraints.maxHeight > 0 ? constraints.maxHeight : 600.0;

    final fx = screenFocalPoint?.dx ?? (viewportW / 2.0);
    final fy = screenFocalPoint?.dy ?? (viewportH / 2.0);

    // Mapeamento inverso: coordenada de tela para coordenada no canvas atual
    final canvasFocalX = (fx - curDx) / effectiveScale;
    final canvasFocalY = (fy - curDy) / effectiveScale;

    // Coordenada global no mundo a partir da origem do grid atual
    final worldPx = _originPx + canvasFocalX;
    final worldPy = _originPy + canvasFocalY;
    final focalLng = pixelX2lon(worldPx, _zoom, _tileSize);
    final focalLat = pixelY2lat(worldPy, _zoom, _tileSize);

    // Nova origem do grid em targetZoom
    final newCenterTileX = lon2tileX(centerLng, newZoom);
    final newCenterTileY = lat2tileY(centerLat, newZoom);
    final newMinTileX = newCenterTileX - _gridHalfSize;
    final newMinTileY = newCenterTileY - _gridHalfSize;
    final newOriginPx = newMinTileX * _tileSize;
    final newOriginPy = newMinTileY * _tileSize;

    // Nova posição do ponto focal no canvas a targetZoom
    final newWorldPx = lon2pixelX(focalLng, newZoom, _tileSize);
    final newWorldPy = lat2pixelY(focalLat, newZoom, _tileSize);
    final newCanvasX = newWorldPx - newOriginPx;
    final newCanvasY = newWorldPy - newOriginPy;

    // Para manter o ponto focal exatamente sob (fx, fy) com escala resetada para 1.0:
    final targetDx = fx - newCanvasX;
    final targetDy = fy - newCanvasY;

    final canvasWidth = (_gridHalfSize * 2 + 1) * _tileSize;
    final canvasHeight = (_gridHalfSize * 2 + 1) * _tileSize;
    const boundaryMargin = 250.0;

    final newDx = targetDx.clamp(
      viewportW - canvasWidth - boundaryMargin,
      boundaryMargin,
    );
    final newDy = targetDy.clamp(
      viewportH - canvasHeight - boundaryMargin,
      boundaryMargin,
    );

    TileCacheService.instance.cancelZoomExcept(newZoom);

    setState(() {
      _zoom = newZoom;
      _originPx = newOriginPx;
      _originPy = newOriginPy;
    });

    _transformationController.value =
        Matrix4.translationValues(newDx, newDy, 0.0);
    widget.onZoomChanged?.call(newZoom);
  }

  void recenterMap(
    double viewportW,
    double viewportH,
    double centerPx,
    double centerPy,
  ) {
    final dx = (viewportW / 2.0) - centerPx;
    final dy = (viewportH / 2.0) - centerPy;
    _transformationController.value = Matrix4.translationValues(dx, dy, 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final geoContacts = widget.contacts
        .where(
          (c) =>
              c.latitude != null &&
              c.longitude != null &&
              (c.latitude != 0.0 || c.longitude != 0.0) &&
              c.latitude!.abs() <= 90 &&
              c.longitude!.abs() <= 180,
        )
        .toList();

    final geoLandmarks = widget.showLandmarks
        ? widget.landmarks
            .where(
              (l) =>
                  l.latitude != null &&
                  l.longitude != null &&
                  (l.latitude != 0.0 || l.longitude != 0.0) &&
                  l.latitude!.abs() <= 90 &&
                  l.longitude!.abs() <= 180,
            )
            .toList()
        : <TerritoryLandmark>[];

    final allLats = [
      ...geoContacts.map((c) => c.latitude!),
      ...geoLandmarks.map((l) => l.latitude!),
    ]..sort();

    final allLngs = [
      ...geoContacts.map((c) => c.longitude!),
      ...geoLandmarks.map((l) => l.longitude!),
    ]..sort();

    PersonEntry? highlightPerson;
    if (widget.highlightPersonId != null) {
      for (final c in widget.contacts) {
        if (c.id == widget.highlightPersonId) {
          highlightPerson = c;
          break;
        }
      }
    }

    final hasHighlightCoords =
        highlightPerson != null &&
        highlightPerson.latitude != null &&
        highlightPerson.longitude != null &&
        (highlightPerson.latitude != 0.0 || highlightPerson.longitude != 0.0) &&
        highlightPerson.latitude!.abs() <= 90 &&
        highlightPerson.longitude!.abs() <= 180;

    double centerLat = -23.550520;
    double centerLng = -46.633308;
    if (hasHighlightCoords) {
      centerLat = highlightPerson.latitude!;
      centerLng = highlightPerson.longitude!;
    } else if (allLats.isNotEmpty && allLngs.isNotEmpty) {
      centerLat = allLats[allLats.length ~/ 2];
      centerLng = allLngs[allLngs.length ~/ 2];
    }

    final centerTileX = lon2tileX(centerLng, _zoom);
    final centerTileY = lat2tileY(centerLat, _zoom);

    final minTileX = centerTileX - _gridHalfSize;
    final maxTileX = centerTileX + _gridHalfSize;
    final minTileY = centerTileY - _gridHalfSize;
    final maxTileY = centerTileY + _gridHalfSize;

    _originPx = minTileX * _tileSize;
    _originPy = minTileY * _tileSize;

    final canvasWidth = (_gridHalfSize * 2 + 1) * _tileSize;
    final canvasHeight = (_gridHalfSize * 2 + 1) * _tileSize;

    final centerPx = lon2pixelX(centerLng, _zoom, _tileSize) - _originPx;
    final centerPy = lat2pixelY(centerLat, _zoom, _tileSize) - _originPy;

    final orderedContacts = List<PersonEntry>.from(geoContacts);
    if (widget.highlightPersonId != null) {
      orderedContacts.sort((a, b) {
        if (a.id == widget.highlightPersonId) return 1;
        if (b.id == widget.highlightPersonId) return -1;
        return 0;
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!_hasCenteredInitialView &&
            constraints.maxWidth > 0 &&
            constraints.maxHeight > 0) {
          _hasCenteredInitialView = true;
          if (hasHighlightCoords) _hasCenteredHighlightPerson = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              final dx = (constraints.maxWidth / 2.0) - centerPx;
              final dy = (constraints.maxHeight / 2.0) - centerPy;
              _transformationController.value =
                  Matrix4.translationValues(dx, dy, 0.0);
            }
          });
        } else if (hasHighlightCoords &&
            !_hasCenteredHighlightPerson &&
            constraints.maxWidth > 0 &&
            constraints.maxHeight > 0) {
          _hasCenteredHighlightPerson = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              final dx = (constraints.maxWidth / 2.0) - centerPx;
              final dy = (constraints.maxHeight / 2.0) - centerPy;
              _transformationController.value =
                  Matrix4.translationValues(dx, dy, 0.0);
            }
          });
        }

        final currentMatrix = _transformationController.value;
        final currentScale = currentMatrix.getMaxScaleOnAxis();
        final effectiveScale = currentScale > 0.01 ? currentScale : 1.0;
        final curDx = currentMatrix.storage[12];
        final curDy = currentMatrix.storage[13];
        final viewportW =
            constraints.maxWidth > 0 ? constraints.maxWidth : 400.0;
        final viewportH =
            constraints.maxHeight > 0 ? constraints.maxHeight : 600.0;
        final canvasCenterX = ((viewportW / 2.0) - curDx) / effectiveScale;
        final canvasCenterY = ((viewportH / 2.0) - curDy) / effectiveScale;
        final focalTileX = minTileX + (canvasCenterX / _tileSize).floor();
        final focalTileY = minTileY + (canvasCenterY / _tileSize).floor();

        final tileCoords = <({int x, int y})>[];
        for (int tx = minTileX; tx <= maxTileX; tx++) {
          for (int ty = minTileY; ty <= maxTileY; ty++) {
            tileCoords.add((x: tx, y: ty));
          }
        }
        tileCoords.sort((a, b) {
          final distA = (a.x - focalTileX).abs() + (a.y - focalTileY).abs();
          final distB = (b.x - focalTileX).abs() + (b.y - focalTileY).abs();
          return distA.compareTo(distB);
        });

        return Stack(
          children: [
            ClipRect(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent) {
                    final now = clock.now();
                    if (_lastZoomChangeTime == null ||
                        now.difference(_lastZoomChangeTime!).inMilliseconds >=
                            100) {
                      if (pointerSignal.scrollDelta.dy < -2 && _zoom < 18) {
                        _lastZoomChangeTime = now;
                        changeZoom(
                          _zoom + 1,
                          screenFocalPoint: pointerSignal.position,
                          constraints: constraints,
                          centerLng: centerLng,
                          centerLat: centerLat,
                        );
                      } else if (pointerSignal.scrollDelta.dy > 2 && _zoom > 10) {
                        _lastZoomChangeTime = now;
                        changeZoom(
                          _zoom - 1,
                          screenFocalPoint: pointerSignal.position,
                          constraints: constraints,
                          centerLng: centerLng,
                          centerLat: centerLat,
                        );
                      }
                    }
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTapDown: (details) {
                    if (_zoom < 18) {
                      changeZoom(
                        _zoom + 1,
                        screenFocalPoint: details.localPosition,
                        constraints: constraints,
                        centerLng: centerLng,
                        centerLat: centerLat,
                      );
                    }
                  },
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(250),
                    panEnabled: true,
                    scaleEnabled: true,
                    trackpadScrollCausesScale: true,
                    minScale: 0.6,
                    maxScale: 2.0,
                    onInteractionUpdate: (details) {
                      _lastPinchFocalPoint = details.localFocalPoint;
                    },
                    onInteractionEnd: (details) {
                      final m = _transformationController.value;
                      final currentScale = m.getMaxScaleOnAxis();
                      if (currentScale >= 1.25 && _zoom < 18) {
                        changeZoom(
                          _zoom + 1,
                          screenFocalPoint: _lastPinchFocalPoint,
                          constraints: constraints,
                          centerLng: centerLng,
                          centerLat: centerLat,
                        );
                      } else if (currentScale <= 0.8 && _zoom > 10) {
                        changeZoom(
                          _zoom - 1,
                          screenFocalPoint: _lastPinchFocalPoint,
                          constraints: constraints,
                          centerLng: centerLng,
                          centerLat: centerLat,
                        );
                      } else if ((currentScale - 1.0).abs() > 0.05) {
                        final dx = m.storage[12];
                        final dy = m.storage[13];
                        _transformationController.value =
                            Matrix4.translationValues(dx, dy, 0.0);
                      }
                    },
                    child: Container(
                      width: canvasWidth,
                      height: canvasHeight,
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                      child: Stack(
                        children: [
                          // Camada de Tiles OSM com cache
                          RepaintBoundary(
                            child: Stack(
                              children: [
                                for (final coord in tileCoords)
                                  Positioned(
                                    key: ValueKey(
                                      'tile_pos_${_zoom}_${coord.x}_${coord.y}',
                                    ),
                                    left: (coord.x - minTileX) * _tileSize,
                                    top: (coord.y - minTileY) * _tileSize,
                                    child: CachedTileWidget(
                                      key: ValueKey(
                                        'tile_${_zoom}_${coord.x}_${coord.y}',
                                      ),
                                      z: _zoom,
                                      x: coord.x,
                                      y: coord.y,
                                      size: _tileSize,
                                      isDark: isDark,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Marcos geolocalizados
                          if (widget.showLandmarks)
                            RepaintBoundary(
                              child: Stack(
                                children: [
                                  for (int i = 0; i < geoLandmarks.length; i++)
                                    _buildLandmarkPin(
                                      geoLandmarks[i],
                                      i,
                                      geoLandmarks.length,
                                      originPx: _originPx,
                                      originPy: _originPy,
                                      canvasWidth: canvasWidth,
                                      canvasHeight: canvasHeight,
                                    ),
                                ],
                              ),
                            ),

                          // Pinos de contatos
                          RepaintBoundary(
                            child: Stack(
                              children: [
                                for (int i = 0; i < orderedContacts.length; i++)
                                  _buildMapPin(
                                    orderedContacts[i],
                                    i,
                                    orderedContacts.length,
                                    originPx: _originPx,
                                    originPy: _originPy,
                                    canvasWidth: canvasWidth,
                                    canvasHeight: canvasHeight,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Banner de destaque
            if (widget.highlightPersonId != null && highlightPerson != null)
              Positioned(
                top: 12,
                left: 12,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(20),
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: widget.onClearHighlight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFF59E0B),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            color: Color(0xFFD97706),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Destacado: ${highlightPerson.name.split(' ').first}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.close,
                            size: 14,
                            color: AppTheme.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Controles Flutuantes de Zoom (+ / -) e Centralizar Território
            Positioned(
              top: 12,
              right: 12,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'map_zoom_in',
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    tooltip: 'Aproximar Zoom',
                    onPressed: () {
                      if (_zoom < 18) {
                        changeZoom(
                          _zoom + 1,
                          constraints: constraints,
                          centerLng: centerLng,
                          centerLat: centerLat,
                        );
                      }
                    },
                    child: const Icon(Icons.add),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Z: $_zoom',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FloatingActionButton.small(
                    heroTag: 'map_zoom_out',
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    tooltip: 'Afastar Zoom',
                    onPressed: () {
                      if (_zoom > 10) {
                        changeZoom(
                          _zoom - 1,
                          constraints: constraints,
                          centerLng: centerLng,
                          centerLat: centerLat,
                        );
                      }
                    },
                    child: const Icon(Icons.remove),
                  ),
                  const SizedBox(height: 6),
                  FloatingActionButton.small(
                    heroTag: 'map_recenter',
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    tooltip: 'Centralizar Território',
                    onPressed: () => recenterMap(
                      constraints.maxWidth,
                      constraints.maxHeight,
                      centerPx,
                      centerPy,
                    ),
                    child: const Icon(Icons.my_location, size: 18),
                  ),
                ],
              ),
            ),

            // Selo de Atribuição OpenStreetMap
            Positioned(
              bottom: 8,
              left: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 10, color: Colors.black87),
                    ),
                  ),
                  if (widget.contacts.length > geoContacts.length) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.amber.shade600,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '${widget.contacts.length - geoContacts.length} contatos sem GPS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLandmarkPin(
    TerritoryLandmark landmark,
    int index,
    int total, {
    required double originPx,
    required double originPy,
    required double canvasWidth,
    required double canvasHeight,
  }) {
    double x;
    double y;

    final hasGeo =
        landmark.latitude != null &&
        landmark.longitude != null &&
        (landmark.latitude != 0.0 || landmark.longitude != 0.0) &&
        landmark.latitude!.abs() <= 90 &&
        landmark.longitude!.abs() <= 180;
    if (hasGeo) {
      x = lon2pixelX(landmark.longitude!, _zoom, _tileSize) - originPx;
      y = lat2pixelY(landmark.latitude!, _zoom, _tileSize) - originPy;
    } else {
      final radius = 120.0 + (index % 3) * 60.0;
      final angle = (index * 2 * math.pi) / (total > 0 ? total : 1);
      x = (canvasWidth / 2) + radius * math.cos(angle);
      y = (canvasHeight / 2) + radius * math.sin(angle);
    }

    final isSelected = widget.selectedLandmark?.id == landmark.id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      key: ValueKey('landmark_pin_${landmark.id}'),
      left: (x - 20).clamp(10.0, canvasWidth - 60.0),
      top: (y - 35).clamp(10.0, canvasHeight - 60.0),
      child: GestureDetector(
        onTap: () => widget.onLandmarkSelected(landmark),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 120),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? landmark.color
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
                border: Border.all(color: landmark.color, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    landmark.icon,
                    size: 14,
                    color: isSelected ? Colors.white : landmark.color,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      landmark.name.split(' ').first,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white : AppTheme.textDark),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              landmark.icon,
              color: landmark.color,
              size: isSelected ? 34 : 26,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPin(
    PersonEntry person,
    int index,
    int total, {
    required double originPx,
    required double originPy,
    required double canvasWidth,
    required double canvasHeight,
  }) {
    double x;
    double y;

    final hasGeo =
        person.latitude != null &&
        person.longitude != null &&
        (person.latitude != 0.0 || person.longitude != 0.0) &&
        person.latitude!.abs() <= 90 &&
        person.longitude!.abs() <= 180;
    if (hasGeo) {
      x = lon2pixelX(person.longitude!, _zoom, _tileSize) - originPx;
      y = lat2pixelY(person.latitude!, _zoom, _tileSize) - originPy;
    } else {
      final radius = 180.0 + (index % 4) * 60.0;
      final angle = (index * 2 * math.pi) / (total > 0 ? total : 1);
      x = (canvasWidth / 2) + radius * math.cos(angle);
      y = (canvasHeight / 2) + radius * math.sin(angle);
    }

    final isHighlighted =
        widget.highlightPersonId != null && person.id == widget.highlightPersonId;
    final isSelected = widget.selectedPerson?.id == person.id;
    final statusColor = getStatusColor(person.status);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isForeign =
        person.tags.toLowerCase().contains('estrangeiro') ||
        (person.generalNotes ?? '').toLowerCase().contains('idioma') ||
        (person.generalNotes ?? '').toLowerCase().contains('língua') ||
        (person.generalNotes ?? '').toLowerCase().contains('estrangeir');

    final Color pinColor;
    if (isHighlighted) {
      pinColor = const Color(0xFFD97706);
    } else if (isSelected) {
      pinColor = AppTheme.primaryBlue;
    } else if (isForeign) {
      pinColor = const Color(0xFF0284C7);
    } else {
      pinColor = statusColor;
    }

    return Positioned(
      key: ValueKey('person_pin_${person.id}'),
      left: (x - (isHighlighted ? 24 : 20)).clamp(10.0, canvasWidth - 70.0),
      top: (y - (isHighlighted ? 44 : 35)).clamp(10.0, canvasHeight - 70.0),
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTap: () => widget.onPersonSelected(person),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: isHighlighted ? 140 : 110),
              padding: EdgeInsets.symmetric(
                horizontal: isHighlighted ? 10 : 8,
                vertical: isHighlighted ? 5 : 4,
              ),
              decoration: BoxDecoration(
                color: isHighlighted
                    ? const Color(0xFFD97706)
                    : (isSelected
                          ? Colors.black87
                          : (isDark ? const Color(0xFF1E293B) : Colors.white)),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  if (isHighlighted)
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.65),
                      blurRadius: 14,
                      spreadRadius: 3,
                    )
                  else
                    const BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                ],
                border: Border.all(
                  color: isHighlighted ? Colors.white : pinColor,
                  width: isHighlighted ? 2.5 : 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isHighlighted) ...[
                    const Icon(Icons.star, color: Colors.amberAccent, size: 13),
                    const SizedBox(width: 4),
                  ] else if (isForeign) ...[
                    const Text('🌐', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      person.name.split(' ').first,
                      style: TextStyle(
                        fontSize: isHighlighted ? 12 : 11,
                        fontWeight: FontWeight.bold,
                        color: (isHighlighted || isSelected)
                            ? Colors.white
                            : (isDark ? Colors.white : AppTheme.textDark),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isHighlighted
                  ? Icons.stars
                  : (isForeign ? Icons.public : Icons.location_on),
              color: isHighlighted ? const Color(0xFFD97706) : pinColor,
              size: isHighlighted ? 44 : (isSelected ? 38 : 30),
              shadows: isHighlighted
                  ? [Shadow(color: Colors.amber.shade300, blurRadius: 12)]
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
