import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../core/app_logger.dart';
import 'geolocation_types.dart';

Future<GeolocationResult> getPlatformCoordinates() async {
  final completer = Completer<GeolocationResult>();
  try {
    web.window.navigator.geolocation.getCurrentPosition(
      (web.GeolocationPosition pos) {
        if (!completer.isCompleted) {
          final lat = pos.coords.latitude.toDouble();
          final lng = pos.coords.longitude.toDouble();
          if (lat.isFinite && lng.isFinite) {
            completer.complete(
              GeolocationResult(
                status: GeolocationStatus.success,
                coordinates: (latitude: lat, longitude: lng),
              ),
            );
          } else {
            completer.complete(
              const GeolocationResult(
                status: GeolocationStatus.unavailableOrTimeout,
              ),
            );
          }
        }
      }.toJS,
      (web.GeolocationPositionError err) {
        if (!completer.isCompleted) {
          final status = switch (err.code) {
            1 => GeolocationStatus.permissionDenied,
            2 => GeolocationStatus.serviceDisabled,
            _ => GeolocationStatus.unavailableOrTimeout,
          };
          completer.complete(GeolocationResult(status: status));
        }
      }.toJS,
    );
  } catch (e, st) {
    AppLogger.warning('Falha ao invocar navigator.geolocation na Web', e, st);
    return const GeolocationResult(
      status: GeolocationStatus.unsupportedPlatform,
    );
  }
  return completer.future.timeout(
    const Duration(seconds: 8),
    onTimeout: () => const GeolocationResult(
      status: GeolocationStatus.unavailableOrTimeout,
    ),
  );
}

Future<GeoCoordinates?> getBrowserCoordinates() async {
  final res = await getPlatformCoordinates();
  return res.coordinates;
}
