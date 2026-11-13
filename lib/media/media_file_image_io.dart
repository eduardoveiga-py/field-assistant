import 'dart:io';

import 'package:flutter/material.dart';

Widget buildLocalFileImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  required Widget Function() fallback,
}) {
  final file = File(path);
  if (!file.existsSync()) return fallback();
  return Image.file(
    file,
    fit: fit,
    width: width,
    height: height,
    errorBuilder: (context, error, stackTrace) => fallback(),
  );
}
