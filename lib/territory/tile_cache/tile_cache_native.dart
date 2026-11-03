import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import 'tile_cache_interface.dart';

TileCacheBackend getTileBackend() => TileCacheNative();

class _DownloadTask {
  final int z;
  final int x;
  final int y;
  final String key;
  final Completer<Uint8List?> completer = Completer<Uint8List?>();
  bool cancelled = false;

  _DownloadTask({
    required this.z,
    required this.x,
    required this.y,
    required this.key,
  });
}

class TileCacheNative implements TileCacheBackend, TileCacheCancellable {
  Directory? _cacheDir;
  final http.Client _client;
  final bool _ownsClient;

  // Concorrência máxima para downloads de tiles (respeita diretrizes de uso do OSM e previne 429)
  static const int _maxConcurrentDownloads = 4;
  int _activeDownloads = 0;
  final List<_DownloadTask> _queue = [];
  final Map<String, _DownloadTask> _queuedByKey = {};

  // Rastreamento de cancelamentos e zoom ativo para descarte imediato
  final Set<String> _cancelledKeys = {};
  int? _activeZoom;

  // Rastreamento de gravações em disco pendentes
  final Set<Future<void>> _pendingWrites = {};

  // Deduplicação de requisições de download ativas
  final Map<String, Future<Uint8List?>> _inFlightDownloads = {};

  // Cache negativo para falhas de rede / 429 com TTL de 20 segundos
  final Map<String, DateTime> _failedTiles = {};

  TileCacheNative({Directory? customDir, http.Client? httpClient})
    : _cacheDir = customDir,
      _client = httpClient ?? http.Client(),
      _ownsClient = httpClient == null;

  void dispose() {
    cancelZoomExcept(-1);
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<void> flushWrites() async {
    if (_pendingWrites.isNotEmpty) {
      await Future.wait(List.from(_pendingWrites));
    }
  }

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
    final key = '$z/$x/$y';

    // Se a requisição já foi cancelada ou pertence a zoom obsoleto, descarta imediatamente
    if (_cancelledKeys.remove(key) ||
        (_activeZoom != null && _activeZoom != -1 && z != _activeZoom)) {
      return null;
    }

    try {
      final dir = await _getDir();
      final file = _getTileFile(dir, z, x, y);
      if (await file.exists()) {
        return await file.readAsBytes();
      }

      // Re-checa cancelamento após I/O assíncrono de verificação de disco
      if (_cancelledKeys.remove(key) ||
          (_activeZoom != null && _activeZoom != -1 && z != _activeZoom)) {
        return null;
      }

      // Do not make live HTTP calls during automated tests when using default live client
      if (_ownsClient && Platform.environment.containsKey('FLUTTER_TEST')) {
        return null;
      }

      // 1. Cache negativo: se falhou recentemente com timeout/erro, não sobrecarrega a rede
      final lastFail = _failedTiles[key];
      if (lastFail != null &&
          DateTime.now().difference(lastFail).inSeconds < 20) {
        return null;
      }

      // 2. Deduplicação em voo: se este bloco já está sendo baixado ou enfileirado
      if (_inFlightDownloads.containsKey(key)) {
        return await _inFlightDownloads[key];
      }

      final future = _enqueueOrDownload(dir, z, x, y, key);
      _inFlightDownloads[key] = future;
      try {
        return await future;
      } finally {
        _inFlightDownloads.remove(key);
      }
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _enqueueOrDownload(
    Directory dir,
    int z,
    int x,
    int y,
    String key,
  ) {
    if (_activeDownloads < _maxConcurrentDownloads) {
      return _executeDownload(dir, z, x, y, key);
    }

    final task = _DownloadTask(z: z, x: x, y: y, key: key);
    _queue.add(task);
    _queuedByKey[key] = task;

    return task.completer.future;
  }

  Future<Uint8List?> _executeDownload(
    Directory dir,
    int z,
    int x,
    int y,
    String key,
  ) async {
    _activeDownloads++;
    Uint8List? result;
    try {
      final uri = Uri.parse('https://tile.openstreetmap.org/$z/$x/$y.png');
      final res = await _client
          .get(
            uri,
            headers: {
              'User-Agent': 'MinisterioPessoalOfflineTerritorio/1.0 (offline territory mapping app)',
              'Accept': 'image/png,image/*;q=0.8',
            },
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        _failedTiles.remove(key);
        result = res.bodyBytes;
        // Salva no disco assincronamente em segundo plano, liberando imediatamente o slot de rede
        _saveTileAsync(dir, z, x, y, res.bodyBytes);
      } else {
        _failedTiles[key] = DateTime.now();
      }
    } catch (_) {
      _failedTiles[key] = DateTime.now();
    } finally {
      _activeDownloads--;
      _drainQueue(dir);
    }
    return result;
  }

  void _saveTileAsync(Directory dir, int z, int x, int y, Uint8List bytes) {
    final file = _getTileFile(dir, z, x, y);
    late final Future<void> writeFuture;
    writeFuture = () async {
      try {
        if (!await file.parent.exists()) {
          await file.parent.create(recursive: true);
        }
        await file.writeAsBytes(bytes);
      } catch (_) {
      } finally {
        _pendingWrites.remove(writeFuture);
      }
    }();
    _pendingWrites.add(writeFuture);
  }

  void _drainQueue(Directory dir) {
    while (_queue.isNotEmpty && _activeDownloads < _maxConcurrentDownloads) {
      final task = _queue.removeAt(0);
      _queuedByKey.remove(task.key);

      if (task.cancelled ||
          (_activeZoom != null && _activeZoom != -1 && task.z != _activeZoom)) {
        if (!task.completer.isCompleted) {
          task.completer.complete(null);
        }
        continue;
      }

      _executeDownload(dir, task.z, task.x, task.y, task.key)
          .then((bytes) {
            if (!task.completer.isCompleted) {
              task.completer.complete(bytes);
            }
          })
          .catchError((_) {
            if (!task.completer.isCompleted) {
              task.completer.complete(null);
            }
          });
    }
  }

  @override
  void cancelTile(int z, int x, int y) {
    final key = '$z/$x/$y';
    _cancelledKeys.add(key);
    final task = _queuedByKey.remove(key);
    if (task != null) {
      task.cancelled = true;
      _queue.remove(task);
      if (!task.completer.isCompleted) {
        task.completer.complete(null);
      }
    }
  }

  @override
  void cancelZoomExcept(int currentZoom) {
    _activeZoom = currentZoom;
    final toCancel = <_DownloadTask>[];
    for (final task in _queue) {
      if (task.z != currentZoom) {
        toCancel.add(task);
      }
    }
    for (final task in toCancel) {
      task.cancelled = true;
      _queue.remove(task);
      _queuedByKey.remove(task.key);
      if (!task.completer.isCompleted) {
        task.completer.complete(null);
      }
    }
  }

  @override
  Future<void> saveTile(int z, int x, int y, Uint8List bytes) async {
    try {
      final dir = await _getDir();
      final file = _getTileFile(dir, z, x, y);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsBytes(bytes);
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
