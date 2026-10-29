import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<({double latitude, double longitude})?> getBrowserCoordinates() async {
  final completer = Completer<({double latitude, double longitude})?>();
  try {
    web.window.navigator.geolocation.getCurrentPosition(
      (web.GeolocationPosition pos) {
        if (!completer.isCompleted) {
          completer.complete((
            latitude: pos.coords.latitude.toDouble(),
            longitude: pos.coords.longitude.toDouble(),
          ));
        }
      }.toJS,
      (web.GeolocationPositionError err) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      }.toJS,
    );
  } catch (_) {
    return null;
  }
  return completer.future.timeout(
    const Duration(seconds: 7),
    onTimeout: () => null,
  );
}
