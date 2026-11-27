import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Seleção nativa de arquivos para Android, iOS e Desktop.
///
/// Usa [FileType.any] no seletor do sistema para evitar que MIME types ausentes
/// ou UTIs dinâmicas (.epub, .json, .jwpub, .jwlpub) deixem arquivos válidos
/// esmaecidos no Android DocumentsUI ou no app Arquivos do iOS; a validação de
/// formato acontece em seguida pelo conteúdo/extensão em Dart.
Future<({String name, Uint8List bytes})?> pickLibraryFileImpl({
  String? dialogTitle,
  List<String>? allowedExtensions,
}) async {
  final files = await FilePicker.pickFiles(
    dialogTitle: dialogTitle,
    type: FileType.any,
  );
  if (files.isEmpty) return null;

  final picked = files.first;
  var bytes = await _readPlatformFileBytes(picked);
  if (bytes == null || bytes.isEmpty) {
    final path = picked.path;
    if (path != null && path.trim().isNotEmpty) {
      final f = File(path);
      if (await f.exists()) {
        bytes = await f.readAsBytes();
      }
    }
  }

  return (name: picked.name, bytes: bytes ?? Uint8List(0));
}

Future<Uint8List?> _readPlatformFileBytes(PlatformFile picked) async {
  try {
    final direct = await picked.readAsBytes();
    if (direct.isNotEmpty) return direct;
  } catch (_) {}

  try {
    final collected = <int>[];
    await for (final chunk in picked.readAsByteStream()) {
      collected.addAll(chunk);
    }
    if (collected.isNotEmpty) {
      return Uint8List.fromList(collected);
    }
  } catch (_) {}

  return null;
}
