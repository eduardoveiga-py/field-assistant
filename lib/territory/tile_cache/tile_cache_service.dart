import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/app_logger.dart';
import '../mbtiles/mbtiles_service.dart';
import 'tile_cache_interface.dart';
import 'tile_cache_web.dart' if (dart.library.io) 'tile_cache_native.dart';

export 'tile_cache_interface.dart';

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

  String getTileUrl(int z, int x, int y, [MapLayerStyle? style]) {
    final s = style ?? _activeStyle;
    switch (s) {
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

  static String _cacheKey(int z, int x, int y, MapLayerStyle style) {
    final version = style == MapLayerStyle.standard
        ? MBTilesService.instance.tilesRevision.value : 0;
    return '${style.id}/$version/$z/$x/$y';
  }

  static Uint8List? getFromMemory(int z, int x, int y, [MapLayerStyle? style]) {
    final s = style ?? instance.activeStyle;
    final key = _cacheKey(z, x, y, s);
    final mem = _memoryCache[key];
    if (mem != null) return mem;
    return null;
  }

  /// Retorna bytes do ancestral apenas para consumidores que recortem o
  /// quadrante correto; não serve para exibir diretamente como tile filho.
  static Uint8List? getFallbackFromMemory(int z, int x, int y, [MapLayerStyle? style]) {
    final s = style ?? instance.activeStyle;
    final exact = getFromMemory(z, x, y, s);
    if (exact != null) return exact;
    if (z > 1) {
      final parent = getFromMemory(z - 1, x >> 1, y >> 1, s);
      if (parent != null) return parent;
    }
    if (z > 2) {
      final grandParent = getFromMemory(z - 2, x >> 2, y >> 2, s);
      if (grandParent != null) return grandParent;
    }
    return null;
  }

  Future<Uint8List?> getTileBytes(int z, int x, int y, [MapLayerStyle? style]) {
    final s = style ?? _activeStyle;
    final key = _cacheKey(z, x, y, s);
    final mem = _memoryCache[key];
    if (mem != null) return Future.value(mem);

    return _inFlight.putIfAbsent(key, () async {
      try {
        // 1. Tenta carregar do pacote regional .mbtiles (<0.2ms)
        if (s == MapLayerStyle.standard) {
          try {
            final mbtile = await MBTilesService.instance.getTile(z, x, y);
            if (mbtile != null && mbtile.isNotEmpty) {
              if (_memoryCache.length > 600) {
                _memoryCache.remove(_memoryCache.keys.first);
              }
              _memoryCache[key] = mbtile;
              return mbtile;
            }
          } catch (e, st) {
            AppLogger.warning('Falha ao abrir mapa offline; tentando cache local.', e, st);
          }
        }

        // 2. Tenta carregar do backend padrão (cache local no disco / download online)
        final res = await _backend.getTile(z, x, y, s);
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

  Future<void> saveTile(int z, int x, int y, Uint8List bytes, [MapLayerStyle? style]) {
    final s = style ?? _activeStyle;
    return _backend.saveTile(z, x, y, bytes, s);
  }

  Future<bool> isTileCached(int z, int x, int y, [MapLayerStyle? style]) {
    final s = style ?? _activeStyle;
    return _backend.isTileCached(z, x, y, s);
  }

  Future<int> getCachedTileCount([MapLayerStyle? style]) {
    return _backend.getCachedTileCount(style ?? _activeStyle);
  }

  /// Bloqueado até haver uma fonte que permita explicitamente o pré-download.
  Future<int> preloadArea({
    required int z,
    required int minX,
    required int maxX,
    required int minY,
    required int maxY,
    MapLayerStyle? style,
    void Function(int completed, int total)? onProgress,
  }) async {
    // Os servidores públicos configurados neste aplicativo não oferecem
    // permissão verificada para download preventivo de áreas. Use MBTiles.
    throw UnsupportedError('Pré-download indisponível; importe um pacote MBTiles com licença apropriada.');
  }
}

/// Widget otimizado para renderizar tiles com cache persistente e fallback offline
class CachedTileWidget extends StatefulWidget {
  final int z;
  final int x;
  final int y;
  final double size;
  final bool isDark;
  final MapLayerStyle? layerStyle;

  const CachedTileWidget({
    super.key,
    required this.z,
    required this.x,
    required this.y,
    this.size = 256.0,
    required this.isDark,
    this.layerStyle,
  });

  @override
  State<CachedTileWidget> createState() => _CachedTileWidgetState();
}

class _CachedTileWidgetState extends State<CachedTileWidget> {
  Uint8List? _tileBytes;
  int _requestId = 0;
  late final MBTilesService _mapService;

  MapLayerStyle get _effectiveStyle =>
      widget.layerStyle ?? TileCacheService.instance.activeStyle;

  @override
  void initState() {
    super.initState();
    _mapService = MBTilesService.instance;
    _mapService.tilesRevision.addListener(_onPackagesChanged);
    // Um tile pai inteiro não representa o quadrante do tile atual. É melhor
    // mostrar ausência do mapa do que desenhar ruas fora da posição dos pinos.
    _tileBytes = TileCacheService.getFromMemory(widget.z, widget.x, widget.y, _effectiveStyle);
    if (TileCacheService.getFromMemory(widget.z, widget.x, widget.y, _effectiveStyle) == null) {
      _loadTile();
    }
  }

  void _onPackagesChanged() {
    if (_effectiveStyle != MapLayerStyle.standard) return;
    setState(() => _tileBytes = null);
    _loadTile();
  }

  @override
  void dispose() {
    _mapService.tilesRevision.removeListener(_onPackagesChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(CachedTileWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldStyle = oldWidget.layerStyle ?? TileCacheService.instance.activeStyle;
    final newStyle = _effectiveStyle;
    if (oldWidget.z != widget.z ||
        oldWidget.x != widget.x ||
        oldWidget.y != widget.y ||
        oldStyle != newStyle) {
      ++_requestId; // invalida qualquer resposta anterior mesmo se houver cache exato
      final exact = TileCacheService.getFromMemory(widget.z, widget.x, widget.y, newStyle);
      if (exact != null) {
        _tileBytes = exact;
      } else {
        _tileBytes = null;
        _loadTile();
      }
    }
  }

  Future<void> _loadTile() async {
    final requestId = ++_requestId;
    final style = _effectiveStyle;
    Uint8List? bytes;
    try {
      bytes = await TileCacheService.instance.getTileBytes(
        widget.z, widget.x, widget.y, style,
      );
    } catch (e, st) {
      AppLogger.debug('Falha ao carregar tile.', e, st);
    }
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
        // Não manter a imagem do tile anterior ao trocar de coordenadas.
        gaplessPlayback: false,
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
