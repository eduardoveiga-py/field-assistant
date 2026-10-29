import 'web_downloader_stub.dart'
    if (dart.library.js_interop) 'web_downloader_web.dart';

class FileDownloader {
  static void download(String filename, String content) {
    downloadFileWeb(filename, content);
  }
}
