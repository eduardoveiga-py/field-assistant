import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import '../../core/app_logger.dart';
import 'mbtiles_backend.dart';

MBTilesBackend getMBTilesBackend() => MBTilesNative();

class MBTilesNative implements MBTilesBackend {
  final Map<String, sql.Database> _openDbs = {};
  Directory? _mbtilesDir;
  bool _initialized = false;

  @override
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final docs = await getApplicationDocumentsDirectory();
      _mbtilesDir = Directory('${docs.path}/mbtiles');

      if (!await _mbtilesDir!.exists()) {
        await _mbtilesDir!.create(recursive: true);
      }

      final files = _mbtilesDir!.listSync().whereType<File>();
      for (final f in files) {
        if (f.path.endsWith('.mbtiles')) {
          _openMbtilesFile(f.path);
        }
      }
    } catch (e) {
      AppLogger.warning('MBTilesNative init warning: $e');
    }
  }

  void _openMbtilesFile(String path) {
    try {
      final db = sql.sqlite3.open(path);
      _openDbs[path] = db;
      AppLogger.info('MBTiles carregado: $path');
    } catch (e) {
      AppLogger.warning('Erro ao abrir .mbtiles ($path): $e');
    }
  }

  @override
  Future<Uint8List?> getTile(int z, int x, int y) async {
    if (_openDbs.isEmpty) return null;

    final tmsY = (1 << z) - 1 - y;

    for (final db in _openDbs.values) {
      try {
        final result = db.select(
          'SELECT tile_data FROM tiles WHERE zoom_level = ? AND tile_column = ? AND tile_row = ? LIMIT 1;',
          [z, x, tmsY],
        );
        if (result.isNotEmpty && result.first['tile_data'] != null) {
          final data = result.first['tile_data'];
          if (data is Uint8List) return data;
          if (data is List<int>) return Uint8List.fromList(data);
        }

        final fallbackResult = db.select(
          'SELECT tile_data FROM tiles WHERE zoom_level = ? AND tile_column = ? AND tile_row = ? LIMIT 1;',
          [z, x, y],
        );
        if (fallbackResult.isNotEmpty && fallbackResult.first['tile_data'] != null) {
          final data = fallbackResult.first['tile_data'];
          if (data is Uint8List) return data;
          if (data is List<int>) return Uint8List.fromList(data);
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  void dispose() {
    for (final db in _openDbs.values) {
      try {
        db.close();
      } catch (_) {}
    }
    _openDbs.clear();
  }
}
