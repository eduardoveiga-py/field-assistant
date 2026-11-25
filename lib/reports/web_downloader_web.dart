import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../core/app_logger.dart';

void downloadFileWeb(String filename, String content) {
  final bytes = Uint8List.fromList(utf8.encode(content));
  downloadBytesWeb(filename, bytes, 'text/csv;charset=utf-8;');
}

void downloadBytesWeb(String filename, Uint8List bytes, String mimeType) {
  try {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = filename;
    anchor.click();
    web.URL.revokeObjectURL(url);
  } catch (e, st) {
    AppLogger.warning('Falha ao baixar arquivo na Web ($filename)', e, st);
  }
}
