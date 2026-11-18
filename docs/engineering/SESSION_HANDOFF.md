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

3. **Fase 2 — Criptografia em Repouso, Backup v3 & iOS Data Protection (`FA-SEC-06`, `FA-SEC-07`, `FA-SEC-08`, `FA-BAK-01`, `FA-IOS-02`) — Commits `7eda064`, `fe78264`, `6cb9a20`, `279c060`:**
   - **PIN KDF forte & Backup v3 (`FA-SEC-07`):** PBKDF2-HMAC-SHA256 (100k iterações) no PIN e >=600.000 iterações em isolate com salt aleatório no backup v3.
   - **SQLite em repouso (`FA-SEC-06`):** `sqlite3mc` (SQLite3MultipleCiphers) via build hooks do Dart, migração não-destrutiva de banco plaintext WAL/SHM com backup `.pre_enc.bak` e rollback automático.
   - **iOS Data Protection (`FA-SEC-06`):** `Runner.entitlements` com `NSFileProtectionCompleteUntilFirstUserAuthentication` (ADR-015) e `isExcludedFromBackup = true` em `AppDelegate.swift` para SQLite e anexos.
   - **Zero credenciais hardcoded (`FA-SEC-08`):** remoção de `defaultUrl` e `defaultAnonKey` de `SupabaseSyncService`; modo offline-first limpo.
   - **Atomicidade de e-mail (`FA-SEC-08`):** `JwEmailService` transacional com `_base` e incremento de `revision`.
   - **Suíte adversarial de backup (`FA-BAK-01`):** `test/backup/backup_adversarial_test.dart` comprovando rejeição de senha errada, bit-flip em GCM, arquivo corrompido, mídia ausente e rollback seguro.

4. **Fase 3 — Reconciliação Drift vs Supabase & Conflitos de Domínio (`FA-SYNC-01`, `FA-SYNC-02`, `FA-SEC-08`) — Commit `8e9b524`:**
   - **Revogação de RPC legada (`FA-SEC-08`):** Migration `20261118000000_revoke_legacy_sync_upsert.sql` revogando `EXECUTE` de `public.sync_upsert(TEXT, JSONB)` para `PUBLIC, anon, authenticated` (testada via PGlite).
   - **Suíte pgTAP (`FA-SEC-08`):** Arquivo `supabase/tests/01_rls_e2ee_storage_security.sql` com 24 asserções de RLS, E2EE e 4 buckets de Storage.
   - **Mapeamento Drift vs Supabase (`FA-SYNC-01`):** `mapEntityToRemoteTable` cobre todas as 26 tabelas sincronizadas em snake_case, camelCase, PascalCase, singular e plural.
   - **Detecção de conflitos de agenda (`FA-SYNC-02`):** `AppointmentDomainConflictDetector` detecta sobreposição temporal entre compromissos distintos após pull, marca `status = 'conflito'` sem sobrescrever ou apagar nenhum registro, e grava auditoria no `app_kv_store`.

5. **Fase 4 — Map Engine Nível 2 & Experiência Cartográfica (`FA-MAP-01`, `FA-MAP-02`) — Commit `adf93ed`:**
   - **Eliminação de URLs 404 (`FA-MAP-02`):** Remoção do fallback `mbtiles-v1/$id.mbtiles`; status explícito de pacote (`isAvailableForDownload` vs `Em preparação`); botão inteligente em `download_maps_screen.dart` que direciona pacotes sem mirror para URL personalizada / importação local sem crash.
   - **Eliminação de corte diagonal no mapa (`FA-MAP-01`):** Expansão do canvas lógico (`gridHalfSize >= 16`) e buffer de tiles (`tileBuffer = 3`) cobrindo 100% da viewport sob rotação máxima sem triângulos pretos diagonais ou limitação de altura.
   - **Rotação fluida e bússola:** Suporte a rotação por mouse com botão direito e Shift-drag no desktop/web; toque na bússola (`Icons.navigation_rounded`) reseta suavemente para o Norte (0°).

6. **Fase 6 — Notificações Locais & Linguística Ticuna (`FA-FUNC-01`, `FA-FUNC-02`) — Commit `e7e3930`:**
   - **Lembretes locais nativos (`FA-FUNC-01`):** Criação de `LocalReminderService` com agendamento persistente no SQLite/KV, cálculo de antecedência (lead time) e sincronização automática a partir de compromissos futuros da agenda ministerial.
   - **Língua Ticuna (`FA-FUNC-02`):** `test/ticuna/ticuna_unicode_audio_test.dart` cobrindo os 12 glifos canônicos (`ĩ, ü̃, ü̃́, ũ, ã́, ẽ` e maiúsculas), normalização e preservação fonética de `Duü̃`.

7. **Fase 9 — Performance & Otimização de Índices (`FA-PERF-01`) — Commit `22ec46c`:**
   - **Índices de alta performance no Drift SQLite:** Adicionados índices condicionais `idx_people_coords` (`latitude, longitude`), `idx_appointments_start_time`, `idx_appointments_person_id` e `idx_visits_person_id` garantidos em `_ensurePerformanceIndexes()`, mantendo 100% de compatibilidade retroativa com migrações desde a v1.
   - **Benchmark de dataset sintético:** Suíte automatizada `test/perf/synthetic_dataset_benchmark_test.dart` comprovando inserção em lote de 5.000 contatos, busca indexada por nome e filtro espacial por bounding box respondendo em milissegundos.

8. **Fase 8 — UX Adaptativa iPad & Master-Detail (`FA-UX-01`) — Commit `cca9857`:**
   - **Split View Master-Detail nativo:** Em telas grandes (`constraints.maxWidth >= 900px`), `PeopleScreen` exibe painel mestre de contatos (420px) com seleção destacada (`BorderSide(color: primaryBlue, width: 2)`) e painel de detalhe `PersonDetailScreen` integrado à direita com placeholder informativo quando desmarcado.
   - **Suíte de testes de layout adaptativo:** `test/ui/people_screen_adaptive_test.dart` validando tanto o layout de coluna única no iPhone (`400x800`) quanto o Master-Detail split-view no iPad (`1024x768`).

9. **Fase 7 & Fase 11 — Decomposição Modular e Política LGPD (`FA-ARCH-02`, `FA-REL-01`) — Commit `0f135ad`:**
   - **Extração de `DynamicTileLayer`:** Decomposição modular da tela gigante `contacts_map_screen.dart` (-177 LOC) com extração de `DynamicTileLayer` para `lib/ui/widgets/map/dynamic_tile_layer.dart`, mantendo isolamento de repaint e estabilidade sob rotação/arraste.
   - **Política de Conformidade LGPD:** Criação de `docs/privacy/LGPD_COMPLIANCE.md` cobrindo bases legais, minimização de dados, criptografia em repouso (`sqlite3mc`) e trânsito (E2EE fail-closed), isolamento de contas, exercícios de direitos dos titulares (Art. 18) e auditoria de licenças de terceiros.

10. **Revisão Independente Adversarial & Correção de Bugs Críticos:**
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
