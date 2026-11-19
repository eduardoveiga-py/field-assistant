import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/territory/map_engine/pmtiles_reader.dart';

void main() {
  test('app PMTiles reader returns the real CLI-extracted sample', () async {
    final archivePath = Platform.environment['REAL_PMTILES'];
    final expectedPath = Platform.environment['EXPECTED_TILE'];
    if (archivePath == null || expectedPath == null) {
      // Real external sample is supplied only in the experimental pipeline.
      return;
    }
    final expected = await File(expectedPath).readAsBytes();
    expect(expected, isNotEmpty);
    final actual = await PmtilesReader(File(archivePath)).getTile(14, 5099, 8333);
    expect(actual, equals(expected));
  });
}
