import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'tile_cache_interface.dart';

TileCacheBackend getTileBackend() => TileCacheWeb();

class TileCacheWeb implements TileCacheBackend {
  static final Map<String, Uint8List> _cache = {};

  @override
  Future<Uint8List?> getTile(int z, int x, int y) async {
    final key = '$z/$x/$y';
    if (_cache.containsKey(key)) {
      return _cache[key];
    }

    try {
      final uri = Uri.parse('https://tile.openstreetmap.org/$z/$x/$y.png');
      final res = await http.get(uri, headers: {
        'User-Agent': 'MinisterioPessoalOfflineTerritorio/1.0',
      }).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        _cache[key] = res.bodyBytes;
        return res.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> saveTile(int z, int x, int y, Uint8List bytes) async {
    _cache['$z/$x/$y'] = bytes;
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
