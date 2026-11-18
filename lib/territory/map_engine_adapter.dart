import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

/// Formato de pacote cartográfico offline suportado pelo Map Engine (Nível 2 — FA-MAP-01/02).
enum OfflineMapFormat {
  pmtiles('pmtiles'),
  mbtiles('mbtiles');

  final String wireName;
  const OfflineMapFormat(this.wireName);

  static OfflineMapFormat fromWire(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'pmtiles':
        return OfflineMapFormat.pmtiles;
      case 'mbtiles':
        return OfflineMapFormat.mbtiles;
      default:
        throw FormatException('Formato de mapa offline não suportado: $raw');
    }
  }
}

/// Limites geográficos (bounding box WGS-84) de um pacote cartográfico.
class GeoBoundingBox {
  final double minLat;
  final double minLon;
  final double maxLat;
  final double maxLon;

  const GeoBoundingBox({
    required this.minLat,
    required this.minLon,
    required this.maxLat,
    required this.maxLon,
  });

  bool get isValid =>
      minLat >= -90 &&
      maxLat <= 90 &&
      minLon >= -180 &&
      maxLon <= 180 &&
      minLat < maxLat &&
      minLon < maxLon;

  bool contains(double lat, double lon) =>
      lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon;

  Map<String, dynamic> toJson() => {
    'minLat': minLat,
    'minLon': minLon,
    'maxLat': maxLat,
    'maxLon': maxLon,
  };

  factory GeoBoundingBox.fromJson(Map<String, dynamic> json) {
    final bbox = GeoBoundingBox(
      minLat: (json['minLat'] as num).toDouble(),
      minLon: (json['minLon'] as num).toDouble(),
      maxLat: (json['maxLat'] as num).toDouble(),
      maxLon: (json['maxLon'] as num).toDouble(),
    );
    if (!bbox.isValid) {
      throw const FormatException('Bounding box geográfica inválida.');
    }
    return bbox;
  }
}

/// Manifesto imutável e verificável de pacote cartográfico offline (FA-MAP-02).
/// Impede instalação de URLs mutáveis (`@master`/`@main`), pacotes sem SHA-256
/// ou pacotes sem licença/atribuição explícita (ex.: ODbL).
class OfflineMapPackageManifest {
  final String id;
  final String regionName;
  final Uri downloadUrl;
  final int sizeBytes;
  final String sha256;
  final GeoBoundingBox bbox;
  final int minZoom;
  final int maxZoom;
  final DateTime generatedAt;
  final String version;
  final String license;
  final String attribution;
  final OfflineMapFormat format;
  final int minAppSchemaVersion;

  OfflineMapPackageManifest({
    required this.id,
    required this.regionName,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.sha256,
    required this.bbox,
    required this.minZoom,
    required this.maxZoom,
    required this.generatedAt,
    required this.version,
    required this.license,
    required this.attribution,
    required this.format,
    this.minAppSchemaVersion = 1,
  }) {
    validate();
  }

  static final RegExp _sha256Hex = RegExp(r'^[0-9a-fA-F]{64}$');
  static final RegExp _safeIdPattern = RegExp(r'^[a-z0-9][a-z0-9_-]{1,63}$');

  void validate() {
    if (!_safeIdPattern.hasMatch(id)) {
      throw FormatException('ID de pacote offline inválido: "$id".');
    }
    if (regionName.trim().isEmpty) {
      throw const FormatException('Nome da região ausente no manifesto.');
    }
    final urlStr = downloadUrl.toString();
    if (downloadUrl.scheme != 'https' ||
        urlStr.contains('@master') ||
        urlStr.contains('@main') ||
        urlStr.contains('tile.openstreetmap.org')) {
      throw FormatException(
        'URL de pacote offline rejeitada (exige HTTPS imutável e proíbe bulk download do servidor público OSM): $urlStr',
      );
    }
    if (sizeBytes <= 0) {
      throw const FormatException('Tamanho do pacote deve ser positivo.');
    }
    if (!_sha256Hex.hasMatch(sha256)) {
      throw const FormatException(
        'SHA-256 ausente ou malformado no manifesto.',
      );
    }
    if (!bbox.isValid) {
      throw const FormatException('Bounding box inválida no manifesto.');
    }
    if (minZoom < 0 || maxZoom > 22 || minZoom > maxZoom) {
      throw const FormatException('Intervalo de zoom inválido no manifesto.');
    }
    if (version.trim().isEmpty ||
        license.trim().isEmpty ||
        attribution.trim().isEmpty) {
      throw const FormatException(
        'Versão, licença (ex.: ODbL) e atribuição são obrigatórias no manifesto.',
      );
    }
  }

  /// Valida tamanho e integridade SHA-256 de um pacote baixado antes da instalação atômica.
  bool verifyBytesIntegrity(Uint8List bytes) {
    if (bytes.length != sizeBytes) return false;
    final actual = crypto.sha256.convert(bytes).toString().toLowerCase();
    return actual == sha256.toLowerCase();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'regionName': regionName,
    'downloadUrl': downloadUrl.toString(),
    'sizeBytes': sizeBytes,
    'sha256': sha256.toLowerCase(),
    'bbox': bbox.toJson(),
    'minZoom': minZoom,
    'maxZoom': maxZoom,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'version': version,
    'license': license,
    'attribution': attribution,
    'format': format.wireName,
    'minAppSchemaVersion': minAppSchemaVersion,
  };

  factory OfflineMapPackageManifest.fromJson(Map<String, dynamic> json) {
    return OfflineMapPackageManifest(
      id: json['id'] as String,
      regionName: json['regionName'] as String,
      downloadUrl: Uri.parse(json['downloadUrl'] as String),
      sizeBytes: (json['sizeBytes'] as num).toInt(),
      sha256: json['sha256'] as String,
      bbox: GeoBoundingBox.fromJson(
        Map<String, dynamic>.from(json['bbox'] as Map),
      ),
      minZoom: (json['minZoom'] as num).toInt(),
      maxZoom: (json['maxZoom'] as num).toInt(),
      generatedAt: DateTime.parse(json['generatedAt'] as String).toUtc(),
      version: json['version'] as String,
      license: json['license'] as String,
      attribution: json['attribution'] as String,
      format: OfflineMapFormat.fromWire(json['format'] as String),
      minAppSchemaVersion: (json['minAppSchemaVersion'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Estado de câmera/viewport desacoplado do motor cartográfico (MapLibre Native / Raster fallback).
class MapViewportState {
  final double latitude;
  final double longitude;
  final double zoom;
  final double bearingDegrees;
  final double tiltDegrees;

  const MapViewportState({
    required this.latitude,
    required this.longitude,
    required this.zoom,
    this.bearingDegrees = 0.0,
    this.tiltDegrees = 0.0,
  });
}

/// Capacidades reais declaradas por cada implementação do Map Engine (proibido prometer roteamento offline sem engine local).
class MapEngineCapabilities {
  final bool vectorRendering;
  final bool supportsRotation;
  final bool supportsTilt;
  final bool supportsOfflinePackages;
  final bool supportsOfflineContactsOverlay;
  final bool supportsOfflineRouting;

  const MapEngineCapabilities({
    required this.vectorRendering,
    required this.supportsRotation,
    required this.supportsTilt,
    required this.supportsOfflinePackages,
    required this.supportsOfflineContactsOverlay,
    required this.supportsOfflineRouting,
  });
}

/// Abstração central do Map Engine (FA-MAP-01).
/// Permite evoluir de raster MBTiles para MapLibre Native + PMTiles sem acoplar a UI.
abstract class MapEngineAdapter {
  String get engineName;
  MapEngineCapabilities get capabilities;
  Future<void> initialize();
  Future<void> moveCamera(MapViewportState viewport);
  Future<void> setOfflinePackages(List<OfflineMapPackageManifest> packages);
  void dispose();
}
