/// Enquanto a sincronização E2EE não estiver integrada e verificada, não
/// transfira objetos legados em claro pelo Storage. Não altera arquivos locais
/// nem apaga objetos antigos. Autenticação Supabase continua a usar HTTPS.
class SyncPrivacyPolicy {
  SyncPrivacyPolicy._();
  static bool get unencryptedMediaAllowed => false;
}
