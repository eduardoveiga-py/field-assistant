import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:sqlite3/sqlite3.dart' as sql;

import '../../core/app_logger.dart';
import 'pmtiles_reader.dart';

/// Callback para busca de tile raster ou vetorial por coordenadas z, x, y.
typedef TileLookup = Future<Uint8List?> Function(int z, int x, int y);

/// Servidor HTTP local embutido (loopback 127.0.0.1) baseado em Shelf (RFC 7233 / RFC 9110)
/// para servir pacotes vetoriais e raster PMTiles e MBTiles nativamente para MapLibre Native
/// ou motores de mapa desacoplados (FA-MAP-01/02).
class OfflineTileServer {
  HttpServer? _server;
  int? _port;
  TileLookup? tileLookup;
  final Map<String, File> _pmtilesPackages = {};
  final Map<String, File> _mbtilesPackages = {};
  final Map<String, PmtilesReader> _pmtilesReaders = {};
  Directory? packagesDir;
  bool _disposed = false;

  OfflineTileServer({this.tileLookup, this.packagesDir});

  /// Indica se o servidor HTTP está ativo e escutando conexões.
  bool get isRunning => _server != null && !_disposed;

  /// Porta TCP atribuída pelo sistema operacional na interface loopback.
  int? get port => _port;

  /// URL base para requisições no loopback IPv4.
  String? get baseUrl => _port != null ? 'http://127.0.0.1:$_port' : null;

  /// Registra ou atualiza o provedor de tiles padrão (fallback).
  void setTileLookup(TileLookup lookup) {
    tileLookup = lookup;
  }

  /// Define o diretório físico onde pacotes .pmtiles e .mbtiles residem.
  void setPackagesDirectory(Directory dir) {
    packagesDir = dir;
  }

  /// Registra explicitamente um arquivo PMTiles mapeado a um identificador seguro.
  void registerPmtilesPackage(String packageId, File file) {
    _validateSafeId(packageId);
    _pmtilesPackages[packageId] = file;
    _pmtilesReaders[packageId] = PmtilesReader(file);
  }

  /// Remove registro explícito de um pacote PMTiles.
  void unregisterPmtilesPackage(String packageId) {
    _pmtilesPackages.remove(packageId);
    _pmtilesReaders.remove(packageId);
  }

  /// Registra explicitamente um arquivo MBTiles mapeado a um identificador seguro.
  void registerMbtilesPackage(String packageId, File file) {
    _validateSafeId(packageId);
    _mbtilesPackages[packageId] = file;
  }

  /// Remove registro explícito de um pacote MBTiles.
  void unregisterMbtilesPackage(String packageId) {
    _mbtilesPackages.remove(packageId);
  }

  /// Inicializa e vincula o servidor na interface loopback local (`127.0.0.1`)
  /// em porta efêmera (0) para evitar conflitos de porta.
  Future<int> start({int desiredPort = 0}) async {
    if (isRunning) return _port!;
    _disposed = false;

    // Configura o pipeline Shelf com middleware de CORS e segurança
    final handler = const shelf.Pipeline()
        .addMiddleware(_corsAndSecurityMiddleware())
        .addHandler(_routerHandler);

    final server = await shelf_io.serve(
      handler,
      InternetAddress.loopbackIPv4,
      desiredPort,
      shared: false,
    );

    _server = server;
    _port = server.port;

    AppLogger.info(
      'OfflineTileServer (Shelf) iniciado em http://127.0.0.1:$_port',
    );
    return _port!;
  }

  /// Encerra a execução do servidor HTTP local.
  Future<void> stop({bool force = false}) async {
    _disposed = true;
    final server = _server;
    _server = null;
    _port = null;
    _pmtilesReaders.clear();
    if (server != null) {
      await server.close(force: force);
      AppLogger.info('OfflineTileServer finalizado.');
    }
  }

  /// Middleware Shelf para CORS universal e segurança de interface loopback.
  static shelf.Middleware _corsAndSecurityMiddleware() {
    return (shelf.Handler innerHandler) {
      return (shelf.Request request) async {
        // Regra de segurança: apenas conexões da interface loopback são aceitas.
        final connectionInfo =
            request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
        final remote = connectionInfo?.remoteAddress;
        if (remote != null && !remote.isLoopback) {
          return shelf.Response.forbidden(
            'Acesso restrito à interface loopback.',
          );
        }

        final corsHeaders = {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
          'Access-Control-Allow-Headers': 'Range, Content-Type, Accept',
          'Access-Control-Expose-Headers':
              'Content-Range, Content-Length, Accept-Ranges',
        };

        if (request.method == 'OPTIONS') {
          return shelf.Response(HttpStatus.noContent, headers: corsHeaders);
        }

        if (request.method != 'GET' && request.method != 'HEAD') {
          return shelf.Response(
            HttpStatus.methodNotAllowed,
            headers: corsHeaders,
          );
        }

        final response = await innerHandler(request);
        return response.change(headers: corsHeaders);
      };
    };
  }

  /// Roteamento central de requisições Shelf.
  Future<shelf.Response> _routerHandler(shelf.Request request) async {
    // Normaliza os segmentos do caminho URL
    final segments = request.url.pathSegments;
    final path = '/${segments.join('/')}';

    try {
      if (path == '/status' || path == '/health') {
        return _handleStatus();
      }

      // Rota PMTiles:
      // 1) /pmtiles/:regionId/:z/:x/:y (.pbf opcional) -> tile vetorial extraído
      // 2) /pmtiles/:regionId -> range request RFC 7233
      if (segments.isNotEmpty && segments[0] == 'pmtiles') {
        if (segments.length == 5) {
          return await _handlePmtilesTileRequest(
            regionId: segments[1],
            zStr: segments[2],
            xStr: segments[3],
            yStr: segments[4],
          );
        } else if (segments.length == 2) {
          return await _handlePmtilesRangeRequest(request, segments[1]);
        }
        return shelf.Response(HttpStatus.badRequest);
      }

      // Rota MBTiles:
      // /mbtiles/:regionId/:z/:x/:y (.pbf opcional) -> tile vetorial ou raster do SQLite
      if (segments.isNotEmpty && segments[0] == 'mbtiles') {
        if (segments.length == 5) {
          return await _handleMbtilesTileRequest(
            regionId: segments[1],
            zStr: segments[2],
            xStr: segments[3],
            yStr: segments[4],
          );
        }
        return shelf.Response(HttpStatus.badRequest);
      }

      // Rota Tiles legado / compatibilidade:
      // 1) /tiles/:z/:x/:y
      // 2) /tiles/mbtiles/:z/:x/:y
      if (segments.isNotEmpty && segments[0] == 'tiles') {
        return await _handleLegacyTileRequest(segments);
      }

      return shelf.Response.notFound('Recurso não encontrado');
    } catch (e, st) {
      AppLogger.warning(
        'Erro ao processar requisição no OfflineTileServer: $path',
        e,
        st,
      );
      return shelf.Response.internalServerError(body: 'Erro interno');
    }
  }

  shelf.Response _handleStatus() {
    final body = jsonEncode({
      'status': 'ok',
      'port': _port,
      'registeredPmtiles': _pmtilesPackages.keys.toList(),
      'registeredMbtiles': _mbtilesPackages.keys.toList(),
      'hasTileLookup': tileLookup != null,
      'hasPackagesDir': packagesDir != null,
    });
    return shelf.Response.ok(
      body,
      headers: {HttpHeaders.contentTypeHeader: 'application/json'},
    );
  }

  /// Trata rota `/tiles/{format?}/{z}/{x}/{y}`
  Future<shelf.Response> _handleLegacyTileRequest(List<String> segments) async {
    int? z, x, y;
    if (segments.length == 4 && segments[0] == 'tiles') {
      z = int.tryParse(segments[1]);
      x = int.tryParse(segments[2]);
      y = int.tryParse(_stripExtension(segments[3]));
    } else if (segments.length == 5 && segments[0] == 'tiles') {
      z = int.tryParse(segments[2]);
      x = int.tryParse(segments[3]);
      y = int.tryParse(_stripExtension(segments[4]));
    }

    if (z == null || x == null || y == null) {
      return shelf.Response(HttpStatus.badRequest);
    }

    final lookup = tileLookup;
    if (lookup == null) {
      return shelf.Response(HttpStatus.serviceUnavailable);
    }

    final tileBytes = await lookup(z, x, y);
    if (tileBytes == null || tileBytes.isEmpty) {
      return shelf.Response.notFound('Tile não encontrado');
    }

    final headers = _detectContentTypeHeaders(tileBytes);
    headers[HttpHeaders.contentLengthHeader] = tileBytes.length.toString();
    return shelf.Response.ok(tileBytes, headers: headers);
  }

  /// Trata requisições PMTiles com Range Requests: `/pmtiles/{packageId}`
  Future<shelf.Response> _handlePmtilesRangeRequest(
    shelf.Request request,
    String rawId,
  ) async {
    final packageId = _stripPmtilesExtension(rawId);
    if (!_safeIdPattern.hasMatch(packageId)) {
      return shelf.Response(HttpStatus.badRequest);
    }

    File? file = _pmtilesPackages[packageId];
    if (file == null || !file.existsSync()) {
      if (packagesDir != null) {
        final candidate = File('${packagesDir!.path}/$packageId.pmtiles');
        if (candidate.existsSync()) {
          file = candidate;
        }
      }
    }

    if (file == null || !file.existsSync()) {
      return shelf.Response.notFound('Pacote PMTiles não encontrado');
    }

    final fileLength = file.lengthSync();
    final baseHeaders = {
      HttpHeaders.acceptRangesHeader: 'bytes',
      HttpHeaders.contentTypeHeader: 'application/vnd.pmtiles',
    };

    final rangeHeader = request.headers[HttpHeaders.rangeHeader];
    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      return _serveByteRange(file, fileLength, rangeHeader, baseHeaders);
    }

    // Requisição completa (200 OK)
    baseHeaders[HttpHeaders.contentLengthHeader] = fileLength.toString();
    return shelf.Response.ok(file.openRead(), headers: baseHeaders);
  }

  /// Trata requisições de tile vetorial direto de PMTiles: `/pmtiles/:regionId/:z/:x/:y.pbf`
  Future<shelf.Response> _handlePmtilesTileRequest({
    required String regionId,
    required String zStr,
    required String xStr,
    required String yStr,
  }) async {
    final cleanRegion = _stripPmtilesExtension(regionId);
    if (!_safeIdPattern.hasMatch(cleanRegion)) {
      return shelf.Response(HttpStatus.badRequest);
    }

    final z = int.tryParse(zStr);
    final x = int.tryParse(xStr);
    final y = int.tryParse(_stripExtension(yStr));
    if (z == null || x == null || y == null) {
      return shelf.Response(HttpStatus.badRequest);
    }

    var reader = _pmtilesReaders[cleanRegion];
    if (reader == null) {
      File? file = _pmtilesPackages[cleanRegion];
      if (file == null || !file.existsSync()) {
        if (packagesDir != null) {
          final candidate = File('${packagesDir!.path}/$cleanRegion.pmtiles');
          if (candidate.existsSync()) {
            file = candidate;
          }
        }
      }
      if (file != null && file.existsSync()) {
        reader = PmtilesReader(file);
        _pmtilesReaders[cleanRegion] = reader;
      }
    }

    Uint8List? tileBytes;
    if (reader != null) {
      tileBytes = await reader.getTile(z, x, y);
    }
    if ((tileBytes == null || tileBytes.isEmpty) && tileLookup != null) {
      tileBytes = await tileLookup!(z, x, y);
    }

    if (tileBytes == null || tileBytes.isEmpty) {
      return shelf.Response.notFound('Tile não encontrado no pacote PMTiles');
    }

    final headers = _detectContentTypeHeaders(tileBytes);
    headers[HttpHeaders.contentLengthHeader] = tileBytes.length.toString();
    return shelf.Response.ok(tileBytes, headers: headers);
  }

  /// Trata requisições de tile de MBTiles vetorial/raster: `/mbtiles/:regionId/:z/:x/:y.pbf`
  Future<shelf.Response> _handleMbtilesTileRequest({
    required String regionId,
    required String zStr,
    required String xStr,
    required String yStr,
  }) async {
    final cleanRegion = _stripMbtilesExtension(regionId);
    if (!_safeIdPattern.hasMatch(cleanRegion)) {
      return shelf.Response(HttpStatus.badRequest);
    }

    final z = int.tryParse(zStr);
    final x = int.tryParse(xStr);
    final y = int.tryParse(_stripExtension(yStr));
    if (z == null || x == null || y == null) {
      return shelf.Response(HttpStatus.badRequest);
    }

    File? file = _mbtilesPackages[cleanRegion];
    if (file == null || !file.existsSync()) {
      if (packagesDir != null) {
        final candidate = File('${packagesDir!.path}/$cleanRegion.mbtiles');
        if (candidate.existsSync()) {
          file = candidate;
        }
      }
    }

    Uint8List? tileBytes;

    if (file != null && file.existsSync()) {
      sql.Database? db;
      try {
        db = sql.sqlite3.open(file.path, mode: sql.OpenMode.readOnly);
        final tmsY = (1 << z) - 1 - y;
        final stmt = db.prepare(
          'SELECT tile_data FROM tiles WHERE zoom_level = ? AND tile_column = ? AND (tile_row = ? OR tile_row = ?) LIMIT 1;',
        );
        final result = stmt.select([z, x, tmsY, y]);
        stmt.close();
        if (result.isNotEmpty && result.first['tile_data'] is Uint8List) {
          tileBytes = result.first['tile_data'] as Uint8List;
        }
      } catch (e, st) {
        AppLogger.warning('Erro ao ler MBTiles ${file.path}', e, st);
      } finally {
        db?.close();
      }
    }
    if ((tileBytes == null || tileBytes.isEmpty) && tileLookup != null) {
      tileBytes = await tileLookup!(z, x, y);
    }

    if (tileBytes == null || tileBytes.isEmpty) {
      return shelf.Response.notFound('Tile não encontrado no MBTiles');
    }

    final headers = _detectContentTypeHeaders(tileBytes);
    headers[HttpHeaders.contentLengthHeader] = tileBytes.length.toString();
    return shelf.Response.ok(tileBytes, headers: headers);
  }

  /// Processa e serve um range de bytes conforme especificação HTTP 206 (RFC 9110).
  shelf.Response _serveByteRange(
    File file,
    int fileLength,
    String rangeHeader,
    Map<String, String> baseHeaders,
  ) {
    final spec = rangeHeader.substring(6).trim(); // Remove "bytes="
    final dashIndex = spec.indexOf('-');
    if (dashIndex == -1) {
      return _rejectRange(fileLength, baseHeaders);
    }

    final startStr = spec.substring(0, dashIndex).trim();
    final endStr = spec.substring(dashIndex + 1).trim();

    int start;
    int end;

    if (startStr.isEmpty && endStr.isNotEmpty) {
      final suffixLen = int.tryParse(endStr);
      if (suffixLen == null || suffixLen <= 0) {
        return _rejectRange(fileLength, baseHeaders);
      }
      start = fileLength - suffixLen;
      if (start < 0) start = 0;
      end = fileLength - 1;
    } else if (startStr.isNotEmpty && endStr.isEmpty) {
      final parsedStart = int.tryParse(startStr);
      if (parsedStart == null || parsedStart < 0 || parsedStart >= fileLength) {
        return _rejectRange(fileLength, baseHeaders);
      }
      start = parsedStart;
      end = fileLength - 1;
    } else if (startStr.isNotEmpty && endStr.isNotEmpty) {
      final parsedStart = int.tryParse(startStr);
      final parsedEnd = int.tryParse(endStr);
      if (parsedStart == null ||
          parsedEnd == null ||
          parsedStart < 0 ||
          parsedStart > parsedEnd ||
          parsedStart >= fileLength) {
        return _rejectRange(fileLength, baseHeaders);
      }
      start = parsedStart;
      end = parsedEnd >= fileLength ? fileLength - 1 : parsedEnd;
    } else {
      return _rejectRange(fileLength, baseHeaders);
    }

    final chunkLength = end - start + 1;
    final headers = Map<String, String>.from(baseHeaders);
    headers[HttpHeaders.contentRangeHeader] = 'bytes $start-$end/$fileLength';
    headers[HttpHeaders.contentLengthHeader] = chunkLength.toString();

    final stream = file.openRead(start, end + 1);
    return shelf.Response(
      HttpStatus.partialContent,
      body: stream,
      headers: headers,
    );
  }

  shelf.Response _rejectRange(int fileLength, Map<String, String> baseHeaders) {
    final headers = Map<String, String>.from(baseHeaders);
    headers[HttpHeaders.contentRangeHeader] = 'bytes */$fileLength';
    return shelf.Response(
      HttpStatus.requestedRangeNotSatisfiable,
      headers: headers,
    );
  }

  Map<String, String> _detectContentTypeHeaders(Uint8List bytes) {
    final headers = <String, String>{};
    if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
      // GZIP (Vector Tiles PBF)
      headers[HttpHeaders.contentTypeHeader] = 'application/x-protobuf';
      headers[HttpHeaders.contentEncodingHeader] = 'gzip';
    } else if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      // PNG
      headers[HttpHeaders.contentTypeHeader] = 'image/png';
    } else if (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xd8) {
      // JPEG
      headers[HttpHeaders.contentTypeHeader] = 'image/jpeg';
    } else if (bytes.length >= 12 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      // WebP
      headers[HttpHeaders.contentTypeHeader] = 'image/webp';
    } else {
      headers[HttpHeaders.contentTypeHeader] = 'application/x-protobuf';
    }
    return headers;
  }

  static final RegExp _safeIdPattern = RegExp(
    r'^[a-zA-Z0-9][a-zA-Z0-9_\-]{0,63}$',
  );

  void _validateSafeId(String id) {
    if (!_safeIdPattern.hasMatch(id)) {
      throw FormatException('ID de pacote cartográfico inválido: "$id"');
    }
  }

  String _stripExtension(String segment) {
    final dot = segment.lastIndexOf('.');
    if (dot != -1) return segment.substring(0, dot);
    return segment;
  }

  String _stripPmtilesExtension(String raw) {
    if (raw.toLowerCase().endsWith('.pmtiles')) {
      return raw.substring(0, raw.length - 8);
    }
    return raw;
  }

  String _stripMbtilesExtension(String raw) {
    if (raw.toLowerCase().endsWith('.mbtiles')) {
      return raw.substring(0, raw.length - 8);
    }
    return raw;
  }
}
