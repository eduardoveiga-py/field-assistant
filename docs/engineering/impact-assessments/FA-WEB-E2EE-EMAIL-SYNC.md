# Impact Assessment & Architecture Design — Desbloqueio E2EE Persistente na Web e Sincronização Multi-Dispositivos de Contas/E-mails

- **Task ID:** `FA-WEB-E2EE-EMAIL-SYNC`
- **Branch Base:** `feat/persistent-e2ee-email-second-brain` (derivada de `feat/home-unread-email-badge`)
- **Governance:** `AGENTS.md`, `.agents/rules/field-assistant-ci-gate.md`, `.agents/skills/field-assistant-engineering-standard/SKILL.md`, `.agents/skills/offline-first-sync/SKILL.md`, `.agents/skills/flutter-drift-architecture/SKILL.md`

---

## 1. Problema Observado & Resultado Esperado

### 1.1 Por que os 3 dispositivos PWA (celular, tablet e PC) não sincronizavam
1. **Bloqueio de plataforma Web (`SyncPrivacyPolicy.webPersistentSyncAllowed => false`):** No `SupabaseSyncService._evaluateSyncGate()`, qualquer execução com `kIsWeb == true` retornava imediatamente status pausado (`_webSyncPausedMessage`) sem fazer push nem pull no Supabase.
2. **Persistência volátil na Web (`RecoveryKeyStore._webMemoryKeys`):** Na Web, a chave mestra derivada da frase de 24 palavras (BIP-39 -> HKDF-SHA256) existia apenas em memória RAM (`Map<String, String> _webMemoryKeys`), sendo apagada em todo reload ou fechamento de aba.
3. **E-mails e contas não sincronizavam completamente:**
   - As contas (`EmailAccount`) ficavam apenas em `app_kv_store['multi_email_accounts_registry']` — chave local não incluída em `SupabaseSyncService.syncTables`. Assim, uma conta Exchange ou IMAP configurada no Android/iOS nunca aparecia no PWA Web ou em outro aparelho.
   - `RecoveryCrypto.seal` e o RPC PostgreSQL `encrypted_record_cas` impõem limite estrito de **1 MiB** (`1048576` bytes plaintext) por registro na tabela `encrypted_records`. E-mails com `rawEmlBase64` ou HTML/anexos inline extensos ultrapassavam 1 MiB ao empacotar `metadata['email']` inteiro no JSON de `inbox_entries`, falhando no envio E2EE.

### 1.2 Objetivo
- **Desbloqueio E2EE persistente seguro na Web PWA:** Usuário restaura sua frase de 24 palavras **uma única vez** por navegador (escolhendo entre manter desbloqueio persistente via `WebCrypto` `CryptoKey` não-extraível no IndexedDB ou proteger o desbloqueio no navegador com PIN rápido PBKDF2-HMAC-SHA256), sobrevivendo a reloads do navegador em celular, tablet e PC sem nunca gravar a frase de 24 palavras em texto claro.
- **Sincronização de contas de e-mail SEM senhas + mensagens:** Criar tabela Drift versionada e sincronizada E2EE `email_accounts` (exclusivamente metadados de conta: nome, endereço, provedor, hosts, portas, protocolo, assinatura HTML; **zero senhas e zero tokens OAuth**), garantindo que Exchange/IMAP sincronizados por dispositivo nativo (Android/iOS/Windows) apareçam integralmente no Web PWA e demais dispositivos.
- **Compatação/Offload E2EE para `inbox_entries` > 750 KiB:** Deslocar automaticamente blobs pesados de e-mail (`rawEmlBase64` / `bodyHtml` extenso) para chunks cifrados AES-256-GCM no bucket `knowledge_vault` via `EncryptedMediaTransfer`, mantendo cada registro `encrypted_records` bem abaixo de 1 MiB.

---

## 2. Jornada do Usuário & Fronteiras de Confiança (Trust Boundaries)

1. **Dispositivo Primário (Android / iOS / Windows):**
   - Usuário autentica no Supabase e cria/restaura seu cofre BIP-39 (chave persistida no Keystore/Keychain/DPAPI).
   - Configura Exchange ActiveSync, IMAP/SMTP, Gmail API ou Microsoft Graph; senha/token OAuth ficam exclusivamente no `FlutterSecureStorage` local deste dispositivo.
   - `EmailAccountsManager.saveAccount` grava em `email_accounts` e enfileira em `sync_queue`.
   - `ExchangeReadService` / `EmailSyncCoordinator` / `JwEmailService` gravam mensagens em `inbox_entries` e enfileiram em `sync_queue`.
   - `SupabaseSyncService` cifra ambos (metadados de contas sem senha + e-mails, com offload cifrado se > 750 KiB) em `public.encrypted_records` + `knowledge_vault`.
2. **Dispositivos Secundários (Web PWA no PC, Tablet e Celular):**
   - Usuário faz login com a mesma conta Supabase.
   - Na primeira vez no navegador, insere suas 24 palavras uma vez (`E2eeSetupDialog`) e escolhe o modo Web:
     - **Dispositivo Pessoal (Persistente):** browser gera `WebCrypto` `AES-GCM` `CryptoKey` (`extractable: false`) e armazena o `CryptoKey` opaco + envelope cifrado da chave E2EE no IndexedDB (`field_assistant_e2ee_keystore`). Recarregamentos futuros desbloqueiam automaticamente sem redigitar 24 palavras nem PIN.
     - **Navegador Compartilhado (PIN Rápido):** chave E2EE é cifrada no IndexedDB com chave derivada via **PBKDF2-HMAC-SHA256 (600.000 iterações + sal aleatório de 16 bytes)**. Ao reabrir a PWA, basta digitar o PIN curto para liberar a chave em sessão; clicar "Bloquear Cofre" limpa a RAM mantendo o cofre protegido no IndexedDB.
   - **Trade-off explícito (FAES 5.1):** Armazenamento no navegador (`IndexedDB` + `WebCrypto extractable: false`) protege contra extração trivial dos bytes da chave por inspeção de storage/disk e contra leitura passiva, porém em modelo de ameaça Web continua subordinado ao mesmo-origem (`Same-Origin Policy`); XSS na origem ativa durante sessão desbloqueada poderia usar a sessão em RAM. Isso será explicitamente documentado na UI (`E2eeSetupDialog` / `Configurações`) e nesta especificação.
   - Contas sincronizadas (inclusive `exchange` e `imap`) e todas as suas mensagens aparecem no `InboxScreen`.
   - Para contas cuja credencial local não existe no dispositivo secundário (ou protocolos sem suporte de socket na Web como `exchange`/`imap`), a UI sinaliza claramente:
     - *Somente leitura sincronizada (credencial local não configurada neste aparelho)* ou *Sincronização direta indisponível no navegador (mensagens recebidas via cofre E2EE do outro dispositivo)*, oferecendo botão para inserir credencial local em desktop/nativo quando suportado.

---

## 3. Componentes e Arquivos Afetados

| Componente | Arquivo | Mudança |
|---|---|---|
| Persistência E2EE Web | `lib/sync/crypto/web_key_persistence.dart`, `web_key_persistence_stub.dart`, `web_key_persistence_web.dart` | Interface multiplataforma + PBKDF2-SHA256 600k PIN wrapper + IndexedDB/WebCrypto (`extractable: false`) |
| KeyStore & E2EE | `lib/sync/crypto/recovery_key_store.dart`, `lib/sync/crypto/e2ee_service.dart` | Suporte persistente/PIN-locked na Web preservando 100% contratos em `recovery_key_store_test.dart`; estado detalhado (locked/unlocked) |
| Política de Sync | `lib/sync/sync_privacy_policy.dart` | Mantém `ENABLE_E2EE_SYNC` `defaultValue: false`; ativa `webPersistentSyncAllowed => true` |
| UI E2EE | `lib/ui/widgets/e2ee_setup_dialog.dart`, `lib/ui/screens/settings/settings_integration_cards.dart`, `lib/ui/screens/today_screen.dart` | Escolha Persistente/PIN na Web, modal de desbloqueio por PIN, ações de Bloquear/Esquecer navegador, aviso de limite Web vs Keychain, status real de sync na `TodayScreen` |
| Schema & Migration | `lib/database/tables.dart`, `lib/database/app_database.dart`, `lib/database/app_database.g.dart` | Nova tabela `EmailAccounts` (`email_accounts`) na versão **9** com migração idempotente a partir de `app_kv_store` e enfileiramento inicial |
| Contas & Mensagens | `lib/inbox/email_account_model.dart`, `lib/inbox/email_sync_coordinator.dart`, `lib/ui/screens/inbox_screen.dart` | Persistência em `email_accounts` + `sync_queue`, remoção de `catch (_)` silenciosos, badges/UX de credencial local ausente ou proxy E2EE na Web |
| Motor de Sync E2EE | `lib/sync/supabase_sync_service.dart`, `lib/sync/sync_owner_guard.dart`, `lib/settings/backup_service.dart` | Inclusão de `'email_accounts'` em `syncTables`, offload/hidratação E2EE de `inbox_entries` > 750 KiB (`knowledge_vault`), isolamento de troca de conta e backup/restore |

---

## 4. Casos de Borda, Segurança & Rollback

1. **Fallback fail-closed:** `ENABLE_E2EE_SYNC` permanece `false` por padrão no código; se chave Web estiver corrompida, ausente ou bloqueada por PIN, `_evaluateSyncGate` bloqueia push/pull sem vazar plaintext e preserva `sync_queue`.
2. **Isolamento de conta:** `RecoveryKeyStore._storageKey(owner)` usa `sha256(owner)`; `SyncOwnerGuard.resetLocalWorkspaceForAccountSwitch` limpa `email_accounts` e limpa chaves Web de sessão/IndexedDB apenas via `clear(owner)` / isolamento por UID.
3. **Senhas nunca sincronizam:** `EmailAccounts.toColumns` e `_prepareEntryMap('email_accounts', ...)` não têm colunas nem chaves JSON para senha ou token OAuth; `_scrubDisallowedCredentials` remove qualquer eventual campo residual caso injetado.
4. **Rollback:** Como o servidor PostgreSQL usa `public.encrypted_records` opaco por `route`, não há DDL destrutiva no Supabase. Reverter a branch restaura comportamento anterior sem corromper o cofre remoto; localmente, a tabela `email_accounts` mantém cópia compatível e `BackupService` preserva todos os registros.

---

## 5. Plano de Testes

- `test/sync/crypto/recovery_key_store_test.dart` (manter + adicionar cobertura completa Web persistent backend mock + PIN 600k lock/unlock/wrong-PIN/corrupt + >= 90% coverage em `lib/sync/crypto/`).
- `test/sync/privacy_pause_test.dart` (assegurar que `ENABLE_E2EE_SYNC == false` continua pausando corretamente).
- `test/sync/email_accounts_and_large_inbox_e2ee_test.dart`:
  - Sync bidirecional E2EE de `email_accounts` garantindo 0 vazamento de senha/OAuth;
  - Sync de conta `exchange` + mensagens de dispositivo nativo -> dispositivo Web/secundário;
  - Payload `inbox_entries` > 1 MiB com `rawEmlBase64` / HTML extenso -> offload cifrado em `knowledge_vault` + hidratação intacta no destino;
  - Bloqueio fail-closed em erro de download ou envelope corrompido.
- `.\tool\pre_push.ps1`, `flutter build web --release --base-href /field-assistant/ --dart-define=ENABLE_E2EE_SYNC=true`.
