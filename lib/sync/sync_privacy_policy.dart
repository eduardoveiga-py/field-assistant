import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

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
    defaultValue: false,
  );

  // O ponteiro mutável de mídia não implementa CAS; a flag de build sozinha
  // não pode abrir sync real até o protocolo de mídia ser corrigido e testado.
  static bool get mediaProtocolVerified => false;

  static bool get isCloudSyncEnabled =>
      _enableE2eeSyncCompileFlag && mediaProtocolVerified;

  // Explicitly unsafe opt-in, for disposable local data only. Never enabled in
  // profile/release or Web, even if these defines are accidentally supplied.
  static const _localTestRequested = bool.fromEnvironment(
    'FA_ENABLE_UNSAFE_LOCAL_TEST_SYNC',
    defaultValue: false,
  );
  static const _localTestRiskAccepted = bool.fromEnvironment(
    'FA_ACK_TEST_DATA_MAY_BE_LOST',
    defaultValue: false,
  );

  static bool get localTestBuildEnabled =>
      kDebugMode && !kIsWeb && _localTestRequested && _localTestRiskAccepted;

  /// Only the exact, default local endpoint; never infer isolation from DNS.
  /// A local proxy can still forward elsewhere, so the user must verify it.
  static bool isLocalTestEndpoint(String? url) =>
      url == 'http://127.0.0.1:54321' || url == 'http://127.0.0.1:54321/';

  /// Na Web não há Keychain/Keystore nativo; sincronização persistente na Web
  /// permanece desabilitada por padrão até solução validada de passphrase por sessão.
  static bool get webPersistentSyncAllowed => false;

  /// Verifica se a sincronização remota pode operar na plataforma atual.
  static bool canRunRemoteSync({
    bool allowInTesting = false,
    String? verifiedLocalClientUrl,
  }) {
    if (allowInTesting) return true;
    if (kIsWeb && !webPersistentSyncAllowed) return false;
    return isCloudSyncEnabled ||
        (localTestBuildEnabled && isLocalTestEndpoint(verifiedLocalClientUrl));
  }
}
