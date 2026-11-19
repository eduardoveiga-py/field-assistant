import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/app_logger.dart';
import '../map_engine_adapter.dart';
import 'offline_map_catalog.dart';
import 'offline_tile_server.dart';

/// Estado de ciclo de vida do download e instalação de pacote offline.
enum PackageDownloadStatus {
  available,
  downloading,
  validating,
  installed,
  failed,
}

/// Estado imutável de um pacote cartográfico gerenciado.
class PackageState {
  final OfflineMapPackageManifest manifest;
  final PackageDownloadStatus status;
  final double progress; // 0.0 a 1.0
  final int downloadedBytes;
  final File? localFile;
  final String? errorMessage;

  const PackageState({
    required this.manifest,
    required this.status,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.localFile,
    this.errorMessage,
  });

  bool get isInstalled =>
      status == PackageDownloadStatus.installed &&
      localFile != null &&
      localFile!.existsSync();

  PackageState copyWith({
    PackageDownloadStatus? status,
    double? progress,
    int? downloadedBytes,
    File? localFile,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PackageState(
      manifest: manifest,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      localFile: localFile ?? this.localFile,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Gerenciador de Pacotes Cartográficos Vetoriais Offline (FA-MAP-02 / M4).
///
/// Encapsula:
/// 1. Catálogo com manifesto SHA-256 e bounding box imutáveis.
/// 2. Download resiliente com suporte a retomada RFC 7233 (HTTP Range).
/// 3. Validação criptográfica de integridade SHA-256 e cabeçalho PMTiles v3 / MBTiles.
/// 4. Instalação atômica com rollback automático em caso de arquivo corrompido.
/// 5. Registro automático de pacotes instalados no [OfflineTileServer] local.
class OfflineMapPackageManager {
  final Directory? _customStorageDir;
  final http.Client _httpClient;
  final OfflineTileServer? _tileServer;

  final Map<String, PackageState> _states = {};
  final StreamController<Map<String, PackageState>> _statesController =
      StreamController<Map<String, PackageState>>.broadcast();

  OfflineMapPackageManager({
    Directory? storageDir,
    http.Client? httpClient,
    this._tileServer,
  }) : _customStorageDir = storageDir,
       _httpClient = httpClient ?? http.Client() {
    _initCatalog();
  }

  void _initCatalog() {
    for (final manifest in OfflineMapCatalog.defaultCatalog) {
      _states[manifest.id] = PackageState(
        manifest: manifest,
        status: PackageDownloadStatus.available,
      );
    }
  }

  /// Fluxo de estados reativos de todos os pacotes gerenciados.
  Stream<Map<String, PackageState>> get stateStream => _statesController.stream;

  /// Retorna o estado atual de todos os pacotes.
  Map<String, PackageState> get currentStates => Map.unmodifiable(_states);

  /// Retorna o diretório físico onde os pacotes de mapas ficam salvos.
  Future<Directory> getStorageDirectory() async {
    if (_customStorageDir != null) {
      if (!_customStorageDir.existsSync()) {
        _customStorageDir.createSync(recursive: true);
      }
      return _customStorageDir;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/offline_map_packages');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Retorna o arquivo destino final para um pacote pelo seu ID e formato.
  Future<File> getPackageFile(OfflineMapPackageManifest manifest) async {
    final dir = await getStorageDirectory();
    final ext = manifest.format == OfflineMapFormat.pmtiles
        ? 'pmtiles'
        : 'mbtiles';
    return File('${dir.path}/${manifest.id}.$ext');
  }

  /// Sincroniza o catálogo em memória com os arquivos fisicamente existentes em disco.
  Future<void> syncWithDisk() async {
    final dir = await getStorageDirectory();

    for (final manifest in OfflineMapCatalog.defaultCatalog) {
      final ext = manifest.format == OfflineMapFormat.pmtiles
          ? 'pmtiles'
          : 'mbtiles';
      final file = File('${dir.path}/${manifest.id}.$ext');

      if (file.existsSync()) {
        final length = file.lengthSync();
        if (length == manifest.sizeBytes || manifest.sizeBytes <= 0) {
          _states[manifest.id] = PackageState(
            manifest: manifest,
            status: PackageDownloadStatus.installed,
            progress: 1.0,
            downloadedBytes: length,
            localFile: file,
          );
          _registerWithTileServer(manifest.id, file, manifest.format);
        } else {
          _states[manifest.id] = PackageState(
            manifest: manifest,
            status: PackageDownloadStatus.available,
            localFile: file,
          );
        }
      } else {
        _states[manifest.id] = PackageState(
          manifest: manifest,
          status: PackageDownloadStatus.available,
        );
      }
    }
    _statesController.add(Map.of(_states));
  }

  /// Registra pacote com o servidor HTTP local se disponível.
  void _registerWithTileServer(String id, File file, OfflineMapFormat format) {
    final server = _tileServer;
    if (server == null) return;
    if (format == OfflineMapFormat.pmtiles) {
      server.registerPmtilesPackage(id, file);
    } else {
      server.registerMbtilesPackage(id, file);
    }
  }

  /// Executa o download resiliente e a instalação atômica com validação de checksum SHA-256.
  Future<PackageState> downloadAndInstall({
    required OfflineMapPackageManifest manifest,
    void Function(double progress)? onProgress,
    bool allowResume = true,
  }) async {
    manifest.validate();
    final finalFile = await getPackageFile(manifest);
    final stagingFile = File('${finalFile.path}.tmp');
    final backupFile = File('${finalFile.path}.bak');

    // Transição de estado: DOWNLOADING
    _updateState(
      manifest.id,
      (s) => s.copyWith(
        status: PackageDownloadStatus.downloading,
        progress: 0.0,
        clearError: true,
      ),
    );

    try {
      var existingBytes = 0;
      if (allowResume && stagingFile.existsSync()) {
        existingBytes = stagingFile.lengthSync();
      }

      // Prepara requisição HTTP com suporte a Range se houver bytes prévios
      final request = http.Request('GET', manifest.downloadUrl);
      if (existingBytes > 0 && allowResume) {
        request.headers['Range'] = 'bytes=$existingBytes-';
      }

      final response = await _httpClient.send(request);

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException(
          'Servidor respondeu com status ${response.statusCode} para o pacote ${manifest.id}.',
          uri: manifest.downloadUrl,
        );
      }

      final isPartial = response.statusCode == 206;
      final fileMode = (isPartial && existingBytes > 0)
          ? FileMode.append
          : FileMode.write;
      if (!isPartial && existingBytes > 0) {
        existingBytes = 0; // Servidor reiniciou do começo
      }

      final sink = stagingFile.openSync(mode: fileMode);
      var received = existingBytes;
      final total = manifest.sizeBytes;

      await for (final chunk in response.stream) {
        sink.writeFromSync(chunk);
        received += chunk.length;

        final currentProgress = total > 0
            ? (received / total).clamp(0.0, 1.0)
            : 0.0;
        onProgress?.call(currentProgress);
        _updateState(
          manifest.id,
          (s) =>
              s.copyWith(progress: currentProgress, downloadedBytes: received),
        );
      }
      sink.closeSync();

      // Transição de estado: VALIDATING
      _updateState(
        manifest.id,
        (s) =>
            s.copyWith(status: PackageDownloadStatus.validating, progress: 1.0),
      );

      // Validação 1: Tamanho do arquivo
      final stagingLength = stagingFile.lengthSync();
      if (manifest.sizeBytes > 0 && stagingLength != manifest.sizeBytes) {
        throw FormatException(
          'Tamanho do pacote baixado ($stagingLength bytes) difere do manifesto (${manifest.sizeBytes} bytes).',
        );
      }

      // Validação 2: Checksum SHA-256
      final fileBytes = await stagingFile.readAsBytes();
      final actualHash = crypto.sha256
          .convert(fileBytes)
          .toString()
          .toLowerCase();
      if (actualHash != manifest.sha256.toLowerCase()) {
        throw FormatException(
          'Checksum SHA-256 inválido! Esperado: ${manifest.sha256}, Obtido: $actualHash. O arquivo pode estar corrompido ou adulterado.',
        );
      }

      // Validação 3: Formato do arquivo (Magic String PMTiles)
      if (manifest.format == OfflineMapFormat.pmtiles) {
        if (fileBytes.length < 127) {
          throw const FormatException(
            'Arquivo PMTiles inválido: menor que 127 bytes.',
          );
        }
        final magic = String.fromCharCodes(fileBytes.sublist(0, 7));
        if (magic != 'PMTiles') {
          throw FormatException('Assinatura mágica PMTiles inválida: "$magic"');
        }
      }

      // Instalação Atômica com Rollback Seguro
      if (finalFile.existsSync()) {
        if (backupFile.existsSync()) backupFile.deleteSync();
        finalFile.renameSync(backupFile.path);
      }

      try {
        stagingFile.renameSync(finalFile.path);
        if (backupFile.existsSync()) {
          backupFile.deleteSync();
        }
      } catch (renameError) {
        // Rollback para versão anterior caso o rename falhe
        if (backupFile.existsSync()) {
          backupFile.renameSync(finalFile.path);
        }
        rethrow;
      }

      // Registro no TileServer
      _registerWithTileServer(manifest.id, finalFile, manifest.format);

      // Transição de estado: INSTALLED
      final installedState = PackageState(
        manifest: manifest,
        status: PackageDownloadStatus.installed,
        progress: 1.0,
        downloadedBytes: stagingLength,
        localFile: finalFile,
      );
      _states[manifest.id] = installedState;
      _statesController.add(Map.of(_states));

      AppLogger.info(
        'Pacote offline ${manifest.id} instalado com sucesso em ${finalFile.path}.',
      );
      return installedState;
    } catch (e, st) {
      AppLogger.error(
        'Falha na instalação do pacote ${manifest.id}: $e',
        e,
        st,
      );

      // Limpeza de arquivo temporário
      if (stagingFile.existsSync()) {
        try {
          stagingFile.deleteSync();
        } catch (_) {}
      }

      final failedState = PackageState(
        manifest: manifest,
        status: PackageDownloadStatus.failed,
        errorMessage: e.toString(),
      );
      _states[manifest.id] = failedState;
      _statesController.add(Map.of(_states));
      rethrow;
    }
  }

  /// Remove com segurança um pacote instalado e desregistra do servidor local.
  Future<void> removePackage(String packageId) async {
    final state = _states[packageId];
    if (state == null) return;

    if (_tileServer != null) {
      if (state.manifest.format == OfflineMapFormat.pmtiles) {
        _tileServer.unregisterPmtilesPackage(packageId);
      } else {
        _tileServer.unregisterMbtilesPackage(packageId);
      }
    }

    final file = await getPackageFile(state.manifest);
    if (file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {}
    }

    _states[packageId] = PackageState(
      manifest: state.manifest,
      status: PackageDownloadStatus.available,
    );
    _statesController.add(Map.of(_states));
  }

  void _updateState(
    String id,
    PackageState Function(PackageState current) updater,
  ) {
    final current = _states[id];
    if (current != null) {
      _states[id] = updater(current);
      _statesController.add(Map.of(_states));
    }
  }

  void dispose() {
    _statesController.close();
  }
}
