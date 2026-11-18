import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import '../../core/app_logger.dart';
import '../map_engine/pmtiles_reader.dart';
import '../map_engine_adapter.dart';
import 'mbtiles_backend.dart';

MBTilesBackend getMBTilesBackend() => MBTilesNative();

/// Implementação nativa de backend MBTiles baseada em dart:io e SQLite3.
class MBTilesNative implements MBTilesBackend {
  final Directory? customDir;
  final Map<String, sql.Database> _openDbs = {};
  Directory? _mbtilesDir;
  bool _initialized = false;
  Future<void>? _initializing;
  final Set<String> _xyzDatabases = {};
  _TileReader? _reader;

  MBTilesNative({this.customDir});

  @override
  Future<void> init() {
    if (_initialized) return Future.value();
    return _initializing ??= _initialize().whenComplete(() {
      _initializing = null;
    });
  }

  Future<void> _initialize() async {
    if (customDir != null) {
      _mbtilesDir = customDir;
    } else {
      final docs = await getApplicationDocumentsDirectory();
      _mbtilesDir = Directory('${docs.path}/mbtiles');
    }
    if (!await _mbtilesDir!.exists()) {
      await _mbtilesDir!.create(recursive: true);
    }
    // Recupera o pacote anterior se o processo terminou durante a troca.
    final files = _mbtilesDir!.listSync().whereType<File>().toList();
    for (final backup in files.where((f) => f.path.endsWith('.mbtiles.bak'))) {
      final originalPath = backup.path.substring(0, backup.path.length - 4);
      final original = File(originalPath);
      if (!original.existsSync()) {
        backup.renameSync(originalPath);
      } else {
        // Se houve interrupção após a troca, manter o anterior até verificar
        // o novo; se inválido, preservar também o arquivo suspeito.
        var valid = false;
        try {
          _validateMbtilesFile(original, originalPath);
          valid = true;
        } catch (e, st) {
          AppLogger.warning('Pacote substituto inválido: $originalPath', e, st);
        }
        if (valid) {
          try {
            backup.deleteSync();
          } catch (e, st) {
            AppLogger.warning(
              'Não foi possível remover backup do mapa.',
              e,
              st,
            );
          }
        } else {
          final damaged =
              '$originalPath.invalid.${DateTime.now().microsecondsSinceEpoch}';
          original.renameSync(damaged);
          try {
            backup.renameSync(originalPath);
          } catch (_) {
            if (!original.existsSync()) File(damaged).renameSync(originalPath);
            rethrow;
          }
        }
      }
    }
    for (final f in _mbtilesDir!.listSync().whereType<File>()) {
      if (f.path.endsWith('.mbtiles') && f.lengthSync() > 0) {
        _openMbtilesFile(f.path);
      }
    }
    _initialized = true;
  }

  String _dbKey(String path) => path.replaceAll('\\', '/');

  void _openMbtilesFile(String path) {
    try {
      final key = _dbKey(path);
      _closeDb(key);
      final db = sql.sqlite3.open(path, mode: sql.OpenMode.readOnly);
      _openDbs[key] = db;
      try {
        final result = db.select(
          "SELECT value FROM metadata WHERE name = 'scheme' LIMIT 1",
        );
        if (result.isNotEmpty &&
            result.first['value']?.toString().toLowerCase() == 'xyz') {
          _xyzDatabases.add(key);
        }
      } on sql.SqliteException {
        // MBTiles sem metadata de scheme usa o padrão TMS.
      }
      AppLogger.info('MBTiles carregado: $path');
    } catch (e) {
      AppLogger.warning('Erro ao abrir .mbtiles ($path): $e');
    }
  }

  void _closeDb(String path) {
    final key = _dbKey(path);
    final db = _openDbs.remove(key);
    _xyzDatabases.remove(key);
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
    final mbtilesFile = File(
      '${_mbtilesDir!.path}${Platform.pathSeparator}$regionId.mbtiles',
    );
    if (mbtilesFile.existsSync() && mbtilesFile.lengthSync() > 0) return true;
    final pmtilesFile = File(
      '${_mbtilesDir!.path}${Platform.pathSeparator}$regionId.pmtiles',
    );
    return pmtilesFile.existsSync() && pmtilesFile.lengthSync() > 0;
  }

  @override
  String getRegionFilePath(String regionId) {
    if (_mbtilesDir == null) {
      throw StateError(
        'MBTilesNative não inicializado. Chame init() primeiro.',
      );
    }
    return '${_mbtilesDir!.path}${Platform.pathSeparator}$regionId.mbtiles';
  }

  String _getPmtilesFilePath(String regionId) {
    if (_mbtilesDir == null) {
      throw StateError(
        'MBTilesNative não inicializado. Chame init() primeiro.',
      );
    }
    return '${_mbtilesDir!.path}${Platform.pathSeparator}$regionId.pmtiles';
  }

  @override
  String? getPackagesDirectoryPath() => _mbtilesDir?.path;

  bool _isVectorMbtilesFile(File file) {
    sql.Database? db;
    try {
      db = sql.sqlite3.open(file.path, mode: sql.OpenMode.readOnly);
      try {
        final meta = db.select(
          "SELECT value FROM metadata WHERE name = 'format' LIMIT 1",
        );
        if (meta.isNotEmpty) {
          final fmt = meta.first['value']?.toString().toLowerCase() ?? '';
          if (fmt == 'pbf' || fmt == 'mvt' || fmt.contains('vector')) {
            return true;
          }
          if (fmt == 'png' || fmt == 'jpg' || fmt == 'jpeg' || fmt == 'webp') {
            return false;
          }
        }
      } on sql.SqliteException {
        // Sem tabela metadata: inspeciona amostra de tile.
      }
      final samples = db.select('SELECT tile_data FROM tiles LIMIT 1');
      if (samples.isEmpty || samples.first['tile_data'] is! Uint8List) {
        return false;
      }
      final bytes = samples.first['tile_data'] as Uint8List;
      final isPng =
          bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4e &&
          bytes[3] == 0x47;
      final isJpeg =
          bytes.length >= 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff;
      final isWebp =
          bytes.length >= 12 &&
          ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
          ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP';
      return !isPng && !isJpeg && !isWebp;
    } catch (_) {
      return false;
    } finally {
      db?.close();
    }
  }

  @override
  List<InstalledOfflineMapPackage> getInstalledPackages() {
    if (_mbtilesDir == null || !_mbtilesDir!.existsSync()) {
      return const [];
    }
    final packages = <InstalledOfflineMapPackage>[];
    final files = _mbtilesDir!.listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in files) {
      final size = f.lengthSync();
      if (size <= 0) continue;
      final name = f.uri.pathSegments.last;
      if (name.endsWith('.pmtiles')) {
        final id = name.substring(0, name.length - '.pmtiles'.length);
        packages.add(
          InstalledOfflineMapPackage(
            id: id,
            format: OfflineMapFormat.pmtiles,
            isVector: true,
            filePath: f.path,
            sizeBytes: size,
          ),
        );
      } else if (name.endsWith('.mbtiles')) {
        final id = name.substring(0, name.length - '.mbtiles'.length);
        packages.add(
          InstalledOfflineMapPackage(
            id: id,
            format: OfflineMapFormat.mbtiles,
            isVector: _isVectorMbtilesFile(f),
            filePath: f.path,
            sizeBytes: size,
          ),
        );
      }
    }
    return packages;
  }

  @override
  int? getRegionFileSize(String regionId) {
    if (_mbtilesDir == null) return null;
    final pmtilesFile = File(
      '${_mbtilesDir!.path}${Platform.pathSeparator}$regionId.pmtiles',
    );
    if (pmtilesFile.existsSync() && pmtilesFile.lengthSync() > 0) {
      return pmtilesFile.lengthSync();
    }
    final file = File(
      '${_mbtilesDir!.path}${Platform.pathSeparator}$regionId.mbtiles',
    );
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
      } else if (name.endsWith('.pmtiles') && f.lengthSync() > 0) {
        final id = name.substring(0, name.length - '.pmtiles'.length);
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

      // Mantém o pacote anterior até o novo ter sido instalado. Se houver uma
      // interrupção na troca, init restaura o backup caso o destino esteja ausente.
      _closeDb(finalPath);
      final finalFile = File(finalPath);
      final backup = File('$finalPath.bak');
      if (backup.existsSync()) {
        _openMbtilesFile(finalPath);
        throw FileSystemException(
          'Backup de mapa pendente; resolva antes de atualizar.',
          backup.path,
        );
      }
      final hadOld = finalFile.existsSync();
      try {
        if (hadOld) finalFile.renameSync(backup.path);
        tmpFile.renameSync(finalPath);
      } catch (_) {
        if (hadOld && backup.existsSync() && !finalFile.existsSync()) {
          backup.renameSync(finalPath);
        }
        if (finalFile.existsSync()) _openMbtilesFile(finalPath);
        rethrow;
      }
      _openMbtilesFile(finalPath);
      if (backup.existsSync()) {
        try {
          backup.deleteSync();
        } catch (_) {
          /* preserva backup se não puder removê-lo */
        }
      }
      AppLogger.info(
        'MBTiles instalado com sucesso: $finalPath ($downloadedBytes bytes)',
      );
    } catch (e) {
      try {
        await sink.close();
      } catch (closeErr, closeSt) {
        AppLogger.debug(
          'Falha ao fechar sink temporário MBTiles: $closeErr',
          closeSt,
        );
      }
      if (tmpFile.existsSync()) {
        try {
          tmpFile.deleteSync();
        } catch (delErr, delSt) {
          AppLogger.debug(
            'Falha ao apagar tmpFile MBTiles ($finalPath.tmp): $delErr',
            delSt,
          );
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
      0x53,
      0x51,
      0x4c,
      0x69,
      0x74,
      0x65,
      0x20,
      0x66,
      0x6f,
      0x72,
      0x6d,
      0x61,
      0x74,
      0x20,
      0x33,
      0x00,
    ];
    if (header.length < 16) {
      throw FormatException(
        'Cabeçalho SQLite ausente no arquivo MBTiles ($regionId)',
      );
    }
    for (int i = 0; i < 16; i++) {
      if (header[i] != sqliteMagic[i]) {
        throw FormatException(
          'Arquivo baixado não é um banco SQLite/MBTiles válido ($regionId)',
        );
      }
    }

    sql.Database? verifyDb;
    try {
      verifyDb = sql.sqlite3.open(file.path, mode: sql.OpenMode.readOnly);
      final tables = verifyDb.select(
        "SELECT name FROM sqlite_master WHERE type IN ('table', 'view') AND name='tiles' LIMIT 1;",
      );
      if (tables.isEmpty) {
        throw FormatException(
          'Pacote MBTiles sem tabela obrigatória "tiles" ($regionId)',
        );
      }
      verifyDb.select(
        'SELECT zoom_level, tile_column, tile_row, tile_data FROM tiles LIMIT 0;',
      );
      final samples = verifyDb.select('SELECT tile_data FROM tiles LIMIT 1');
      if (samples.isEmpty || samples.first['tile_data'] is! Uint8List) {
        throw FormatException('Pacote MBTiles sem dados de tile ($regionId)');
      }
      final bytes = samples.first['tile_data'] as Uint8List;
      final isPng =
          bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4e &&
          bytes[3] == 0x47 &&
          bytes[4] == 0x0d &&
          bytes[5] == 0x0a &&
          bytes[6] == 0x1a &&
          bytes[7] == 0x0a;
      final isJpeg =
          bytes.length >= 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff;
      final isWebp =
          bytes.length >= 12 &&
          ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
          ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP';
      // MVT / PBF (vetorial) comumente comprimido com gzip (0x1f, 0x8b), zlib (0x78) ou protobuf não comprimido
      final isGzipVector =
          bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
      final isZlibVector =
          bytes.length >= 2 &&
          bytes[0] == 0x78 &&
          (bytes[1] == 0x9c || bytes[1] == 0x01 || bytes[1] == 0xda);
      final isRawMvt =
          bytes.isNotEmpty &&
          (bytes[0] == 0x1a || bytes[0] == 0x28 || bytes[0] == 0x0a);
      final isVector = isGzipVector || isZlibVector || isRawMvt;

      if (!isPng && !isJpeg && !isWebp && !isVector) {
        throw FormatException(
          'Pacote não contém tiles raster (PNG/JPEG/WebP) ou vetoriais (MVT/PBF) compatíveis ($regionId)',
        );
      }
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

  @override
  Future<void> importPmtilesFile({
    required String regionId,
    required String sourceFilePath,
    void Function(double progress, int copiedBytes)? onProgress,
  }) async {
    if (_mbtilesDir == null) await init();
    final sourceFile = File(sourceFilePath);
    if (!sourceFile.existsSync()) {
      throw FileSystemException(
        'Arquivo .pmtiles selecionado não foi encontrado no dispositivo.',
        sourceFilePath,
      );
    }

    // Valida cabeçalho oficial PMTiles v3 antes de instalar no diretório gerenciado.
    final reader = PmtilesReader(sourceFile);
    await reader.getHeader();

    final finalPath = _getPmtilesFilePath(regionId);
    final tmpPath = '$finalPath.tmp';
    final tmpFile = File(tmpPath);
    if (tmpFile.existsSync()) {
      tmpFile.deleteSync();
    }

    final totalBytes = sourceFile.lengthSync();
    int copied = 0;
    final sink = tmpFile.openWrite();
    try {
      await for (final chunk in sourceFile.openRead()) {
        sink.add(chunk);
        copied += chunk.length;
        final progress = totalBytes > 0
            ? (copied / totalBytes).clamp(0.0, 1.0)
            : 0.0;
        onProgress?.call(progress, copied);
      }
      await sink.flush();
      await sink.close();

      // Revalida o arquivo gravado antes da substituição atômica.
      await PmtilesReader(tmpFile).getHeader();

      final finalFile = File(finalPath);
      if (finalFile.existsSync()) {
        finalFile.deleteSync();
      }
      tmpFile.renameSync(finalPath);
      AppLogger.info(
        'PMTiles vetorial instalado com sucesso: $finalPath ($copied bytes)',
      );
    } catch (e) {
      try {
        await sink.close();
      } catch (_) {}
      if (tmpFile.existsSync()) {
        try {
          tmpFile.deleteSync();
        } catch (_) {}
      }
      rethrow;
    }
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

    final pmtilesPath = _getPmtilesFilePath(regionId);
    final pmtilesFile = File(pmtilesPath);
    if (pmtilesFile.existsSync()) {
      try {
        pmtilesFile.deleteSync();
        AppLogger.info('Arquivo PMTiles excluído do disco: $pmtilesPath');
      } catch (e) {
        AppLogger.error('Erro ao excluir arquivo PMTiles ($pmtilesPath): $e');
        rethrow;
      }
    }

    final tmpFile = File('$finalPath.tmp');
    if (tmpFile.existsSync()) {
      try {
        tmpFile.deleteSync();
      } catch (e, st) {
        AppLogger.debug(
          'Falha ao remover temporário MBTiles (${tmpFile.path}): $e',
          st,
        );
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
    final removedPaths = _openDbs.keys
        .where((p) => !currentFiles.contains(p))
        .toList();
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
    await init();
    if (z < 0 || z > 30) return null;
    final width = 1 << z;
    if (x < 0 || y < 0 || x >= width || y >= width) return null;
    if (_openDbs.isEmpty) return null;
    // SQLite and file I/O run on a long-lived worker, not Flutter's UI isolate.
    // Each lookup opens read-only and closes its handles, so package replacement
    // and deletion do not leave a long-lived worker handle to an old file.
    final reader = (_reader == null || _reader!.isClosed)
        ? (_reader = _TileReader())
        : _reader!;
    try {
      final paths = _openDbs.keys
          .map((path) => [path, _xyzDatabases.contains(path)])
          .toList();
      return await reader.getTile(paths, z, x, y);
    } catch (e, st) {
      AppLogger.debug('Falha ao consultar tile offline ($z/$x/$y): $e', st);
      return null;
    }
  }

  @override
  void dispose() {
    _reader?.dispose();
    _reader = null;
    for (final db in _openDbs.values) {
      try {
        db.close();
      } catch (e, st) {
        AppLogger.debug('Falha ao fechar banco MBTiles em dispose: $e', st);
      }
    }
    _openDbs.clear();
    _xyzDatabases.clear();
    _initialized = false;
  }
}

/// Serial SQLite lookups on a background isolate. Never shares SQLite handles
/// across isolates and returns independent byte buffers.
class _TileReader {
  final ReceivePort _responses = ReceivePort();
  final ReceivePort _errors = ReceivePort();
  final ReceivePort _exits = ReceivePort();
  final Completer<SendPort> _ready = Completer<SendPort>();
  final Map<int, Completer<Uint8List?>> _pending = {};
  Isolate? _isolate;
  bool isClosed = false;
  int _nextId = 0;

  _TileReader() {
    _responses.listen((message) {
      if (message is SendPort) {
        if (!_ready.isCompleted) _ready.complete(message);
      } else if (message is List && message.length == 2 && message[0] is int) {
        final completer = _pending.remove(message[0]);
        if (completer != null && !completer.isCompleted) {
          completer.complete(message[1] as Uint8List?);
        }
      }
    });
    _errors.listen((_) => dispose());
    _exits.listen((_) => dispose());
    Isolate.spawn(
          _tileReaderMain,
          _responses.sendPort,
          onError: _errors.sendPort,
          onExit: _exits.sendPort,
        )
        .then((isolate) {
          if (isClosed) {
            isolate.kill(priority: Isolate.immediate);
          } else {
            _isolate = isolate;
          }
        })
        .catchError((Object _) => dispose());
  }

  Future<Uint8List?> getTile(
    List<List<Object>> paths,
    int z,
    int x,
    int y,
  ) async {
    final port = await _ready.future.timeout(const Duration(seconds: 10));
    if (isClosed) return null;
    final id = _nextId++;
    final result = Completer<Uint8List?>();
    _pending[id] = result;
    port.send([id, paths, z, x, y]);
    try {
      return await result.future.timeout(const Duration(seconds: 10));
    } finally {
      _pending.remove(id);
    }
  }

  void dispose() {
    if (isClosed) return;
    isClosed = true;
    if (!_ready.isCompleted) {
      _ready.completeError(StateError('Leitor de mapas encerrado.'));
    }
    for (final c in _pending.values) {
      if (!c.isCompleted) c.complete(null);
    }
    _pending.clear();
    _isolate?.kill(priority: Isolate.immediate);
    _responses.close();
    _errors.close();
    _exits.close();
  }
}

void _tileReaderMain(SendPort reply) {
  final requests = ReceivePort();
  reply.send(requests.sendPort);
  requests.listen((message) {
    if (message is! List || message.length != 5) return;
    final id = message[0] as int;
    final paths = message[1] as List;
    final z = message[2] as int;
    final x = message[3] as int;
    final y = message[4] as int;
    Uint8List? tile;
    for (final item in paths) {
      sql.Database? db;
      try {
        final path = item[0] as String;
        final xyz = item[1] as bool;
        db = sql.sqlite3.open(path, mode: sql.OpenMode.readOnly);
        final row = xyz ? y : (1 << z) - 1 - y;
        final result = db.select(
          'SELECT tile_data FROM tiles WHERE zoom_level = ? AND tile_column = ? AND tile_row = ? LIMIT 1;',
          [z, x, row],
        );
        if (result.isNotEmpty && result.first['tile_data'] is List<int>) {
          tile = Uint8List.fromList(result.first['tile_data'] as List<int>);
          break;
        }
      } catch (_) {
        // Try another installed package; the UI receives a missing-tile result.
      } finally {
        db?.close();
      }
    }
    reply.send([id, tile]);
  });
}
