import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'tile_cache_interface.dart';

TileCacheBackend getTileBackend() => TileCacheNative();

class TileCacheNative implements TileCacheBackend {
  Directory? _cacheDir;

  TileCacheNative({Directory? customDir}) : _cacheDir = customDir;

  Future<Directory> _getDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final baseDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${baseDir.path}/osm_tiles');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  File _getTileFile(Directory dir, int z, int x, int y) {
    return File('${dir.path}/$z/$x/$y.png');
  }

  @override
  Future<Uint8List?> getTile(int z, int x, int y) async {
    try {
      final dir = await _getDir();
      final file = _getTileFile(dir, z, x, y);
      if (await file.exists()) {
        return await file.readAsBytes();
      }

      // Do not make live HTTP calls during automated tests
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return null;
      }

      // Download online if not cached
      final uri = Uri.parse('https://tile.openstreetmap.org/$z/$x/$y.png');
      final res = await http.get(uri, headers: {
        'User-Agent': 'MinisterioPessoalOfflineTerritorio/1.0',
      }).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        await saveTile(z, x, y, res.bodyBytes);
        return res.bodyBytes;
      }
    } catch (_) {
      // Offline or network error
    }
    return null;
  }

  @override
  Future<void> saveTile(int z, int x, int y, Uint8List bytes) async {
    try {
      final dir = await _getDir();
      final file = _getTileFile(dir, z, x, y);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {}
  }

  @override
  Future<bool> isTileCached(int z, int x, int y) async {
    try {
      final dir = await _getDir();
      final file = _getTileFile(dir, z, x, y);
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<int> getCachedTileCount() async {
    try {
      final dir = await _getDir();
      if (!await dir.exists()) return 0;
      int count = 0;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.endsWith('.png')) {
          count++;
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }
}
