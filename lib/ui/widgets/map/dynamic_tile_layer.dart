import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../territory/tile_cache/tile_cache_service.dart';

/// Layer de renderização dinâmica de tiles cartográficos com poda por viewport.
///
/// Recalcula e constrói exclusivamente os tiles visíveis no momento em que a
/// matriz do [transformationController] ou a orientação de [rotationListenable]
/// mudam — eliminando rebuilds da tela inteira durante arraste, zoom e rotação.
class DynamicTileLayer extends StatefulWidget {
  final TransformationController transformationController;
  final ValueListenable<double> rotationListenable;
  final int zoom;
  final int minTileX;
  final int maxTileX;
  final int minTileY;
  final int maxTileY;
  final double originPx;
  final double originPy;
  final double viewportW;
  final double viewportH;
  final double viewerW;
  final double viewerH;
  final double tileSize;
  final bool isDark;
  final MapLayerStyle layerStyle;
  final Matrix4? initialMatrixOverride;
  final bool Function()? shouldIgnoreTransformUpdates;

  const DynamicTileLayer({
    super.key,
    required this.transformationController,
    required this.rotationListenable,
    required this.zoom,
    required this.minTileX,
    required this.maxTileX,
    required this.minTileY,
    required this.maxTileY,
    required this.originPx,
    required this.originPy,
    required this.viewportW,
    required this.viewportH,
    required this.viewerW,
    required this.viewerH,
    required this.tileSize,
    required this.isDark,
    required this.layerStyle,
    this.initialMatrixOverride,
    this.shouldIgnoreTransformUpdates,
  });

  @override
  State<DynamicTileLayer> createState() => _DynamicTileLayerState();
}

class _DynamicTileLayerState extends State<DynamicTileLayer> {
  late ({int minX, int maxX, int minY, int maxY}) _bounds;

  @override
  void initState() {
    super.initState();
    _bounds = _computeBounds(matrixOverride: widget.initialMatrixOverride);
    widget.transformationController.addListener(_onViewportChanged);
    widget.rotationListenable.addListener(_onViewportChanged);
  }

  @override
  void didUpdateWidget(covariant DynamicTileLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transformationController != widget.transformationController) {
      oldWidget.transformationController.removeListener(_onViewportChanged);
      widget.transformationController.addListener(_onViewportChanged);
    }
    if (oldWidget.rotationListenable != widget.rotationListenable) {
      oldWidget.rotationListenable.removeListener(_onViewportChanged);
      widget.rotationListenable.addListener(_onViewportChanged);
    }
    _bounds = _computeBounds(matrixOverride: widget.initialMatrixOverride);
  }

  @override
  void dispose() {
    widget.transformationController.removeListener(_onViewportChanged);
    widget.rotationListenable.removeListener(_onViewportChanged);
    super.dispose();
  }

  ({int minX, int maxX, int minY, int maxY}) _computeBounds({
    Matrix4? matrixOverride,
  }) {
    final m = matrixOverride ?? widget.transformationController.value;
    final currentScale = m.getMaxScaleOnAxis();
    final effectiveScale = currentScale > 0.01 ? currentScale : 1.0;
    final curDx = m.storage[12];
    final curDy = m.storage[13];

    final canvasCenterX = ((widget.viewerW / 2.0) - curDx) / effectiveScale;
    final canvasCenterY = ((widget.viewerH / 2.0) - curDy) / effectiveScale;
    final centerWorldX = widget.originPx + canvasCenterX;
    final centerWorldY = widget.originPy + canvasCenterY;

    // Bounding box exata da viewport rotacionada dentro do InteractiveViewer
    final rotation = widget.rotationListenable.value;
    final absCos = math.cos(rotation).abs();
    final absSin = math.sin(rotation).abs();
    final visibleHalfW =
        (widget.viewportW * absCos + widget.viewportH * absSin) / 2.0;
    final visibleHalfH =
        (widget.viewportW * absSin + widget.viewportH * absCos) / 2.0;

    final minVisWorldX = centerWorldX - visibleHalfW / effectiveScale;
    final maxVisWorldX = centerWorldX + visibleHalfW / effectiveScale;
    final minVisWorldY = centerWorldY - visibleHalfH / effectiveScale;
    final maxVisWorldY = centerWorldY + visibleHalfH / effectiveScale;

    final maxTileIndex = (1 << widget.zoom) - 1;
    // Anel de 3 tiles (768px) de pré-carregamento em todas as direções para evitar vazios em rotação
    const int tileBuffer = 3;
    final calcMinX = ((minVisWorldX / widget.tileSize).floor() - tileBuffer)
        .clamp(0, maxTileIndex);
    final calcMaxX = ((maxVisWorldX / widget.tileSize).floor() + tileBuffer)
        .clamp(0, maxTileIndex);
    final calcMinY = ((minVisWorldY / widget.tileSize).floor() - tileBuffer)
        .clamp(0, maxTileIndex);
    final calcMaxY = ((maxVisWorldY / widget.tileSize).floor() + tileBuffer)
        .clamp(0, maxTileIndex);

    final clampedGridMinX = widget.minTileX.clamp(0, maxTileIndex);
    final clampedGridMaxX = widget.maxTileX.clamp(0, maxTileIndex);
    final clampedGridMinY = widget.minTileY.clamp(0, maxTileIndex);
    final clampedGridMaxY = widget.maxTileY.clamp(0, maxTileIndex);

    final loadMinX = math.max(clampedGridMinX, calcMinX);
    final loadMaxX = math.min(clampedGridMaxX, calcMaxX);
    final loadMinY = math.max(clampedGridMinY, calcMinY);
    final loadMaxY = math.min(clampedGridMaxY, calcMaxY);

    return (minX: loadMinX, maxX: loadMaxX, minY: loadMinY, maxY: loadMaxY);
  }

  void _onViewportChanged() {
    if (!mounted || widget.shouldIgnoreTransformUpdates?.call() == true) return;
    final next = _computeBounds();
    if (next.minX != _bounds.minX ||
        next.maxX != _bounds.maxX ||
        next.minY != _bounds.minY ||
        next.maxY != _bounds.maxY) {
      setState(() {
        _bounds = next;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ordem estável (x, y) evita embaralhar RenderObjects no Stack a cada tile
    // atravessado durante o arraste, e RepaintBoundary isola repints de tiles
    // dos pinos e sombras do mapa.
    return RepaintBoundary(
      child: Stack(
        children: [
          for (int x = _bounds.minX; x <= _bounds.maxX; x++)
            for (int y = _bounds.minY; y <= _bounds.maxY; y++)
              Positioned(
                key: ValueKey('tile_pos_${widget.zoom}_${x}_$y'),
                left: (x - widget.minTileX) * widget.tileSize,
                top: (y - widget.minTileY) * widget.tileSize,
                child: CachedTileWidget(
                  key: ValueKey(
                    'tile_${widget.layerStyle.id}_${widget.zoom}_${x}_$y',
                  ),
                  z: widget.zoom,
                  x: x,
                  y: y,
                  size: widget.tileSize,
                  isDark: widget.isDark,
                  layerStyle: widget.layerStyle,
                ),
              ),
        ],
      ),
    );
  }
}
