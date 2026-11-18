import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/app_logger.dart';
import '../../database/app_database.dart';
import '../geocoding_service.dart';

/// Tipo de entidade encontrada em busca local offline.
enum LocalResultType {
  contact('contact'),
  landmark('landmark'),
  sector('sector');

  final String wireName;
  const LocalResultType(this.wireName);
}

/// Registro unificado de resultado de busca cartográfica offline.
class LocalSearchResult {
  final String id;
  final LocalResultType type;
  final String title;
  final String? subtitle;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic> metadata;

  const LocalSearchResult({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.latitude,
    this.longitude,
    this.metadata = const {},
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.wireName,
    'title': title,
    'subtitle': subtitle,
    'latitude': latitude,
    'longitude': longitude,
    'metadata': metadata,
  };
}

/// Serviço de Geocodificação Híbrido e Offline-First (FA-MAP-01/02).
/// Inclui:
/// 1. Cache persistente em Drift/SQLite (AppKvStore) com TTL estrito de 30 dias.
/// 2. Rate-limiter de 1 requisição/segundo conforme diretrizes da Fundação OpenStreetMap.
/// 3. Mecanismo de busca local em contatos (People), marcos (TerritoryLandmarks) e setores
///    (TerritorySectors) no banco SQLite local, funcionando 100% sem conexão com a internet.
class OfflineGeocodingService {
  static const Duration cacheTtl = Duration(days: 30);

  static final Map<String, _CachedEntry> _memoryCache = {};
  static DateTime? _lastRequestTime;
  static Future<void> _rateLimitChain = Future<void>.value();

  /// Limpa o cache em memória (utilizado em testes unitários).
  static void clearMemoryCache() {
    _memoryCache.clear();
    _lastRequestTime = null;
    _rateLimitChain = Future<void>.value();
  }

  /// Garante estrita obediência ao rate limit de 1 req/s para a API OSM Nominatim
  /// sem deixar timers pendentes após o término da requisição.
  static Future<void> _enforceRateLimit() {
    final prev = _rateLimitChain;
    final completer = Completer<void>();
    _rateLimitChain = completer.future;

    Future<void> run() async {
      try {
        await prev;
      } catch (_) {}
      try {
        final now = DateTime.now();
        if (_lastRequestTime != null) {
          final elapsed = now.difference(_lastRequestTime!);
          if (elapsed < const Duration(milliseconds: 1000)) {
            await Future.delayed(const Duration(milliseconds: 1000) - elapsed);
          }
        }
        _lastRequestTime = DateTime.now();
      } finally {
        if (!completer.isCompleted) completer.complete();
      }
    }

    return run();
  }

  /// Geocodificação reversa (coordenadas -> endereço) com cache SQLite Drift (TTL 30 dias)
  /// e fallback offline.
  static Future<ReverseGeocodingResult?> reverseGeocode(
    double lat,
    double lon, {
    AppDatabase? db,
    http.Client? httpClient,
  }) async {
    final cacheKey =
        'nominatim_rev_${lat.toStringAsFixed(5)}_${lon.toStringAsFixed(5)}';

    // 1. Consulta em memória
    if (_memoryCache.containsKey(cacheKey)) {
      final entry = _memoryCache[cacheKey]!;
      if (!entry.isExpired(cacheTtl)) {
        return entry.result;
      }
    }

    // 2. Consulta no banco SQLite Drift (AppKvStore)
    if (db != null) {
      try {
        final row = await (db.select(
          db.appKvStore,
        )..where((t) => t.key.equals(cacheKey))).getSingleOrNull();
        if (row != null) {
          final payload = jsonDecode(row.value) as Map<String, dynamic>;
          final cachedAtStr = payload['cachedAt'] as String?;
          final result = ReverseGeocodingResult.fromJson(
            payload['data'] as Map<String, dynamic>,
          );

          DateTime? cachedAt;
          if (cachedAtStr != null) {
            cachedAt = DateTime.tryParse(cachedAtStr);
          }

          final isExpired =
              cachedAt != null &&
              DateTime.now().toUtc().difference(cachedAt) > cacheTtl;

          if (!isExpired) {
            _memoryCache[cacheKey] = _CachedEntry(
              result,
              cachedAt ?? DateTime.now(),
            );
            return result;
          }
        }
      } catch (e, st) {
        AppLogger.debug(
          'Erro ao consultar cache SQLite em reverseGeocode: $e',
          st,
        );
      }
    }

    // 3. Consulta de rede com rate-limiting
    try {
      await _enforceRateLimit();

      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&addressdetails=1',
      );
      final headers = <String, String>{
        'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
      };
      if (!kIsWeb) {
        headers['User-Agent'] = 'MinisterioPessoalTerritorio/1.0 (territorio-app-local; contact: suporte@ministeriopessoal.app)';
      }

      final ownsClient = httpClient == null;
      final client = httpClient ?? http.Client();
      final http.Response response;
      try {
        response = await client
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 8));
      } finally {
        if (ownsClient) client.close();
      }

      if (response.statusCode == 200) {
        final data = json.decode(
          utf8.decode(response.bodyBytes),
        ) as Map<String, dynamic>;
        if (data['error'] != null) {
          return null;
        }
        final address = data['address'] as Map<String, dynamic>?;
        final displayName = data['display_name'] as String?;
        if (address == null &&
            (displayName == null || displayName.trim().isEmpty)) {
          return null;
        }

        final road =
            address?['road'] ??
            address?['pedestrian'] ??
            address?['street'] ??
            address?['footway'] ??
            address?['residential'] ??
            address?['avenue'] ??
            address?['highway'];

        final houseNumber = address?['house_number'];
        final suburb =
            address?['suburb'] ??
            address?['neighbourhood'] ??
            address?['quarter'] ??
            address?['city_district'] ??
            address?['residential'];

        final city =
            address?['city'] ??
            address?['town'] ??
            address?['municipality'] ??
            address?['village'] ??
            address?['county'];

        final state = address?['state'];

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

        final now = DateTime.now().toUtc();
        _memoryCache[cacheKey] = _CachedEntry(result, now);

        if (db != null) {
          try {
            final cachePayload = jsonEncode({
              'cachedAt': now.toIso8601String(),
              'data': result.toJson(),
            });
            await db
                .into(db.appKvStore)
                .insertOnConflictUpdate(
                  AppKvStoreCompanion.insert(
                    key: cacheKey,
                    value: cachePayload,
                    updatedAt: Value(now),
                  ),
                );
          } catch (_) {}
        }

        return result;
      }
    } catch (e, st) {
      AppLogger.debug(
        'Falha de rede na geocodificação reversa ($lat, $lon): $e',
        st,
      );
    }

    return null;
  }

  /// Geocodificação direta (texto/endereço -> coordenadas) com cache Drift TTL 30 dias.
  static Future<ReverseGeocodingResult?> geocodeAddress(
    String query, {
    AppDatabase? db,
    http.Client? httpClient,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return null;

    final cacheKey = 'nominatim_geo_${cleanQuery.toLowerCase()}';

    // 1. Memória
    if (_memoryCache.containsKey(cacheKey)) {
      final entry = _memoryCache[cacheKey]!;
      if (!entry.isExpired(cacheTtl)) {
        return entry.result;
      }
    }

    // 2. Cache SQLite
    if (db != null) {
      try {
        final row = await (db.select(
          db.appKvStore,
        )..where((t) => t.key.equals(cacheKey))).getSingleOrNull();
        if (row != null) {
          final payload = jsonDecode(row.value) as Map<String, dynamic>;
          final cachedAtStr = payload['cachedAt'] as String?;
          final result = ReverseGeocodingResult.fromJson(
            payload['data'] as Map<String, dynamic>,
          );

          DateTime? cachedAt;
          if (cachedAtStr != null) {
            cachedAt = DateTime.tryParse(cachedAtStr);
          }

          final isExpired =
              cachedAt != null &&
              DateTime.now().toUtc().difference(cachedAt) > cacheTtl;

          if (!isExpired) {
            _memoryCache[cacheKey] = _CachedEntry(
              result,
              cachedAt ?? DateTime.now(),
            );
            return result;
          }
        }
      } catch (e, st) {
        AppLogger.debug(
          'Erro ao consultar cache SQLite em geocodeAddress: $e',
          st,
        );
      }
    }

    // 3. Rede com rate-limiting
    try {
      await _enforceRateLimit();

      final encodedQuery = Uri.encodeComponent(cleanQuery);
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=$encodedQuery&limit=1&addressdetails=1',
      );
      final headers = <String, String>{
        'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
      };
      if (!kIsWeb) {
        headers['User-Agent'] = 'MinisterioPessoalTerritorio/1.0 (territorio-app-local; contact: suporte@ministeriopessoal.app)';
      }

      final ownsClient = httpClient == null;
      final client = httpClient ?? http.Client();
      final http.Response response;
      try {
        response = await client
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 8));
      } finally {
        if (ownsClient) client.close();
      }

      if (response.statusCode == 200) {
        final list =
            json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        if (list.isNotEmpty) {
          final first = list[0] as Map<String, dynamic>;
          final lat = double.tryParse(first['lat']?.toString() ?? '');
          final lon = double.tryParse(first['lon']?.toString() ?? '');
          if (lat != null && lon != null) {
            final address = first['address'] as Map<String, dynamic>?;
            final road =
                address?['road'] ??
                address?['pedestrian'] ??
                address?['street'] ??
                address?['footway'] ??
                address?['residential'] ??
                address?['avenue'] ??
                address?['highway'];
            final suburb =
                address?['suburb'] ??
                address?['neighbourhood'] ??
                address?['quarter'] ??
                address?['city_district'] ??
                address?['residential'];
            final city =
                address?['city'] ??
                address?['town'] ??
                address?['municipality'] ??
                address?['village'] ??
                address?['county'];
            final result = ReverseGeocodingResult(
              latitude: lat,
              longitude: lon,
              street: road?.toString(),
              houseNumber: address?['house_number']?.toString(),
              neighborhood: suburb?.toString(),
              city: city?.toString(),
              state: address?['state']?.toString(),
              fullAddress: first['display_name'] as String?,
            );

            final now = DateTime.now().toUtc();
            _memoryCache[cacheKey] = _CachedEntry(result, now);

            if (db != null) {
              try {
                final cachePayload = jsonEncode({
                  'cachedAt': now.toIso8601String(),
                  'data': result.toJson(),
                });
                await db
                    .into(db.appKvStore)
                    .insertOnConflictUpdate(
                      AppKvStoreCompanion.insert(
                        key: cacheKey,
                        value: cachePayload,
                        updatedAt: Value(now),
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

  /// Busca offline local instantânea em contatos, marcos territoriais e setores
  /// cadastrados no banco de dados SQLite local, permitindo localizar ruas e POIs
  /// mesmo em modo avião ou em territórios sem qualquer sinal de celular.
  static Future<List<LocalSearchResult>> searchOffline({
    required String query,
    required AppDatabase? db,
  }) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty || db == null) return [];

    final results = <LocalSearchResult>[];

    try {
      // 1. Busca em Pessoas / Contatos do Território (com endereço ou coordenadas)
      final people = await (db.select(
        db.people,
      )..where((t) => t.deletedAt.isNull())).get();

      for (final person in people) {
        final name = person.name.toLowerCase();
        final address = (person.address ?? '').toLowerCase();
        final notes = (person.generalNotes ?? '').toLowerCase();

        if (name.contains(clean) ||
            address.contains(clean) ||
            notes.contains(clean)) {
          results.add(
            LocalSearchResult(
              id: person.id,
              type: LocalResultType.contact,
              title: person.name,
              subtitle: (person.address != null && person.address!.isNotEmpty)
                  ? person.address
                  : 'Contato no território',
              latitude: person.latitude,
              longitude: person.longitude,
              metadata: {'status': person.status, 'phone': person.phone},
            ),
          );
        }
      }

      // 2. Busca em Marcos Territoriais (TerritoryLandmarks - POIs)
      final landmarks = await (db.select(
        db.territoryLandmarks,
      )..where((t) => t.deletedAt.isNull())).get();

      for (final lm in landmarks) {
        final name = lm.name.toLowerCase();
        final address = (lm.address ?? '').toLowerCase();
        final category = lm.category.toLowerCase();
        final notes = (lm.notes ?? '').toLowerCase();

        if (name.contains(clean) ||
            address.contains(clean) ||
            category.contains(clean) ||
            notes.contains(clean)) {
          results.add(
            LocalSearchResult(
              id: lm.id,
              type: LocalResultType.landmark,
              title: lm.name,
              subtitle: (lm.address != null && lm.address!.isNotEmpty)
                  ? '${lm.category.toUpperCase()} • ${lm.address}'
                  : lm.category.toUpperCase(),
              latitude: lm.latitude,
              longitude: lm.longitude,
              metadata: {'category': lm.category, 'notes': lm.notes},
            ),
          );
        }
      }

      // 3. Busca em Setores Territoriais (TerritorySectors)
      final sectors = await (db.select(
        db.territorySectors,
      )..where((t) => t.deletedAt.isNull())).get();

      for (final sec in sectors) {
        final name = sec.name.toLowerCase();
        final desc = (sec.description ?? '').toLowerCase();

        if (name.contains(clean) || desc.contains(clean)) {
          results.add(
            LocalSearchResult(
              id: sec.id,
              type: LocalResultType.sector,
              title: sec.name,
              subtitle: (sec.description != null && sec.description!.isNotEmpty)
                  ? sec.description
                  : 'Setor de território',
              metadata: {'description': sec.description ?? ''},
            ),
          );
        }
      }
    } catch (e, st) {
      AppLogger.warning('Erro ao executar busca local offline', e, st);
    }

    return results;
  }

  /// Limpa entradas de cache expiradas (> 30 dias) do banco de dados SQLite Drift.
  static Future<int> pruneExpiredCache({required AppDatabase? db}) async {
    if (db == null) return 0;
    try {
      final rows = await (db.select(
        db.appKvStore,
      )..where((t) => t.key.like('nominatim_%'))).get();

      var pruned = 0;
      final now = DateTime.now().toUtc();

      for (final row in rows) {
        try {
          final payload = jsonDecode(row.value) as Map<String, dynamic>;
          final cachedAtStr = payload['cachedAt'] as String?;
          if (cachedAtStr != null) {
            final cachedAt = DateTime.parse(cachedAtStr);
            if (now.difference(cachedAt) > cacheTtl) {
              await (db.delete(
                db.appKvStore,
              )..where((t) => t.key.equals(row.key))).go();
              pruned++;
            }
          }
        } catch (_) {}
      }

      AppLogger.info(
        'OfflineGeocodingService: $pruned entradas expiradas removidas do cache.',
      );
      return pruned;
    } catch (e, st) {
      AppLogger.warning(
        'Erro ao podar cache expirado de geocodificação',
        e,
        st,
      );
      return 0;
    }
  }
}

class _CachedEntry {
  final ReverseGeocodingResult result;
  final DateTime cachedAt;

  const _CachedEntry(this.result, this.cachedAt);

  bool isExpired(Duration ttl) {
    return DateTime.now().toUtc().difference(cachedAt.toUtc()) > ttl;
  }
}
