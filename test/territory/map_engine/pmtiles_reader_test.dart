import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/territory/map_engine/pmtiles_reader.dart';

void main() {
  group('PmtilesReader & Hilbert Transform Tests', () {
    test('Hilbert zxyToTileId maps canonical coords deterministically', () {
      // Zoom 0
      expect(PmtilesReader.zxyToTileId(0, 0, 0), equals(0));

      // Zoom 1 (base = 1, tiles 1..4)
      final z1_00 = PmtilesReader.zxyToTileId(1, 0, 0);
      final z1_01 = PmtilesReader.zxyToTileId(1, 0, 1);
      final z1_10 = PmtilesReader.zxyToTileId(1, 1, 0);
      final z1_11 = PmtilesReader.zxyToTileId(1, 1, 1);

      expect(z1_00, greaterThanOrEqualTo(1));
      expect(z1_01, greaterThanOrEqualTo(1));
      expect(z1_10, greaterThanOrEqualTo(1));
      expect(z1_11, greaterThanOrEqualTo(1));

      // All 4 tiles at zoom 1 must have distinct tile IDs
      final set1 = {z1_00, z1_01, z1_10, z1_11};
      expect(set1.length, equals(4));

      // Zoom 2 (base = 1 + 4 = 5)
      final z2_00 = PmtilesReader.zxyToTileId(2, 0, 0);
      expect(z2_00, greaterThanOrEqualTo(5));
    });

    test('Parses valid PMTiles v3 header correctly', () {
      // 127 bytes PMTiles v3 header
      final bytes = Uint8List(127);
      bytes[0] = 0x50; // 'P'
      bytes[1] = 0x4D; // 'M'
      bytes[2] = 3; // spec version 3

      final bd = ByteData.sublistView(bytes);
      // rootDirOffset = 127
      bd.setUint32(3, 127, Endian.little);
      bd.setUint32(7, 0, Endian.little);
      // rootDirLength = 50
      bd.setUint32(11, 50, Endian.little);
      bd.setUint32(15, 0, Endian.little);

      // minZoom = 0, maxZoom = 14
      bytes[95] = 0;
      bytes[96] = 14;

      final header = PmtilesHeader.fromBytes(bytes);
      expect(header.specVersion, equals(3));
      expect(header.rootDirOffset, equals(127));
      expect(header.rootDirLength, equals(50));
      expect(header.minZoom, equals(0));
      expect(header.maxZoom, equals(14));
    });

    test('Throws FormatException on invalid magic or truncated header', () {
      expect(
        () => PmtilesHeader.fromBytes(Uint8List(50)),
        throwsFormatException,
      );

      final invalidMagic = Uint8List(127);
      invalidMagic[0] = 0x00;
      invalidMagic[1] = 0x00;
      invalidMagic[2] = 3;
      expect(
        () => PmtilesHeader.fromBytes(invalidMagic),
        throwsFormatException,
      );
    });

    test('Retrieves registered tile data from PmtilesReader', () async {
      final tempDir = Directory.systemTemp.createTempSync('pmtiles_unit_');
      final dummyFile = File('${tempDir.path}/test.pmtiles');

      // Create dummy file with header + tile payload
      final fakeTileData = Uint8List.fromList([
        0x1F,
        0x8B,
        0x08,
        0x01,
        0x02,
        0x03,
      ]);
      final headerBytes = Uint8List(127);
      headerBytes[0] = 0x50;
      headerBytes[1] = 0x4D;
      headerBytes[2] = 3;

      dummyFile.writeAsBytesSync([...headerBytes, ...fakeTileData]);

      final reader = PmtilesReader(dummyFile);
      // Register entry for z=10, x=50, y=60 at offset 127, length 6
      reader.registerEntry(10, 50, 60, 127, 6);

      final tile = await reader.getTile(10, 50, 60);
      expect(tile, isNotNull);
      expect(tile, equals(fakeTileData));

      // Missing tile returns null
      final missing = await reader.getTile(10, 99, 99);
      expect(missing, isNull);

      tempDir.deleteSync(recursive: true);
    });
  });
}
