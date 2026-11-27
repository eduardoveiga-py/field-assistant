import 'dart:convert';

import 'package:crypto/crypto.dart' as digest;
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';

import '../core/sync_timestamp.dart';
import '../database/app_database.dart';
import '../database/repository.dart';
import 'crypto/encrypted_record.dart';

/// Varre registros locais pré-existentes nas tabelas sincronizáveis e enfileira
/// com segurança apenas aqueles que ainda não possuem checkpoint E2EE nem operação
/// pendente na `sync_queue` para a conta autenticada (`ownerId`).
class E2eeLocalBackfill {
  E2eeLocalBackfill._();

  static String doneFlagKey(String ownerId) =>
      'e2ee_initial_backfill_done_v1_${ownerId.trim()}';

  static String _checkpointKey(String owner, String route) =>
      'e2ee_checkpoint_v1_${digest.sha256.convert(utf8.encode(jsonEncode([owner, route])))}';

  static Future<bool> isInitialBackfillDone(
    AppDatabase db,
    String ownerId,
  ) async {
    final cleanOwner = ownerId.trim();
    if (cleanOwner.isEmpty) return false;
    final row = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.equals(doneFlagKey(cleanOwner)))).getSingleOrNull();
    return row?.value == 'true';
  }

  static Future<void> markInitialBackfillDone(
    AppDatabase db,
    String ownerId,
  ) async {
    final cleanOwner = ownerId.trim();
    if (cleanOwner.isEmpty) return;
    await db
        .into(db.appKvStore)
        .insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: doneFlagKey(cleanOwner),
            value: 'true',
            updatedAt: drift.Value(DateTime.now().toUtc()),
          ),
        );
  }

  /// Limpa a marcação para forçar uma nova verificação completa sob demanda.
  static Future<void> resetInitialBackfillFlag(
    AppDatabase db,
    String ownerId,
  ) async {
    final cleanOwner = ownerId.trim();
    if (cleanOwner.isEmpty) return;
    await (db.delete(
      db.appKvStore,
    )..where((t) => t.key.equals(doneFlagKey(cleanOwner)))).go();
  }

  /// Enfileira registros ativos sem checkpoint E2EE nem pendência ativa.
  /// Respeita estritamente a ordem pai-antes-de-filho de [syncTables].
  static Future<int> enqueueMissingRecords({
    required AppDatabase db,
    required AppRepository repository,
    required String ownerId,
    required SecretKey key,
    required List<String> syncTables,
    required String Function(String entityType) mapEntityToRemoteTable,
    required Future<Map<String, dynamic>?> Function(String table, String id)
    loadLocalRow,
    bool force = false,
  }) async {
    final cleanOwner = ownerId.trim();
    if (cleanOwner.isEmpty) return 0;

    if (!force && await isInitialBackfillDone(db, cleanOwner)) {
      return 0;
    }

    final checkpointRows = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.like('e2ee_checkpoint_v1_%'))).get();
    final knownCheckpointKeys = checkpointRows.map((r) => r.key).toSet();

    final unresolvedOps = await repository.getUnresolvedSyncOperations();
    final unresolvedKeys = <String>{
      for (final op in unresolvedOps)
        '${mapEntityToRemoteTable(op.entityType)}|${op.entityId}',
    };

    const uuid = Uuid();
    var enqueued = 0;
    var inspected = 0;
    final toInsert = <SyncQueueCompanion>[];
    final now = DateTime.now().toUtc();

    for (final table in syncTables) {
      final exists = await db
          .customSelect(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
            variables: [drift.Variable.withString(table)],
          )
          .get();
      if (exists.isEmpty) continue;

      final colsResult = await db
          .customSelect('PRAGMA table_info($table)')
          .get();
      final colNames = colsResult.map((c) => c.read<String>('name')).toSet();
      if (!colNames.contains('id')) continue;

      final querySql = colNames.contains('deleted_at')
          ? 'SELECT id FROM $table WHERE deleted_at IS NULL'
          : 'SELECT id FROM $table';
      final idRows = await db.customSelect(querySql).get();

      for (final row in idRows) {
        final id = row.read<String>('id').trim();
        if (id.isEmpty) continue;

        final queueKey = '$table|$id';
        if (unresolvedKeys.contains(queueKey)) continue;

        final route = await EncryptedRecord.route(
          key: key,
          owner: cleanOwner,
          entityType: table,
          entityId: id,
        );
        final cpKey = _checkpointKey(cleanOwner, route);
        if (knownCheckpointKeys.contains(cpKey)) continue;

        final localMap = await loadLocalRow(table, id);
        if (localMap == null) continue;

        final normalized = SyncTimestamp.normalizeMapDates(localMap);
        normalized['id'] = id;
        toInsert.add(
          SyncQueueCompanion.insert(
            id: uuid.v4(),
            entityType: table,
            entityId: id,
            operation: 'INSERT',
            payload: jsonEncode(normalized),
            createdAt: now,
          ),
        );
        unresolvedKeys.add(queueKey);
        enqueued++;

        inspected++;
        if (kIsWeb && inspected % 40 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }
    }

    if (toInsert.isNotEmpty) {
      await db.transaction(() async {
        for (final entry in toInsert) {
          await db.into(db.syncQueue).insert(entry);
        }
      });
    }

    await markInitialBackfillDone(db, cleanOwner);
    return enqueued;
  }
}
