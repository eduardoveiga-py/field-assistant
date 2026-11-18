import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/app_logger.dart';

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

class GeocodingService {
  static final Map<String, ReverseGeocodingResult> _memCache = {};
  static DateTime? _lastRequestTime;
  static Future<void>? _rateLimitQueue;

  /// Garante conformidade estrita com a política de uso do Nominatim (máximo 1 req/s)
  static Future<void> _throttle() async {
    while (_rateLimitQueue != null) {
      await _rateLimitQueue;
    }
    final completer = Future<void>.delayed(const Duration(milliseconds: 1000));
    _rateLimitQueue = completer;

    final now = DateTime.now();
    if (_lastRequestTime != null) {
      final elapsed = now.difference(_lastRequestTime!);
      if (elapsed < const Duration(milliseconds: 1000)) {
        await Future.delayed(const Duration(milliseconds: 1000) - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();
    completer.then((_) {
      if (_rateLimitQueue == completer) {
        _rateLimitQueue = null;
      }
    });
  }

  /// Limpa cache em memória (usado em testes automatizados)
  static void clearMemoryCache() {
    _memCache.clear();
    _lastRequestTime = null;
    _rateLimitQueue = null;
  }

  /// Realiza Geocodificação Reversa usando a API OpenStreetMap Nominatim
  /// com cache em memória e persistência em AppKvStore.
  static Future<ReverseGeocodingResult?> reverseGeocode(
    double lat,
    double lon, {
    dynamic db,
  }) async {
    final cacheKey =
        'nominatim_rev_${lat.toStringAsFixed(5)}_${lon.toStringAsFixed(5)}';

    if (_memCache.containsKey(cacheKey)) {
      return _memCache[cacheKey];
    }

    if (db != null) {
      try {
        final row = await (db.select(
          db.appKvStore,
        )..where((t) => t.key.equals(cacheKey))).getSingleOrNull();
        if (row != null) {
          final decoded = jsonDecode(row.value) as Map<String, dynamic>;
          final cached = ReverseGeocodingResult.fromJson(decoded);
          _memCache[cacheKey] = cached;
          return cached;
        }
      } catch (_) {}
    }

    try {
      await _throttle();

      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&addressdetails=1',
      );
      final headers = <String, String>{
        'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
      };
      if (!kIsWeb) {
        headers['User-Agent'] = 'MinisterioPessoalTerritorio/1.0 (territorio-app-local; contact: suporte@ministeriopessoal.app)';
      }
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(
          utf8.decode(response.bodyBytes),
        ) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final road =
              address['road'] ??
              address['pedestrian'] ??
              address['street'] ??
              address['footway'] ??
              address['residential'] ??
              address['avenue'] ??
              address['highway'];

          final houseNumber = address['house_number'];
          final suburb =
              address['suburb'] ??
              address['neighbourhood'] ??
              address['quarter'] ??
              address['city_district'] ??
              address['residential'];

          final city =
              address['city'] ??
              address['town'] ??
              address['municipality'] ??
              address['village'] ??
              address['county'];

          final state = address['state'];
          final displayName = data['display_name'] as String?;

          final result = ReverseGeocodingResult(
            latitude: lat,
            longitude: lon,
            street: road?.toString(),
            houseNumber: houseNumber?.toString(),
            neighborhood: suburb?.toString(),
            city: city?.toString(),
            state: state?.toString(),
            fullAddress: displayName,
          );

          _memCache[cacheKey] = result;

          if (db != null) {
            try {
              await db
                  .into(db.appKvStore)
                  .insertOnConflictUpdate(
                    dynamicDbCompanion(
                      db,
                      cacheKey,
                      jsonEncode(result.toJson()),
                    ),
                  );
            } catch (_) {}
          }

          return result;
        }
      }
    } catch (e, st) {
      AppLogger.debug(
        'Falha de rede na geocodificação reversa ($lat, $lon): $e',
        st,
      );
    }
    return null;
  }

  /// Realiza Geocodificação Direta (endereço -> latitude e longitude)
  /// com cache persistente e rate-limiting estrito.
  static Future<ReverseGeocodingResult?> geocodeAddress(
    String query, {
    dynamic db,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return null;

    final cacheKey = 'nominatim_geo_${cleanQuery.toLowerCase()}';
    if (_memCache.containsKey(cacheKey)) {
      return _memCache[cacheKey];
    }

    if (db != null) {
      try {
        final row = await (db.select(
          db.appKvStore,
        )..where((t) => t.key.equals(cacheKey))).getSingleOrNull();
        if (row != null) {
          final decoded = jsonDecode(row.value) as Map<String, dynamic>;
          final cached = ReverseGeocodingResult.fromJson(decoded);
          _memCache[cacheKey] = cached;
          return cached;
        }
      } catch (_) {}
    }

    try {
      await _throttle();

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
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final list =
            json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        if (list.isNotEmpty) {
          final first = list[0] as Map<String, dynamic>;
          final lat = double.tryParse(first['lat']?.toString() ?? '');
          final lon = double.tryParse(first['lon']?.toString() ?? '');
          if (lat != null && lon != null) {
            final result = ReverseGeocodingResult(
              latitude: lat,
              longitude: lon,
              fullAddress: first['display_name'] as String?,
            );
            _memCache[cacheKey] = result;

            if (db != null) {
              try {
                await db
                    .into(db.appKvStore)
                    .insertOnConflictUpdate(
                      dynamicDbCompanion(
                        db,
                        cacheKey,
                        jsonEncode(result.toJson()),
                      ),
                    );
              } catch (_) {}
            }

            return result;
          }
        }
      }
    } catch (e, st) {
      AppLogger.debug(
        'Falha de rede na geocodificação direta ("$cleanQuery"): $e',
        st,
      );
    }
    return null;
  }

  static dynamic dynamicDbCompanion(dynamic db, String key, String value) {
    return db.appKvStore.companion(
      key: key,
      value: value,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}
