import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'tile_cache_interface.dart';
import 'tile_cache_web.dart'
    if (dart.library.io) 'tile_cache_native.dart';

class TileCacheService {
  static final TileCacheService instance = TileCacheService._internal();
  TileCacheBackend _backend = getTileBackend();

  TileCacheService._internal();

  @visibleForTesting
  set backend(TileCacheBackend b) {
    _backend = b;
  }

  Future<Uint8List?> getTileBytes(int z, int x, int y) {
    return _backend.getTile(z, x, y);
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
    int total = (maxX - minX + 1) * (maxY - minY + 1);
    if (total <= 0) return 0;
    int completed = 0;
    int savedCount = 0;

    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
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

  @override
  void initState() {
    super.initState();
    _loadTile();
  }

  @override
  void didUpdateWidget(CachedTileWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.z != widget.z || oldWidget.x != widget.x || oldWidget.y != widget.y) {
      _loadTile();
    }
  }

  Future<void> _loadTile() async {
    final bytes = await TileCacheService.instance.getTileBytes(widget.z, widget.x, widget.y);
    if (mounted) {
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
        color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
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
              'Mapa Offline',
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
