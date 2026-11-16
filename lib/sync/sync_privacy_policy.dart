/// Política de privacidade e criptografia ponta a ponta (E2EE).
/// Objetos e registros no Supabase são autenticados e protegidos (AES-256-GCM / BIP-39).
class SyncPrivacyPolicy {
  SyncPrivacyPolicy._();

  /// Transferência de mídia em texto claro (sem criptografia) não é permitida.
  static bool get unencryptedMediaAllowed => false;

  /// Motor de criptografia de ponta a ponta ativo e operacional.
  static bool get e2eeActive => true;
}
