import 'dart:typed_data';

/// Implementação stub de fallback para salvamento de arquivos binários.
class BinaryFileSaver {
  static Future<String?> saveBytes({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
    String? dialogTitle,
  }) {
    throw UnsupportedError(
      'BinaryFileSaver não suportado nesta plataforma ($fileName).',
    );
  }
}
