import 'dart:io';
import 'dart:typed_data';

import '../../core/app_logger.dart';

/// Tipo de compressão de tiles em PMTiles v3.
enum PmtilesCompression {
  unknown(0),
  none(1),
  gzip(2),
  brotli(3),
  zstd(4);

  final int code;
  const PmtilesCompression(this.code);

  static PmtilesCompression fromCode(int c) {
    for (final v in values) {
      if (v.code == c) return v;
    }
    return PmtilesCompression.unknown;
  }
}

/// Tipo de tile em PMTiles v3.
enum PmtilesTileType {
  unknown(0),
  mvt(1),
  png(2),
  jpeg(3),
  webp(4);

  final int code;
  const PmtilesTileType(this.code);

  static PmtilesTileType fromCode(int c) {
    for (final v in values) {
      if (v.code == c) return v;
    }
    return PmtilesTileType.unknown;
  }
}

/// Cabeçalho PMTiles v3 (especificação oficial protomaps/PMTiles v3 - 127 bytes).
class PmtilesHeader {
  final int specVersion;
  final int rootDirOffset;
  final int rootDirLength;
  final int jsonMetadataOffset;
  final int jsonMetadataLength;
  final int leafDirsOffset;
  final int leafDirsLength;
  final int tileDataOffset;
  final int tileDataLength;
  final int numAddressedTiles;
  final int numTileEntries;
  final int numTileContents;
  final bool clustered;
  final PmtilesCompression internalCompression;
  final PmtilesCompression tileCompression;
  final PmtilesTileType tileType;
  final int minZoom;
  final int maxZoom;
  final double minLon;
  final double minLat;
  final double maxLon;
  final double maxLat;
  final int centerZoom;
  final double centerLon;
  final double centerLat;

  const PmtilesHeader({
    required this.specVersion,
    required this.rootDirOffset,
    required this.rootDirLength,
    required this.jsonMetadataOffset,
    required this.jsonMetadataLength,
    required this.leafDirsOffset,
    required this.leafDirsLength,
    required this.tileDataOffset,
    required this.tileDataLength,
    required this.numAddressedTiles,
    required this.numTileEntries,
    required this.numTileContents,
    required this.clustered,
    required this.internalCompression,
    required this.tileCompression,
    required this.tileType,
    required this.minZoom,
    required this.maxZoom,
    required this.minLon,
    required this.minLat,
    required this.maxLon,
    required this.maxLat,
    required this.centerZoom,
    required this.centerLon,
    required this.centerLat,
  });

  factory PmtilesHeader.fromBytes(Uint8List bytes) {
    if (bytes.length < 127) {
      throw const FormatException(
        'Cabeçalho PMTiles inválido: menor que 127 bytes.',
      );
    }
    // Magic: "PM" (0x50, 0x4D)
    if (bytes[0] != 0x50 || bytes[1] != 0x4D) {
      throw const FormatException('Assinatura mágica PMTiles ausente.');
    }
    final version = bytes[2];
    if (version != 3) {
      throw FormatException(
        'Versão PMTiles não suportada: $version (apenas v3 suportada).',
      );
    }

    final bd = ByteData.sublistView(bytes);

    int getUint64(int offset) {
      // Dart ByteData não tem getUint64 em todas plataformas sem 64-bit int; lemos little-endian
      final low = bd.getUint32(offset, Endian.little);
      final high = bd.getUint32(offset + 4, Endian.little);
      return (high << 32) | low;
    }

    return PmtilesHeader(
      specVersion: version,
      rootDirOffset: getUint64(3),
      rootDirLength: getUint64(11),
      jsonMetadataOffset: getUint64(19),
      jsonMetadataLength: getUint64(27),
      leafDirsOffset: getUint64(35),
      leafDirsLength: getUint64(43),
      tileDataOffset: getUint64(51),
      tileDataLength: getUint64(59),
      numAddressedTiles: getUint64(67),
      numTileEntries: getUint64(75),
      numTileContents: getUint64(83),
      clustered: bytes[91] == 1,
      internalCompression: PmtilesCompression.fromCode(bytes[92]),
      tileCompression: PmtilesCompression.fromCode(bytes[93]),
      tileType: PmtilesTileType.fromCode(bytes[94]),
      minZoom: bytes[95],
      maxZoom: bytes[96],
      minLon: bd.getInt32(97, Endian.little) / 10000000.0,
      minLat: bd.getInt32(101, Endian.little) / 10000000.0,
      maxLon: bd.getInt32(105, Endian.little) / 10000000.0,
      maxLat: bd.getInt32(109, Endian.little) / 10000000.0,
      centerZoom: bytes[113],
      centerLon: bd.getInt32(114, Endian.little) / 10000000.0,
      centerLat: bd.getInt32(118, Endian.little) / 10000000.0,
    );
  }
}

/// Entrada no diretório PMTiles v3 (mapeia TileId -> Offset + Length).
class PmtilesEntry {
  final int tileId;
  final int offset;
  final int length;
  final int runLength;

  const PmtilesEntry({
    required this.tileId,
    required this.offset,
    required this.length,
    required this.runLength,
  });
}

/// Leitor de arquivo PMTiles (v3) em disco com decodificação de coordenadas Hilbert.
class PmtilesReader {
  final File file;
  PmtilesHeader? _header;
  final Map<int, PmtilesEntry> _entries = {};
  bool _parsed = false;

  PmtilesReader(this.file);

  /// Converte coordenadas (z, x, y) em TileID da curva de Hilbert (PMTiles v3 spec).
  static int zxyToTileId(int z, int x, int y) {
    if (z == 0) return 0;
    int base = 0;
    for (int i = 0; i < z; i++) {
      base += 1 << (2 * i);
    }
    int d = 0;
    int s = 1 << (z - 1);
    int rx, ry;
    int curX = x;
    int curY = y;
    while (s > 0) {
      rx = (curX & s) > 0 ? 1 : 0;
      ry = (curY & s) > 0 ? 1 : 0;
      d += s * s * ((3 * rx) ^ ry);
      if (ry == 0) {
        if (rx == 1) {
          curX = s - 1 - curX;
          curY = s - 1 - curY;
        }
        final t = curX;
        curX = curY;
        curY = t;
      }
      s >>= 1;
    }
    return base + d;
  }

  Future<PmtilesHeader> getHeader() async {
    if (_header != null) return _header!;
    final raf = await file.open(mode: FileMode.read);
    try {
      final headerBytes = await raf.read(127);
      _header = PmtilesHeader.fromBytes(headerBytes);
      return _header!;
    } finally {
      await raf.close();
    }
  }

  /// Lê o diretório raiz e constrói o índice de tiles em memória.
  Future<void> _ensureParsed() async {
    if (_parsed) return;
    final header = await getHeader();
    final raf = await file.open(mode: FileMode.read);
    try {
      if (header.rootDirLength > 0) {
        await raf.setPosition(header.rootDirOffset);
        final rawDirBytes = await raf.read(header.rootDirLength);
        Uint8List dirBytes;
        if (header.internalCompression == PmtilesCompression.gzip) {
          dirBytes = Uint8List.fromList(gzip.decode(rawDirBytes));
        } else {
          dirBytes = rawDirBytes;
        }
        _parseDirectory(dirBytes, header.tileDataOffset);
      }
      _parsed = true;
    } catch (e, st) {
      AppLogger.warning(
        'Erro ao processar diretório PMTiles de ${file.path}',
        e,
        st,
      );
    } finally {
      await raf.close();
    }
  }

  void _parseDirectory(Uint8List dirBytes, int tileDataOffset) {
    if (dirBytes.isEmpty) return;
    var pos = 0;

    int readVarint() {
      var result = 0;
      var shift = 0;
      while (pos < dirBytes.length) {
        final b = dirBytes[pos++];
        result |= (b & 0x7f) << shift;
        shift += 7;
        if ((b & 0x80) == 0) break;
      }
      return result;
    }

    if (pos >= dirBytes.length) return;
    final numEntries = readVarint();

    final tileIds = <int>[];
    var lastTileId = 0;
    for (var i = 0; i < numEntries && pos < dirBytes.length; i++) {
      final delta = readVarint();
      lastTileId += delta;
      tileIds.add(lastTileId);
    }

    final runLengths = <int>[];
    for (var i = 0; i < numEntries && pos < dirBytes.length; i++) {
      runLengths.add(readVarint());
    }

    final lengths = <int>[];
    for (var i = 0; i < numEntries && pos < dirBytes.length; i++) {
      lengths.add(readVarint());
    }

    var lastOffset = 0;
    for (var i = 0; i < numEntries && pos < dirBytes.length; i++) {
      final offsetVal = readVarint();
      int absoluteOffset;
      if (offsetVal == 0 && i > 0) {
        absoluteOffset = lastOffset + lengths[i - 1];
      } else {
        absoluteOffset = offsetVal - 1;
      }
      lastOffset = absoluteOffset;

      final tileId = tileIds[i];
      final length = lengths[i];
      final runLen = i < runLengths.length ? runLengths[i] : 1;

      for (var r = 0; r < runLen; r++) {
        _entries[tileId + r] = PmtilesEntry(
          tileId: tileId + r,
          offset: tileDataOffset + absoluteOffset,
          length: length,
          runLength: runLen,
        );
      }
    }
  }

  /// Obtém os bytes do tile vetorial/raster para as coordenadas dadas.
  Future<Uint8List?> getTile(int z, int x, int y) async {
    await _ensureParsed();
    final tileId = zxyToTileId(z, x, y);
    final entry = _entries[tileId];
    if (entry == null || entry.length <= 0) return null;

    final raf = await file.open(mode: FileMode.read);
    try {
      await raf.setPosition(entry.offset);
      return await raf.read(entry.length);
    } finally {
      await raf.close();
    }
  }

  /// Permite injetar manualmente entradas (para pacotes sintetizados em testes).
  void registerEntry(int z, int x, int y, int offset, int length) {
    final tileId = zxyToTileId(z, x, y);
    _entries[tileId] = PmtilesEntry(
      tileId: tileId,
      offset: offset,
      length: length,
      runLength: 1,
    );
    _parsed = true;
  }
}
