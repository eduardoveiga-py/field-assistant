import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/territory/map_engine/map_engine_selector.dart';
import 'package:ministerio_pessoal/territory/map_engine/maplibre_native_adapter.dart';
import 'package:ministerio_pessoal/territory/map_engine/raster_fallback_adapter.dart';
import 'package:ministerio_pessoal/territory/map_engine_adapter.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_backend.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_native.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_service.dart';
import 'package:ministerio_pessoal/territory/sector_manager.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/contacts_map_screen.dart';
import 'package:ministerio_pessoal/ui/widgets/map/maplibre_vector_map_view.dart';

Uint8List _buildMinimalValidPmtilesV3Bytes() {
  final header = Uint8List(127);
  // Magic: "PMTiles" (7 bytes) + version 3 at byte 7
  final magic = 'PMTiles'.codeUnits;
  for (var i = 0; i < magic.length; i++) {
    header[i] = magic[i];
  }
  header[7] = 3;
  // Tile type = MVT (1) at offset 99, minZoom = 0 at 100, maxZoom = 14 at 101
  header[99] = 1;
  header[100] = 0;
  header[101] = 14;
  return header;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapEngineSelector & PMTiles Vector Package Activation (P0-02)', () {
    test('selects MaplibreNativeAdapter automatically on iOS/Android when a vector PMTiles package is installed', () {
      final tempDir = Directory.systemTemp.createTempSync('map_sel_pm_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final pmFile = File('${tempDir.path}/am_vector.pmtiles')
        ..writeAsBytesSync(_buildMinimalValidPmtilesV3Bytes());

      final selection = MapEngineSelector.resolve(
        preference: MapEnginePreference.auto,
        platformSupportsMapLibre: true,
        packagesDirectoryPath: tempDir.path,
        installedPackages: [
          InstalledOfflineMapPackage(
            id: 'am_vector',
            format: OfflineMapFormat.pmtiles,
            isVector: true,
            filePath: pmFile.path,
            sizeBytes: pmFile.lengthSync(),
          ),
        ],
      );
      addTearDown(() {
        if (selection.ownsAdapter) selection.adapter.dispose();
      });

      expect(selection.adapter, isA<MaplibreNativeAdapter>());
      expect(selection.usesVectorEngine, isTrue);
      expect(selection.activePackageId, equals('am_vector'));
      expect(selection.activePackageFormat, equals(OfflineMapFormat.pmtiles));
    });

    test('keeps safe RasterFallbackAdapter on desktop or when only raster packages exist in auto mode', () {
      final desktopSelection = MapEngineSelector.resolve(
        preference: MapEnginePreference.auto,
        platformSupportsMapLibre: false,
        installedPackages: const [
          InstalledOfflineMapPackage(
            id: 'am_vector',
            format: OfflineMapFormat.pmtiles,
            isVector: true,
            filePath: '/tmp/am_vector.pmtiles',
            sizeBytes: 127,
          ),
        ],
      );
      addTearDown(() => desktopSelection.adapter.dispose());
      expect(desktopSelection.adapter, isA<RasterFallbackAdapter>());
      expect(desktopSelection.usesVectorEngine, isFalse);

      final rasterOnlySelection = MapEngineSelector.resolve(
        preference: MapEnginePreference.auto,
        platformSupportsMapLibre: true,
        installedPackages: const [
          InstalledOfflineMapPackage(
            id: 'br_am_solimoes',
            format: OfflineMapFormat.mbtiles,
            isVector: false,
            filePath: '/tmp/br_am_solimoes.mbtiles',
            sizeBytes: 1024,
          ),
        ],
      );
      addTearDown(() => rasterOnlySelection.adapter.dispose());
      expect(rasterOnlySelection.adapter, isA<RasterFallbackAdapter>());
      expect(rasterOnlySelection.usesVectorEngine, isFalse);
    });

    test('selects MaplibreNativeAdapter when user explicitly chooses vectorMapLibre on supported platform', () {
      final selection = MapEngineSelector.resolve(
        preference: MapEnginePreference.vectorMapLibre,
        platformSupportsMapLibre: true,
        installedPackages: const [],
      );
      addTearDown(() => selection.adapter.dispose());

      expect(selection.adapter, isA<MaplibreNativeAdapter>());
      expect(selection.usesVectorEngine, isTrue);
    });

    test('MBTilesService imports, validates, and discovers local .pmtiles vector packages', () async {
      final tempDir = Directory.systemTemp.createTempSync('mbtiles_pm_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final srcValid = File('${tempDir.path}/source_valid.pmtiles')
        ..writeAsBytesSync(_buildMinimalValidPmtilesV3Bytes());
      final srcInvalid = File('${tempDir.path}/source_invalid.pmtiles')
        ..writeAsBytesSync(Uint8List.fromList([1, 2, 3, 4, 5]));

      final storageDir = Directory('${tempDir.path}/store')..createSync();
      final service = MBTilesService.custom(
        backend: MBTilesNative(customDir: storageDir),
      );
      addTearDown(service.dispose);
      await service.init();

      await expectLater(
        service.importLocalPmtiles(sourceFilePath: srcInvalid.path),
        throwsA(isA<FormatException>()),
      );

      final imported = await service.importLocalPmtiles(
        regionId: 'am_vec_01',
        sourceFilePath: srcValid.path,
        displayName: 'Amazonas Vetorial',
      );
      expect(imported.id, equals('am_vec_01'));
      expect(imported.isInstalled, isTrue);
      expect(service.primaryVectorPackage, isNotNull);
      expect(service.primaryVectorPackage!.id, equals('am_vec_01'));
      expect(
        service.primaryVectorPackage!.format,
        equals(OfflineMapFormat.pmtiles),
      );
      expect(service.primaryVectorPackage!.isVector, isTrue);
    });

    test('buildSectorOverlayMaps constructs valid closed GeoJSON polygon rings for geocoded sector contacts', () {
      final now = DateTime.now();
      final sectors = [
        TerritorySector(id: 's1', name: 'Centro', createdAt: now),
        TerritorySector(id: 's2', name: 'Sem Contatos', createdAt: now),
      ];
      final contacts = [
        PersonEntry(
          id: 'p1',
          name: 'Maria',
          status: 'revisita',
          address: 'Rua A, Centro',
          tags: '',
          latitude: -3.100,
          longitude: -60.020,
          firstContactAt: now,
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
        PersonEntry(
          id: 'p2',
          name: 'João',
          status: 'estudo',
          address: 'Av B, Centro',
          tags: '',
          latitude: -3.105,
          longitude: -60.025,
          firstContactAt: now,
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
        PersonEntry(
          id: 'p3',
          name: 'Ana',
          status: 'interessado',
          address: 'Travessa C, Centro',
          tags: '',
          latitude: -3.102,
          longitude: -60.015,
          firstContactAt: now,
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
      ];

      final overlays = MapEngineSelector.buildSectorOverlayMaps(
        sectors: sectors,
        contacts: contacts,
      );
      expect(overlays, hasLength(1));
      expect(overlays.first['id'], equals('s1'));
      expect(overlays.first['name'], equals('Centro'));
      final coords = overlays.first['coordinates'] as List;
      final ring = coords.first as List;
      expect(ring.length, greaterThanOrEqualTo(4));
      expect(ring.first, equals(ring.last));
    });

    testWidgets(
      'ContactsMapScreen wires packageId, packageFormat, and sectors into MapLibreVectorMapView on iOS',
      (tester) async {
        final prevPlatform = debugDefaultTargetPlatformOverride;
        final prevService = MBTilesService.instance;
        final tempDir = Directory.systemTemp.createTempSync('map_screen_pm_');
        final storageDir = Directory('${tempDir.path}/store')..createSync();
        final srcValid = File('${tempDir.path}/regiao_vec.pmtiles')
          ..writeAsBytesSync(_buildMinimalValidPmtilesV3Bytes());

        final testService = MBTilesService.custom(
          backend: MBTilesNative(customDir: storageDir),
        );
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final repo = AppRepository(db);
        final sectorManager = SectorManager(db);
        await tester.runAsync(() async {
          await testService.init();
          await testService.importLocalPmtiles(
            regionId: 'regiao_vec',
            sourceFilePath: srcValid.path,
          );
          await sectorManager.addSector('Centro');
          await repo.createPerson(
            name: 'Carlos',
            status: 'estudo',
            address: 'Rua Principal, Centro',
            latitude: -3.101,
            longitude: -60.021,
            firstContactAt: DateTime.now(),
          );
        });
        MBTilesService.setMockInstance(testService);
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        final adapter = MaplibreNativeAdapter();
        addTearDown(() async {
          debugDefaultTargetPlatformOverride = prevPlatform;
          MBTilesService.setMockInstance(prevService);
          adapter.dispose();
          testService.dispose();
          await db.close();
          try {
            if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
          } catch (_) {}
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
            ],
            child: MaterialApp(
              home: ContactsMapScreen(mapEngineAdapter: adapter),
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final vectorViewFinder = find.byType(MapLibreVectorMapView);
        expect(vectorViewFinder, findsOneWidget);

        final vectorView = tester.widget<MapLibreVectorMapView>(
          vectorViewFinder,
        );
        expect(vectorView.packageId, equals('regiao_vec'));
        expect(vectorView.packageFormat, equals(OfflineMapFormat.pmtiles));
        expect(vectorView.sectors, hasLength(1));
        expect(vectorView.sectors.first['name'], equals('Centro'));

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
        debugDefaultTargetPlatformOverride = prevPlatform;
      },
    );
  });
}
