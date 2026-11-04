# ESTADO FINAL DO PROJETO: FIELD ASSISTANT

- **Fase Atual:** Milestone 5 Concluído — Release Candidate Verificado
- **Branch de Trabalho:** `master` / `stabilization/definitive-hardening`
- **Schema Drift/SQLite:** Versão `4` (22 tabelas fortemente tipadas)
- **Total de Testes Automatizados:** **719 testes aprovados (100% de sucesso)**
- **Status do Build Web:** Concluído com sucesso (`flutter build web --release`)
- **Status da Análise Estática:** **0 issues** (`dart analyze lib test --fatal-infos`)
- **Status da Formatação:** 100% em conformidade (`dart format --output=none --set-exit-if-changed lib test`)
- **Veredito de Engenharia:** **APROVADO PARA RELEASE CANDIDATE (CÓDIGO E TESTES 100% ESTABILIZADOS)**

---

## 1. Visão Geral da Arquitetura Final Validada

O **Field Assistant** é uma aplicação Flutter multiplataforma (iOS, Android, Web WASM e Desktop) para organização do ministério pastoral e pessoal:

1. **Camada de Apresentação Desacoplada e Modular:**
   - Telas de alta complexidade modularizadas em widgets coesos em `lib/ui/widgets/`.
   - Preservação rigorosa de todas as `Key`s para widget testing (`person_pin_*`, `landmark_pin_*`, `ValueKey(study.id)`).
   - Dynamic Type, Material 3, tema de alto contraste para o sol (`sunModeTheme`) e alvos de toque >= 48x48 dp.
   - Gestão de estado reativa e segura com Flutter Riverpod (`flutter_riverpod`).

2. **Repositório de Domínio por Mixins:**
   - `AppRepository` composto por Mixins em `lib/database/domains/` (`PeopleDomainMixin`, `VisitsDomainMixin`, `StudiesDomainMixin`, `AppointmentsDomainMixin`, `ActivitiesDomainMixin`, `TrashDomainMixin`, `SyncQueueDomainMixin`) herdando de `BaseRepository`.
   - 100% de retrocompatibilidade com os `providers.dart` e todos os testes existentes.
   - Eliminação de chamadas diretas `db.select` em widgets e garantia de transações atômicas `db.transaction` em operações compostas.

3. **Persistência Local Offline-First:**
   - Drift (SQLite) com 22 tabelas fortemente tipadas (`schemaVersion: 4`).
   - Plataformas Nativas (iOS, Android, Desktop): `NativeDatabase` com `PRAGMA foreign_keys = ON;`, `PRAGMA journal_mode = WAL;`, `PRAGMA synchronous = NORMAL;` e `busy_timeout = 5000;`.
   - Web: SQLite compilado para WebAssembly (`drift/wasm.dart`) com armazenamento persistente em IndexedDB e worker canônico único `web/drift_worker.js`.

4. **Sincronização Multi-Dispositivo (10 Cenários P0 Aprovados):**
   - Push/Pull bidirecional via Supabase com fila de saída transacional durável (`sync_queue`).
   - Mesclagem determinística de 3 vias (`SyncEngine.mergeEntities`) com snapshot `_base` preservando edições concorrentes em campos distintos.
   - Detecção e retenção explícita de conflitos em edições no mesmo campo.
   - Detecção semântica de compromissos concorrentes na agenda pós-sincronização com sinalização de `conflito` e `isProvisional`.
   - Soft delete via tombstones (`deleted_at`, `revision`) com trigger PostgreSQL `prevent_stale_resurrection` impedindo ressurreição acidental de registros excluídos.
   - Mídias de notas de voz sincronizadas de forma privada no Supabase Storage (`voice_notes`) com sanitização compulsória de caminhos locais (`audio_file_path`).
   - Isolamento multi-tenant absoluto via RLS (`owner_id = auth.uid()`) e bloqueio ativo de credenciais privilegiadas (`service_role`) no cliente via `AppConfig`.
   - Resiliência contra falhas de rede com backoff exponencial + jitter (clamped a 300s) e retentativas supervisionadas.
   - Bootstrap em dispositivo limpo com full pull paginado via cursor determinístico composto `(updated_at, id)`.

5. **Segurança, Backup e Mídia:**
   - Criptografia de backup em Envelope v2: AES-256-GCM + PBKDF2-HMAC-SHA256 (100.000 iterações), com staging em 3 etapas e rollback transacional seguro de áudios (`replacedOriginalsBackup`).
   - Política de Zero Diretórios Temporários em produção: eliminação de `Directory.systemTemp` / `/tmp` e adoção de `StorageUnavailableException`.
   - Gravação de notas de voz com parada física no hardware aos 30 segundos (`record.stop()`), barreira `_isCancelled` e fallback amigável caso o ditado offline não esteja instalado no iOS.

---

## 2. Mapa dos Módulos do Sistema

| Módulo | Caminho | Responsabilidade |
|---|---|---|
| **Database Domains** | `lib/database/domains/` | Mixins de domínio de Pessoas, Visitas, Estudos, Agenda, Atividades, Lixeira e Outbox. |
| **Database Core** | `lib/database/` | `app_database.dart`, `tables.dart`, `repository.dart`, conexões nativa e web Wasm. |
| **Core & Injeção** | `lib/core/` | `app_config.dart`, `supabase_initializer.dart`, `app_logger.dart`. |
| **Sync Engine** | `lib/sync/` | `sync_engine.dart`, `supabase_sync_service.dart`, controle de outbox, cursor e storage. |
| **Appointments / Calendar** | `lib/appointments/` | `availability_engine.dart`, `calendar_sync_coordinator.dart`, Google Calendar, Apple EventKit e .ics. |
| **Contacts & Territories** | `lib/contacts/`, `lib/territory/` | Pessoas, contatos telefônicos, mapa com zoom focal e cache de tiles OSM. |
| **Voice Notes & Briefing** | `lib/voice_notes/` | Gravação física de 30s, ditado offline, parser teocrático e briefing na porta com catálogo LFF. |
| **Settings & Backup** | `lib/settings/` | Backup criptografado v2, preferências e customização de telas. |
| **UI & Widgets** | `lib/ui/`, `lib/ui/widgets/` | Telas e widgets modulares (timeline espiritual, diálogos unificados, wizard de agenda, etc.). |

---

## 3. Estado das Fases da Missão (Milestones M1 a M5)

- [x] **Milestone 1 (Fase 1: Unificação e Higienização da Documentação)**: **CONCLUÍDO (PASS)**
- [x] **Milestone 2 (Fase 2: Limpeza dos Workers Web do Drift)**: **CONCLUÍDO (PASS)**
- [x] **Milestone 3 (Fase 3: Auditoria de Código, Banco e Sincronização)**: **CONCLUÍDO (PASS)**
- [x] **Milestone 4 (Fase 4: Modularização de Telas Extensas & UI Features)**: **CONCLUÍDO (PASS)**
- [x] **Milestone 5 (Fase 5: Validação Final, 10 Sync Scenarios P0, Governança & Registros)**: **CONCLUÍDO (PASS)**

---

## 4. Recursos Externos Necessários para Homologação Final em Produção

1. **Ambiente Apple:**
   - Máquina macOS (local ou runner GitHub Actions `macos-latest`) com Xcode 15+ instalado.
   - Conta Apple Developer ativa para assinatura de código (Provisioning Profiles / Certificates).
   - Distribuição via Apple TestFlight para validação em hardware físico (iPhone / iPad).
2. **Ambiente Supabase:**
   - **Concluído e Validado:** Projeto Supabase com as migrações SQL aplicadas, todas as 10 tabelas de domínio com RLS ativo por `owner_id = auth.uid()` e bucket privado `voice_notes`.
