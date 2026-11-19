import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:ministerio_pessoal/territory/map_engine/offline_tile_server.dart';
import 'package:path/path.dart' as p;

/// Gerenciador de ciclo de vida seguro para o [OfflineTileServer] durante testes E2E.
///
/// Garante que o servidor Shelf loopback seja vinculado exclusivamente a `127.0.0.1`
/// em porta efêmera (0) e seja encerrado de forma limpa (`server.stop(force: true)`)
/// ao final dos testes, evitando portas presas ou conflitos entre suítes de teste.
class TileServerTestLifecycle {
  final OfflineTileServer server;
  final Directory packagesDir;
  final Directory assetsDir;
  final bool _managedTempDirs;
  bool _isDisposed = false;

  TileServerTestLifecycle._({
    required this.server,
    required this.packagesDir,
    required this.assetsDir,
    required this._managedTempDirs,
  });

  /// Cria uma nova instância de [TileServerTestLifecycle] com diretórios isolados.
  factory TileServerTestLifecycle({
    Directory? packagesDir,
    Directory? assetsDir,
  }) {
    final managed = packagesDir == null || assetsDir == null;
    final pkgDir =
        packagesDir ??
        Directory.systemTemp.createTempSync('tile_lifecycle_pkgs_');
    final astDir =
        assetsDir ??
        Directory.systemTemp.createTempSync('tile_lifecycle_assets_');

    final server = OfflineTileServer(packagesDir: pkgDir, assetsDir: astDir);

    return TileServerTestLifecycle._(
      server: server,
      packagesDir: pkgDir,
      assetsDir: astDir,
      managedTempDirs: managed,
    );
  }

  /// Cria e inicializa imediatamente o servidor em porta efêmera.
  static Future<TileServerTestLifecycle> createStarted({
    Directory? packagesDir,
    Directory? assetsDir,
    int desiredPort = 0,
  }) async {
    final lifecycle = TileServerTestLifecycle(
      packagesDir: packagesDir,
      assetsDir: assetsDir,
    );
    await lifecycle.start(desiredPort: desiredPort);
    return lifecycle;
  }

  /// Porta TCP atribuída pelo SO no loopback.
  int? get port => server.port;

  /// URL base no formato `http://127.0.0.1:$port`.
  String? get baseUrl => server.baseUrl;

  /// Indica se o servidor está ouvindo ativamente.
  bool get isRunning => server.isRunning && !_isDisposed;

  /// Inicia o servidor HTTP local em loopback IPv4.
  Future<int> start({int desiredPort = 0}) async {
    if (_isDisposed) {
      throw StateError(
        'Cannot start TileServerTestLifecycle after it has been disposed.',
      );
    }
    return server.start(desiredPort: desiredPort);
  }

  /// Registra um pacote PMTiles diretamente a partir de bytes em memória,
  /// salvando-o no diretório de pacotes gerenciado.
  Future<File> registerPmtilesBytes(
    String packageId,
    Uint8List pmtilesBytes,
  ) async {
    final file = File(p.join(packagesDir.path, '$packageId.pmtiles'));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(pmtilesBytes, flush: true);
    server.registerPmtilesPackage(packageId, file);
    return file;
  }

  /// Registra um arquivo PMTiles existente com o identificador fornecido.
  void registerPmtilesFile(String packageId, File file) {
    server.registerPmtilesPackage(packageId, file);
  }

  /// Registra um arquivo MBTiles existente com o identificador fornecido.
  void registerMbtilesFile(String packageId, File file) {
    server.registerMbtilesPackage(packageId, file);
  }

  /// Consulta o endpoint `/status` do servidor.
  Future<http.Response> fetchStatus() async {
    _ensureRunning();
    return http.get(Uri.parse('$baseUrl/status'));
  }

  /// Consulta os metadados do cabeçalho de um pacote PMTiles (`/pmtiles/{packageId}`).
  Future<http.Response> fetchPmtilesHeader(String packageId) async {
    _ensureRunning();
    return http.get(Uri.parse('$baseUrl/pmtiles/$packageId'));
  }

  /// Requisita um tile vetorial específico (`/pmtiles/{packageId}/{z}/{x}/{y}`).
  Future<http.Response> fetchTile(
    String packageId,
    int z,
    int x,
    int y, {
    Map<String, String>? headers,
  }) async {
    _ensureRunning();
    return http.get(
      Uri.parse('$baseUrl/pmtiles/$packageId/$z/$x/$y'),
      headers: headers,
    );
  }

  /// Requisita um arquivo de fonte SDF (.pbf) (`/assets/fonts/{fontstack}/{range}.pbf`).
  Future<http.Response> fetchFontGlyph(String fontstack, String range) async {
    _ensureRunning();
    return http.get(Uri.parse('$baseUrl/assets/fonts/$fontstack/$range.pbf'));
  }

  /// Executa o encerramento do servidor e remoção segura de diretórios temporários.
  Future<void> stop({bool force = true}) async {
    if (_isDisposed) return;
    _isDisposed = true;

    try {
      await server.stop(force: force);
    } catch (_) {}

    if (_managedTempDirs) {
      for (final dir in [packagesDir, assetsDir]) {
        if (dir.existsSync()) {
          try {
            dir.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
    }
  }

  /// Alias de conveniência para encerramento (`dispose` compatível com `addTearDown`).
  Future<void> dispose() => stop(force: true);

  void _ensureRunning() {
    if (!isRunning || baseUrl == null) {
      throw StateError(
        'OfflineTileServer is not currently running. Call start() before making requests.',
      );
    }
  }
}
