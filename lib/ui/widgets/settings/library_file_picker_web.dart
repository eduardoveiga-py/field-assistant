import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Seleção de arquivos para Web/PWA resistente ao cancelamento prematuro no `focus`.
///
/// O plugin `file_picker_web` cancela o diálogo em 500ms após `window.focus`
/// (`cancelUploadOnWindowBlur: true`), além de filtrar `<input accept="...">`
/// por extensões que navegadores móveis (Android Chrome / iOS Safari PWA) muitas
/// vezes não mapeiam ao MIME de arquivos baixados (`.epub` / `.json`).
/// Aqui mantemos o gesto síncrono de `input.click()`, não filtramos no OS e só
/// encerramos por cancelamento explícito (`cancel`) ou após janela segura sem seleção.
Future<({String name, Uint8List bytes})?> pickLibraryFileImpl({
  String? dialogTitle,
  List<String>? allowedExtensions,
}) {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..multiple = false
    ..style.position = 'fixed'
    ..style.left = '-9999px'
    ..style.top = '-9999px'
    ..style.opacity = '0';

  web.document.body?.appendChild(input);

  final completer = Completer<({String name, Uint8List bytes})?>();
  var finished = false;
  Timer? focusGraceTimer;

  late final JSFunction onChangeJs;
  late final JSFunction onCancelJs;
  late final JSFunction onWindowFocusJs;

  void cleanup() {
    focusGraceTimer?.cancel();
    input.removeEventListener('change', onChangeJs);
    input.removeEventListener('cancel', onCancelJs);
    web.window.removeEventListener('focus', onWindowFocusJs);
    if (input.parentNode != null) {
      input.parentNode!.removeChild(input);
    }
  }

  Future<void> deliverSelectedFile() async {
    if (finished) return;
    finished = true;
    try {
      final files = input.files;
      final file = files != null && files.length > 0 ? files.item(0) : null;
      cleanup();
      if (file == null) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      final buffer = await file.arrayBuffer().toDart;
      final bytes = buffer.toDart.asUint8List();
      if (!completer.isCompleted) {
        completer.complete((name: file.name, bytes: bytes));
      }
    } catch (e, st) {
      cleanup();
      if (!completer.isCompleted) {
        completer.completeError(e, st);
      }
    }
  }

  void cancelSelection() {
    if (finished) return;
    finished = true;
    cleanup();
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  }

  onChangeJs = ((web.Event _) {
    unawaited(deliverSelectedFile());
  }).toJS;

  onCancelJs = ((web.Event _) {
    cancelSelection();
  }).toJS;

  // Fallback para navegadores WebKit/iOS mais antigos que não disparam evento `cancel`:
  // aguarda janela ampla para o navegador preencher `input.files` antes de concluir null.
  onWindowFocusJs = ((web.Event _) {
    focusGraceTimer?.cancel();
    focusGraceTimer = Timer(const Duration(milliseconds: 3000), () {
      if (finished) return;
      final files = input.files;
      if (files != null && files.length > 0) {
        unawaited(deliverSelectedFile());
      } else {
        cancelSelection();
      }
    });
  }).toJS;

  input.addEventListener('change', onChangeJs);
  input.addEventListener('cancel', onCancelJs);
  web.window.addEventListener('focus', onWindowFocusJs);

  input.click();
  return completer.future;
}
