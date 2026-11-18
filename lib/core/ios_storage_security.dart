import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart';

import 'app_logger.dart';

/// Ponte nativa iOS para aplicar `NSFileProtectionComplete` e
/// `URLResourceValues.isExcludedFromBackup = true` em arquivos sensíveis
/// (banco SQLite, WAL/SHM, anexos e backups locais do dispositivo).
class IosStorageSecurity {
  IosStorageSecurity._();

  static const MethodChannel _channel = MethodChannel(
    'com.ministeriopessoal.ministerioPessoal/storage_security',
  );

  static bool get _isIos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Solicita ao `AppDelegate.swift` a proteção do banco SQLite, WAL/SHM,
  /// diretórios de mídia e backups locais contra cópia no iCloud/iTunes.
  static Future<int> protectSensitiveStorage() async {
    if (!_isIos) return 0;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'protectStorage',
      );
      return (result?['protectedCount'] as num?)?.toInt() ?? 0;
    } on MissingPluginException {
      return 0;
    } catch (e, st) {
      AppLogger.warning(
        'Falha ao aplicar proteção nativa de armazenamento iOS',
        e,
        st,
      );
      return 0;
    }
  }

  /// Marca um arquivo ou diretório específico como `isExcludedFromBackup = true`
  /// e `NSFileProtectionComplete` no iOS.
  static Future<bool> excludePathFromBackup(String path) async {
    if (!_isIos || path.trim().isEmpty) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('excludePathFromBackup', {
        'path': path,
      });
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } catch (e, st) {
      AppLogger.warning(
        'Falha ao excluir caminho do backup iCloud ($path)',
        e,
        st,
      );
      return false;
    }
  }
}
