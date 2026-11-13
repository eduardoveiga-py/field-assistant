import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/app_logger.dart';
import '../../core/app_version.dart';
import 'mbtiles_backend.dart';
import 'mbtiles_web.dart' if (dart.library.io) 'mbtiles_native.dart';

/// Exceção lançada em caso de erro no download de pacotes MBTiles
class MBTilesDownloadException implements Exception {
  final String message;
  final int? statusCode;

  const MBTilesDownloadException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

/// Metadados de um pacote regional de mapas offline (.mbtiles)
class MBTileRegion {
  final String id;
  final String country;
  final String state;
  final String name;
  final String description;
  final int minZoom;
  final int maxZoom;
  final int sizeBytes;
  final bool isInstalled;
  final double downloadProgress; // 0.0 a 1.0
  final String? downloadUrl;

  const MBTileRegion({
    required this.id,
    required this.country,
    required this.state,
    required this.name,
    required this.description,
    this.minZoom = 6,
    this.maxZoom = 18,
    required this.sizeBytes,
    this.isInstalled = false,
    this.downloadProgress = 0.0,
    this.downloadUrl,
  });

  /// URL canônica para download do pacote .mbtiles
  String get effectiveDownloadUrl =>
      downloadUrl ??
      'https://github.com/${AppVersion.githubRepo}/releases/download/mbtiles-v1/$id.mbtiles';

  String get formattedSize {
    final mb = sizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  MBTileRegion copyWith({
    bool? isInstalled,
    double? downloadProgress,
    int? sizeBytes,
    String? downloadUrl,
    bool clearDownloadUrl = false,
  }) {
    return MBTileRegion(
      id: id,
      country: country,
      state: state,
      name: name,
      description: description,
      minZoom: minZoom,
      maxZoom: maxZoom,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      isInstalled: isInstalled ?? this.isInstalled,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadUrl: clearDownloadUrl ? null : (downloadUrl ?? this.downloadUrl),
    );
  }
}

/// Serviço de gerenciamento de pacotes regionais SQLite .mbtiles
/// Oferece leitura offline ultrarrápida (<0.2ms) e sem risco de banimento de IP no OSM.
class MBTilesService {
  static MBTilesService instance = MBTilesService._internal();

  MBTilesService._internal([MBTilesBackend? backend])
      : _backend = backend ?? getMBTilesBackend();

  @visibleForTesting
  static void setMockInstance(MBTilesService service) {
    instance = service;
  }

  @visibleForTesting
  factory MBTilesService.custom({MBTilesBackend? backend}) {
    return MBTilesService._internal(backend);
  }

  final MBTilesBackend _backend;

  /// Alterado quando um pacote é instalado, substituído ou removido.
  final ValueNotifier<int> tilesRevision = ValueNotifier<int>(0);


  final StreamController<List<MBTileRegion>> _regionsController =
      StreamController<List<MBTileRegion>>.broadcast();

  final Map<String, http.Client> _activeClients = {};
  final Set<String> _cancelledRegions = {};
  String? _customBaseUrl;
  final Map<String, String> _customRegionUrls = {};
  final Map<String, String> _customRegionNames = {};

  String? get customBaseUrl => _customBaseUrl;

  String? getRegionCustomUrl(String regionId) => _customRegionUrls[regionId];

  Stream<List<MBTileRegion>> get regionsStream => _regionsController.stream;

  // Catálogo hierárquico padrão com territórios teocráticos estratégicos estilo Organic Maps (23 regiões do Brasil)
  // NOTA: isInstalled inicia como false para todas as regiões. O status real é determinado
  // pela checagem física de existência de arquivo no disco pelo backend nativo.
  static const List<MBTileRegion> _defaultCatalog = [
    MBTileRegion(
      id: 'br_am_solimoes',
      country: 'Brasil',
      state: 'Amazonas',
      name: 'Santo Antônio do Içá e entorno (experimental)',
      description:
          'Retângulo de SAI e entorno; não cobre todo o Alto Solimões. Aldeias, rios e caminhos podem estar incompletos. Não usar para navegação.',
      minZoom: 8,
      maxZoom: 16,
      sizeBytes: 120 * 1024 * 1024,
      isInstalled: false, // Não é mais estaticamente pré-instalado
    ),
    MBTileRegion(
      id: 'br_am_manaus',
      country: 'Brasil',
      state: 'Amazonas',
      name: 'Manaus, Rio Negro & Baixo Amazonas',
      description:
          'Capital amazonense, comunidades ribeirinhas e municípios de Itacoatiara e Parintins.',
      minZoom: 6,
      maxZoom: 17,
      sizeBytes: 52 * 1024 * 1024,
    ),
    MBTileRegion(
      id: 'br_rr_yanomami',
      country: 'Brasil',
      state: 'Roraima',
      name: 'Terra Indígena Yanomami & Surucucu',
      description:
          'Região Norte de Roraima cobrindo postos e comunidades da bacia dos rios Catrimani e Mucajaí.',
      minZoom: 6,
      maxZoom: 17,
      sizeBytes: 28 * 1024 * 1024, // 28 MB
    ),
    MBTileRegion(
      id: 'br_rr_boavista',
      country: 'Brasil',
      state: 'Roraima',
      name: 'Boa Vista, Pacaraima & Fronteira Venezuela',
      description:
          'Capital e corredor migratório ao longo da BR-174 com alta densidade ministerial multilíngue.',
      minZoom: 6,
      maxZoom: 17,
      sizeBytes: 31 * 1024 * 1024,
    ),
    MBTileRegion(
      id: 'br_ma_guajajara',
      country: 'Brasil',
      state: 'Maranhão',
      name: 'Terra Indígena Arariboia (Guajajara)',
      description:
          'Aldeias e municípios adjacentes no centro-sul do Maranhão (Amargosa, Lagoa Comprida).',
      minZoom: 6,
      maxZoom: 17,
      sizeBytes: 35 * 1024 * 1024, // 35 MB
    ),
    MBTileRegion(
      id: 'br_ma_saoluis',
      country: 'Brasil',
      state: 'Maranhão',
      name: 'São Luís, Imperatriz & Litoral Maranhense',
      description:
          'Região metropolitana da ilha de São Luís, Baixada Maranhense e polo de Imperatriz.',
      minZoom: 7,
      maxZoom: 17,
      sizeBytes: 44 * 1024 * 1024,
    ),
    MBTileRegion(
      id: 'br_pa_belem',
      country: 'Brasil',
      state: 'Pará',
      name: 'Belém, Santarém & Arquipélago do Marajó',
      description:
          'Metrópole paraense, orla fluvial amazônica e rotas ribeirinhas do Baixo Amazonas.',
      minZoom: 6,
      maxZoom: 17,
      sizeBytes: 58 * 1024 * 1024,
    ),
    MBTileRegion(
      id: 'br_ac_riobranco',
      country: 'Brasil',
      state: 'Acre',
      name: 'Rio Branco & Cruzeiro do Sul (Vale do Juruá)',
      description:
          'Capital acreana, fronteira com o Peru e comunidades isoladas na floresta amazônica.',
      minZoom: 6,
      maxZoom: 17,
      sizeBytes: 26 * 1024 * 1024,
    ),
    MBTileRegion(
      id: 'br_ro_portovelho',
      country: 'Brasil',
      state: 'Rondônia',
      name: 'Porto Velho & Ji-Paraná (Corredor BR-364)',
      description:
          'Bacia do Rio Madeira, polos agropecuários e congregações ao longo do eixo rodoviário.',
      minZoom: 6,
      maxZoom: 17,
      sizeBytes: 34 * 1024 * 1024,
    ),
    MBTileRegion(
      id: 'br_ap_macapa',
      country: 'Brasil',
      state: 'Amapá',
      name: 'Macapá, Santana & Oiapoque (Fronteira Guiana)',
      description:
          'Linha do Equador, foz do Rio Amazonas e território de fronteira franco-brasileira.',
      minZoom: 6,
      maxZoom: 17,
      sizeBytes: 24 * 1024 * 1024,
    ),
    MBTileRegion(
      id: 'br_sp_capital',
      country: 'Brasil',
      state: 'São Paulo',
      name: 'São Paulo — Capital & Grande ABC',
      description:
          'Zonas urbanas, bairros metropolitanos e periferias com alta densidade de revisitas.',
      minZoom: 8,
      maxZoom: 18,
      sizeBytes: 85 * 1024 * 1024, // 85 MB
    ),
    MBTileRegion(
      id: 'br_sp_campinas',
      country: 'Brasil',
      state: 'São Paulo',
      name: 'Campinas, Sorocaba & Vale do Paraíba',
      description:
          'Polo tecnológico paulista, eixo Dutra e cidades do interior com intenso campo teocrático.',
      minZoom: 7,
      maxZoom: 17,
      sizeBytes: 64 * 1024 * 1024,
    ),
    MBTileRegion(
      id: 'br_sp_litoral',
      country: 'Brasil',
      state: 'São Paulo',
      name: 'Baixada Santista & Litoral Norte / Sul',
      description:
          'Santos, São Vicente, Guarujá, Ubatuba, Caraguatatuba e orla marítima paulista.',
      minZoom: 7,
      maxZoom: 17,
      sizeBytes: 38 * 1024 * 1024,
    ),
    MBTileRegion(
      id: 'br_rj_capital',
      country: 'Brasil',
      state: 'Rio de Janeiro',
      name: 'Rio de Janeiro — Capital, Niterói & Baixada',
      description:
          'Zona Sul, Norte, Oeste, Baixada Fluminense e conurbação leste da Baía de Guanabara.',
      minZoom: 8,
      maxZoom: 18,
      sizeBytes: 76 * 1024 * 1024,
    ),
    MBTileRegion(
      id: 'br_rj_serra',
      country: 'Brasil',
      state: 'Rio de Janeiro',
      name: 'Região Serrana, Região dos Lagos & Norte Fluminense',
      description:
          'Petrópolis, Teresópolis, Nova Friburgo, Cabo Frio, Campos dos Goytacazes e Macaé.',
      minZoom: 7,
      maxZoom: 17,
      sizeBytes: 42 * 1024 * 1024,
    ),
    MBTileRegion(
      id: 'br_mg_bh',
      country: 'Brasil',
      state: 'Minas Gerais',
      name: 'Belo Horizonte & Região Metropolitana',
      description:
          'Capital mineira, Contagem, Betim e cidades históricas vizinhas com vastos territórios.',
      minZoom: 8,
      maxZoom: 18,
      sizeBytes: 68 * 1024 * 1024,
    ),
    MBTileRegion(
      id: 'br_mg_triangulo',
      country: 'Brasil',
      state: 'Minas Gerais',
      name: 'Triângulo Mineiro & Alto Paranaíba (Uberlândia/Uberaba)',
      description:
          'Pólo agroindustrial e congregações dinâmicas do interior de Minas Gerais.',
      minZoom: 7,
      maxZoom: 17,
      sizeBytes: 48 * 1024 * 1024,
    ),
    MBTileRegion(
      id: 'br_pr_curitiba',
      country: 'Brasil',
      state: 'Paraná',
      name: 'Curitiba & Região Metropolitana',
      description:
          'Planalto paranaense, bairros planejados e municípios limítrofes da grande Curitiba.',
      minZoom: 8,
      maxZoom: 18,
      sizeBytes: 54 * 1024 * 1024,
    ),
    MBTileRegion(
      id: 'br_pr_foz',
      country: 'Brasil',
      state: 'Paraná',
      name: 'Foz do Iguaçu, Cascavel & Fronteira Tríplice',
      description:
          'Território internacional fronteiriço com Paraguai e Argentina e oeste do Paraná.',
      minZoom: 7,
      maxZoom: 17,
      sizeBytes: 39 * 1024 * 1024,
    ),
    MBTileRegion(
      id: 'br_rs_portoalegre',
      country: 'Brasil',
      state: 'Rio Grande do Sul',
      name: 'Porto Alegre, Vale dos Sinos & Serra Gaúcha',
      description:
          'Capital gaúcha, Caxias do Sul, Bento Gonçalves e cidades de colonização europeia.',
      minZoom: 7,
      maxZoom: 17,
      sizeBytes: 62 * 1024 * 1024,
    ),
    MBTileRegion(
      id: 'br_sc_floripa',
      country: 'Brasil',
      state: 'Santa Catarina',
      name: 'Florianópolis, Joinville & Vale do Itajaí (Blumenau)',
      description:
          'Ilha e continente catarinense, pólo fabril do norte e vale têxtil europeu.',
      minZoom: 7,
      maxZoom: 17,
      sizeBytes: 47 * 1024 * 1024,
    ),
    MBTileRegion(
      id: 'br_ba_salvador',
      country: 'Brasil',
      state: 'Bahia',
      name: 'Salvador, Recôncavo & Feira de Santana',
      description:
          'Primeira capital do Brasil, Baía de Todos os Santos e maior entroncamento do Nordeste.',
      minZoom: 7,
      maxZoom: 17,
      sizeBytes: 59 * 1024 * 1024,
    ),
    MBTileRegion(
      id: 'br_df_brasilia',
      country: 'Brasil',
      state: 'Distrito Federal & Goiás',
      name: 'Brasília (DF), Entorno Metropolitano & Goiânia',
      description:
          'Planalto Central, Plano Piloto, Cidades Satélites e conurbação de Goiânia/Aparecida.',
      minZoom: 7,
      maxZoom: 17,
      sizeBytes: 55 * 1024 * 1024,
    ),
  ];

  final List<MBTileRegion> _currentRegions = List.of(_defaultCatalog);

  List<MBTileRegion> get currentRegions => List.unmodifiable(_currentRegions);

  int get totalDownloadedSizeBytes {
    return _currentRegions
        .where((r) => r.isInstalled)
        .fold(0, (sum, r) => sum + r.sizeBytes);
  }

  String get formattedTotalDownloadedSize {
    final mb = totalDownloadedSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// Inicializa o backend nativo, carrega URLs personalizadas persistidas
  /// e atualiza o status de instalação verificando os arquivos em disco.
  Future<void> init() async {
    await _backend.init();
    await _loadUrlConfig();
    await refreshInstalledStatus();
  }

  Future<void> _loadUrlConfig() async {
    final cfg = await _backend.loadUrlConfig();
    final base = cfg['baseUrl']?.toString().trim();
    _customBaseUrl = (base != null && base.isNotEmpty) ? base : null;

    _customRegionUrls.clear();
    final rawRegions = cfg['regionUrls'];
    if (rawRegions is Map) {
      rawRegions.forEach((k, v) {
        final key = k.toString().trim();
        final val = v.toString().trim();
        if (key.isNotEmpty && val.isNotEmpty) {
          _customRegionUrls[key] = val;
        }
      });
    }

    _customRegionNames.clear();
    final rawNames = cfg['customRegionNames'];
    if (rawNames is Map) {
      rawNames.forEach((k, v) {
        final key = k.toString().trim();
        final val = v.toString().trim();
        if (key.isNotEmpty && val.isNotEmpty) {
          _customRegionNames[key] = val;
        }
      });
    }
  }

  Future<void> _persistUrlConfig() {
    return _backend.saveUrlConfig({
      if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty)
        'baseUrl': _customBaseUrl,
      'regionUrls': Map<String, String>.from(_customRegionUrls),
      'customRegionNames': Map<String, String>.from(_customRegionNames),
    });
  }

  static void _validateOptionalHttpUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return;
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      throw const FormatException(
        'URL inválida. Informe um endereço completo iniciado por https:// ou http://',
      );
    }
  }

  /// Resolve a URL de download efetiva para a região (URL específica -> URL base -> padrão GitHub mbtiles-v1).
  String resolveDownloadUrl(MBTileRegion region) {
    final perRegion = _customRegionUrls[region.id];
    if (perRegion != null && perRegion.isNotEmpty) {
      return perRegion;
    }
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      final cleanBase = _customBaseUrl!.endsWith('/')
          ? _customBaseUrl!.substring(0, _customBaseUrl!.length - 1)
          : _customBaseUrl!;
      return '$cleanBase/${region.id}.mbtiles';
    }
    return region.effectiveDownloadUrl;
  }

  /// Configura e persiste localmente uma URL base personalizada para o catálogo `.mbtiles`.
  /// Passe `null` ou string vazia para restaurar o padrão oficial do repositório.
  Future<void> setBaseCatalogUrl(String? url) async {
    final trimmed = url?.trim();
    _validateOptionalHttpUrl(trimmed);
    _customBaseUrl = (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;
    await _persistUrlConfig();
    await refreshInstalledStatus();
  }

  /// Configura e persiste localmente uma URL personalizada para uma região específica.
  /// Passe `null` ou string vazia para remover o override da região.
  Future<void> setRegionCustomUrl(String regionId, String? url) async {
    final trimmed = url?.trim();
    _validateOptionalHttpUrl(trimmed);
    if (trimmed != null && trimmed.isNotEmpty) {
      _customRegionUrls[regionId] = trimmed;
    } else {
      _customRegionUrls.remove(regionId);
    }
    await _persistUrlConfig();
    await refreshInstalledStatus();
  }

  /// Importa um arquivo `.mbtiles` local via caminho em disco, validando cabeçalho SQLite
  /// e tabela `tiles` antes de disponibilizá-lo para o mapa offline.
  Future<MBTileRegion> importLocalMbtiles({
    String? regionId,
    required String sourceFilePath,
    String? displayName,
    void Function(double progress, int copiedBytes)? onProgress,
  }) async {
    await _backend.init();
    String targetId = (regionId ?? '').trim();
    final fileName = sourceFilePath.split(RegExp(r'[/\\]')).last;
    final stem = fileName.toLowerCase().endsWith('.mbtiles')
        ? fileName.substring(0, fileName.length - '.mbtiles'.length)
        : fileName;

    if (targetId.isEmpty) {
      final sanitized = stem
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      targetId = sanitized.isNotEmpty ? 'local_$sanitized' : 'local_mbtiles';
    }

    await _backend.importRegionFile(
      regionId: targetId,
      sourceFilePath: sourceFilePath,
      onProgress: onProgress,
    );

    tilesRevision.value++;
    final isDefault = _defaultCatalog.any((r) => r.id == targetId);
    if (!isDefault) {
      final label = (displayName != null && displayName.trim().isNotEmpty)
          ? displayName.trim()
          : (stem.trim().isNotEmpty ? stem.trim() : targetId);
      _customRegionNames[targetId] = label;
      await _persistUrlConfig();
    }

    await refreshInstalledStatus();
    return _currentRegions.firstWhere((r) => r.id == targetId);
  }

  /// Verifica se uma região está instalada no disco.
  bool isRegionInstalled(String regionId) {
    return _backend.isRegionInstalled(regionId);
  }

  /// Atualiza o status `isInstalled`, URLs resolvidas e tamanho em bytes de cada região.
  Future<void> refreshInstalledStatus() async {
    final installedIds = _backend.getInstalledRegionIds();
    final updatedList = <MBTileRegion>[];
    final knownIds = <String>{};

    for (final baseRegion in _defaultCatalog) {
      knownIds.add(baseRegion.id);
      final isInstalled = installedIds.contains(baseRegion.id);
      final realSize = _backend.getRegionFileSize(baseRegion.id);
      final customUrl = _customRegionUrls[baseRegion.id] ??
          (_customBaseUrl != null && _customBaseUrl!.isNotEmpty
              ? resolveDownloadUrl(baseRegion)
              : null);
      updatedList.add(
        baseRegion.copyWith(
          isInstalled: isInstalled,
          downloadProgress: isInstalled ? 1.0 : 0.0,
          sizeBytes: realSize ?? baseRegion.sizeBytes,
          downloadUrl: customUrl,
          clearDownloadUrl: customUrl == null,
        ),
      );
    }

    for (final id in installedIds) {
      if (knownIds.contains(id)) continue;
      final realSize = _backend.getRegionFileSize(id) ?? 0;
      final label = _customRegionNames[id] ??
          id.replaceFirst(RegExp(r'^local_'), '').replaceAll('_', ' ');
      updatedList.add(
        MBTileRegion(
          id: id,
          country: 'Importado Localmente',
          state: 'Pacote .mbtiles',
          name: label,
          description: 'Pacote .mbtiles local validado (SQLite + tabela tiles).',
          sizeBytes: realSize,
          isInstalled: true,
          downloadProgress: 1.0,
          downloadUrl: _customRegionUrls[id],
        ),
      );
    }

    _currentRegions
      ..clear()
      ..addAll(updatedList);
    _regionsController.add(List.of(_currentRegions));
  }

  /// Busca bloco diretamente de pacotes .mbtiles locais (<0.2ms)
  Future<Uint8List?> getTile(int z, int x, int y) {
    return _backend.getTile(z, x, y);
  }

  /// Informa se um download está ativamente em andamento para a região.
  bool isDownloading(String regionId) => _activeClients.containsKey(regionId);

  /// Cancela o download em andamento de uma região.
  void cancelDownload(String regionId) {
    _cancelledRegions.add(regionId);
    final client = _activeClients.remove(regionId);
    if (client != null) {
      client.close();
      AppLogger.info('Download cancelado pelo usuário para região: $regionId');
      final idx = _currentRegions.indexWhere((r) => r.id == regionId);
      if (idx != -1) {
        final stillInstalled = _backend.isRegionInstalled(regionId);
        _currentRegions[idx] = _currentRegions[idx].copyWith(
          downloadProgress: stillInstalled ? 1.0 : 0.0,
          isInstalled: stillInstalled,
        );
        _regionsController.add(List.of(_currentRegions));
      }
    }
  }

  /// Baixa um pacote de mapas regional via HTTP streaming real, persistindo em disco.
  /// Suporta injeção de [httpClient] para testes automatizados.
  Future<void> downloadRegion(
    String regionId, {
    http.Client? httpClient,
    void Function(double progress, int downloadedBytes)? onProgress,
  }) async {
    final idx = _currentRegions.indexWhere((r) => r.id == regionId);
    if (idx == -1) {
      throw ArgumentError('Região $regionId não encontrada no catálogo.');
    }

    if (_activeClients.containsKey(regionId)) {
      AppLogger.warning('Download já em andamento para região: $regionId');
      return;
    }

    final target = _currentRegions[idx];
    final ownsClient = httpClient == null;
    final client = httpClient ?? http.Client();
    _cancelledRegions.remove(regionId);
    _activeClients[regionId] = client;

    try {
      _regionsController.add(List.of(_currentRegions));

      final resolvedUrl = resolveDownloadUrl(target);
      final uri = Uri.parse(resolvedUrl);
      final request = http.Request('GET', uri);
      request.headers['User-Agent'] = AppVersion.userAgent;

      final streamedResponse = await client.send(request);
      if (_cancelledRegions.contains(regionId)) {
        throw const MBTilesDownloadException('Download cancelado pelo usuário.');
      }
      if (streamedResponse.statusCode < 200 || streamedResponse.statusCode >= 300) {
        if (streamedResponse.statusCode == 404) {
          throw MBTilesDownloadException(
            'Pacote "${target.name}" indisponível no servidor (HTTP 404) em $resolvedUrl. '
            'Configure uma URL personalizada ou importe um arquivo .mbtiles local.',
            404,
          );
        }
        throw MBTilesDownloadException(
          'Falha no download (${streamedResponse.statusCode}): ${streamedResponse.reasonPhrase}',
          streamedResponse.statusCode,
        );
      }

      final totalBytes = streamedResponse.contentLength ?? target.sizeBytes;

      await _backend.saveRegionStream(
        regionId: regionId,
        byteStream: streamedResponse.stream,
        totalBytes: totalBytes,
        isCancelled: () => _cancelledRegions.contains(regionId),
        onProgress: (progress, downloadedBytes) {
          if (_cancelledRegions.contains(regionId)) return;
          _currentRegions[idx] = target.copyWith(
            downloadProgress: progress,
          );
          _regionsController.add(List.of(_currentRegions));
          onProgress?.call(progress, downloadedBytes);
        },
      );

      tilesRevision.value++;
      if (_cancelledRegions.contains(regionId)) {
        throw const MBTilesDownloadException('Download cancelado pelo usuário.');
      }

      final realSize = _backend.getRegionFileSize(regionId) ?? totalBytes;
      _currentRegions[idx] = target.copyWith(
        isInstalled: true,
        downloadProgress: 1.0,
        sizeBytes: realSize,
      );
      _regionsController.add(List.of(_currentRegions));
    } catch (e) {
      final stillInstalled = _backend.isRegionInstalled(regionId);
      final existingSize = _backend.getRegionFileSize(regionId);
      _currentRegions[idx] = target.copyWith(
        isInstalled: stillInstalled,
        downloadProgress: stillInstalled ? 1.0 : 0.0,
        sizeBytes: existingSize ?? target.sizeBytes,
      );
      _regionsController.add(List.of(_currentRegions));
      AppLogger.error('Erro no download da região $regionId: $e');
      rethrow;
    } finally {
      _activeClients.remove(regionId);
      _cancelledRegions.remove(regionId);
      if (ownsClient) {
        try {
          client.close();
        } catch (e, st) {
          AppLogger.debug('Falha ao fechar cliente HTTP do download MBTiles ($regionId): $e', st);
        }
      }
    }
  }

  /// Exclui um mapa regional instalado (remove o arquivo físico e fecha a conexão SQLite).
  Future<void> deleteRegion(String regionId) async {
    cancelDownload(regionId);

    final idx = _currentRegions.indexWhere((r) => r.id == regionId);
    if (idx == -1) return;

    await _backend.deleteRegion(regionId);
    tilesRevision.value++;
    if (_customRegionNames.remove(regionId) != null) {
      await _persistUrlConfig();
    }
    await refreshInstalledStatus();
  }

  /// Atualiza todos os mapas instalados e retorna a lista de nomes que falharam.
  /// Pacotes importados localmente (`local_*`) sem URL personalizada configurada são preservados sem tentativa de download remoto.
  Future<List<String>> updateAll({
    http.Client? httpClient,
    void Function(String regionName, double progress)? onProgress,
  }) async {
    final installed = _currentRegions.where((r) => r.isInstalled).toList();
    final failed = <String>[];
    for (final reg in installed) {
      final isLocalOnly = reg.id.startsWith('local_') &&
          !_customRegionUrls.containsKey(reg.id) &&
          (_customBaseUrl == null || _customBaseUrl!.isEmpty);
      if (isLocalOnly) {
        continue;
      }
      try {
        await downloadRegion(
          reg.id,
          httpClient: httpClient,
          onProgress: (p, _) => onProgress?.call(reg.name, p),
        );
      } catch (e) {
        failed.add(reg.name);
        AppLogger.warning('Falha ao atualizar mapa ${reg.name}: $e');
      }
    }
    return failed;
  }

  void dispose() {
    for (final client in _activeClients.values) {
      client.close();
    }
    _activeClients.clear();
    _backend.dispose();
    tilesRevision.dispose();
    _regionsController.close();
  }
}
