import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../mbtiles/mbtiles_service.dart';
import 'tile_cache_interface.dart';
import 'tile_cache_web.dart' if (dart.library.io) 'tile_cache_native.dart';

/// Estilos de camada de mapa compatíveis com Organic Maps e navegação teocrática
enum MapLayerStyle {
  standard(
    'standard',
    'Padrão (OSM)',
    'Ruas, bairros e povoados com alta clareza cartográfica',
    Icons.map_outlined,
  ),
  satellite(
    'satellite',
    'Satélite (Esri World)',
    'Fotografia aérea real para identificar telhados, trilhas e rios',
    Icons.satellite_alt_rounded,
  ),
  topo(
    'topo',
    'Topográfico (Relevo)',
    'Curvas de nível e hidrografia para áreas rurais e ribeirinhas',
    Icons.terrain_rounded,
  ),
  dark(
    'dark',
    'Modo Noturno (Carto)',
    'Contraste elevado para economia de bateria e ministério à noite',
    Icons.dark_mode_outlined,
  );

  final String id;
  final String label;
  final String description;
  final IconData icon;

  const MapLayerStyle(this.id, this.label, this.description, this.icon);
}

class TileCacheService {
  static final TileCacheService instance = TileCacheService._internal();
  TileCacheBackend _backend = getTileBackend();
  final Map<String, Future<Uint8List?>> _inFlight = {};
  static final Map<String, Uint8List> _memoryCache = {};
  MapLayerStyle _activeStyle = MapLayerStyle.standard;

  TileCacheService._internal();

  MapLayerStyle get activeStyle => _activeStyle;

  void setLayerStyle(MapLayerStyle style) {
    if (_activeStyle != style) {
      _activeStyle = style;
      _memoryCache.clear();
      _inFlight.clear();
    }
  }

  String getTileUrl(int z, int x, int y) {
    switch (_activeStyle) {
      case MapLayerStyle.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/$z/$y/$x';
      case MapLayerStyle.topo:
        return 'https://tile.opentopomap.org/$z/$x/$y.png';
      case MapLayerStyle.dark:
        return 'https://a.basemaps.cartocdn.com/dark_all/$z/$x/$y.png';
      case MapLayerStyle.standard:
        return 'https://tile.openstreetmap.org/$z/$x/$y.png';
    }
  }

  @visibleForTesting
  set backend(TileCacheBackend b) {
    _backend = b;
    _inFlight.clear();
    _memoryCache.clear();
  }

  static Uint8List? getFromMemory(int z, int x, int y) {
    return _memoryCache['$z/$x/$y'];
  }

  /// Retorna bloco pai de menor resolução quando o nível atual ainda está carregando,
  /// eliminando 100% dos piscas/flashes cinzas na tela durante o zoom estilo Organic Maps.
  static Uint8List? getFallbackFromMemory(int z, int x, int y) {
    final exact = _memoryCache['$z/$x/$y'];
    if (exact != null) return exact;
    if (z > 1) {
      final parent = _memoryCache['${z - 1}/${x >> 1}/${y >> 1}'];
      if (parent != null) return parent;
    }
    if (z > 2) {
      final grandParent = _memoryCache['${z - 2}/${x >> 2}/${y >> 2}'];
      if (grandParent != null) return grandParent;
    }
    return null;
  }

  Future<Uint8List?> getTileBytes(int z, int x, int y) {
    final key = '$z/$x/$y';
    final mem = _memoryCache[key];
    if (mem != null) return Future.value(mem);

    return _inFlight.putIfAbsent(key, () async {
      try {
        // 1. Tenta carregar do pacote regional .mbtiles (<0.2ms)
        final mbtile = await MBTilesService.instance.getTile(z, x, y);
        if (mbtile != null && mbtile.isNotEmpty) {
          if (_memoryCache.length > 600) {
            _memoryCache.remove(_memoryCache.keys.first);
          }
          _memoryCache[key] = mbtile;
          return mbtile;
        }

        // 2. Tenta carregar do backend padrão (cache local no disco / download online)
        final res = await _backend.getTile(z, x, y);
        if (res != null && res.isNotEmpty) {
          if (_memoryCache.length > 600) {
            _memoryCache.remove(_memoryCache.keys.first);
          }
          _memoryCache[key] = res;
        }
        return res;
      } finally {
        _inFlight.remove(key);
      }
    });
  }

  Future<void> saveTile(int z, int x, int y, Uint8List bytes) {
    return _backend.saveTile(z, x, y, bytes);
  }

  Future<bool> isTileCached(int z, int x, int y) {
    return _backend.isTileCached(z, x, y);
  }

  Future<int> getCachedTileCount() {
    return _backend.getCachedTileCount();
  }

  /// Pré-carrega uma região inteira de blocos para uso offline no ministério
  Future<int> preloadArea({
    required int z,
    required int minX,
    required int maxX,
    required int minY,
    required int maxY,
    void Function(int completed, int total)? onProgress,
  }) async {
    final maxCoord = (1 << z) - 1;
    final actualMinX = (minX <= maxX ? minX : maxX).clamp(0, maxCoord);
    final actualMaxX = (minX <= maxX ? maxX : minX).clamp(0, maxCoord);
    final actualMinY = (minY <= maxY ? minY : maxY).clamp(0, maxCoord);
    final actualMaxY = (minY <= maxY ? maxY : minY).clamp(0, maxCoord);

    int total = (actualMaxX - actualMinX + 1) * (actualMaxY - actualMinY + 1);
    if (total <= 0) return 0;
    int completed = 0;
    int savedCount = 0;

    for (int x = actualMinX; x <= actualMaxX; x++) {
      for (int y = actualMinY; y <= actualMaxY; y++) {
        try {
          final bytes = await _backend.getTile(z, x, y);
          if (bytes != null && bytes.isNotEmpty) {
            savedCount++;
          }
        } catch (_) {}
        completed++;
        onProgress?.call(completed, total);
      }
    }

    return savedCount;
  }
}

/// Widget otimizado para renderizar tiles com cache persistente e fallback offline
class CachedTileWidget extends StatefulWidget {
  final int z;
  final int x;
  final int y;
  final double size;
  final bool isDark;

  const CachedTileWidget({
    super.key,
    required this.z,
    required this.x,
    required this.y,
    this.size = 256.0,
    required this.isDark,
  });

  @override
  State<CachedTileWidget> createState() => _CachedTileWidgetState();
}

class _CachedTileWidgetState extends State<CachedTileWidget> {
  Uint8List? _tileBytes;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _tileBytes = TileCacheService.getFromMemory(widget.z, widget.x, widget.y) ??
        TileCacheService.getFallbackFromMemory(widget.z, widget.x, widget.y);
    if (TileCacheService.getFromMemory(widget.z, widget.x, widget.y) == null) {
      _loadTile();
    }
  }

  @override
  void didUpdateWidget(CachedTileWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.z != widget.z ||
        oldWidget.x != widget.x ||
        oldWidget.y != widget.y) {
      final exact = TileCacheService.getFromMemory(widget.z, widget.x, widget.y);
      if (exact != null) {
        _tileBytes = exact;
      } else {
        // Preserva o tile anterior ou obtém fallback em memória do zoom adjacente
        _tileBytes = _tileBytes ??
            TileCacheService.getFallbackFromMemory(widget.z, widget.x, widget.y);
        _loadTile();
      }
    }
  }

  Future<void> _loadTile() async {
    final requestId = ++_requestId;
    final bytes = await TileCacheService.instance.getTileBytes(
      widget.z,
      widget.x,
      widget.y,
    );
    if (mounted && requestId == _requestId) {
      setState(() {
        _tileBytes = bytes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tileBytes != null && _tileBytes!.isNotEmpty) {
      return Image.memory(
        _tileBytes!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }

    // Se estiver carregando pela primeira vez ou offline sem cache, renderiza grade cartográfica suave
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.isDark
            ? const Color(0xFF1E293B)
            : const Color(0xFFE2E8F0),
        border: Border.all(
          color: widget.isDark ? Colors.white10 : Colors.black12,
          width: 0.5,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_outlined,
              size: 24,
              color: widget.isDark ? Colors.white24 : Colors.black26,
            ),
            const SizedBox(height: 2),
            Text(
              'Mapa indisponível',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: widget.isDark ? Colors.white24 : Colors.black26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
