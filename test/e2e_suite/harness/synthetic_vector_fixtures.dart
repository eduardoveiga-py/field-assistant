import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ministerio_pessoal/territory/map_engine/pmtiles_reader.dart';

/// Coordenadas e geometrias geográficas canônicas da bacia do Alto Solimões (Amazonas)
/// para testes de navegação, roteamento offline A*, busca FTS5 e isolamento fluvial.
class AmazonianCoordinates {
  AmazonianCoordinates._();

  /// Sede municipal de Santo Antônio do Içá (AM)
  static const double santoAntonioLat = -3.1022;
  static const double santoAntonioLon = -67.9397;

  /// Comunidade indígena Ticuna de Betânia (Rio Jandiatuba)
  static const double betaniaLat = -3.1700;
  static const double betaniaLon = -68.0800;

  /// Comunidade ribeirinha de Lago Grande
  static const double lagoGrandeLat = -3.2500;
  static const double lagoGrandeLon = -67.8500;

  /// Envelope regional do Alto Solimões (Bounding Box)
  static const double minLat = -3.4000;
  static const double minLon = -68.2000;
  static const double maxLat = -3.0000;
  static const double maxLon = -67.7000;

  /// Borda fluvial do Rio Solimões (barreira natural intransponível por vias terrestres sem balsa)
  static const double solimoesNorthLat = -3.2000;
  static const double solimoesSouthLat = -3.3800;
  static const double solimoesWestLon = -68.2500;
  static const double solimoesEastLon = -67.7000;

  /// Retorna se a coordenada informada reside dentro do envelope do Alto Solimões.
  static bool containsCoordinate(double lat, double lon) {
    return lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon;
  }

  /// Calcula a distância geográfica direta via fórmula de Haversine (em metros).
  static double haversineDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusMeters = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  /// Detecta se um trajeto direto entre dois pontos cruza perpendicularmente a calha do Rio Solimões,
  /// o que violaria o princípio de impedância infinita para navegação puramente terrestre sem balsa.
  static bool isFluvialBarrierCrossing(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final withinLonBand =
        (lon1 >= solimoesWestLon && lon1 <= solimoesEastLon) ||
        (lon2 >= solimoesWestLon && lon2 <= solimoesEastLon);
    if (!withinLonBand) return false;

    // Travessia entre a margem norte (Santo Antônio do Içá / Betânia, lat > -3.20)
    // e a margem sul (Lago Grande, lat < -3.20)
    return (lat1 > solimoesNorthLat && lat2 < solimoesNorthLat) ||
        (lat2 > solimoesNorthLat && lat1 < solimoesNorthLat);
  }
}

/// Descritor de tile para síntese de arquivos PMTiles v3.
class SyntheticTileSpec {
  final int z;
  final int x;
  final int y;
  final Uint8List data;

  const SyntheticTileSpec({
    required this.z,
    required this.x,
    required this.y,
    required this.data,
  });
}

/// Gerador sintético de pacotes binários oficiais PMTiles v3 (127-byte header,
/// ordenação de curva de Hilbert, diretórios varint e blocos de dados de tiles).
class SyntheticVectorFixtures {
  SyntheticVectorFixtures._();

  static void _writeVarint(BytesBuilder out, int value) {
    var v = value;
    while (v >= 0x80) {
      out.addByte((v & 0x7f) | 0x80);
      v >>= 7;
    }
    out.addByte(v & 0x7f);
  }

  static Uint8List _encodeDirectory(List<PmtilesEntry> entries) {
    final out = BytesBuilder();
    _writeVarint(out, entries.length);

    var lastId = 0;
    for (final e in entries) {
      _writeVarint(out, e.tileId - lastId);
      lastId = e.tileId;
    }
    for (final e in entries) {
      _writeVarint(out, e.runLength);
    }
    for (final e in entries) {
      _writeVarint(out, e.length);
    }
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      if (i > 0 && e.offset == entries[i - 1].offset + entries[i - 1].length) {
        _writeVarint(out, 0);
      } else {
        _writeVarint(out, e.offset + 1);
      }
    }
    return out.takeBytes();
  }

  static void _setUint64LE(ByteData bd, int offset, int value) {
    bd.setUint32(offset, value & 0xffffffff, Endian.little);
    bd.setUint32(offset + 4, (value >> 32) & 0xffffffff, Endian.little);
  }

  /// Constrói o cabeçalho canônico oficial de 127 bytes PMTiles v3.
  static Uint8List buildV3Header({
    required int rootDirOffset,
    required int rootDirLength,
    int jsonMetadataOffset = 0,
    int jsonMetadataLength = 0,
    int leafDirsOffset = 0,
    int leafDirsLength = 0,
    int tileDataOffset = 0,
    int tileDataLength = 0,
    int numAddressedTiles = 1,
    int numTileEntries = 1,
    int numTileContents = 1,
    PmtilesCompression internalCompression = PmtilesCompression.none,
    PmtilesCompression tileCompression = PmtilesCompression.none,
    PmtilesTileType tileType = PmtilesTileType.mvt,
    int minZoom = 0,
    int maxZoom = 14,
    double minLon = AmazonianCoordinates.minLon,
    double minLat = AmazonianCoordinates.minLat,
    double maxLon = AmazonianCoordinates.maxLon,
    double maxLat = AmazonianCoordinates.maxLat,
    int centerZoom = 10,
    double centerLon = AmazonianCoordinates.santoAntonioLon,
    double centerLat = AmazonianCoordinates.santoAntonioLat,
    int specVersion = 3,
    List<int>? customMagic,
  }) {
    final bytes = Uint8List(127);
    final magic = customMagic ?? PmtilesHeader.magicBytes;
    for (var i = 0; i < magic.length && i < 7; i++) {
      bytes[i] = magic[i];
    }
    bytes[7] = specVersion;
    final bd = ByteData.sublistView(bytes);
    _setUint64LE(bd, 8, rootDirOffset);
    _setUint64LE(bd, 16, rootDirLength);
    _setUint64LE(bd, 24, jsonMetadataOffset);
    _setUint64LE(bd, 32, jsonMetadataLength);
    _setUint64LE(bd, 40, leafDirsOffset);
    _setUint64LE(bd, 48, leafDirsLength);
    _setUint64LE(bd, 56, tileDataOffset);
    _setUint64LE(bd, 64, tileDataLength);
    _setUint64LE(bd, 72, numAddressedTiles);
    _setUint64LE(bd, 80, numTileEntries);
    _setUint64LE(bd, 88, numTileContents);
    bytes[96] = 1; // clustered
    bytes[97] = internalCompression.code;
    bytes[98] = tileCompression.code;
    bytes[99] = tileType.code;
    bytes[100] = minZoom;
    bytes[101] = maxZoom;
    bd.setInt32(102, (minLon * 10000000).round(), Endian.little);
    bd.setInt32(106, (minLat * 10000000).round(), Endian.little);
    bd.setInt32(110, (maxLon * 10000000).round(), Endian.little);
    bd.setInt32(114, (maxLat * 10000000).round(), Endian.little);
    bytes[118] = centerZoom;
    bd.setInt32(119, (centerLon * 10000000).round(), Endian.little);
    bd.setInt32(123, (centerLat * 10000000).round(), Endian.little);
    return bytes;
  }

  /// Sintetiza um arquivo binário completo e válido PMTiles v3 a partir de uma lista de tiles.
  ///
  /// Organiza os tiles na ordem 1D da curva de Hilbert calculada por [PmtilesReader.zxyToTileId],
  /// gera o diretório varint, compacta se especificado, e concatena os blocos.
  static Uint8List createPmtilesV3Archive({
    required List<SyntheticTileSpec> tiles,
    PmtilesCompression internalCompression = PmtilesCompression.none,
    PmtilesCompression tileCompression = PmtilesCompression.none,
    PmtilesTileType tileType = PmtilesTileType.mvt,
    int minZoom = 0,
    int maxZoom = 14,
    double minLon = AmazonianCoordinates.minLon,
    double minLat = AmazonianCoordinates.minLat,
    double maxLon = AmazonianCoordinates.maxLon,
    double maxLat = AmazonianCoordinates.maxLat,
    double centerLon = AmazonianCoordinates.santoAntonioLon,
    double centerLat = AmazonianCoordinates.santoAntonioLat,
    int centerZoom = 10,
  }) {
    if (tiles.isEmpty) {
      throw ArgumentError('At least one tile is required to build a valid PMTiles archive.');
    }

    // Mapeia para entradas PMTiles ordenadas por Hilbert tileId
    final mappedEntries = <({int tileId, Uint8List rawData})>[];
    for (final t in tiles) {
      final tileId = PmtilesReader.zxyToTileId(t.z, t.x, t.y);
      mappedEntries.add((tileId: tileId, rawData: t.data));
    }
    mappedEntries.sort((a, b) => a.tileId.compareTo(b.tileId));

    // Concatena blocos de tiles e calcula offsets
    final tileDataBuilder = BytesBuilder();
    final pmtilesEntries = <PmtilesEntry>[];
    var currentOffset = 0;

    for (final item in mappedEntries) {
      final rawData = item.rawData;
      final effectiveData = tileCompression == PmtilesCompression.gzip
          ? Uint8List.fromList(gzip.encode(rawData))
          : rawData;

      pmtilesEntries.add(
        PmtilesEntry(
          tileId: item.tileId,
          offset: currentOffset,
          length: effectiveData.length,
          runLength: 1,
        ),
      );

      tileDataBuilder.add(effectiveData);
      currentOffset += effectiveData.length;
    }

    final tileDataBytes = tileDataBuilder.takeBytes();

    // Codifica diretório raiz
    final rawDirBytes = _encodeDirectory(pmtilesEntries);
    final effectiveDirBytes = internalCompression == PmtilesCompression.gzip
        ? Uint8List.fromList(gzip.encode(rawDirBytes))
        : rawDirBytes;

    const rootDirOffset = 127;
    final rootDirLength = effectiveDirBytes.length;
    final tileDataOffset = rootDirOffset + rootDirLength;
    final tileDataLength = tileDataBytes.length;

    final headerBytes = buildV3Header(
      rootDirOffset: rootDirOffset,
      rootDirLength: rootDirLength,
      tileDataOffset: tileDataOffset,
      tileDataLength: tileDataLength,
      numAddressedTiles: pmtilesEntries.length,
      numTileEntries: pmtilesEntries.length,
      numTileContents: pmtilesEntries.length,
      internalCompression: internalCompression,
      tileCompression: tileCompression,
      tileType: tileType,
      minZoom: minZoom,
      maxZoom: maxZoom,
      minLon: minLon,
      minLat: minLat,
      maxLon: maxLon,
      maxLat: maxLat,
      centerZoom: centerZoom,
      centerLon: centerLon,
      centerLat: centerLat,
    );

    final archive = BytesBuilder();
    archive.add(headerBytes);
    archive.add(effectiveDirBytes);
    archive.add(tileDataBytes);

    return archive.takeBytes();
  }

  /// Cria um pacote sintético canônico de teste para o Alto Solimões contendo
  /// os tiles representativos de Santo Antônio do Içá (z=0, z=10) e Betânia (z=10).
  static Uint8List createAltoSolimoesPackage() {
    // Tile z=0 (base mundial)
    final tileZ0 = SyntheticTileSpec(
      z: 0,
      x: 0,
      y: 0,
      data: Uint8List.fromList(
        utf8.encode('{"layer":"transportation","name":"Alto Solimões Base"}'),
      ),
    );

    // Tile z=10 cobrindo Santo Antônio do Içá (-3.1022, -67.9397)
    // x = ((-67.9397 + 180) / 360 * 1024).floor() = 318
    // y = ((1 - log(tan(lat) + 1/cos(lat))/pi)/2 * 1024).floor() = 520
    final tileZ10Sai = SyntheticTileSpec(
      z: 10,
      x: 318,
      y: 520,
      data: Uint8List.fromList(
        utf8.encode('{"layer":"places","name":"Santo Antônio do Içá"}'),
      ),
    );

    // Tile z=10 cobrindo Betânia (-3.1700, -68.0800)
    final tileZ10Betania = SyntheticTileSpec(
      z: 10,
      x: 318,
      y: 521,
      data: Uint8List.fromList(
        utf8.encode('{"layer":"indigenous","name":"Betânia Ticuna"}'),
      ),
    );

    return createPmtilesV3Archive(
      tiles: [tileZ0, tileZ10Sai, tileZ10Betania],
      minZoom: 0,
      maxZoom: 14,
    );
  }

  /// Cria um pacote contendo um único tile na coordenada informada.
  static Uint8List createSingleTileArchive({
    int z = 0,
    int x = 0,
    int y = 0,
    Uint8List? tileData,
  }) {
    final payload = tileData ??
        Uint8List.fromList(utf8.encode('{"test_tile": [1, 2, 3]}'));
    return createPmtilesV3Archive(
      tiles: [
        SyntheticTileSpec(z: z, x: x, y: y, data: payload),
      ],
      minZoom: z,
      maxZoom: z,
    );
  }

  /// Gera variantes corrompidas de PMTiles v3 para validação estrita de fail-closed e BVA:
  /// - `tooShort`: buffer truncado com menos de 127 bytes.
  /// - `badMagic`: assinatura mágica diferente de 'PMTiles'.
  /// - `unsupportedVersion`: versão diferente de 3 (ex: versão 4 ou 2).
  static Uint8List createCorruptedArchive({
    bool tooShort = false,
    bool badMagic = false,
    int? customVersion,
  }) {
    if (tooShort) {
      return Uint8List(100); // 100 bytes < 127
    }

    return buildV3Header(
      rootDirOffset: 127,
      rootDirLength: 10,
      customMagic: badMagic ? [0x58, 0x58, 0x58, 0x58, 0x58, 0x58, 0x58] : null,
      specVersion: customVersion ?? 3,
    );
  }
}
