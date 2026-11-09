import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Estilos de camada de mapa compatíveis com Organic Maps e navegação teocrática
enum MapLayerStyle {
  standard(
    'standard',
    'Padrão (OSM)',
    'Ruas, bairros e povoados com alta clareza cartográfica',
    Icons.map_outlined,
  ),
  satellite(
    'satellite',
    'Satélite (Esri World)',
    'Fotografia aérea real para identificar telhados, trilhas e rios',
    Icons.satellite_alt_rounded,
  ),
  topo(
    'topo',
    'Topográfico (Relevo)',
    'Curvas de nível e hidrografia para áreas rurais e ribeirinhas',
    Icons.terrain_rounded,
  ),
  dark(
    'dark',
    'Modo Noturno (Carto)',
    'Contraste elevado para economia de bateria e ministério à noite',
    Icons.dark_mode_outlined,
  );

  final String id;
  final String label;
  final String description;
  final IconData icon;

  const MapLayerStyle(this.id, this.label, this.description, this.icon);
}

abstract class TileCacheBackend {
  Future<Uint8List?> getTile(int z, int x, int y, [MapLayerStyle? style]);
  Future<void> saveTile(int z, int x, int y, Uint8List bytes, [MapLayerStyle? style]);
  Future<bool> isTileCached(int z, int x, int y, [MapLayerStyle? style]);
  Future<int> getCachedTileCount([MapLayerStyle? style]);
}
