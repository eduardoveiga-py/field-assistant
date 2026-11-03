import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'tile_cache_interface.dart';

TileCacheBackend getTileBackend() => TileCacheWeb();

class _WebDownloadTask {
  final int z;
  final int x;
  final int y;
  final String key;
  final Completer<Uint8List?> completer = Completer<Uint8List?>();
  bool cancelled = false;

  _WebDownloadTask({
    required this.z,
    required this.x,
    required this.y,
    required this.key,
  });
}

class TileCacheWeb implements TileCacheBackend, TileCacheCancellable {
  static final Map<String, Uint8List> _cache = {};
  static final Map<String, Future<Uint8List?>> _inFlight = {};
  static final Map<String, DateTime> _failedTiles = {};

  static const int _maxConcurrentDownloads = 6;
  static int _activeDownloads = 0;
  static final List<_WebDownloadTask> _queue = [];
  static final Map<String, _WebDownloadTask> _queuedByKey = {};

  @override
  Future<Uint8List?> getTile(int z, int x, int y) async {
    final key = '$z/$x/$y';
    if (_cache.containsKey(key)) {
      return _cache[key];
    }

    final lastFail = _failedTiles[key];
    if (lastFail != null &&
        DateTime.now().difference(lastFail).inSeconds < 20) {
      return null;
    }

    if (_inFlight.containsKey(key)) {
      return await _inFlight[key];
    }

    final future = _enqueueOrDownload(z, x, y, key);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<Uint8List?> _enqueueOrDownload(int z, int x, int y, String key) {
    if (_activeDownloads < _maxConcurrentDownloads) {
      return _executeDownload(z, x, y, key);
    }

    final task = _WebDownloadTask(z: z, x: x, y: y, key: key);
    _queue.add(task);
    _queuedByKey[key] = task;

    return task.completer.future;
  }

  Future<Uint8List?> _executeDownload(int z, int x, int y, String key) async {
    _activeDownloads++;
    Uint8List? result;
    try {
      final uri = Uri.parse('https://tile.openstreetmap.org/$z/$x/$y.png');
      final res = await http
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
        _cache[key] = res.bodyBytes;
        result = res.bodyBytes;
      } else {
        _failedTiles[key] = DateTime.now();
      }
    } catch (_) {
      _failedTiles[key] = DateTime.now();
    } finally {
      _activeDownloads--;
      _drainQueue();
    }
    return result;
  }

  void _drainQueue() {
    while (_queue.isNotEmpty && _activeDownloads < _maxConcurrentDownloads) {
      final task = _queue.removeAt(0);
      _queuedByKey.remove(task.key);

      if (task.cancelled) {
        continue;
      }

      _executeDownload(task.z, task.x, task.y, task.key)
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
    final toCancel = <_WebDownloadTask>[];
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
