import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/territory/map_engine/pmtiles_reader.dart';

import 'opaque_box_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AirplaneNetworkGate globalGate;

  setUpAll(() {
    globalGate = AirplaneNetworkGate(airplaneModeActive: true)..install();
  });

  tearDownAll(() {
    globalGate.uninstall();
  });

  group('Milestone E2E-M1: Test Harness & Shared Fixtures Sanity Suite', () {
    // -------------------------------------------------------------------------
    // 1. AirplaneNetworkGate Tests
    // -------------------------------------------------------------------------
    group('AirplaneNetworkGate (Fail-Closed HTTP Isolation)', () {
      late AirplaneNetworkGate gate;

      setUp(() {
        gate = AirplaneNetworkGate(airplaneModeActive: true)..install();
      });

      tearDown(() {
        gate.uninstall();
        // Restaura o gate global para os grupos subsequentes
        globalGate.install();
      });

      test('permits loopback HTTP requests (127.0.0.1 and localhost)', () async {
        expect(gate.isAllowed('127.0.0.1'), isTrue);
        expect(gate.isAllowed('localhost'), isTrue);
        expect(gate.isAllowed('::1'), isTrue);
      });

      test('intercepts external HTTP request and throws AirplaneModeViolationException', () async {
        expect(gate.isAllowed('api.supabase.co'), isFalse);
        expect(gate.isAllowed('example.com'), isFalse);
        expect(gate.isAllowed('192.168.1.100'), isFalse);

        final client = HttpClient();
        expect(
          () => client.getUrl(Uri.parse('http://example.com/api')),
          throwsA(
            isA<AirplaneModeViolationException>()
                .having((e) => e.blockedHost, 'blockedHost', 'example.com')
                .having((e) => e.method, 'method', 'GET')
                .having((e) => e.uri.toString(), 'uri', contains('example.com')),
          ),
        );
      });

      test('allows external requests when airplane mode is toggled off', () {
        gate.airplaneModeActive = false;
        expect(gate.isAllowed('api.supabase.co'), isTrue);
        expect(gate.isAllowed('example.com'), isTrue);
      });

      test('runWithGate executes computation in hermetic network zone', () {
        final result = AirplaneNetworkGate.runWithGate(
          () {
            final client = HttpClient();
            expect(
              () => client.getUrl(Uri.parse('https://external-api.org')),
              throwsA(isA<AirplaneModeViolationException>()),
            );
            return 'blocked_safely';
          },
          airplaneMode: true,
        );
        expect(result, equals('blocked_safely'));
      });
    });

    // -------------------------------------------------------------------------
    // 2. InMemoryEncryptedDb Tests
    // -------------------------------------------------------------------------
    group('InMemoryEncryptedDb (Hermetic & ChaCha20 Verification)', () {
      test('creates in-memory Drift database with foreign keys enabled', () async {
        final db = InMemoryEncryptedDb.createInMemory();
        expect(db, isNotNull);

        // Testa inserção e consulta através do repositório
        final repo = db.asRepository;
        final created = await repo.createPerson(
          name: 'Irmão Pioneiro Teste',
          address: 'Rua Principal, 100',
        );
        expect(created.id, isNotEmpty);

        final person = await repo.getPersonById(created.id);
        expect(person, isNotNull);
        expect(person!.name, equals('Irmão Pioneiro Teste'));

        await db.close();
      });

      test('detects SQLite3MultipleCiphers native extension availability', () {
        final isAvailable = InMemoryEncryptedDb.isSqlite3McAvailable();
        expect(isAvailable, isTrue);
      });

      test('creates disk-backed database and asserts ChaCha20 encryption at rest', () async {
        final handle = await InMemoryEncryptedDb.createEncryptedFileDb();
        addTearDown(handle.dispose);

        const sampleSecret = 'Registro Confidencial Betânia 2026';
        await handle.repo.createPerson(
          name: sampleSecret,
          address: 'Comunidade Betânia - Rio Jandiatuba',
        );

        // Executa asserções fail-closed de criptografia em disco
        await handle.assertChaCha20Encrypted(sampleSecretText: sampleSecret);
      });
    });

    // -------------------------------------------------------------------------
    // 3. TileServerTestLifecycle Tests
    // -------------------------------------------------------------------------
    group('TileServerTestLifecycle (Shelf Loopback 127.0.0.1)', () {
      late TileServerTestLifecycle tileLifecycle;

      setUp(() async {
        tileLifecycle = await TileServerTestLifecycle.createStarted();
      });

      tearDown(() async {
        await tileLifecycle.dispose();
      });

      test('binds to loopback on ephemeral port and serves /status', () async {
        expect(tileLifecycle.isRunning, isTrue);
        expect(tileLifecycle.port, greaterThan(0));
        expect(tileLifecycle.baseUrl, equals('http://127.0.0.1:${tileLifecycle.port}'));

        final res = await tileLifecycle.fetchStatus();
        expect(res.statusCode, equals(200));
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        expect(json['status'], equals('ok'));
        expect(json['port'], equals(tileLifecycle.port));
      });

      test('serves registered PMTiles package header and vector tiles', () async {
        final pmtilesBytes = SyntheticVectorFixtures.createAltoSolimoesPackage();
        await tileLifecycle.registerPmtilesBytes('alto_solimoes', pmtilesBytes);

        // Consulta cabeçalho PMTiles
        final headerRes = await tileLifecycle.fetchPmtilesHeader('alto_solimoes');
        expect(headerRes.statusCode, equals(200));
        expect(headerRes.bodyBytes.length, greaterThanOrEqualTo(127));
        expect(headerRes.bodyBytes.sublist(0, 7), equals([0x50, 0x4D, 0x54, 0x69, 0x6C, 0x65, 0x73]));
        expect(headerRes.bodyBytes[7], equals(3));

        // Requisita tile de Santo Antônio do Içá (z=10, x=318, y=520)
        final tileRes = await tileLifecycle.fetchTile('alto_solimoes', 10, 318, 520);
        expect(tileRes.statusCode, equals(200));
        expect(utf8.decode(tileRes.bodyBytes), contains('Santo Antônio do Içá'));
      });
    });

    // -------------------------------------------------------------------------
    // 4. SyntheticVectorFixtures & AmazonianCoordinates Tests
    // -------------------------------------------------------------------------
    group('SyntheticVectorFixtures & AmazonianCoordinates', () {
      test('canonical Amazonian geographic coordinates are accurate', () {
        expect(AmazonianCoordinates.santoAntonioLat, closeTo(-3.1022, 0.0001));
        expect(AmazonianCoordinates.santoAntonioLon, closeTo(-67.9397, 0.0001));
        expect(AmazonianCoordinates.betaniaLat, closeTo(-3.1700, 0.0001));
        expect(AmazonianCoordinates.betaniaLon, closeTo(-68.0800, 0.0001));
        expect(AmazonianCoordinates.lagoGrandeLat, closeTo(-3.2500, 0.0001));
        expect(AmazonianCoordinates.lagoGrandeLon, closeTo(-67.8500, 0.0001));

        expect(
          AmazonianCoordinates.containsCoordinate(
            AmazonianCoordinates.santoAntonioLat,
            AmazonianCoordinates.santoAntonioLon,
          ),
          isTrue,
        );
      });

      test('Haversine distance accurately measures distance between communities', () {
        final dist = AmazonianCoordinates.haversineDistanceMeters(
          AmazonianCoordinates.santoAntonioLat,
          AmazonianCoordinates.santoAntonioLon,
          AmazonianCoordinates.betaniaLat,
          AmazonianCoordinates.betaniaLon,
        );
        // Distância Santo Antônio do Içá <-> Betânia é ~17.3 km
        expect(dist, greaterThan(15000));
        expect(dist, lessThan(20000));
      });

      test('fluvial barrier accurately detects river crossing attempts', () {
        // Trajeto entre Betânia (norte) e Lago Grande (sul) cruza o Rio Solimões
        final isCrossing = AmazonianCoordinates.isFluvialBarrierCrossing(
          AmazonianCoordinates.betaniaLat,
          AmazonianCoordinates.betaniaLon,
          AmazonianCoordinates.lagoGrandeLat,
          AmazonianCoordinates.lagoGrandeLon,
        );
        expect(isCrossing, isTrue);

        // Trajeto entre Betânia e Santo Antônio do Içá (ambos ao norte) não cruza o Solimões
        final isNotCrossing = AmazonianCoordinates.isFluvialBarrierCrossing(
          AmazonianCoordinates.betaniaLat,
          AmazonianCoordinates.betaniaLon,
          AmazonianCoordinates.santoAntonioLat,
          AmazonianCoordinates.santoAntonioLon,
        );
        expect(isNotCrossing, isFalse);
      });

      test('synthesizes valid PMTiles v3 archive decodable by PmtilesReader', () async {
        final archiveBytes = SyntheticVectorFixtures.createAltoSolimoesPackage();
        final tempFile = File('${Directory.systemTemp.path}/test_sai.pmtiles');
        await tempFile.writeAsBytes(archiveBytes, flush: true);
        addTearDown(() async {
          if (tempFile.existsSync()) await tempFile.delete();
        });

        final reader = PmtilesReader(tempFile);
        final header = await reader.getHeader();

        expect(header.specVersion, equals(3));
        expect(header.numAddressedTiles, equals(3));
        expect(header.tileType, equals(PmtilesTileType.mvt));
        expect(header.centerLat, closeTo(AmazonianCoordinates.santoAntonioLat, 0.001));
        expect(header.centerLon, closeTo(AmazonianCoordinates.santoAntonioLon, 0.001));

        // Busca o tile (z=10, x=318, y=520) através do reader
        final tileData = await reader.getTile(10, 318, 520);
        expect(tileData, isNotNull);
        expect(utf8.decode(tileData!), contains('Santo Antônio do Içá'));
      });

      test('synthesizes corrupted archives that trigger fail-closed validation', () async {
        final tooShort = SyntheticVectorFixtures.createCorruptedArchive(tooShort: true);
        expect(tooShort.length, lessThan(127));

        final badMagic = SyntheticVectorFixtures.createCorruptedArchive(badMagic: true);
        expect(badMagic.length, equals(127));

        final badVersion = SyntheticVectorFixtures.createCorruptedArchive(customVersion: 4);
        expect(badVersion[7], equals(4));
      });
    });

    // -------------------------------------------------------------------------
    // 5. OpaqueBoxHarness Integration Tests
    // -------------------------------------------------------------------------
    group('OpaqueBoxHarness (Unified Lifecycle & Device Presets)', () {
      test('initializes all subcomponents in hermetic airplane mode', () async {
        final harness = await OpaqueBoxHarness.create(airplaneMode: true);
        addTearDown(harness.dispose);

        expect(harness.airplaneMode, isTrue);
        expect(harness.networkGate.airplaneModeActive, isTrue);
        expect(harness.tileServer, isNotNull);
        expect(harness.tileServer!.isRunning, isTrue);
        expect(harness.db, isNotNull);
        expect(harness.repo, isNotNull);
        expect(harness.settings, isNotNull);

        // Verifica que chamadas locais para o tileServer funcionam
        final statusRes = await harness.tileServer!.fetchStatus();
        expect(statusRes.statusCode, equals(200));

        // Verifica que chamadas externas são interceptadas pelo gate
        final client = HttpClient();
        expect(
          () => client.getUrl(Uri.parse('https://remote.service.com')),
          throwsA(isA<AirplaneModeViolationException>()),
        );
      });

      testWidgets('buildApp pumps widget in responsive viewports (Phone & Tablet)', (tester) async {
        late OpaqueBoxHarness harness;
        await tester.runAsync(() async {
          harness = await OpaqueBoxHarness.create(airplaneMode: true);
        });
        addTearDown(() async {
          await tester.runAsync(harness.dispose);
        });

        final testWidget = Builder(
          builder: (context) {
            final mediaQuery = MediaQuery.of(context);
            final isWide = mediaQuery.size.width >= 900;
            return Scaffold(
              body: Center(
                child: Text(
                  isWide ? 'Layout Amplo (Tablet)' : 'Layout Compacto (Phone)',
                  textDirection: TextDirection.ltr,
                ),
              ),
            );
          },
        );

        // 1. Testa viewport Phone (390 x 844)
        await tester.pumpHarnessScreen(
          screen: testWidget,
          harness: harness,
          devicePreset: E2EDevicePreset.phone,
        );
        expect(find.text('Layout Compacto (Phone)'), findsOneWidget);
        expect(tester.view.physicalSize, equals(const Size(390, 844)));

        // 2. Testa viewport Tablet em Paisagem (1024 x 768)
        await tester.pumpHarnessScreen(
          screen: testWidget,
          harness: harness,
          devicePreset: E2EDevicePreset.tablet,
        );
        expect(find.text('Layout Amplo (Tablet)'), findsOneWidget);
        expect(tester.view.physicalSize, equals(const Size(1024, 768)));
      });
    });
  });
}

extension on AppDatabase {
  AppRepository get asRepository => AppRepository(this);
}
