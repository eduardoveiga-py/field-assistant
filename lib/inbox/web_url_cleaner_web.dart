// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

void cleanWebUrlQuery() {
  try {
    final loc = html.window.location;
    html.window.history.replaceState(null, '', loc.pathname ?? '/');
  } catch (_) {}
}
