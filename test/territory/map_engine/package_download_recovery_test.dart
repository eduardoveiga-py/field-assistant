import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/territory/map_engine/offline_map_package_manager.dart';

void main() {
  late Directory directory;
  late Uint8List bytes;
  late OfflineMapPackageManifest manifest;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('package-recovery-');
    bytes = Uint8List.fromList([
      ...utf8.encode('PMTiles'),
      3,
      ...List.filled(119, 0),
      ...List.generate(100, (i) => i),
    ]);
    manifest = OfflineMapPackageManifest(
      id: 'test_region',
      regionName: 'Test region',
      downloadUrl: Uri.parse('https://example.com/immutable.pmtiles'),
      sizeBytes: bytes.length,
      sha256: crypto.sha256.convert(bytes).toString(),
      bbox: const GeoBoundingBox(
        minLat: -4,
        minLon: -68,
        maxLat: -3,
        maxLon: -67,
      ),
      minZoom: 0,
      maxZoom: 14,
    );
  });

  tearDown(() => directory.deleteSync(recursive: true));

  test(
    'interrupted download preserves bytes and resumes after correct 206',
    () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        if (requests == 1)
          return http.Response.bytes(bytes.sublist(0, 80), 200);
        expect(request.headers['Range'], 'bytes=80-');
        return http.Response.bytes(
          bytes.sublist(80),
          206,
          headers: {
            'content-range': 'bytes 80-${bytes.length - 1}/${bytes.length}',
          },
        );
      });
      final manager = OfflineMapPackageManager(
        storageDir: directory,
        httpClient: client,
      );
      addTearDown(manager.dispose);
      await expectLater(
        manager.downloadAndInstall(manifest: manifest),
        throwsA(isA<DownloadInterruptedException>()),
      );
      final target = await manager.getPackageFile(manifest);
      expect(await File('${target.path}.tmp').length(), 80);
      final installed = await manager.downloadAndInstall(manifest: manifest);
      expect(installed.status, PackageDownloadStatus.installed);
      expect(await target.readAsBytes(), bytes);
    },
  );

  test(
    'incorrect Content-Range fails without replacing an installed package',
    () async {
      final original = Uint8List.fromList([1, 2, 3]);
      final target = File('${directory.path}/${manifest.id}.pmtiles');
      await target.writeAsBytes(original);
      await File('${target.path}.tmp').writeAsBytes(bytes.sublist(0, 80));
      final client = MockClient(
        (request) async => http.Response.bytes(
          bytes.sublist(80),
          206,
          headers: {
            'content-range': 'bytes 81-${bytes.length - 1}/${bytes.length}',
          },
        ),
      );
      final manager = OfflineMapPackageManager(
        storageDir: directory,
        httpClient: client,
      );
      addTearDown(manager.dispose);
      await expectLater(
        manager.downloadAndInstall(manifest: manifest),
        throwsA(isA<InvalidPackageFormatException>()),
      );
      expect(await target.readAsBytes(), original);
    },
  );

  test(
    'sync restores a sole backup after interruption before installing',
    () async {
      final target = File('${directory.path}/${manifest.id}.pmtiles');
      final backup = File('${target.path}.bak');
      await backup.writeAsBytes(bytes);
      final manager = OfflineMapPackageManager(
        storageDir: directory,
        catalog: [manifest],
      );
      addTearDown(manager.dispose);
      await manager.syncWithDisk();
      expect(await target.readAsBytes(), bytes);
      expect(backup.existsSync(), isFalse);
      expect(
        manager.currentStates[manifest.id]!.status,
        PackageDownloadStatus.installed,
      );
    },
  );

  test('existing backup is never overwritten during replacement', () async {
    final target = File('${directory.path}/${manifest.id}.pmtiles');
    final backup = File('${target.path}.bak');
    await target.writeAsBytes([1]);
    await backup.writeAsBytes([2]);
    final manager = OfflineMapPackageManager(
      storageDir: directory,
      httpClient: MockClient((_) async => http.Response.bytes(bytes, 200)),
    );
    addTearDown(manager.dispose);
    await expectLater(
      manager.downloadAndInstall(manifest: manifest),
      throwsA(isA<FileSystemException>()),
    );
    expect(await target.readAsBytes(), [1]);
    expect(await backup.readAsBytes(), [2]);
  });

  test(
    'same-instance concurrent installation and removal are rejected',
    () async {
      final release = Completer<void>();
      final started = Completer<void>();
      final manager = OfflineMapPackageManager(
        storageDir: directory,
        httpClient: MockClient((_) async {
          started.complete();
          await release.future;
          return http.Response.bytes(bytes, 200);
        }),
      );
      addTearDown(manager.dispose);
      final first = manager.downloadAndInstall(manifest: manifest);
      await started.future;
      await expectLater(
        manager.downloadAndInstall(manifest: manifest),
        throwsStateError,
      );
      await expectLater(manager.removePackage(manifest.id), throwsStateError);
      release.complete();
      expect((await first).isInstalled, isTrue);
    },
  );
  for (final preserve in [false, true]) {
    test(
      'cancel closes the response before ${preserve ? 'preserving' : 'purging'} temporary data',
      () async {
        final firstChunk = Completer<void>();
        final controller = StreamController<List<int>>();
        final manager = OfflineMapPackageManager(
          storageDir: directory,
          httpClient: MockClient.streaming(
            (_, __) async => http.StreamedResponse(controller.stream, 200),
          ),
        );
        addTearDown(manager.dispose);
        final download = manager.downloadAndInstall(
          manifest: manifest,
          onProgress: (progress) {
            if (progress > 0 && !firstChunk.isCompleted) firstChunk.complete();
          },
        );
        final result = expectLater(
          download,
          throwsA(isA<DownloadCancelledException>()),
        );
        controller.add(bytes.sublist(0, 80));
        await firstChunk.future;
        await manager.cancelDownload(manifest.id, purgeTempFile: !preserve);
        await result;
        await controller.close();
        final target = await manager.getPackageFile(manifest);
        final partial = File('${target.path}.tmp');
        expect(partial.existsSync(), preserve);
        if (preserve) expect(await partial.readAsBytes(), bytes.sublist(0, 80));
        expect(target.existsSync(), isFalse);
      },
    );
  }
}
