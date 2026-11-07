import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'tile_cache_interface.dart';

TileCacheBackend getTileBackend() => TileCacheWeb();

class TileCacheWeb implements TileCacheBackend {
  static final Map<String, Uint8List> _cache = {};
  static const int _blockedTileByteLength = 6725;
  static const String _userAgent =
      'MinisterioPessoal/1.0.1 (https://github.com/eduardoveiga-py/field-assistant; eduardofaturistatuper@gmail.com)';

  bool _isBlockedTile(Uint8List bytes) {
    if (bytes.length == _blockedTileByteLength) return true;
    if (bytes.length < 500) {
      try {
        final text = String.fromCharCodes(bytes);
        if (text.contains('Access blocked') || text.contains('osm.wiki/Blocked')) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<Uint8List?> getTile(int z, int x, int y) async {
    final key = '$z/$x/$y';
    if (_cache.containsKey(key)) {
      final cachedBytes = _cache[key]!;
      if (!_isBlockedTile(cachedBytes)) {
        return cachedBytes;
      }
      _cache.remove(key);
    }

    try {
      // 1ª Tentativa: OpenStreetMap oficial
      final uri = Uri.parse('https://tile.openstreetmap.org/$z/$x/$y.png');
      try {
        final res = await http.get(
          uri,
          headers: {
            'User-Agent': _userAgent,
            'Accept': 'image/png,image/*',
          },
        ).timeout(const Duration(seconds: 5));

        final isOsmBlocked = res.headers.containsKey('x-blocked') ||
            res.bodyBytes.length == _blockedTileByteLength ||
            _isBlockedTile(res.bodyBytes);

        if (res.statusCode == 200 && !isOsmBlocked) {
          _cache[key] = res.bodyBytes;
          return res.bodyBytes;
        }
      } catch (_) {}

      // 2ª Tentativa: Fallback CARTO Voyager
      final cartoUri = Uri.parse(
        'https://basemaps.cartocdn.com/rastertiles/voyager/$z/$x/$y.png',
      );
      final resCarto = await http.get(
        cartoUri,
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'image/png,image/*',
        },
      ).timeout(const Duration(seconds: 6));

      if (resCarto.statusCode == 200 && !_isBlockedTile(resCarto.bodyBytes)) {
        _cache[key] = resCarto.bodyBytes;
        return resCarto.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> saveTile(int z, int x, int y, Uint8List bytes) async {
    if (!_isBlockedTile(bytes)) {
      _cache['$z/$x/$y'] = bytes;
    }
  }

  @override
  Future<bool> isTileCached(int z, int x, int y) async {
    return _cache.containsKey('$z/$x/$y');
  }

  @override
  Future<int> getCachedTileCount() async {
    return _cache.length;
  }
}
