import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/territory/map_engine/offline_map_package_manager.dart';
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
    final actual = await PmtilesReader(File(archivePath))
        .getTile(14, 5099, 8333);
    expect(actual, equals(expected));

    final bytes = await File(archivePath).readAsBytes();
    final directory = await Directory.systemTemp.createTemp('real-map-install-');
    final manifest = OfflineMapPackageManifest(
      id: 'real_sample',
      regionName: 'Experimental sample',
      downloadUrl: Uri.parse('https://example.com/sample.pmtiles'),
      sizeBytes: bytes.length,
      sha256: crypto.sha256.convert(bytes).toString(),
      bbox: const GeoBoundingBox(minLat: -3.4, minLon: -68.2, maxLat: -3.0, maxLon: -67.7),
      minZoom: 0,
      maxZoom: 14,
    );
    final manager = OfflineMapPackageManager(
      storageDir: directory,
      catalog: [manifest],
      httpClient: MockClient((_) async => http.Response.bytes(bytes, 200)),
    );
    try {
      final installed = await manager.downloadAndInstall(manifest: manifest);
      expect(installed.isInstalled, isTrue);
      await manager.syncWithDisk();
      expect(manager.currentStates[manifest.id]!.isInstalled, isTrue);
      final installedTile = await PmtilesReader(installed.localFile!).getTile(14, 5099, 8333);
      expect(installedTile, equals(expected));
    } finally {
      manager.dispose();
      await directory.delete(recursive: true);
    }
  });
}
