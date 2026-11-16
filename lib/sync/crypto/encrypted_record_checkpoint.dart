import 'dart:convert';

import 'package:crypto/crypto.dart' as digest;
import 'package:drift/drift.dart' as drift;

import '../../database/app_database.dart';
import 'encrypted_record.dart';
import 'encrypted_record_sync.dart';

/// Aplicação experimental de um registro e seu checkpoint na mesma transação.
/// O callback deve gravar usando [db], nunca em outro banco nem em arquivos.
/// Não está ligado à fila de sincronização. Checkpoints locais podem ser
/// revertidos por restauração de backup ou exclusão dos dados do aplicativo.
class EncryptedRecordCheckpoint {
  final AppDatabase db;
  final EncryptedRecordSync sync;
  const EncryptedRecordCheckpoint({required this.db, required this.sync});

  static String _key(String owner, String route) => 'e2ee_checkpoint_v1_${digest.sha256.convert(
      utf8.encode(jsonEncode([owner, route])))}';

  static String _fingerprint(Map<String, dynamic> envelope) => digest.sha256.convert(utf8.encode(jsonEncode([
    envelope['v'], envelope['algorithm'], envelope['nonce'], envelope['ciphertext'], envelope['tag'],
  ]))).toString();

  /// Retorna true se o registro foi aplicado, false se já estava aplicado ou
  /// se não há registro e nunca houve checkpoint. Exceções revertem tanto a
  /// aplicação quanto o checkpoint. Não executa exclusões em resposta a ausência.
  Future<bool> pullAndApply({
    required String entityType,
    required String entityId,
    required Future<void> Function(Map<String, dynamic> data, int revision) apply,
  }) async {
    final route = await EncryptedRecord.route(key: sync.key, owner: sync.owner,
        entityType: entityType, entityId: entityId);
    final remote = await sync.transport.fetch(route);
    return db.transaction(() async {
      final checkpointKey = _key(sync.owner, route);
      final row = await (db.select(db.appKvStore)..where((t) => t.key.equals(checkpointKey))).getSingleOrNull();
      int knownRevision = 0;
      String? knownDigest;
      if (row != null) {
        final parsed = jsonDecode(row.value);
        if (parsed is! Map || parsed.length != 2 || parsed['revision'] is! int ||
            (parsed['revision'] as int) < 1 || (parsed['revision'] as int) > 9007199254740991 ||
            parsed['digest'] is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(parsed['digest'] as String)) {
          throw const FormatException('Checkpoint cifrado local inválido.');
        }
        knownRevision = parsed['revision'] as int;
        knownDigest = parsed['digest'] as String;
      }
      if (remote == null) {
        if (knownRevision > 0) throw StateError('Registro conhecido ausente; dados locais preservados.');
        return false;
      }
      if (remote.route != route || remote.revision < 1 || remote.revision < knownRevision ||
          remote.revision > 9007199254740991) {
        throw StateError('Rota ou revisão inválida; dados locais preservados.');
      }
      final fingerprint = _fingerprint(remote.envelope);
      if (remote.revision == knownRevision && fingerprint != knownDigest) {
        throw StateError('Conteúdo mudou sem nova revisão; dados locais preservados.');
      }
      // Sempre autenticar, inclusive em uma repetição de revisão já aplicada.
      final payload = await EncryptedRecord.open(key: sync.key, owner: sync.owner,
          routeId: route, revision: remote.revision, envelope: remote.envelope);
      if (payload['entityType'] != entityType || payload['entityId'] != entityId) {
        throw const FormatException('Identidade do registro não confere.');
      }
      if (remote.revision == knownRevision) return false;
      await apply(Map<String, dynamic>.from(payload['data'] as Map), remote.revision);
      await db.into(db.appKvStore).insertOnConflictUpdate(AppKvStoreCompanion.insert(
        key: checkpointKey,
        value: jsonEncode({'revision': remote.revision, 'digest': fingerprint}),
        updatedAt: drift.Value(DateTime.now()),
      ));
      return true;
    });
  }
}
