import '../map_engine_adapter.dart';

/// Pacotes oficialmente publicados e verificados.
///
/// Nenhum pacote vetorial foi validado e publicado para este catálogo ainda.
/// Arquivos já existentes em disco não são removidos por esta lista vazia.
class OfflineMapCatalog {
  OfflineMapCatalog._();

  static final List<OfflineMapPackageManifest> defaultCatalog =
      List.unmodifiable(<OfflineMapPackageManifest>[]);

  static OfflineMapPackageManifest? findById(String id) {
    for (final package in defaultCatalog) {
      if (package.id == id) return package;
    }
    return null;
  }
}
