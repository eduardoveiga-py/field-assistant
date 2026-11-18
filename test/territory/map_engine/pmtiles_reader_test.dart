import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ministerio_pessoal/territory/map_engine/offline_tile_server.dart';
import 'package:ministerio_pessoal/territory/map_engine/pmtiles_reader.dart';

void _writeVarint(BytesBuilder out, int value) {
  var v = value;
  while (v >= 0x80) {
    out.addByte((v & 0x7f) | 0x80);
    v >>= 7;
  }
  out.addByte(v & 0x7f);
}

Uint8List _encodeDirectory(List<PmtilesEntry> entries) {
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

void _setUint64LE(ByteData bd, int offset, int value) {
  bd.setUint32(offset, value & 0xffffffff, Endian.little);
  bd.setUint32(offset + 4, (value >> 32) & 0xffffffff, Endian.little);
}

Uint8List _buildV3Header({
  required int rootDirOffset,
  required int rootDirLength,
  int leafDirsOffset = 0,
  int leafDirsLength = 0,
  int tileDataOffset = 0,
  int tileDataLength = 0,
  PmtilesCompression internalCompression = PmtilesCompression.gzip,
  PmtilesCompression tileCompression = PmtilesCompression.gzip,
  PmtilesTileType tileType = PmtilesTileType.mvt,
  int minZoom = 0,
  int maxZoom = 14,
  double minLon = -60.5,
  double minLat = -3.5,
  double maxLon = -59.8,
  double maxLat = -2.8,
  int centerZoom = 10,
  double centerLon = -60.02,
  double centerLat = -3.11,
}) {
  final bytes = Uint8List(127);
  for (var i = 0; i < PmtilesHeader.magicBytes.length; i++) {
    bytes[i] = PmtilesHeader.magicBytes[i];
  }
  bytes[7] = 3; // spec version 3
  final bd = ByteData.sublistView(bytes);
  _setUint64LE(bd, 8, rootDirOffset);
  _setUint64LE(bd, 16, rootDirLength);
  _setUint64LE(bd, 40, leafDirsOffset);
  _setUint64LE(bd, 48, leafDirsLength);
  _setUint64LE(bd, 56, tileDataOffset);
  _setUint64LE(bd, 64, tileDataLength);
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

void main() {
  group('PmtilesReader & Official PMTiles v3 Specification Tests', () {
    test('Hilbert zxyToTileId matches canonical PMTiles v3 test vectors', () {
      expect(PmtilesReader.zxyToTileId(0, 0, 0), equals(0));

      // Zoom 1 canonical Hilbert order: (0,0)->1, (0,1)->2, (1,1)->3, (1,0)->4
      expect(PmtilesReader.zxyToTileId(1, 0, 0), equals(1));
      expect(PmtilesReader.zxyToTileId(1, 0, 1), equals(2));
      expect(PmtilesReader.zxyToTileId(1, 1, 1), equals(3));
      expect(PmtilesReader.zxyToTileId(1, 1, 0), equals(4));

      // Zoom 2 boundary checks (base = 5, 16 distinct tile IDs 5..20)
      final z2Ids = <int>{};
      for (var x = 0; x < 4; x++) {
        for (var y = 0; y < 4; y++) {
          z2Ids.add(PmtilesReader.zxyToTileId(2, x, y));
        }
      }
      expect(z2Ids.length, equals(16));
      expect(z2Ids.reduce((a, b) => a < b ? a : b), equals(5));
      expect(z2Ids.reduce((a, b) => a > b ? a : b), equals(20));
      expect(PmtilesReader.zxyToTileId(2, 0, 0), equals(5));
      expect(PmtilesReader.zxyToTileId(2, 2, 0), equals(19));
      expect(PmtilesReader.zxyToTileId(2, 3, 0), equals(20));
    });

    test(
      'Parses official 127-byte PMTiles v3 header with 7-byte "PMTiles" magic',
      () {
        final bytes = _buildV3Header(
          rootDirOffset: 127,
          rootDirLength: 50,
          leafDirsOffset: 177,
          leafDirsLength: 40,
          tileDataOffset: 217,
          tileDataLength: 512,
          minZoom: 2,
          maxZoom: 15,
          minLon: -60.5,
          minLat: -3.5,
          maxLon: -59.8,
          maxLat: -2.8,
          centerZoom: 11,
          centerLon: -60.02,
          centerLat: -3.11,
        );

        final header = PmtilesHeader.fromBytes(bytes);
        expect(header.specVersion, equals(3));
        expect(header.rootDirOffset, equals(127));
        expect(header.rootDirLength, equals(50));
        expect(header.leafDirsOffset, equals(177));
        expect(header.leafDirsLength, equals(40));
        expect(header.tileDataOffset, equals(217));
        expect(header.tileDataLength, equals(512));
        expect(header.clustered, isTrue);
        expect(header.internalCompression, equals(PmtilesCompression.gzip));
        expect(header.tileType, equals(PmtilesTileType.mvt));
        expect(header.minZoom, equals(2));
        expect(header.maxZoom, equals(15));
        expect(header.minLon, closeTo(-60.5, 1e-6));
        expect(header.minLat, closeTo(-3.5, 1e-6));
        expect(header.maxLon, closeTo(-59.8, 1e-6));
        expect(header.maxLat, closeTo(-2.8, 1e-6));
        expect(header.centerZoom, equals(11));
        expect(header.centerLon, closeTo(-60.02, 1e-6));
        expect(header.centerLat, closeTo(-3.11, 1e-6));
      },
    );

    test(
      'Rejects legacy 2-byte "PM" magic, bad version, and truncated header',
      () {
        expect(
          () => PmtilesHeader.fromBytes(Uint8List(50)),
          throwsFormatException,
        );

        // Legacy 2-byte "PM" header must be rejected
        final legacyV2 = Uint8List(127);
        legacyV2[0] = 0x50;
        legacyV2[1] = 0x4D;
        legacyV2[2] = 3;
        expect(() => PmtilesHeader.fromBytes(legacyV2), throwsFormatException);

        // Valid 7-byte magic with wrong spec version
        final wrongVersion = _buildV3Header(
          rootDirOffset: 127,
          rootDirLength: 0,
        );
        wrongVersion[7] = 2;
        expect(
          () => PmtilesHeader.fromBytes(wrongVersion),
          throwsFormatException,
        );
      },
    );

    test('Reads gzipped PMTiles v3 archive with RLE runs (1M tiles O(1) memory) and leaf directories end-to-end via OfflineTileServer', () async {
      HttpOverrides.global = null;
      final tempDir = Directory.systemTemp.createTempSync('pmtiles_v3_e2e_');
      final archiveFile = File('${tempDir.path}/solimoes.pmtiles');
      final server = OfflineTileServer(packagesDir: tempDir);

      try {
        final tileRootPayload = Uint8List.fromList([
          0x1F,
          0x8B,
          0x08,
          0x00,
          0xAA,
          0xBB,
        ]);
        final tileOceanPayload = Uint8List.fromList([
          0x1F,
          0x8B,
          0x08,
          0x00,
          0x11,
          0x22,
          0x33,
        ]);
        final tileLeafPayload = Uint8List.fromList([
          0x1F,
          0x8B,
          0x08,
          0x00,
          0xDE,
          0xAD,
          0xBE,
          0xEF,
        ]);

        final tileData = Uint8List.fromList([
          ...tileRootPayload, // offset 0, len 6
          ...tileOceanPayload, // offset 6, len 7
          ...tileLeafPayload, // offset 13, len 8
        ]);

        // Target leaf tile at z=12, x=1365, y=2080
        final leafTileId = PmtilesReader.zxyToTileId(12, 1365, 2080);
        final leafDirRaw = _encodeDirectory([
          PmtilesEntry(
            tileId: leafTileId,
            offset: tileRootPayload.length + tileOceanPayload.length,
            length: tileLeafPayload.length,
            runLength: 1,
          ),
        ]);
        final leafDirGzip = Uint8List.fromList(gzip.encode(leafDirRaw));

        // Root directory:
        // 1) z=0,0,0 (tileId 0) -> direct tile
        // 2) tileId 100..100+999999 -> huge RLE run of 1,000,000 ocean tiles
        // 3) leafTileId - 10 -> leaf directory pointer (runLength == 0)
        final rootDirRaw = _encodeDirectory([
          PmtilesEntry(
            tileId: 0,
            offset: 0,
            length: tileRootPayload.length,
            runLength: 1,
          ),
          PmtilesEntry(
            tileId: 100,
            offset: tileRootPayload.length,
            length: tileOceanPayload.length,
            runLength: 1000000,
          ),
          PmtilesEntry(
            tileId: leafTileId - 10,
            offset: 0,
            length: leafDirGzip.length,
            runLength: 0, // Leaf directory!
          ),
        ]);
        final rootDirGzip = Uint8List.fromList(gzip.encode(rootDirRaw));

        const rootOffset = 127;
        final leafOffset = rootOffset + rootDirGzip.length;
        final dataOffset = leafOffset + leafDirGzip.length;

        final headerBytes = _buildV3Header(
          rootDirOffset: rootOffset,
          rootDirLength: rootDirGzip.length,
          leafDirsOffset: leafOffset,
          leafDirsLength: leafDirGzip.length,
          tileDataOffset: dataOffset,
          tileDataLength: tileData.length,
        );

        archiveFile.writeAsBytesSync([
          ...headerBytes,
          ...rootDirGzip,
          ...leafDirGzip,
          ...tileData,
        ]);

        final reader = PmtilesReader(archiveFile);
        // 1. Direct root tile
        expect(await reader.getTile(0, 0, 0), equals(tileRootPayload));
        // 2. Tile resolved via leaf directory (runLength == 0)
        expect(await reader.getTile(12, 1365, 2080), equals(tileLeafPayload));
        // 3. Missing tile near leaf directory
        expect(await reader.getTile(12, 1365, 2081), isNull);
        // 4. RLE hit at offset inside 1M run (z=6, x=2, y=2 -> tileId in [100, 1000099])
        final rleTileId = PmtilesReader.zxyToTileId(6, 2, 2);
        expect(rleTileId, greaterThanOrEqualTo(100));
        expect(await reader.getTile(6, 2, 2), equals(tileOceanPayload));

        // 5. End-to-end HTTP via OfflineTileServer
        server.registerPmtilesPackage('solimoes', archiveFile);
        await server.start();

        final client = HttpClient()..autoUncompress = false;
        final req = await client.getUrl(
          Uri.parse('${server.baseUrl}/pmtiles/solimoes/12/1365/2080.pbf'),
        );
        final res = await req.close();
        expect(res.statusCode, equals(200));
        expect(
          res.headers.value(HttpHeaders.contentTypeHeader),
          equals('application/x-protobuf'),
        );
        expect(
          res.headers.value(HttpHeaders.contentEncodingHeader),
          equals('gzip'),
        );
        final body = <int>[];
        await for (final chunk in res) {
          body.addAll(chunk);
        }
        expect(body, equals(tileLeafPayload));
        client.close();

        final miss = await http.get(
          Uri.parse('${server.baseUrl}/pmtiles/solimoes/12/1365/2081.pbf'),
        );
        expect(miss.statusCode, equals(404));
      } finally {
        await server.stop(force: true);
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test(
      'Retrieves manually registered tile data from PmtilesReader',
      () async {
        final tempDir = Directory.systemTemp.createTempSync('pmtiles_unit_');
        final dummyFile = File('${tempDir.path}/test.pmtiles');
        try {
          final fakeTileData = Uint8List.fromList([
            0x1F,
            0x8B,
            0x08,
            0x01,
            0x02,
            0x03,
          ]);
          final headerBytes = _buildV3Header(
            rootDirOffset: 127,
            rootDirLength: 0,
          );
          dummyFile.writeAsBytesSync([...headerBytes, ...fakeTileData]);

          final reader = PmtilesReader(dummyFile);
          reader.registerEntry(10, 50, 60, 127, 6);

          expect(await reader.getTile(10, 50, 60), equals(fakeTileData));
          expect(await reader.getTile(10, 99, 99), isNull);
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      },
    );
  });
}
