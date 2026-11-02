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
| **F05** | **Agenda Estilo Consultório** | `lib/appointments/availability_engine.dart`<br>`lib/ui/screens/appointments_screen.dart` | `test/availability_engine_test.dart`<br>`test/appointments/calendar_sync_test.dart` | **Parcialmente Concluído (Gargalo de Concorrência)** | `appointments_screen.dart` possui 4.379 linhas. Validação local impede colisões locais, mas reservas simultâneas entre dois dispositivos offline geram colisões silenciosas pós-sincronização. |
| **F06** | **Integração Apple EventKit e Google Calendar** | `lib/appointments/calendar_sync_coordinator.dart`<br>`lib/appointments/apple_eventkit_provider.dart`<br>`lib/appointments/google_calendar_provider.dart` | `test/appointments/calendar_sync_test.dart` (22 testes) | **Concluído e Blindado** | Proteção contra consultas parciais truncadas (>25%) e fingerprint SHA-256 com regra de recorrência. Necessita teste em dispositivo físico com calendário ativo. |
| **F07** | **Calculadora de Ritmo de Pioneiro** | `lib/dashboard/pioneer_pace_calculator.dart`<br>`lib/ui/widgets/pioneer_pace_card.dart`<br>`lib/ui/screens/activities_screen.dart` | `test/pioneer_pace_calculator_test.dart`<br>`test/pioneer_pace_adversarial_test.dart` | **Concluído** | Testado contra anos bissextos, viradas de mês e estresse com TextScaler 2.0x sem overflow. |
| **F08** | **Destaque de Sementes Recentes** | `lib/contacts/recent_seeds_helper.dart`<br>`lib/ui/screens/people_screen.dart` | `test/recent_seeds_test.dart` | **Concluído** | Badge visual de tempo decorrido nos contatos cadastrados há <= 7 dias sem revisita e chip de filtro. |
| **F09** | **Botão Plano B Imediato** | `lib/appointments/plan_b_recommender.dart`<br>`lib/ui/widgets/plan_b_dialog.dart` | `test/plan_b_recommender_test.dart` | **Concluído** | Sugestão de 2 a 3 contatos mais próximos por Haversine geográfico e horários habituais ao desmarcar visita. |
| **F10** | **Cronômetro Auto-Corretivo** | `lib/activities/auto_corrective_timer_logic.dart`<br>`lib/ui/screens/activities_screen.dart` | `test/auto_corrective_timer_test.dart` | **Concluído** | Persistência de timer no SQLite; alerta amigável ao ultrapassar 4h ininterruptas com diálogo de ajuste. |
| **F11** | **Notas de Voz e Ditado** | `lib/voice_notes/audio_recording_service.dart`<br>`lib/voice_notes/voice_dictation_service.dart`<br>`lib/voice_notes/voice_note_parser.dart` | `test/voice_notes_test.dart` (15 testes) | **Parcialmente Concluído (Bug Crítico de Parada)** | **Bug P1:** O timer de 30 segundos apenas cancela a contagem mas NÃO interrompe o hardware de gravação. Transcrição "offline" depende de modelos do sistema operacional que podem não estar baixados. |
| **F12** | **Backup e Restauração Criptografados** | `lib/settings/backup_service.dart`<br>`lib/ui/screens/settings_screen.dart` | `test/backup_service_test.dart` (18 testes) | **Concluído e Blindado** | AES-256 GCM + PBKDF2 (100k iterações); staging em 3 etapas com rollback transacional seguro de áudios; fallback para `/tmp` eliminado; suporte a snapshot em Web. |
| **F13** | **Sincronização Offline-First Supabase** | `lib/core/app_config.dart`<br>`lib/core/supabase_initializer.dart`<br>`lib/sync/supabase_sync_service.dart`<br>`lib/sync/sync_engine.dart` | `test/core/app_config_test.dart` (9 testes)<br>`test/core/supabase_initializer_test.dart` (10 testes)<br>`test/sync/supabase_lifecycle_test.dart` (7 testes)<br>`test/supabase_sync_service_test.dart`<br>`test/sync_engine_test.dart` | **Em Estabilização (P0-03 Resolvido em U1; P0-01 Resolvido em U2; Bloqueado apenas por P0-02)** | **U1 e U2 Concluídas e Blindadas:** Injeção segura via `AppConfig`, inicialização não-bloqueante desacoplada em `main.dart`, orquestrador `SupabaseInitializer` com lock de concorrência e zero `AssertionError`, ciclo de vida `WidgetsBindingObserver`, durabilidade garantida da outbox, backoff exponencial com jitter e pausa em 5 falhas. Pendente U3 (Schema remoto/Storage). |
| **F14** | **Banco Local SQLite / Drift** | `lib/database/app_database.dart`<br>`lib/database/connection/native.dart`<br>`lib/database/connection/connection_web.dart` | `test/database_integrity_test.dart` | **Concluído com Ressalva P1 de Migrações** | Foreign Keys e WAL ativos. Migrações históricas usam `catch (_) {}` que silenciam falhas de alteração de schema. Banco nativo não possui criptografia em repouso por chave local. |
| **F15** | **Mapa de Contatos e Território** | `lib/ui/screens/contacts_map_screen.dart`<br>`lib/territory/` | `test/unified_study_logging_test.dart` | **Concluído** | Reprojeção matemática de mapa sem ballooning; respeita a diretriz de não substituir a solução externa Hourglass. |
| **F16** | **Configurações e Customização de Telas** | `lib/ui/screens/customize_features_screen.dart`<br>`lib/settings/app_settings_manager.dart` | `test/widget_test.dart` | **Concluído** | Feature flags ocultam itens na interface sem nunca executar migrações destrutivas de dados históricos. |

---

## 2. Quadro Resumo de Implementação
- **Funcionalidades Totais Auditadas:** 16
- **Totalmente Estabilizadas e Testadas:** 12 (75%)
- **Parcialmente Implementadas com Débito / Risco P1:** 3 (18,75% — Concorrência na Agenda, Gravação de Áudio/Transcrição, Migrações do Banco Local)
- **Em Estabilização P0:** 1 (6,25% — Sincronização Supabase remota: U1 e U2 concluídas com 547 testes aprovados; U3 pendente)

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
- **Próxima Ação:** Executar Unidade U3 (Schema SQL remoto, Storage e validação RLS).
