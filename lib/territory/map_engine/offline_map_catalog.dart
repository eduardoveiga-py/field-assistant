import '../map_engine_adapter.dart';

/// Catálogo Canônico Imutável de Pacotes Cartográficos Oficiais (FA-MAP-02).
///
/// Todos os manifestos utilizam HTTPS imutável (sem `@master`/`@main`),
/// SHA-256 estrito, licença ODbL e bounding box geográfico válido.
class OfflineMapCatalog {
  OfflineMapCatalog._();

  /// Pacote vetorial oficial regional do Alto Solimões (PMTiles v3).
  ///
  /// Cobre Santo Antônio do Içá, Aldeia Betânia (Ticuna) e Lago Grande.
  /// Contém camadas MVT: water, waterways, transportation, places, poi (zooms 8 a 16).
  static final OfflineMapPackageManifest altoSolimoesVectorPackage =
      OfflineMapPackageManifest(
        id: 'alto_solimoes_sai_vector',
        regionName: 'Alto Solimões — Santo Antônio do Içá, Betânia & Lago Grande (Vetorial PMTiles)',
        downloadUrl: Uri.parse(
          'https://github.com/field-assistant/field-assistant/releases/download/v2.0.0/alto_solimoes.pmtiles',
        ),
        sizeBytes: 15728640, // 15 MB
        sha256:
            '61d368e5461c360877918fcf57a4a2ad554f24ef5eecde9d4ef7b5bc6082ee20',
        bbox: const GeoBoundingBox(
          minLat: -3.4000,
          minLon: -68.2000,
          maxLat: -3.0000,
          maxLon: -67.7000,
        ),
        minZoom: 8,
        maxZoom: 16,
        generatedAt: DateTime.utc(2026, 11, 18),
        version: '2.0.0',
        license: 'ODbL-1.0',
        attribution: '© OpenStreetMap contributors',
        format: OfflineMapFormat.pmtiles,
      );

  /// Lista imutável de todos os pacotes oficiais homologados.
  static final List<OfflineMapPackageManifest> defaultCatalog =
      List.unmodifiable([altoSolimoesVectorPackage]);

  /// Localiza um manifesto pelo identificador canônico.
  static OfflineMapPackageManifest? findById(String id) {
    try {
      return defaultCatalog.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}
