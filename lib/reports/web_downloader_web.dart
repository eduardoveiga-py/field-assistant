import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../core/app_logger.dart';

void downloadFileWeb(String filename, String content) {
  try {
    final bytes = utf8.encode(content);
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'text/csv;charset=utf-8;'),
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
