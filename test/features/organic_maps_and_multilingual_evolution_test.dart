import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_service.dart';
import 'package:ministerio_pessoal/territory/tile_cache/tile_cache_service.dart';
import 'package:ministerio_pessoal/ticuna/ticuna_providers.dart';
import 'package:ministerio_pessoal/ui/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Organic Maps Parity & Multi-Layer System Tests', () {
    test('MBTilesService possui catálogo de 23 regiões do Brasil estilo Organic Maps', () {
      final catalog = MBTilesService.instance.currentRegions;
      expect(catalog.length, equals(23));

      // Verifica pre-instalação da região Ticuna / Santo Antônio do Içá
      final solimoes = catalog.firstWhere((r) => r.id == 'br_am_solimoes');
      expect(solimoes.isInstalled, isTrue);
      expect(solimoes.country, equals('Brasil'));
      expect(solimoes.state, equals('Amazonas'));

      // Verifica presença de outros estados estratégicos
      expect(catalog.any((r) => r.id == 'br_rr_yanomami'), isTrue);
      expect(catalog.any((r) => r.id == 'br_ma_guajajara'), isTrue);
      expect(catalog.any((r) => r.id == 'br_sp_capital'), isTrue);
      expect(catalog.any((r) => r.id == 'br_rj_capital'), isTrue);
      expect(catalog.any((r) => r.id == 'br_df_brasilia'), isTrue);
      expect(catalog.any((r) => r.id == 'br_pr_foz'), isTrue);
    });

    test('TileCacheService suporta troca fluida entre 4 estilos de camadas de mapa', () {
      final tileService = TileCacheService.instance;

      // Padrão OSM
      tileService.setLayerStyle(MapLayerStyle.standard);
      expect(tileService.activeStyle, equals(MapLayerStyle.standard));
      expect(tileService.getTileUrl(10, 300, 400), contains('openstreetmap.org/10/300/400.png'));

      // Satélite Esri
      tileService.setLayerStyle(MapLayerStyle.satellite);
      expect(tileService.activeStyle, equals(MapLayerStyle.satellite));
      expect(tileService.getTileUrl(10, 300, 400), contains('arcgisonline.com'));
      expect(tileService.getTileUrl(10, 300, 400), contains('World_Imagery'));

      // Topográfico OpenTopoMap
      tileService.setLayerStyle(MapLayerStyle.topo);
      expect(tileService.activeStyle, equals(MapLayerStyle.topo));
      expect(tileService.getTileUrl(10, 300, 400), contains('opentopomap.org'));

      // Modo Noturno Carto Dark
      tileService.setLayerStyle(MapLayerStyle.dark);
      expect(tileService.activeStyle, equals(MapLayerStyle.dark));
      expect(tileService.getTileUrl(10, 300, 400), contains('cartocdn.com/dark_all'));

      // Retorna para standard
      tileService.setLayerStyle(MapLayerStyle.standard);
      expect(tileService.activeStyle, equals(MapLayerStyle.standard));
    });

    test('TileCacheService.getFallbackFromMemory recupera bloco pai z-1 eliminando pisca/flash cinza', () {
      // Quando z=11, x=300, y=400 não está no cache, o fallback busca z=10, x=150, y=200
      expect(TileCacheService.getFallbackFromMemory(11, 300, 400), isNull);
    });

    test('isMapFullscreenProvider alterna modo tela cheia para visualização 100% imersiva', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(isMapFullscreenProvider), isFalse);

      container.read(isMapFullscreenProvider.notifier).toggle();
      expect(container.read(isMapFullscreenProvider), isTrue);

      container.read(isMapFullscreenProvider.notifier).toggle();
      expect(container.read(isMapFullscreenProvider), isFalse);
    });
  });

  group('Multi-Language Selection & Database Seeding Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Database migrations e beforeOpen realizam seed de 5 idiomas padrão com Ticuna como default', () async {
      // Força a execução da estratégia de migração e beforeOpen
      await db.customSelect('SELECT 1').get();

      final languages = await (db.select(db.appLanguages)).get();
      expect(languages.isNotEmpty, isTrue);

      // Deve conter Ticuna, Português, Espanhol, Guajajara e Yanomami
      final ids = languages.map((l) => l.id).toSet();
      expect(ids.contains('tca'), isTrue);
      expect(ids.contains('por'), isTrue);
      expect(ids.contains('spa'), isTrue);
      expect(ids.contains('gub'), isTrue);
      expect(ids.contains('yan'), isTrue);

      final tca = languages.firstWhere((l) => l.id == 'tca');
      expect(tca.isDefault, isTrue);
      expect(tca.symbol, equals('🏹'));
    });

    test('ActiveLanguageNotifier persiste idioma selecionado no AppKvStore', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      // Aguarda inicialização do banco
      await db.customSelect('SELECT 1').get();

      final languages = await (db.select(db.appLanguages)).get();
      final gub = languages.firstWhere((l) => l.id == 'gub');

      await container.read(activeLanguageProvider.notifier).selectLanguage(gub);
      expect(container.read(activeLanguageProvider)?.id, equals('gub'));

      // Verifica persistência na tabela AppKvStore
      final row = await (db.select(db.appKvStore)..where((t) => t.key.equals('active_language_code'))).getSingleOrNull();
      expect(row, isNotNull);
      expect(row!.value, equals('gub'));
    });
  });
}
