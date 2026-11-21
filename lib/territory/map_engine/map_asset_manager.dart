import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/app_logger.dart';

/// Gerenciador de ativos cartográficos offline (FA-MAP-01/02).
/// Responsável por transferir estilos JSON, fontes/glifos (.pbf) e sprites do
/// AssetBundle para o armazenamento local do dispositivo, viabilizando
/// leitura local segura e offline via URIs `file://` para MapLibre Native.
class MapAssetManager {
  static const String _mapAssetsSubdir = 'map_assets';

  final AssetBundle? _customBundle;
  final Directory? _customTargetDir;

  MapAssetManager({AssetBundle? bundle, Directory? targetDir})
    : _customBundle = bundle,
      _customTargetDir = targetDir;

  AssetBundle get _bundle => _customBundle ?? rootBundle;

  Future<Directory> getAssetsDirectory() async {
    final customTargetDir = _customTargetDir;
    if (customTargetDir != null) {
      final dir = Directory('${customTargetDir.path}/$_mapAssetsSubdir');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return dir;
    }
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory('${supportDir.path}/$_mapAssetsSubdir');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Lista de ativos essenciais para funcionamento do mapa offline.
  static const List<String> bundledAssets = [
    'assets/map/style_offline_light.json',
    'assets/map/style_offline_dark.json',
    'assets/map/sprites/sprite.json',
    'assets/map/sprites/sprite.png',
    'assets/map/sprites/sprite@2x.json',
    'assets/map/sprites/sprite@2x.png',
    'assets/map/fonts/Noto Sans Regular/0-255.pbf',
  ];

  /// Copia todos os ativos cartográficos do bundle para o disco do dispositivo
  /// caso ainda não existam ou forçando sobrescrita se `overwrite = true`.
  Future<void> copyAssetsToDisk({bool overwrite = false}) async {
    final targetDir = await getAssetsDirectory();

    for (final assetPath in bundledAssets) {
      try {
        final relativeSubpath = assetPath.replaceFirst('assets/map/', '');
        final destinationFile = File('${targetDir.path}/$relativeSubpath');

        if (!destinationFile.existsSync() || overwrite) {
          destinationFile.parent.createSync(recursive: true);
          final byteData = await _bundle.load(assetPath);
          final bytes = byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          );
          await destinationFile.writeAsBytes(bytes, flush: true);
          AppLogger.debug('Ativo cartográfico copiado: $relativeSubpath');
        } else {
          final byteData = await _bundle.load(assetPath);
          final bytes = byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          );
          final existingBytes = await destinationFile.readAsBytes();
          if (!_bytesEqual(existingBytes, bytes)) {
            await destinationFile.writeAsBytes(bytes, flush: true);
            AppLogger.debug('Ativo cartográfico atualizado: $relativeSubpath');
          }
        }
      } catch (e, st) {
        AppLogger.warning(
          'Falha ao copiar ativo cartográfico $assetPath para disco',
          e,
          st,
        );
      }
    }
  }

  bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Retorna o caminho do arquivo de estilo pronto para uso em disco (`file://...`).
  Future<String> getStyleFilePath(String styleName) async {
    final dir = await getAssetsDirectory();
    final filename = styleName.endsWith('.json')
        ? styleName
        : '$styleName.json';
    return '${dir.path}/$filename';
  }

  /// Retorna o conteúdo do Style JSON com os placeholders `{assets_dir}` e
  /// `{server_port}` substituídos pelas referências reais locais.
  Future<String> getPreparedStyleJson(
    String styleName, {
    int? tileServerPort,
  }) async {
    final dir = await getAssetsDirectory();
    final filename = styleName.endsWith('.json')
        ? styleName
        : '$styleName.json';
    final styleFile = File('${dir.path}/$filename');

    String rawJson;
    if (styleFile.existsSync()) {
      rawJson = await styleFile.readAsString();
    } else {
      // Fallback para carregar diretamente do asset bundle
      rawJson = await _bundle.loadString('assets/map/$filename');
    }

    final assetsUri = dir.uri.toString().replaceAll(RegExp(r'/$'), '');
    var prepared = rawJson.replaceAll('{assets_dir}', assetsUri);

    if (tileServerPort != null) {
      prepared = prepared.replaceAll(
        'http://127.0.0.1:8080',
        'http://127.0.0.1:$tileServerPort',
      );
    }

    return prepared;
  }
}
