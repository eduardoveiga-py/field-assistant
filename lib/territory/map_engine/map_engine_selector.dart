import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../database/app_database.dart';
import '../../ui/widgets/map/maplibre_vector_map_view.dart';
import '../map_engine_adapter.dart';
import '../mbtiles/mbtiles_backend.dart';
import '../mbtiles/mbtiles_service.dart';
import '../sector_manager.dart';
import 'map_asset_manager.dart';
import 'maplibre_native_adapter.dart';
import 'offline_tile_server.dart';
import 'raster_fallback_adapter.dart';

/// Preferência de seleção do motor cartográfico na tela do mapa (FA-MAP-01/02).
enum MapEnginePreference {
  /// Seleciona MapLibre Native automaticamente em plataformas suportadas quando
  /// houver um pacote vetorial (.pmtiles / .mbtiles MVT) instalado; caso contrário
  /// utiliza o fallback raster com segurança.
  auto('Automático (Vetorial quando disponível)'),

  /// Força o uso de MapLibre Native em plataformas suportadas (iOS/Android/Web),
  /// com fallback seguro ao modo raster em desktop.
  vectorMapLibre('MapLibre Vetorial (Nível 2)'),

  /// Mantém o modo Raster/OSM com cache offline e pacotes MBTiles raster.
  rasterFallback('Raster / Clássico');

  final String label;
  const MapEnginePreference(this.label);
}

/// Resultado da resolução de motor cartográfico para [ContactsMapScreen].
class MapEngineSelectionResult {
  final MapEngineAdapter adapter;
  final bool ownsAdapter;
  final String? activePackageId;
  final OfflineMapFormat activePackageFormat;
  final bool usesVectorEngine;
  final MapEnginePreference preference;

  const MapEngineSelectionResult({
    required this.adapter,
    required this.ownsAdapter,
    required this.activePackageId,
    required this.activePackageFormat,
    required this.usesVectorEngine,
    required this.preference,
  });
}

/// Seletor determinístico de motor cartográfico que ativa [MaplibreNativeAdapter]
/// em produção nas plataformas suportadas (iOS/Android/Web) quando há pacote
/// vetorial instalado ou seleção explícita do usuário, preservando fallback seguro
/// para [RasterFallbackAdapter] em desktop, testes e pacotes estritamente raster.
class MapEngineSelector {
  const MapEngineSelector._();

  static MapEngineSelectionResult resolve({
    MapEngineAdapter? overrideAdapter,
    MapEnginePreference preference = MapEnginePreference.auto,
    bool? platformSupportsMapLibre,
    List<InstalledOfflineMapPackage>? installedPackages,
    String? packagesDirectoryPath,
    MBTilesService? mbtilesService,
  }) {
    final service = mbtilesService ?? MBTilesService.instance;
    final packages = installedPackages ?? service.installedPackages;
    final vectorPkg = _pickPrimaryVectorPackage(packages);
    final supportsNative =
        platformSupportsMapLibre ??
        MapLibreVectorMapView.isSupportedOnCurrentPlatform;

    if (overrideAdapter != null) {
      final isVector = overrideAdapter is MaplibreNativeAdapter;
      return MapEngineSelectionResult(
        adapter: overrideAdapter,
        ownsAdapter: false,
        activePackageId: vectorPkg?.id,
        activePackageFormat: vectorPkg?.format ?? OfflineMapFormat.pmtiles,
        usesVectorEngine: isVector && supportsNative,
        preference: preference,
      );
    }

    final shouldUseVector =
        supportsNative &&
        (preference == MapEnginePreference.vectorMapLibre ||
            (preference == MapEnginePreference.auto && vectorPkg != null));

    if (!shouldUseVector) {
      return MapEngineSelectionResult(
        adapter: RasterFallbackAdapter(),
        ownsAdapter: true,
        activePackageId: vectorPkg?.id,
        activePackageFormat: vectorPkg?.format ?? OfflineMapFormat.pmtiles,
        usesVectorEngine: false,
        preference: preference,
      );
    }

    OfflineTileServer? server;
    MapAssetManager? assetManager;
    if (!kIsWeb) {
      final dirPath = packagesDirectoryPath ?? service.packagesDirectoryPath;
      final dir = (dirPath != null && dirPath.isNotEmpty)
          ? Directory(dirPath)
          : null;
      server = OfflineTileServer(
        packagesDir: dir,
        tileLookup: (z, x, y) => service.getTile(z, x, y),
      );
      for (final pkg in packages) {
        final f = File(pkg.filePath);
        if (!f.existsSync()) continue;
        try {
          if (pkg.format == OfflineMapFormat.pmtiles) {
            server.registerPmtilesPackage(pkg.id, f);
          } else {
            server.registerMbtilesPackage(pkg.id, f);
          }
        } catch (_) {
          // Ignora pacotes com ID fora do padrão seguro sem bloquear o mapa.
        }
      }
      assetManager = MapAssetManager();
    }

    return MapEngineSelectionResult(
      adapter: MaplibreNativeAdapter(
        tileServer: server,
        ownsTileServer: server != null,
        assetManager: assetManager,
      ),
      ownsAdapter: true,
      activePackageId: vectorPkg?.id,
      activePackageFormat: vectorPkg?.format ?? OfflineMapFormat.pmtiles,
      usesVectorEngine: true,
      preference: preference,
    );
  }

  static InstalledOfflineMapPackage? _pickPrimaryVectorPackage(
    List<InstalledOfflineMapPackage> packages,
  ) {
    InstalledOfflineMapPackage? firstVectorMbtiles;
    for (final pkg in packages) {
      if (!pkg.isVector) continue;
      if (pkg.format == OfflineMapFormat.pmtiles) return pkg;
      firstVectorMbtiles ??= pkg;
    }
    return firstVectorMbtiles;
  }

  /// Paleta estável para polígonos de setores territoriais no MapLibre GeoJSON.
  static const List<String> _sectorPalette = [
    '#2563eb',
    '#0d9488',
    '#d97706',
    '#7c3aed',
    '#dc2626',
    '#059669',
  ];

  /// Converte os setores territoriais (`TerritorySector`) e os contatos geocodificados
  /// em mapas compatíveis com [MaplibreNativeAdapter.buildSectorsGeoJson],
  /// construindo um polígono envoltório seguro (convex hull ou caixa mínima) para
  /// cada setor com contatos geolocalizados, sem alterar o esquema do banco Drift.
  static List<Map<String, dynamic>> buildSectorOverlayMaps({
    required List<TerritorySector> sectors,
    required List<PersonEntry> contacts,
  }) {
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < sectors.length; i++) {
      final sector = sectors[i];
      final normalizedName = sector.name.trim().toLowerCase();
      if (normalizedName.isEmpty) continue;

      final pts = <math.Point<double>>[];
      for (final c in contacts) {
        final lat = c.latitude;
        final lng = c.longitude;
        final addr = (c.address ?? '').toLowerCase();
        if (lat == null ||
            lng == null ||
            (lat == 0.0 && lng == 0.0) ||
            lat.abs() > 90 ||
            lng.abs() > 180) {
          continue;
        }
        if (addr.contains(normalizedName)) {
          pts.add(math.Point<double>(lng, lat));
        }
      }
      if (pts.isEmpty) continue;

      final ring = _buildPolygonRing(pts);
      result.add({
        'id': sector.id,
        'code': sector.name,
        'name': sector.name,
        'color': _sectorPalette[i % _sectorPalette.length],
        'coordinates': [ring],
      });
    }
    return result;
  }

  static List<List<double>> _buildPolygonRing(List<math.Point<double>> points) {
    if (points.length < 3) {
      double minX = points.first.x;
      double maxX = points.first.x;
      double minY = points.first.y;
      double maxY = points.first.y;
      for (final p in points) {
        if (p.x < minX) minX = p.x;
        if (p.x > maxX) maxX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.y > maxY) maxY = p.y;
      }
      const pad = 0.0012;
      minX -= pad;
      maxX += pad;
      minY -= pad;
      maxY += pad;
      return [
        [minX, minY],
        [maxX, minY],
        [maxX, maxY],
        [minX, maxY],
        [minX, minY],
      ];
    }

    final sorted = List<math.Point<double>>.from(points)
      ..sort((a, b) => a.x != b.x ? a.x.compareTo(b.x) : a.y.compareTo(b.y));

    double cross(
      math.Point<double> o,
      math.Point<double> a,
      math.Point<double> b,
    ) => (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);

    final lower = <math.Point<double>>[];
    for (final p in sorted) {
      while (lower.length >= 2 &&
          cross(lower[lower.length - 2], lower[lower.length - 1], p) <= 0) {
        lower.removeLast();
      }
      lower.add(p);
    }

    final upper = <math.Point<double>>[];
    for (final p in sorted.reversed) {
      while (upper.length >= 2 &&
          cross(upper[upper.length - 2], upper[upper.length - 1], p) <= 0) {
        upper.removeLast();
      }
      upper.add(p);
    }

    lower.removeLast();
    upper.removeLast();
    final hull = [...lower, ...upper];
    if (hull.length < 3) {
      return _buildPolygonRing([sorted.first, sorted.last]);
    }
    final ring = hull.map((p) => [p.x, p.y]).toList();
    ring.add([hull.first.x, hull.first.y]);
    return ring;
  }
}
