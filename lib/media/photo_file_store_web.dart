Future<String?> savePhotoBytesToDisk({
  required String photoId,
  required List<int> bytes,
  String extension = 'jpg',
  Future<String> Function()? documentsDirectoryProvider,
}) async => null;

Future<void> deletePhotoFileFromDisk(String? filePath) async {}
