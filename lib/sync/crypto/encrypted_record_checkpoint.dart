import 'dart:convert';

import 'package:crypto/crypto.dart' as digest;
import 'package:drift/drift.dart' as drift;

import '../../database/app_database.dart';
import 'encrypted_record.dart';
import 'encrypted_record_sync.dart';

/// Resultado explícito da aplicação de um registro cifrado remoto.
/// Separa o pulo idempotente (`alreadyApplied`) de uma rejeição/conflito (`rejected`)
/// para que o cursor `server_seq` nunca avance sobre registros não aplicados.
enum EncryptedApplyOutcome { applied, alreadyApplied, rejected }

/// Aplicação transacional de registros cifrados e checkpoints anti-rollback
/// na mesma transação SQLite/Drift (FA-SEC-02).
class EncryptedRecordCheckpoint {
  final AppDatabase db;
  final EncryptedRecordSync sync;
  const EncryptedRecordCheckpoint({required this.db, required this.sync});

  static String _key(String owner, String route) =>
      'e2ee_checkpoint_v1_${digest.sha256.convert(utf8.encode(jsonEncode([owner, route])))}';

  static String _fingerprint(Map<String, dynamic> envelope) => digest.sha256
      .convert(
        utf8.encode(
          jsonEncode([
            envelope['v'],
            envelope['algorithm'],
            envelope['nonce'],
            envelope['ciphertext'],
            envelope['tag'],
          ]),
        ),
      )
      .toString();

  static ({int revision, String digest}) _parseCheckpoint(String raw) {
    final parsed = jsonDecode(raw);
    if (parsed is! Map ||
        parsed.length != 2 ||
        parsed['revision'] is! int ||
        (parsed['revision'] as int) < 1 ||
        (parsed['revision'] as int) > 9007199254740991 ||
        parsed['digest'] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(parsed['digest'] as String)) {
      throw const FormatException('Checkpoint cifrado local inválido.');
    }
    return (
      revision: parsed['revision'] as int,
      digest: parsed['digest'] as String,
    );
  }

  /// Retorna a última revisão criptográfica confirmada localmente para esta entidade (0 se nova).
  Future<int> getKnownRevision({
    required String entityType,
    required String entityId,
  }) async {
    final route = await EncryptedRecord.route(
      key: sync.key,
      owner: sync.owner,
      entityType: entityType,
      entityId: entityId,
    );
    final row = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.equals(_key(sync.owner, route)))).getSingleOrNull();
    if (row == null) return 0;
    return _parseCheckpoint(row.value).revision;
  }

  /// Persiste o checkpoint de um registro recém-enviado com CAS confirmado.
  Future<void> recordPushedEnvelope({
    required String route,
    required int revision,
    required Map<String, dynamic> envelope,
  }) async {
    final checkpointKey = _key(sync.owner, route);
    final fingerprint = _fingerprint(envelope);
    await db
        .into(db.appKvStore)
        .insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: checkpointKey,
            value: jsonEncode({'revision': revision, 'digest': fingerprint}),
            updatedAt: drift.Value(DateTime.now()),
          ),
        );
  }

  /// Aplica um registro cifrado já obtido via `pullSince`, autenticando AAD,
  /// vínculo de rota e monotonicidade na mesma transação Drift.
  Future<EncryptedApplyOutcome> applyRemoteRecord({
    required EncryptedRemoteRecord remote,
    required Future<bool> Function(
      String entityType,
      String entityId,
      Map<String, dynamic> data,
      int revision,
    )
    apply,
  }) async {
    if (remote.revision < 1 || remote.revision > 9007199254740991) {
      throw StateError('Revisão remota inválida; dados locais preservados.');
    }
    final payload = await EncryptedRecord.open(
      key: sync.key,
      owner: sync.owner,
      routeId: remote.route,
      revision: remote.revision,
      envelope: remote.envelope,
    );
    final entityType = payload['entityType'] as String;
    final entityId = payload['entityId'] as String;
    final expectedRoute = await EncryptedRecord.route(
      key: sync.key,
      owner: sync.owner,
      entityType: entityType,
      entityId: entityId,
    );
    if (expectedRoute != remote.route) {
      throw StateError(
        'Rota cifrada não corresponde à entidade decifrada; possível adulteração.',
      );
    }

    return db.transaction(() async {
      final checkpointKey = _key(sync.owner, remote.route);
      final row = await (db.select(
        db.appKvStore,
      )..where((t) => t.key.equals(checkpointKey))).getSingleOrNull();
      var knownRevision = 0;
      String? knownDigest;
      if (row != null) {
        final parsed = _parseCheckpoint(row.value);
        knownRevision = parsed.revision;
        knownDigest = parsed.digest;
      }
      if (remote.revision < knownRevision) {
        throw StateError(
          'Rollback de revisão remota detectado (${remote.revision} < $knownRevision); dados locais preservados.',
        );
      }
      final fingerprint = _fingerprint(remote.envelope);
      if (remote.revision == knownRevision && fingerprint != knownDigest) {
        throw StateError(
          'Conteúdo mudou sem nova revisão; dados locais preservados.',
        );
      }
      if (remote.revision == knownRevision) {
        return EncryptedApplyOutcome.alreadyApplied;
      }

      final applied = await apply(
        entityType,
        entityId,
        Map<String, dynamic>.from(payload['data'] as Map),
        remote.revision,
      );
      if (!applied) return EncryptedApplyOutcome.rejected;

      await db
          .into(db.appKvStore)
          .insertOnConflictUpdate(
            AppKvStoreCompanion.insert(
              key: checkpointKey,
              value: jsonEncode({
                'revision': remote.revision,
                'digest': fingerprint,
              }),
              updatedAt: drift.Value(DateTime.now()),
            ),
          );
      return EncryptedApplyOutcome.applied;
    });
  }

  /// Retorna true se o registro foi aplicado, false se já estava aplicado ou
  /// se não há registro e nunca houve checkpoint. Exceções revertem tanto a
  /// aplicação quanto o checkpoint. Não executa exclusões em resposta a ausência.
  Future<bool> pullAndApply({
    required String entityType,
    required String entityId,
    required Future<void> Function(Map<String, dynamic> data, int revision)
    apply,
  }) async {
    final route = await EncryptedRecord.route(
      key: sync.key,
      owner: sync.owner,
      entityType: entityType,
      entityId: entityId,
    );
    final remote = await sync.transport.fetch(route);
    return db.transaction(() async {
      final checkpointKey = _key(sync.owner, route);
      final row = await (db.select(
        db.appKvStore,
      )..where((t) => t.key.equals(checkpointKey))).getSingleOrNull();
      int knownRevision = 0;
      String? knownDigest;
      if (row != null) {
        final parsed = _parseCheckpoint(row.value);
        knownRevision = parsed.revision;
        knownDigest = parsed.digest;
      }
      if (remote == null) {
        if (knownRevision > 0) {
          throw StateError(
            'Registro conhecido ausente; dados locais preservados.',
          );
        }
        return false;
      }
      if (remote.route != route ||
          remote.revision < 1 ||
          remote.revision < knownRevision ||
          remote.revision > 9007199254740991) {
        throw StateError('Rota ou revisão inválida; dados locais preservados.');
      }
      final fingerprint = _fingerprint(remote.envelope);
      if (remote.revision == knownRevision && fingerprint != knownDigest) {
        throw StateError(
          'Conteúdo mudou sem nova revisão; dados locais preservados.',
        );
      }
      // Sempre autenticar, inclusive em uma repetição de revisão já aplicada.
      final payload = await EncryptedRecord.open(
        key: sync.key,
        owner: sync.owner,
        routeId: route,
        revision: remote.revision,
        envelope: remote.envelope,
      );
      if (payload['entityType'] != entityType ||
          payload['entityId'] != entityId) {
        throw const FormatException('Identidade do registro não confere.');
      }
      if (remote.revision == knownRevision) return false;
      await apply(
        Map<String, dynamic>.from(payload['data'] as Map),
        remote.revision,
      );
      await db
          .into(db.appKvStore)
          .insertOnConflictUpdate(
            AppKvStoreCompanion.insert(
              key: checkpointKey,
              value: jsonEncode({
                'revision': remote.revision,
                'digest': fingerprint,
              }),
              updatedAt: drift.Value(DateTime.now()),
            ),
          );
      return true;
    });
  }
}
