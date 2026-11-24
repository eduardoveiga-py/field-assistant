import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../inbox/email_html_sanitizer.dart';

/// Renderizador de e-mail profissional para Mobile (Android/iOS) e Desktop (Windows/macOS/Linux).
/// Utiliza `HtmlWidget` nativo dentro de um container com tema claro `#FFFFFF`,
/// respeitando dimensões declaradas de imagens e renderizando inline CIDs sem distorções.
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

    final contentWidget = Theme(
      data: ThemeData.light(),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: minHeight),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SelectionArea(
          child: HtmlWidget(
            resolvedHtml,
            textStyle: const TextStyle(
              fontSize: 14.5,
              height: 1.55,
              letterSpacing: 0.15,
              color: Color(0xFF1E293B),
            ),
            customWidgetBuilder: (element) {
              if (element.localName == 'img') {
                final src = element.attributes['src'] ?? '';
                final widthAttr = double.tryParse(
                  element.attributes['width'] ?? '',
                );
                final heightAttr = double.tryParse(
                  element.attributes['height'] ?? '',
                );

                if (src.startsWith('data:image/')) {
                  final commaIndex = src.indexOf(',');
                  if (commaIndex != -1) {
                    try {
                      final base64Data = src.substring(commaIndex + 1);
                      final bytes = base64Decode(base64Data);
                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 600),
                        child: Image.memory(
                          bytes,
                          width: widthAttr,
                          height: heightAttr,
                          fit: BoxFit.scaleDown,
                        ),
                      );
                    } catch (_) {}
                  }
                } else if (src.startsWith('http://') ||
                    src.startsWith('https://')) {
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 600),
                    child: Image.network(
                      src,
                      width: widthAttr,
                      height: heightAttr,
                      fit: BoxFit.scaleDown,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  );
                }
              }
              return null;
            },
            onTapUrl: (url) async {
              final uri = Uri.tryParse(url);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                return true;
              }
              return false;
            },
          ),
        ),
      ),
    );

    if (height != null) {
      return SizedBox(
        height: height,
        child: SingleChildScrollView(child: contentWidget),
      );
    }
    return contentWidget;
  }
}
