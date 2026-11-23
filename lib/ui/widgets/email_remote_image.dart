import 'package:flutter/widgets.dart';

import 'email_remote_image_stub.dart'
    if (dart.library.js_interop) 'email_remote_image_web.dart'
    as impl;

/// Componente que renderiza imagens remotas de e-mails de forma segura
/// em todas as plataformas:
/// - Na Web (HTML5/CanvasKit), usa elemento <img> nativo via `HtmlElementView`
///   com `referrerPolicy = 'no-referrer'`, contornando bloqueios rígidos de CORS.
/// - No Mobile/Desktop, utiliza `Image.network` com fallback amigável.
class EmailRemoteImage extends StatelessWidget {
  final String url;
  final String? alt;
  final double? width;
  final double? height;
  final BoxFit fit;

  const EmailRemoteImage({
    super.key,
    required this.url,
    this.alt,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return impl.buildEmailRemoteImage(
      context: context,
      url: url,
      alt: alt,
      width: width,
      height: height,
      fit: fit,
    );
  }
}
