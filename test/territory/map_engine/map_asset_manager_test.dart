import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/territory/map_engine/map_asset_manager.dart';

class _FakeAssetBundle extends CachingAssetBundle {
  final Map<String, ByteData> assets = {};

  void addStringAsset(String key, String content) {
    final list = Uint8List.fromList(content.codeUnits);
    assets[key] = ByteData.sublistView(list);
  }

  void addBinaryAsset(String key, Uint8List bytes) {
    assets[key] = ByteData.sublistView(bytes);
  }

  @override
  Future<ByteData> load(String key) async {
    final data = assets[key];
    if (data == null) {
      throw FlutterError('Asset not found: $key');
    }
    return data;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late _FakeAssetBundle fakeBundle;
  late MapAssetManager manager;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('map_assets_test_');
    fakeBundle = _FakeAssetBundle();
    manager = MapAssetManager(bundle: fakeBundle, targetDir: tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('MapAssetManager Tests', () {
    test('copies bundled assets to disk directory correctly', () async {
      fakeBundle.addStringAsset(
        'assets/map/style_offline_light.json',
        '{"version": 8, "name": "light"}',
      );
      fakeBundle.addStringAsset(
        'assets/map/style_offline_dark.json',
        '{"version": 8, "name": "dark"}',
      );
      fakeBundle.addStringAsset(
        'assets/map/sprites/sprite.json',
        '{"marker": {}}',
      );
      fakeBundle.addBinaryAsset(
        'assets/map/sprites/sprite.png',
        Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]),
      );
      fakeBundle.addStringAsset(
        'assets/map/sprites/sprite@2x.json',
        '{"marker": {}}',
      );
      fakeBundle.addBinaryAsset(
        'assets/map/sprites/sprite@2x.png',
        Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]),
      );
      fakeBundle.addBinaryAsset(
        'assets/map/fonts/Noto Sans Regular/0-255.pbf',
        Uint8List.fromList([1, 2, 3, 4]),
      );

      await manager.copyAssetsToDisk();

      final assetsDir = await manager.getAssetsDirectory();
      expect(assetsDir.existsSync(), isTrue);

      final stylePath = await manager.getStyleFilePath('style_offline_light');
      expect(File(stylePath).existsSync(), isTrue);
      expect(File(stylePath).readAsStringSync(), contains('"light"'));

      final fontFile = File(
        '${assetsDir.path}/fonts/Noto Sans Regular/0-255.pbf',
      );
      expect(fontFile.existsSync(), isTrue);
    });

    test(
      'replaces {assets_dir} and port placeholders in prepared style JSON',
      () async {
        const template = '''
{
  "version": 8,
  "sprite": "{assets_dir}/sprites/sprite",
  "glyphs": "{assets_dir}/fonts/{fontstack}/{range}.pbf",
  "sources": {
    "openmaptiles": {
      "type": "vector",
      "tiles": ["http://127.0.0.1:8080/tiles/mbtiles/{z}/{x}/{y}.pbf"]
    }
  }
}
''';
        fakeBundle.addStringAsset(
          'assets/map/style_offline_light.json',
          template,
        );

        await manager.copyAssetsToDisk();

        final prepared = await manager.getPreparedStyleJson(
          'style_offline_light',
          tileServerPort: 54321,
        );

        expect(prepared, contains('http://127.0.0.1:54321/tiles/mbtiles'));
        expect(prepared, isNot(contains('{assets_dir}')));
        expect(prepared, contains('/map_assets/sprites/sprite'));
        expect(prepared, contains('/map_assets/fonts/'));
      },
    );
  });
}
