import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/core/app_config.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servidor PostgREST e Supabase Storage simulado para todas as 18 tabelas de domínio.
/// Implementa RLS estrito (owner_id = auth.uid()), paginação por range, detecção de
/// tombstones (deleted_at), rejeição de ressurreição stale e simulação de rede.
class MockSupabaseFullDomainServer {
  final Map<String, Map<String, Map<String, dynamic>>> tables = {};
  final Map<String, Map<String, List<int>>> storageBuckets = {};
  bool simulateNetworkDrop = false;
  String? authenticatedOwnerId;

  static const List<String> domainTables = [
    'people',
    'visits',
    'bible_studies',
    'study_participants',
    'study_sessions',
    'appointments',
    'activity_records',
    'voice_notes',
    'phone_contacts',
    'territory_landmarks',
    'family_ties',
    'ministry_experiences',
    'person_photos',
    'person_publications',
    'research_articles',
    'research_tags',
    'territory_sectors',
    'student_manual_order',
  ];

  MockSupabaseFullDomainServer({this.authenticatedOwnerId = 'usr-default-01'}) {
    for (final table in domainTables) {
      tables[table] = {};
    }
    storageBuckets['voice_notes'] = {};
    storageBuckets['person_photos'] = {};
  }

  void seed(String table, Map<String, dynamic> row) {
    final copy = Map<String, dynamic>.from(row);
    if (!copy.containsKey('owner_id') && authenticatedOwnerId != null) {
      copy['owner_id'] = authenticatedOwnerId;
    }
    tables.putIfAbsent(table, () => {})[copy['id'] as String] = copy;
  }

  Map<String, dynamic>? getRow(String table, String id) {
    return tables[table]?[id];
  }

  List<Map<String, dynamic>> getAllRows(String table) {
    return tables[table]?.values.toList() ?? [];
  }

  http.Response _json(
    http.Request request,
    Object body, {
    int status = 200,
    String range = '*/0',
  }) {
    return http.Response(
      jsonEncode(body),
      status,
      request: request,
      headers: {
        'content-type': 'application/json',
        'content-range': range,
      },
    );
  }

  http.Response handleRequest(http.Request request) {
    if (simulateNetworkDrop) {
      throw const SocketException('503 Service Unavailable / Rede inalcançável simulada');
    }

    final path = request.url.path;

    // Supabase Storage endpoints: /storage/v1/object/...
    if (path.startsWith('/storage/v1/object/')) {
      return _handleStorageRequest(request);
    }

    final match = RegExp(r'/rest/v1/([a-z_]+)').firstMatch(path);
    if (match == null) {
      return _json(request, []);
    }
    final table = match.group(1)!;
    final tableMap = tables.putIfAbsent(table, () => {});

    // DELETE físico (deve ser bloqueado ou transformado em tombstone nos clientes de domínio)
    if (request.method == 'DELETE') {
      final idParam = request.url.queryParameters['id'];
      if (idParam != null && idParam.startsWith('eq.')) {
        final id = idParam.substring(3);
        tableMap.remove(id);
      }
      return _json(request, []);
    }

    // PATCH (Tombstone soft-delete ou atualização parcial)
    if (request.method == 'PATCH') {
      final idParam = request.url.queryParameters['id'];
      final id = (idParam != null && idParam.startsWith('eq.'))
          ? idParam.substring(3)
          : null;
      final body = jsonDecode(request.body) as Map<String, dynamic>;

      if (id != null) {
        final existing = tableMap[id] ?? <String, dynamic>{'id': id};
        // RLS check
        if (authenticatedOwnerId != null &&
            existing.containsKey('owner_id') &&
            existing['owner_id'] != authenticatedOwnerId) {
          return http.Response('{"error":"RLS Policy Violation"}', 403, request: request);
        }
        body.forEach((k, v) => existing[k] = v);
        tableMap[id] = existing;
      }
      return _json(request, [body]);
    }

    // POST / Upsert
    if (request.method == 'POST') {
      final body = jsonDecode(request.body);
      final List<Map<String, dynamic>> items = body is List
          ? body.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : [Map<String, dynamic>.from(body as Map)];

      for (final item in items) {
        final id = item['id'] as String?;
        if (id == null) continue;

        // RLS enforcement: auto-inject server authenticated owner_id
        if (authenticatedOwnerId != null) {
          item['owner_id'] = authenticatedOwnerId;
        }

        final existing = tableMap[id];
        if (existing != null) {
          // RLS check em update
          if (authenticatedOwnerId != null &&
              existing['owner_id'] != null &&
              existing['owner_id'] != authenticatedOwnerId) {
            return http.Response('{"error":"RLS Policy Violation"}', 403, request: request);
          }

          final oldDeletedAt = existing['deleted_at'] ?? existing['deletedAt'];
          final newDeletedAt = item['deleted_at'] ?? item['deletedAt'];

          // Proteção contra ressurreição stale (PostgreSQL trigger prevent_stale_resurrection)
          if (oldDeletedAt != null && newDeletedAt == null) {
            final oldRev = (existing['revision'] as int?) ?? 1;
            final newRev = (item['revision'] as int?) ?? 1;
            final oldDel = DateTime.tryParse(oldDeletedAt.toString());
            final newUpdRaw = item['updated_at'] ?? item['updatedAt'];
            final newUpd = newUpdRaw != null
                ? DateTime.tryParse(newUpdRaw.toString())
                : null;

            final isLegitimateRestore =
                newRev > oldRev &&
                newUpd != null &&
                oldDel != null &&
                newUpd.isAfter(oldDel);

            if (!isLegitimateRestore) {
              item['deleted_at'] = oldDeletedAt;
              item['revision'] = oldRev > newRev ? oldRev : newRev;
            }
          }
          item.forEach((k, v) => existing[k] = v);
          tableMap[id] = existing;
        } else {
          tableMap[id] = item;
        }
      }
      return _json(request, items);
    }

    // GET com filtros RLS, cursores e ordenação determinística
    if (request.method == 'GET') {
      var rows = tableMap.values.toList();

      // RLS filtering
      if (authenticatedOwnerId != null) {
        rows = rows.where((r) => r['owner_id'] == null || r['owner_id'] == authenticatedOwnerId).toList();
      }

      final queryParams = request.url.queryParameters;
      final orFilter = queryParams['or'];
      final gteFilter = queryParams['updated_at'];

      if (orFilter != null) {
        final gtMatch = RegExp(r'updated_at\.gt\.([^,]+)').firstMatch(orFilter);
        final eqMatch = RegExp(r'updated_at\.eq\.([^,]+)').firstMatch(orFilter);
        final idGtMatch = RegExp(r'id\.gt\.([^\)]+)').firstMatch(orFilter);

        final gtTime = gtMatch != null
            ? DateTime.tryParse(gtMatch.group(1)!)
            : null;
        final eqTime = eqMatch != null
            ? DateTime.tryParse(eqMatch.group(1)!)
            : null;
        final minId = idGtMatch?.group(1);

        rows = rows.where((row) {
          final upRaw = row['updated_at'] ?? row['updatedAt'];
          final dt = upRaw != null ? DateTime.tryParse(upRaw.toString()) : null;
          if (dt == null) return false;
          final rowId = (row['id'] ?? '').toString();

          if (gtTime != null && dt.isAfter(gtTime)) return true;
          if (eqTime != null && dt.isAtSameMomentAs(eqTime)) {
            if (minId != null) {
              return rowId.compareTo(minId) > 0;
            }
            return true;
          }
          return false;
        }).toList();
      } else if (gteFilter != null) {
        if (gteFilter.startsWith('gte.')) {
          final target = DateTime.tryParse(gteFilter.substring(4));
          if (target != null) {
            rows = rows.where((row) {
              final upRaw = row['updated_at'] ?? row['updatedAt'];
              final dt = upRaw != null
                  ? DateTime.tryParse(upRaw.toString())
                  : null;
              if (dt == null) return false;
              return dt.isAfter(target) || dt.isAtSameMomentAs(target);
            }).toList();
          }
        }
      }

      rows.sort((a, b) {
        final dtA = DateTime.tryParse(
              (a['updated_at'] ?? a['updatedAt'] ?? '').toString(),
            ) ??
            DateTime(1970);
        final dtB = DateTime.tryParse(
              (b['updated_at'] ?? b['updatedAt'] ?? '').toString(),
            ) ??
            DateTime(1970);
        final cmp = dtA.compareTo(dtB);
        if (cmp != 0) return cmp;
        return ((a['id'] ?? '') as String).compareTo(
          (b['id'] ?? '') as String,
        );
      });

      final rangeHeader =
          request.headers['range'] ?? request.headers['Range'] ?? '';
      int from = 0;
      int count = rows.length;
      if (rangeHeader.isNotEmpty) {
        final matchRange = RegExp(r'(\d+)-(\d+)').firstMatch(rangeHeader);
        if (matchRange != null) {
          from = int.parse(matchRange.group(1)!);
          final to = int.parse(matchRange.group(2)!);
          count = to - from + 1;
        }
      }
      final paged = rows.skip(from).take(count).toList();
      final end = paged.isEmpty ? from : from + paged.length - 1;
      return _json(request, paged, range: '$from-$end/${rows.length}');
    }

    return _json(request, []);
  }

  http.Response _handleStorageRequest(http.Request request) {
    // /storage/v1/object/<bucket>/<path...>
    final parts = request.url.path.replaceFirst('/storage/v1/object/', '').split('/');
    if (parts.isEmpty) return http.Response('{"error":"Invalid bucket"}', 400);

    final bucket = parts.first;
    final objectPath = parts.sublist(1).join('/');

    // RLS em Storage: prefixo deve ser <owner_id>/<filename>
    if (authenticatedOwnerId != null && !objectPath.startsWith('$authenticatedOwnerId/')) {
      return http.Response('{"error":"Storage RLS Policy Violation"}', 403, request: request);
    }

    final bucketMap = storageBuckets.putIfAbsent(bucket, () => {});

    if (request.method == 'POST') {
      bucketMap[objectPath] = request.bodyBytes;
      return http.Response('{"Key":"$bucket/$objectPath"}', 200, request: request);
    }

    if (request.method == 'GET') {
      final bytes = bucketMap[objectPath];
      if (bytes == null) {
        return http.Response('{"error":"Object not found"}', 404, request: request);
      }
      return http.Response.bytes(bytes, 200, request: request);
    }

    return http.Response('{"ok":true}', 200, request: request);
  }
}

/// Helper para instanciar instâncias simuladas de dispositivos conectados.
class MultiDeviceSimEnvironment {
  final AppDatabase dbA;
  final AppRepository repoA;
  final Directory tempDirA;

  final AppDatabase dbB;
  final AppRepository repoB;
  final Directory tempDirB;

  final MockSupabaseFullDomainServer server;
  final AppConfig config;

  MultiDeviceSimEnvironment._({
    required this.dbA,
    required this.repoA,
    required this.tempDirA,
    required this.dbB,
    required this.repoB,
    required this.tempDirB,
    required this.server,
    required this.config,
  });

  static Future<MultiDeviceSimEnvironment> create({
    String ownerId = 'usr-household-01',
  }) async {
    final server = MockSupabaseFullDomainServer(authenticatedOwnerId: ownerId);
    final config = AppConfig.create(
      environment: AppEnvironment.development,
      supabaseUrl: 'https://test.supabase.co',
      supabaseAnonKey: 'test-anon-key-p0-e2e',
    );

    final dbA = AppDatabase.forTesting(NativeDatabase.memory());
    final repoA = AppRepository(dbA);
    final tempDirA = await Directory.systemTemp.createTemp('p0_e2e_a_');

    final dbB = AppDatabase.forTesting(NativeDatabase.memory());
    final repoB = AppRepository(dbB);
    final tempDirB = await Directory.systemTemp.createTemp('p0_e2e_b_');

    return MultiDeviceSimEnvironment._(
      dbA: dbA,
      repoA: repoA,
      tempDirA: tempDirA,
      dbB: dbB,
      repoB: repoB,
      tempDirB: tempDirB,
      server: server,
      config: config,
    );
  }

  SupabaseSyncService createServiceA() {
    final client = SupabaseClient(
      'https://test.supabase.co',
      'test-anon-key-p0-e2e',
      httpClient: MockClient((req) async => server.handleRequest(req)),
    );
    return SupabaseSyncService(
      db: dbA,
      repository: repoA,
      config: config,
      clientOverride: client,
      documentsDirectoryProvider: () async => tempDirA.path,
    );
  }

  SupabaseSyncService createServiceB() {
    final client = SupabaseClient(
      'https://test.supabase.co',
      'test-anon-key-p0-e2e',
      httpClient: MockClient((req) async => server.handleRequest(req)),
    );
    return SupabaseSyncService(
      db: dbB,
      repository: repoB,
      config: config,
      clientOverride: client,
      documentsDirectoryProvider: () async => tempDirB.path,
    );
  }

  Future<void> dispose() async {
    await dbA.close();
    await dbB.close();
    if (await tempDirA.exists()) await tempDirA.delete(recursive: true);
    if (await tempDirB.exists()) await tempDirB.delete(recursive: true);
  }
}
