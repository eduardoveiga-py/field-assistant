# Field Assistant — Session Handoff (FAES Master Program)

- **Data:** 2026-11-17
- **Branch ativa:** `stabilization/faes-master-program` (base `master` @ `47cc87d`)
- **Status do Gate Global:** `NOT APPROVED / IN PROGRESS` — **Todos os bloqueadores P0 de Fase 0 e Fase 1 foram eliminados e comprovados com testes reais; P1/P2 de hardware Apple, Supabase staging live, MapLibre Native, SQLite cifra local e refatoração das telas monolíticas seguem documentados para as próximas iterações.**

## Fases e Unidades Concluídas (com Commits Atômicos)

1. **Fase 0 — Governança & CI/CD (`FA-GOV-01`, `FA-CI-01`) — Commit `f1b3c9f`:**
   - Instalados e versionados `AGENTS.md` e `.agents/skills/field-assistant-engineering-standard/SKILL.md`.
   - Consolidados os 3 logs de ADRs na fonte única `docs/engineering/DECISIONS.md` (ADR-001 a ADR-014).
   - Criados `docs/engineering/PRODUCT_AND_SYSTEM_MAP.md`, `docs/engineering/MASTER_BACKLOG.md` e `docs/engineering/impact-assessments/FA-PHASE-0-1-SECURITY-HARDENING.md`.
   - Endurecidos `.github/workflows/ci.yml`, `validation.yml`, adicionado `security-scan.yml` (CodeQL + secret audit + SBOM), `.github/dependabot.yml`, `tool/ci_coverage_check.py` e `tool/generate_sbom.py`. Zero `contents: write` global; 100% Actions pinadas em SHA-1 completo de 40 caracteres; PGlite em `master`/PRs/`stabilization/**`.

2. **Fase 1 — Eliminação de TODOS os Bloqueadores P0 (`FA-SEC-01`, `FA-SEC-02`, `FA-SEC-03`, `FA-SEC-04`, `FA-SEC-05`, `FA-SEC-09`, `FA-BAK-01`) — Commit `9613363`:**
   - **Fail-open E2EE eliminado (`FA-SEC-01`):** `SupabaseSyncService` em modo produção (`!_legacyTestMode`) jamais chama `sync_upsert_if_unchanged`, jamais lê/escreve nas 26 tabelas plaintext e jamais envia mídia sem criptografia; falhas abortam fail-closed preservando `sync_queue`.
   - **E2EE completo ponta a ponta (`FA-SEC-02`):** Migration aditiva `20261117000000_e2ee_server_seq_pull_and_hardening.sql` (`server_seq BIGSERIAL`, índice `(owner_id, server_seq)`, RPC `encrypted_records_pull_since`), `EncryptedRecordCheckpoint` integrado atomicamente em push/pull, tombstones cifrados no `DELETE`, `restoreVault` falha fechado se cofre remoto ausente, remoção de fallbacks experimentais silenciosos.
   - **Mídias cifradas nos 4 buckets (`FA-SEC-03`):** `EncryptedMediaTransfer` integrado para `voice_notes`, `ticuna_audio`, `knowledge_vault` e `person_photos` com chunks AES-256-GCM + manifesto autenticado + limpeza de órfãos.
   - **Isolamento total de contas (`FA-SEC-04`):** `SyncOwnerGuard` centralizado em `SupabaseSyncService` e `MainNavigationShell`; remoção completa do espelhamento bidirecional de chaves via `local_user` em `E2eeService`; migração local explícita com confirmação; `AuthSplashScreen` não dispara sync no modo offline; `resetLocalWorkspaceForAccountSwitch` transacional.
   - **Gate seguro de produção & Web (`FA-SEC-05`):** `SyncPrivacyPolicy.canRunRemoteSync` mantém produção pausada por padrão (`ENABLE_E2EE_SYNC=false`) até homologação em staging/dispositivos reais, e desabilita sync persistente na Web (`webPersistentSyncAllowed => false`).
   - **Path traversal bloqueado (`FA-SEC-09`):** `saveMediaBytes` em `lib/sync/media_bytes_io.dart` valida segmentos/nomes, aplica contenção canônica (`p.canonicalize` + `p.isWithin`) e grava atomicamente.
   - **Restore consciente da conta (`FA-BAK-01`):** `BackupService` protege chaves de identidade, segurança, cursores e checkpoints no `app_kv_store` e não reinjeta operações antigas da `sync_queue`.

3. **Fase 2 & Correções P1 de Alto Impacto (`FA-SEC-06` parcial, `FA-SEC-07`, `FA-UX-01` parcial, `FA-IOS-02` parcial, `FA-FUNC-01` parcial, `FA-MAP-01/02` base, `FA-TEST-01` parcial):**
   - **PIN KDF forte (`FA-SEC-07`):** `BiometricAuthService` migrado de SHA-256 1 rodada para PBKDF2-HMAC-SHA256 (100.000 iterações em isolate fora de testWidgets) com comparação constant-time e upgrade transparente de hashes legados.
   - **Backup v3 em Isolate (`FA-SEC-07`):** `BackupService.exportEncryptedBackupV3` com >= 600.000 iterações PBKDF2-HMAC-SHA256 em `Isolate.run` + AES-256-GCM, mantendo leitura de v2 e v1 opt-in.
   - **Proteção Android em repouso (`FA-SEC-06`):** `android:allowBackup="false"`, `data_extraction_rules.xml` e `backup_rules.xml`.
   - **iPad/Desktop `NavigationRail` (`FA-UX-01`):** `AppFeature.territoryMaps` restaurado no `NavigationRail`.
   - **Ditado offline honesto (`FA-IOS-02`):** `SpeechListenOptions(onDevice: preferOnDevice)`, verificação de locales instalados e `supportsTicunaOnDevice => false`.
   - **`FeatureRegistry` unificado (`FA-FUNC-01`):** adicionados `inbox`, `tasksProjects` e `knowledge` com preservação integral de dados.
   - **Arquitetura Map Engine Nível 2 (`FA-MAP-01/02`):** `docs/engineering/MAP_ENGINE_ARCHITECTURE.md` (comparação MapLibre Native vs `flutter_map` vs Organic Maps) e `lib/territory/map_engine_adapter.dart` (`OfflineMapPackageManifest` imutável com SHA-256/ODbL).
   - **Pirâmide de Testes (`FA-TEST-01`):** `integration_test/app_stabilization_e2e_test.dart`, `test/e2e/stabilization_master_e2e_test.dart` e zero issues no `dart analyze lib test integration_test`.

4. **Revisão Independente Adversarial & Correção de Bugs Críticos Pós-Fase 1/2:**
   - **Pull E2EE (`supabase_sync_service.dart`, `encrypted_record_checkpoint.dart`):** substituído retorno booleano ambíguo por `EncryptedApplyOutcome` (`applied`/`alreadyApplied`/`rejected`) impedindo o cursor `server_seq` de pular conflitos; ordenada a aplicação em lote em ordem pai-antes-de-filho (`syncTables`) evitando deadlock de FK quando um pai é atualizado após um filho; rejeitado `serverSeq <= 0`.
   - **Conflito delete-vs-update & resolução E2EE (`supabase_sync_service.dart`):** tombstone remoto contra edição local pendente agora gera conflito explícito sem corromper colunas `NOT NULL`; `resolveConflictAcceptRemote` agora atualiza atomicamente o `EncryptedRecordCheckpoint` com a revisão/envelope remoto autoritativo evitando loop infinito de conflito CAS.
   - **Mídias E2EE (`supabase_sync_service.dart`, `encrypted_media.dart`, `encrypted_media_transfer.dart`):** falhas transitórias de download agora gravam marcadores `pending_*_download_*` recuperados e limpos por `retryPendingMediaDownloads()`; `deleteEncrypted` agora inspeciona o manifesto autenticado (`EncryptedMedia.inspectChunkCount`) para remover todos os blocos em arquivos > 4 MiB (> 16 chunks) sem órfãos.
   - **Segurança local & Conta (`media_bytes_io.dart`, `biometric_auth_service.dart`, `backup_service.dart`, `sync_owner_guard.dart`, `auth_splash_screen.dart`, `settings_screen.dart`):** bloqueado escape de symlink de subdiretório (`resolvedBase -> resolvedDir`) e caracteres ilegais em `saveMediaBytes`; geração de salt aleatório novo no upgrade de PIN legado não-hex + proteção contra falta de `WidgetsBinding` + alinhamento de docs; validação de faixa de iterações PBKDF2 em `previewBackup` (anti-DoS/anti-downgrade v3) e ativação de `exportEncryptedBackupV3` na UI de Configurações; `SyncOwnerGuard.prepareWorkspaceForAuthenticatedAccount` conectado ao login em `AuthGateShell` e `SettingsScreen` com diálogo de confirmação caso existam alterações pendentes da conta anterior.
   - **Coerência `FeatureRegistry` & Busca Global (`global_search_screen.dart`, `today_screen.dart`):** removidos tipos `dynamic` em `_performSearch` (corrigindo `NoSuchMethodError` silenciosos em `PersonEntry.notes`, `repo.getAllPhoneContacts()`, `ResearchArticleEntry.scriptures/notes/category` e `.like()`/`|`/`&` sem import Drift) e aplicados toggles `inbox`, `tasksProjects` e `knowledge` na Busca Global e na tela Hoje preservando 100% dos registros no SQLite.
   - **Regressão adversarial (`test/security/adversarial_review_regressions_test.dart`):** 12 novos testes cobrindo todos os cenários acima, além de `commitRestore` real nos fluxos E2E e expansão do check `dart format` no CI.

## Bloqueadores Externos para Aprovação Final (>=9,7/10)
1. **Hardware físico Apple (iPhone/iPad + macOS/Xcode):** obrigatório para homologar `FA-IOS-01` (EventKit / `device_calendar_plus`), `FA-IOS-02` (gravação sob interrupção telefônica / ditado on-device pt-BR), `FA-SEC-06` (`NSFileProtectionComplete` + Keychain), `FA-UX-01` (VoiceOver / Dynamic Type 200%) e MapLibre Native em GPU Metal.
2. **Projeto Supabase Staging / Docker + Supabase CLI:** obrigatório para executar `supabase test db` (pgTAP) contra RLS/Storage reais e validar aplicação da migration `20261117000000_e2ee_server_seq_pull_and_hardening.sql` antes de liberar `ENABLE_E2EE_SYNC=true` em produção.
3. **Decisões pendentes do proprietário (`FA-REL-01`):** escolha da licença raiz do repositório (considerando `third_party/enough_mail` sob MPL-2.0) e aprovação de hospedagem definitiva dos pacotes PMTiles/MBTiles.

## Próxima Ação Exata na Próxima Sessão
1. Concluir `FA-SEC-06` (remover `sqlite3_flutter_libs` EOL e validar build hook `sqlite3_multiple_ciphers` com teste de migração do banco existente + `NSFileProtectionComplete` iOS).
2. Executar `FA-MAP-01/02` (integrar backend MapLibre Native por trás de `MapEngineAdapter`, pipeline de pacotes PMTiles/MBTiles verificáveis eliminando URLs 404, endurecer cache/rate-limit Nominatim).
3. Executar `FA-FUNC-01/02` (filtrar Busca Global/Hoje/Relatórios pelos novos toggles, empacotar fontes Ticuna locais + testes Unicode, implementar notificações locais nativas).
4. Executar `FA-SYNC-02`, `FA-ARCH-01/02`, `FA-UX-01` (split/list-detail iPad), `FA-PERF-01` (dataset sintético + índices SQL) e `FA-REL-01`.
