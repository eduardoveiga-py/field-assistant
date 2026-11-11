Future<String> saveVerifiedUpdateFile({
  required List<int> bytes,
  required String fileName,
  String? customDirectoryPath,
}) async {
  throw UnsupportedError(
    'Download e instalação local de pacote não são suportados na Web.',
  );
}

Future<bool> openVerifiedUpdateFile(String filePath) async => false;
