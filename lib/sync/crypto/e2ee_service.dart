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
import 'web_key_persistence.dart';

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

  /// Verifica se o cofre local na Web está salvo porém bloqueado por PIN rápido.
  Future<bool> isWebPinLocked(String ownerId) async {
    final effectiveId = _normalizeOwner(ownerId);
    try {
      return await keyStore.isWebPinLocked(effectiveId);
    } catch (e, st) {
      AppLogger.warning(
        'Falha ao consultar estado de bloqueio PIN na Web para $effectiveId',
        e,
        st,
      );
      return false;
    }
  }

  /// Retorna o estado detalhado de persistência da chave E2EE para [ownerId].
  Future<WebKeyUnlockMode> getWebUnlockMode(String ownerId) async {
    final effectiveId = _normalizeOwner(ownerId);
    try {
      return await keyStore.getWebUnlockState(effectiveId);
    } catch (e, st) {
      AppLogger.warning(
        'Falha ao consultar modo de desbloqueio E2EE para $effectiveId',
        e,
        st,
      );
      return WebKeyUnlockMode.none;
    }
  }

  /// Desbloqueia o cofre protegido por PIN PBKDF2-SHA256 no navegador.
  Future<bool> unlockWithWebPin({
    required String ownerId,
    required String pin,
  }) async {
    final effectiveId = _normalizeOwner(ownerId);
    await keyStore.unlockWithPin(owner: effectiveId, pin: pin);
    return true;
  }

  /// Bloqueia apenas a sessão em RAM na Web preservando o envelope protegido no IndexedDB.
  Future<void> lockWebSession(String ownerId) async {
    final effectiveId = _normalizeOwner(ownerId);
    await keyStore.lockWebSession(effectiveId);
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
    final existingTargetKey = await keyStore.load(target);
    if (existingTargetKey != null) {
      throw StateError(
        'A conta de destino já possui chave E2EE instalada neste dispositivo.',
      );
    }
    if (await hasRemoteVault(target)) {
      throw StateError(
        'A conta de destino já possui um cofre E2EE remoto. Use a restauração pela frase de recuperação.',
      );
    }
    final localKey = await keyStore.load(localUserId);
    if (localKey == null) {
      throw StateError('Nenhuma chave local encontrada para migração.');
    }
    await keyStore.copyOwnerKey(fromOwner: localUserId, toOwner: target);
    await keyStore.clear(localUserId);
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
    if (transport == null) return false;
    try {
      final marker = await transport.fetch();
      return marker != null;
    } catch (e, st) {
      AppLogger.warning(
        'Erro ao consultar cofre remoto E2EE para $ownerId',
        e,
        st,
      );
      return false;
    }
  }

  /// Inicializa um novo cofre E2EE com frase mnemônica de 24 palavras BIP-39,
  /// grava no cofre remoto e instala EXCLUSIVAMENTE sob [ownerId].
  Future<String> setupNewVault(String ownerId, {String? webUnlockPin}) async {
    final effectiveId = _normalizeOwner(ownerId);
    final phrase = RecoveryCrypto.createPhrase();
    final key = await RecoveryCrypto.keyFromPhrase(phrase);
    final marker = await RecoveryVaultVerifier.create(
      root: key,
      owner: effectiveId,
    );
    final vaultId = marker['vaultId'] as String;

    final transport = getVaultTransport(effectiveId);
    if (transport != null) {
      final setup = RecoveryVaultSetup(
        owner: effectiveId,
        transport: transport,
      );
      final created = await setup.createConfirmed(
        key: key,
        marker: marker,
        expectedVaultId: vaultId,
      );
      if (!created) {
        throw StateError(
          'Já existe um cofre de criptografia cadastrado para esta conta. Use sua frase de recuperação existente.',
        );
      }
    }

    await keyStore.install(
      owner: effectiveId,
      phrase: phrase,
      confirmation: phrase,
      webUnlockPin: webUnlockPin,
    );
    AppLogger.info('Novo cofre E2EE configurado com sucesso para $effectiveId');
    return phrase;
  }

  /// Restaura o acesso ao cofre a partir da frase de 24 palavras digitada pelo usuário.
  /// Falha fechada se o cofre remoto não existir (nunca cria silenciosamente um novo cofre).
  Future<bool> restoreVault(
    String ownerId,
    String phrase, {
    String? webUnlockPin,
  }) async {
    final effectiveId = _normalizeOwner(ownerId);
    final key = await RecoveryCrypto.keyFromPhrase(phrase);
    final transport = getVaultTransport(effectiveId);
    String? expectedVaultId;
    Map<String, dynamic>? remoteMarker;
    if (transport != null) {
      remoteMarker = await transport.fetch();
      if (remoteMarker == null) {
        throw StateError(
          'Nenhum cofre de criptografia encontrado no servidor para esta conta. '
          'Crie um novo cofre em vez de restaurar.',
        );
      }
      try {
        expectedVaultId = await RecoveryVaultVerifier.verify(
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
    if (remoteMarker != null && expectedVaultId != null) {
      await keyStore.restoreVerified(
        owner: effectiveId,
        phrase: phrase,
        confirmation: phrase,
        marker: remoteMarker,
        expectedVaultId: expectedVaultId,
        webUnlockPin: webUnlockPin,
      );
    } else {
      await keyStore.install(
        owner: effectiveId,
        phrase: phrase,
        confirmation: phrase,
        webUnlockPin: webUnlockPin,
      );
    }
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
