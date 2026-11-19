import 'package:cryptography/cryptography.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_logger.dart';
import '../../database/app_database.dart';
import 'encrypted_record_checkpoint.dart';
import 'encrypted_record_sync.dart';
import 'recovery_crypto.dart';
import 'recovery_key_store.dart';
import 'recovery_vault_transport.dart';
import 'recovery_vault_verifier.dart';

/// Serviço central de gerenciamento da Criptografia de Ponta a Ponta (E2EE).
/// Coordena o cofre BIP-39, chaves criptográficas locais estritamente isoladas
/// por conta (`ownerId`) e transporte seguro.
class E2eeService {
  final RecoveryKeyStore keyStore;
  final SupabaseClient? client;
  final AppDatabase db;
  final RecoveryVaultTransport? vaultTransportOverride;
  final EncryptedRecordTransport? recordTransportOverride;

  E2eeService({
    RecoveryKeyStore? keyStore,
    this.client,
    required this.db,
    this.vaultTransportOverride,
    this.recordTransportOverride,
  }) : keyStore = keyStore ?? RecoveryKeyStore();

  SupabaseClient? get _client {
    try {
      return client ??
          (Supabase.instance.isInitialized ? Supabase.instance.client : null);
    } catch (_) {
      return null;
    }
  }

  static const String localUserId = 'local_user';

  String _normalizeOwner(String ownerId) {
    final trimmed = ownerId.trim();
    return trimmed.isNotEmpty ? trimmed : localUserId;
  }

  /// Verifica se a chave E2EE está instalada localmente EXCLUSIVAMENTE para [ownerId].
  /// Nunca herda ou copia chaves automaticamente de `local_user` ou de outra conta.
  Future<bool> isKeyInstalled(String ownerId) async {
    final effectiveId = _normalizeOwner(ownerId);
    try {
      final key = await keyStore.load(effectiveId);
      return key != null;
    } catch (e, st) {
      AppLogger.warning(
        'Falha ao verificar chave E2EE local para $effectiveId',
        e,
        st,
      );
      return false;
    }
  }

  /// Retorna a chave E2EE (SecretKey) em memória EXCLUSIVAMENTE para [ownerId].
  /// Nunca realiza fallback ou espelhamento entre contas.
  Future<SecretKey?> getKey(String ownerId) async {
    final effectiveId = _normalizeOwner(ownerId);
    try {
      return await keyStore.load(effectiveId);
    } catch (e, st) {
      AppLogger.warning(
        'Falha ao carregar chave E2EE para $effectiveId',
        e,
        st,
      );
      return null;
    }
  }

  /// Remove a chave E2EE local de uma conta específica.
  Future<void> clearKey(String ownerId) async {
    final effectiveId = _normalizeOwner(ownerId);
    await keyStore.clear(effectiveId);
  }

  /// Migração explícita e autenticada da chave de modo offline (`local_user`)
  /// para uma conta autenticada recém-criada. Exige confirmação explícita do usuário.
  Future<void> migrateLocalKeyToAccount({
    required String targetOwnerId,
    required bool userConfirmed,
  }) async {
    final target = targetOwnerId.trim();
    if (!userConfirmed) {
      throw StateError(
        'Migração da chave local exige confirmação explícita do usuário.',
      );
    }
    if (target.isEmpty || target == localUserId) {
      throw ArgumentError.value(
        targetOwnerId,
        'targetOwnerId',
        'Conta de destino inválida para migração E2EE.',
      );
    }
    // Consultar ausência e copiar a chave não cria um cofre remoto de forma
    // atômica. Até existir um protocolo recuperável, não mover nenhuma chave.
    throw StateError(
      'Migração de chave local temporariamente indisponível; '
      'nenhuma chave foi alterada.',
    );
  }

  /// Obtém o transporte do cofre de recuperação para a conta.
  RecoveryVaultTransport? getVaultTransport(String ownerId) {
    if (vaultTransportOverride != null) return vaultTransportOverride;
    final c = _client;
    if (c == null) return null;
    if (c.auth.currentUser == null || c.auth.currentUser!.id != ownerId) {
      return null;
    }
    return SupabaseRecoveryVaultTransport(client: c, owner: ownerId);
  }

  /// Obtém o transporte de registros cifrados para a conta.
  EncryptedRecordTransport? getRecordTransport(String ownerId) {
    if (recordTransportOverride != null) return recordTransportOverride;
    final c = _client;
    if (c == null) return null;
    if (c.auth.currentUser == null || c.auth.currentUser!.id != ownerId) {
      return null;
    }
    return SupabaseEncryptedRecordTransport(client: c, owner: ownerId);
  }

  /// Verifica se já existe um cofre cadastrado para este usuário no Supabase.
  Future<bool> hasRemoteVault(String ownerId) async {
    final transport = getVaultTransport(ownerId);
    if (transport == null) {
      throw StateError('Cofre remoto indisponível para esta conta.');
    }
    return await transport.fetch() != null;
  }

  /// Gera uma frase apenas para o modo local. Para contas remotas a frase
  /// deve ser mostrada ao usuário *antes* da operação de rede.
  Future<String> setupNewVault(String ownerId) async {
    if (_normalizeOwner(ownerId) != localUserId) {
      throw StateError('Para contas remotas, confirme a frase antes de criar o cofre.');
    }
    final phrase = RecoveryCrypto.createPhrase();
    await setupVaultWithPhrase(ownerId, phrase);
    return phrase;
  }

  /// O chamador deve mostrar e confirmar a frase antes desta operação e
  /// conservá-la em caso de resposta de rede incerta para permitir restauração.
  Future<void> setupVaultWithPhrase(String ownerId, String phrase) async {
    final effectiveId = _normalizeOwner(ownerId);
    if (await keyStore.load(effectiveId) != null) {
      throw StateError('Já existe uma chave local para esta conta; ela não foi alterada.');
    }
    final key = await RecoveryCrypto.keyFromPhrase(phrase);
    if (effectiveId != localUserId) {
      final transport = getVaultTransport(effectiveId);
      if (transport == null) {
        throw StateError('Cofre remoto indisponível; nenhuma chave foi instalada.');
      }
      final marker = await RecoveryVaultVerifier.create(root: key, owner: effectiveId);
      final setup = RecoveryVaultSetup(owner: effectiveId, transport: transport);
      final created = await setup.createConfirmed(
        key: key,
        marker: marker,
        expectedVaultId: marker['vaultId'] as String,
      );
      if (!created) {
        throw StateError('Já existe um cofre remoto. Use a frase existente para restaurá-lo.');
      }
      await setup.fetchVerified(
        key: key,
        expectedVaultId: marker['vaultId'] as String,
      );
    }
    await keyStore.install(owner: effectiveId, phrase: phrase, confirmation: phrase);
  }

  /// Confirma que a chave instalada corresponde ao cofre remoto atual.
  /// A ausência ou falha de rede nunca autoriza sincronização.
  Future<void> verifyRemoteVaultForSync(String ownerId) async {
    final key = await keyStore.load(ownerId);
    final transport = getVaultTransport(ownerId);
    if (key == null || transport == null) {
      throw StateError('Chave ou cofre remoto indisponível.');
    }
    final marker = await transport.fetch();
    if (marker == null) throw StateError('Cofre remoto não encontrado.');
    await RecoveryVaultVerifier.verify(root: key, owner: ownerId, marker: marker);
  }

  /// Restaura o acesso ao cofre a partir da frase de 24 palavras digitada pelo usuário.
  /// Falha fechada se o cofre remoto não existir (nunca cria silenciosamente um novo cofre).
  Future<bool> restoreVault(String ownerId, String phrase) async {
    final effectiveId = _normalizeOwner(ownerId);
    final key = await RecoveryCrypto.keyFromPhrase(phrase);
    final transport = getVaultTransport(effectiveId);
    if (transport == null && effectiveId != localUserId) {
      throw StateError('Cofre remoto indisponível; nenhuma chave foi instalada.');
    }
    if (effectiveId == localUserId && await keyStore.load(effectiveId) == null) {
      throw StateError('Não é possível verificar uma frase local sem chave existente.');
    }
    if (transport != null && effectiveId != localUserId) {
      final remoteMarker = await transport.fetch();
      if (remoteMarker == null) {
        throw StateError(
          'Nenhum cofre de criptografia encontrado no servidor para esta conta. '
          'Crie um novo cofre em vez de restaurar.',
        );
      }
      try {
        await RecoveryVaultVerifier.verify(
          root: key,
          owner: effectiveId,
          marker: remoteMarker,
        );
      } on SecretBoxAuthenticationError catch (e, st) {
        AppLogger.warning(
          'Frase incorreta ao restaurar cofre E2EE para $effectiveId',
          e,
          st,
        );
        throw const FormatException(
          'A frase fornecida não corresponde ao cofre cadastrado no servidor.',
        );
      }
    }
    await keyStore.install(
      owner: effectiveId,
      phrase: phrase,
      confirmation: phrase,
    );
    AppLogger.info('Cofre E2EE restaurado com sucesso para $effectiveId');
    return true;
  }

  /// Cria instância do sincronizador de registros cifrados.
  Future<EncryptedRecordSync?> getRecordSync(String ownerId) async {
    final effectiveId = _normalizeOwner(ownerId);
    final key = await getKey(effectiveId);
    final transport = getRecordTransport(effectiveId);
    if (key == null || transport == null) return null;
    return EncryptedRecordSync(
      owner: effectiveId,
      key: key,
      transport: transport,
    );
  }

  /// Cria instância de checkpoint atômico no banco SQLite local.
  Future<EncryptedRecordCheckpoint?> getCheckpoint(String ownerId) async {
    final sync = await getRecordSync(ownerId);
    if (sync == null) return null;
    return EncryptedRecordCheckpoint(db: db, sync: sync);
  }
}
