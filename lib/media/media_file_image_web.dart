import 'package:flutter/material.dart';

Widget buildLocalFileImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  required Widget Function() fallback,
}) {
  return fallback();
}
