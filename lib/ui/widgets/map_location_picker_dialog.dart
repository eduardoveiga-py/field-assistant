import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../territory/geocoding_service.dart';
import '../../territory/geolocation_helper.dart';
import '../../territory/tile_cache/tile_cache_service.dart';

class MapLocationPickerDialog extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialAddress;
  final String? initialNeighborhood;

  const MapLocationPickerDialog({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialAddress,
    this.initialNeighborhood,
  });

  @override
  State<MapLocationPickerDialog> createState() => _MapLocationPickerDialogState();
}

class _MapLocationPickerDialogState extends State<MapLocationPickerDialog> {
  late double _selectedLat;
  late double _selectedLng;
  late double _viewCenterLat;
  late double _viewCenterLng;
  final TransformationController _transformationController = TransformationController();
  bool _hasCenteredInitialView = false;
  int _zoom = 16;
  double _basePinchScale = 1.0;
  double _trackpadScale = 1.0;
  DateTime? _lastZoomChangeTime;
  bool _isLoadingAddress = false;
  ReverseGeocodingResult? _geocodedResult;
  String _statusText = 'Toque no mapa para marcar a localização exata da casa.';

  // Constantes de visualização de grade de blocos
  static const int _gridHalfSize = 5; // 11x11 tiles = 2816x2816 px
  static const double _tileSize = 256.0;

  void _changeZoom(int newZoom, BoxConstraints constraints, double originPx, double originPy) {
    final targetZoom = newZoom.clamp(10, 18);
    if (targetZoom == _zoom) return;

    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    final effectiveScale = currentScale > 0.01 ? currentScale : 1.0;
    final dx = currentMatrix.storage[12];
    final dy = currentMatrix.storage[13];

    final viewportW = constraints.maxWidth > 0 ? constraints.maxWidth : 400.0;
    final viewportH = constraints.maxHeight > 0 ? constraints.maxHeight : 500.0;

    final canvasCenterX = ((viewportW / 2.0) - dx) / effectiveScale;
    final canvasCenterY = ((viewportH / 2.0) - dy) / effectiveScale;
    final worldPx = originPx + canvasCenterX;
    final worldPy = originPy + canvasCenterY;
    final focalLng = _pixelX2lon(worldPx, _zoom);
    final focalLat = _pixelY2lat(worldPy, _zoom);

    final newCenterTileX = _lon2tileX(_viewCenterLng, targetZoom);
    final newCenterTileY = _lat2tileY(_viewCenterLat, targetZoom);
    final newMinTileX = newCenterTileX - _gridHalfSize;
    final newMinTileY = newCenterTileY - _gridHalfSize;
    final newOriginPx = newMinTileX * _tileSize;
    final newOriginPy = newMinTileY * _tileSize;

    final newWorldPx = _lon2pixelX(focalLng, targetZoom);
    final newWorldPy = _lat2pixelY(focalLat, targetZoom);

    final newCanvasX = newWorldPx - newOriginPx;
    final newCanvasY = newWorldPy - newOriginPy;

    final canvasWidth = (_gridHalfSize * 2 + 1) * _tileSize;
    final canvasHeight = (_gridHalfSize * 2 + 1) * _tileSize;
    final newDx = ((viewportW / 2.0) - newCanvasX).clamp(viewportW - canvasWidth, 0.0);
    final newDy = ((viewportH / 2.0) - newCanvasY).clamp(viewportH - canvasHeight, 0.0);

    setState(() {
      _zoom = targetZoom;
    });

    _transformationController.value = Matrix4.translationValues(newDx, newDy, 0.0);
  }

  @override
  void initState() {
    super.initState();
    _selectedLat = widget.initialLat ?? -23.550520;
    _selectedLng = widget.initialLng ?? -46.633308;
    _viewCenterLat = _selectedLat;
    _viewCenterLng = _selectedLng;

    final centerTileX = _lon2tileX(_viewCenterLng, _zoom);
    final centerTileY = _lat2tileY(_viewCenterLat, _zoom);
    final minTileX = centerTileX - _gridHalfSize;
    final minTileY = centerTileY - _gridHalfSize;
    final originPx = minTileX * _tileSize;
    final originPy = minTileY * _tileSize;
    final pinX = _lon2pixelX(_selectedLng, _zoom) - originPx;
    final pinY = _lat2pixelY(_selectedLat, _zoom) - originPy;
    _transformationController.value = Matrix4.translationValues(300.0 - pinX, 250.0 - pinY, 0.0);

    if (widget.initialLat != null && widget.initialLng != null) {
      _fetchAddressForCoords(_selectedLat, _selectedLng);
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  int _lon2tileX(double lon, int z) => ((lon + 180.0) / 360.0 * (1 << z)).floor();

  int _lat2tileY(double lat, int z) {
    final latRad = lat.clamp(-85.0511, 85.0511) * math.pi / 180.0;
    return ((1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) / 2.0 * (1 << z)).floor();
  }

  double _lon2pixelX(double lon, int z) => (lon + 180.0) / 360.0 * (_tileSize * (1 << z));

  double _lat2pixelY(double lat, int z) {
    final latRad = lat.clamp(-85.0511, 85.0511) * math.pi / 180.0;
    final sinLat = math.sin(latRad).clamp(-0.9999, 0.9999);
    return (0.5 - math.log((1.0 + sinLat) / (1.0 - sinLat)) / (4.0 * math.pi)) * (_tileSize * (1 << z));
  }

  double _pixelX2lon(double px, int z) => (px / (_tileSize * (1 << z))) * 360.0 - 180.0;

  double _pixelY2lat(double py, int z) {
    final n = math.pi - (2.0 * math.pi * py) / (_tileSize * (1 << z));
    return 180.0 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
  }

  Future<void> _fetchAddressForCoords(double lat, double lng) async {
    setState(() {
      _isLoadingAddress = true;
      _statusText = 'Buscando endereço via OpenStreetMap...';
    });

    final res = await GeocodingService.reverseGeocode(lat, lng);
    if (!mounted) return;

    setState(() {
      _isLoadingAddress = false;
      _geocodedResult = res;
      if (res != null) {
        _statusText = res.formattedSummary;
      } else {
        _statusText = 'Local marcado: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
      }
    });
  }

  Future<void> _useCurrentGps() async {
    setState(() => _statusText = 'Obtendo GPS do dispositivo...');
    final pos = await GeolocationHelper.getCurrentLocation();
    if (!mounted) return;

    if (pos != null) {
      setState(() {
        _selectedLat = pos.latitude;
        _selectedLng = pos.longitude;
        _viewCenterLat = pos.latitude;
        _viewCenterLng = pos.longitude;
        _hasCenteredInitialView = false;
      });
      await _fetchAddressForCoords(pos.latitude, pos.longitude);
    } else {
      setState(() => _statusText = 'GPS indisponível. Toque no mapa para marcar.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final centerTileX = _lon2tileX(_viewCenterLng, _zoom);
    final centerTileY = _lat2tileY(_viewCenterLat, _zoom);

    final minTileX = centerTileX - _gridHalfSize;
    final maxTileX = centerTileX + _gridHalfSize;
    final minTileY = centerTileY - _gridHalfSize;
    final maxTileY = centerTileY + _gridHalfSize;

    final originPx = minTileX * _tileSize;
    final originPy = minTileY * _tileSize;

    final canvasWidth = (_gridHalfSize * 2 + 1) * _tileSize;
    final canvasHeight = (_gridHalfSize * 2 + 1) * _tileSize;

    final pinX = _lon2pixelX(_selectedLng, _zoom) - originPx;
    final pinY = _lat2pixelY(_selectedLat, _zoom) - originPy;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 700),
        child: Column(
          children: [
            // Cabeçalho
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.edit_location_alt, color: AppTheme.primaryBlue, size: 24),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Marcar Localização Exata da Casa no Mapa',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Mapa Interativo com OpenStreetMap Tiles
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (!_hasCenteredInitialView && constraints.maxWidth > 0 && constraints.maxHeight > 0) {
                    _hasCenteredInitialView = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        final dx = (constraints.maxWidth / 2.0) - pinX;
                        final dy = (constraints.maxHeight / 2.0) - pinY;
                        _transformationController.value = Matrix4.translationValues(dx, dy, 0.0);
                      }
                    });
                  }

                  return Stack(
                    children: [
                      ClipRect(
                        child: Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerSignal: (pointerSignal) {
                            if (pointerSignal is PointerScrollEvent) {
                              final now = DateTime.now();
                              if (_lastZoomChangeTime == null || now.difference(_lastZoomChangeTime!).inMilliseconds > 180) {
                                if (pointerSignal.scrollDelta.dy.abs() > 2) {
                                  _lastZoomChangeTime = now;
                                  if (pointerSignal.scrollDelta.dy < 0 && _zoom < 18) {
                                    _changeZoom(_zoom + 1, constraints, originPx, originPy);
                                  } else if (pointerSignal.scrollDelta.dy > 0 && _zoom > 10) {
                                    _changeZoom(_zoom - 1, constraints, originPx, originPy);
                                  }
                                }
                              }
                            }
                          },
                          onPointerPanZoomStart: (event) {
                            _trackpadScale = 1.0;
                          },
                          onPointerPanZoomUpdate: (event) {
                            _trackpadScale *= event.scale;
                            final now = DateTime.now();
                            if (_lastZoomChangeTime == null || now.difference(_lastZoomChangeTime!).inMilliseconds > 200) {
                              if (_trackpadScale > 1.25 && _zoom < 18) {
                                _lastZoomChangeTime = now;
                                _trackpadScale = 1.0;
                                _changeZoom(_zoom + 1, constraints, originPx, originPy);
                              } else if (_trackpadScale < 0.8 && _zoom > 10) {
                                _lastZoomChangeTime = now;
                                _trackpadScale = 1.0;
                                _changeZoom(_zoom - 1, constraints, originPx, originPy);
                              }
                            }
                          },
                          onPointerPanZoomEnd: (event) {
                            _trackpadScale = 1.0;
                          },
                          child: InteractiveViewer(
                            transformationController: _transformationController,
                            constrained: false,
                            boundaryMargin: EdgeInsets.zero,
                            panEnabled: true,
                            scaleEnabled: true,
                            trackpadScrollCausesScale: false,
                            minScale: 0.65,
                            maxScale: 1.8,
                            onInteractionStart: (details) {
                              _basePinchScale = 1.0;
                            },
                            onInteractionUpdate: (details) {
                              if (details.pointerCount >= 2) {
                                final relativeScale = details.scale / _basePinchScale;
                                if (relativeScale > 1.25 && _zoom < 18) {
                                  _basePinchScale = details.scale;
                                  _changeZoom(_zoom + 1, constraints, originPx, originPy);
                                } else if (relativeScale < 0.8 && _zoom > 10) {
                                  _basePinchScale = details.scale;
                                  _changeZoom(_zoom - 1, constraints, originPx, originPy);
                                }
                              }
                            },
                            onInteractionEnd: (details) {
                              _basePinchScale = 1.0;
                              final m = _transformationController.value;
                              final currentScale = m.getMaxScaleOnAxis();
                              if ((currentScale - 1.0).abs() > 0.05) {
                                final dx = m.storage[12];
                                final dy = m.storage[13];
                                _transformationController.value = Matrix4.translationValues(dx, dy, 0.0);
                              }
                            },
                            child: GestureDetector(
                              onDoubleTap: () {
                                if (_zoom < 18) {
                                  _changeZoom(_zoom + 1, constraints, originPx, originPy);
                                }
                              },
                              onTapUp: (details) {
                                final clickX = details.localPosition.dx;
                                final clickY = details.localPosition.dy;
                                final worldPx = originPx + clickX;
                                final worldPy = originPy + clickY;
                                final newLng = _pixelX2lon(worldPx, _zoom);
                                final newLat = _pixelY2lat(worldPy, _zoom);

                                setState(() {
                                  _selectedLat = newLat;
                                  _selectedLng = newLng;
                                });

                                _fetchAddressForCoords(newLat, newLng);
                              },
                              child: Container(
                                width: canvasWidth,
                                height: canvasHeight,
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                child: Stack(
                                  children: [
                                    // Tiles do OpenStreetMap com suporte a cache offline móvel
                                    for (int tx = minTileX; tx <= maxTileX; tx++)
                                      for (int ty = minTileY; ty <= maxTileY; ty++)
                                        Positioned(
                                          key: ValueKey('picker_tile_pos_${_zoom}_${tx}_$ty'),
                                          left: (tx - minTileX) * _tileSize,
                                          top: (ty - minTileY) * _tileSize,
                                          child: CachedTileWidget(
                                            key: ValueKey('picker_tile_${_zoom}_${tx}_$ty'),
                                            z: _zoom,
                                            x: tx,
                                            y: ty,
                                            size: _tileSize,
                                            isDark: isDark,
                                          ),
                                        ),

                                    // Pino da Casa / Localização Selecionada
                                    Positioned(
                                      left: pinX - 20,
                                      top: pinY - 40,
                                      child: IgnorePointer(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.alertRed,
                                                borderRadius: BorderRadius.circular(6),
                                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                                              ),
                                              child: const Text(
                                                'Casa / Ponto',
                                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const Icon(
                                              Icons.location_on,
                                              color: AppTheme.alertRed,
                                              size: 40,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Controles Flutuantes de Zoom (+ / -) e GPS
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Column(
                          children: [
                            FloatingActionButton.small(
                              heroTag: 'zoom_in_picker',
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              onPressed: () {
                                if (_zoom < 18) {
                                  _changeZoom(_zoom + 1, constraints, originPx, originPy);
                                }
                              },
                              child: const Icon(Icons.add),
                            ),
                            const SizedBox(height: 6),
                            FloatingActionButton.small(
                              heroTag: 'zoom_out_picker',
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              onPressed: () {
                                if (_zoom > 10) {
                                  _changeZoom(_zoom - 1, constraints, originPx, originPy);
                                }
                              },
                              child: const Icon(Icons.remove),
                            ),
                            const SizedBox(height: 6),
                            FloatingActionButton.small(
                              heroTag: 'gps_picker',
                              tooltip: 'Minha Posição GPS',
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              onPressed: _useCurrentGps,
                              child: const Icon(Icons.my_location, size: 18),
                            ),
                          ],
                        ),
                      ),

                      // Dica de navegação
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black87.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('Toque na casa para posicionar o pino', style: TextStyle(color: Colors.white, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // Painel Inferior com Endereço e Confirmação
            Container(
              padding: const EdgeInsets.all(14),
              color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (_isLoadingAddress)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(Icons.place, size: 18, color: AppTheme.alertRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusText,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Coordenadas: ${_selectedLat.toStringAsFixed(6)}, ${_selectedLng.toStringAsFixed(6)}',
                    style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Confirmar Este Ponto'),
                        onPressed: () {
                          final finalResult = _geocodedResult ??
                              ReverseGeocodingResult(
                                latitude: _selectedLat,
                                longitude: _selectedLng,
                                street: widget.initialAddress,
                                neighborhood: widget.initialNeighborhood,
                              );
                          Navigator.pop(context, finalResult);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
