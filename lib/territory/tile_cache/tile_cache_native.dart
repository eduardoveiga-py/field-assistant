import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import '../../core/app_version.dart';
import 'tile_cache_interface.dart';

TileCacheBackend getTileBackend() => TileCacheNative();

class TileCacheNative implements TileCacheBackend {
  Directory? _cacheDir;
  final http.Client? httpClient;
  static const int _blockedTileByteLength = 6725;
  static const String _userAgent = AppVersion.userAgent;

  // Limite de concorrência para downloads online (máx. 2 conexões simultâneas)
  // em total conformidade com a Tile Usage Policy do OpenStreetMap.
  static int _activeDownloads = 0;
  static final List<Completer<void>> _downloadQueue = [];

  @visibleForTesting
  static int get activeDownloads => _activeDownloads;

  @visibleForTesting
  static void resetQueue() {
    _activeDownloads = 0;
    _downloadQueue.clear();
  }

  static Future<void> _acquireDownloadSlot() async {
    if (_activeDownloads < 2) {
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
    } else if (_activeDownloads > 0) {
      _activeDownloads--;
    }
  }

  TileCacheNative({Directory? customDir, this.httpClient})
      : _cacheDir = customDir;

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
    if (bytes.isEmpty) return true;

    // Detecta tiles com marca d'água de erro da CARTO (2049 bytes claro, 2513 bytes escuro)
    if (bytes.length == 2049 || bytes.length == 2513) return true;

    // Detecta o tile de bloqueio (403) do OpenStreetMap pelo tamanho ou assinatura
    if (bytes.length == _blockedTileByteLength) return true;
    if (bytes.length >= 5000 && bytes.length <= 8500) {
      final raw = String.fromCharCodes(bytes.take(2048));
      if (raw.contains('Blocked') ||
          raw.contains('policy') ||
          raw.contains('volunteer')) {
        return true;
      }
    }
    if (bytes.length < 1000) {
      try {
        final text = String.fromCharCodes(bytes);
        if (text.contains('Access blocked') ||
            text.contains('osm.wiki/Blocked')) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  @visibleForTesting
  bool isBlockedTile(Uint8List bytes) => _isBlockedTile(bytes);

  @override
  Future<Uint8List?> getTile(int z, int x, int y) async {
    try {
      final dir = await _getDir();
      final file = _getTileFile(dir, z, x, y);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        // Se o arquivo em cache for o bloco de erro/bloqueio 403 ou marca d'água CARTO,
        // remove do armazenamento e tenta baixar novamente uma versão limpa
        if (!_isBlockedTile(bytes)) {
          return bytes;
        }
        try {
          await file.delete();
        } catch (_) {}
      }

      // Do not make live HTTP calls during automated tests unless a custom client is provided
      if (httpClient == null && Platform.environment.containsKey('FLUTTER_TEST')) {
        return null;
      }

      await _acquireDownloadSlot();
      final client = httpClient ?? http.Client();
      final shouldCloseClient = httpClient == null;
      try {
        // 1ª Tentativa: OpenStreetMap oficial com User-Agent plenamente identificado
        final osmUri = Uri.parse('https://tile.openstreetmap.org/$z/$x/$y.png');
        try {
          final res = await client
              .get(
                osmUri,
                headers: {
                  'User-Agent': _userAgent,
                  'Accept': 'image/png,image/*',
                },
              )
              .timeout(const Duration(seconds: 5));

          final etag = res.headers['etag']?.toLowerCase() ?? '';
          final isWatermarked = etag.contains('wm-') ||
              res.bodyBytes.length == 2049 ||
              res.bodyBytes.length == 2513;

          final isOsmBlocked = res.headers.containsKey('x-blocked') ||
              isWatermarked ||
              res.bodyBytes.length == _blockedTileByteLength ||
              _isBlockedTile(res.bodyBytes);

          if (res.statusCode == 200 && !isOsmBlocked) {
            await saveTile(z, x, y, res.bodyBytes);
            return res.bodyBytes;
          }
        } catch (_) {
          // Falha transitória de rede; prossegue para fallback
        }

        // 2ª Tentativa (Fallback transparente de alta disponibilidade): OSM France
        // Garante que o mapa nunca fique com blocos vazios ou indisponíveis
        final fallbackUri = Uri.parse(
          'https://a.tile.openstreetmap.fr/osmfr/$z/$x/$y.png',
        );
        try {
          final resFallback = await client
              .get(
                fallbackUri,
                headers: {
                  'User-Agent': _userAgent,
                  'Accept': 'image/png,image/*',
                },
              )
              .timeout(const Duration(seconds: 6));

          final fallbackEtag = resFallback.headers['etag']?.toLowerCase() ?? '';
          final isFallbackWatermarked = fallbackEtag.contains('wm-') ||
              resFallback.bodyBytes.length == 2049 ||
              resFallback.bodyBytes.length == 2513;

          final isFallbackBlocked = resFallback.headers.containsKey('x-blocked') ||
              isFallbackWatermarked ||
              resFallback.bodyBytes.length == _blockedTileByteLength ||
              _isBlockedTile(resFallback.bodyBytes);

          if (resFallback.statusCode == 200 && !isFallbackBlocked) {
            await saveTile(z, x, y, resFallback.bodyBytes);
            return resFallback.bodyBytes;
          }
        } catch (_) {
          // Falha de rede no fallback
        }
      } finally {
        if (shouldCloseClient) {
          client.close();
        }
        _releaseDownloadSlot();
      }
    } catch (_) {
      // Offline or network error
    }
    return null;
  }

  @override
  Future<void> saveTile(int z, int x, int y, Uint8List bytes) async {
    // Rejeita salvar arquivos vazios, com bloqueio ou com marca d'água de erro (2049 / 2513 bytes)
    if (_isBlockedTile(bytes)) {
      try {
        final dir = await _getDir();
        final file = _getTileFile(dir, z, x, y);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
      return;
    }
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
      if (await file.exists()) {
        final len = await file.length();
        if (len == 0 ||
            len == 2049 ||
            len == 2513 ||
            len == _blockedTileByteLength) {
          try {
            await file.delete();
          } catch (_) {}
          return false;
        }
        return true;
      }
      return false;
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
          final len = await entity.length();
          if (len == 0 ||
              len == 2049 ||
              len == 2513 ||
              len == _blockedTileByteLength) {
            try {
              await entity.delete();
            } catch (_) {}
          } else {
            count++;
          }
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }
}
