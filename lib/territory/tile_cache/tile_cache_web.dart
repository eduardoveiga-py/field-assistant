import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/app_logger.dart';
import '../../core/app_version.dart';
import 'tile_cache_service.dart';

TileCacheBackend getTileBackend() => TileCacheWeb();

class TileCacheWeb implements TileCacheBackend {
  static final Map<String, Uint8List> _cache = {};
  static const int _blockedTileByteLength = 6725;
  static const String _userAgent = AppVersion.userAgent;

  /// Limite máximo de azulejos na memória para prevenir estouro de RAM no navegador
  static const int maxCacheEntries = 500;

  final http.Client? httpClient;

  TileCacheWeb({this.httpClient});

  static void _put(String key, Uint8List bytes) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = bytes;
  }

  bool _isBlockedTile(Uint8List bytes) {
    if (bytes.isEmpty) return true;
    // Detecta tiles com marca d'água de erro da CARTO (2049 bytes claro, 2513 bytes escuro)
    if (bytes.length == 2049 || bytes.length == 2513) return true;
    if (bytes.length == _blockedTileByteLength) return true;
    if (bytes.length < 500) {
      try {
        final text = String.fromCharCodes(bytes);
        if (text.contains('Access blocked') || text.contains('osm.wiki/Blocked')) {
          return true;
        }
      } catch (e, st) {
        AppLogger.debug('Falha ao inspecionar bytes de tile Web: $e', st);
      }
    }
    return false;
  }

  @visibleForTesting
  bool isBlockedTile(Uint8List bytes) => _isBlockedTile(bytes);

  @override
  Future<Uint8List?> getTile(int z, int x, int y, [MapLayerStyle? style]) async {
    final s = style ?? TileCacheService.instance.activeStyle;
    final key = '${s.id}/$z/$x/$y';
    final legacyKey = '$z/$x/$y';

    if (_cache.containsKey(key)) {
      final cachedBytes = _cache.remove(key)!;
      if (!_isBlockedTile(cachedBytes)) {
        _cache[key] = cachedBytes;
        return cachedBytes;
      }
    } else if (s == MapLayerStyle.standard && _cache.containsKey(legacyKey)) {
      final cachedBytes = _cache.remove(legacyKey)!;
      if (!_isBlockedTile(cachedBytes)) {
        _cache[key] = cachedBytes;
        return cachedBytes;
      }
    }

    final client = httpClient ?? http.Client();
    final shouldCloseClient = httpClient == null;

    try {
      // 1ª Tentativa: Provedor de azulejos oficial com estilo selecionado
      final uri = Uri.parse(TileCacheService.instance.getTileUrl(z, x, y, s));
      try {
        final res = await client.get(
          uri,
          headers: {
            'User-Agent': _userAgent,
            'Accept': 'image/png,image/*',
          },
        ).timeout(const Duration(seconds: 5));

        final etag = res.headers['etag']?.toLowerCase() ?? '';
        final isWatermarked = etag.contains('wm-') ||
            res.bodyBytes.length == 2049 ||
            res.bodyBytes.length == 2513;

        final isOsmBlocked = res.headers.containsKey('x-blocked') ||
            isWatermarked ||
            res.bodyBytes.length == _blockedTileByteLength ||
            _isBlockedTile(res.bodyBytes);

        if (res.statusCode == 200 && !isOsmBlocked) {
          _put(key, res.bodyBytes);
          return res.bodyBytes;
        }
      } catch (e, st) {
        AppLogger.debug('Falha ao buscar tile primário Web ($z/$x/$y): $e', st);
      }

      // 2ª Tentativa: Fallback OSM France (alta disponibilidade)
      final fallbackUri = Uri.parse(
        'https://a.tile.openstreetmap.fr/osmfr/$z/$x/$y.png',
      );
      try {
        final resFallback = await client.get(
          fallbackUri,
          headers: {
            'User-Agent': _userAgent,
            'Accept': 'image/png,image/*',
          },
        ).timeout(const Duration(seconds: 6));

        final fallbackEtag = resFallback.headers['etag']?.toLowerCase() ?? '';
        final isFallbackWatermarked = fallbackEtag.contains('wm-') ||
            resFallback.bodyBytes.length == 2049 ||
            resFallback.bodyBytes.length == 2513;

        final isFallbackBlocked = resFallback.headers.containsKey('x-blocked') ||
            isFallbackWatermarked ||
            resFallback.bodyBytes.length == _blockedTileByteLength ||
            _isBlockedTile(resFallback.bodyBytes);

        if (resFallback.statusCode == 200 && !isFallbackBlocked) {
          _put(key, resFallback.bodyBytes);
          return resFallback.bodyBytes;
        }
      } catch (e, st) {
        AppLogger.debug('Falha no fallback OSM France Web ($z/$x/$y): $e', st);
      }
    } catch (e, st) {
      AppLogger.warning('Erro inesperado ao obter tile Web ($z/$x/$y)', e, st);
    } finally {
      if (shouldCloseClient) {
        client.close();
      }
    }
    return null;
  }

  @override
  Future<void> saveTile(int z, int x, int y, Uint8List bytes, [MapLayerStyle? style]) async {
    final s = style ?? TileCacheService.instance.activeStyle;
    final key = '${s.id}/$z/$x/$y';
    if (_isBlockedTile(bytes)) {
      _cache.remove(key);
      return;
    }
    _put(key, bytes);
  }

  @override
  Future<bool> isTileCached(int z, int x, int y, [MapLayerStyle? style]) async {
    final s = style ?? TileCacheService.instance.activeStyle;
    final key = '${s.id}/$z/$x/$y';
    final legacyKey = '$z/$x/$y';
    final bytes = _cache[key] ?? (s == MapLayerStyle.standard ? _cache[legacyKey] : null);
    if (bytes == null || _isBlockedTile(bytes)) {
      _cache.remove(key);
      if (s == MapLayerStyle.standard) _cache.remove(legacyKey);
      return false;
    }
    return true;
  }

  @override
  Future<int> getCachedTileCount([MapLayerStyle? style]) async {
    _cache.removeWhere((_, bytes) => _isBlockedTile(bytes));
    if (style != null) {
      return _cache.keys.where((k) => k.startsWith('${style.id}/')).length;
    }
    return _cache.length;
  }

  @visibleForTesting
  static void clearCache() {
    _cache.clear();
  }
}
