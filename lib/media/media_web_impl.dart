import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<String?> pickImageFromBrowser({bool useCamera = false}) async {
  final completer = Completer<String?>();
  try {
    final uploadInput = web.HTMLInputElement()
      ..type = 'file'
      ..accept = 'image/*,video/*';

    if (useCamera) {
      uploadInput.setAttribute('capture', 'environment');
    }

    uploadInput.onChange.listen((event) {
      final files = uploadInput.files;
      if (files != null && files.length > 0) {
        final file = files.item(0);
        if (file != null) {
          final reader = web.FileReader();
          reader.onLoadEnd.listen((e) {
            final result = reader.result;
            if (result != null) {
              if (result.isA<JSString>()) {
                completer.complete((result as JSString).toDart);
              } else {
                completer.complete(result.toString());
              }
            } else {
              completer.complete(null);
            }
          });
          reader.readAsDataURL(file);
          return;
        }
      }
      completer.complete(null);
    });

    uploadInput.click();
  } catch (_) {
    completer.complete(null);
  }

  return completer.future;
}
