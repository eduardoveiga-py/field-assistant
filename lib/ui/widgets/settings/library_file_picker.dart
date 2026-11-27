import 'dart:typed_data';

import 'library_file_picker_stub.dart'
    if (dart.library.io) 'library_file_picker_io.dart'
    if (dart.library.js_interop) 'library_file_picker_web.dart'
    as impl;

/// Resultado multiplataforma da seleção de arquivo para importação offline.
typedef PickedLibraryFile = ({String name, Uint8List bytes});

/// Seleciona um arquivo local de Bíblia ou publicação (.epub / .json) e lê seus bytes.
/// Retorna `null` se o usuário cancelar a seleção.
Future<PickedLibraryFile?> pickLibraryFile({
  String? dialogTitle,
  List<String>? allowedExtensions,
}) {
  return impl.pickLibraryFileImpl(
    dialogTitle: dialogTitle,
    allowedExtensions: allowedExtensions,
  );
}
