import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/core/biometric_auth_service.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/inbox/jw_email_service.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_crypto.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_key_store.dart';
import 'package:ministerio_pessoal/territory/geolocation_helper.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_service.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_web.dart';
import 'package:ministerio_pessoal/territory/tile_cache/tile_cache_service.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/contacts_map_screen.dart';
import 'package:ministerio_pessoal/ui/screens/settings_screen.dart';
import 'package:ministerio_pessoal/ui/widgets/e2ee_setup_dialog.dart';

class _EmptyTiles implements TileCacheBackend {
  final Set<String> requestedKeys = {};

  @override
  Future<Uint8List?> getTile(
    int z,
    int x,
    int y, [
    MapLayerStyle? style,
  ]) async {
    requestedKeys.add('$z/$x/$y');
    return null;
  }

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    RecoveryKeyStore.resetForTesting();
  });

  group('Map Rotation & Heading Adjustment Tests', () {
    testWidgets(
      'Mapa inicializa com rotação para o norte (0°) e permite girar e resetar suavemente',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final mock = MBTilesService.custom(backend: MBTilesWeb());
        MBTilesService.setMockInstance(mock);
        TileCacheService.instance.backend = _EmptyTiles();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: const MaterialApp(home: ContactsMapScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Verifica botão da bússola com tooltip inicial de 0°
        final compassFinder = find.byTooltip(
          'Rotação do mapa (0°). Toque para voltar suavemente ao norte ou arraste para girar.',
        );
        expect(compassFinder, findsOneWidget);

        // Botões de ajuste rápido de rotação
        final rotateRightFinder = find.byTooltip('Girar 45° à direita');
        final rotateLeftFinder = find.byTooltip('Girar 45° à esquerda');
        expect(rotateRightFinder, findsOneWidget);
        expect(rotateLeftFinder, findsOneWidget);

        // Gira 45° à direita
        await tester.tap(rotateRightFinder);
        await tester.pumpAndSettle();

        // Tooltip agora deve indicar 45°
        final compass45Finder = find.byTooltip(
          'Rotação do mapa (45°). Toque para voltar suavemente ao norte ou arraste para girar.',
        );
        expect(compass45Finder, findsOneWidget);

        // Confirma que a seta gira para a direção da rotação (+45° = pi/4)
        final transformFinder = find.descendant(
          of: compass45Finder,
          matching: find.byType(Transform),
        );
        expect(transformFinder, findsOneWidget);
        final transformWidget = tester.widget<Transform>(transformFinder);
        expect(transformWidget.transform.storage[0], closeTo(0.707, 0.02));
        expect(transformWidget.transform.storage[1], closeTo(0.707, 0.02));

        // Toca na bússola para voltar suavemente ao norte (0°)
        await tester.tap(compass45Finder);
        // Avança a animação de retorno suave
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        // Deve ter retornado a 0°
        expect(
          find.byTooltip(
            'Rotação do mapa (0°). Toque para voltar suavemente ao norte ou arraste para girar.',
          ),
          findsOneWidget,
        );
        final transform0Finder = find.descendant(
          of: compassFinder,
          matching: find.byType(Transform),
        );
        final transform0Widget = tester.widget<Transform>(transform0Finder);
        expect(transform0Widget.transform.storage[0], closeTo(1.0, 0.01));
        expect(transform0Widget.transform.storage[1], closeTo(0.0, 0.01));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Redimensionamento de viewport expande altura do mapa dinamicamente e preserva o centro',
      (tester) async {
        tester.view.physicalSize = const Size(800, 460);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final original = MBTilesService.instance;
        final mock = MBTilesService.custom(backend: MBTilesWeb());
        MBTilesService.setMockInstance(mock);
        addTearDown(() {
          MBTilesService.setMockInstance(original);
          mock.dispose();
        });
        final tileBackend = _EmptyTiles();
        TileCacheService.instance.backend = tileBackend;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: const MaterialApp(home: ContactsMapScreen()),
          ),
        );
        await tester.pumpAndSettle();

        Iterable<CachedTileWidget> tiles() =>
            tester.widgetList<CachedTileWidget>(find.byType(CachedTileWidget));

        final cityX =
            ((GeolocationHelper.defaultLng + 180.0) / 360.0 * (1 << 15))
                .floor();
        final latRad = GeolocationHelper.defaultLat * math.pi / 180.0;
        final cityY =
            ((1.0 -
                        math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) /
                            math.pi) /
                    2.0 *
                    (1 << 15))
                .floor();

        // Garante que o tile central já carrega na inicialização
        expect(
          tiles().any((t) => t.z == 15 && t.x == cityX && t.y == cityY),
          isTrue,
        );

        final mapViewportFinder = find
            .ancestor(
              of: find.byType(InteractiveViewer).first,
              matching: find.byType(ClipRect),
            )
            .first;
        final initialViewportRect = tester.getRect(mapViewportFinder);
        final initialMinY = tiles().map((t) => t.y).reduce(math.min);
        final initialMaxY = tiles().map((t) => t.y).reduce(math.max);
        final initialRowSpan = initialMaxY - initialMinY + 1;

        // Expande drasticamente a altura da janela (não pode ficar limitado à altura do primeiro carregamento)
        tester.view.physicalSize = const Size(800, 1450);
        await tester.pumpAndSettle();

        final expandedViewportRect = tester.getRect(mapViewportFinder);
        expect(
          expandedViewportRect.height,
          greaterThan(initialViewportRect.height + 900),
        );

        final expandedMinY = tiles().map((t) => t.y).reduce(math.min);
        final expandedMaxY = tiles().map((t) => t.y).reduce(math.max);
        final expandedRowSpan = expandedMaxY - expandedMinY + 1;
        expect(expandedRowSpan, greaterThan(initialRowSpan));

        // Confirma cobertura física de 100% da nova altura por tiles montados
        double tilesTop = double.infinity;
        double tilesBottom = double.negativeInfinity;
        for (final t in tiles()) {
          final rect = tester.getRect(
            find.byKey(ValueKey('tile_pos_${t.z}_${t.x}_${t.y}')),
          );
          if (rect.top < tilesTop) tilesTop = rect.top;
          if (rect.bottom > tilesBottom) tilesBottom = rect.bottom;
        }
        expect(tilesTop, lessThanOrEqualTo(expandedViewportRect.top + 1.0));
        expect(
          tilesBottom,
          greaterThanOrEqualTo(expandedViewportRect.bottom - 1.0),
        );

        // Confirma que o centro geográfico foi preservado após a mudança de altura e gridHalfSize
        final centerTileRect = tester.getRect(
          find.byKey(ValueKey('tile_pos_15_${cityX}_$cityY')),
        );
        expect(
          (centerTileRect.center.dx - expandedViewportRect.center.dx).abs(),
          lessThan(256.0),
        );
        expect(
          (centerTileRect.center.dy - expandedViewportRect.center.dy).abs(),
          lessThan(256.0),
        );

        // Alterna para Tela Cheia e verifica nova expansão de altura sem erro
        await tester.tap(find.byTooltip('Modo Tela Cheia'));
        await tester.pumpAndSettle();
        final fullscreenViewportRect = tester.getRect(mapViewportFinder);
        expect(
          fullscreenViewportRect.height,
          greaterThan(expandedViewportRect.height),
        );
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Rotação em tela paisagem preenche 100% da altura e largura sem corte nas bordas',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final original = MBTilesService.instance;
        final mock = MBTilesService.custom(backend: MBTilesWeb());
        MBTilesService.setMockInstance(mock);
        addTearDown(() {
          MBTilesService.setMockInstance(original);
          mock.dispose();
        });
        TileCacheService.instance.backend = _EmptyTiles();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: const MaterialApp(home: ContactsMapScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final mapViewportFinder = find
            .ancestor(
              of: find.byType(InteractiveViewer).first,
              matching: find.byType(ClipRect),
            )
            .first;
        final viewportRect = tester.getRect(mapViewportFinder);
        final expectedDiagonal = math.sqrt(
          viewportRect.width * viewportRect.width +
              viewportRect.height * viewportRect.height,
        );

        // O InteractiveViewer deve ter extensão >= diagonal para nunca expor bordas escuras ao girar
        final viewerSize = tester.getSize(find.byType(InteractiveViewer).first);
        expect(viewerSize.width, greaterThanOrEqualTo(expectedDiagonal - 1.0));
        expect(viewerSize.height, greaterThanOrEqualTo(expectedDiagonal - 1.0));

        void expectFullViewportCoverage() {
          final renderedTiles = tester
              .widgetList<CachedTileWidget>(find.byType(CachedTileWidget))
              .toList();
          expect(renderedTiles, isNotEmpty);

          double minLeft = double.infinity;
          double maxRight = double.negativeInfinity;
          double minTop = double.infinity;
          double maxBottom = double.negativeInfinity;

          for (final t in renderedTiles) {
            final rect = tester.getRect(
              find.byKey(ValueKey('tile_pos_${t.z}_${t.x}_${t.y}')),
            );
            if (rect.left < minLeft) minLeft = rect.left;
            if (rect.right > maxRight) maxRight = rect.right;
            if (rect.top < minTop) minTop = rect.top;
            if (rect.bottom > maxBottom) maxBottom = rect.bottom;
          }

          expect(minLeft, lessThanOrEqualTo(viewportRect.left + 1.0));
          expect(maxRight, greaterThanOrEqualTo(viewportRect.right - 1.0));
          expect(minTop, lessThanOrEqualTo(viewportRect.top + 1.0));
          expect(maxBottom, greaterThanOrEqualTo(viewportRect.bottom - 1.0));
        }

        // Gira 45° em paisagem e valida cobertura total
        await tester.tap(find.byTooltip('Girar 45° à direita'));
        await tester.pumpAndSettle();
        expectFullViewportCoverage();

        // Gira mais 45° (90° total em paisagem) e valida cobertura total sem corte de altura
        await tester.tap(find.byTooltip('Girar 45° à direita'));
        await tester.pumpAndSettle();
        expectFullViewportCoverage();

        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Carregamento dinâmico de tiles ocorre continuamente durante o arraste antes de soltar',
      (tester) async {
        tester.view.physicalSize = const Size(600, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final original = MBTilesService.instance;
        final mock = MBTilesService.custom(backend: MBTilesWeb());
        MBTilesService.setMockInstance(mock);
        addTearDown(() {
          MBTilesService.setMockInstance(original);
          mock.dispose();
        });
        final tileBackend = _EmptyTiles();
        TileCacheService.instance.backend = tileBackend;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: const MaterialApp(home: ContactsMapScreen()),
          ),
        );
        await tester.pumpAndSettle();

        Iterable<CachedTileWidget> tiles() =>
            tester.widgetList<CachedTileWidget>(find.byType(CachedTileWidget));

        final initialMinX = tiles().map((t) => t.x).reduce(math.min);
        final initialMaxX = tiles().map((t) => t.x).reduce(math.max);
        final initialMaxY = tiles().map((t) => t.y).reduce(math.max);

        final mapViewportFinder = find
            .ancestor(
              of: find.byType(InteractiveViewer).first,
              matching: find.byType(ClipRect),
            )
            .first;
        final startPoint = tester.getCenter(mapViewportFinder);

        // Inicia arraste contínuo SEM soltar o ponteiro (testa carregamento mid-drag)
        final gesture = await tester.startGesture(startPoint);
        for (var i = 0; i < 4; i++) {
          await gesture.moveBy(const Offset(-160, 0));
          await tester.pump(const Duration(milliseconds: 40));
        }

        // Mesmo antes de gesture.up(), novos tiles à direita já devem estar montados e solicitados
        final midDragMinX = tiles().map((t) => t.x).reduce(math.min);
        final midDragMaxX = tiles().map((t) => t.x).reduce(math.max);
        expect(midDragMaxX, greaterThan(initialMaxX));
        expect(midDragMinX, greaterThan(initialMinX));
        expect(
          tileBackend.requestedKeys.any(
            (k) => k.startsWith('15/$midDragMaxX/'),
          ),
          isTrue,
        );

        // Continua arrastando verticalmente SEM soltar o ponteiro
        for (var i = 0; i < 3; i++) {
          await gesture.moveBy(const Offset(0, -160));
          await tester.pump(const Duration(milliseconds: 40));
        }

        final midDragMaxY = tiles().map((t) => t.y).reduce(math.max);
        expect(midDragMaxY, greaterThan(initialMaxY));

        await gesture.up();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Pinça de zoom-out e arraste contínuo longo carregam tiles dinamicamente sem corte',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final original = MBTilesService.instance;
        final mock = MBTilesService.custom(backend: MBTilesWeb());
        MBTilesService.setMockInstance(mock);
        addTearDown(() {
          MBTilesService.setMockInstance(original);
          mock.dispose();
        });
        final tileBackend = _EmptyTiles();
        TileCacheService.instance.backend = tileBackend;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: const MaterialApp(home: ContactsMapScreen()),
          ),
        );
        await tester.pumpAndSettle();

        Iterable<CachedTileWidget> tiles() =>
            tester.widgetList<CachedTileWidget>(find.byType(CachedTileWidget));

        final mapViewportFinder = find
            .ancestor(
              of: find.byType(InteractiveViewer).first,
              matching: find.byType(ClipRect),
            )
            .first;
        final viewportRect = tester.getRect(mapViewportFinder);
        final center = viewportRect.center;

        final initialSpanX =
            tiles().map((t) => t.x).reduce(math.max) -
            tiles().map((t) => t.x).reduce(math.min) +
            1;

        // Pinça de afastamento (zoom out) com dois dedos sem soltar:
        // novos tiles externos devem montar dinamicamente durante o gesto.
        final p1 = await tester.startGesture(
          center + const Offset(-220, 0),
          pointer: 1,
        );
        final p2 = await tester.startGesture(
          center + const Offset(220, 0),
          pointer: 2,
        );
        await tester.pump();
        for (var i = 0; i < 4; i++) {
          await p1.moveBy(const Offset(22, 0));
          await p2.moveBy(const Offset(-22, 0));
          await tester.pump(const Duration(milliseconds: 30));
        }

        final midPinchSpanX =
            tiles().map((t) => t.x).reduce(math.max) -
            tiles().map((t) => t.x).reduce(math.min) +
            1;
        expect(midPinchSpanX, greaterThan(initialSpanX));

        // Cobertura de 100% da viewport durante o pinch-out
        double minLeft = double.infinity;
        double maxRight = double.negativeInfinity;
        double minTop = double.infinity;
        double maxBottom = double.negativeInfinity;
        for (final t in tiles()) {
          final rect = tester.getRect(
            find.byKey(ValueKey('tile_pos_${t.z}_${t.x}_${t.y}')),
          );
          if (rect.left < minLeft) minLeft = rect.left;
          if (rect.right > maxRight) maxRight = rect.right;
          if (rect.top < minTop) minTop = rect.top;
          if (rect.bottom > maxBottom) maxBottom = rect.bottom;
        }
        expect(minLeft, lessThanOrEqualTo(viewportRect.left + 1.0));
        expect(maxRight, greaterThanOrEqualTo(viewportRect.right - 1.0));
        expect(minTop, lessThanOrEqualTo(viewportRect.top + 1.0));
        expect(maxBottom, greaterThanOrEqualTo(viewportRect.bottom - 1.0));

        await p1.up();
        await p2.up();
        await tester.pumpAndSettle();

        // Soltar a pinça com escala <= 0.75 reprojeta para Z: 14
        expect(find.text('Z: 14'), findsOneWidget);

        // Arraste contínuo longo (>1.100px sem soltar) deve continuar carregando tiles sem bater em parede
        final beforeDragMaxX = tiles().map((t) => t.x).reduce(math.max);
        final drag = await tester.startGesture(center);
        for (var i = 0; i < 8; i++) {
          await drag.moveBy(const Offset(-150, 0));
          await tester.pump(const Duration(milliseconds: 30));
        }
        final afterDragMaxX = tiles().map((t) => t.x).reduce(math.max);
        expect(afterDragMaxX - beforeDragMaxX, greaterThanOrEqualTo(4));
        await drag.up();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Arraste contínuo com mapa rotacionado a 135° em paisagem carrega novos tiles sem corte',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final original = MBTilesService.instance;
        final mock = MBTilesService.custom(backend: MBTilesWeb());
        MBTilesService.setMockInstance(mock);
        addTearDown(() {
          MBTilesService.setMockInstance(original);
          mock.dispose();
        });
        TileCacheService.instance.backend = _EmptyTiles();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: const MaterialApp(home: ContactsMapScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Rotaciona 135° (3 x 45°)
        final rotateBtn = find.byTooltip('Girar 45° à direita');
        for (var i = 0; i < 3; i++) {
          await tester.tap(rotateBtn);
          await tester.pumpAndSettle();
        }

        Iterable<CachedTileWidget> tiles() =>
            tester.widgetList<CachedTileWidget>(find.byType(CachedTileWidget));
        final beforeKeys = tiles().map((t) => '${t.x}_${t.y}').toSet();

        final mapViewportFinder = find
            .ancestor(
              of: find.byType(InteractiveViewer).first,
              matching: find.byType(ClipRect),
            )
            .first;
        final viewportRect = tester.getRect(mapViewportFinder);

        final gesture = await tester.startGesture(viewportRect.center);
        for (var i = 0; i < 4; i++) {
          await gesture.moveBy(const Offset(-160, -120));
          await tester.pump(const Duration(milliseconds: 30));
        }

        final midKeys = tiles().map((t) => '${t.x}_${t.y}').toSet();
        expect(midKeys.difference(beforeKeys), isNotEmpty);

        double minLeft = double.infinity;
        double maxRight = double.negativeInfinity;
        double minTop = double.infinity;
        double maxBottom = double.negativeInfinity;
        for (final t in tiles()) {
          final rect = tester.getRect(
            find.byKey(ValueKey('tile_pos_${t.z}_${t.x}_${t.y}')),
          );
          if (rect.left < minLeft) minLeft = rect.left;
          if (rect.right > maxRight) maxRight = rect.right;
          if (rect.top < minTop) minTop = rect.top;
          if (rect.bottom > maxBottom) maxBottom = rect.bottom;
        }
        expect(minLeft, lessThanOrEqualTo(viewportRect.left + 1.0));
        expect(maxRight, greaterThanOrEqualTo(viewportRect.right - 1.0));
        expect(minTop, lessThanOrEqualTo(viewportRect.top + 1.0));
        expect(maxBottom, greaterThanOrEqualTo(viewportRect.bottom - 1.0));

        await gesture.up();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Redimensionamentos alternados, troca de modo e zoom imediato preservam centro e cobertura',
      (tester) async {
        tester.view.physicalSize = const Size(800, 460);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final original = MBTilesService.instance;
        final mock = MBTilesService.custom(backend: MBTilesWeb());
        MBTilesService.setMockInstance(mock);
        addTearDown(() {
          MBTilesService.setMockInstance(original);
          mock.dispose();
        });
        TileCacheService.instance.backend = _EmptyTiles();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: const MaterialApp(home: ContactsMapScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Alterna rapidamente entre tamanhos e troca para Lista e de volta para Mapa
        tester.view.physicalSize = const Size(800, 1450);
        await tester.pump();
        tester.view.physicalSize = const Size(1280, 640);
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Ver em Lista / Bairros'));
        await tester.pumpAndSettle();
        tester.view.physicalSize = const Size(800, 1450);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Ver Mapa Interativo'));
        await tester.pumpAndSettle();

        // Aplica zoom imediatamente após redimensionamento
        await tester.tap(find.byTooltip('Aproximar Zoom'));
        await tester.pumpAndSettle();
        expect(find.text('Z: 16'), findsOneWidget);

        final mapViewportFinder = find
            .ancestor(
              of: find.byType(InteractiveViewer).first,
              matching: find.byType(ClipRect),
            )
            .first;
        final viewportRect = tester.getRect(mapViewportFinder);

        final cityX16 =
            ((GeolocationHelper.defaultLng + 180.0) / 360.0 * (1 << 16))
                .floor();
        final latRad = GeolocationHelper.defaultLat * math.pi / 180.0;
        final cityY16 =
            ((1.0 -
                        math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) /
                            math.pi) /
                    2.0 *
                    (1 << 16))
                .floor();

        final centerTileFinder = find.byKey(
          ValueKey('tile_pos_16_${cityX16}_$cityY16'),
        );
        expect(centerTileFinder, findsOneWidget);
        final centerTileRect = tester.getRect(centerTileFinder);
        expect(
          (centerTileRect.center.dx - viewportRect.center.dx).abs(),
          lessThan(256.0),
        );
        expect(
          (centerTileRect.center.dy - viewportRect.center.dy).abs(),
          lessThan(256.0),
        );

        double tilesTop = double.infinity;
        double tilesBottom = double.negativeInfinity;
        for (final t in tester.widgetList<CachedTileWidget>(
          find.byType(CachedTileWidget),
        )) {
          final rect = tester.getRect(
            find.byKey(ValueKey('tile_pos_${t.z}_${t.x}_${t.y}')),
          );
          if (rect.top < tilesTop) tilesTop = rect.top;
          if (rect.bottom > tilesBottom) tilesBottom = rect.bottom;
        }
        expect(tilesTop, lessThanOrEqualTo(viewportRect.top + 1.0));
        expect(tilesBottom, greaterThanOrEqualTo(viewportRect.bottom - 1.0));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Fechar banner de contato destacado preserva a localização sem saltar para a origem padrão',
      (tester) async {
        tester.view.physicalSize = const Size(900, 760);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final original = MBTilesService.instance;
        final mock = MBTilesService.custom(backend: MBTilesWeb());
        MBTilesService.setMockInstance(mock);
        addTearDown(() {
          MBTilesService.setMockInstance(original);
          mock.dispose();
        });
        TileCacheService.instance.backend = _EmptyTiles();

        final now = DateTime.now();
        const spLat = -23.5505;
        const spLng = -46.6333;
        await db
            .into(db.people)
            .insert(
              PeopleCompanion.insert(
                id: 'sp_highlight',
                name: 'Marcos Paulista',
                status: const Value('estudo'),
                address: const Value('Av. Paulista, 1000'),
                latitude: const Value(spLat),
                longitude: const Value(spLng),
                firstContactAt: now,
                createdAt: now,
                updatedAt: now,
              ),
            );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: const MaterialApp(
              home: ContactsMapScreen(highlightPersonId: 'sp_highlight'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final spX = ((spLng + 180.0) / 360.0 * (1 << 15)).floor();
        final spRad = spLat * math.pi / 180.0;
        final spY =
            ((1.0 -
                        math.log(math.tan(spRad) + 1.0 / math.cos(spRad)) /
                            math.pi) /
                    2.0 *
                    (1 << 15))
                .floor();

        expect(find.byKey(ValueKey('tile_pos_15_${spX}_$spY')), findsOneWidget);
        expect(find.text('Destacado: Marcos'), findsOneWidget);

        await tester.tap(find.text('Destacado: Marcos'));
        await tester.pumpAndSettle();

        expect(find.text('Destacado: Marcos'), findsNothing);
        // Deve permanecer centrado nos tiles de São Paulo e não saltar para Santo Antônio do Içá
        expect(find.byKey(ValueKey('tile_pos_15_${spX}_$spY')), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  });

  group('E2EE 24-Word Key Always Visible in Settings Tests', () {
    testWidgets(
      'Card de configuração E2EE de 24 palavras está sempre visível mesmo sem usuário logado',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await db
            .into(db.appKvStore)
            .insert(
              AppKvStoreCompanion.insert(
                key: 'last_silent_backup_timestamp',
                value: DateTime.now().toIso8601String(),
              ),
            );
        final repo = AppRepository(db);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
            ],
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Rola o ListView para baixo até encontrar a seção de sincronização Supabase
        await tester.scrollUntilVisible(
          find.text('Conta e Sincronização (Supabase)'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(
          find.text('Conta e Sincronização (Supabase)'),
        );
        await tester.pumpAndSettle();

        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();

        // O card de chave E2EE DEVE estar visível mesmo quando currentUser == null
        expect(
          find.text('Chave E2EE de 24 Palavras Necessária'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(
            ElevatedButton,
            'Configurar / Restaurar Chave de 24 Palavras',
          ),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );

    testWidgets('E2eeSetupDialog.show abre sem exigir userId explícito', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db
          .into(db.appKvStore)
          .insert(
            AppKvStoreCompanion.insert(
              key: 'last_silent_backup_timestamp',
              value: DateTime.now().toIso8601String(),
            ),
          );
      final repo = AppRepository(db);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            repositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => E2eeSetupDialog.show(ctx),
                  child: const Text('Abrir Dialog'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abrir Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Criptografia Ponta a Ponta (E2EE)'), findsOneWidget);
      expect(find.text('Novo Cofre'), findsOneWidget);
      expect(find.text('Restaurar com Frase'), findsOneWidget);

      // Fecha o dialog antes de desmontar o widget
      Navigator.of(
        tester.element(find.text('Criptografia Ponta a Ponta (E2EE)')),
      ).pop();
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets(
      'Card E2EE configurado exibe status ativo e ações de chave mesmo sem login',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await db
            .into(db.appKvStore)
            .insert(
              AppKvStoreCompanion.insert(
                key: 'last_silent_backup_timestamp',
                value: DateTime.now().toIso8601String(),
              ),
            );
        final repo = AppRepository(db);

        final keyStore = RecoveryKeyStore();
        final testPhrase = RecoveryCrypto.createPhrase();
        await tester.runAsync(() async {
          await keyStore.install(
            owner: 'local_user',
            phrase: testPhrase,
            confirmation: testPhrase,
          );
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
            ],
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.scrollUntilVisible(
          find.text('Conta e Sincronização (Supabase)'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(
          find.text('Conta e Sincronização (Supabase)'),
        );
        await tester.pumpAndSettle();

        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();

        // O card deve indicar E2EE Ativa e permitir reconfigurar ou verificar status
        expect(
          find.text('Criptografia de Ponta a Ponta Ativa (E2EE)'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(
            ElevatedButton,
            'Configurar / Restaurar Chave (24 Palavras)',
          ),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(OutlinedButton, 'Verificar Status do Cofre'),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );

    testWidgets('E2eeViewPhraseDialog exibe as 24 palavras com botão de cópia', (
      tester,
    ) async {
      const phrase =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: E2eeViewPhraseDialog(phrase: phrase)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Frase de Recuperação E2EE'), findsOneWidget);
      expect(find.text('Copiar'), findsOneWidget);
      expect(find.text('abandon'), findsWidgets);

      await tester.scrollUntilVisible(
        find.text('art'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('art'), findsOneWidget);
    });
  });

  group('Inbox & Email Supabase Sync Queue Tests', () {
    test(
      'saveDraft enfileira item na sync_queue para replicação ao Supabase',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final service = JwEmailService(
          db: db,
          biometricAuth: BiometricAuthService(),
        );
        final draft = JwEmailMessage(
          id: 'draft-sync-test-1',
          subject: 'Assunto do Rascunho',
          bodyText: 'Corpo da mensagem de teste',
          from: 'missionario@jw.org',
          to: 'anciao@jw.org',
          date: DateTime.now(),
          isDraft: true,
        );

        await service.saveDraft(draft);

        final entries = await db.select(db.inboxEntries).get();
        expect(entries.length, 1);
        expect(entries.single.id, 'email_draft_draft-sync-test-1');

        final queue = await db.select(db.syncQueue).get();
        expect(queue.length, 1);
        expect(queue.single.entityType, 'inbox_entries');
        expect(queue.single.entityId, 'email_draft_draft-sync-test-1');
        expect(queue.single.operation, 'INSERT');

        final payload =
            jsonDecode(queue.single.payload) as Map<String, dynamic>;
        expect(payload['content'], contains('Assunto do Rascunho'));

        // Atualiza o rascunho existente - operação agora deve ser UPDATE
        final updatedDraft = draft.copyWith(subject: 'Assunto Atualizado');
        await service.saveDraft(updatedDraft);

        final queueAfterUpdate = await db.select(db.syncQueue).get();
        expect(queueAfterUpdate.length, 2);
        expect(queueAfterUpdate.last.entityType, 'inbox_entries');
        expect(queueAfterUpdate.last.entityId, 'email_draft_draft-sync-test-1');
        expect(queueAfterUpdate.last.operation, 'UPDATE');

        await db.close();
      },
    );
  });
}
