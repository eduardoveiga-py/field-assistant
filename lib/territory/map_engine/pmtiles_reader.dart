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

  /// Assinatura mágica oficial PMTiles v3 (7 bytes ASCII: "PMTiles").
  static const List<int> magicBytes = <int>[
    0x50,
    0x4D,
    0x54,
    0x69,
    0x6C,
    0x65,
    0x73,
  ];

  factory PmtilesHeader.fromBytes(Uint8List bytes) {
    if (bytes.length < 127) {
      throw const FormatException(
        'Cabeçalho PMTiles inválido: menor que 127 bytes.',
      );
    }
    // Magic: "PMTiles" (7 bytes: 0x50 0x4D 0x54 0x69 0x6C 0x65 0x73)
    for (var i = 0; i < magicBytes.length; i++) {
      if (bytes[i] != magicBytes[i]) {
        throw const FormatException(
          'Assinatura mágica PMTiles v3 ("PMTiles") ausente.',
        );
      }
    }
    final version = bytes[7];
    if (version != 3) {
      throw FormatException(
        'Versão PMTiles não suportada: $version (apenas v3 suportada).',
      );
    }

    final bd = ByteData.sublistView(bytes);

    int getUint64(int offset) {
      // Leitura little-endian de 64 bits compatível com todas as plataformas Dart.
      final low = bd.getUint32(offset, Endian.little);
      final high = bd.getUint32(offset + 4, Endian.little);
      return (high << 32) | low;
    }

    return PmtilesHeader(
      specVersion: version,
      rootDirOffset: getUint64(8),
      rootDirLength: getUint64(16),
      jsonMetadataOffset: getUint64(24),
      jsonMetadataLength: getUint64(32),
      leafDirsOffset: getUint64(40),
      leafDirsLength: getUint64(48),
      tileDataOffset: getUint64(56),
      tileDataLength: getUint64(64),
      numAddressedTiles: getUint64(72),
      numTileEntries: getUint64(80),
      numTileContents: getUint64(88),
      clustered: bytes[96] == 1,
      internalCompression: PmtilesCompression.fromCode(bytes[97]),
      tileCompression: PmtilesCompression.fromCode(bytes[98]),
      tileType: PmtilesTileType.fromCode(bytes[99]),
      minZoom: bytes[100],
      maxZoom: bytes[101],
      minLon: bd.getInt32(102, Endian.little) / 10000000.0,
      minLat: bd.getInt32(106, Endian.little) / 10000000.0,
      maxLon: bd.getInt32(110, Endian.little) / 10000000.0,
      maxLat: bd.getInt32(114, Endian.little) / 10000000.0,
      centerZoom: bytes[118],
      centerLon: bd.getInt32(119, Endian.little) / 10000000.0,
      centerLat: bd.getInt32(123, Endian.little) / 10000000.0,
    );
  }
}

/// Entrada no diretório PMTiles v3 (mapeia TileId -> Offset + Length).
/// Quando `runLength == 0`, representa um ponteiro de diretório folha (leaf directory)
/// relativo a `header.leafDirsOffset`; quando `runLength > 0`, representa dados de tile
/// relativos a `header.tileDataOffset`.
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

  bool get isLeafDirectory => runLength == 0;
}

/// Leitor de arquivo PMTiles (v3) em disco com decodificação de coordenadas Hilbert,
/// busca binária O(log N) em intervalos RLE e resolução de diretórios folha (leaf directories).
class PmtilesReader {
  static const int _maxLeafDepth = 3;

  final File file;
  PmtilesHeader? _header;
  List<PmtilesEntry> _rootEntries = const [];
  final Map<int, List<PmtilesEntry>> _leafCache = {};
  final Map<int, PmtilesEntry> _manualEntries = {};
  bool _parsed = false;

  PmtilesReader(this.file);

  /// Converte coordenadas (z, x, y) em TileID da curva de Hilbert (PMTiles v3 spec).
  static int zxyToTileId(int z, int x, int y) {
    if (z < 0 || z > 26) {
      throw RangeError.range(z, 0, 26, 'z');
    }
    if (z == 0) return 0;
    final n = 1 << z;
    if (x < 0 || x >= n || y < 0 || y >= n) {
      throw RangeError('Coordenadas (z=$z, x=$x, y=$y) fora dos limites.');
    }
    var base = 0;
    for (var i = 0; i < z; i++) {
      base += 1 << (2 * i);
    }
    var d = 0;
    var s = n >> 1;
    var curX = x;
    var curY = y;
    while (s > 0) {
      final rx = (curX & s) > 0 ? 1 : 0;
      final ry = (curY & s) > 0 ? 1 : 0;
      d += s * s * ((3 * rx) ^ ry);
      if (ry == 0) {
        if (rx == 1) {
          curX = n - 1 - curX;
          curY = n - 1 - curY;
        }
        final t = curX;
        curX = curY;
        curY = t;
      }
      s >>= 1;
    }
    return base + d;
  }

  /// Busca binária O(log N) conforme especificação oficial PMTiles v3.
  static PmtilesEntry? findEntry(List<PmtilesEntry> entries, int tileId) {
    var m = 0;
    var n = entries.length - 1;
    while (m <= n) {
      final k = (n + m) >> 1;
      final cmp = tileId - entries[k].tileId;
      if (cmp > 0) {
        m = k + 1;
      } else if (cmp < 0) {
        n = k - 1;
      } else {
        return entries[k];
      }
    }
    if (n >= 0) {
      if (entries[n].runLength == 0) {
        return entries[n];
      }
      if (tileId - entries[n].tileId < entries[n].runLength) {
        return entries[n];
      }
    }
    return null;
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

  Uint8List _decompressInternal(
    Uint8List rawBytes,
    PmtilesCompression compression,
  ) {
    if (compression == PmtilesCompression.gzip) {
      return Uint8List.fromList(gzip.decode(rawBytes));
    }
    if (compression == PmtilesCompression.none ||
        compression == PmtilesCompression.unknown) {
      return rawBytes;
    }
    throw UnsupportedError(
      'Compressão interna PMTiles não suportada: ${compression.name}',
    );
  }

  /// Lê o diretório raiz e constrói a lista compacta de entradas em memória.
  Future<void> _ensureParsed() async {
    if (_parsed) return;
    final header = await getHeader();
    final raf = await file.open(mode: FileMode.read);
    try {
      if (header.rootDirLength > 0) {
        await raf.setPosition(header.rootDirOffset);
        final rawDirBytes = await raf.read(header.rootDirLength);
        final dirBytes = _decompressInternal(
          rawDirBytes,
          header.internalCompression,
        );
        _rootEntries = parseDirectoryBytes(dirBytes);
      }
      _parsed = true;
    } catch (e, st) {
      AppLogger.warning(
        'Erro ao processar diretório PMTiles de ${file.path}',
        e,
        st,
      );
      rethrow;
    } finally {
      await raf.close();
    }
  }

  /// Decodifica um diretório PMTiles v3 (raiz ou folha) em lista ordenada de [PmtilesEntry].
  static List<PmtilesEntry> parseDirectoryBytes(Uint8List dirBytes) {
    if (dirBytes.isEmpty) return const [];
    var pos = 0;

    int readVarint() {
      var result = 0;
      var shift = 0;
      while (pos < dirBytes.length) {
        final b = dirBytes[pos++];
        result |= (b & 0x7f) << shift;
        shift += 7;
        if ((b & 0x80) == 0) return result;
      }
      throw const FormatException('Varint truncado no diretório PMTiles.');
    }

    final numEntries = readVarint();
    if (numEntries == 0) return const [];

    final tileIds = List<int>.filled(numEntries, 0);
    var lastTileId = 0;
    for (var i = 0; i < numEntries; i++) {
      lastTileId += readVarint();
      tileIds[i] = lastTileId;
    }

    final runLengths = List<int>.filled(numEntries, 0);
    for (var i = 0; i < numEntries; i++) {
      runLengths[i] = readVarint();
    }

    final lengths = List<int>.filled(numEntries, 0);
    for (var i = 0; i < numEntries; i++) {
      lengths[i] = readVarint();
    }

    final entries = <PmtilesEntry>[];
    var lastOffset = 0;
    for (var i = 0; i < numEntries; i++) {
      final offsetVal = readVarint();
      final int relativeOffset;
      if (offsetVal == 0) {
        if (i == 0) {
          throw const FormatException(
            'Offset PMTiles inválido (0) na primeira entrada do diretório.',
          );
        }
        relativeOffset = lastOffset + lengths[i - 1];
      } else {
        relativeOffset = offsetVal - 1;
      }
      lastOffset = relativeOffset;

      entries.add(
        PmtilesEntry(
          tileId: tileIds[i],
          offset: relativeOffset,
          length: lengths[i],
          runLength: runLengths[i],
        ),
      );
    }
    return entries;
  }

  Future<List<PmtilesEntry>> _loadLeafDirectory(
    PmtilesHeader header,
    int leafOffset,
    int leafLength,
  ) async {
    final cached = _leafCache[leafOffset];
    if (cached != null) return cached;

    final raf = await file.open(mode: FileMode.read);
    try {
      await raf.setPosition(header.leafDirsOffset + leafOffset);
      final rawBytes = await raf.read(leafLength);
      final decoded = _decompressInternal(rawBytes, header.internalCompression);
      final entries = parseDirectoryBytes(decoded);
      _leafCache[leafOffset] = entries;
      return entries;
    } finally {
      await raf.close();
    }
  }

  /// Obtém os bytes do tile vetorial/raster para as coordenadas dadas,
  /// percorrendo diretório raiz e diretórios folha quando presentes.
  Future<Uint8List?> getTile(int z, int x, int y) async {
    final int tileId;
    try {
      tileId = zxyToTileId(z, x, y);
    } on RangeError {
      return null;
    }

    final manual = _manualEntries[tileId];
    if (manual != null && manual.length > 0) {
      final raf = await file.open(mode: FileMode.read);
      try {
        await raf.setPosition(manual.offset);
        return await raf.read(manual.length);
      } finally {
        await raf.close();
      }
    }

    if (_parsed && _rootEntries.isEmpty) return null;
    await _ensureParsed();
    final header = _header;
    if (header == null || _rootEntries.isEmpty) return null;

    var currentEntries = _rootEntries;
    for (var depth = 0; depth <= _maxLeafDepth; depth++) {
      final entry = findEntry(currentEntries, tileId);
      if (entry == null || entry.length <= 0) return null;

      if (entry.isLeafDirectory) {
        if (depth == _maxLeafDepth) return null;
        currentEntries = await _loadLeafDirectory(
          header,
          entry.offset,
          entry.length,
        );
        continue;
      }

      final raf = await file.open(mode: FileMode.read);
      try {
        await raf.setPosition(header.tileDataOffset + entry.offset);
        return await raf.read(entry.length);
      } finally {
        await raf.close();
      }
    }
    return null;
  }

  /// Permite injetar manualmente entradas (para pacotes sintetizados em testes).
  void registerEntry(int z, int x, int y, int offset, int length) {
    final tileId = zxyToTileId(z, x, y);
    _manualEntries[tileId] = PmtilesEntry(
      tileId: tileId,
      offset: offset,
      length: length,
      runLength: 1,
    );
    _parsed = true;
  }
}
