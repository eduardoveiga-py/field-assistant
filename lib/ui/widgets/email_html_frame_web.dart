import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../../inbox/email_html_sanitizer.dart';

/// Renderizador de e-mail seguro para Flutter Web (HTML5/CanvasKit).
/// Isola todo o conteúdo HTML em um único `<iframe>` nativo sandboxed,
/// eliminando conflitos de PlatformView, sobreposição de imagens e restrições de CORS.
class EmailHtmlFrame extends StatelessWidget {
  final String html;
  final List<Map<String, dynamic>> attachments;
  final double? height;
  final double minHeight;

  const EmailHtmlFrame({
    super.key,
    required this.html,
    this.attachments = const [],
    this.height,
    this.minHeight = 520,
  });

  static String buildIframeSrcDoc(String resolvedHtml) =>
      EmailHtmlSanitizer.buildIframeSrcDoc(resolvedHtml);

  @override
  Widget build(BuildContext context) {
    final cleanHtml = EmailHtmlSanitizer.sanitizeHtmlForDisplay(html);
    final resolvedHtml = EmailHtmlSanitizer.resolveInlineCidImages(
      cleanHtml,
      attachments,
    );
    final srcDoc = buildIframeSrcDoc(resolvedHtml);

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: HtmlElementView.fromTagName(
          key: ValueKey(srcDoc.hashCode),
          tagName: 'iframe',
          onElementCreated: (Object element) {
            final iframe = element as web.HTMLIFrameElement;
            iframe.setAttribute('srcdoc', srcDoc);
            iframe.setAttribute(
              'sandbox',
              'allow-popups allow-popups-to-escape-sandbox',
            );
            iframe.style.border = 'none';
            iframe.style.width = '100%';
            iframe.style.height = '100%';
            iframe.style.backgroundColor = '#ffffff';
          },
        ),
      ),
    );
  }
}
