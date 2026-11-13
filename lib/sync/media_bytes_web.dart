import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

Future<Uint8List?> readMediaBytes(String pathOrUrl) async {
  if (pathOrUrl.isEmpty) return null;
  if (pathOrUrl.startsWith('data:')) {
    final commaIdx = pathOrUrl.indexOf(',');
    if (commaIdx != -1) {
      return base64Decode(pathOrUrl.substring(commaIdx + 1));
    }
    return null;
  }
  if (pathOrUrl.startsWith('blob:') ||
      pathOrUrl.startsWith('http://') ||
      pathOrUrl.startsWith('https://')) {
    final resp = await http.get(Uri.parse(pathOrUrl));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return resp.bodyBytes;
    }
  }
  return null;
}

Future<String?> saveMediaBytes({
  required String baseDir,
  required String subDir,
  required String fileName,
  required Uint8List bytes,
  String mimeType = 'application/octet-stream',
}) async {
  return 'data:$mimeType;base64,${base64Encode(bytes)}';
}

Future<bool> localMediaExists(String pathOrUrl) async {
  return pathOrUrl.startsWith('data:') ||
      pathOrUrl.startsWith('blob:') ||
      pathOrUrl.startsWith('http://') ||
      pathOrUrl.startsWith('https://');
}

Future<String> resolveDefaultDocumentsDir() async => '';
