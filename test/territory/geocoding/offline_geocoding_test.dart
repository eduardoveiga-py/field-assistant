import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/territory/geocoding/offline_geocoding_service.dart';
import 'package:ministerio_pessoal/territory/geocoding_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    OfflineGeocodingService.clearMemoryCache();
  });

  tearDown(() async {
    await db.close();
  });

  group('OfflineGeocodingService Reverse & Direct Geocoding Tests', () {
    test('Caches reverse geocoding result in AppKvStore with TTL', () async {
      var httpCalls = 0;
      final mockClient = MockClient((request) async {
        httpCalls++;
        final jsonResponse = {
          'display_name': 'Rua das Flores, 100, São Paulo, SP',
          'address': {
            'road': 'Rua das Flores',
            'house_number': '100',
            'suburb': 'Centro',
            'city': 'São Paulo',
            'state': 'São Paulo',
          },
        };
        return http.Response(
          jsonEncode(jsonResponse),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      // 1ª chamada: vai na rede
      final res1 = await OfflineGeocodingService.reverseGeocode(
        -23.5505,
        -46.6333,
        db: db,
        httpClient: mockClient,
      );

      expect(res1, isNotNull);
      expect(res1!.street, equals('Rua das Flores'));
      expect(res1.houseNumber, equals('100'));
      expect(httpCalls, equals(1));

      // Limpa cache em memória para forçar leitura do SQLite (AppKvStore)
      OfflineGeocodingService.clearMemoryCache();

      // 2ª chamada: deve vir do cache SQLite sem chamar a rede
      final res2 = await OfflineGeocodingService.reverseGeocode(
        -23.5505,
        -46.6333,
        db: db,
        httpClient: mockClient,
      );

      expect(res2, isNotNull);
      expect(res2!.street, equals('Rua das Flores'));
      expect(httpCalls, equals(1)); // HTTP não foi chamado de novo!
    });

    test('30-day TTL expiration and cache pruning', () async {
      // Injeta entrada no AppKvStore com data de 35 dias atrás
      final expiredDate = DateTime.now().toUtc().subtract(
        const Duration(days: 35),
      );
      final cacheKey = 'nominatim_rev_-23.55050_-46.63330';
      final payload = jsonEncode({
        'cachedAt': expiredDate.toIso8601String(),
        'data': {
          'latitude': -23.5505,
          'longitude': -46.6333,
          'street': 'Rua Antiga Expirada',
        },
      });

      await db
          .into(db.appKvStore)
          .insert(
            AppKvStoreCompanion.insert(
              key: cacheKey,
              value: payload,
              updatedAt: Value(expiredDate),
            ),
          );

      // Poda entradas expiradas (> 30 dias)
      final pruned = await OfflineGeocodingService.pruneExpiredCache(db: db);
      expect(pruned, equals(1));

      final remaining = await (db.select(
        db.appKvStore,
      )..where((t) => t.key.equals(cacheKey))).getSingleOrNull();
      expect(remaining, isNull);
    });

    test('Direct address geocoding caches and resolves coordinates', () async {
      var httpCalls = 0;
      final mockClient = MockClient((request) async {
        httpCalls++;
        final jsonResponse = [
          {
            'lat': '-3.10719',
            'lon': '-60.0261',
            'display_name': 'Teatro Amazonas, Manaus - AM',
          },
        ];
        return http.Response(
          jsonEncode(jsonResponse),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final res = await OfflineGeocodingService.geocodeAddress(
        'Teatro Amazonas',
        db: db,
        httpClient: mockClient,
      );

      expect(res, isNotNull);
      expect(res!.latitude, closeTo(-3.10719, 0.0001));
      expect(res.longitude, closeTo(-60.0261, 0.0001));
      expect(res.fullAddress, contains('Teatro Amazonas'));
      expect(httpCalls, equals(1));

      // Segunda chamada usa cache
      OfflineGeocodingService.clearMemoryCache();
      final resCached = await OfflineGeocodingService.geocodeAddress(
        'Teatro Amazonas',
        db: db,
        httpClient: mockClient,
      );
      expect(resCached, isNotNull);
      expect(resCached!.latitude, closeTo(-3.10719, 0.0001));
      expect(httpCalls, equals(1));
    });

    test('GeocodingService delegates to OfflineGeocodingService and persists cleanly in Drift AppKvStore', () async {
      var httpCalls = 0;
      final mockClient = MockClient((request) async {
        httpCalls++;
        return http.Response(
          jsonEncode({
            'display_name': 'Av. Eduardo Ribeiro, 500, Manaus, AM',
            'address': {
              'road': 'Av. Eduardo Ribeiro',
              'house_number': '500',
              'suburb': 'Centro',
              'city': 'Manaus',
              'state': 'Amazonas',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final res1 = await GeocodingService.reverseGeocode(
        -3.13163,
        -60.02305,
        db: db,
        httpClient: mockClient,
      );
      expect(res1, isNotNull);
      expect(res1!.street, equals('Av. Eduardo Ribeiro'));
      expect(httpCalls, equals(1));

      // Clear memory cache and verify SQLite AppKvStore actually persisted the entry
      GeocodingService.clearMemoryCache();
      final res2 = await GeocodingService.reverseGeocode(
        -3.13163,
        -60.02305,
        db: db,
        httpClient: mockClient,
      );
      expect(res2, isNotNull);
      expect(res2!.street, equals('Av. Eduardo Ribeiro'));
      expect(httpCalls, equals(1));
    });

    test('reverseGeocode rejects Nominatim HTTP 200 error payloads and does not cache empty results', () async {
      var httpCalls = 0;
      final mockClient = MockClient((request) async {
        httpCalls++;
        return http.Response(
          jsonEncode({'error': 'Unable to geocode'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final res = await OfflineGeocodingService.reverseGeocode(
        0.0,
        0.0,
        db: db,
        httpClient: mockClient,
      );
      expect(res, isNull);
      expect(httpCalls, equals(1));

      final rows = await db.select(db.appKvStore).get();
      expect(rows, isEmpty);
    });

    test('geocodeAddress parses structured addressdetails fields when returned by Nominatim', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'lat': '-3.1019',
              'lon': '-60.025',
              'display_name': 'Av. Eduardo Ribeiro, 500, Centro, Manaus, AM',
              'address': {
                'road': 'Av. Eduardo Ribeiro',
                'house_number': '500',
                'suburb': 'Centro',
                'city': 'Manaus',
                'state': 'Amazonas',
              },
            },
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final res = await OfflineGeocodingService.geocodeAddress(
        'Av Eduardo Ribeiro 500 Manaus',
        db: db,
        httpClient: mockClient,
      );
      expect(res, isNotNull);
      expect(res!.street, equals('Av. Eduardo Ribeiro'));
      expect(res.houseNumber, equals('500'));
      expect(res.neighborhood, equals('Centro'));
      expect(res.city, equals('Manaus'));
      expect(res.state, equals('Amazonas'));
    });
  });

  group('Offline Local Search Tests (People, Landmarks, Sectors)', () {
    test(
      'Finds contacts, landmarks, and sectors offline without network',
      () async {
        final now = DateTime.now().toUtc();

        // 1. Inserir Contato
        await db
            .into(db.people)
            .insert(
              PeopleCompanion.insert(
                id: 'p-1',
                name: 'Carlos Oliveira',
                address: const Value('Rua das Palmeiras, 450'),
                latitude: const Value(-23.5510),
                longitude: const Value(-46.6340),
                firstContactAt: now,
                createdAt: now,
                updatedAt: now,
              ),
            );

        // 2. Inserir Marco Territorial
        await db
            .into(db.territoryLandmarks)
            .insert(
              TerritoryLandmarksCompanion.insert(
                id: 'lm-1',
                name: 'Hospital Regional',
                category: 'saude',
                address: const Value('Av. Principal, 1000'),
                latitude: const Value(-23.5550),
                longitude: const Value(-46.6380),
                createdAt: now,
                updatedAt: now,
              ),
            );

        // 3. Inserir Setor
        await db
            .into(db.territorySectors)
            .insert(
              TerritorySectorsCompanion.insert(
                id: 'sec-1',
                name: 'Setor 05 - Jardim Alvorada',
                description: const Value('Região residencial com sobrados'),
                createdAt: now,
              ),
            );

        // Busca por nome de contato
        final resContact = await OfflineGeocodingService.searchOffline(
          query: 'Carlos',
          db: db,
        );
        expect(resContact.length, equals(1));
        expect(resContact.first.type, equals(LocalResultType.contact));
        expect(resContact.first.title, equals('Carlos Oliveira'));
        expect(resContact.first.latitude, equals(-23.5510));

        // Busca por rua de contato
        final resStreet = await OfflineGeocodingService.searchOffline(
          query: 'Palmeiras',
          db: db,
        );
        expect(resStreet.length, equals(1));
        expect(resStreet.first.id, equals('p-1'));

        // Busca por marco (POI)
        final resLandmark = await OfflineGeocodingService.searchOffline(
          query: 'Hospital',
          db: db,
        );
        expect(resLandmark.length, equals(1));
        expect(resLandmark.first.type, equals(LocalResultType.landmark));
        expect(resLandmark.first.title, equals('Hospital Regional'));

        // Busca por setor
        final resSector = await OfflineGeocodingService.searchOffline(
          query: 'Alvorada',
          db: db,
        );
        expect(resSector.length, equals(1));
        expect(resSector.first.type, equals(LocalResultType.sector));
        expect(resSector.first.title, contains('Jardim Alvorada'));

        // Busca sem correspondência retorna vazio
        final resEmpty = await OfflineGeocodingService.searchOffline(
          query: 'Inexistente XYZ',
          db: db,
        );
        expect(resEmpty, isEmpty);
      },
    );
  });
}
