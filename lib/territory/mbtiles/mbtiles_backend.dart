import 'dart:typed_data';

import '../map_engine_adapter.dart';

/// Metadados de um pacote cartográfico offline instalado em disco (.pmtiles ou .mbtiles).
class InstalledOfflineMapPackage {
  final String id;
  final OfflineMapFormat format;
  final bool isVector;
  final String filePath;
  final int sizeBytes;

  const InstalledOfflineMapPackage({
    required this.id,
    required this.format,
    required this.isVector,
    required this.filePath,
    required this.sizeBytes,
  });
}

/// Interface de backend para persistência e leitura de pacotes .mbtiles e .pmtiles.
/// Abstrai plataformas nativas (com dart:io e sqlite3) e Web.
abstract class MBTilesBackend {
  /// Inicializa o diretório e abre os arquivos .mbtiles existentes.
  Future<void> init();

  /// Busca o bloco (tile) de imagem diretamente dos pacotes locais.
  Future<Uint8List?> getTile(int z, int x, int y);

  /// Verifica se o arquivo da região existe fisicamente no disco e possui tamanho > 0.
  bool isRegionInstalled(String regionId);

  /// Retorna o caminho absoluto do arquivo .mbtiles da região no sistema de arquivos.
  String getRegionFilePath(String regionId);

  /// Retorna o diretório gerenciado onde pacotes offline residem, ou null (ex.: Web).
  String? getPackagesDirectoryPath() => null;

  /// Lista todos os pacotes offline (.pmtiles e .mbtiles) instalados no disco,
  /// indicando formato e se contêm tiles vetoriais.
  List<InstalledOfflineMapPackage> getInstalledPackages() => const [];

  /// Retorna o tamanho do arquivo em disco (em bytes) se instalado, ou null.
  int? getRegionFileSize(String regionId);

  /// Retorna o conjunto de IDs de regiões atualmente instaladas no disco.
  Set<String> getInstalledRegionIds();

  /// Grava a stream de bytes no arquivo temporário (.tmp) e realiza a renomeação
  /// atômica para o arquivo final .mbtiles. Abre a conexão SQLite imediatamente.
  Future<void> saveRegionStream({
    required String regionId,
    required Stream<List<int>> byteStream,
    int? totalBytes,
    void Function(double progress, int downloadedBytes)? onProgress,
    bool Function()? isCancelled,
  });

  /// Importa um arquivo .mbtiles local já existente, validando cabeçalho SQLite
  /// e tabela `tiles` antes de instalar no diretório gerenciado.
  Future<void> importRegionFile({
    required String regionId,
    required String sourceFilePath,
    void Function(double progress, int copiedBytes)? onProgress,
  });

  /// Importa um arquivo .pmtiles vetorial local, validando o cabeçalho PMTiles v3
  /// antes de instalar atomicamente no diretório gerenciado.
  Future<void> importPmtilesFile({
    required String regionId,
    required String sourceFilePath,
    void Function(double progress, int copiedBytes)? onProgress,
  });

  /// Carrega configuração persistida de URLs personalizadas (.mbtiles).
  Future<Map<String, dynamic>> loadUrlConfig();

  /// Persiste configuração de URLs personalizadas (.mbtiles).
  Future<void> saveUrlConfig(Map<String, dynamic> config);

  /// Fecha as conexões SQLite e remove fisicamente o arquivo de mapa do disco.
  Future<void> deleteRegion(String regionId);

  /// Reescaneia o diretório e sincroniza as conexões SQLite abertas.
  Future<void> reload();

  /// Encerra todas as conexões SQLite abertas.
  void dispose();
}
