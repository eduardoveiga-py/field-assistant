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
      final bd = ByteData.sublistView(header);

      const rootDirOffset = 127;
      const rootDirLength = 32;
      bd.setUint32(8, rootDirOffset, Endian.little);
      bd.setUint32(16, rootDirLength, Endian.little);

      final contentBytes = utf8.encode(content);
      const tileDataOffset = rootDirOffset + rootDirLength;
      final tileDataLength = contentBytes.isNotEmpty ? contentBytes.length : 64;
      bd.setUint32(56, tileDataOffset, Endian.little);
      bd.setUint32(64, tileDataLength, Endian.little);

      bd.setUint32(72, 1, Endian.little); // numAddressedTiles
      bd.setUint32(80, 1, Endian.little); // numTileEntries

      header[96] = 1; // clustered
      header[97] = 1; // internalCompression (none)
      header[98] = 1; // tileCompression (none)
      header[99] = 1; // tileType (mvt)
      header[100] = 8; // minZoom
      header[101] = 16; // maxZoom

      bd.setInt32(102, (-68.20 * 10000000).round(), Endian.little); // minLon
      bd.setInt32(106, (-3.40 * 10000000).round(), Endian.little); // minLat
      bd.setInt32(110, (-67.70 * 10000000).round(), Endian.little); // maxLon
      bd.setInt32(114, (-3.00 * 10000000).round(), Endian.little); // maxLat

      header[118] = 10; // centerZoom
      bd.setInt32(119, (-68.00 * 10000000).round(), Endian.little); // centerLon
      bd.setInt32(123, (-3.20 * 10000000).round(), Endian.little); // centerLat

      final builder = BytesBuilder();
      builder.add(header);
      builder.add(Uint8List(rootDirLength));
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

    test('TC-PKGMGR-04: validatePmtilesHeader rejects synthetic dummy PMTiles header and invalid coordinates', () {
      // 1. Cabeçalho sintético gerado por scripts legados (64 KB de zeros sem diretório nem tiles)
      final dummyHeader = Uint8List(127);
      dummyHeader.setRange(0, 7, 'PMTiles'.codeUnits);
      dummyHeader[7] = 3;

      expect(
        () => OfflineMapPackageManager.validatePmtilesHeader(dummyHeader),
        throwsA(
          isA<InvalidPackageFormatException>().having(
            (e) => e.message,
            'message',
            contains(
              'Pacote PMTiles sintético ou corrompido: cabeçalho sem diretório ou tiles válidos.',
            ),
          ),
        ),
      );

      // 2. Cabeçalho com bounding box invertido (minLon >= maxLon)
      final invertedHeader = createValidPmtilesBytes('dummy').sublist(0, 127);
      final bd = ByteData.sublistView(invertedHeader);
      // Inverte: minLon = 10, maxLon = -10
      bd.setInt32(102, (10.0 * 10000000).round(), Endian.little);
      bd.setInt32(110, (-10.0 * 10000000).round(), Endian.little);

      expect(
        () => OfflineMapPackageManager.validatePmtilesHeader(invertedHeader),
        throwsA(isA<InvalidPackageFormatException>()),
      );

      // 3. Cabeçalho menor que 127 bytes
      expect(
        () => OfflineMapPackageManager.validatePmtilesHeader(Uint8List(64)),
        throwsA(isA<InvalidPackageFormatException>()),
      );
    });

    test('TC-PKGMGR-05: validateMbtilesHeader verifies SQLite magic and rejects non-SQLite files', () {
      final validSqliteHeader = Uint8List.fromList(
        utf8.encode('SQLite format 3\x00extra-header-data-1234'),
      );
      expect(
        () => OfflineMapPackageManager.validateMbtilesHeader(validSqliteHeader),
        returnsNormally,
      );

      final invalidSqliteHeader = Uint8List.fromList(
        utf8.encode('INVALID MAGIC 12\x00extra-header-data-1234'),
      );
      expect(
        () =>
            OfflineMapPackageManager.validateMbtilesHeader(invalidSqliteHeader),
        throwsA(isA<InvalidPackageFormatException>()),
      );

      expect(
        () => OfflineMapPackageManager.validateMbtilesHeader(Uint8List(10)),
        throwsA(isA<InvalidPackageFormatException>()),
      );
    });

    test('TC-PKGMGR-06: Transient network failure (ClientException) preserves .tmp file for resumption', () async {
      final fullPayload = createValidPmtilesBytes('TransientFailureTestData');
      final fullSha = crypto.sha256.convert(fullPayload).toString();

      final manifest = OfflineMapPackageManifest(
        id: 'test_pkg_transient',
        regionName: 'Região Transitória',
        downloadUrl: Uri.parse('https://example.com/transient.pmtiles'),
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

      final mockClient = MockClient((request) async {
        throw http.ClientException('Network connection reset by peer');
      });

      final manager = OfflineMapPackageManager(
        storageDir: tempDir,
        httpClient: mockClient,
      );
      addTearDown(manager.dispose);

      // Pré-grava 30 bytes no .tmp
      final targetFile = File('${tempDir.path}/${manifest.id}.pmtiles');
      final tmpFile = File('${targetFile.path}.tmp');
      tmpFile.writeAsBytesSync(fullPayload.sublist(0, 30));

      await expectLater(
        () => manager.downloadAndInstall(manifest: manifest),
        throwsA(isA<http.ClientException>()),
      );

      // O arquivo .tmp NÃO pode ser apagado em falhas transitórias
      expect(tmpFile.existsSync(), isTrue);
      expect(tmpFile.lengthSync(), equals(30));
    });

    test('TC-PKGMGR-07: Resilient resumption: server HTTP 200 response truncates .tmp cleanly', () async {
      final fullPayload = createValidPmtilesBytes(
        'ServerResponded200InsteadOf206',
      );
      final fullSha = crypto.sha256.convert(fullPayload).toString();

      final manifest = OfflineMapPackageManifest(
        id: 'test_pkg_200_truncation',
        regionName: 'Região Truncamento 200',
        downloadUrl: Uri.parse('https://example.com/truncate.pmtiles'),
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

      final targetFile = File('${tempDir.path}/${manifest.id}.pmtiles');
      final tmpFile = File('${targetFile.path}.tmp');
      // Escreve bytes residuais parciais
      tmpFile.writeAsBytesSync(fullPayload.sublist(0, 25));

      final mockClient200 = MockClient((request) async {
        return http.Response.bytes(fullPayload, 200);
      });

      final manager200 = OfflineMapPackageManager(
        storageDir: tempDir,
        httpClient: mockClient200,
      );
      addTearDown(manager200.dispose);

      final state = await manager200.downloadAndInstall(manifest: manifest);
      expect(state.status, equals(PackageDownloadStatus.installed));
      expect(targetFile.existsSync(), isTrue);
      expect(targetFile.lengthSync(), equals(fullPayload.length));
    });

    test('TC-PKGMGR-08: Mismatched HTTP 206 Content-Range restarts cleanly from byte 0', () async {
      final fullPayload = createValidPmtilesBytes(
        'ContentRangeMismatchHandling',
      );
      final fullSha = crypto.sha256.convert(fullPayload).toString();

      final manifest = OfflineMapPackageManifest(
        id: 'test_pkg_range_mismatch',
        regionName: 'Região Mismatch 206',
        downloadUrl: Uri.parse('https://example.com/mismatch.pmtiles'),
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

      final targetFile = File('${tempDir.path}/${manifest.id}.pmtiles');
      final tmpFile = File('${targetFile.path}.tmp');
      tmpFile.writeAsBytesSync(fullPayload.sublist(0, 40));

      // Servidor envia 206, mas Content-Range começa do byte 0 em vez de 40 (mismatch)
      final mockClientMismatch = MockClient((request) async {
        return http.Response.bytes(
          fullPayload,
          206,
          headers: {
            'content-range':
                'bytes 0-${fullPayload.length - 1}/${fullPayload.length}',
          },
        );
      });

      final managerMismatch = OfflineMapPackageManager(
        storageDir: tempDir,
        httpClient: mockClientMismatch,
      );
      addTearDown(managerMismatch.dispose);

      final state = await managerMismatch.downloadAndInstall(
        manifest: manifest,
      );
      expect(state.status, equals(PackageDownloadStatus.installed));
      expect(targetFile.existsSync(), isTrue);
      expect(targetFile.lengthSync(), equals(fullPayload.length));
    });

    test('TC-PKGMGR-09: syncWithDisk restores surviving valid .bak file when primary file is missing', () async {
      final payload = createValidPmtilesBytes('BackupRestorationData2026');
      final expectedSha = crypto.sha256.convert(payload).toString();

      final manifest = OfflineMapPackageManifest(
        id: 'test_pkg_backup_restore',
        regionName: 'Região de Backup',
        downloadUrl: Uri.parse('https://example.com/backup.pmtiles'),
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

      final finalFile = File('${tempDir.path}/${manifest.id}.pmtiles');
      final backupFile = File('${finalFile.path}.bak');

      // Garante que o arquivo principal não existe, mas o backup sim
      if (finalFile.existsSync()) finalFile.deleteSync();
      backupFile.writeAsBytesSync(payload);

      final manager = OfflineMapPackageManager(storageDir: tempDir);
      addTearDown(manager.dispose);

      await manager.syncWithDisk(manifests: [manifest]);

      // Verifica que o backup foi restaurado para o arquivo principal
      expect(finalFile.existsSync(), isTrue);
      expect(backupFile.existsSync(), isFalse);
      expect(finalFile.lengthSync(), equals(payload.length));

      final state = manager.currentStates[manifest.id];
      expect(state, isNotNull);
      expect(state!.status, equals(PackageDownloadStatus.installed));
      expect(state.localFile?.path, equals(finalFile.path));
    });

    test('TC-PKGMGR-10: syncWithDisk rejects corrupted .bak and does not restore it', () async {
      final corruptPayload = Uint8List(127); // Dummy zerado sem PMTiles válido
      final manifest = OfflineMapPackageManifest(
        id: 'test_pkg_corrupt_bak',
        regionName: 'Região de Backup Corrompido',
        downloadUrl: Uri.parse('https://example.com/corrupt_bak.pmtiles'),
        sizeBytes: corruptPayload.length,
        sha256:
            '0000000000000000000000000000000000000000000000000000000000000000',
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

      final finalFile = File('${tempDir.path}/${manifest.id}.pmtiles');
      final backupFile = File('${finalFile.path}.bak');

      if (finalFile.existsSync()) finalFile.deleteSync();
      backupFile.writeAsBytesSync(corruptPayload);

      final manager = OfflineMapPackageManager(storageDir: tempDir);
      addTearDown(manager.dispose);

      await manager.syncWithDisk(manifests: [manifest]);

      // O arquivo principal continua não existindo
      expect(finalFile.existsSync(), isFalse);
      // O status continua available (não instalado)
      final state = manager.currentStates[manifest.id];
      expect(state, isNotNull);
      expect(state!.status, equals(PackageDownloadStatus.available));
    });
  });
}
