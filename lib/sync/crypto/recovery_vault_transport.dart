import 'package:cryptography/cryptography.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'recovery_vault_verifier.dart';

abstract class RecoveryVaultTransport {
  Future<Map<String, dynamic>?> fetch();

  /// Retorna falso se já existir um marcador; nunca deve substituí-lo.
  Future<bool> createIfAbsent(Map<String, dynamic> marker);
}

/// Adaptador de produção para cofre de recuperação no Supabase.
/// Exige uma sessão correspondente à conta esperada e opera com create-only.
class SupabaseRecoveryVaultTransport implements RecoveryVaultTransport {
  final SupabaseClient client;
  final String owner;
  SupabaseRecoveryVaultTransport({required this.client, required this.owner});

  void _checkOwner() {
    if (owner.isEmpty || client.auth.currentUser?.id != owner) {
      throw StateError('A conta autenticada não corresponde ao cofre.');
    }
  }

  @override
  Future<Map<String, dynamic>?> fetch() async {
    _checkOwner();
    try {
      final row = await client
          .from('recovery_vaults')
          .select('marker')
          .eq('owner_id', owner)
          .maybeSingle();
      if (row != null && row['marker'] is Map) {
        return Map<String, dynamic>.from(row['marker'] as Map);
      }
    } catch (_) {
      // Fallback para tabela com prefixo experimental caso a tabela de produção ainda não tenha sido aplicada
    }

    try {
      final row = await client
          .from('experimental_recovery_vaults')
          .select('marker')
          .eq('owner_id', owner)
          .maybeSingle();
      if (row == null) return null;
      if (row['marker'] is! Map) throw const FormatException('Marcador remoto inválido.');
      return Map<String, dynamic>.from(row['marker'] as Map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> createIfAbsent(Map<String, dynamic> marker) async {
    _checkOwner();
    try {
      final result = await client.rpc('recovery_vault_create', params: {'p_marker': marker});
      if (result is Map && result['success'] is bool) {
        return result['success'] as bool;
      }
    } catch (_) {
      // Fallback para RPC com prefixo experimental
    }

    final result = await client.rpc('experimental_recovery_vault_create', params: {'p_marker': marker});
    if (result is! Map || result['success'] is! bool ||
        (result['success'] == false && result['conflict'] != true)) {
      throw const FormatException('Resposta de criação do cofre inválida.');
    }
    return result['success'] as bool;
  }
}

/// Confere o marcador antes de enviá-lo e nunca substitui outro cofre.
class RecoveryVaultSetup {
  final String owner;
  final RecoveryVaultTransport transport;
  const RecoveryVaultSetup({required this.owner, required this.transport});

  Future<bool> createConfirmed({
    required SecretKey key,
    required Map<String, dynamic> marker,
    required String expectedVaultId,
  }) async {
    final id = await RecoveryVaultVerifier.verify(root: key, owner: owner, marker: marker);
    if (id != expectedVaultId) throw StateError('Identidade do cofre não confere.');
    return transport.createIfAbsent(marker);
  }

  /// O ID deve vir de uma fonte confiável independente do servidor.
  Future<Map<String, dynamic>> fetchVerified({
    required SecretKey key,
    required String expectedVaultId,
  }) async {
    final marker = await transport.fetch();
    if (marker == null) throw StateError('Cofre não encontrado; nenhuma chave foi instalada.');
    final id = await RecoveryVaultVerifier.verify(root: key, owner: owner, marker: marker);
    if (id != expectedVaultId) throw StateError('Identidade do cofre não confere.');
    return marker;
  }
}
