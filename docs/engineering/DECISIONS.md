# Field Assistant — Registro Canônico de Decisões de Arquitetura (ADRs)

> **Fonte Única de Verdade:** Este arquivo consolida integralmente os históricos anteriores de `docs/DECISIONS.md` e `docs/engineering/DECISION_LOG.md` sob o padrão **FAES** (`.agents/skills/field-assistant-engineering-standard/SKILL.md`). Nenhuma decisão histórica foi descartada.

---

## Parte I — Decisões Arquiteturais Fundacionais (Histórico Preservado)

### ADR-001: Adoção do Flutter com Suporte a iOS/iPadOS, Android, Desktop e Web
- **Status:** Aprovado e Mantido
- **Contexto:** Necessidade de aplicação executável em iPhone, iPad, Android, Desktop e Web com base de código compartilhada.
- **Decisão:** Utilizar Flutter com Dart estável, priorizando qualidade iOS/iPadOS sem quebrar Android/Web/Desktop.

### ADR-002: Banco de Dados Local Drift (SQLite & Wasm) com Foreign Keys e WAL
- **Status:** Aprovado e Mantido (em evolução para cifra local via `sqlite3_multiple_ciphers` — ver ADR-014)
- **Contexto:** Arquitetura estritamente offline-first com integridade referencial, streams reativos e persistência real.
- **Decisão:** Drift com SQLite nativo (`PRAGMA foreign_keys = ON; PRAGMA journal_mode = WAL; PRAGMA synchronous = NORMAL; PRAGMA busy_timeout = 5000;`) e SQLite Wasm na Web.

### ADR-003: Backend Supabase com Row Level Security (RLS)
- **Status:** Aprovado e Mantido (RLS como autorização; confidencialidade delegada à camada E2EE — ver ADR-010)
- **Contexto:** Sincronização multi-dispositivo com isolamento por `owner_id = auth.uid()`.
- **Decisão:** Manter Supabase/PostgreSQL com RLS estrito em todas as tabelas e buckets, reconhecendo que RLS é autorização no servidor e **não substitui E2EE**.

### ADR-004: Fila de Sincronização Transacional com Resolução de Conflitos e Mutações Indiretas
- **Status:** Aprovado e Mantido
- **Contexto:** Evitar perda silenciosa por LWW cego em edições concorrentes offline e garantir coerência de atualizações indiretas (ex.: `createVisit` atualizando `people`).
- **Decisão:** Toda mutação local (direta ou indireta) na transação grava operação na `sync_queue` com snapshot `baseData`; conflitos são preservados para decisão consciente.

### ADR-005: Ordenação Determinística Composta e Motor de Disponibilidade na Agenda
- **Status:** Aprovado e Mantido
- **Contexto:** Evitar perda de registros na fronteira de paginação e evitar sobreposição involuntária de compromissos.
- **Decisão:** Paginação determinística composta (`server_seq` monotônico no protocolo E2EE; `(updated_at, id)` em legado) e verificação de intervalos `[start, end]` na Agenda.

### ADR-006: Eliminação de Fallback para `Directory.systemTemp` e Staging em 3 Etapas no Restore
- **Status:** Aprovado e Mantido
- **Contexto:** `Directory.systemTemp` pode ser expurgado pelo SO; sobrescrita direta de áudios durante restore causava perda de dados em rollback.
- **Decisão:** Lançar `StorageUnavailableException` quando armazenamento persistente falha; usar staging em 3 etapas (`safety_staging` -> `safety_audio_backup` -> commit -> swap atômico).

### ADR-007: Proteção Contra Consultas Parciais EventKit e Fingerprint com `RRULE`
- **Status:** Aprovado e Mantido (em investigação de substituição de `device_calendar` 4.3.3 por `device_calendar_plus`/EventKit nativo — `FA-IOS-01`)
- **Contexto:** Consultas truncadas do calendário do SO podiam remover vínculos pastorais; recorrências alteradas precisavam ser detectadas.
- **Decisão:** Detectar anomalia de remoção em massa (>25%) e incluir `recurrenceRuleStr` no fingerprint SHA-256.

### ADR-008: Proibição de Migrações Destrutivas por Feature Flags
- **Status:** Aprovado e Mantido (Invariante FAES #5)
- **Contexto:** Usuários podem ocultar/desativar módulos em `customize_features_screen.dart`.
- **Decisão:** Desativar um módulo apenas oculta pontos de entrada na UI; jamais dispara `DROP TABLE` ou `DELETE`. Reativar restaura 100% do histórico.

### ADR-009: Evolução Cartográfica — Nível 2 (Superando Restrição Anterior de Visualizador Simples)
- **Data:** 2026-11-17
- **Status:** Aprovado (Substitui a restrição de escopo anterior do antigo ADR-008 de `DECISION_LOG.md`)
- **Contexto:** Decisão de produto explícita do Programa Mestre FAES: elevar Mapas & Territórios para **Nível 2 — Experiência Cartográfica Completa** offline-first, com contatos offline e arquitetura plugável (MapLibre Native como candidato preferencial + pacotes vetoriais PMTiles/MBTiles verificáveis com SHA-256).
- **Decisão:** Preservar integridade dos contatos privados no Drift (nunca misturar com pacotes cartográficos públicos), corrigir inacessibilidade no `NavigationRail`, eliminar URLs 404 e evoluir o Map Engine via camada de abstração (`MapEngineAdapter`) após avaliação técnica objetiva.

---

## Parte II — Decisões Arquiteturais do Programa Mestre FAES (2026-11-17)

### ADR-010: Eliminação Total de Fail-Open E2EE e Política Fail-Closed na Sincronização
- **Data:** 2026-11-17
- **Status:** Aprovado para Implementação Imediata (`FA-SEC-01`, `FA-SEC-02`, `FA-SEC-03`)
- **Contexto:** A auditoria em `47cc87d` comprovou que `SupabaseSyncService._processQueue()` tentava gravar em `encrypted_records`, engolia exceções como warning e seguia enviando `remotePayload` em texto claro via `sync_upsert_if_unchanged`; `_fetchRemoteChanges()` lia apenas as 26 tabelas plaintext; e todos os 4 buckets de Storage enviavam binários sem criptografia.
- **Decisão:**
  1. **Zero fallback para texto claro** no fluxo de produção (`!_legacyTestMode`). Qualquer falha criptográfica ou ausência de chave aborta o item mantendo a `sync_queue` intacta.
  2. Sincronização de produção opera exclusivamente via `encrypted_records` (push CAS cifrado + pull paginado por cursor monotônico `server_seq` + checkpoints atômicos `EncryptedRecordCheckpoint` + tombstones cifrados para `DELETE`).
  3. Mídias em todos os 4 buckets (`voice_notes`, `ticuna_audio`, `knowledge_vault`, `person_photos`) obedecem `SyncPrivacyPolicy.unencryptedMediaAllowed == false` e usam `EncryptedMedia` (chunks AES-256-GCM + manifesto autenticado), bloqueando qualquer upload/download plaintext em produção.
  4. Gate de segurança de produção (`SyncPrivacyPolicy.productionSyncEnabled`): até homologação completa em staging/dispositivo, manter bloqueio explícito ou modo estritamente cifrado sem qualquer escrita nas 26 tabelas plaintext.

### ADR-011: Isolamento Estrito de Contas (`OwnerGuard` Centralizado) e Remoção de Espelhamento `local_user`
- **Data:** 2026-11-17
- **Status:** Aprovado para Implementação Imediata (`FA-SEC-04`)
- **Contexto:** `AuthSplashScreen` chamava `sync()` sem validar `automatic_sync_owner_id`/`demo_mode`, e `E2eeService` copiava chaves bidirecionalmente entre `local_user` e qualquer `ownerId` autenticado, permitindo que a Conta B herdasse a chave e dados locais da Conta A após logout/login.
- **Decisão:**
  1. Remover completamente a cópia automática bidirecional de chaves entre `local_user` e usuários autenticados em `E2eeService`.
  2. Exigir migração explícita e autenticada quando um usuário offline (`local_user`) optar por vincular seus dados locais à sua conta.
  3. Centralizar `SyncOwnerGuard` dentro de `SupabaseSyncService` (executado em `sync()`, `fetchRemoteChanges()`, `processQueue()`, `retryPendingMediaDownloads()`, `resolveConflictAcceptRemote()` e operações de mídia), validando sessão autenticada, `automatic_sync_owner_id` e `demo_mode`.
  4. Corrigir `E2eeService.restoreVault()`: se não existir cofre remoto (`remoteMarker == null`), **falhar explicitamente** em vez de criar silenciosamente um cofre novo.
  5. Limpar estado de sessão/chave em memória e impedir auto-sync durante transição/logout.

### ADR-012: Contenção Canônica Contra Path Traversal em `saveMediaBytes`
- **Data:** 2026-11-17
- **Status:** Aprovado para Implementação Imediata (`FA-SEC-09`)
- **Contexto:** `lib/sync/media_bytes_io.dart` aceitava `fileName` e `subDir` sem sanitização nem validação de contenção canônica, permitindo gravação fora do diretório de documentos (ex.: `../../evil.txt`).
- **Decisão:** Validar `subDir` e `fileName` contra segmentos vazios, caminhos absolutos, separadores (`/` ou `\`), `..`, bytes nulos e caracteres de controle; validar contenção canônica (`p.canonicalize` + `p.isWithin`); gravar em arquivo temporário dentro do diretório alvo e renomear atomicamente para não corromper arquivos existentes em caso de falha.

### ADR-013: Restauração de Backup Consciente da Identidade de Conta e Estado Crítico de Sync
- **Data:** 2026-11-17
- **Status:** Aprovado para Implementação Imediata (`FA-BAK-01`)
- **Contexto:** `BackupService.restoreFromBackup()` sobrescrevia quase todo `app_kv_store` (corrompendo `automatic_sync_owner_id`, cursores `last_synced_at_*`, checkpoints `e2ee_checkpoint_*`, flags de sessão) e reinjetava a `sync_queue` antiga do backup.
- **Decisão:** Preservar chaves protegidas de identidade, segurança e estado de sincronização durante restore (`automatic_sync_owner_id`, `e2ee_checkpoint_*`, `last_synced_at_*`, `e2ee_cursor_*`, `offline_mode_enabled`, `demo_mode`, `device_silent_backup_secret`, `app_pin_*`, `last_safety_snapshot_*`); não reinjetar cegamente operações antigas da `sync_queue` do backup (reconstituindo apenas mutações locais válidas com integridade verificada).

### ADR-014: Criptografia em Repouso (SQLite Local, KDF de PIN e Backup v3)
- **Data:** 2026-11-17
- **Status:** Aprovado (`FA-SEC-06`, `FA-SEC-07`)
- **Contexto:** `sqlite3_flutter_libs: ^0.6.0+eol` e `sqlcipher_flutter_libs: 0.7.0+eol` atingiram EOL. O PIN atual usa SHA-256 de 1 rodada e o Backup v2 usa PBKDF2 com 100.000 iterações na UI thread.
- **Decisão:**
  1. Migrar PIN para PBKDF2-HMAC-SHA256 com 600.000 iterações (ou Argon2id) + salt aleatório de 16 bytes + comparação constant-time, mantendo migração transparente na verificação de hashes legados.
  2. Introduzir Backup v3 com PBKDF2-HMAC-SHA256 >= 600.000 iterações executado em isolate (`compute`/`Isolate.run`), salt 16B, nonce seguro e AES-256-GCM, preservando leitura compatível de backups v2 (e v1 opt-in).
  3. Para SQLite local: remover dependência EOL `sqlite3_flutter_libs` e avaliar/integrar `sqlite3_multiple_ciphers` via Dart Build Hooks com plano de migração e rollback validado em testes nativos.

### ADR-015: Criptografia SQLite (`sqlite3mc`), Proteção de Arquivos iOS e Remoção de Credenciais Supabase Hardcoded
- **Data:** 2026-11-17
- **Status:** Implementado e Verificado em Testes Nativos Windows (`FA-SEC-06`, `FA-SEC-08`); Hardware Apple pendente (`NOT VERIFIED`)
- **Contexto:** Era necessário eliminar a dependência EOL `sqlite3_flutter_libs`, cifrar o banco SQLite local em repouso sem destruir bancos existentes em modo WAL, proteger arquivos locais no iOS contra backup iCloud/iTunes e remover credenciais Supabase hardcoded (`defaultUrl`/`defaultAnonKey`) de `SupabaseSyncService`.
- **Decisão:**
  1. **SQLite3MultipleCiphers (`sqlite3mc`):** Configurado em `pubspec.yaml` via Dart Build Hooks do `sqlite3 ^3.5.2` (`hooks: user_defines: sqlite3: source: sqlite3mc`, licença MIT / SQLite Public Domain). `LocalDatabaseEncryption` gera/armazena chave aleatória de 256 bits em `FlutterSecureStorage` e executa migração não-destrutiva de bancos plaintext (`PRAGMA wal_checkpoint(TRUNCATE)` -> cópia `.enc.tmp` -> `PRAGMA rekey` -> `PRAGMA integrity_check` + verificação de cabeçalho não-plaintext -> swap atômico com `.pre_enc.bak` e rollback automático em falha). Arquivos `.mbtiles` públicos continuam abrindo em leitura sem `PRAGMA key`.
  2. **iOS Data Protection & Exclusão de Backup:** Adicionado `ios/Runner/Runner.entitlements` com `com.apple.developer.default-data-protection = NSFileProtectionComplete` (registrado nas 3 configurações Debug/Profile/Release de `project.pbxproj`). Como o app não declara `UIBackgroundModes` de sync em segundo plano em `Info.plist`, `NSFileProtectionComplete` oferece a proteção máxima; caso background sync seja adicionado futuramente, o entitlement deverá ser ajustado para `NSFileProtectionCompleteUntilFirstUserAuthentication` com ADR dedicado. `AppDelegate.swift` + `IosStorageSecurity` aplicam `isExcludedFromBackup = true` e `.completeFileProtection` no banco SQLite, `-wal`, `-shm`, mídias e backups locais.
  3. **Zero Credenciais Hardcoded:** Removidos `defaultUrl` e `defaultAnonKey` de `SupabaseSyncService`; o app exige `--dart-define` (`SUPABASE_URL`/`SUPABASE_ANON_KEY`) ou configuração runtime em `FlutterSecureStorage`, operando 100% offline-first quando não configurado.
  4. **Atomicidade em `JwEmailService`:** `saveDraft`, `sendEmail` e `syncEmails` executam escrita em `inbox_entries` + `sync_queue` em transação única com incremento de `revision` e snapshot `_base` nos updates.
