import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';
import 'base_repository.dart';

/// Domínio responsável pelo gerenciamento da fila de sincronização (Outbox / sync_queue).
mixin SyncQueueDomainMixin on BaseRepository {
  @override
  Future<void> recordSyncOperation({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
    Map<String, dynamic>? baseData,
  }) async {
    final finalPayload = Map<String, dynamic>.from(payload);
    if (baseData != null) {
      finalPayload['_base'] = baseData;
    }
    await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: uuid.v4(),
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            payload: jsonEncode(finalPayload),
            createdAt: DateTime.now(),
            status: const Value('pending'),
          ),
        );
  }

  Future<List<SyncQueueEntry>> getPendingSyncOperations() {
    return (db.select(db.syncQueue)
          ..where(
            (tbl) =>
                tbl.status.equals('pending') |
                tbl.status.equals('in_progress') |
                (tbl.status.equals('failed') &
                    tbl.attempts.isSmallerThanValue(5)),
          )
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc),
          ]))
        .get();
  }

  Future<void> markSyncOperationSuccess(String id) async {
    await (db.update(db.syncQueue)..where((tbl) => tbl.id.equals(id))).write(
      const SyncQueueCompanion(status: Value('synced')),
    );
  }

  Future<void> markSyncOperationFailed(String id, String error) async {
    final op = await (db.select(
      db.syncQueue,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (op != null) {
      await (db.update(db.syncQueue)..where((tbl) => tbl.id.equals(id))).write(
        SyncQueueCompanion(
          status: const Value('failed'),
          attempts: Value(op.attempts + 1),
          lastError: Value(error),
        ),
      );
    }
  }

  /// Recupera com segurança operações da outbox com falha (attempts >= 5),
  /// redefinindo seu status para 'pending' e ajustando tentativas para o menor entre tentativas atuais e 4
  /// para permitir mais um ciclo supervisionado de tentativas, sem descartar
  /// registros da outbox e preservando o histórico do erro prévio.
  Future<int> requeueFailedSyncOperations({List<String>? operationIds}) async {
    if (operationIds != null && operationIds.isEmpty) {
      return 0;
    }

    return await db.transaction(() async {
      final query = db.select(db.syncQueue)
        ..where((tbl) {
          final isFailed = tbl.status.equals('failed');
          if (operationIds != null && operationIds.isNotEmpty) {
            return isFailed & tbl.id.isIn(operationIds);
          }
          return isFailed & tbl.attempts.isBiggerOrEqualValue(5);
        });
      final failedOps = await query.get();
      int count = 0;
      for (final op in failedOps) {
        final newAttempts = op.attempts < 4 ? op.attempts : 4;
        await (db.update(
          db.syncQueue,
        )..where((tbl) => tbl.id.equals(op.id))).write(
          SyncQueueCompanion(
            status: const Value('pending'),
            attempts: Value(newAttempts),
            lastError: Value(
              'Reenfileirado para sincronizacao. Erro previo: ${op.lastError ?? "nenhum"}',
            ),
          ),
        );
        count++;
      }
      return count;
    });
  }
}
