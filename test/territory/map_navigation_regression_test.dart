import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/territory/geolocation_helper.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_service.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_web.dart';
import 'package:ministerio_pessoal/territory/tile_cache/tile_cache_service.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/contacts_map_screen.dart';
import 'package:ministerio_pessoal/ui/screens/today_screen.dart';

class EmptyTiles implements TileCacheBackend {
  @override
  Future<Uint8List?> getTile(int z, int x, int y, [MapLayerStyle? style]) async => null;
  @override
  Future<void> saveTile(int z, int x, int y, Uint8List bytes, [MapLayerStyle? style]) async {}
  @override
  Future<bool> isTileCached(int z, int x, int y, [MapLayerStyle? style]) async => false;
  @override
  Future<int> getCachedTileCount([MapLayerStyle? style]) async => 0;
}

class ParentMap extends MBTilesWeb {
  final bytes = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==');
  @override
  Future<Uint8List?> getTile(int z, int x, int y) async =>
      z == 16 && x == 100 && y == 150 ? bytes : null;
}

void main() {
  testWidgets('zoom acima do pacote recorta o quadrante correto do tile offline', (tester) async {
    final original = MBTilesService.instance;
    final mock = MBTilesService.custom(backend: ParentMap());
    MBTilesService.setMockInstance(mock);
    TileCacheService.instance.backend = EmptyTiles();
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CachedTileWidget(
      z: 17, x: 201, y: 301, size: 256, isDark: false,
    ))));
    await tester.pumpAndSettle();
    final transform = tester.widget<Transform>(find.descendant(
      of: find.byType(CachedTileWidget), matching: find.byType(Transform)).first);
    expect(transform.transform.storage[12], -256);
    expect(transform.transform.storage[13], -256);
    expect(find.text('Sem mapa nesta área ou zoom'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    MBTilesService.setMockInstance(original);
    mock.dispose();
  });

  testWidgets('mapa abre em SAI apesar de contato em SP e acompanha vários gestos', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = MBTilesService.instance;
    final mock = MBTilesService.custom(backend: MBTilesWeb());
    MBTilesService.setMockInstance(mock);
    TileCacheService.instance.backend = EmptyTiles();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.now();
    await db.into(db.people).insert(PeopleCompanion.insert(
      id: 'sp', name: 'Amostra', firstContactAt: now, createdAt: now,
      updatedAt: now, latitude: const Value(-23.55), longitude: const Value(-46.63),
    ));
    await tester.pumpWidget(ProviderScope(overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: ContactsMapScreen())));
    await tester.pumpAndSettle();
    Iterable<CachedTileWidget> tiles() => tester.widgetList<CachedTileWidget>(find.byType(CachedTileWidget));
    final cityX = ((GeolocationHelper.defaultLng + 180) / 360 * (1 << 15)).floor();
    expect(tiles().any((t) => t.z == 15 && t.x == cityX), isTrue);
    final originalMin = tiles().map((t) => t.x).reduce((a, b) => a < b ? a : b);
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(InteractiveViewer).first, const Offset(-220, 0));
      await tester.pumpAndSettle();
    }
    final movedMin = tiles().map((t) => t.x).reduce((a, b) => a < b ? a : b);
    expect(movedMin, greaterThan(originalMin));
    await tester.tap(find.byTooltip('Ir para Santo Antônio do Içá (mapa offline: camada Padrão, zoom 8 a 16)'));
    await tester.pumpAndSettle();
    expect(tiles().any((t) => t.z == 15 && t.x == cityX), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    MBTilesService.setMockInstance(original);
    mock.dispose();
  });

  testWidgets('título Hoje é legível em tela estreita', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: TodayScreen())));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('Hoje')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
