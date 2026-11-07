import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import 'tile_cache_interface.dart';

TileCacheBackend getTileBackend() => TileCacheNative();

class TileCacheNative implements TileCacheBackend {
  Directory? _cacheDir;
  static const int _blockedTileByteLength = 6725;
  static const String _userAgent =
      'MinisterioPessoal/1.0.1 (https://github.com/eduardoveiga-py/field-assistant; eduardofaturistatuper@gmail.com)';

  // Limite de concorrência para downloads online (máx. 4 conexões simultâneas)
  // em total conformidade com a Tile Usage Policy do OpenStreetMap.
  static int _activeDownloads = 0;
  static final List<Completer<void>> _downloadQueue = [];

  static Future<void> _acquireDownloadSlot() async {
    if (_activeDownloads < 4) {
      _activeDownloads++;
      return;
    }
    final c = Completer<void>();
    _downloadQueue.add(c);
    await c.future;
  }

  static void _releaseDownloadSlot() {
    if (_downloadQueue.isNotEmpty) {
      final next = _downloadQueue.removeAt(0);
      next.complete();
    } else {
      _activeDownloads--;
    }
  }

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

  bool _isBlockedTile(Uint8List bytes) {
    // Detecta o tile de bloqueio (403) do OpenStreetMap pelo tamanho ou assinatura
    if (bytes.length == _blockedTileByteLength) return true;
    if (bytes.length >= 5000 && bytes.length <= 8500) {
      final raw = String.fromCharCodes(bytes.take(2048));
      if (raw.contains('Blocked') || raw.contains('policy') || raw.contains('volunteer')) {
        return true;
      }
    }
    if (bytes.length < 1000) {
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
    try {
      final dir = await _getDir();
      final file = _getTileFile(dir, z, x, y);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        // Se o arquivo em cache for o bloco de erro/bloqueio 403, remove e tenta baixar novamente
        if (!_isBlockedTile(bytes)) {
          return bytes;
        }
        try {
          await file.delete();
        } catch (_) {}
      }

      // Do not make live HTTP calls during automated tests
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return null;
      }

      await _acquireDownloadSlot();
      try {
        // 1ª Tentativa: OpenStreetMap oficial com User-Agent plenamente identificado
        final osmUri = Uri.parse('https://basemaps.cartocdn.com/rastertiles/voyager/$z/$x/$y.png');
        try {
          final res = await http
              .get(
                osmUri,
                headers: {
                  'User-Agent': _userAgent,
                  'Accept': 'image/png,image/*',
                },
              )
              .timeout(const Duration(seconds: 5));

          final isOsmBlocked = res.headers.containsKey('x-blocked') ||
              res.bodyBytes.length == _blockedTileByteLength ||
              _isBlockedTile(res.bodyBytes);

          if (res.statusCode == 200 && !isOsmBlocked) {
            await saveTile(z, x, y, res.bodyBytes);
            return res.bodyBytes;
          }
        } catch (_) {
          // Falha transitória de rede; prossegue para fallback
        }

        // 2ª Tentativa (Fallback transparente de alta disponibilidade): CARTO Voyager
        // Garante que o mapa nunca fique com blocos amarelos/pretos ou vazio
        final cartoUri = Uri.parse(
          'https://tile.openstreetmap.org/$z/$x/$y.png',
        );
        final resCarto = await http
            .get(
              cartoUri,
              headers: {
                'User-Agent': _userAgent,
                'Accept': 'image/png,image/*',
              },
            )
            .timeout(const Duration(seconds: 6));

        if (resCarto.statusCode == 200 && !_isBlockedTile(resCarto.bodyBytes)) {
          await saveTile(z, x, y, resCarto.bodyBytes);
          return resCarto.bodyBytes;
        }
      } finally {
        _releaseDownloadSlot();
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
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
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
