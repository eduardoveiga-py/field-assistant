import 'package:flutter/material.dart';

Widget buildEmailRemoteImage({
  required BuildContext context,
  required String url,
  String? alt,
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
}) {
  return Image.network(
    url,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (context, error, stackTrace) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          alt?.isNotEmpty == true ? alt! : 'Imagem',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    },
  );
}
