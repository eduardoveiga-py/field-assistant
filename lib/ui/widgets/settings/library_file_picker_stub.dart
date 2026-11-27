import 'dart:typed_data';

/// Stub padrão quando nem dart:io nem dart:js_interop estão disponíveis.
Future<({String name, Uint8List bytes})?> pickLibraryFileImpl({
  String? dialogTitle,
  List<String>? allowedExtensions,
}) {
  throw UnsupportedError('Seleção de arquivos não suportada nesta plataforma.');
}
