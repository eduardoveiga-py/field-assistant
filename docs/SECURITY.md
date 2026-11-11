# Política de Segurança e Privacidade: Ministério Pessoal

## 1. Princípios de Privacidade
Os dados gerenciados por este aplicativo dizem respeito a conversas, nomes, endereços e preferências espirituais de moradores e estudantes bíblicos. Portanto:
- **Zero Telemetria / Zero Ads:** Nenhum SDK de analytics comercial, rastreamento comportamental ou anúncios é incluído no projeto.
- **Isolamento de Logs:** Informações pessoais (nomes, telefones, anotações de visitas, perguntas) nunca são impressas no console ou em logs técnicos em ambiente de produção.
- **Comunicação Segura:** Toda comunicação de rede com o backend Supabase ocorre estritamente via TLS 1.3/HTTPS.

---

## 2. Segurança no Banco Local e Plataformas
- **Dispositivos Móveis (iOS/iPadOS/Android):** Drift com SQLite nativo em sandbox do aplicativo. Suporte a bloqueio biométrico (FaceID/TouchID/Impressão Digital) com fallback obrigatório por PIN local (hash PBKDF2/SHA-256 salgado em armazenamento seguro — sem desbloqueio automático quando hardware biométrico está ausente).
- **Web (Wasm / IndexedDB):** Drift Wasm com `IndexedDbFileSystem` isolado pela política de mesma origem (Same-Origin Policy) e protegido por `Content-Security-Policy` estrito em `web/index.html`.
  - *Aviso sobre sigilo na Web:* O IndexedDB do navegador não é criptografado em repouso pelo sistema operacional da mesma forma que o SQLite em sandbox móvel. Evite utilizar computadores públicos/compartilhados para dados ministeriais sensíveis e prefira dispositivos móveis com bloqueio de tela e PIN para anotações detalhadas.
- **Armazenamento de Segredos:** Credenciais de e-mail, tokens OAuth, PIN e a chave de backup silencioso (`device_silent_backup_secret`) são gravados exclusivamente via `flutter_secure_storage` (Keychain/Keystore), nunca em `app_kv_store` ou texto plano.
- **Verificação de Atualizações (A1/A10):** No Android, downloads de APK passam por validação **fail-closed** contra manifesto `SHA256SUMS.txt` / digest da GitHub Release antes de acionar o instalador. No iOS (distribuição sideload/LiveContainer sem assinatura corporativa da App Store), o pacote `.ipa` é **unsigned** e não é auto-atualizável nem verificável criptograficamente em runtime pelo app — valide manualmente o SHA-256 na página oficial da release ou utilize o canal oficial de release publicada (`releases/latest/download/apps.json`).

---

## 3. Segurança no Backend (Supabase / PostgreSQL e Storage)
- **Row Level Security (RLS):** Todas as 26 tabelas sincronizadas possuem RLS ativado em `supabase/migrations/`. As políticas garantem isolamento estrito por `owner_id = auth.uid()` (via `auth.uid()` e RPC `sync_upsert` com validação de propriedade).
- **Buckets Privados de Storage (`voice_notes`, `ticuna_audio`, `person_photos`, `knowledge_vault`):** Todos os uploads e downloads exigem sessão autenticada e utilizam estritamente prefixo `${auth.uid()}/...` (sem pasta compartilhada anônima e sem fallback entre buckets distintos). Policies RLS de `storage.objects` devem restringir `SELECT`, `INSERT`, `UPDATE` e `DELETE` a `(storage.foldername(name))[1] = auth.uid()::text`.
  - *Teste manual recomendado:* autenticar como Usuário A, tentar listar/baixar objeto em `${userB}/...` em cada bucket e confirmar HTTP `403`/lista vazia.
- **Chaves de Acesso:** Nenhuma URL Supabase, `anon_key` ou `GOOGLE_WEB_CLIENT_ID` de produção possui valor padrão hardcoded no código-fonte; configure via `--dart-define` ou `.env` (sem `service_role`).
- **Auditoria de Acesso Cruzado:** Testes automatizados e RPC server-side garantem bloqueio de sobrescritas e acesso entre proprietários divergentes.

---

## 4. Segurança de Backup e Restauração
- **Criptografia Simétrica Forte:** O arquivo de backup exportado é criptografado com AES-GCM (256 bits).
- **Derivação de Chave:** A chave criptográfica é derivada da senha fornecida pelo usuário utilizando PBKDF2 com salt aleatório e alto número de iterações.
- **Verificação de Integridade:** O arquivo contém tag de autenticação HMAC/GCM para impedir restauração de dados corrompidos ou adulterados.
- **Proteção na Restauração:** O fluxo de restauração nunca sobrescreve o banco cegamente; ele realiza pré-visualização, cálculo de diff (adições, alterações, conflitos) e validação de versão do esquema antes de efetivar qualquer modificação.
