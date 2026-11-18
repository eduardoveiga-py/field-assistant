# Field Assistant — Backlog Mestre de Estabilização e Evolução (FAES)

- **Baseline:** `master` @ `47cc87d` (Nota inicial: **4,46/10** — `NOT APPROVED`)
- **Meta de Aprovação:** Nota ponderada >= **9,7/10**, nenhuma dimensão < **9,0**, zero P0/P1 ativos, todos os hard gates aprovados.
- **Branch de Execução:** `stabilization/faes-master-program`

---

## Matriz de Backlog e Dependências

| ID | Prio | Fase | Frente | Escopo | Dependências | Status | Evidência |
|---|---|---|---|---|---|---|---|
| **FA-GOV-01** | P0 | 0 | Gov | Instalar `AGENTS.md` e `.agents/skills/field-assistant-engineering-standard/SKILL.md`; consolidar 3 logs ADR em `docs/engineering/DECISIONS.md`; criar `PRODUCT_AND_SYSTEM_MAP.md`, `MASTER_BACKLOG.md`, `impact-assessments/` e atualizar `SESSION_HANDOFF.md` | — | `DONE` | `AGENTS.md`, `.agents/skills/field-assistant-engineering-standard/SKILL.md`, `docs/engineering/DECISIONS.md`, `PRODUCT_AND_SYSTEM_MAP.md`, `MASTER_BACKLOG.md`, `impact-assessments/FA-PHASE-0-1-SECURITY-HARDENING.md` |
| **FA-CI-01** | P1 | 0 | I | Hardening de CI/CD: `contents: read` no CI, separar release, SHA pin nas Actions, `dart format --set-exit-if-changed`, PGlite em `master`/PRs, cobertura reportada, Dependabot/CodeQL/secret scanning/SBOM | `FA-GOV-01` | `DONE` | `.github/workflows/ci.yml` (`contents: read` global, `contents: write` só em `publish_release`, 100% SHA pin, `sql_safety` PGlite em `master`/PRs), `validation.yml`, `security-scan.yml`, `.github/dependabot.yml`, `tool/ci_coverage_check.py`, `tool/generate_sbom.py` |
| **FA-SEC-01** | P0 | 1 | A | Fechar fail-open E2EE: eliminar fallback plaintext para `sync_upsert_if_unchanged` e Storage não cifrado em produção; fazer respeitar `SyncPrivacyPolicy`; garantir que e-mails JW/Exchange não saiam em texto claro | `FA-GOV-01` | `PENDING` | — |
| **FA-SEC-04** | P0 | 1 | A | Isolamento total de contas: criar `SyncOwnerGuard` centralizado em `SupabaseSyncService`; remover espelhamento de chaves via `local_user` em `E2eeService`; corrigir `AuthSplashScreen`, logout e troca Conta A -> Conta B | `FA-GOV-01` | `PENDING` | — |
| **FA-SEC-09** | P0 | 1 | A | Corrigir path traversal em `saveMediaBytes` (`lib/sync/media_bytes_io.dart`) com validação estrita, contenção canônica e gravação atômica | `FA-GOV-01` | `PENDING` | — |
| **FA-BAK-01** | P0 | 1 | B | Corrigir `BackupService.restore`: proteger chaves de identidade/sync/E2EE no `app_kv_store` e impedir reinjeção cega da `sync_queue` legada | `FA-SEC-04` | `PENDING` | — |
| **FA-SEC-02** | P0 | 1 | A | Completar E2EE ponta a ponta: push cifrado, pull paginado por cursor monotônico `server_seq BIGSERIAL` + índice `(owner_id, server_seq)`, `EncryptedRecordCheckpoint` atômico, tombstones cifrados no `DELETE`, correção de `restoreVault` (não criar cofre silenciosamente), eliminação de fallbacks experimentais silenciosos | `FA-SEC-01`, `FA-SEC-04` | `PENDING` | — |
| **FA-SEC-03** | P0 | 1 | A | Criptografar mídias nos 4 buckets (`voice_notes`, `ticuna_audio`, `knowledge_vault`, `person_photos`) com `EncryptedMedia` (AES-256-GCM + manifesto + integridade) | `FA-SEC-01`, `FA-SEC-02` | `PENDING` | — |
| **FA-SEC-05** | P1 | 1 | A | E2EE Web (passphrase por sessão ou gate honesto desabilitando sync persistente na Web até solução validada) + remoção de credenciais hardcoded se aplicável | `FA-SEC-02` | `PENDING` | — |
| **FA-SEC-06** | P1 | 2 | A | SQLite criptografado (remover `sqlite3_flutter_libs` EOL; avaliar/adotar `sqlite3_multiple_ciphers` via Dart Build Hooks com ADR + migração) + File Protection iOS (`NSFileProtectionComplete`) + Android `allowBackup`/`dataExtractionRules` | `FA-BAK-01` | `PENDING` | — |
| **FA-SEC-07** | P1 | 2 | A | Substituir PIN SHA-256 1 rodada por KDF forte (PBKDF2-HMAC-SHA256 600k / Argon2id) + Backup v3 em isolate com >=600k iterações preservando compatibilidade v1/v2 | `FA-BAK-01` | `PENDING` | — |
| **FA-SEC-08** | P1 | 3 | A/B | Auditar logs/segredos + testes pgTAP/PGlite para RLS e 4 buckets Storage (anon, auth, cross-user) + remover RPCs legadas inseguras | `FA-SEC-02`, `FA-SEC-03` | `PENDING` | — |
| **FA-SYNC-01** | P1 | 3 | B | Reconciliar schema Drift vs Supabase (`mapEntityToRemoteTable` completo, constraints, índices, migrações) + CAS estrito | `FA-SEC-02` | `PENDING` | — |
| **FA-SYNC-02** | P1 | 3 | B | Detecção de conflitos de domínio (ex.: compromissos simultâneos), idempotência, retry seguro, testes 2 contas / 2 dispositivos / fault injection | `FA-SYNC-01` | `PENDING` | — |
| **FA-IOS-01** | P1 | 5 | C | Calendário iOS/iPadOS: avaliar/migrar `device_calendar` 4.3.3 -> `device_calendar_plus`/EventKit nativo preservando `CalendarProvider`; homologar em hardware Apple | `FA-SYNC-01` | `PENDING` | — |
| **FA-IOS-02** | P1 | 5 | C | Ditado e áudio: corrigir `SpeechListenOptions(onDevice: true)` quando offline solicitado, verificar pacote de idioma, transparência sobre Ticuna, testes de gravação/interrupção | `FA-GOV-01` | `PENDING` | — |
| **FA-MAP-01** | P1 | 4 | D | Map Engine Nível 2: avaliação objetiva MapLibre Native vs `flutter_map` vs Organic Maps; abstração `MapEngineAdapter`; contatos offline no mapa; endurecimento de Nominatim (cache SQLite/LRU, rate limit, User-Agent, aviso de privacidade) | `FA-GOV-01` | `PENDING` | — |
| **FA-MAP-02** | P1 | 4 | D | Mapas offline completos: manifesto imutável com SHA-256/bbox/zoom/licença/ODbL, download temporário -> validação -> instalação atômica -> rollback, eliminação das 22/23 URLs 404 | `FA-MAP-01` | `PENDING` | — |
| **FA-UX-01** | P1 | 4/8 | G | Corrigir `territoryMaps` ausente no `NavigationRail` (`>=768px`) + layouts adaptativos split/list-detail no iPad + acessibilidade (VoiceOver, Dynamic Type 200%, WCAG AAA) | `FA-FUNC-01` | `PENDING` | — |
| **FA-FUNC-01** | P1 | 6 | E | Unificar `FeatureRegistry` incluindo Inbox, Tasks/Projects e Knowledge; toggles respeitados em navegação, Hoje, busca, relatórios e atalhos sem apagar dados | `FA-GOV-01` | `PENDING` | — |
| **FA-FUNC-02** | P1 | 6 | E | Busca Global indexada/completa offline + Notificações locais nativas + fontes Ticuna locais (Noto Sans / Charis SIL) e testes Unicode | `FA-FUNC-01` | `PENDING` | — |
| **FA-ARCH-01** | P2 | 7 | F | Modularização incremental de `SupabaseSyncService`, `BackupService` e `AppRepository` com testes de caracterização | `FA-SEC-02`, `FA-BAK-01` | `PENDING` | — |
| **FA-ARCH-02** | P2 | 7 | F | Fatiamento incremental das telas monolíticas (`person_detail`, `appointments`, `contacts_map`, `settings`, `studies`, `dashboard`, `ticuna`, `inbox`) | `FA-TEST-01` | `PENDING` | — |
| **FA-PERF-01** | P2 | 9 | H | Remover full-scan de `_autoSync` a cada 2 min (orientado a eventos + backoff exponencial), dataset sintético reproduzível, isolates e índices SQL | `FA-ARCH-01` | `PENDING` | — |
| **FA-TEST-01** | P1 | 10 | I | Criar `integration_test/`, corrigir falso positivo de `e2ee_sync_flow_test.dart`, testes de 2 contas/2 dispositivos, fault injection, migrations v1->v8->v9 e regenerar `coverage/lcov.info` | `FA-SEC-02`, `FA-SEC-03`, `FA-SEC-04` | `PENDING` | — |
| **FA-REL-01** | P1 | 11 | J | Unificar identidade/metadados sem quebrar instalações, eliminar `@master`/tags inexistentes, auditar MPL-2.0 (`enough_mail`) e preparar opções de licença raiz, atualizar LGPD/README/SECURITY e checklist de release | Todas anteriores | `PENDING` | — |
