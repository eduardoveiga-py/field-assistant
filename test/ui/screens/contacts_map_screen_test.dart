import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/territory/geolocation_helper.dart';
import 'package:ministerio_pessoal/territory/map_engine_adapter.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_service.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_web.dart';
import 'package:ministerio_pessoal/territory/tile_cache/tile_cache_service.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/contacts_map_screen.dart';

class _EmptyTiles implements TileCacheBackend {
  @override
  Future<Uint8List?> getTile(
    int z,
    int x,
    int y, [
    MapLayerStyle? style,
  ]) async => null;
  @override
  Future<void> saveTile(
    int z,
    int x,
    int y,
    Uint8List bytes, [
    MapLayerStyle? style,
  ]) async {}
  @override
  Future<bool> isTileCached(
    int z,
    int x,
    int y, [
    MapLayerStyle? style,
  ]) async => false;
  @override
  Future<int> getCachedTileCount([MapLayerStyle? style]) async => 0;
}

class _TestMapEngineAdapter implements MapEngineAdapter {
  final List<MapViewportState> cameraMoves = [];

  @override
  String get engineName => 'TestEngine';

  @override
  MapEngineCapabilities get capabilities => const MapEngineCapabilities(
    vectorRendering: false,
    supportsRotation: true,
    supportsTilt: false,
    supportsOfflinePackages: true,
    supportsOfflineContactsOverlay: true,
    supportsOfflineRouting: false,
  );

  @override
  Future<void> initialize() async {}

  @override
  Future<void> moveCamera(MapViewportState viewport) async {
    cameraMoves.add(viewport);
  }

  @override
  Future<void> setOfflinePackages(
    List<OfflineMapPackageManifest> packages,
  ) async {}

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    GeolocationHelper.locationOverride = null;
    final mock = MBTilesService.custom(backend: MBTilesWeb());
    MBTilesService.setMockInstance(mock);
    TileCacheService.instance.backend = _EmptyTiles();
  });

  tearDown(() {
    GeolocationHelper.locationOverride = null;
  });

  group('R4: ContactsMapScreen GPS Location & Camera Tests', () {
    testWidgets(
      'TC-GPS-01: Opens at default Santo Antônio do Içá coordinates when cache and GPS are empty',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final db = AppDatabase.forTesting(NativeDatabase.memory());

        // Sem GPS e sem cache
        GeolocationHelper.locationOverride = () async =>
            const GeolocationResult(
              status: GeolocationStatus.unavailableOrTimeout,
              coordinates: null,
            );

        final adapter = _TestMapEngineAdapter();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              home: ContactsMapScreen(mapEngineAdapter: adapter),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(adapter.cameraMoves, isNotEmpty);
        final initialMove = adapter.cameraMoves.first;
        expect(
          initialMove.latitude,
          closeTo(GeolocationHelper.defaultLat, 0.001),
        );
        expect(
          initialMove.longitude,
          closeTo(GeolocationHelper.defaultLng, 0.001),
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await db.close();
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'TC-GPS-02: Loads cached coordinates from appKvStore as initial camera position',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final db = AppDatabase.forTesting(NativeDatabase.memory());

        // Preenche coordenadas prévias em cache (São Paulo, SP)
        const cachedLat = -23.5505;
        const cachedLng = -46.6333;
        await db
            .into(db.appKvStore)
            .insert(
              AppKvStoreCompanion.insert(
                key: 'last_known_user_lat',
                value: cachedLat.toString(),
                updatedAt: drift.Value(DateTime.now().toUtc()),
              ),
            );
        await db
            .into(db.appKvStore)
            .insert(
              AppKvStoreCompanion.insert(
                key: 'last_known_user_lng',
                value: cachedLng.toString(),
                updatedAt: drift.Value(DateTime.now().toUtc()),
              ),
            );

        // GPS em tempo real indisponível
        GeolocationHelper.locationOverride = () async =>
            const GeolocationResult(
              status: GeolocationStatus.serviceDisabled,
              coordinates: null,
            );

        final adapter = _TestMapEngineAdapter();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              home: ContactsMapScreen(mapEngineAdapter: adapter),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(adapter.cameraMoves, isNotEmpty);
        final hasCachedMove = adapter.cameraMoves.any(
          (m) =>
              (m.latitude - cachedLat).abs() < 0.001 &&
              (m.longitude - cachedLng).abs() < 0.001,
        );
        expect(hasCachedMove, isTrue);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await db.close();
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'TC-GPS-03: Asynchronously fetches current GPS location, moves camera, and persists to appKvStore',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final db = AppDatabase.forTesting(NativeDatabase.memory());

        // Mock de GPS ao vivo (Rio de Janeiro, RJ)
        const liveLat = -22.9068;
        const liveLng = -43.1729;
        GeolocationHelper.locationOverride = () async =>
            const GeolocationResult(
              status: GeolocationStatus.success,
              coordinates: (latitude: liveLat, longitude: liveLng),
            );

        final adapter = _TestMapEngineAdapter();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              home: ContactsMapScreen(mapEngineAdapter: adapter),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verifica que a câmera foi movida para as coordenadas de GPS ao vivo
        expect(adapter.cameraMoves, isNotEmpty);
        final hasLiveMove = adapter.cameraMoves.any(
          (m) =>
              (m.latitude - liveLat).abs() < 0.001 &&
              (m.longitude - liveLng).abs() < 0.001,
        );
        expect(hasLiveMove, isTrue);

        // Verifica que as coordenadas foram persistidas no appKvStore
        final latRow = await (db.select(
          db.appKvStore,
        )..where((t) => t.key.equals('last_known_user_lat'))).getSingleOrNull();
        final lngRow = await (db.select(
          db.appKvStore,
        )..where((t) => t.key.equals('last_known_user_lng'))).getSingleOrNull();

        expect(latRow, isNotNull);
        expect(double.parse(latRow!.value), closeTo(liveLat, 0.0001));
        expect(lngRow, isNotNull);
        expect(double.parse(lngRow!.value), closeTo(liveLng, 0.0001));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await db.close();
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'TC-GPS-04: When highlightPersonId is provided, GPS centering does NOT overwrite highlighted contact',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final db = AppDatabase.forTesting(NativeDatabase.memory());

        // Insere um contato com coordenadas específicas (Brasília, DF)
        const contactLat = -15.7801;
        const contactLng = -47.9292;
        final now = DateTime.now();
        await db
            .into(db.people)
            .insert(
              PeopleCompanion.insert(
                id: 'contact_brasilia',
                name: 'Irmão de Brasília',
                firstContactAt: now,
                createdAt: now,
                updatedAt: now,
                status: const drift.Value('revisita'),
                latitude: const drift.Value(contactLat),
                longitude: const drift.Value(contactLng),
              ),
            );

        // Preenche cache diferente (São Paulo)
        await db
            .into(db.appKvStore)
            .insert(
              AppKvStoreCompanion.insert(
                key: 'last_known_user_lat',
                value: '-23.5505',
                updatedAt: drift.Value(DateTime.now().toUtc()),
              ),
            );
        await db
            .into(db.appKvStore)
            .insert(
              AppKvStoreCompanion.insert(
                key: 'last_known_user_lng',
                value: '-46.6333',
                updatedAt: drift.Value(DateTime.now().toUtc()),
              ),
            );

        // Mock de GPS diferente (Rio)
        GeolocationHelper.locationOverride = () async =>
            const GeolocationResult(
              status: GeolocationStatus.success,
              coordinates: (latitude: -22.9068, longitude: -43.1729),
            );

        final adapter = _TestMapEngineAdapter();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              home: ContactsMapScreen(
                highlightPersonId: 'contact_brasilia',
                mapEngineAdapter: adapter,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verifica que NENHUM movimento de câmera foi feito para o GPS (-22.9068) ou Cache (-23.5505)
        final movedToGps = adapter.cameraMoves.any(
          (m) => (m.latitude - (-22.9068)).abs() < 0.001,
        );
        final movedToCache = adapter.cameraMoves.any(
          (m) => (m.latitude - (-23.5505)).abs() < 0.001,
        );
        expect(movedToGps, isFalse);
        expect(movedToCache, isFalse);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await db.close();
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'TC-GPS-05: Pressing GPS locate FAB persists obtained coordinates to appKvStore',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final db = AppDatabase.forTesting(NativeDatabase.memory());

        const locateLat = -19.9167;
        const locateLng = -43.9345;
        GeolocationHelper.locationOverride = () async =>
            const GeolocationResult(
              status: GeolocationStatus.success,
              coordinates: (latitude: locateLat, longitude: locateLng),
            );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: const MaterialApp(home: ContactsMapScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final locateFab = find.byTooltip('Minha Localização GPS');
        expect(locateFab, findsOneWidget);
        await tester.tap(locateFab);
        await tester.pumpAndSettle();

        final latRow = await (db.select(
          db.appKvStore,
        )..where((t) => t.key.equals('last_known_user_lat'))).getSingleOrNull();
        final lngRow = await (db.select(
          db.appKvStore,
        )..where((t) => t.key.equals('last_known_user_lng'))).getSingleOrNull();

        expect(latRow, isNotNull);
        expect(double.parse(latRow!.value), closeTo(locateLat, 0.001));
        expect(lngRow, isNotNull);
        expect(double.parse(lngRow!.value), closeTo(locateLng, 0.001));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await db.close();
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });
}
