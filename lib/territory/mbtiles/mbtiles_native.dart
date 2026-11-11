import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import '../../core/app_logger.dart';
import 'mbtiles_backend.dart';

MBTilesBackend getMBTilesBackend() => MBTilesNative();

/// Implementação nativa de backend MBTiles baseada em dart:io e SQLite3.
class MBTilesNative implements MBTilesBackend {
  final Directory? _customDir;
  final Map<String, sql.Database> _openDbs = {};
  Directory? _mbtilesDir;
  bool _initialized = false;

  MBTilesNative({this._customDir});

  @override
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      if (_customDir != null) {
        _mbtilesDir = _customDir;
      } else {
        final docs = await getApplicationDocumentsDirectory();
        _mbtilesDir = Directory('${docs.path}/mbtiles');
      }

      if (!await _mbtilesDir!.exists()) {
        await _mbtilesDir!.create(recursive: true);
      }

      final files = _mbtilesDir!.listSync().whereType<File>();
      for (final f in files) {
        if (f.path.endsWith('.mbtiles') && f.lengthSync() > 0) {
          _openMbtilesFile(f.path);
        }
      }
    } catch (e) {
      AppLogger.warning('MBTilesNative init warning: $e');
    }
  }

  String _dbKey(String path) => path.replaceAll('\\', '/');

  void _openMbtilesFile(String path) {
    try {
      final key = _dbKey(path);
      _closeDb(key);
      final db = sql.sqlite3.open(path);
      _openDbs[key] = db;
      AppLogger.info('MBTiles carregado: $path');
    } catch (e) {
      AppLogger.warning('Erro ao abrir .mbtiles ($path): $e');
    }
  }

  void _closeDb(String path) {
    final key = _dbKey(path);
    final db = _openDbs.remove(key);
    if (db != null) {
      try {
        db.close();
        AppLogger.info('Conexão MBTiles fechada: $path');
      } catch (e) {
        AppLogger.warning('Erro ao fechar .mbtiles ($path): $e');
      }
    }
  }

  @override
  bool isRegionInstalled(String regionId) {
    if (_mbtilesDir == null) return false;
    final file = File('${_mbtilesDir!.path}${Platform.pathSeparator}$regionId.mbtiles');
    return file.existsSync() && file.lengthSync() > 0;
  }

  @override
  String getRegionFilePath(String regionId) {
    if (_mbtilesDir == null) {
      throw StateError('MBTilesNative não inicializado. Chame init() primeiro.');
    }
    return '${_mbtilesDir!.path}${Platform.pathSeparator}$regionId.mbtiles';
  }

  @override
  int? getRegionFileSize(String regionId) {
    if (_mbtilesDir == null) return null;
    final file = File('${_mbtilesDir!.path}${Platform.pathSeparator}$regionId.mbtiles');
    if (file.existsSync()) {
      return file.lengthSync();
    }
    return null;
  }

  @override
  Set<String> getInstalledRegionIds() {
    if (_mbtilesDir == null || !_mbtilesDir!.existsSync()) return {};
    final ids = <String>{};
    final files = _mbtilesDir!.listSync().whereType<File>();
    for (final f in files) {
      final name = f.uri.pathSegments.last;
      if (name.endsWith('.mbtiles') && f.lengthSync() > 0) {
        final id = name.substring(0, name.length - '.mbtiles'.length);
        ids.add(id);
      }
    }
    return ids;
  }

  @override
  Future<void> saveRegionStream({
    required String regionId,
    required Stream<List<int>> byteStream,
    int? totalBytes,
    void Function(double progress, int downloadedBytes)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (_mbtilesDir == null) await init();
    final finalPath = getRegionFilePath(regionId);
    final tmpPath = '$finalPath.tmp';
    final tmpFile = File(tmpPath);

    if (tmpFile.existsSync()) {
      try {
        tmpFile.deleteSync();
      } catch (e) {
        AppLogger.warning('Falha ao limpar .tmp residual ($tmpPath): $e');
      }
    }

    final sink = tmpFile.openWrite();
    int downloadedBytes = 0;

    try {
      await for (final chunk in byteStream) {
        if (isCancelled?.call() == true) {
          throw StateError('Download cancelado pelo usuário ($regionId)');
        }
        sink.add(chunk);
        downloadedBytes += chunk.length;
        final progress = (totalBytes != null && totalBytes > 0)
            ? (downloadedBytes / totalBytes).clamp(0.0, 1.0)
            : 0.0;
        onProgress?.call(progress, downloadedBytes);
      }
      if (isCancelled?.call() == true) {
        throw StateError('Download cancelado pelo usuário ($regionId)');
      }
      await sink.flush();
      await sink.close();

      _validateMbtilesFile(tmpFile, regionId);

      // Fecha conexão SQLite anterior caso o pacote esteja sendo atualizado
      _closeDb(finalPath);

      final finalFile = File(finalPath);
      if (finalFile.existsSync()) {
        finalFile.deleteSync();
      }

      // Renomeação atômica
      tmpFile.renameSync(finalPath);

      // Abre imediatamente no backend para disponibilizar tiles em runtime
      _openMbtilesFile(finalPath);
      AppLogger.info('MBTiles instalado com sucesso: $finalPath ($downloadedBytes bytes)');
    } catch (e) {
      try {
        await sink.close();
      } catch (closeErr, closeSt) {
        AppLogger.debug('Falha ao fechar sink temporário MBTiles: $closeErr', closeSt);
      }
      if (tmpFile.existsSync()) {
        try {
          tmpFile.deleteSync();
        } catch (delErr, delSt) {
          AppLogger.debug('Falha ao apagar tmpFile MBTiles ($finalPath.tmp): $delErr', delSt);
        }
      }
      AppLogger.error('Falha ao salvar stream MBTiles ($regionId): $e');
      rethrow;
    }
  }

  void _validateMbtilesFile(File file, String regionId) {
    if (!file.existsSync() || file.lengthSync() < 16) {
      throw FormatException('Pacote MBTiles inválido ou vazio ($regionId)');
    }
    final raf = file.openSync(mode: FileMode.read);
    final List<int> header;
    try {
      header = raf.readSync(16);
    } finally {
      raf.closeSync();
    }
    const sqliteMagic = <int>[
      0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66,
      0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00,
    ];
    if (header.length < 16) {
      throw FormatException('Cabeçalho SQLite ausente no arquivo MBTiles ($regionId)');
    }
    for (int i = 0; i < 16; i++) {
      if (header[i] != sqliteMagic[i]) {
        throw FormatException('Arquivo baixado não é um banco SQLite/MBTiles válido ($regionId)');
      }
    }

    sql.Database? verifyDb;
    try {
      verifyDb = sql.sqlite3.open(file.path, mode: sql.OpenMode.readOnly);
      final tables = verifyDb.select(
        "SELECT name FROM sqlite_master WHERE type IN ('table', 'view') AND name='tiles' LIMIT 1;",
      );
      if (tables.isEmpty) {
        throw FormatException('Pacote MBTiles sem tabela obrigatória "tiles" ($regionId)');
      }
      verifyDb.select(
        'SELECT zoom_level, tile_column, tile_row, tile_data FROM tiles LIMIT 0;',
      );
    } on FormatException {
      rethrow;
    } on sql.SqliteException catch (e) {
      throw FormatException(
        'Estrutura SQLite inválida para pacote MBTiles ($regionId): ${e.message}',
      );
    } finally {
      verifyDb?.close();
    }
  }

  @override
  Future<void> importRegionFile({
    required String regionId,
    required String sourceFilePath,
    void Function(double progress, int copiedBytes)? onProgress,
  }) async {
    if (_mbtilesDir == null) await init();
    final sourceFile = File(sourceFilePath);
    if (!sourceFile.existsSync()) {
      throw FileSystemException(
        'Arquivo .mbtiles selecionado não foi encontrado no dispositivo.',
        sourceFilePath,
      );
    }

    final totalBytes = sourceFile.lengthSync();
    await saveRegionStream(
      regionId: regionId,
      byteStream: sourceFile.openRead(),
      totalBytes: totalBytes > 0 ? totalBytes : null,
      onProgress: onProgress,
    );
  }

  File get _urlConfigFile =>
      File('${_mbtilesDir!.path}${Platform.pathSeparator}mbtiles_config.json');

  @override
  Future<Map<String, dynamic>> loadUrlConfig() async {
    if (_mbtilesDir == null) await init();
    if (_mbtilesDir == null) return const <String, dynamic>{};
    try {
      final file = _urlConfigFile;
      if (!file.existsSync()) return const <String, dynamic>{};
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return const <String, dynamic>{};
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e, st) {
      AppLogger.warning('Falha ao ler configuração de URLs MBTiles: $e', st);
    }
    return const <String, dynamic>{};
  }

  @override
  Future<void> saveUrlConfig(Map<String, dynamic> config) async {
    if (_mbtilesDir == null) await init();
    if (_mbtilesDir == null) return;
    final tmp = File('${_urlConfigFile.path}.tmp');
    tmp.writeAsStringSync(jsonEncode(config), flush: true);
    if (_urlConfigFile.existsSync()) {
      _urlConfigFile.deleteSync();
    }
    tmp.renameSync(_urlConfigFile.path);
  }

  @override
  Future<void> deleteRegion(String regionId) async {
    if (_mbtilesDir == null) await init();
    final finalPath = getRegionFilePath(regionId);
    _closeDb(finalPath);

    final file = File(finalPath);
    if (file.existsSync()) {
      try {
        file.deleteSync();
        AppLogger.info('Arquivo MBTiles excluído do disco: $finalPath');
      } catch (e) {
        AppLogger.error('Erro ao excluir arquivo MBTiles ($finalPath): $e');
        rethrow;
      }
    }

    final tmpFile = File('$finalPath.tmp');
    if (tmpFile.existsSync()) {
      try {
        tmpFile.deleteSync();
      } catch (e, st) {
        AppLogger.debug('Falha ao remover temporário MBTiles (${tmpFile.path}): $e', st);
      }
    }
  }

  @override
  Future<void> reload() async {
    if (_mbtilesDir == null) {
      await init();
      return;
    }

    final currentFiles = _mbtilesDir!
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.mbtiles') && f.lengthSync() > 0)
        .map((f) => _dbKey(f.path))
        .toSet();

    // Fecha conexões para arquivos que deixaram de existir
    final removedPaths = _openDbs.keys.where((p) => !currentFiles.contains(p)).toList();
    for (final p in removedPaths) {
      _closeDb(p);
    }

    // Abre conexões para arquivos novos
    for (final p in currentFiles) {
      if (!_openDbs.containsKey(p)) {
        _openMbtilesFile(p);
      }
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
      } catch (e, st) {
        AppLogger.debug('Falha ao consultar tile ($z/$x/$y) em MBTiles: $e', st);
      }
    }
    return null;
  }

  @override
  void dispose() {
    for (final db in _openDbs.values) {
      try {
        db.close();
      } catch (e, st) {
        AppLogger.debug('Falha ao fechar banco MBTiles em dispose: $e', st);
      }
    }
    _openDbs.clear();
  }
}
