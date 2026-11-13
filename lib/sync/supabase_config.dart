/// Configuração de integração opcional com Supabase via --dart-define.
/// O aplicativo opera 100% offline-first mesmo sem essas variáveis configuradas.
class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isConfigured =>
      url.trim().isNotEmpty &&
      publishableKey.trim().isNotEmpty &&
      !url.contains('your-project.supabase.co') &&
      !url.contains('your-supabase-url') &&
      !publishableKey.contains('your-anon-key');
}
