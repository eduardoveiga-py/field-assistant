import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
    if (neighborhood != null && neighborhood!.isNotEmpty) parts.add(neighborhood!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    return parts.join(' - ');
  }
}

class GeocodingService {
  /// Realiza Geocodificação Reversa usando a API OpenStreetMap Nominatim
  static Future<ReverseGeocodingResult?> reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&addressdetails=1',
      );
      final headers = <String, String>{
        'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
      };
      if (!kIsWeb) {
        headers['User-Agent'] = 'MinisterioPessoalTerritorio/1.0 (territorio-app-local; contact: suporte@ministeriopessoal.app)';
      }
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final road = address['road'] ??
              address['pedestrian'] ??
              address['street'] ??
              address['footway'] ??
              address['residential'] ??
              address['avenue'] ??
              address['highway'];

          final houseNumber = address['house_number'];
          final suburb = address['suburb'] ??
              address['neighbourhood'] ??
              address['quarter'] ??
              address['city_district'] ??
              address['residential'];

          final city = address['city'] ??
              address['town'] ??
              address['municipality'] ??
              address['village'] ??
              address['county'];

          final state = address['state'];
          final displayName = data['display_name'] as String?;

          return ReverseGeocodingResult(
            latitude: lat,
            longitude: lon,
            street: road?.toString(),
            houseNumber: houseNumber?.toString(),
            neighborhood: suburb?.toString(),
            city: city?.toString(),
            state: state?.toString(),
            fullAddress: displayName,
          );
        }
      }
    } catch (_) {
      // Falha graciosa de rede
    }
    return null;
  }

  /// Realiza Geocodificação Direta (endereço -> latitude e longitude)
  static Future<ReverseGeocodingResult?> geocodeAddress(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return null;
    try {
      final clean = Uri.encodeComponent(cleanQuery);
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=$clean&limit=1&addressdetails=1',
      );
      final headers = <String, String>{
        'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
      };
      if (!kIsWeb) {
        headers['User-Agent'] = 'MinisterioPessoalTerritorio/1.0 (territorio-app-local; contact: suporte@ministeriopessoal.app)';
      }
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final list = json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        if (list.isNotEmpty) {
          final first = list[0] as Map<String, dynamic>;
          final lat = double.tryParse(first['lat']?.toString() ?? '');
          final lon = double.tryParse(first['lon']?.toString() ?? '');
          if (lat != null && lon != null) {
            return ReverseGeocodingResult(
              latitude: lat,
              longitude: lon,
              fullAddress: first['display_name'] as String?,
            );
          }
        }
      }
    } catch (_) {
      // Falha graciosa de rede
    }
    return null;
  }
}

