import 'package:cryptography/cryptography.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'encrypted_record.dart';

class EncryptedRemoteRecord {
  final String route;
  final int revision;
  final int serverSeq;
  final Map<String, dynamic> envelope;

  const EncryptedRemoteRecord({
    required this.route,
    required this.revision,
    required this.envelope,
    this.serverSeq = 0,
  });
}

class EncryptedWriteResult {
  final bool success;
  final int? revision;
  final int? serverSeq;

  const EncryptedWriteResult({
    required this.success,
    required this.revision,
    this.serverSeq,
  });
}

abstract class EncryptedRecordTransport {
  Future<EncryptedRemoteRecord?> fetch(String route);
  Future<EncryptedWriteResult> compareAndSwap({
    required String route,
    required int expectedRevision,
    required Map<String, dynamic> envelope,
  });
}

/// Extensão paginada por cursor monotônico `server_seq` (FA-SEC-02).
abstract class PaginatedEncryptedRecordTransport
    implements EncryptedRecordTransport {
  Future<List<EncryptedRemoteRecord>> pullSince({
    required int sinceSeq,
    int limit = 100,
  });
}

/// Extensão para reconciliação histórica E2EE via watermark e scan por colação binária C (FA-SEC-09).
abstract class ReconcilableEncryptedRecordTransport
    implements PaginatedEncryptedRecordTransport {
  Future<int> reconcileStart();
  Future<List<EncryptedRemoteRecord>> scanPage({
    String? afterRoute,
    int limit = 100,
  });
}

/// Adaptador de produção para transporte de registros cifrados (`encrypted_records`).
/// Não envia dados em claro nem recorre silenciosamente a tabelas experimentais.
/// Uma conta diferente da conta para a qual o adaptador foi criado falha fechada.
class SupabaseEncryptedRecordTransport
    implements ReconcilableEncryptedRecordTransport {
  final SupabaseClient client;
  final String owner;

  SupabaseEncryptedRecordTransport({required this.client, required this.owner});

  void _checkOwner() {
    if (owner.isEmpty || client.auth.currentUser?.id != owner) {
      throw StateError('A conta autenticada não corresponde ao cofre.');
    }
  }

  EncryptedRemoteRecord _parseRow(Map<dynamic, dynamic> row) {
    final route = row['route'];
    final revision = row['revision'];
    final envelope = row['envelope'];
    final rawSeq = row['server_seq'];
    if (route is! String || revision is! int || envelope is! Map) {
      throw const FormatException('Registro remoto cifrado inválido.');
    }
    final serverSeq = rawSeq is int
        ? rawSeq
        : (rawSeq is num ? rawSeq.toInt() : 0);
    return EncryptedRemoteRecord(
      route: route,
      revision: revision,
      serverSeq: serverSeq,
      envelope: Map<String, dynamic>.from(envelope),
    );
  }

  @override
  Future<EncryptedRemoteRecord?> fetch(String route) async {
    _checkOwner();
    final row = await client
        .from('encrypted_records')
        .select('route,revision,server_seq,envelope')
        .eq('owner_id', owner)
        .eq('route', route)
        .maybeSingle();
    if (row == null) return null;
    return _parseRow(row);
  }

  @override
  Future<EncryptedWriteResult> compareAndSwap({
    required String route,
    required int expectedRevision,
    required Map<String, dynamic> envelope,
  }) async {
    _checkOwner();
    final response = await client.rpc(
      'encrypted_record_cas',
      params: {
        'p_route': route,
        'p_expected_revision': expectedRevision,
        'p_envelope': envelope,
      },
    );
    if (response is! Map ||
        response['success'] is! bool ||
        (response['revision'] != null && response['revision'] is! int) ||
        (response['success'] == false && response['conflict'] != true)) {
      throw const FormatException('Resposta de gravação cifrada inválida.');
    }
    final rawSeq = response['server_seq'];
    return EncryptedWriteResult(
      success: response['success'] as bool,
      revision: response['revision'] as int?,
      serverSeq: rawSeq is int
          ? rawSeq
          : (rawSeq is num ? rawSeq.toInt() : null),
    );
  }

  @override
  Future<List<EncryptedRemoteRecord>> pullSince({
    required int sinceSeq,
    int limit = 100,
  }) async {
    _checkOwner();
    if (sinceSeq < 0) {
      throw ArgumentError.value(sinceSeq, 'sinceSeq', 'Cursor negativo.');
    }
    final response = await client.rpc(
      'encrypted_records_pull_since',
      params: {'p_since_seq': sinceSeq, 'p_limit': limit},
    );
    if (response is! List) {
      throw const FormatException('Resposta de pull cifrado inválida.');
    }
    return [
      for (final item in response)
        if (item is Map)
          _parseRow(item)
        else
          throw const FormatException('Item de pull cifrado inválido.'),
    ];
  }

  static final RegExp _hexRoutePattern = RegExp(r'^[0-9a-f]{64}$');

  @override
  Future<int> reconcileStart() async {
    _checkOwner();
    final response = await client.rpc('encrypted_records_reconcile_start');
    if (response is int) return response;
    if (response is num) return response.toInt();
    if (response is String) {
      final parsed = int.tryParse(response);
      if (parsed != null) return parsed;
    }
    throw const FormatException(
      'Resposta de reconciliação de watermark inválida.',
    );
  }

  @override
  Future<List<EncryptedRemoteRecord>> scanPage({
    String? afterRoute,
    int limit = 100,
  }) async {
    _checkOwner();
    if (afterRoute != null && !_hexRoutePattern.hasMatch(afterRoute)) {
      throw ArgumentError.value(
        afterRoute,
        'afterRoute',
        'Rota hexadecimal inválida.',
      );
    }
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'Limite deve ser positivo.');
    }
    final clampedLimit = limit > 500 ? 500 : limit;
    final response = await client.rpc(
      'encrypted_records_scan_page',
      params: {
        'p_after_route': afterRoute,
        'p_limit': clampedLimit,
      },
    );
    if (response is! List) {
      throw const FormatException(
        'Resposta de scan de registros cifrados inválida.',
      );
    }
    return [
      for (final item in response)
        if (item is Map)
          _parseRow(item)
        else
          throw const FormatException('Item de scan cifrado inválido.'),
    ];
  }
}

/// Operações criptográficas de leitura e escrita CAS para registros sincronizados.
class EncryptedRecordSync {
  final String owner;
  final SecretKey key;
  final EncryptedRecordTransport transport;

  const EncryptedRecordSync({
    required this.owner,
    required this.key,
    required this.transport,
  });

  static const int _maxRevision = 9007199254740991;

  Future<Map<String, dynamic>?> read({
    required String entityType,
    required String entityId,
    int minimumRevision = 0,
  }) async {
    if (minimumRevision < 0 || minimumRevision > _maxRevision) {
      throw ArgumentError.value(minimumRevision, 'minimumRevision');
    }
    final route = await EncryptedRecord.route(
      key: key,
      owner: owner,
      entityType: entityType,
      entityId: entityId,
    );
    final record = await transport.fetch(route);
    if (record == null) {
      if (minimumRevision > 0) {
        throw StateError(
          'Registro conhecido ausente; possível perda ou replay.',
        );
      }
      return null;
    }
    if (record.route != route ||
        record.revision < 1 ||
        record.revision < minimumRevision ||
        record.revision > _maxRevision) {
      throw StateError(
        'Rota ou revisão remota inválida; dados locais preservados.',
      );
    }
    final payload = await EncryptedRecord.open(
      key: key,
      owner: owner,
      routeId: route,
      revision: record.revision,
      envelope: record.envelope,
    );
    if (payload['entityType'] != entityType ||
        payload['entityId'] != entityId) {
      throw const FormatException('Identidade do registro não confere.');
    }
    return {'revision': record.revision, 'data': payload['data']};
  }

  /// Grava envelope cifrado com Compare-and-Swap. Retorna também o envelope selado
  /// para persistência do checkpoint local pelo chamador.
  Future<
    ({EncryptedWriteResult result, String route, Map<String, dynamic> envelope})
  >
  writeSealed({
    required String entityType,
    required String entityId,
    required int expectedRevision,
    required Map<String, dynamic> data,
  }) async {
    if (expectedRevision < 0 || expectedRevision >= _maxRevision) {
      throw ArgumentError.value(expectedRevision, 'expectedRevision');
    }
    final sealed = await EncryptedRecord.seal(
      key: key,
      owner: owner,
      entityType: entityType,
      entityId: entityId,
      revision: expectedRevision + 1,
      data: data,
    );
    final route = sealed['route'] as String;
    final envelope = Map<String, dynamic>.from(sealed['envelope'] as Map);
    final result = await transport.compareAndSwap(
      route: route,
      expectedRevision: expectedRevision,
      envelope: envelope,
    );
    if ((result.success && result.revision != expectedRevision + 1) ||
        (result.revision != null &&
            (result.revision! < 1 || result.revision! > _maxRevision))) {
      throw const FormatException('Revisão retornada pelo servidor inválida.');
    }
    return (result: result, route: route, envelope: envelope);
  }

  /// A revisão esperada deve vir do estado anteriormente verificado, não de
  /// um novo GET seguido de sobrescrita. Não retenta conflito automaticamente.
  Future<EncryptedWriteResult> write({
    required String entityType,
    required String entityId,
    required int expectedRevision,
    required Map<String, dynamic> data,
  }) async {
    final sealedResult = await writeSealed(
      entityType: entityType,
      entityId: entityId,
      expectedRevision: expectedRevision,
      data: data,
    );
    return sealedResult.result;
  }
}
