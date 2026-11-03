import 'dart:io';

import 'package:path_provider/path_provider.dart';

void downloadFileWeb(String filename, String content) {
  try {
    getApplicationDocumentsDirectory()
        .then((dir) {
          final file = File('${dir.path}/$filename');
          file.writeAsStringSync(content);
        })
        .catchError((_) {});
  } catch (_) {}
}
