import 'dart:typed_data';

import 'web_downloader.dart';

/// Implementação Web/PWA utilizando download direto via Blob URL.
class BinaryFileSaver {
  static Future<String?> saveBytes({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
    String? dialogTitle,
  }) async {
    FileDownloader.downloadBytes(fileName, bytes, mimeType: mimeType);
    return fileName;
  }
}
