import 'package:http/http.dart' as http;

import '../database/app_database.dart';
import 'geocoding/offline_geocoding_service.dart';

class ReverseGeocodingResult {
  final double latitude;
  final double longitude;
  final String? street;
  final String? houseNumber;
  final String? neighborhood;
  final String? city;
  final String? state;
  final String? fullAddress;

  const ReverseGeocodingResult({
    required this.latitude,
    required this.longitude,
    this.street,
    this.houseNumber,
    this.neighborhood,
    this.city,
    this.state,
    this.fullAddress,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'street': street,
    'houseNumber': houseNumber,
    'neighborhood': neighborhood,
    'city': city,
    'state': state,
    'fullAddress': fullAddress,
  };

  factory ReverseGeocodingResult.fromJson(Map<String, dynamic> json) {
    return ReverseGeocodingResult(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      street: json['street'] as String?,
      houseNumber: json['houseNumber'] as String?,
      neighborhood: json['neighborhood'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      fullAddress: json['fullAddress'] as String?,
    );
  }

  String get streetAndNumber {
    if (street != null && street!.trim().isNotEmpty) {
      if (houseNumber != null && houseNumber!.trim().isNotEmpty) {
        return '$street, $houseNumber';
      }
      return street!;
    }
    return fullAddress ?? '';
  }

  String get formattedSummary {
    final parts = <String>[];
    if (streetAndNumber.isNotEmpty) parts.add(streetAndNumber);
    if (neighborhood != null && neighborhood!.isNotEmpty) {
      parts.add(neighborhood!);
    }
    if (city != null && city!.isNotEmpty) parts.add(city!);
    return parts.join(' - ');
  }
}

/// Fachada retrocompatível que delega integralmente ao [OfflineGeocodingService]
/// (cache persistente Drift `AppKvStore` com TTL de 30 dias, rate-limit de 1 req/s
/// conforme política Nominatim e busca local offline).
class GeocodingService {
  /// Limpa cache em memória (usado em testes automatizados).
  static void clearMemoryCache() {
    OfflineGeocodingService.clearMemoryCache();
  }

  /// Realiza Geocodificação Reversa via [OfflineGeocodingService] com cache TTL de 30 dias.
  static Future<ReverseGeocodingResult?> reverseGeocode(
    double lat,
    double lon, {
    AppDatabase? db,
    http.Client? httpClient,
  }) {
    return OfflineGeocodingService.reverseGeocode(
      lat,
      lon,
      db: db,
      httpClient: httpClient,
    );
  }

  /// Realiza Geocodificação Direta via [OfflineGeocodingService] com cache TTL de 30 dias.
  static Future<ReverseGeocodingResult?> geocodeAddress(
    String query, {
    AppDatabase? db,
    http.Client? httpClient,
  }) {
    return OfflineGeocodingService.geocodeAddress(
      query,
      db: db,
      httpClient: httpClient,
    );
  }
}
