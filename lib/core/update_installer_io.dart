import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> saveVerifiedUpdateFile({
  required List<int> bytes,
  required String fileName,
  String? customDirectoryPath,
}) async {
  final targetDir = customDirectoryPath != null
      ? Directory(customDirectoryPath)
      : await getTemporaryDirectory();
  if (!await targetDir.exists()) {
    await targetDir.create(recursive: true);
  }
  final safeName = p.basename(fileName).replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  final file = File(p.join(targetDir.path, safeName));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<bool> openVerifiedUpdateFile(String filePath) async {
  final result = await OpenFilex.open(filePath);
  return result.type == ResultType.done;
}
