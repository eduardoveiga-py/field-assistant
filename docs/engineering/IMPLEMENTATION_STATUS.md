# INVENTÁRIO E ESTADO DE IMPLEMENTAÇÃO DAS FUNCIONALIDADES

Este documento mapeia o status real de cada funcionalidade do **Field Assistant**, contrastando código implementado, arquivos envolvidos, testes associados e problemas conhecidos.

---

## 1. Matriz de Funcionalidades

| # | Funcionalidade | Módulo / Arquivos Principais | Testes Associados | Status Real | Problemas / Riscos Conhecidos |
|---|---|---|---|---|---|
| **F01** | **Gestão de Contatos e Pessoas** | `lib/contacts/`<br>`lib/database/repository.dart`<br>`lib/ui/screens/people_screen.dart`<br>`lib/ui/screens/person_detail_screen.dart` | `test/widget_test.dart`<br>`test/recent_seeds_test.dart`<br>`test/doorstep_briefing_adversarial_test.dart` | **Concluído com Débito Técnico** | `person_detail_screen.dart` é monolítico (7.346 linhas); `people_screen.dart` (2.054 linhas). Mutações indiretas foram corrigidas para a outbox. |
| **F02** | **Registro de Visitas e Conversas** | `lib/database/repository.dart`<br>`lib/ui/screens/person_detail_screen.dart` | `test/unified_study_logging_test.dart`<br>`test/counting_rules_test.dart` | **Concluído** | Atualizações automáticas de data de último contato e próxima ação geram operação `UPDATE` para `people` na outbox. |
| **F03** | **Estudos Bíblicos e Sessões** | `lib/dashboard/counting_rules.dart`<br>`lib/ui/screens/studies_screen.dart`<br>`lib/database/tables.dart` | `test/counting_rules_test.dart`<br>`test/voice_note_parser_theocratic_test.dart` | **Concluído com Débito Técnico** | `studies_screen.dart` possui 2.713 linhas. Separação de contagem de múltiplos participantes validada por 20 testes formais. |
| **F04** | **Briefing na Porta (30s)** | `lib/contacts/doorstep_briefing_helper.dart`<br>`lib/ui/widgets/doorstep_briefing_card.dart` | `test/doorstep_briefing_test.dart`<br>`test/doorstep_briefing_adversarial_test.dart` | **Concluído** | Consolidação de lição, ponto, pendência, alvo e notas com deep link para JW Library. |
| **F05** | **Agenda Estilo Consultório** | `lib/appointments/availability_engine.dart`<br>`lib/ui/screens/appointments_screen.dart` | `test/availability_engine_test.dart`<br>`test/appointments/calendar_sync_test.dart`<br>`test/sync/u3_2_integrated_acceptance_test.dart` | **Concluído e Blindado Contra Concorrência** | Detecção atômica de sobreposição concorrente pós-sincronização no `SupabaseSyncService`, marcação visual de conflito/provisório na UI e atualização síncrona do payload da outbox na `sync_queue`. Check constraint PostgreSQL atualizado para `conflito`. |
| **F06** | **Integração Apple EventKit e Google Calendar** | `lib/appointments/calendar_sync_coordinator.dart`<br>`lib/appointments/apple_eventkit_provider.dart`<br>`lib/appointments/google_calendar_provider.dart` | `test/appointments/calendar_sync_test.dart` (22 testes) | **Concluído e Blindado** | Proteção contra consultas parciais truncadas (>25%) e fingerprint SHA-256 com regra de recorrência. Necessita teste em dispositivo físico com calendário ativo. |
| **F07** | **Calculadora de Ritmo de Pioneiro** | `lib/dashboard/pioneer_pace_calculator.dart`<br>`lib/ui/widgets/pioneer_pace_card.dart`<br>`lib/ui/screens/activities_screen.dart` | `test/pioneer_pace_calculator_test.dart`<br>`test/pioneer_pace_adversarial_test.dart` | **Concluído** | Testado contra anos bissextos, viradas de mês e estresse com TextScaler 2.0x sem overflow. |
| **F08** | **Destaque de Sementes Recentes** | `lib/contacts/recent_seeds_helper.dart`<br>`lib/ui/screens/people_screen.dart` | `test/recent_seeds_test.dart` | **Concluído** | Badge visual de tempo decorrido nos contatos cadastrados há <= 7 dias sem revisita e chip de filtro. |
| **F09** | **Botão Plano B Imediato** | `lib/appointments/plan_b_recommender.dart`<br>`lib/ui/widgets/plan_b_dialog.dart` | `test/plan_b_recommender_test.dart` | **Concluído** | Sugestão de 2 a 3 contatos mais próximos por Haversine geográfico e horários habituais ao desmarcar visita. |
| **F10** | **Cronômetro Auto-Corretivo** | `lib/activities/auto_corrective_timer_logic.dart`<br>`lib/ui/screens/activities_screen.dart` | `test/auto_corrective_timer_test.dart` | **Concluído** | Persistência de timer no SQLite; alerta amigável ao ultrapassar 4h ininterruptas com diálogo de ajuste. |
| **F11** | **Notas de Voz e Ditado** | `lib/voice_notes/audio_recording_service.dart`<br>`lib/voice_notes/voice_dictation_service.dart`<br>`lib/voice_notes/voice_note_parser.dart` | `test/voice_notes_test.dart` (15 testes)<br>`test/sync/u3_2_integrated_acceptance_test.dart` | **Concluído e Blindado** | Limite real de 30 segundos com parada física do hardware no driver nativo (`record.stop()`), barreira de cancelamento (`_isCancelled`), eliminação de áudios órfãos no descarte da modal e fallback explícito de UI caso o pacote de ditado offline não esteja baixado no iOS, preservando o arquivo de áudio. |
| **F12** | **Backup e Restauração Criptografados** | `lib/settings/backup_service.dart`<br>`lib/ui/screens/settings_screen.dart` | `test/backup_service_test.dart` (18 testes) | **Concluído e Blindado** | AES-256 GCM + PBKDF2 (100k iterações); staging em 3 etapas com rollback transacional seguro de áudios; fallback para `/tmp` eliminado; suporte a snapshot em Web. |
| **F13** | **Sincronização Offline-First Supabase** | `lib/core/app_config.dart`<br>`lib/core/supabase_initializer.dart`<br>`lib/sync/supabase_sync_service.dart`<br>`lib/sync/sync_engine.dart`<br>`supabase/migrations/` | `test/core/app_config_test.dart` (9 testes)<br>`test/core/supabase_initializer_test.dart` (12 testes)<br>`test/sync/supabase_lifecycle_test.dart` (18 testes)<br>`test/sync/supabase_u3_schema_storage_test.dart` (15 testes)<br>`test/sync/supabase_soft_delete_test.dart` (11 testes)<br>`test/sync/supabase_hardening_u3_2_test.dart` (17 testes)<br>`test/sync/u3_2_integrated_acceptance_test.dart` (11 testes)<br>`test/supabase_sync_service_test.dart` (13 testes)<br>`test/sync_engine_test.dart` (5 testes) | **Concluído e Blindado (Bloqueadores P0-01, P0-02, P0-03, U3.1 e U3.2 Resolvidos)** | Injeção centralizada segura (U1), boot desacoplado não-bloqueante (U2), travas reentrantes `isSyncing`, durabilidade outbox e 3-way merge, schema remoto completo com as 10 tabelas, bucket privado de áudio de 10 MB e isolamento RLS estrito (U3), exclusão física abolida, tombstones e barreiras contra ressurreição em todas as 10 tabelas sincronizadas (U3.1), 3-way merge com `baseData` real em todos os managers, normalização profunda por valor de coleções em tags, preservação de áudio local, normalização JSONB, RLS Storage estrito por nota de voz, retentativa resiliente de downloads pendentes e requeue seguro (U3.2), detecção de sobreposição na agenda e parada física aos 30s. Total da suíte do app: 602 testes 100% aprovados. |
| **F14** | **Banco Local SQLite / Drift** | `lib/database/app_database.dart`<br>`lib/database/connection/native.dart`<br>`lib/database/connection/connection_web.dart` | `test/database_integrity_test.dart` | **Concluído com Ressalva P1 de Migrações** | Foreign Keys e WAL ativos. Migrações históricas usam `catch (_) {}` que silenciam falhas de alteração de schema. Banco nativo não possui criptografia em repouso por chave local. |
| **F15** | **Mapa de Contatos e Território** | `lib/ui/screens/contacts_map_screen.dart`<br>`lib/territory/` | `test/unified_study_logging_test.dart` | **Concluído** | Reprojeção matemática de mapa sem ballooning; respeita a diretriz de não substituir a solução externa Hourglass. |
| **F16** | **Configurações e Customização de Telas** | `lib/ui/screens/customize_features_screen.dart`<br>`lib/settings/app_settings_manager.dart` | `test/widget_test.dart` | **Concluído** | Feature flags ocultam itens na interface sem nunca executar migrações destrutivas de dados históricos. |

---

## 2. Quadro Resumo de Implementação
- **Funcionalidades Totais Auditadas:** 16
- **Totalmente Estabilizadas e Testadas:** 13 (81,25%)
- **Parcialmente Implementadas com Débito / Risco P1:** 3 (18,75% — Concorrência na Agenda, Gravação de Áudio/Transcrição, Migrações do Banco Local)
- **Em Estabilização P0:** 0 (0% — Bloqueadores P0-01, P0-02 e P0-03 100% resolvidos)

---

## 3. Registro de Execução da Fase 2 (Estabilização P0)

### Unidade U1 — Configuração e Injeção de Ambiente
- **Identificador:** `FASE2-U1`
- **Commit Base:** `19815c4`
- **Branch Dedicada:** `stabilization/u1-env-config`
- **Arquivos Alterados / Criados:**
  - `lib/core/app_config.dart` (Novo: modelo centralizado imutável, validador estrito de URL/chaves, bloqueio abrangente de credenciais privilegiadas, mascaramento de segredos em logs, normalização de trailing slash e userInfo masking)
  - `lib/sync/supabase_sync_service.dart` (Integração com `AppConfig`, eliminação de `String.fromEnvironment` duplicados e campos delegados)
  - `test/core/app_config_test.dart` (Novo: 9 testes cobrindo todos os cenários obrigatórios e ataques de borda)
  - `.env.example`, `.env.homolog.example`, `.env.prod.example` (Templates versionados seguros sem segredos)
  - `.gitignore` (Proteção estrita para `.env*` garantindo que `.env.prod` e `.env.homolog` jamais sejam comitados)
  - `docs/ENVIRONMENT_CONFIGURATION.md` (Documentação formal de injeção e flags)
  - `scripts/run_web.ps1`, `scripts/run_web.bat`, `scripts/run_tests.ps1` (Suporte a `-EnvFile`/`-env`, detecção automática de `.env` e `--fatal-infos`)
  - `README.md` (Atualização da contagem de testes para 517 e comandos)
- **Testes Executados:** 517 testes aprovados (`flutter test`), 0 falhas, 0 issues de análise estática (`dart analyze lib test --fatal-infos`).
- **Resultado:** Aprovado em U1.
- **Riscos Remanescentes:** Supabase ainda não é inicializado em `main.dart` (P0-01, escopo de U2); Schema SQL remoto incompleto (P0-02, escopo de U3).
- **Dependências:** Autorização formal para prosseguir para a Unidade U2.

### Unidade U2 — Inicialização do Supabase, Ciclo de Vida e Resiliência Offline
- **Identificador:** `FASE2-U2`
- **Commit Base:** `9da0f21` (merge de U1)
- **Branch Dedicada:** `stabilization/u2-supabase-lifecycle`
- **Arquivos Alterados / Criados:**
  - `lib/core/supabase_initializer.dart` (Orquestrador centralizado, enum de estados granular, trava assíncrona de concorrência com `Completer`, sanitização de credenciais, probe ativo `checkConnectivity`, preservação de `authenticationRequired`, listener de auth state, e providers Riverpod dedicados)
  - `lib/main.dart` (Ordem de boot estrita: SQLite e repositório inicializam primeiro; inicialização remota do Supabase ocorre assíncrona e desacoplada via `unawaited`; `supabaseSyncServiceProvider` ativado na raiz)
  - `lib/database/repository.dart` (Ajustado `getPendingSyncOperations()` para incluir operações `failed` com menos de 5 tentativas, garantindo durabilidade da outbox)
  - `lib/sync/supabase_sync_service.dart` (Implementado `WidgetsBindingObserver` para resume de ciclo de vida em background, escuta a `stateStream` para reconexão automática, trava de reentrância `isSyncing`, blindagem 3-way merge em `_applyRemoteRecord`, backoff exponencial com jitter clamped a 300s, aborto seguro de loop em erros de rede e proteção contra `AssertionError` via `clientOrNull`)
  - `test/core/supabase_initializer_test.dart` (12 testes cobrindo modo offline, rejeição de credenciais inválidas, idempotência, concorrência simultânea, timeout e falhas de socket, probe de reachability, preservação de `authenticationRequired`, notificação de rede e Riverpod)
  - `test/sync/supabase_lifecycle_test.dart` (18 testes cobrindo boot 100% offline sem exceções, durabilidade da outbox em falhas transitórias, limite de 5 retentativas sem starvation, cálculo de backoff com jitter, recuperação de conexão, background resume, transações locais concorrentes, trava `isSyncing`, resiliência a falhas de rede, 3-way merge para failed ops, auto-reconexão via stream, interrupção em erros 5xx/503 do PostgREST, blindagem contra sobrescrita com attempts >= 5, status com fila vazia em modo offline/desconfigurado, mensagens diagnósticas precisas em `sync()`, detecção de erros transitórios alfanuméricos e cancelamento de busca remota em instabilidade)
  - Documentação em `docs/engineering/` (ADR-011 adicionado em `DECISION_LOG.md`, matrizes atualizadas em `PRODUCTION_READINESS.md`, `SESSION_HANDOFF.md` e `REGRESSION_GUARDRAILS.md`)
- **Testes Executados:** 547 testes aprovados (`flutter test`), 0 falhas, 0 issues de análise estática (`dart analyze lib test --fatal-infos`), build web release aprovado (`flutter build web --release`).
- **Resultado:** Aprovado em U2. Bloqueador P0-01 resolvido.
- **Riscos Remanescentes:** Schema SQL remoto incompleto (P0-02, escopo da Unidade U3).
- **Próxima Ação:** Executada Unidade U3 (Schema SQL remoto, Storage e validação RLS).

### Unidade U3 — Schema Remoto Supabase, Storage e Validação RLS
- **Identificador:** `FASE2-U3`
- **Commit Base:** `8e6a1ff`
- **Branch Dedicada:** `stabilization/u3-supabase-schema`
- **Arquivos Alterados / Criados:**
  - `supabase/migrations/20261102000000_u3_missing_tables_storage.sql` (Novo: DDL de `voice_notes`, `phone_contacts` e `territory_landmarks` com UUID pk, `owner_id REFERENCES auth.users(id) DEFAULT auth.uid()`, FKs para `people`/`visits`/`bible_studies`, índices de busca/auditoria, RLS estrito por operação SELECT/INSERT/UPDATE/DELETE, triggers de auditoria `updated_at`/`revision`, bucket privado `voice_notes` de 10 MB e políticas RLS de storage)
  - `lib/database/repository.dart` (Adicionado método `requeueFailedSyncOperations()` para recuperação segura e supervisionada de operações com falha sem descarte de histórico)
  - `test/sync/supabase_u3_schema_storage_test.dart` (Novo: 15 testes cobrindo DDL, índices, bucket privado, contratos RLS positivo, negativo e anônimo, Storage RLS, serialização de payloads das 3 tabelas, inbound pull com 3-way merge e procedimento de requeue)
  - `docs/engineering/DECISION_LOG.md` (ADR-012 documentado)
  - `docs/engineering/IMPLEMENTATION_STATUS.md`, `PRODUCTION_READINESS.md`, `SESSION_HANDOFF.md`, `REGRESSION_GUARDRAILS.md`, `README.md`
- **Testes Executados:** 562 testes aprovados (`flutter test`), 0 falhas, 0 issues de análise estática (`dart analyze lib test --fatal-infos`), build web release aprovado (`flutter build web --release`).
- **Resultado:** Aprovado em U3. Bloqueador P0-02 categoricamente eliminado.
- **Riscos Remanescentes:** Validação em infraestrutura Supabase Cloud / staging real; validação física em iPhone/iPad (Fase 4); concorrência remota na agenda (P1); parada do microfone (P1).
- **Próxima Ação:** Execução da Unidade U3.1 (Integridade de exclusões, tombstones e sincronização multidispositivo).

### Unidade U3.1 — Integridade de Exclusões, Tombstones e Sincronização Multidispositivo
- **Identificador:** `FASE2-U3.1`
- **Commit Base:** `332975e`
- **Branch Dedicada:** `stabilization/u3.1-soft-delete`
- **Arquivos Alterados / Criados:**
  - `lib/sync/supabase_sync_service.dart` (Eliminação de `activeClient.from(table).delete()`; implementação de soft delete via `.update(tombstonePayload)` com `deleted_at`, `updated_at` e `revision`; blindagem de operações `INSERT`/`UPDATE` na outbox preservando `deleted_at` caso o registro local já esteja soft-deletado; prevenção de ressurreição no cliente em `_applyRemoteRecord`; cursor composto `(updated_at, id)` via PostgREST `.or(...)` com barreira de erro de aplicação; desacoplamento de aplicação local de tombstones com atualização atômica de `deletedAt`, `updatedAt` e `revision` no Drift SQLite sem disparar loops de outbox; defaults resilientes em `_prepareEntryMap` para campos obrigatórios de todas as 10 entidades)
  - `lib/database/repository.dart` (Inclusão explícita de `updatedAt` e `revision` em payloads de `DELETE` na outbox para `people`, `visits`, `bible_studies`, `appointments` e `activity_records`)
  - `lib/voice_notes/voice_notes_manager.dart` (Inclusão de `updated_at` em payload de `DELETE` de `voice_notes`)
  - `lib/contacts/phone_contacts_manager.dart` (Inclusão de `updated_at` em payload de `DELETE` de `phone_contacts`)
  - `lib/territory/landmark_manager.dart` (Inclusão de `updated_at` em payload de `DELETE` de `territory_landmarks`)
  - `supabase/migrations/20261102010000_u3_1_soft_delete_tombstones.sql` (Novo: Trigger function PostgreSQL `handle_soft_delete_and_resurrection_guard()` vinculada a todas as 10 tabelas sincronizadas, bloqueando que `deleted_at` seja anulado por upserts desatualizados, com tratamento seguro de NULL e rollback documentado)
  - `test/sync/supabase_soft_delete_test.dart` (Novo: 11 testes cobrindo propagação de tombstones A -> B, prevenção de ressurreição, idempotência, resiliência a falhas de rede, cursor incremental sem omissão de tombstones simultâneos, ausência de loop de outbox, validação em todas as 10 tabelas sincronizadas, tombstones parciais com colunas obrigatórias, integridade atômica de metadados, rejeição de ressurreição com nulos e concorrência com DELETE local)
  - `docs/engineering/ADR_U3_1_SOFT_DELETE_TOMBSTONES.md` (ADR-013 documentado)
  - `docs/engineering/DECISION_LOG.md`, `MASTER_CONTEXT.md`, `IMPLEMENTATION_STATUS.md`, `PRODUCTION_READINESS.md`, `SESSION_HANDOFF.md`, `REGRESSION_GUARDRAILS.md`
- **Testes Executados:** 573 testes aprovados (`flutter test`), 0 falhas, 0 issues de análise estática (`dart analyze lib test --fatal-infos`), build web release aprovado (`flutter build web --release`).
- **Resultado:** Aprovado em U3.1. Exclusão física remota abolida e integridade de tombstones garantida.
- **Riscos Remanescentes:** Validação em cluster Supabase Cloud real (testes atuais utilizam mock client determinístico e Drift SQLite in-memory); concorrência remota na agenda (P1); parada do microfone (P1).
- **Próxima Ação:** Execução da Unidade U3.2 (Hardening definitivo e resiliência offline).

### Unidade U3.2 — Hardening Definitivo de Sincronização e Resiliência Offline
- **Identificador:** `FASE2-U3.2`
- **Commit Base:** `7b9316f`
- **Branch Dedicada:** `stabilization/u3.2-definitive-hardening`
- **Arquivos Alterados / Criados:**
  - `lib/contacts/phone_contacts_manager.dart` (Inclusão de snapshot `_base: existing.toMap()`, incremento monotônico de `revision`, e proteção atômica via `db.transaction`)
  - `lib/territory/landmark_manager.dart` (Inclusão de snapshot `_base: existing.toMap()`, incremento monotônico de `revision`, e proteção atômica via `db.transaction`)
  - `lib/voice_notes/voice_notes_manager.dart` (Inclusão de snapshot `_base: existing.toMap()`, incremento monotônico de `revision`, e proteção atômica via `db.transaction`)
  - `lib/sync/supabase_sync_service.dart` (Preservação de `audioFilePath` local em `_updateLocalEntry` e `_applyRemoteRecord` se o remoto for nulo/ausente; 3-way merge determinístico com `baseData` real; normalização de `tags` JSONB para List nativo em `toRemotePayload`; normalização de booleans de whatsapp/social; notifiers Riverpod `outboxRecoveryProvider` e `failedSyncOperationsStreamProvider`; `@visibleForTesting applyRemoteRecordForTesting`)
  - `lib/database/repository.dart` (Operação de requeue atômica com `db.transaction`, retorno precoce se `operationIds.isEmpty`, e clamping de tentativas `attempts < 4 ? attempts : 4`)
  - `lib/core/supabase_initializer.dart` (`retryInitialization()` e `retrySupabaseInitializationIfConfigured()` para recuperação no boot / ISSUE-U2-01)
  - `lib/core/app_config.dart` (`AppConfig.unconfigured()` factory para inicialização segura em testes e modo offline)
  - `lib/database/app_database.dart` (`AppLogger.error` e `rethrow` de erros fatais de DDL em migrações locais)
  - `supabase/migrations/20261102020000_u3_2_storage_and_hardening.sql` (Políticas de Supabase Storage RLS com verificação estrita de ownership de notas de voz contra tabela `voice_notes`, regex multi-extensão `.mp4`/`.aac`/`.m4a`, e substituição de `timezone('utc'::text, now())` por `now()` em colunas/triggers `TIMESTAMPTZ`)
  - `test/sync/supabase_hardening_u3_2_test.dart` (Novo: 13 testes cobrindo BUG-U3-02 a BUG-U3-10, ISSUE-U2-01, ISSUE-U2-02 e validações de migração)
- **Testes Executados:** 586 testes aprovados (`flutter test`), 0 falhas, 0 issues de análise estática (`dart analyze lib test --fatal-infos`), build web release aprovado (`flutter build web --release`).
- **Resultado:** Aprovado em U3.2. Sincronização 3-way merge blindada com `baseData` real, RLS Storage estrito, integridade de áudio local e recuperação robusta da outbox.
- **Riscos Remanescentes:** Validação em cluster Supabase Cloud real com credenciais ativas; concorrência remota na agenda (P1); parada de microfone aos 30s (P1).
- **Próxima Ação:** Conclusão da Fase 2 e transição supervisionada.

---

## 4. Matriz de Entidades Locais com Auditoria Não Sincronizadas

| Entidade Local (Drift) | Tabela Remota (Supabase) | Presente no Sincronizador? | Possui Outbox? | Necessário em Outros Aparelhos? | Risco de Inconsistência Funcional / Recomendação |
|---|---|:---:|:---:|:---:|---|
| `FamilyTies` (`family_ties`) | Inexistente | Não | Não | Sim (grau de parentesco entre contatos) | **Baixo/Médio:** Contatos sincronizam, mas o vínculo de parentesco (ex: pai/filho) permanece apenas no aparelho de origem. Recomendada unidade futura para inclusão no schema. |
| `PersonPhotos` (`person_photos`) | Inexistente | Não | Não | Recomendável | **Baixo:** Fotos de perfil são armazenadas apenas localmente. Não bloqueia o uso ministerial principal. |
| `TerritorySectors` (`territory_sectors`) | Inexistente | Não | Não | Sim | **Médio:** Subdivisões territoriais internas; o aplicativo delega território primário para Hourglass, mas anotações de setor não sincronizam. |
| `MinistryExperiences` (`ministry_experiences`) | Inexistente | Não | Não | Desejável | **Baixo:** Relatos de experiências memoráveis de campo salvos localmente. |
| `PersonPublications` (`person_publications`) | Inexistente | Não | Não | Sim | **Médio:** Histórico de publicações deixadas com um morador; visitas registram o texto, mas a tabela normalizada não sobe. |
| `ResearchArticles` (`research_articles`) | Inexistente | Não | Não | Opcional | **Baixo:** Notas temáticas e artigos pesquisados; uso pessoal local. |
| `ResearchTags` (`research_tags`) | Inexistente | Não | Não | Opcional | **Baixo:** Tags de categorização de artigos de pesquisa. |
| `StudentManualOrder` (`student_manual_order` / `user_kv_store`) | Inexistente | Não | Não | Opcional | **Baixo:** Ordem de classificação manual da lista de estudantes para partes na reunião; salvo localmente no KV store. Risco desprezível. |
| `ExternalCalendarEvents` | Inexistente | Não (por design) | Não (por design) | Não (local do device) | **Nenhum (Conforme):** Tabela de cache do Apple EventKit / Google Calendar nativo de cada aparelho físico. |
| `CalendarEventLinks` | Inexistente | Não (por design) | Não (por design) | Não (local do device) | **Nenhum (Conforme):** Mapeamento de IDs externos do sistema operacional específico. |


