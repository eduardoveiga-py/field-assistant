import 'ics_picker_stub.dart'
    if (dart.library.js_interop) 'ics_picker_web.dart';

class IcsPickerHelper {
  /// Abre seletor de arquivos do navegador / sistema para carregar arquivo .ics
  static Future<String?> pickIcsFile() async {
    return pickIcsFileFromBrowser();
  }
}
