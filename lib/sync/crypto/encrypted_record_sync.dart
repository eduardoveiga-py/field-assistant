import 'package:cryptography/cryptography.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'encrypted_record.dart';

/// Infraestrutura experimental: não integrada à fila nem habilitada no app.
class EncryptedRemoteRecord {
  final String route;
  final int revision;
  final Map<String, dynamic> envelope;
  const EncryptedRemoteRecord({required this.route, required this.revision, required this.envelope});
}

class EncryptedWriteResult {
  final bool success;
  final int? revision;
  const EncryptedWriteResult({required this.success, required this.revision});
}

abstract class EncryptedRecordTransport {
  Future<EncryptedRemoteRecord?> fetch(String route);
  Future<EncryptedWriteResult> compareAndSwap({
    required String route,
    required int expectedRevision,
    required Map<String, dynamic> envelope,
  });
}

/// Adaptador de produção para transporte de registros cifrados. Não enviar dados em claro por este canal.
/// Uma conta diferente da conta para a qual o adaptador foi criado falha fechada.
class SupabaseEncryptedRecordTransport implements EncryptedRecordTransport {
  final SupabaseClient client;
  final String owner;
  SupabaseEncryptedRecordTransport({required this.client, required this.owner});

  void _checkOwner() {
    if (owner.isEmpty || client.auth.currentUser?.id != owner) {
      throw StateError('A conta autenticada não corresponde ao cofre.');
    }
  }

  @override
  Future<EncryptedRemoteRecord?> fetch(String route) async {
    _checkOwner();
    try {
      final row = await client.from('encrypted_records')
          .select('route,revision,envelope').eq('owner_id', owner).eq('route', route).maybeSingle();
      if (row != null) {
        if (row['route'] is! String || row['revision'] is! int || row['envelope'] is! Map) {
          throw const FormatException('Registro remoto inválido.');
        }
        return EncryptedRemoteRecord(route: row['route'] as String, revision: row['revision'] as int,
            envelope: Map<String, dynamic>.from(row['envelope'] as Map));
      }
    } catch (_) {
      // Fallback para tabela com prefixo experimental
    }

    final row = await client.from('experimental_encrypted_records')
        .select('route,revision,envelope').eq('owner_id', owner).eq('route', route).maybeSingle();
    if (row == null) return null;
    if (row['route'] is! String || row['revision'] is! int || row['envelope'] is! Map) {
      throw const FormatException('Registro remoto inválido.');
    }
    return EncryptedRemoteRecord(route: row['route'] as String, revision: row['revision'] as int,
        envelope: Map<String, dynamic>.from(row['envelope'] as Map));
  }

  @override
  Future<EncryptedWriteResult> compareAndSwap({required String route, required int expectedRevision,
      required Map<String, dynamic> envelope}) async {
    _checkOwner();
    try {
      final response = await client.rpc('encrypted_record_cas', params: {
        'p_route': route, 'p_expected_revision': expectedRevision, 'p_envelope': envelope,
      });
      if (response is Map && response['success'] is bool) {
        return EncryptedWriteResult(success: response['success'] as bool, revision: response['revision'] as int?);
      }
    } catch (_) {
      // Fallback para RPC com prefixo experimental
    }

    final response = await client.rpc('experimental_encrypted_record_cas', params: {
      'p_route': route, 'p_expected_revision': expectedRevision, 'p_envelope': envelope,
    });
    if (response is! Map || response['success'] is! bool ||
        (response['revision'] != null && response['revision'] is! int) ||
        (response['success'] == false && response['conflict'] != true)) {
      throw const FormatException('Resposta de gravação cifrada inválida.');
    }
    return EncryptedWriteResult(success: response['success'] as bool, revision: response['revision'] as int?);
  }
}

/// Operações de registro para um cofre experimental. O chamador precisa gravar
/// checkpoints e dados locais na mesma transação. Um servidor pode omitir dados
/// ou devolver um estado antigo; [minimumRevision] só protege quando vem de
/// estado local confiável. Um aparelho novo ainda não detecta replay integral.
class EncryptedRecordSync {
  final String owner;
  final SecretKey key;
  final EncryptedRecordTransport transport;
  const EncryptedRecordSync({required this.owner, required this.key, required this.transport});

  static const int _maxRevision = 9007199254740991;

  Future<Map<String, dynamic>?> read({required String entityType, required String entityId,
      int minimumRevision = 0}) async {
    if (minimumRevision < 0 || minimumRevision > _maxRevision) {
      throw ArgumentError.value(minimumRevision, 'minimumRevision');
    }
    final route = await EncryptedRecord.route(key: key, owner: owner, entityType: entityType, entityId: entityId);
    final record = await transport.fetch(route);
    if (record == null) {
      if (minimumRevision > 0) throw StateError('Registro conhecido ausente; possível perda ou replay.');
      return null;
    }
    if (record.route != route || record.revision < 1 || record.revision < minimumRevision || record.revision > _maxRevision) {
      throw StateError('Rota ou revisão remota inválida; dados locais preservados.');
    }
    final payload = await EncryptedRecord.open(key: key, owner: owner, routeId: route,
        revision: record.revision, envelope: record.envelope);
    if (payload['entityType'] != entityType || payload['entityId'] != entityId) {
      throw const FormatException('Identidade do registro não confere.');
    }
    return {'revision': record.revision, 'data': payload['data']};
  }

  /// A revisão esperada deve vir do estado anteriormente verificado, não de
  /// um novo GET seguido de sobrescrita. Não retenta conflito automaticamente.
  Future<EncryptedWriteResult> write({required String entityType, required String entityId,
      required int expectedRevision, required Map<String, dynamic> data}) async {
    if (expectedRevision < 0 || expectedRevision >= _maxRevision) {
      throw ArgumentError.value(expectedRevision, 'expectedRevision');
    }
    final sealed = await EncryptedRecord.seal(key: key, owner: owner, entityType: entityType,
      entityId: entityId, revision: expectedRevision + 1, data: data);
    final result = await transport.compareAndSwap(route: sealed['route'] as String,
      expectedRevision: expectedRevision, envelope: Map<String, dynamic>.from(sealed['envelope'] as Map));
    if ((result.success && result.revision != expectedRevision + 1) ||
        (result.revision != null && (result.revision! < 1 || result.revision! > _maxRevision))) {
      throw const FormatException('Revisão retornada pelo servidor inválida.');
    }
    return result;
  }
}
