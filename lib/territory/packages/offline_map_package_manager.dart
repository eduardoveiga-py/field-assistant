import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/app_logger.dart';
import '../map_engine/offline_map_catalog.dart';
import '../map_engine/offline_tile_server.dart';
import '../map_engine_adapter.dart';
import '../mbtiles/mbtiles_backend.dart';

export '../map_engine/offline_map_catalog.dart';
export '../map_engine_adapter.dart';
export '../mbtiles/mbtiles_backend.dart';

/// Type alias aligning PROJECT.md § Interface Contracts with OfflineMapPackageManifest.
typedef OfflineMapPackageMetadata = OfflineMapPackageManifest;

/// Token cooperativo para cancelamento de download e purga de arquivos temporários.
class CancellationToken {
  bool _isCancelled = false;
  bool _purgeOnCancel = true;
  final List<void Function()> _listeners = [];

  bool get isCancelled => _isCancelled;

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    for (final listener in _listeners) {
      try {
        listener();
      } catch (_) {}
    }
    _listeners.clear();
  }

  void onCancel(void Function() listener) {
    if (_isCancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }
}

/// Estado do ciclo de vida de um pacote offline gerenciado.
enum PackageDownloadStatus {
  available,
  downloading,
  paused,
  validating,
  installing,
  installed,
  failed,
  error,
  corrupted;

  bool get isTerminal =>
      this == installed || this == failed || this == error || this == corrupted;

  bool get isProcessing =>
      this == downloading || this == validating || this == installing;
}

/// Snapshot imutável de estado de um pacote.
class PackageState {
  final OfflineMapPackageMetadata manifest;
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

  bool get isError =>
      status == PackageDownloadStatus.failed ||
      status == PackageDownloadStatus.error ||
      status == PackageDownloadStatus.corrupted;

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

/// Exceções formais de ciclo de vida do gerenciador
class PackageDownloadException extends HttpException {
  final int? statusCode;

  PackageDownloadException(super.message, {super.uri, this.statusCode});

  @override
  String toString() =>
      'PackageDownloadException: $message (status: $statusCode)';
}

class DownloadInterruptedException extends PackageDownloadException {
  DownloadInterruptedException(String message) : super(message);
}

class RangeNotSatisfiableException extends PackageDownloadException {
  final int requestedStart;
  final int remoteFileSize;

  RangeNotSatisfiableException(
    this.requestedStart,
    this.remoteFileSize, {
    super.uri,
  }) : super(
         'HTTP 416 Range Not Satisfiable: start $requestedStart exceeds file size $remoteFileSize',
         statusCode: 416,
       );
}

class CorruptedPackageException extends FormatException
    implements PackageDownloadException {
  final String expectedSha256;
  final String actualSha256;
  @override
  final Uri? uri;
  @override
  final int? statusCode;

  CorruptedPackageException(
    this.expectedSha256,
    this.actualSha256, {
    this.uri,
    this.statusCode,
  }) : super(
         'Checksum SHA-256 inválido! Esperado: $expectedSha256, Obtido: $actualSha256. O arquivo pode estar corrompido ou adulterado.',
       );
}

class InvalidPackageFormatException extends FormatException
    implements PackageDownloadException {
  @override
  final Uri? uri;
  @override
  final int? statusCode;

  InvalidPackageFormatException(String reason, {this.uri, this.statusCode})
    : super('Formato de pacote inválido: $reason');
}

class DownloadCancelledException extends PackageDownloadException {
  final String packageId;

  DownloadCancelledException(this.packageId)
    : super('Download do pacote $packageId cancelado pelo usuário.');
}

/// Gerenciador de Pacotes Cartográficos Vetoriais Offline (Feature F12).
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
  final OfflineTileServer? tileServer;
  final List<OfflineMapPackageManifest> _catalog;

  final Map<String, PackageState> _states = {};
  final Map<String, CancellationToken> _activeTokens = {};
  final Set<String> _installingIds = {};
  final StreamController<Map<String, PackageState>> _statesController =
      StreamController<Map<String, PackageState>>.broadcast();

  OfflineMapPackageManager({
    Directory? storageDir,
    http.Client? httpClient,
    this.tileServer,
    List<OfflineMapPackageManifest>? catalog,
  }) : _customStorageDir = storageDir,
       _httpClient = httpClient ?? http.Client(),
       _catalog = List.unmodifiable(
         catalog ?? OfflineMapCatalog.defaultCatalog,
       ) {
    _initCatalog();
  }

  void _initCatalog() {
    for (final manifest in _catalog) {
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
  Future<File> getPackageFile(OfflineMapPackageMetadata manifest) async {
    final dir = await getStorageDirectory();
    final ext = manifest.format == OfflineMapFormat.pmtiles
        ? 'pmtiles'
        : 'mbtiles';
    return File('${dir.path}/${manifest.id}.$ext');
  }

  /// Sincroniza o catálogo em memória com os arquivos fisicamente existentes em disco.
  Future<void> syncWithDisk() async {
    final dir = await getStorageDirectory();

    for (final manifest in _catalog) {
      if (_installingIds.contains(manifest.id)) continue;
      final ext = manifest.format == OfflineMapFormat.pmtiles
          ? 'pmtiles'
          : 'mbtiles';
      final file = File('${dir.path}/${manifest.id}.$ext');
      final backup = File('${file.path}.bak');
      if (!file.existsSync() && backup.existsSync()) {
        // Restore the only known copy after interruption between renames.
        // Registration still requires validation against the current manifest.
        try {
          await backup.rename(file.path);
        } on FileSystemException {
          _states[manifest.id] = PackageState(
            manifest: manifest,
            status: PackageDownloadStatus.failed,
            localFile: backup,
            errorMessage:
                'Não foi possível restaurar a cópia anterior do pacote.',
          );
          continue;
        }
      }

      if (!file.existsSync()) {
        if (manifest.format == OfflineMapFormat.pmtiles) {
          tileServer?.unregisterPmtilesPackage(manifest.id);
        } else {
          tileServer?.unregisterMbtilesPackage(manifest.id);
        }
        _states[manifest.id] = PackageState(
          manifest: manifest,
          status: PackageDownloadStatus.available,
        );
        continue;
      }
      try {
        final length = await file.length();
        if (length != manifest.sizeBytes ||
            await calculateSha256(file) != manifest.sha256.toLowerCase()) {
          throw const FormatException('Tamanho ou checksum divergente.');
        }
        if (manifest.format == OfflineMapFormat.pmtiles) {
          final raf = await file.open();
          try {
            validatePmtilesHeader(await raf.read(127));
          } finally {
            await raf.close();
          }
        }
        _states[manifest.id] = PackageState(
          manifest: manifest,
          status: PackageDownloadStatus.installed,
          progress: 1.0,
          downloadedBytes: length,
          localFile: file,
        );
        _registerWithTileServer(manifest.id, file, manifest.format);
      } catch (_) {
        if (manifest.format == OfflineMapFormat.pmtiles) {
          tileServer?.unregisterPmtilesPackage(manifest.id);
        } else {
          tileServer?.unregisterMbtilesPackage(manifest.id);
        }
        // Nunca remover um arquivo do usuário em uma verificação falha.
        _states[manifest.id] = PackageState(
          manifest: manifest,
          status: PackageDownloadStatus.corrupted,
          localFile: file,
          errorMessage: 'Não foi possível verificar a integridade do pacote.',
        );
      }
    }
    _statesController.add(Map.of(_states));
  }

  /// Interface Contract from PROJECT.md:
  /// `installPackage(OfflineMapPackageMetadata package) -> Future<InstalledOfflineMapPackage>`
  /// com integridade SHA-256 verificada.
  Future<InstalledOfflineMapPackage> installPackage(
    OfflineMapPackageMetadata package, {
    void Function(double progress)? onProgress,
    bool allowResume = true,
    CancellationToken? cancellationToken,
  }) async {
    final state = await downloadAndInstall(
      manifest: package,
      onProgress: onProgress,
      allowResume: allowResume,
      cancellationToken: cancellationToken,
    );

    final finalFile = state.localFile!;
    return InstalledOfflineMapPackage(
      id: package.id,
      format: package.format,
      isVector: package.format == OfflineMapFormat.pmtiles,
      filePath: finalFile.path,
      sizeBytes: finalFile.lengthSync(),
    );
  }

  /// Executa o download resiliente RFC 7233 e instalação atômica.
  Future<PackageState> downloadAndInstall({
    required OfflineMapPackageMetadata manifest,
    void Function(double progress)? onProgress,
    bool allowResume = true,
    CancellationToken? cancellationToken,
  }) async {
    manifest.validate();
    if (!_installingIds.add(manifest.id)) {
      throw StateError(
        'Já existe uma instalação em andamento para ${manifest.id}.',
      );
    }
    try {
      return await _downloadAndInstallLocked(
        manifest: manifest,
        onProgress: onProgress,
        allowResume: allowResume,
        cancellationToken: cancellationToken,
      );
    } finally {
      _installingIds.remove(manifest.id);
    }
  }

  Future<PackageState> _downloadAndInstallLocked({
    required OfflineMapPackageMetadata manifest,
    void Function(double progress)? onProgress,
    required bool allowResume,
    CancellationToken? cancellationToken,
  }) async {
    final finalFile = await getPackageFile(manifest);
    final stagingFile = File('${finalFile.path}.tmp');
    final backupFile = File('${finalFile.path}.bak');

    final token = cancellationToken ?? CancellationToken();
    _activeTokens[manifest.id] = token;

    _states.putIfAbsent(
      manifest.id,
      () => PackageState(
        manifest: manifest,
        status: PackageDownloadStatus.available,
      ),
    );

    // Transição de estado: DOWNLOADING
    _updateState(
      manifest.id,
      (s) => s.copyWith(
        status: PackageDownloadStatus.downloading,
        progress: 0.0,
        clearError: true,
      ),
    );

    IOSink? sink;
    StreamSubscription? responseSub;

    try {
      if (token.isCancelled) {
        throw DownloadCancelledException(manifest.id);
      }

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
      if (token.isCancelled) {
        await response.stream.listen(null).cancel();
        throw DownloadCancelledException(manifest.id);
      }

      // Tratamento RFC 7233: 416 Range Not Satisfiable
      if (response.statusCode == 416) {
        if (stagingFile.existsSync()) {
          try {
            stagingFile.deleteSync();
          } catch (_) {}
        }
        throw RangeNotSatisfiableException(
          existingBytes,
          manifest.sizeBytes,
          uri: manifest.downloadUrl,
        );
      }

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw PackageDownloadException(
          'Servidor respondeu com status ${response.statusCode} para o pacote ${manifest.id}.',
          uri: manifest.downloadUrl,
          statusCode: response.statusCode,
        );
      }

      final isPartial = response.statusCode == 206;
      if (isPartial) {
        final contentRange = response.headers['content-range'] ?? '';
        final match = RegExp(
          r'^bytes (\d+)-(\d+)/(\d+)$',
          caseSensitive: false,
        ).firstMatch(contentRange);
        final start = match == null ? null : int.tryParse(match[1]!);
        final end = match == null ? null : int.tryParse(match[2]!);
        final length = match == null ? null : int.tryParse(match[3]!);
        if (existingBytes == 0 ||
            start != existingBytes ||
            end != manifest.sizeBytes - 1 ||
            length != manifest.sizeBytes) {
          await response.stream.listen(null).cancel();
          throw InvalidPackageFormatException(
            'Content-Range inválido para a retomada do pacote.',
          );
        }
      }
      final fileMode = (isPartial && existingBytes > 0)
          ? FileMode.append
          : FileMode.write;
      if (!isPartial && existingBytes > 0) {
        existingBytes = 0; // Servidor reiniciou do começo
      }

      sink = stagingFile.openWrite(mode: fileMode);
      var received = existingBytes;
      final total = manifest.sizeBytes;

      final completer = Completer<void>();

      token.onCancel(() {
        if (!completer.isCompleted) {
          responseSub?.cancel();
          completer.completeError(DownloadCancelledException(manifest.id));
        }
      });

      responseSub = response.stream.listen(
        (chunk) {
          if (token.isCancelled) {
            responseSub?.cancel();
            return;
          }
          if (received + chunk.length > total) {
            responseSub?.cancel();
            if (!completer.isCompleted) {
              completer.completeError(
                InvalidPackageFormatException(
                  'Download excedeu o tamanho do manifesto.',
                ),
              );
            }
            return;
          }
          sink?.add(chunk);
          received += chunk.length;

          final currentProgress = total > 0
              ? (received / total).clamp(0.0, 1.0)
              : 0.0;
          onProgress?.call(currentProgress);
          _updateState(
            manifest.id,
            (s) => s.copyWith(
              progress: currentProgress,
              downloadedBytes: received,
            ),
          );
        },
        onError: (err, st) {
          if (!completer.isCompleted) {
            completer.completeError(err, st);
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        cancelOnError: true,
      );

      await completer.future;
      await sink.flush();
      await sink.close();
      sink = null;

      // Transição de estado: VALIDATING
      _updateState(
        manifest.id,
        (s) =>
            s.copyWith(status: PackageDownloadStatus.validating, progress: 1.0),
      );

      // Validação 1: Tamanho do arquivo
      final stagingLength = stagingFile.lengthSync();
      if (stagingLength < manifest.sizeBytes) {
        throw DownloadInterruptedException(
          'Download incompleto ($stagingLength de ${manifest.sizeBytes} bytes); retomada disponível.',
        );
      }
      if (stagingLength != manifest.sizeBytes) {
        throw InvalidPackageFormatException(
          'Tamanho do pacote baixado ($stagingLength bytes) difere do manifesto (${manifest.sizeBytes} bytes).',
        );
      }

      // Validação 2: Formato do arquivo (Magic String PMTiles)
      if (manifest.format == OfflineMapFormat.pmtiles) {
        if (stagingLength < 127) {
          throw InvalidPackageFormatException(
            'Arquivo PMTiles inválido: menor que 127 bytes.',
          );
        }
        final raf = stagingFile.openSync(mode: FileMode.read);
        final headerBytes = raf.readSync(127);
        raf.closeSync();
        validatePmtilesHeader(headerBytes);
      }

      // Validação 3: Checksum SHA-256 criptográfico (Streaming seguro para memória)
      final actualHash = await calculateSha256(stagingFile);
      if (actualHash != manifest.sha256.toLowerCase()) {
        throw CorruptedPackageException(
          manifest.sha256.toLowerCase(),
          actualHash,
          uri: manifest.downloadUrl,
        );
      }

      if (token.isCancelled) {
        throw DownloadCancelledException(manifest.id);
      }

      // Transição de estado: INSTALLING
      _updateState(
        manifest.id,
        (s) => s.copyWith(status: PackageDownloadStatus.installing),
      );

      // Instalação Atômica com Rollback Seguro
      if (backupFile.existsSync()) {
        throw FileSystemException(
          'Cópia anterior preservada; resolva o backup antes de instalar.',
          backupFile.path,
        );
      }
      if (finalFile.existsSync()) {
        finalFile.renameSync(backupFile.path);
      }

      try {
        stagingFile.renameSync(finalFile.path);
      } catch (renameError) {
        // Rollback only if the new file was not placed at the destination.
        if (!finalFile.existsSync() && backupFile.existsSync()) {
          backupFile.renameSync(finalFile.path);
        }
        rethrow;
      }
      // A cleanup failure must never roll back over the new installed file.
      // Preserve the backup; the next replacement will refuse to overwrite it.
      if (backupFile.existsSync()) {
        try {
          backupFile.deleteSync();
        } on FileSystemException catch (error, stack) {
          AppLogger.warning(
            'Não foi possível remover o backup anterior.',
            error,
            stack,
          );
        }
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
    } catch (e) {
      await responseSub?.cancel();
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      final preservePartial =
          e is DownloadInterruptedException ||
          e is SocketException ||
          e is http.ClientException ||
          (e is DownloadCancelledException && !token._purgeOnCancel);
      if (!preservePartial && stagingFile.existsSync()) {
        try {
          stagingFile.deleteSync();
        } catch (_) {}
      }

      final errorStatus = (e is CorruptedPackageException)
          ? PackageDownloadStatus.corrupted
          : PackageDownloadStatus.failed;

      final failedState = PackageState(
        manifest: manifest,
        status: errorStatus,
        errorMessage: e.toString(),
      );
      _states[manifest.id] = failedState;
      _statesController.add(Map.of(_states));
      rethrow;
    } finally {
      _activeTokens.remove(manifest.id);
    }
  }

  /// Cancela um download ativo e expurga o arquivo .tmp
  Future<void> cancelDownload(
    String packageId, {
    bool purgeTempFile = true,
  }) async {
    final token = _activeTokens[packageId];
    if (token != null) {
      token._purgeOnCancel = purgeTempFile;
      token.cancel();
    }

    if (purgeTempFile && token == null) {
      final state = _states[packageId];
      if (state != null) {
        final finalFile = await getPackageFile(state.manifest);
        final tmpFile = File('${finalFile.path}.tmp');
        if (tmpFile.existsSync()) {
          try {
            tmpFile.deleteSync();
          } catch (_) {}
        }
      }
    }

    if (token != null) return;
    _updateState(
      packageId,
      (s) => s.copyWith(
        status: PackageDownloadStatus.available,
        progress: 0.0,
        downloadedBytes: 0,
        clearError: true,
      ),
    );
  }

  /// Remove com segurança um pacote instalado e desregistra do servidor local.
  Future<void> removePackage(String packageId) async {
    if (_installingIds.contains(packageId)) {
      throw StateError(
        'Cancele e aguarde o download antes de remover o pacote.',
      );
    }
    final state = _states[packageId];
    if (state == null) return;

    if (tileServer != null) {
      if (state.manifest.format == OfflineMapFormat.pmtiles) {
        tileServer!.unregisterPmtilesPackage(packageId);
      } else {
        tileServer!.unregisterMbtilesPackage(packageId);
      }
    }

    final file = await getPackageFile(state.manifest);
    if (file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {}
    }
    final tmpFile = File('${file.path}.tmp');
    if (tmpFile.existsSync()) {
      try {
        tmpFile.deleteSync();
      } catch (_) {}
    }
    final bakFile = File('${file.path}.bak');
    if (bakFile.existsSync()) {
      try {
        bakFile.deleteSync();
      } catch (_) {}
    }

    _states[packageId] = PackageState(
      manifest: state.manifest,
      status: PackageDownloadStatus.available,
    );
    _statesController.add(Map.of(_states));
  }

  void _registerWithTileServer(String id, File file, OfflineMapFormat format) {
    final server = tileServer;
    if (server == null) return;
    if (format == OfflineMapFormat.pmtiles) {
      server.registerPmtilesPackage(id, file);
    } else {
      server.registerMbtilesPackage(id, file);
    }
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

  /// Utility RFC 7233: avalia status 206 vs 416
  static int evaluateRangeStatus({
    required int start,
    required int? end,
    required int fileSize,
  }) {
    if (start >= fileSize || (end != null && start > end)) {
      return 416; // Range Not Satisfiable
    }
    return 206; // Partial Content
  }

  /// Utility RFC 7233: verifica se o intervalo start <= end é válido
  static bool isValidRange(int start, int end) => start <= end;

  /// Streaming SHA-256 calculation (heap memory safe).
  static Future<String> calculateSha256(File file) async {
    final digest = await crypto.sha256.bind(file.openRead()).first;
    return digest.toString().toLowerCase();
  }

  /// Validador de cabeçalho PMTiles v3 (127 bytes).
  static void validatePmtilesHeader(Uint8List headerBytes) {
    if (headerBytes.length < 127) {
      throw InvalidPackageFormatException(
        'Cabeçalho PMTiles inválido: menor que 127 bytes.',
      );
    }
    final magic = String.fromCharCodes(headerBytes.sublist(0, 7));
    if (magic != 'PMTiles') {
      throw InvalidPackageFormatException(
        'Assinatura mágica PMTiles inválida: "$magic"',
      );
    }
    final version = headerBytes[7];
    if (version != 3) {
      throw InvalidPackageFormatException(
        'Versão do PMTiles não suportada: $version (apenas v3 é suportada).',
      );
    }
  }

  void dispose() {
    _statesController.close();
  }
}
