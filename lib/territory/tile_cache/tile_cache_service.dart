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
  int _cacheGeneration = 0;
  final Map<String, Future<Uint8List?>> _offlineInFlight = {};
  final Map<String, Uint8List> _offlineParents = {};
  MBTilesService? _offlineOwner;
  int _offlineRevision = -1;
  int _offlineBytes = 0;
  static const int _offlineByteLimit = 8 * 1024 * 1024;
  static const int _offlineTileLimit = 256;
  static final Map<String, Uint8List> _memoryCache = {};
  final Map<String, int> _activeConsumers = {};
  final Map<String, int> _directRequests = {};
  final Set<String> _widgetTrackedKeys = {};
  static VoidCallback? _onStaleTileReleased;
  MapLayerStyle _activeStyle = MapLayerStyle.standard;

  TileCacheService._internal();

  MapLayerStyle get activeStyle => _activeStyle;

  static void setStaleQueuePruner(VoidCallback? pruner) {
    _onStaleTileReleased = pruner;
  }

  String registerTileConsumer(int z, int x, int y, [MapLayerStyle? style]) {
    final key = _cacheKey(z, x, y, style ?? _activeStyle);
    _activeConsumers[key] = (_activeConsumers[key] ?? 0) + 1;
    _widgetTrackedKeys.add(key);
    return key;
  }

  void unregisterTileConsumer(String key) {
    final current = _activeConsumers[key];
    if (current == null || current <= 1) {
      _activeConsumers.remove(key);
      if ((_directRequests[key] ?? 0) == 0 &&
          _widgetTrackedKeys.contains(key)) {
        _onStaleTileReleased?.call();
      }
    } else {
      _activeConsumers[key] = current - 1;
    }
  }

  /// Retorna true apenas quando o pedido partiu exclusivamente de widgets
  /// de tile que já foram desmontados (ex.: usuário arrastou para longe).
  /// Chamadas diretas ao backend ou a [getTileBytes] nunca são canceladas.
  bool isTileRequestStale(int z, int x, int y, [MapLayerStyle? style]) {
    final key = _cacheKey(z, x, y, style ?? _activeStyle);
    if ((_directRequests[key] ?? 0) > 0) return false;
    if (!_widgetTrackedKeys.contains(key)) return false;
    return (_activeConsumers[key] ?? 0) == 0;
  }

  void setLayerStyle(MapLayerStyle style) {
    if (_activeStyle != style) {
      _activeStyle = style;
      _cacheGeneration++;
      _memoryCache.clear();
      _inFlight.clear();
      _widgetTrackedKeys.clear();
      _onStaleTileReleased?.call();
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
    _cacheGeneration++;
    _inFlight.clear();
    _memoryCache.clear();
    _widgetTrackedKeys.clear();
    _onStaleTileReleased?.call();
  }

  static String _cacheKey(int z, int x, int y, MapLayerStyle style) {
    final version = style == MapLayerStyle.standard
        ? MBTilesService.instance.tilesRevision.value
        : 0;
    return '${style.id}/$version/$z/$x/$y';
  }

  static Uint8List? getFromMemory(int z, int x, int y, [MapLayerStyle? style]) {
    final s = style ?? instance.activeStyle;
    final key = _cacheKey(z, x, y, s);
    final mem = _memoryCache.remove(key);
    if (mem != null) {
      _memoryCache[key] = mem; // LRU: preserva os tiles mais recentes
      return mem;
    }
    return null;
  }

  /// Retorna bytes do ancestral apenas para consumidores que recortem o
  /// quadrante correto; não serve para exibir diretamente como tile filho.
  static Uint8List? getFallbackFromMemory(
    int z,
    int x,
    int y, [
    MapLayerStyle? style,
  ]) {
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

  /// Compartilha leituras de ancestrais entre tiles filhos, sem fazer rede.
  /// A revisão invalida o cache e respostas antigas não entram no cache novo.
  Future<Uint8List?> getOfflineTileBytes(int z, int x, int y) {
    final owner = MBTilesService.instance;
    final revision = owner.tilesRevision.value;
    if (!identical(owner, _offlineOwner) || revision != _offlineRevision) {
      _offlineOwner = owner;
      _offlineRevision = revision;
      _offlineParents.clear();
      _offlineInFlight.clear();
      _offlineBytes = 0;
    }
    final key = '$z/$x/$y';
    final cached = _offlineParents.remove(key);
    if (cached != null) {
      _offlineParents[key] =
          cached; // LRU: prioriza os tiles usados recentemente.
      return Future.value(cached);
    }
    final existing = _offlineInFlight[key];
    if (existing != null) return existing;
    late final Future<Uint8List?> future;
    future = (() async {
      try {
        final bytes = await Future<Uint8List?>.sync(
          () => owner.getTile(z, x, y),
        );
        if (bytes != null &&
            bytes.isNotEmpty &&
            bytes.length <= _offlineByteLimit &&
            identical(owner, _offlineOwner) &&
            revision == _offlineRevision &&
            owner.tilesRevision.value == revision) {
          while (_offlineParents.isNotEmpty &&
              (_offlineParents.length >= _offlineTileLimit ||
                  _offlineBytes + bytes.length > _offlineByteLimit)) {
            _offlineBytes -= _offlineParents
                .remove(_offlineParents.keys.first)!
                .length;
          }
          _offlineParents[key] = bytes;
          _offlineBytes += bytes.length;
        }
        return bytes;
      } finally {
        if (identical(_offlineInFlight[key], future)) {
          _offlineInFlight.remove(key);
        }
      }
    })();
    _offlineInFlight[key] = future;
    return future;
  }

  Future<Uint8List?> getTileBytes(
    int z,
    int x,
    int y, [
    MapLayerStyle? style,
    bool fromWidget = false,
  ]) {
    final s = style ?? _activeStyle;
    final key = _cacheKey(z, x, y, s);
    final mem = _memoryCache.remove(key);
    if (mem != null) {
      _memoryCache[key] = mem; // LRU: mantém tiles ativos no topo do cache
      return Future.value(mem);
    }

    if (!fromWidget) {
      _directRequests[key] = (_directRequests[key] ?? 0) + 1;
    }

    final existing = _inFlight[key];
    if (existing != null) {
      if (fromWidget) return existing;
      return existing.whenComplete(() {
        final rem = (_directRequests[key] ?? 1) - 1;
        if (rem <= 0) {
          _directRequests.remove(key);
        } else {
          _directRequests[key] = rem;
        }
      });
    }

    final generation = _cacheGeneration;
    final backend = _backend;
    late final Future<Uint8List?> request;
    request = (() async {
      // Deixa a referência do Future ser registrada antes de qualquer retorno.
      await Future<void>.value();
      try {
        // 1. Tenta carregar do pacote regional .mbtiles
        if (s == MapLayerStyle.standard) {
          try {
            final mbtile = await MBTilesService.instance.getTile(z, x, y);
            if (mbtile != null && mbtile.isNotEmpty) {
              if (_cacheGeneration == generation) {
                if (_memoryCache.length >= 600) {
                  _memoryCache.remove(_memoryCache.keys.first);
                }
                _memoryCache[key] = mbtile;
              }
              return mbtile;
            }
          } catch (e, st) {
            AppLogger.warning(
              'Falha ao abrir mapa offline; tentando cache local.',
              e,
              st,
            );
          }
        }

        // 2. Cache em disco / rede. Resultados antigos não alimentam cache novo.
        final res = await backend.getTile(z, x, y, s);
        if (res != null && res.isNotEmpty && _cacheGeneration == generation) {
          if (_memoryCache.length >= 600) {
            _memoryCache.remove(_memoryCache.keys.first);
          }
          _memoryCache[key] = res;
        }
        return res;
      } finally {
        if (!fromWidget) {
          final rem = (_directRequests[key] ?? 1) - 1;
          if (rem <= 0) {
            _directRequests.remove(key);
          } else {
            _directRequests[key] = rem;
          }
        }
        if (identical(_inFlight[key], request)) _inFlight.remove(key);
        if ((_activeConsumers[key] ?? 0) == 0) {
          _widgetTrackedKeys.remove(key);
        }
      }
    })();
    _inFlight[key] = request;
    return request;
  }

  Future<void> saveTile(
    int z,
    int x,
    int y,
    Uint8List bytes, [
    MapLayerStyle? style,
  ]) {
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
    throw UnsupportedError(
      'Pré-download indisponível; importe um pacote MBTiles com licença apropriada.',
    );
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
  int _parentLevels = 0;
  bool _loading = true;
  int _requestId = 0;
  late final MBTilesService _mapService;
  String? _registeredConsumerKey;

  MapLayerStyle get _effectiveStyle =>
      widget.layerStyle ?? TileCacheService.instance.activeStyle;

  void _releaseConsumer() {
    final key = _registeredConsumerKey;
    if (key != null) {
      _registeredConsumerKey = null;
      TileCacheService.instance.unregisterTileConsumer(key);
    }
  }

  void _acquireConsumer(MapLayerStyle style) {
    _releaseConsumer();
    _registeredConsumerKey = TileCacheService.instance.registerTileConsumer(
      widget.z,
      widget.x,
      widget.y,
      style,
    );
  }

  @override
  void initState() {
    super.initState();
    _mapService = MBTilesService.instance;
    _mapService.tilesRevision.addListener(_onPackagesChanged);
    // Um tile pai inteiro não representa o quadrante do tile atual. É melhor
    // mostrar ausência do mapa do que desenhar ruas fora da posição dos pinos.
    _tileBytes = TileCacheService.getFromMemory(
      widget.z,
      widget.x,
      widget.y,
      _effectiveStyle,
    );
    if (_tileBytes == null) {
      _loadTile();
    } else {
      _loading = false;
    }
  }

  void _onPackagesChanged() {
    if (_effectiveStyle != MapLayerStyle.standard) return;
    setState(() {
      _tileBytes = null;
      _parentLevels = 0;
      _loading = true;
    });
    _loadTile();
  }

  @override
  void dispose() {
    _releaseConsumer();
    _mapService.tilesRevision.removeListener(_onPackagesChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(CachedTileWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldStyle =
        oldWidget.layerStyle ?? TileCacheService.instance.activeStyle;
    final newStyle = _effectiveStyle;
    if (oldWidget.z != widget.z ||
        oldWidget.x != widget.x ||
        oldWidget.y != widget.y ||
        oldStyle != newStyle) {
      ++_requestId; // invalida qualquer resposta anterior mesmo se houver cache exato
      _releaseConsumer();
      final exact = TileCacheService.getFromMemory(
        widget.z,
        widget.x,
        widget.y,
        newStyle,
      );
      _parentLevels = 0;
      if (exact != null) {
        _tileBytes = exact;
        _loading = false;
      } else {
        _tileBytes = null;
        _loading = true;
        _loadTile();
      }
    }
  }

  Future<void> _loadTile() async {
    final requestId = ++_requestId;
    final style = _effectiveStyle;
    _acquireConsumer(style);
    Uint8List? bytes;
    try {
      // Zooms acima da resolução nativa do pacote usam um recorte do ancestral,
      // nunca a imagem inteira: ruas e pinos continuam na posição correta.
      if (style == MapLayerStyle.standard && widget.z > 16) {
        for (var levels = 1; levels <= 3 && widget.z - levels >= 0; levels++) {
          try {
            final parent = await TileCacheService.instance.getOfflineTileBytes(
              widget.z - levels,
              widget.x >> levels,
              widget.y >> levels,
            );
            if (!mounted || requestId != _requestId) return;
            if (parent != null && parent.isNotEmpty) {
              setState(() {
                _tileBytes = parent;
                _parentLevels = levels;
              });
              break;
            }
          } catch (e, st) {
            AppLogger.debug(
              'Falha ao consultar tile ancestral offline.',
              e,
              st,
            );
            break;
          }
        }
      }
      try {
        bytes = await TileCacheService.instance.getTileBytes(
          widget.z,
          widget.x,
          widget.y,
          style,
          true,
        );
      } catch (e, st) {
        AppLogger.debug('Falha ao carregar tile.', e, st);
      }
      if (mounted && requestId == _requestId) {
        setState(() {
          _loading = false;
          if (bytes != null && bytes.isNotEmpty) {
            _tileBytes = bytes;
            _parentLevels = 0;
          }
        });
      }
    } finally {
      if (requestId == _requestId) {
        _releaseConsumer();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tileBytes != null && _tileBytes!.isNotEmpty) {
      if (_parentLevels > 0) {
        final factor = 1 << _parentLevels;
        final offsetX = widget.x % factor;
        final offsetY = widget.y % factor;
        return ClipRect(
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: widget.size * factor,
              maxWidth: widget.size * factor,
              minHeight: widget.size * factor,
              maxHeight: widget.size * factor,
              child: Transform.translate(
                offset: Offset(-offsetX * widget.size, -offsetY * widget.size),
                child: Image.memory(
                  _tileBytes!,
                  width: widget.size * factor,
                  height: widget.size * factor,
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ),
        );
      }
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
              _loading ? 'Carregando mapa…' : 'Sem mapa nesta área ou zoom',
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
