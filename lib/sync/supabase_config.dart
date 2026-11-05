/// Configuração pública do projeto. A chave publishable não é um segredo:
/// a proteção dos dados depende das políticas RLS no servidor Supabase.
class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pchwrcwrvnbiywrdsvum.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_TUOpxRmQESlufGuNMqrhUA_Bltscqvy',
  );
}
