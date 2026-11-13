import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'geolocation_stub.dart'
    if (dart.library.js_interop) 'geolocation_web.dart';
import 'geolocation_types.dart';

export 'geolocation_types.dart';

class GeolocationHelper {
  /// Coordenada padrão: Santo Antônio do Içá, AM
  static const double manausCenterLat = -3.1022;
  static const double manausCenterLng = -67.9397;
  static const double defaultLat = -3.1022;
  static const double defaultLng = -67.9397;

  @visibleForTesting
  static Future<GeolocationResult> Function()? locationOverride;

  /// Obtém as coordenadas atuais com detalhes de status (permissão/serviço/indisponibilidade)
  static Future<GeolocationResult> getCurrentLocationWithStatus() {
    if (locationOverride != null) {
      return locationOverride!();
    }
    return getPlatformCoordinates();
  }

  /// Obtém as coordenadas atuais do navegador/dispositivo com fallback gracioso
  static Future<GeoCoordinates?> getCurrentLocation() async {
    final res = await getCurrentLocationWithStatus();
    return res.coordinates;
  }

  /// Calcula a distância geográfica precisa em km pelo método Haversine
  static double calculateHaversineDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final rLat1 = lat1 * math.pi / 180.0;
    final rLat2 = lat2 * math.pi / 180.0;

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) *
            math.sin(dLon / 2) *
            math.cos(rLat1) *
            math.cos(rLat2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }
}
