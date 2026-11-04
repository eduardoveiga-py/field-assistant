# INVENTÁRIO E ESTADO DE IMPLEMENTAÇÃO DAS FUNCIONALIDADES

Este documento mapeia o status real e auditado de cada funcionalidade do **Field Assistant**, contrastando código implementado, módulos envolvidos, testes associados e a matriz canônica de sincronização das 22 tabelas Drift.

---

## 1. Matriz de Funcionalidades do Sistema

| # | Funcionalidade | Módulo / Arquivos Principais | Testes Associados | Status Real | Observações de Engenharia |
|---|---|---|---|---|---|
| **F01** | **Gestão de Contatos e Pessoas** | `lib/contacts/`<br>`lib/database/domains/people_domain.dart`<br>`lib/ui/screens/people_screen.dart`<br>`lib/ui/screens/person_detail_screen.dart`<br>`lib/ui/widgets/person_*` | `test/widget_test.dart`<br>`test/recent_seeds_test.dart`<br>`test/person_detail_tabs_test.dart` | **100% Concluído e Modularizado** | Telas modularizadas em widgets coesos (`person_visits_tab`, `person_study_tab`, `person_edit_dialog`, etc.); queries N+1 eliminadas via Mixins em `lib/database/domains/`. Mutações registram outbox atomicamente. |
| **F02** | **Registro de Visitas e Conversas** | `lib/database/domains/visits_domain.dart`<br>`lib/ui/widgets/quick_visit_dialog.dart`<br>`lib/ui/screens/person_detail_screen.dart` | `test/counting_rules_test.dart`<br>`test/sync/cross_device_10_scenarios_p0_test.dart` | **100% Concluído** | Suporte a visitas retroativas com toggle de data/hora (data atual padrão oculta quando toggle desligado). Atualização atômica na outbox para `people` (`lastContactAt` e `nextActionNote`). |
| **F03** | **Estudos Bíblicos e Sessões** | `lib/database/domains/studies_domain.dart`<br>`lib/dashboard/counting_rules.dart`<br>`lib/ui/screens/studies_screen.dart`<br>`lib/ui/widgets/study_*` | `test/counting_rules_test.dart`<br>`test/lff_and_priority_test.dart` | **100% Concluído e Modularizado** | `createStudy` com múltiplos participantes transacionado atomicamente via `db.transaction`. Diálogos unificados em `lib/ui/widgets/` (`record_study_session_dialog`, `study_form_dialog`, `publication_link_dialog`, `end_study_dialog`). Regras de contagem (1 estudo com N participantes = 1 estudo) validadas. |
| **F04** | **Briefing na Porta Enriquecido (30s)** | `lib/contacts/doorstep_briefing_helper.dart`<br>`lib/ui/widgets/doorstep_briefing_card.dart` | `test/doorstep_briefing_test.dart`<br>`test/doorstep_briefing_adversarial_test.dart` | **100% Concluído** | Seção "Onde parou" exibe compulsoriamente: título oficial da lição (catálogo LFF), título do ponto/seção e data exata da última visita registrada, com deep link direto via `PublicationLinkResolver`. |
| **F05** | **Linha do Tempo Espiritual do Estudante** | `lib/database/domains/studies_domain.dart`<br>`lib/ui/widgets/person_unified_timeline_section.dart` | `test/business_rules_enhancements_test.dart`<br>`test/widget_test.dart` | **100% Concluído** | Grava e exibe a data exata em que cada marco/progresso espiritual foi alcançado (primeira oração, publicador, batismo, etc.) com auditoria no Drift. |
| **F06** | **Agenda e Disponibilidade Estilo Consultório** | `lib/database/domains/appointments_domain.dart`<br>`lib/appointments/availability_engine.dart`<br>`lib/ui/screens/appointments_screen.dart`<br>`lib/ui/widgets/calendar_views/` | `test/availability_engine_test.dart`<br>`test/sync/u3_2_integrated_acceptance_test.dart`<br>`test/sync/cross_device_10_scenarios_p0_test.dart` | **100% Concluído e Blindado Contra Concorrência** | Detecção semântica de sobreposição concorrente pós-sincronização no `SupabaseSyncService`, marcação visual de status `conflito` e `isProvisional: true` na base local e atualização atômica na outbox (`sync_queue`). Check constraint PostgreSQL validada. Wizard de cópia mensal modularizado. |
| **F07** | **Integrações de Calendário (Apple EventKit & Google Calendar)** | `lib/appointments/calendar_sync_coordinator.dart`<br>`lib/appointments/google_calendar_provider.dart`<br>`lib/appointments/apple_eventkit_provider.dart`<br>`lib/appointments/web_calendar_platform_isolation_test.dart` | `test/appointments/calendar_sync_test.dart`<br>`test/appointments/web_calendar_platform_isolation_test.dart` | **100% Concluído e Resiliente** | Fim do loading infinito no Google Calendar com timeout assíncrono, feedback visual claro e tratamento de exceções. Na Web: isolamento de `device_calendar` impedindo crashes, Google OAuth Web nativo e gerenciamento .ics em Configurações. |
| **F08** | **Calculadora de Ritmo de Pioneiro** | `lib/dashboard/pioneer_pace_calculator.dart`<br>`lib/ui/widgets/pioneer_pace_card.dart` | `test/pioneer_pace_calculator_test.dart`<br>`test/pioneer_pace_adversarial_test.dart` | **100% Concluído** | Cálculos auditados contra viradas de mês, anos bissextos e TextScaler 2.0x sem overflow de renderização. |
| **F09** | **Destaque de Sementes Recentes** | `lib/contacts/recent_seeds_helper.dart`<br>`lib/ui/screens/people_screen.dart` | `test/recent_seeds_test.dart` | **100% Concluído** | Destaque visual e chips de filtro para novos contatos cadastrados há <= 7 dias sem revisita. |
| **F10** | **Recomendador Plano B Imediato** | `lib/appointments/plan_b_recommender.dart`<br>`lib/ui/widgets/plan_b_dialog.dart` | `test/plan_b_recommender_test.dart` | **100% Concluído** | Sugestão inteligente de 2 a 3 contatos vizinhos por distância Haversine e horários habituais ao desmarcar visita. |
| **F11** | **Cronômetro Auto-Corretivo** | `lib/activities/auto_corrective_timer_logic.dart`<br>`lib/ui/screens/activities_screen.dart` | `test/auto_corrective_timer_test.dart` | **100% Concluído** | Persistência do timer no SQLite; alerta inteligente ao ultrapassar 4h contínuas com diálogo de ajuste. |
| **F12** | **Notas de Voz e Ditado com Parada Física aos 30s** | `lib/voice_notes/audio_recording_service.dart`<br>`lib/voice_notes/voice_dictation_service.dart`<br>`lib/ui/widgets/quick_voice_note_dialog.dart` | `test/sync/u3_2_integrated_acceptance_test.dart`<br>`test/voice_notes_test.dart` | **100% Concluído e Blindado** | Limite real de 30 segundos com parada física no hardware (`record.stop()`), barreira `_isCancelled`, eliminação de áudios órfãos e fallback explícito de UI caso o pacote de ditado offline não esteja instalado, preservando o arquivo binário. |
| **F13** | **Backup Criptografado Envelope v2** | `lib/settings/backup_service.dart`<br>`lib/ui/screens/settings_screen.dart` | `test/backup_service_test.dart` (18 testes) | **100% Concluído e Blindado** | AES-256-GCM + PBKDF2 (100k iterações); staging em 3 etapas com rollback transacional (`replacedOriginalsBackup`); eliminação de fallback para diretórios temporários `/tmp` via `StorageUnavailableException`. |
| **F14** | **Sincronização Multi-Dispositivo (10 Cenários P0)** | `lib/sync/sync_engine.dart`<br>`lib/sync/supabase_sync_service.dart`<br>`lib/core/supabase_initializer.dart`<br>`lib/core/app_config.dart`<br>`supabase/migrations/` | `test/sync/cross_device_10_scenarios_p0_test.dart` (10 testes)<br>`test/sync/supabase_hardening_u3_2_test.dart`<br>`test/sync/supabase_lifecycle_test.dart`<br>`test/sync/supabase_soft_delete_test.dart`<br>`test/sync/supabase_u3_schema_storage_test.dart`<br>`test/supabase_sync_service_test.dart` | **100% Concluído e Validado (P0 Requisito Mandatório v1)** | 10 cenários de aceitação entre 2 dispositivos aprovados: push/pull bidirecional, durabilidade da outbox pós-restart, 3-way merge determinístico com `baseData`, resolução de conflitos, detecção de concorrência na agenda, tombstones sem ressurreição, mídia privada sem expor caminhos locais, RLS estrito (`owner_id = auth.uid()`), resiliência de rede com backoff e bootstrap limpo. |
| **F15** | **Banco de Dados Local Drift (SQLite & Wasm)** | `lib/database/app_database.dart`<br>`lib/database/domains/`<br>`lib/database/connection/` | `test/database_integrity_test.dart`<br>`test/database_migration_test.dart` | **100% Concluído e Auditado** | 22 tabelas fortemente tipadas (`schemaVersion: 4`). `PRAGMA foreign_keys = ON;`, `journal_mode = WAL;`. Migrações resilientes com `AppLogger.error` e `rethrow`. Drift Wasm com IndexedDB na Web e worker canônico `drift_worker.js`. |
| **F16** | **Mapa de Contatos e Território com Zoom Focal** | `lib/ui/screens/contacts_map_screen.dart`<br>`lib/ui/widgets/interactive_map_canvas.dart`<br>`lib/territory/tile_cache/` | `test/map_tiles_and_performance_hardening_test.dart`<br>`test/layout_fixes_and_map_highlight_test.dart` | **100% Concluído e Otimizado** | Correção do deslocamento do mapa ao dar zoom: centralização e focalização exata no ponto de interação. Cancelamento assíncrono de tiles obsoletos (`cancelZoomExcept`), ordenação focal pelo centro do viewport e preservação das Keys de pinos (`person_pin_${p.id}` e `landmark_pin_${l.id}`). |

---

## 2. Matriz de Sincronização Canônica das 22 Tabelas Drift

Conforme o adendo mandatório de sincronização multi-dispositivo da v1, segue a categorização técnica formal e exaustiva de todas as 22 tabelas Drift existentes em `lib/database/tables.dart` e `lib/database/app_database.dart`:

| # | Tabela Drift | Categoria Técnica | Sincroniza Nuvem? | Possui Outbox? | Justificativa Arquitetural & Regra de Negócio |
|---|---|:---:|:---:|:---:|---|
| 1 | `People` | **Sincronizada entre Dispositivos** | **Sim** | **Sim** | Entidade central do ministério (moradores, interessados e estudantes). RLS por `owner_id = auth.uid()`. |
| 2 | `Visits` | **Sincronizada entre Dispositivos** | **Sim** | **Sim** | Histórico cronológico ministerial de visitas, revisitas e conversas. |
| 3 | `BibleStudies` | **Sincronizada entre Dispositivos** | **Sim** | **Sim** | Acompanhamento de estudos bíblicos ativos, lições atuais e progresso. |
| 4 | `StudyParticipants` | **Sincronizada entre Dispositivos** | **Sim** | **Sim** | Vínculo entre estudos e participantes múltiplos cadastrados. |
| 5 | `StudySessions` | **Sincronizada entre Dispositivos** | **Sim** | **Sim** | Registro de ocorrência de sessões/aulas de estudo e matérias tratadas. |
| 6 | `Appointments` | **Sincronizada entre Dispositivos** | **Sim** | **Sim** | Compromissos e horários agendados. Possui detecção de concorrência semântica pós-sync. |
| 7 | `ActivityRecords` | **Sincronizada entre Dispositivos** | **Sim** | **Sim** | Relatório de serviço ministerial (horas, publicações, vídeos e revisitas). |
| 8 | `VoiceNotes` | **Sincronizada entre Dispositivos** | **Sim** | **Sim** | Metadados e transcrições na tabela; áudio binário sincronizado no Supabase Storage (`voice_notes`) com sanitização de caminhos locais. |
| 9 | `PhoneContacts` | **Sincronizada entre Dispositivos** | **Sim** | **Sim** | Registros de testemunho telefônico com flags de WhatsApp e redes sociais. |
| 10 | `TerritoryLandmarks` | **Sincronizada entre Dispositivos** | **Sim** | **Sim** | Marcos e pontos de referência no mapa do território. |
| 11 | `FamilyTies` | **Local por Decisão de Produto** | Não | Não | Grau de parentesco cadastral entre moradores. Uso complementar local na interface. |
| 12 | `MinistryExperiences` | **Local por Decisão de Produto** | Não | Não | Relatos e memórias pessoais de campo mantidos sob controle estrito no aparelho. |
| 13 | `PersonPhotos` | **Local por Decisão de Produto** | Não | Não | Fotos de perfil salvas localmente no armazenamento seguro da aplicação. |
| 14 | `PersonPublications` | **Local por Decisão de Produto** | Não | Não | Histórico tabular complementar de literatura deixada. Visitas já registram a publicação na nuvem. |
| 15 | `ResearchArticles` | **Local por Decisão de Produto** | Não | Não | Notas pastorais e artigos de pesquisa teocrática de cunho privado do publicador. |
| 16 | `ResearchTags` | **Local por Decisão de Produto** | Não | Não | Tags de indexação dos artigos de pesquisa locais. |
| 17 | `TerritorySectors` | **Local por Decisão de Produto** | Não | Não | Subdivisões territoriais de apoio. A gestão de território primário é delegada ao Hourglass. |
| 18 | `StudentManualOrder` | **Local por Decisão de Produto** | Não | Não | Ordem de classificação manual da lista de estudantes para partes de reunião na congregação local. |
| 19 | `SyncQueue` | **Específica de Dispositivo** | Não (por design) | Não | Fila transacional outbox local de cada aparelho. Garante persistência e retentativa autônoma de push. |
| 20 | `ExternalCalendarEvents` | **Específica de Dispositivo** | Não (por design) | Não | Cache de eventos do calendário nativo do sistema operacional (Apple EventKit / Android Calendar). |
| 21 | `CalendarEventLinks` | **Específica de Dispositivo** | Não (por design) | Não | Vínculos entre IDs de eventos do sistema operacional local e compromissos do app. |
| 22 | `AppKvStore` | **Cache / Derivado** | Não (por design) | Não | Chave-valor local para preferências de interface, tokens efêmeros de sessão e timestamps de snapshots. |

---

## 3. Métricas Globais de Cobertura e Qualidade

- **Total de Testes Automatizados:** **704 testes aprovados (100% de sucesso)**
- **Falhas de Teste:** **0**
- **Testes Flaky / Ignorados:** **0**
- **Análise Estática (`dart analyze lib test --fatal-infos`):** **0 issues (0 erros, 0 avisos, 0 lints)**
- **Compilação Release Web:** **Aprovada com sucesso (`flutter build web --release`)**
- **Formatação de Código:** **100% em conformidade (`dart format --output=none --set-exit-if-changed lib test`)**
- **Status de Prontidão:** **Release Candidate Verificado (Aprovado no Código)**
- **Pendências Externas de Infraestrutura:** Geração de Archive iOS em runner macOS com conta Apple Developer ativa e testes em aparelho físico (iPhone/iPad).
