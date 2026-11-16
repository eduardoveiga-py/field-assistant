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
/// Coordena o cofre BIP-39, chaves criptográficas locais e transporte seguro.
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
      return client ?? (Supabase.instance.isInitialized ? Supabase.instance.client : null);
    } catch (_) {
      return null;
    }
  }

  /// Verifica se a chave E2EE está instalada localmente no dispositivo para o usuário
  Future<bool> isKeyInstalled(String ownerId) async {
    if (ownerId.isEmpty) return false;
    try {
      final key = await keyStore.load(ownerId);
      return key != null;
    } catch (e, st) {
      AppLogger.warning('Falha ao verificar chave E2EE local para $ownerId', e, st);
      return false;
    }
  }

  /// Retorna a chave E2EE (SecretKey) em memória se instalada
  Future<SecretKey?> getKey(String ownerId) async {
    if (ownerId.isEmpty) return null;
    try {
      return await keyStore.load(ownerId);
    } catch (e, st) {
      AppLogger.warning('Falha ao carregar chave E2EE para $ownerId', e, st);
      return null;
    }
  }

  /// Obtém o transporte do cofre de recuperação para a conta
  RecoveryVaultTransport? getVaultTransport(String ownerId) {
    if (vaultTransportOverride != null) return vaultTransportOverride;
    final c = _client;
    if (c == null) return null;
    return SupabaseRecoveryVaultTransport(client: c, owner: ownerId);
  }

  /// Obtém o transporte de registros cifrados para a conta
  EncryptedRecordTransport? getRecordTransport(String ownerId) {
    if (recordTransportOverride != null) return recordTransportOverride;
    final c = _client;
    if (c == null) return null;
    return SupabaseEncryptedRecordTransport(client: c, owner: ownerId);
  }

  /// Verifica se já existe um cofre cadastrado para este usuário no Supabase
  Future<bool> hasRemoteVault(String ownerId) async {
    final transport = getVaultTransport(ownerId);
    if (transport == null) return false;
    try {
      final marker = await transport.fetch();
      return marker != null;
    } catch (e, st) {
      AppLogger.warning('Erro ao consultar cofre remoto E2EE para $ownerId', e, st);
      return false;
    }
  }

  /// Inicializa um novo cofre E2EE com frase mnemônica de 24 palavras BIP-39,
  /// grava no cofre remoto e instala no armazenamento local seguro.
  Future<String> setupNewVault(String ownerId) async {
    final phrase = RecoveryCrypto.createPhrase();
    final key = await RecoveryCrypto.keyFromPhrase(phrase);
    final marker = await RecoveryVaultVerifier.create(root: key, owner: ownerId);
    final vaultId = marker['vaultId'] as String;

    final transport = getVaultTransport(ownerId);
    if (transport != null) {
      final setup = RecoveryVaultSetup(owner: ownerId, transport: transport);
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

    await keyStore.install(owner: ownerId, phrase: phrase, confirmation: phrase);
    AppLogger.info('Novo cofre E2EE configurado com sucesso para $ownerId');
    return phrase;
  }

  /// Restaura o acesso ao cofre a partir da frase de 24 palavras digitada pelo usuário
  Future<bool> restoreVault(String ownerId, String phrase) async {
    final key = await RecoveryCrypto.keyFromPhrase(phrase);
    final transport = getVaultTransport(ownerId);
    if (transport != null) {
      final remoteMarker = await transport.fetch();
      if (remoteMarker != null) {
        try {
          await RecoveryVaultVerifier.verify(root: key, owner: ownerId, marker: remoteMarker);
        } on SecretBoxAuthenticationError catch (e, st) {
          AppLogger.warning('Frase incorreta ao restaurar cofre E2EE para $ownerId', e, st);
          throw const FormatException('A frase fornecida não corresponde ao cofre cadastrado no servidor.');
        }
      } else {
        final marker = await RecoveryVaultVerifier.create(root: key, owner: ownerId);
        await transport.createIfAbsent(marker);
      }
    }
    await keyStore.install(owner: ownerId, phrase: phrase, confirmation: phrase);
    AppLogger.info('Cofre E2EE restaurado com sucesso para $ownerId');
    return true;
  }

  /// Cria instância do sincronizador de registros cifrados
  Future<EncryptedRecordSync?> getRecordSync(String ownerId) async {
    final key = await getKey(ownerId);
    final transport = getRecordTransport(ownerId);
    if (key == null || transport == null) return null;
    return EncryptedRecordSync(
      owner: ownerId,
      key: key,
      transport: transport,
    );
  }

  /// Cria instância de checkpoint atômico no banco SQLite local
  Future<EncryptedRecordCheckpoint?> getCheckpoint(String ownerId) async {
    final sync = await getRecordSync(ownerId);
    if (sync == null) return null;
    return EncryptedRecordCheckpoint(db: db, sync: sync);
  }
}
