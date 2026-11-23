import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

Widget buildEmailRemoteImage({
  required BuildContext context,
  required String url,
  String? alt,
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
}) {
  return SizedBox(
    width: width,
    height: height,
    child: HtmlElementView.fromTagName(
      tagName: 'img',
      onElementCreated: (Object element) {
        final img = element as web.HTMLImageElement;
        img.src = url;
        if (alt != null && alt.isNotEmpty) {
          img.alt = alt;
        }
        img.referrerPolicy = 'no-referrer';
        img.style.maxWidth = '100%';
        img.style.height = 'auto';
        img.style.display = 'block';
        img.style.objectFit = 'contain';
      },
    ),
  );
}
