import 'package:flutter/foundation.dart' show kIsWeb;

/// Política de privacidade e criptografia ponta a ponta (E2EE) — FAES FA-SEC-01/05.
/// Objetos e registros no Supabase são autenticados e protegidos (AES-256-GCM / BIP-39).
class SyncPrivacyPolicy {
  SyncPrivacyPolicy._();

  /// Transferência de mídia em texto claro (sem criptografia) jamais é permitida.
  static bool get unencryptedMediaAllowed => false;

  /// Motor de criptografia de ponta a ponta ativo e obrigatório (sem fallback plaintext).
  static bool get e2eeActive => true;

  /// Flag de compilação para liberação em ambiente de staging/homologação.
  /// Por diretriz de segurança (FAES 6.7), a sincronização em nuvem em produção
  /// permanece bloqueada por padrão até conclusão da homologação E2EE em staging
  /// e dispositivos reais.
  static const bool _enableE2eeSyncCompileFlag = bool.fromEnvironment(
    'ENABLE_E2EE_SYNC',
    defaultValue: true,
  );

  static bool get isCloudSyncEnabled => _enableE2eeSyncCompileFlag;

  /// Na Web não há Keychain/Keystore nativo; sincronização persistente na Web
  /// permanece desabilitada por padrão até solução validada de passphrase por sessão.
  static bool get webPersistentSyncAllowed => false;

  /// Verifica se a sincronização remota pode operar na plataforma atual.
  static bool canRunRemoteSync({bool allowInTesting = false}) {
    if (allowInTesting) return true;
    if (kIsWeb && !webPersistentSyncAllowed) return false;
    return isCloudSyncEnabled;
  }
}
