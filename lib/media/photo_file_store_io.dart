import 'dart:io';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:path_provider/path_provider.dart';

import '../core/app_logger.dart';

Future<String?> savePhotoBytesToDisk({
  required String photoId,
  required List<int> bytes,
  String extension = 'jpg',
  Future<String> Function()? documentsDirectoryProvider,
}) async {
  try {
    final basePath = documentsDirectoryProvider != null
        ? await documentsDirectoryProvider()
        : (await getApplicationDocumentsDirectory()).path;
    final dir = Directory('$basePath/person_photos');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final cleanExt = extension.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final ext = cleanExt.isEmpty ? 'jpg' : cleanExt;
    final file = File('${dir.path}/$photoId.$ext');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  } on MissingPluginException {
    return null;
  } on FlutterError {
    return null;
  }
}

Future<void> deletePhotoFileFromDisk(String? filePath) async {
  if (filePath == null || filePath.trim().isEmpty) return;
  try {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (e, st) {
    AppLogger.warning('Falha ao remover arquivo de foto do disco ($filePath)', e, st);
  }
}
