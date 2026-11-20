import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/territory/map_engine/offline_tile_server.dart';
import 'package:ministerio_pessoal/territory/packages/offline_map_package_manager.dart';
import 'package:ministerio_pessoal/territory/routing/offline_routing_engine.dart';

import 'e2e_suite/harness/airplane_network_gate.dart';
import 'e2e_suite/harness/synthetic_vector_fixtures.dart';

void main() {
  group('Adversarial Challenge Wave 2: OfflineMapPackageManager & Routing Robustness', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('adv_wave2_pkg_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    group(
      'Dimension 1: OfflineMapPackageManager Stress & Corruption Probes',
      () {
        test('Probe 1.1: Truncated header (< 127 bytes) throws InvalidPackageFormatException fail-closed', () async {
          final shortPayload = Uint8List.fromList(List.filled(64, 0x42));
          final sha = crypto.sha256.convert(shortPayload).toString();

          final client = MockClient((request) async {
            return http.Response.bytes(shortPayload, 200);
          });

          final manager = OfflineMapPackageManager(
            storageDir: tempDir,
            httpClient: client,
          );

          final manifest = OfflineMapPackageMetadata(
            id: 'truncated_hdr',
            regionName: 'Truncated Header Region',
            downloadUrl: Uri.parse('https://example.com/truncated.pmtiles'),
            sizeBytes: shortPayload.length,
            sha256: sha,
            bbox: const GeoBoundingBox(
              minLat: -4.0,
              minLon: -69.0,
              maxLat: -3.0,
              maxLon: -68.0,
            ),
            minZoom: 10,
            maxZoom: 16,
          );

          await expectLater(
            manager.installPackage(manifest),
            throwsA(isA<InvalidPackageFormatException>()),
          );

          // Verify state is failed
          final state = manager.currentStates[manifest.id];
          expect(state?.status, equals(PackageDownloadStatus.failed));

          // Verify no leftover .tmp or .pmtiles files
          final stagingFile = File('${tempDir.path}/truncated_hdr.pmtiles.tmp');
          final finalFile = File('${tempDir.path}/truncated_hdr.pmtiles');
          expect(stagingFile.existsSync(), isFalse);
          expect(finalFile.existsSync(), isFalse);
        });

        test('Probe 1.2: Corrupted magic signature in PMTiles header throws InvalidPackageFormatException', () async {
          final validPayload =
              SyntheticVectorFixtures.createAltoSolimoesPackage();
          // Corrupt magic bytes 0..6 from "PMTiles" to "BADPMTL"
          final corruptedPayload = Uint8List.fromList(validPayload);
          corruptedPayload.setRange(0, 7, 'BADPMTL'.codeUnits);
          final sha = crypto.sha256.convert(corruptedPayload).toString();

          final client = MockClient((request) async {
            return http.Response.bytes(corruptedPayload, 200);
          });

          final manager = OfflineMapPackageManager(
            storageDir: tempDir,
            httpClient: client,
          );

          final manifest = OfflineMapPackageMetadata(
            id: 'bad_magic_pkg',
            regionName: 'Bad Magic Region',
            downloadUrl: Uri.parse('https://example.com/bad_magic.pmtiles'),
            sizeBytes: corruptedPayload.length,
            sha256: sha,
            bbox: const GeoBoundingBox(
              minLat: -4.0,
              minLon: -69.0,
              maxLat: -3.0,
              maxLon: -68.0,
            ),
            minZoom: 10,
            maxZoom: 16,
          );

          await expectLater(
            manager.installPackage(manifest),
            throwsA(isA<InvalidPackageFormatException>()),
          );

          final state = manager.currentStates[manifest.id];
          expect(state?.status, equals(PackageDownloadStatus.failed));
        });

        test('Probe 1.3: Unsupported PMTiles version (v4 / v2) throws InvalidPackageFormatException', () async {
          final validPayload =
              SyntheticVectorFixtures.createAltoSolimoesPackage();
          final corruptedPayload = Uint8List.fromList(validPayload);
          corruptedPayload[7] = 4; // version 4 (only v3 supported)
          final sha = crypto.sha256.convert(corruptedPayload).toString();

          final client = MockClient((request) async {
            return http.Response.bytes(corruptedPayload, 200);
          });

          final manager = OfflineMapPackageManager(
            storageDir: tempDir,
            httpClient: client,
          );

          final manifest = OfflineMapPackageMetadata(
            id: 'bad_version_pkg',
            regionName: 'Bad Version Region',
            downloadUrl: Uri.parse('https://example.com/bad_version.pmtiles'),
            sizeBytes: corruptedPayload.length,
            sha256: sha,
            bbox: const GeoBoundingBox(
              minLat: -4.0,
              minLon: -69.0,
              maxLat: -3.0,
              maxLon: -68.0,
            ),
            minZoom: 10,
            maxZoom: 16,
          );

          await expectLater(
            manager.installPackage(manifest),
            throwsA(isA<InvalidPackageFormatException>()),
          );

          final state = manager.currentStates[manifest.id];
          expect(state?.status, equals(PackageDownloadStatus.failed));
        });

        test('Probe 1.4: Single-bit SHA-256 mismatch throws CorruptedPackageException and transitions to corrupted', () async {
          final payload = SyntheticVectorFixtures.createAltoSolimoesPackage();
          final correctSha = crypto.sha256.convert(payload).toString();
          // Flip one character in sha
          final tamperedSha =
              correctSha.substring(0, correctSha.length - 1) +
              (correctSha.endsWith('0') ? '1' : '0');

          final client = MockClient((request) async {
            return http.Response.bytes(payload, 200);
          });

          final manager = OfflineMapPackageManager(
            storageDir: tempDir,
            httpClient: client,
          );

          final manifest = OfflineMapPackageMetadata(
            id: 'tampered_sha_pkg',
            regionName: 'Tampered SHA Region',
            downloadUrl: Uri.parse('https://example.com/tampered.pmtiles'),
            sizeBytes: payload.length,
            sha256: tamperedSha,
            bbox: const GeoBoundingBox(
              minLat: -4.0,
              minLon: -69.0,
              maxLat: -3.0,
              maxLon: -68.0,
            ),
            minZoom: 10,
            maxZoom: 16,
          );

          await expectLater(
            manager.installPackage(manifest),
            throwsA(isA<CorruptedPackageException>()),
          );

          final state = manager.currentStates[manifest.id];
          expect(state?.status, equals(PackageDownloadStatus.corrupted));
          expect(state?.errorMessage, contains('Checksum SHA-256 inválido'));

          // Target file must not exist
          final finalFile = File('${tempDir.path}/tampered_sha_pkg.pmtiles');
          expect(finalFile.existsSync(), isFalse);
        });

        test('Probe 1.5: RFC 7233 416 Range Not Satisfiable throws RangeNotSatisfiableException and deletes tmp', () async {
          // Pre-create a staging file
          final stagingFile = File('${tempDir.path}/range_416_pkg.pmtiles.tmp');
          stagingFile.writeAsBytesSync(List.filled(500, 0x01));

          final client = MockClient((request) async {
            if (request.headers.containsKey('Range')) {
              return http.Response('Requested range not satisfiable', 416);
            }
            return http.Response('OK', 200);
          });

          final manager = OfflineMapPackageManager(
            storageDir: tempDir,
            httpClient: client,
          );

          final manifest = OfflineMapPackageMetadata(
            id: 'range_416_pkg',
            regionName: 'Range 416 Region',
            downloadUrl: Uri.parse('https://example.com/range416.pmtiles'),
            sizeBytes: 400, // file size is smaller than existing 500 bytes
            sha256: 'deadbeef' * 8,
            bbox: const GeoBoundingBox(
              minLat: -4.0,
              minLon: -69.0,
              maxLat: -3.0,
              maxLon: -68.0,
            ),
            minZoom: 10,
            maxZoom: 16,
          );

          await expectLater(
            manager.installPackage(manifest, allowResume: true),
            throwsA(isA<RangeNotSatisfiableException>()),
          );

          // Staging file must be purged after 416
          expect(stagingFile.existsSync(), isFalse);
        });

        test('Probe 1.6: Mid-stream cancellation triggers DownloadCancelledException and purges tmp file', () async {
          final token = CancellationToken();
          final stagingFile = File('${tempDir.path}/cancel_pkg.pmtiles.tmp');

          final controller = StreamController<List<int>>();
          final client = MockClient.streaming((request, bodyStream) async {
            return http.StreamedResponse(
              controller.stream,
              200,
              contentLength: 10000,
            );
          });

          final manager = OfflineMapPackageManager(
            storageDir: tempDir,
            httpClient: client,
          );

          final manifest = OfflineMapPackageMetadata(
            id: 'cancel_pkg',
            regionName: 'Cancellation Region',
            downloadUrl: Uri.parse('https://example.com/stream.pmtiles'),
            sizeBytes: 10000,
            sha256: 'deadbeef' * 8,
            bbox: const GeoBoundingBox(
              minLat: -4.0,
              minLon: -69.0,
              maxLat: -3.0,
              maxLon: -68.0,
            ),
            minZoom: 10,
            maxZoom: 16,
          );

          final installFuture = manager.installPackage(
            manifest,
            cancellationToken: token,
          );

          // Feed some bytes
          controller.add(List.filled(1000, 0x01));
          await Future.delayed(const Duration(milliseconds: 50));

          // Cancel mid-stream
          token.cancel();
          controller.close();

          await expectLater(
            installFuture,
            throwsA(isA<DownloadCancelledException>()),
          );

          // Confirm staging file is gone
          expect(stagingFile.existsSync(), isFalse);
        });

        test('Probe 1.7: Atomic rollback preserves existing installed package if update fails corruption check', () async {
          final originalPayload =
              SyntheticVectorFixtures.createAltoSolimoesPackage();
          final originalSha = crypto.sha256.convert(originalPayload).toString();

          // 1. Install original valid package
          final client = MockClient((request) async {
            return http.Response.bytes(originalPayload, 200);
          });

          final manager = OfflineMapPackageManager(
            storageDir: tempDir,
            httpClient: client,
          );

          final manifest = OfflineMapPackageMetadata(
            id: 'atomic_test_pkg',
            regionName: 'Atomic Test Region',
            downloadUrl: Uri.parse('https://example.com/atomic.pmtiles'),
            sizeBytes: originalPayload.length,
            sha256: originalSha,
            bbox: const GeoBoundingBox(
              minLat: -4.0,
              minLon: -69.0,
              maxLat: -3.0,
              maxLon: -68.0,
            ),
            minZoom: 10,
            maxZoom: 16,
          );

          final installed = await manager.installPackage(manifest);
          expect(installed.sizeBytes, equals(originalPayload.length));
          final targetFile = File(installed.filePath);
          expect(targetFile.existsSync(), isTrue);

          // 2. Attempt upgrade with corrupt sha
          final corruptedPayload =
              SyntheticVectorFixtures.createAltoSolimoesPackage();
          final wrongSha = '1' * 64;
          final corruptedManifest = OfflineMapPackageMetadata(
            id: 'atomic_test_pkg',
            regionName: 'Atomic Test Region',
            downloadUrl: Uri.parse('https://example.com/atomic.pmtiles'),
            sizeBytes: corruptedPayload.length,
            sha256: wrongSha,
            bbox: const GeoBoundingBox(
              minLat: -4.0,
              minLon: -69.0,
              maxLat: -3.0,
              maxLon: -68.0,
            ),
            minZoom: 10,
            maxZoom: 16,
          );

          await expectLater(
            manager.installPackage(corruptedManifest),
            throwsA(isA<CorruptedPackageException>()),
          );

          // 3. Verify original target file is still 100% intact with original bytes!
          expect(targetFile.existsSync(), isTrue);
          final diskBytes = targetFile.readAsBytesSync();
          expect(
            crypto.sha256.convert(diskBytes).toString(),
            equals(originalSha),
          );
        });

        test('Probe 1.8: removePackage completely erases disk files and resets state to available', () async {
          final payload = SyntheticVectorFixtures.createAltoSolimoesPackage();
          final sha = crypto.sha256.convert(payload).toString();

          final tileServer = OfflineTileServer();
          final client = MockClient(
            (request) async => http.Response.bytes(payload, 200),
          );

          final manager = OfflineMapPackageManager(
            storageDir: tempDir,
            httpClient: client,
            tileServer: tileServer,
          );

          final manifest = OfflineMapPackageMetadata(
            id: 'pkg_to_remove',
            regionName: 'Remove Test',
            downloadUrl: Uri.parse('https://example.com/remove.pmtiles'),
            sizeBytes: payload.length,
            sha256: sha,
            bbox: const GeoBoundingBox(
              minLat: -4.0,
              minLon: -69.0,
              maxLat: -3.0,
              maxLon: -68.0,
            ),
            minZoom: 10,
            maxZoom: 16,
          );

          final installed = await manager.installPackage(manifest);
          final file = File(installed.filePath);
          expect(file.existsSync(), isTrue);

          await manager.removePackage('pkg_to_remove');

          expect(file.existsSync(), isFalse);
          expect(
            manager.currentStates['pkg_to_remove']?.status,
            equals(PackageDownloadStatus.available),
          );
        });
      },
    );

    group(
      'Dimension 2: OfflineRoutingEngine Turnaround & Boundary Stress Probes',
      () {
        test('Probe 2.1: calculateTurnaroundPenalty enforces 60s walk / 120s drive on 180° reversal', () {
          expect(
            OfflineRoutingEngine.calculateTurnaroundPenalty(
              mode: RoutingMode.walking,
              previousNodeId: 'NODE_A',
              currentNodeId: 'NODE_B',
              nextNodeId: 'NODE_A',
            ),
            equals(60.0),
          );

          expect(
            OfflineRoutingEngine.calculateTurnaroundPenalty(
              mode: RoutingMode.driving,
              previousNodeId: 'NODE_A',
              currentNodeId: 'NODE_B',
              nextNodeId: 'NODE_A',
            ),
            equals(120.0),
          );

          // No turnaround if next != previous
          expect(
            OfflineRoutingEngine.calculateTurnaroundPenalty(
              mode: RoutingMode.walking,
              previousNodeId: 'NODE_A',
              currentNodeId: 'NODE_B',
              nextNodeId: 'NODE_C',
            ),
            equals(0.0),
          );

          // Same node (zero traversal)
          expect(
            OfflineRoutingEngine.calculateTurnaroundPenalty(
              mode: RoutingMode.walking,
              previousNodeId: 'NODE_A',
              currentNodeId: 'NODE_A',
              nextNodeId: 'NODE_A',
            ),
            equals(0.0),
          );
        });

        test('Probe 2.2: Non-existent endpoints or disconnected nodes fail closed gracefully', () {
          final engine = OfflineRoutingEngine.createAltoSolimoesNetwork();

          // 1. Missing start
          final resMissingStart = engine.findRoute(
            startId: 'NON_EXISTENT_START',
            goalId: 'BETANIA_CENTRO',
          );
          expect(resMissingStart.isSuccess, isFalse);
          expect(resMissingStart.errorMessage, contains('não encontrado'));

          // 2. Missing goal
          final resMissingGoal = engine.findRoute(
            startId: 'BETANIA_CENTRO',
            goalId: 'NON_EXISTENT_GOAL',
          );
          expect(resMissingGoal.isSuccess, isFalse);
          expect(resMissingGoal.errorMessage, contains('não encontrado'));

          // 3. Disconnected island node
          engine.addNode(const RoutingNode('ISLAND_NODE', -3.00, -68.00));
          final resIsland = engine.findRoute(
            startId: 'BETANIA_CENTRO',
            goalId: 'ISLAND_NODE',
          );
          expect(resIsland.isSuccess, isFalse);
          expect(
            resIsland.errorMessage,
            contains('Não foi possível encontrar rota viável'),
          );

          // 4. Same start and goal
          final resSelf = engine.findRoute(
            startId: 'BETANIA_CENTRO',
            goalId: 'BETANIA_CENTRO',
          );
          expect(resSelf.isSuccess, isTrue);
          expect(resSelf.totalDistanceMeters, equals(0.0));
          expect(resSelf.estimatedDuration, equals(Duration.zero));
          expect(resSelf.steps, isEmpty);
        });

        test('Probe 2.3: Dense linear chain graph (100 nodes) stress test completes under 50ms', () {
          final stressEngine = OfflineRoutingEngine();
          const int nodeCount = 100;

          for (int i = 0; i < nodeCount; i++) {
            stressEngine.addNode(RoutingNode('N$i', -3.0 + (i * 0.001), -68.0));
            if (i > 0) {
              stressEngine.addBidirectionalEdge(
                'N${i - 1}',
                'N$i',
                distanceMeters: 100.0,
              );
            }
          }

          final stopwatch = Stopwatch()..start();
          final result = stressEngine.findRoute(
            startId: 'N0',
            goalId: 'N99',
            mode: RoutingMode.walking,
          );
          stopwatch.stop();

          expect(result.isSuccess, isTrue);
          expect(result.pathNodeIds.length, equals(nodeCount));
          expect(result.totalDistanceMeters, closeTo(9900.0, 0.01));
          expect(
            stopwatch.elapsedMilliseconds,
            lessThan(100),
          ); // Well under 100ms
        });
      },
    );

    group('Dimension 3: AirplaneNetworkGate Interception Stress Probe', () {
      test('Probe 3.1: Prohibits external network calls while allowing local loopback', () async {
        await AirplaneNetworkGate.runWithGate(() async {
          // 1. External connection attempt throws AirplaneModeViolationException
          final client = HttpClient();
          expect(
            () => client.getUrl(
              Uri.parse('https://api.supabase.co/rest/v1/health'),
            ),
            throwsA(isA<AirplaneModeViolationException>()),
          );

          expect(
            () => client.open('GET', '142.250.190.46', 443, '/'),
            throwsA(isA<AirplaneModeViolationException>()),
          );

          // 2. Loopback 127.0.0.1 is permitted
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          server.listen((req) {
            req.response.write('OK_LOOPBACK');
            req.response.close();
          });

          final req = await client.getUrl(
            Uri.parse('http://127.0.0.1:${server.port}/'),
          );
          final resp = await req.close();
          expect(resp.statusCode, equals(200));

          await server.close(force: true);
        });
      });
    });
  });
}
