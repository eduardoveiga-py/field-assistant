import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Implementação nativa (Windows, macOS, Linux, iOS, Android) usando o seletor nativo.
class BinaryFileSaver {
  static Future<String?> saveBytes({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
    String? dialogTitle,
  }) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      dialogTitle: dialogTitle ?? 'Salvar arquivo',
    );
    if (uri == null) return null;
    try {
      return uri.scheme == 'file' ? uri.toFilePath() : uri.toString();
    } catch (_) {
      return fileName;
    }
  }
}
