import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/territory/map_engine/offline_map_package_manager.dart';

void main() {
  group('OfflineMapPackageManager Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('pkg_mgr_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    Uint8List createValidPmtilesBytes(String content) {
      final header = Uint8List(127);
      header.setRange(0, 7, 'PMTiles'.codeUnits);
      header[7] = 3; // version 3
      final contentBytes = utf8.encode(content);
      final builder = BytesBuilder();
      builder.add(header);
      builder.add(contentBytes);
      return builder.takeBytes();
    }

    test('TC-PKGMGR-01: Full download, SHA-256 validation, and atomic installation succeeds', () async {
      final payload = createValidPmtilesBytes('AltoSolimoesVectorData2026');
      final expectedSha = crypto.sha256.convert(payload).toString();

      final manifest = OfflineMapPackageManifest(
        id: 'test_pkg_01',
        regionName: 'Região de Teste',
        downloadUrl: Uri.parse('https://example.com/test_pkg_01.pmtiles'),
        sizeBytes: payload.length,
        sha256: expectedSha,
        bbox: const GeoBoundingBox(
          minLat: -3.4,
          minLon: -68.2,
          maxLat: -3.0,
          maxLon: -67.7,
        ),
        minZoom: 8,
        maxZoom: 16,
        generatedAt: DateTime.now(),
        version: '1.0.0',
        license: 'ODbL',
        attribution: 'OpenStreetMap contributors',
        format: OfflineMapFormat.pmtiles,
      );

      final mockClient = MockClient((request) async {
        return http.Response.bytes(payload, 200);
      });

      final manager = OfflineMapPackageManager(
        storageDir: tempDir,
        httpClient: mockClient,
      );
      addTearDown(manager.dispose);

      final state = await manager.downloadAndInstall(manifest: manifest);
      expect(state.status, equals(PackageDownloadStatus.installed));
      expect(state.localFile, isNotNull);
      expect(state.localFile!.existsSync(), isTrue);
      expect(state.localFile!.lengthSync(), equals(payload.length));
    });

    test('TC-PKGMGR-02: Corrupted checksum fails validation, triggers rollback, and cleans temp files', () async {
      final validPayload = createValidPmtilesBytes('ValidOriginalData');
      final validSha = crypto.sha256.convert(validPayload).toString();

      final corruptPayload = createValidPmtilesBytes('CorruptModifiedData');

      final manifest = OfflineMapPackageManifest(
        id: 'test_pkg_corrupt',
        regionName: 'Região Corrompida',
        downloadUrl: Uri.parse('https://example.com/corrupt.pmtiles'),
        sizeBytes: corruptPayload.length,
        sha256: validSha, // Checksum diferente do que será baixado!
        bbox: const GeoBoundingBox(
          minLat: -3.4,
          minLon: -68.2,
          maxLat: -3.0,
          maxLon: -67.7,
        ),
        minZoom: 8,
        maxZoom: 16,
        generatedAt: DateTime.now(),
        version: '1.0.0',
        license: 'ODbL',
        attribution: 'OpenStreetMap contributors',
        format: OfflineMapFormat.pmtiles,
      );

      final mockClient = MockClient((request) async {
        return http.Response.bytes(corruptPayload, 200);
      });

      final manager = OfflineMapPackageManager(
        storageDir: tempDir,
        httpClient: mockClient,
      );
      addTearDown(manager.dispose);

      await expectLater(
        () => manager.downloadAndInstall(manifest: manifest),
        throwsA(isA<FormatException>()),
      );

      final finalFile = await manager.getPackageFile(manifest);
      expect(finalFile.existsSync(), isFalse);

      final tmpFile = File('${finalFile.path}.tmp');
      expect(tmpFile.existsSync(), isFalse); // Arquivo .tmp deve ser limpo
    });

    test('TC-PKGMGR-03: Resumable download sends RFC 7233 Range header from existing byte count', () async {
      final fullPayload = createValidPmtilesBytes('0123456789ABCDEF');
      final fullSha = crypto.sha256.convert(fullPayload).toString();

      final manifest = OfflineMapPackageManifest(
        id: 'test_pkg_resume',
        regionName: 'Região Resumo',
        downloadUrl: Uri.parse('https://example.com/resume.pmtiles'),
        sizeBytes: fullPayload.length,
        sha256: fullSha,
        bbox: const GeoBoundingBox(
          minLat: -3.4,
          minLon: -68.2,
          maxLat: -3.0,
          maxLon: -67.7,
        ),
        minZoom: 8,
        maxZoom: 16,
        generatedAt: DateTime.now(),
        version: '1.0.0',
        license: 'ODbL',
        attribution: 'OpenStreetMap contributors',
        format: OfflineMapFormat.pmtiles,
      );

      // Simula arquivo .tmp pré-existente com os primeiros 50 bytes
      final targetFile = File('${tempDir.path}/${manifest.id}.pmtiles');
      final tmpFile = File('${targetFile.path}.tmp');
      final partialBytes = fullPayload.sublist(0, 50);
      tmpFile.writeAsBytesSync(partialBytes);

      String? recordedRangeHeader;
      final mockClient = MockClient((request) async {
        recordedRangeHeader = request.headers['Range'];
        // Retorna HTTP 206 Partial Content com os bytes restantes
        return http.Response.bytes(
          fullPayload.sublist(50),
          206,
          headers: {
            'content-range':
                'bytes 50-${fullPayload.length - 1}/${fullPayload.length}',
          },
        );
      });

      final manager = OfflineMapPackageManager(
        storageDir: tempDir,
        httpClient: mockClient,
      );
      addTearDown(manager.dispose);

      final state = await manager.downloadAndInstall(manifest: manifest);
      expect(recordedRangeHeader, equals('bytes=50-'));
      expect(state.status, equals(PackageDownloadStatus.installed));
      expect(targetFile.existsSync(), isTrue);
      expect(targetFile.lengthSync(), equals(fullPayload.length));
    });
  });
}
