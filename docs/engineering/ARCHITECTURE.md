# Arquitetura de Engenharia: Ministério Pessoal (Field Assistant)

> **Documento Canônico Unificado:** A especificação arquitetural mestra do projeto está consolidada em [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md). Este documento em `docs/engineering/` serve como referência técnica detalhada de engenharia para componentes de baixo nível, contratos de persistência e fluxos de sincronização.

---

## 1. Princípio Fundamental: Offline-First Irrestrito

Todas as ações do usuário — criação de contatos, registro de visitas, marcação de revisitas, alterações em estudos bíblicos, anotações de voz e compromissos — são escritas de forma **síncrona e imediata** no banco de dados local Drift (SQLite nativo no iOS, Android, macOS e Windows com `NativeDatabase` e Drift Wasm com IndexedDB na Web via `WasmDatabase`).

A interface de usuário **nunca aguarda** resposta de rede para confirmar qualquer ação ministerial.

```mermaid
flowchart TD
    UI[Interface do Usuário Flutter / Riverpod] -->|Mutações Imediatas| Repo[AppRepository]
    Repo -->|Transação Atômica Local| DB[(Drift / SQLite Local v4)]
    Repo -->|Enfileiramento com _base snapshot| SQ[(Tabela sync_queue Outbox)]
    
    SQ -->|Processamento em Background| Push[SupabaseSyncService.processQueue]
    Push -->|Upsert TLS 1.3 / RLS owner_id| RemoteDB[(PostgreSQL Supabase 10 Tabelas)]
    Push -->|Upload de Mídia .m4a/.mp4/.aac| Storage[(Supabase Storage: voice_notes)]
    
    RemoteDB -->|Pull Incremental por Cursor updated_at, id| Pull[SupabaseSyncService.fetchRemoteChanges]
    Pull -->|Merge de 3 Vias local, remote, base| SyncEng[SyncEngine.mergeEntities]
    SyncEng -->|Atualização Idempotente| DB
    Storage -->|Download de Binários Ausentes| Audio[Diretório Local /voice_notes/]
    
    RemoteDB -.->|Tombstones deleted_at != null| Pull
    Pull -.->|Guarda contra Ressurreição| DB
```

---

## 2. Camadas de Dados e Isolamento em 5 Níveis

```mermaid
flowchart TB
    subgraph Layer1 [1. Camada de Apresentação & UI]
        Screens[Screens: person_detail, appointments, contacts_map, dashboard, studies]
        Widgets[Widgets Modulares Coesos em lib/ui/widgets/]
        State[Gerenciamento de Estado Riverpod / Notifiers]
        M3[Material 3 / Sun Mode / Acessibilidade >= 48dp]
    end

    subgraph Layer2 [2. Camada de Repositório & Domínio]
        Repo[AppRepository]
        Managers[Domain Managers: PhoneContacts, VoiceNotes, Landmarks, Sectors, Experiences, Research]
        Engines[Engines: AvailabilityEngine, CountingRules, PioneerPace, StudentPriority]
    end

    subgraph Layer3 [3. Camada de Persistência Local]
        DriftNative[NativeDatabase: SQLite Nativo + WAL + PRAGMA Foreign Keys ON]
        DriftWeb[WasmDatabase: sqlite3.wasm + IndexedDB Web]
        Tables[22 Tabelas Fortemente Tipadas - Schema v4]
        KVStore[AppKvStore: Configurações, Tokens, Cursors]
    end

    subgraph Layer4 [4. Camada de Sincronização Offline-First]
        Outbox[Outbox sync_queue: Backoff Exponencial + Jitter]
        SyncEngine[SyncEngine: 3-Way Merge Determinístico]
        SupabaseSync[SupabaseSyncService: Pull Incremental, Tombstones Soft Delete]
        RemotePostgres[PostgreSQL Supabase: 10 Tabelas com RLS owner_id]
        RemoteStorage[Supabase Storage: Bucket voice_notes 10MB Privado]
    end

    subgraph Layer5 [5. Camada de Integração Externa & Segurança]
        AppleCal[Apple EventKit Provider com Isolamento Web]
        GoogleCal[Google Calendar Provider com OAuth Web GIS]
        BackupSec[BackupService: AES-256-GCM + PBKDF2 100k iter + Staging 3 Etapas]
        GISCache[TileCacheCancellable: Cancelamento Assíncrono de Zoom]
        AppCfg[AppConfig: Bloqueio de Service Role e Mascaramento]
    end

    Layer1 --> Layer2
    Layer2 --> Layer3
    Layer2 --> Layer4
    Layer2 --> Layer5
    Layer4 <--> Layer3
    Layer5 <--> Layer3
```

1. **Camada de Apresentação & UI (`lib/ui/`):**
   - Flutter Material 3, Riverpod, Dynamic Type e alto contraste (`sunModeTheme`).
   - Widgets modulares em `lib/ui/widgets/` mantendo chaves de estado de testes (`ValueKey`).

2. **Camada de Repositório & Domínio (`lib/database/repository.dart`, `lib/*/managers`):**
   - Abstração central `AppRepository` agrupando operações atômicas em `db.transaction`.
   - Domain managers com captura de snapshot `_base` e incremento monotônico de `revision`.
   - Motores de domínio desacoplados da interface (`AvailabilityEngine`, `CountingRules`, etc.).

3. **Camada de Persistência Local (`lib/database/tables.dart`, `app_database.dart`):**
   - 22 tabelas formais tipadas (`schemaVersion: 4`).
   - Configuração de conexão nativa com `PRAGMA foreign_keys = ON;` e `PRAGMA journal_mode = WAL;`.
   - Tabela `app_kv_store` para configurações, cursors de paginação e snapshots Web.

4. **Camada de Sincronização Offline-First (`lib/sync/`):**
   - **Outbox:** Processa a `sync_queue` ordenada cronologicamente com backoff exponencial e jitter.
   - **Pull Incremental:** Consulta paginada por cursor determinístico composto `(updated_at, id)`.
   - **Reconciliação 3-Way:** Algoritmo determinístico (`local`, `remote`, `_base`) evitando perda de edições concorrentes.
   - **Tombstones:** Soft delete propagado via `deleted_at != null` com guarda anti-ressurreição.
   - **Storage Binário:** Upload/download resiliente de notas de voz no bucket privado `voice_notes` (10 MB).

5. **Camada de Calendário Externo, Cartografia e Segurança:**
   - Coordenação bidirecional com Apple EventKit e Google Calendar via `calendar_event_links`.
   - Isolamento de plataforma Web (`_isWebPlatform`) e fluxo OAuth GIS Web.
   - Cache cartográfico `TileCacheCancellable` com cancelamento de zoom obsoleto e ordenação focal.
   - Envelope de backup v2 (AES-256-GCM + PBKDF2 100k iterações) e staging em 3 etapas.
   - Blindagem de ambiente via `AppConfig` com bloqueio de credenciais `service_role`.

---

## 3. Matriz de Tabelas e Sincronização

| Tabela Drift | Tabela SQL | Sincroniza Supabase? | RLS Remoto |
|---|---|:---:|:---:|
| `People` | `people` | Sim | `owner_id = auth.uid()` |
| `Visits` | `visits` | Sim | `owner_id = auth.uid()` |
| `BibleStudies` | `bible_studies` | Sim | `owner_id = auth.uid()` |
| `StudyParticipants` | `study_participants` | Sim | `owner_id = auth.uid()` |
| `StudySessions` | `study_sessions` | Sim | `owner_id = auth.uid()` |
| `Appointments` | `appointments` | Sim | `owner_id = auth.uid()` |
| `ActivityRecords` | `activity_records` | Sim | `owner_id = auth.uid()` |
| `VoiceNotes` | `voice_notes` | Sim | `owner_id = auth.uid()` |
| `PhoneContacts` | `phone_contacts` | Sim | `owner_id = auth.uid()` |
| `TerritoryLandmarks` | `territory_landmarks` | Sim | `owner_id = auth.uid()` |
| `SyncQueue` | `sync_queue` | Local | N/A |
| `AppKvStore` | `app_kv_store` | Local | N/A |
| `ExternalCalendarEvents` | `external_calendar_events` | Local | N/A |
| `CalendarEventLinks` | `calendar_event_links` | Local | N/A |
| `TerritorySectors` | `territory_sectors` | Local | N/A |
| `FamilyTies` | `family_ties` | Local | N/A |
| `PersonPhotos` | `person_photos` | Local | N/A |
| `PersonPublications` | `person_publications` | Local | N/A |
| `MinistryExperiences` | `ministry_experiences` | Local | N/A |
| `ResearchArticles` | `research_articles` | Local | N/A |
| `ResearchTags` | `research_tags` | Local | N/A |
| `StudentManualOrder` | `student_manual_order` | Local | N/A |
