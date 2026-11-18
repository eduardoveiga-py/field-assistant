import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final RegExp _controlCharsPattern = RegExp(r'[\x00-\x1F\x7F]');
final RegExp _illegalFileNameChars = RegExp(r'[<>:"|?*]');
final RegExp _windowsReservedDeviceNames = RegExp(
  r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?$',
  caseSensitive: false,
);

List<String> _validateAndSplitSubDir(String subDir) {
  final trimmed = subDir.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(subDir, 'subDir', 'Subdiretório de mídia vazio.');
  }
  if (_controlCharsPattern.hasMatch(trimmed) ||
      _illegalFileNameChars.hasMatch(trimmed) ||
      p.isAbsolute(trimmed) ||
      trimmed.startsWith('/') ||
      trimmed.startsWith('\\')) {
    throw ArgumentError.value(
      subDir,
      'subDir',
      'Subdiretório de mídia contém caminho absoluto ou caracteres proibidos.',
    );
  }
  final segments = trimmed.split(RegExp(r'[/\\]'));
  for (final seg in segments) {
    if (seg.isEmpty ||
        seg == '.' ||
        seg == '..' ||
        seg.contains('..') ||
        seg.endsWith('.') ||
        seg.endsWith(' ') ||
        _windowsReservedDeviceNames.hasMatch(seg)) {
      throw ArgumentError.value(
        subDir,
        'subDir',
        'Subdiretório de mídia contém segmento inválido ou traversal.',
      );
    }
  }
  return segments;
}

String _validateMediaFileName(String fileName) {
  final trimmed = fileName.trim();
  if (trimmed.isEmpty || trimmed.length > 255) {
    throw ArgumentError.value(
      fileName,
      'fileName',
      'Nome de arquivo de mídia vazio ou excede 255 caracteres.',
    );
  }
  if (trimmed == '.' ||
      trimmed == '..' ||
      trimmed.contains('..') ||
      trimmed.contains('/') ||
      trimmed.contains('\\') ||
      trimmed.endsWith('.') ||
      _illegalFileNameChars.hasMatch(trimmed) ||
      _controlCharsPattern.hasMatch(trimmed) ||
      p.isAbsolute(trimmed) ||
      p.basename(trimmed) != trimmed ||
      _windowsReservedDeviceNames.hasMatch(trimmed)) {
    throw ArgumentError.value(
      fileName,
      'fileName',
      'Nome de arquivo de mídia inválido ou tentativa de path traversal.',
    );
  }
  return trimmed;
}

Future<Uint8List?> readMediaBytes(String pathOrUrl) async {
  if (pathOrUrl.isEmpty) return null;
  if (pathOrUrl.startsWith('data:')) {
    final commaIdx = pathOrUrl.indexOf(',');
    if (commaIdx != -1) {
      return base64Decode(pathOrUrl.substring(commaIdx + 1));
    }
    return null;
  }
  if (pathOrUrl.startsWith('http://') ||
      pathOrUrl.startsWith('https://') ||
      pathOrUrl.startsWith('blob:')) {
    final resp = await http.get(Uri.parse(pathOrUrl));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return resp.bodyBytes;
    }
    return null;
  }
  final file = File(pathOrUrl);
  if (!await file.exists()) return null;
  return await file.readAsBytes();
}

Future<String?> saveMediaBytes({
  required String baseDir,
  required String subDir,
  required String fileName,
  required Uint8List bytes,
  String mimeType = 'application/octet-stream',
}) async {
  final trimmedBase = baseDir.trim();
  if (trimmedBase.isEmpty) {
    throw ArgumentError.value(baseDir, 'baseDir', 'Diretório base vazio.');
  }
  final subDirSegments = _validateAndSplitSubDir(subDir);
  final safeFileName = _validateMediaFileName(fileName);

  final canonicalBase = p.canonicalize(trimmedBase);
  final targetDirPath = p.canonicalize(
    p.joinAll([canonicalBase, ...subDirSegments]),
  );
  if (!p.isWithin(canonicalBase, targetDirPath)) {
    throw ArgumentError(
      'Subdiretório de mídia fora do diretório base permitido.',
    );
  }

  final targetFilePath = p.canonicalize(p.join(targetDirPath, safeFileName));
  if (!p.isWithin(targetDirPath, targetFilePath)) {
    throw ArgumentError(
      'Caminho de destino fora do diretório permitido (path traversal bloqueado).',
    );
  }

  final baseDirectory = Directory(canonicalBase);
  if (!await baseDirectory.exists()) {
    await baseDirectory.create(recursive: true);
  }
  final resolvedBase = p.canonicalize(
    await baseDirectory.resolveSymbolicLinks(),
  );

  final dir = Directory(targetDirPath);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  final resolvedDir = p.canonicalize(await dir.resolveSymbolicLinks());
  if (!p.isWithin(resolvedBase, resolvedDir)) {
    throw ArgumentError(
      'Subdiretório resolvido escapa do diretório base permitido (symlink bloqueado).',
    );
  }

  final resolvedTarget = p.canonicalize(p.join(resolvedDir, safeFileName));
  if (!p.isWithin(resolvedDir, resolvedTarget)) {
    throw ArgumentError(
      'Destino resolvido escapa do diretório de mídia permitido.',
    );
  }
  if (await FileSystemEntity.isLink(resolvedTarget)) {
    throw ArgumentError(
      'Destino de mídia é um link simbólico e foi bloqueado por segurança.',
    );
  }

  final rand = Random.secure();
  final nonce =
      '${DateTime.now().microsecondsSinceEpoch}_${rand.nextInt(1 << 30)}';
  final tempFile = File(p.join(resolvedDir, '.media_tmp_$nonce'));
  final targetFile = File(resolvedTarget);
  File? backupExisting;

  try {
    await tempFile.writeAsBytes(bytes, flush: true);
    if (await targetFile.exists()) {
      final bak = File(p.join(resolvedDir, '.media_bak_$nonce'));
      await targetFile.rename(bak.path);
      backupExisting = bak;
    }
    await tempFile.rename(targetFile.path);
    if (backupExisting != null && await backupExisting.exists()) {
      await backupExisting.delete();
      backupExisting = null;
    }
    return targetFile.path;
  } catch (_) {
    if (await tempFile.exists()) {
      try {
        await tempFile.delete();
      } catch (_) {}
    }
    if (backupExisting != null &&
        await backupExisting.exists() &&
        !await targetFile.exists()) {
      try {
        await backupExisting.rename(targetFile.path);
      } catch (_) {}
    }
    rethrow;
  }
}

Future<bool> localMediaExists(String pathOrUrl) async {
  if (pathOrUrl.isEmpty) return false;
  if (pathOrUrl.startsWith('data:') ||
      pathOrUrl.startsWith('http://') ||
      pathOrUrl.startsWith('https://') ||
      pathOrUrl.startsWith('blob:')) {
    return true;
  }
  return File(pathOrUrl).exists();
}

Future<String> resolveDefaultDocumentsDir() async {
  final docsDir = await getApplicationDocumentsDirectory();
  return docsDir.path;
}
