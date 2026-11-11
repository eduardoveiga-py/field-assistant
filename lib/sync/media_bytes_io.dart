import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
  final dir = Directory(p.join(baseDir, subDir));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final target = File(p.join(dir.path, fileName));
  await target.writeAsBytes(bytes, flush: true);
  return target.path;
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
