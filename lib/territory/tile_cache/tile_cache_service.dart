import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'tile_cache_interface.dart';
import 'tile_cache_web.dart' if (dart.library.io) 'tile_cache_native.dart';

class TileFallbackInfo {
  final Uint8List bytes;
  final int quadrantX; // 0 or 1
  final int quadrantY; // 0 or 1

  const TileFallbackInfo({
    required this.bytes,
    required this.quadrantX,
    required this.quadrantY,
  });
}

class TileCacheService {
  static final TileCacheService instance = TileCacheService._internal();
  TileCacheBackend _backend = getTileBackend();

  // Cache de memória L1 para acesso síncrono e instantâneo a blocos (elimina I/O e flickering)
  static const int _maxMemoryCacheSize = 600;
  final Map<String, Uint8List> _memoryCache = {};
  final List<String> _cacheKeysOrder = [];

  // Deduplicação de requisições concorrentes para o mesmo bloco
  final Map<String, Future<Uint8List?>> _inFlight = {};

  TileCacheService._internal();

  @visibleForTesting
  set backend(TileCacheBackend b) {
    _backend = b;
    clearMemoryCache();
  }

  /// Limpa o cache de memória L1 (usado em testes ou reciclagem de memória)
  void clearMemoryCache() {
    _memoryCache.clear();
    _cacheKeysOrder.clear();
    _inFlight.clear();
  }

  /// Retorna o bloco da memória instantaneamente se já estiver carregado
  Uint8List? getMemoryCachedTile(int z, int x, int y) {
    final key = '$z/$x/$y';
    final bytes = _memoryCache[key];
    if (bytes != null) {
      _touchKey(key);
    }
    return bytes;
  }

  /// Armazena no cache de memória L1 com política LRU
  void putMemoryCache(int z, int x, int y, Uint8List bytes) {
    final key = '$z/$x/$y';
    if (_memoryCache.containsKey(key)) {
      _cacheKeysOrder.remove(key);
    } else if (_cacheKeysOrder.length >= _maxMemoryCacheSize) {
      final oldest = _cacheKeysOrder.removeAt(0);
      _memoryCache.remove(oldest);
    }
    _memoryCache[key] = bytes;
    _cacheKeysOrder.add(key);
  }

  void _touchKey(String key) {
    _cacheKeysOrder.remove(key);
    _cacheKeysOrder.add(key);
  }

  /// Procura bloco ancestral (z - 1) no cache de memória para transições de zoom suaves (overzoom)
  TileFallbackInfo? getFallbackTile(int z, int x, int y) {
    if (z <= 10) return null;
    final parentZ = z - 1;
    final parentX = x >> 1;
    final parentY = y >> 1;
    final parentBytes = getMemoryCachedTile(parentZ, parentX, parentY);
    if (parentBytes != null && parentBytes.isNotEmpty) {
      return TileFallbackInfo(
        bytes: parentBytes,
        quadrantX: x & 1,
        quadrantY: y & 1,
      );
    }
    return null;
  }

  /// Procura bloco ancestral (z - 1) no cache de memória ou no disco se já baixado
  Future<TileFallbackInfo?> getFallbackTileAsync(int z, int x, int y) async {
    final syncFallback = getFallbackTile(z, x, y);
    if (syncFallback != null) return syncFallback;

    if (z <= 10) return null;
    final parentZ = z - 1;
    final parentX = x >> 1;
    final parentY = y >> 1;

    try {
      final isCached = await _backend.isTileCached(parentZ, parentX, parentY);
      if (isCached) {
        final parentBytes = await getTileBytes(parentZ, parentX, parentY);
        if (parentBytes != null && parentBytes.isNotEmpty) {
          return TileFallbackInfo(
            bytes: parentBytes,
            quadrantX: x & 1,
            quadrantY: y & 1,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Cancela requisição pendente de um bloco específico
  void cancelTile(int z, int x, int y) {
    final b = _backend;
    if (b is TileCacheCancellable) {
      (b as TileCacheCancellable).cancelTile(z, x, y);
    }
  }

  /// Cancela todas as requisições pendentes de níveis de zoom diferentes do atual
  void cancelZoomExcept(int currentZoom) {
    final b = _backend;
    if (b is TileCacheCancellable) {
      (b as TileCacheCancellable).cancelZoomExcept(currentZoom);
    }
  }

  Future<Uint8List?> getTileBytes(int z, int x, int y) async {
    final key = '$z/$x/$y';
    final mem = _memoryCache[key];
    if (mem != null) {
      _touchKey(key);
      return mem;
    }

    if (_inFlight.containsKey(key)) {
      return await _inFlight[key];
    }

    final future = _backend.getTile(z, x, y);
    _inFlight[key] = future;
    try {
      final bytes = await future;
      if (bytes != null && bytes.isNotEmpty) {
        putMemoryCache(z, x, y, bytes);
      }
      return bytes;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<void> saveTile(int z, int x, int y, Uint8List bytes) {
    putMemoryCache(z, x, y, bytes);
    return _backend.saveTile(z, x, y, bytes);
  }

  Future<bool> isTileCached(int z, int x, int y) {
    if (_memoryCache.containsKey('$z/$x/$y')) {
      return Future.value(true);
    }
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
    int total = (maxX - minX + 1) * (maxY - minY + 1);
    if (total <= 0) return 0;
    int completed = 0;
    int savedCount = 0;

    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        try {
          final bytes = await getTileBytes(z, x, y);
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

/// Widget otimizado para renderizar tiles com cache de dois níveis (RAM + Disco) e fallback overzoom
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
  TileFallbackInfo? _fallbackInfo;

  @override
  void initState() {
    super.initState();
    _resolveTile();
  }

  @override
  void didUpdateWidget(CachedTileWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.z != widget.z ||
        oldWidget.x != widget.x ||
        oldWidget.y != widget.y) {
      _resolveTile();
    }
  }

  @override
  void dispose() {
    if (_tileBytes == null) {
      TileCacheService.instance.cancelTile(widget.z, widget.x, widget.y);
    }
    super.dispose();
  }

  void _resolveTile() {
    // 1. Resolução síncrona na memória L1 (zero latência, sem piscar e sem microtasks desnecessárias)
    final memCached = TileCacheService.instance.getMemoryCachedTile(
      widget.z,
      widget.x,
      widget.y,
    );
    if (memCached != null && memCached.isNotEmpty) {
      _tileBytes = memCached;
      _fallbackInfo = null;
      return;
    }

    // 2. Busca fallback overzoom ancestral da RAM enquanto o bloco oficial carrega
    _tileBytes = null;
    _fallbackInfo = TileCacheService.instance.getFallbackTile(
      widget.z,
      widget.x,
      widget.y,
    );

    // 3. Carrega de forma assíncrona do disco/rede e tenta fallback ancestral do disco se necessário
    _loadTileAsync();
  }

  Future<void> _loadTileAsync() async {
    // Se ainda não temos fallback overzoom, tenta carregar o bloco pai do disco
    if (_fallbackInfo == null) {
      TileCacheService.instance
          .getFallbackTileAsync(widget.z, widget.x, widget.y)
          .then((info) {
            if (mounted && _tileBytes == null && info != null) {
              setState(() {
                _fallbackInfo = info;
              });
            }
          });
    }

    final bytes = await TileCacheService.instance.getTileBytes(
      widget.z,
      widget.x,
      widget.y,
    );
    if (mounted) {
      setState(() {
        _tileBytes = bytes;
        _fallbackInfo = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: _buildTileContent(),
      ),
    );
  }

  Widget _buildTileContent() {
    if (_tileBytes != null && _tileBytes!.isNotEmpty) {
      return Image.memory(
        _tileBytes!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }

    if (_fallbackInfo != null) {
      // Overzoom bilinear instantâneo do bloco pai anterior
      return ClipRect(
        child: OverflowBox(
          alignment: Alignment(
            _fallbackInfo!.quadrantX == 0 ? -1.0 : 1.0,
            _fallbackInfo!.quadrantY == 0 ? -1.0 : 1.0,
          ),
          minWidth: widget.size * 2,
          minHeight: widget.size * 2,
          maxWidth: widget.size * 2,
          maxHeight: widget.size * 2,
          child: Image.memory(
            _fallbackInfo!.bytes,
            width: widget.size * 2,
            height: widget.size * 2,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
            gaplessPlayback: true,
          ),
        ),
      );
    }

    // Grade cartográfica limpa e suave: substitui o antigo padrão poluído de dezenas de "Mapa Offline" repetidos
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark
            ? const Color(0xFF131D31)
            : const Color(0xFFE2E8F0),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
    );
  }
}
