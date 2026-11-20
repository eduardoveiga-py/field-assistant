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

  final Map<String, PackageState> _states = {};
  final Map<String, CancellationToken> _activeTokens = {};
  final StreamController<Map<String, PackageState>> _statesController =
      StreamController<Map<String, PackageState>>.broadcast();

  OfflineMapPackageManager({
    Directory? storageDir,
    http.Client? httpClient,
    this.tileServer,
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
  Future<File> getPackageFile(OfflineMapPackageMetadata manifest) async {
    final dir = await getStorageDirectory();
    final ext = manifest.format == OfflineMapFormat.pmtiles
        ? 'pmtiles'
        : 'mbtiles';
    return File('${dir.path}/${manifest.id}.$ext');
  }

  /// Sincroniza o catálogo em memória com os arquivos fisicamente existentes em disco.
  /// Se um pacote principal estiver ausente mas seu arquivo de backup (.bak) existir,
  /// valida o cabeçalho e restaura o backup automaticamente.
  Future<void> syncWithDisk({
    List<OfflineMapPackageMetadata>? manifests,
  }) async {
    final dir = await getStorageDirectory();

    final packagesToCheck = <OfflineMapPackageMetadata>{
      ...OfflineMapCatalog.defaultCatalog,
      ..._states.values.map((s) => s.manifest),
      ...?manifests,
    };

    for (final manifest in packagesToCheck) {
      final ext = manifest.format == OfflineMapFormat.pmtiles
          ? 'pmtiles'
          : 'mbtiles';
      final file = File('${dir.path}/${manifest.id}.$ext');
      final backupFile = File('${file.path}.bak');

      // Se o arquivo principal não existir, tenta restaurar backup .bak sobrevivente
      if (!file.existsSync() && backupFile.existsSync()) {
        try {
          if (manifest.format == OfflineMapFormat.pmtiles) {
            if (backupFile.lengthSync() >= 127) {
              final raf = backupFile.openSync(mode: FileMode.read);
              final headerBytes = raf.readSync(127);
              raf.closeSync();
              validatePmtilesHeader(headerBytes);
            } else {
              throw InvalidPackageFormatException(
                'Pacote PMTiles sintético ou corrompido: cabeçalho sem diretório ou tiles válidos.',
              );
            }
          } else if (manifest.format == OfflineMapFormat.mbtiles) {
            if (backupFile.lengthSync() >= 16) {
              final raf = backupFile.openSync(mode: FileMode.read);
              final headerBytes = raf.readSync(16);
              raf.closeSync();
              validateMbtilesHeader(headerBytes);
            } else {
              throw InvalidPackageFormatException(
                'Arquivo MBTiles inválido: menor que 16 bytes.',
              );
            }
          }
          backupFile.renameSync(file.path);
          AppLogger.info(
            'Backup de pacote restaurado com sucesso: ${file.path}',
          );
        } catch (e) {
          AppLogger.warning('Falha ao restaurar backup corrompido: $e');
        }
      }

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

      var fileMode = FileMode.write;
      if (response.statusCode == 206) {
        final contentRange = response.headers['content-range'];
        var rangeValid = false;
        if (contentRange != null && existingBytes > 0) {
          final match = RegExp(
            r'^bytes\s+(\d+)-(\d+)/(?:\d+|\*)',
            caseSensitive: false,
          ).firstMatch(contentRange.trim());
          if (match != null) {
            final startByte = int.tryParse(match.group(1)!);
            if (startByte == existingBytes) {
              rangeValid = true;
            }
          }
        }
        if (rangeValid) {
          fileMode = FileMode.append;
        } else {
          // Servidor retornou 206 sem cabeçalho válido ou com início divergente;
          // reinicia o download do início truncando o arquivo existente.
          existingBytes = 0;
          fileMode = FileMode.write;
        }
      } else {
        // Status 200 (ou outro): servidor reiniciou do começo, trunca arquivo .tmp
        existingBytes = 0;
        fileMode = FileMode.write;
      }

      sink = stagingFile.openWrite(mode: fileMode);
      var received = existingBytes;
      final total = manifest.sizeBytes;

      final completer = Completer<void>();

      token.onCancel(() {
        if (!completer.isCompleted) {
          sink?.flush().then((_) => sink?.close());
          if (stagingFile.existsSync()) {
            try {
              stagingFile.deleteSync();
            } catch (_) {}
          }
          completer.completeError(DownloadCancelledException(manifest.id));
        }
      });

      responseSub = response.stream.listen(
        (chunk) {
          if (token.isCancelled) {
            responseSub?.cancel();
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
      if (manifest.sizeBytes > 0 && stagingLength != manifest.sizeBytes) {
        throw InvalidPackageFormatException(
          'Tamanho do pacote baixado ($stagingLength bytes) difere do manifesto (${manifest.sizeBytes} bytes).',
        );
      }

      // Validação 2: Formato do arquivo (Magic String PMTiles / MBTiles)
      if (manifest.format == OfflineMapFormat.pmtiles) {
        if (stagingLength < 127) {
          throw InvalidPackageFormatException(
            'Pacote PMTiles sintético ou corrompido: cabeçalho sem diretório ou tiles válidos.',
          );
        }
        final raf = stagingFile.openSync(mode: FileMode.read);
        final headerBytes = raf.readSync(127);
        raf.closeSync();
        validatePmtilesHeader(headerBytes);
      } else if (manifest.format == OfflineMapFormat.mbtiles) {
        if (stagingLength < 16) {
          throw InvalidPackageFormatException(
            'Arquivo MBTiles inválido: menor que 16 bytes.',
          );
        }
        final raf = stagingFile.openSync(mode: FileMode.read);
        final headerBytes = raf.readSync(16);
        raf.closeSync();
        validateMbtilesHeader(headerBytes);
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

      // Transição de estado: INSTALLING
      _updateState(
        manifest.id,
        (s) => s.copyWith(status: PackageDownloadStatus.installing),
      );

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
    } catch (e) {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }

      // Expurgar .tmp se for erro irrecuperável ou cancelamento explícito do download.
      // Em falhas transitórias de rede (SocketException, TimeoutException, etc.),
      // preservar o arquivo .tmp para permitir retomada via HTTP Range.
      final isCancellation =
          e is DownloadCancelledException ||
          (e is http.ClientException &&
              e.message.toLowerCase().contains('cancelad'));
      final shouldPurge =
          e is CorruptedPackageException ||
          e is InvalidPackageFormatException ||
          e is RangeNotSatisfiableException ||
          isCancellation;

      if (shouldPurge && stagingFile.existsSync()) {
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
    token?.cancel();

    if (purgeTempFile) {
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

  /// Validador profundo de cabeçalho PMTiles v3 (127 bytes).
  ///
  /// Garante que o arquivo possui cabeçalho canônico v3, diretório raiz válido,
  /// offsets consistentes, tiles reais (rejeitando pacotes sintéticos/vazios),
  /// bounding box WGS84 válido e não invertido, e níveis de zoom coerentes.
  static void validatePmtilesHeader(Uint8List headerBytes) {
    const errorMsg =
        'Pacote PMTiles sintético ou corrompido: cabeçalho sem diretório ou tiles válidos.';

    if (headerBytes.length < 127) {
      throw InvalidPackageFormatException(
        'Cabeçalho PMTiles inválido: menor que 127 bytes.',
      );
    }

    final magic = String.fromCharCodes(headerBytes.sublist(0, 7));
    if (magic != 'PMTiles') {
      throw InvalidPackageFormatException(
        'Assinatura mágica PMTiles inválida: esperado "PMTiles".',
      );
    }

    final version = headerBytes[7];
    if (version != 3) {
      throw InvalidPackageFormatException(
        'Versão do PMTiles não suportada: $version (apenas v3 é suportada).',
      );
    }

    final bd = ByteData.sublistView(headerBytes);

    int getUint64(int offset) {
      final low = bd.getUint32(offset, Endian.little);
      final high = bd.getUint32(offset + 4, Endian.little);
      return (high << 32) | low;
    }

    final rootDirOffset = getUint64(8);
    final rootDirLength = getUint64(16);
    if (rootDirOffset < 127 || rootDirLength <= 0) {
      throw InvalidPackageFormatException(errorMsg);
    }

    final tileDataOffset = getUint64(56);
    final tileDataLength = getUint64(64);
    if (tileDataOffset < rootDirOffset + rootDirLength || tileDataLength <= 0) {
      throw InvalidPackageFormatException(errorMsg);
    }

    final numAddressedTiles = getUint64(72);
    final numTileEntries = getUint64(80);
    if (numTileEntries <= 0 && numAddressedTiles <= 0) {
      throw InvalidPackageFormatException(errorMsg);
    }

    final minZoom = headerBytes[100];
    final maxZoom = headerBytes[101];
    if (minZoom < 0 || minZoom > maxZoom || maxZoom > 26) {
      throw InvalidPackageFormatException(errorMsg);
    }

    final minLon = bd.getInt32(102, Endian.little) / 10000000.0;
    final minLat = bd.getInt32(106, Endian.little) / 10000000.0;
    final maxLon = bd.getInt32(110, Endian.little) / 10000000.0;
    final maxLat = bd.getInt32(114, Endian.little) / 10000000.0;

    if (minLon < -180.0 ||
        maxLon > 180.0 ||
        minLat < -90.0 ||
        maxLat > 90.0 ||
        minLon >= maxLon ||
        minLat >= maxLat) {
      throw InvalidPackageFormatException(errorMsg);
    }
  }

  /// Validador de cabeçalho SQLite para MBTiles (16 bytes).
  static void validateMbtilesHeader(Uint8List headerBytes) {
    if (headerBytes.length < 16) {
      throw InvalidPackageFormatException(
        'Arquivo MBTiles inválido: menor que 16 bytes.',
      );
    }
    const sqliteMagic = 'SQLite format 3\x00';
    final magic = String.fromCharCodes(headerBytes.sublist(0, 16));
    if (magic != sqliteMagic) {
      throw InvalidPackageFormatException(
        'Assinatura mágica SQLite inválida no arquivo MBTiles.',
      );
    }
  }

  void dispose() {
    _statesController.close();
  }
}
