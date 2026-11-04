# REGISTRO HISTÓRICO DE DECISÕES DE ENGENHARIA (DECISION LOG)

Este documento preserva o histórico detalhado, contexto de baixo nível, alternativas ponderadas e consequências técnicas de todas as decisões tomadas durante o desenvolvimento, estabilização e hardening do **Field Assistant**.

A numeração segue estritamente a sequência canônica unificada de **ADR-001 a ADR-023**, perfeitamente alinhada com [`docs/DECISIONS.md`](../DECISIONS.md).

---

## Seção 1: Fundações Arquiteturais (ADR-001 a ADR-008)

### ADR-001: Adoção do Flutter com Suporte a Web e iOS
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** Necessidade de aplicação de suporte ministerial executável em ambiente desktop/browser (Windows Web) e dispositivos móveis Apple (iPhone XR e iPad 11 A16), compartilhando 100% da lógica de negócio e persistência.
- **Decisão:** Utilizar Flutter com Dart estável em canal estável.
- **Consequências:** Base de código única para interface, modelo relacional, protocolo de sincronização e testes; compilação Web (Wasm) e pipelines de CI/CD para iOS via macOS runner.

### ADR-002: Banco de Dados Local Drift (SQLite & Wasm)
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** Premissa offline-first irrestrita demandando banco relacional com forte tipagem estática em tempo de compilação, streams reativos e suporte nativo ao navegador.
- **Decisão:** Adotar Drift com backend `NativeDatabase` (Desktop/Mobile) e `WasmDatabase` com IndexedDB (Web via `sqlite3.wasm` e worker dedicado).
- **Consequências:** Zero perda de dados na ausência de rede; integridade de consultas reativas na interface; elimina arquivos monolíticos SQLite para sync.

### ADR-003: Backend Supabase com Row Level Security (RLS) via `owner_id`
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** Sincronização multi-dispositivo sem exposição de registros ministeriais entre diferentes publicadores, exigindo isolamento rígido por usuário autenticado.
- **Decisão:** Supabase com PostgreSQL, GoTrue Auth e políticas de RLS ativas em todas as tabelas e buckets filtrando por `owner_id = auth.uid()`.
- **Consequências:** Isolamento criptográfico e de permissões no banco remoto; rejeição absoluta de chaves administrativas (`service_role`) no cliente; suporte ao funcionamento offline irrestrito sem credenciais.

### ADR-004: Fila de Sincronização Transacional com Resolução de Conflitos
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** Risco de concorrência e perdas silenciosas quando o usuário edita anotações no campo (offline) e posteriormente em outros dispositivos.
- **Decisão:** Outbox transacional persistente (`sync_queue`) com controle monotônico de revisão, reconciliação de 3 vias (`SyncEngine.mergeEntities`) e retenção de versões divergentes para resolução consciente.
- **Consequências:** Eliminação categórica de "Last Write Wins" silencioso; histórico de visitas e sessões preservado de forma imutável.

### ADR-005: Formatação de Horários e Agenda Tipo Consultório
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** Necessidade de agendamento ágil de revisitas no campo com validação imediata de disponibilidade e conflitos de horários.
- **Decisão:** Motor de disponibilidade (`AvailabilityEngine`) que analisa intervalos `[start, end]` contra a base local antes da gravação, marcando `is_provisional: true` e status `conflito` em colisões recebidas de outros nós.
- **Consequências:** Prevenção de sobreposição involuntária de compromissos; flexibilidade para resolver colisões após sincronização sem perda de dados.

### ADR-006: Envelope Criptográfico de Backup v2 com PBKDF2-HMAC-SHA256 e AES-256-GCM
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** Proteção de registros confidenciais em arquivos de exportação e compatibilidade retroativa com arquivos v1.
- **Decisão:** Envelope v2 com derivação de chave por PBKDF2-HMAC-SHA256 (100.000 iterações, salt 16 bytes) e cifra autenticada AES-256-GCM (tag 128 bits, IV 16 bytes). Backups automáticos utilizam segredo do dispositivo persistido em `app_kv_store`.
- **Consequências:** Proteção matemática contra força bruta e adulteração de arquivos; retrocompatibilidade com formato legado v1 (AES-CBC + SHA-256).

### ADR-007: Serviços Reais de Áudio e Ditado com Degradação Graciosa
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** Gravação rápida de áudios pós-visita no hardware do dispositivo e suporte a transcrição/ditado com degradação graciosa na ausência de rede.
- **Decisão:** `RealAudioRecordingService` com parada física aos 30s (`record.stop()`), `RealAudioPlayerService` e `RealVoiceDictationService`, associados a fakes completos para testes automatizados.
- **Consequências:** Gravação `.m4a`/`.aac` em diretório de documentos; tratamento de permissões de microfone; fallback para entrada digitada caso o modelo de voz offline não esteja disponível.

### ADR-008: Evolução do Esquema Drift v2 com Tabelas Fortemente Tipadas
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** Módulos de notas de voz, contatos importados, marcos de mapa e chave-valor utilizavam consultas brutas ou tabelas não-tipadas.
- **Decisão:** Evoluir esquema Drift para versão 2 adicionando formalmente `VoiceNotes`, `PhoneContacts`, `TerritoryLandmarks` e `AppKvStore`.
- **Consequências:** Tipagem estrita de colunas no Dart com DAOs nativos; suporte a transações multi-entidade atômicas e migrações versionadas.

---

## Seção 2: Engenharia, Resiliência e Hardening (ADR-009 a ADR-023)

### ADR-009: Eliminação de Fallback Silencioso para `Directory.systemTemp`
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** Em `lib/settings/backup_service.dart`, `_getDocsDir()` capturava `MissingPluginException` e retornava `Directory.systemTemp`.
- **Decisão:** Rejeitar qualquer uso de diretórios temporários para snapshots de segurança e arquivos de mídia. Lançar explicitamente `StorageUnavailableException`.
- **Justificativa:** O sistema operacional pode expurgar o diretório temporário a qualquer momento para liberar espaço, destruindo notas de voz e inviabilizando restaurações.
- **Consequências:** Aplicação falha de maneira controlada com aviso de erro em vez de perder dados silenciosamente. Validado por `TC-BAK-ADV-03`.

---

### ADR-010: Staging em Três Etapas para Restauração de Áudios
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** Arquivos de notas de voz eram descompactados diretamente na pasta final `/voice_notes/`. Se a transação do banco falhasse em seguida, o bloco catch executava `deleteSync()`, apagando áudios legítimos pré-existentes.
- **Decisão:** Criar um fluxo transacional de staging:
  1. Descompactar para `safety_staging/<uuid>/`.
  2. Mover arquivos pré-existentes que serão substituídos para `safety_audio_backup/<uuid>/`.
  3. Mover atomicamente do staging para `/voice_notes/` apenas após o commit do SQLite.
  4. Em caso de falha no commit, restaurar os originais do backup e limpar o staging.
- **Justificativa:** Garante transacionalidade mútua entre o sistema de arquivos e o banco relacional.
- **Consequências:** Zero perda de mídias durante restaurações com falha. Validado por `TC-BAK-ADV-01` e `TC-BAK-ADV-02`.

---

### ADR-011: Ordenação Determinística Composta no Cursor de Sincronização Supabase
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** A paginação remota em `lib/sync/supabase_sync_service.dart` ordenava apenas por `updated_at`. Quando múltiplos registros compartilhavam o mesmo milissegundo, a fronteira de página pulava registros não processados.
- **Decisão:** Ordenar estritamente por `.order('updated_at', ascending: true).order('id', ascending: true)`. O cursor no KV store só avança até o carimbo de data/hora do último registro efetivamente aplicado no banco local.
- **Justificativa:** Elimina perda silenciosa de dados em cargas em lote.
- **Consequências:** Sincronização incremental 100% determinística. Validado por `TC-SYNC-ADV-01`.

---

### ADR-012: Enfileiramento Obrigatório de Mutações Indiretas na Outbox
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** O método `createVisit()` em `lib/database/repository.dart` atualizava `people` (alterando `lastContactAt` e `nextActionNote`), mas só enfileirava a operação para `visits`. O outro aparelho recebia a visita, mas o contato permanecia desatualizado.
- **Decisão:** Toda mutação em qualquer tabela secundária dentro de uma transação local deve enfileirar sua respectiva operação na `sync_queue` contendo snapshot `baseData`.
- **Justificativa:** Previne divergências de estado entre múltiplos dispositivos.
- **Consequências:** Atualização síncrona de metadados em todos os nós. Validado por `TC-SYNC-ADV-04`.

---

### ADR-013: Ativação Obrigatória de `PRAGMA foreign_keys = ON;` e `WAL`
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** O SQLite nativo via Drift desativa por padrão a validação de chaves estrangeiras se não configurado explicitamente no callback de conexão.
- **Decisão:** Configurar o callback `setup` no `NativeDatabase.createInBackground`:
  ```dart
  rawDb.execute('PRAGMA foreign_keys = ON;');
  rawDb.execute('PRAGMA journal_mode = WAL;');
  rawDb.execute('PRAGMA synchronous = NORMAL;');
  rawDb.execute('PRAGMA busy_timeout = 5000;');
  ```
- **Justificativa:** Garante integridade referencial física e previne bloqueios de leitura concorrente.
- **Consequências:** Tentativas de criar registros órfãos são rejeitadas pelo motor SQLite. Validado por `TC-DB-ADV-01` e `TC-DB-ADV-02`.

---

### ADR-014: Proteção contra Consultas Parciais Truncadas no Apple EventKit
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** Quando o iOS ou `device_calendar` sofria limitação ou retornava um subconjunto parcial de eventos, o sincronizador interpretava os eventos ausentes como exclusões externas e apagava os vínculos pastorais.
- **Decisão:** Detectar anomalias de exclusão em massa (>25% de ausência súbita sem exclusão confirmada) e suspender a remoção automática, solicitando confirmação.
- **Justificativa:** Protege os dados ministeriais contra instabilidades transitórias da API do sistema operacional.
- **Consequências:** Zero perda indevida de agendamentos. Validado por `TC-APPLE-ADV-01`.

---

### ADR-015: Inclusão da Regra de Recorrência no Fingerprint SHA-256
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** O cálculo do hash de alteração de eventos de calendário ignorava a string de regra de recorrência (`RRULE`). Alterações de frequência não eram detectadas.
- **Decisão:** Incluir o campo `recurrenceRuleStr` determinístico no cálculo de `computeEventFingerprint()`.
- **Justificativa:** Garante reconciliação exata entre compromissos recorrentes e avulsos.
- **Consequências:** Reconciliação imediata ao alterar repetição de compromissos. Validado por `TC-APPLE-ADV-02`.

---

### ADR-016: Não Substituição do Hourglass para Gestão de Territórios
- **Data:** Novembro de 2026
- **Status:** Aprovado e Mantido
- **Contexto:** O usuário utiliza a plataforma consolidada Hourglass para gerenciamento cartográfico e de designação de territórios.
- **Decisão:** Manter o escopo do mapa no Field Assistant estritamente como visualizador geográfico de contatos próprios (`contacts_map_screen.dart`), sem tentar reinventar módulos de controle de congregação do Hourglass.
- **Justificativa:** Evita duplicação de esforço e preserva a especialização ministerial do aplicativo.

---

### ADR-017: Proibição de Migrações Destrutivas por Feature Flags
- **Data:** Novembro de 2026
- **Status:** Aprovado e Mantido
- **Contexto:** Em `customize_features_screen.dart`, o usuário pode desativar telas ou submódulos (ex: experiências, publicações, notas de voz).
- **Decisão:** A desativação de uma funcionalidade na interface apenas oculta seus pontos de entrada na UI. É expressamente proibido disparar `DROP TABLE` ou `DELETE` em dados históricos. Ao reativar a flag, todos os dados devem reaparecer intactos.
- **Justificativa:** Preservação categórica do patrimônio de registros do publicador.

---

### ADR-018: Centralização e Validação Imutável de Ambiente via `AppConfig`
- **Data:** Novembro de 2026 (Fase 2 — Unidade U1)
- **Status:** Aprovado e Implementado
- **Contexto:** A injeção de parâmetros do backend Supabase (`SUPABASE_URL` e `SUPABASE_ANON_KEY`) dependia de chamadas dispersas a `String.fromEnvironment()`. Quando variáveis não eram injetadas via `--dart-define-from-file`, o aplicativo assumia strings vazias sem distinção clara entre ausência de configuração e falha de conectividade. Havia risco de inserção acidental de credenciais privilegiadas (`service_role`) e vazamento de segredos em logs de depuração.
- **Decisão:**
  1. Centralizar toda a modelagem de configuração na classe imutável `AppConfig` (`lib/core/app_config.dart`).
  2. Implementar validação estrita em tempo de compilação/inicialização com status explícito (`unconfigured`, `valid`, `invalid`).
  3. Rejeitar categoricamente qualquer chave de autenticação com a role `service_role` (inclusive em base64url com `-` ou `_`), `supabase_admin`, `super_admin`, `admin`, `postgres` ou tokens `sbp_` via inspeção do payload JWT e de strings.
  4. Proibir credenciais de autenticação embebidas na URL (Basic Auth `userInfo`), query parameters e fragmentos em `SUPABASE_URL`, mascarando eventuais dados de usuário em logs.
  5. Exigir estritamente HTTPS em ambiente de produção (inclusive rejeitando `http://localhost`).
  6. Normalizar URLs removendo barras finais redundantes.
  7. Proibir espaços em branco internos e quebras de linha em `SUPABASE_ANON_KEY`.
  8. Implementar mascaramento obrigatório de chaves (`maskedAnonKey`) em `toString()` e logs técnicos, e detalhar erros de validação em `toDiagnosticString()`.
  9. Blindar `.gitignore` para ignorar `.env*` garantindo que `.env.prod` e `.env.homolog` não sejam versionados acidentalmente.
  10. Tratar o modo sem configuração como um estado operacional offline legítimo e seguro (`isOfflineOnly`), sem lançar exceções e mantendo todas as mutações no SQLite.
  11. Padronizar scripts de execução para auto-detecção de `.env` e injeção transparente de `--dart-define-from-file`.
- **Justificativa:** Garante a inviolabilidade do modelo offline-first, previne vazamento de credenciais privilegiadas e elimina comportamentos indefinidos no boot.
- **Consequências:** Inicialização 100% determinística, logs higienizados sem segredos e distinção formal entre modo offline e queda de rede. Validado pela suíte `test/core/app_config_test.dart` (9 testes dedicados).

---

### ADR-019: Inicialização Resiliente, Desacoplada e Ciclo de Vida do Supabase
- **Data:** Novembro de 2026 (Fase 2 — Unidade U2)
- **Status:** Aprovado e Implementado
- **Contexto:** O aplicativo dependia de `Supabase.initialize()` que nunca era chamado em `lib/main.dart` (Bloqueador P0-01). Caso chamado de forma bloqueante antes de `runApp()`, o boot da aplicação travaria ou falharia em ambientes sem rede, violando a premissa fundamental offline-first. Além disso, acessos a `Supabase.instance.client` quando não inicializado lançavam `AssertionError`, e a fila de sincronização (outbox) corria o risco de perder ou travar operações após falhas de rede transitórias.
- **Decisão:**
  1. Criar o orquestrador `SupabaseInitializer` (`lib/core/supabase_initializer.dart`) com enum de estados de conexão granular (`unconfigured`, `initializing`, `initialized`, `connected`, `disconnected`, `authenticationRequired`, `authenticationExpired`, `error`).
  2. Implementar ordem estrita de boot desacoplada em `lib/main.dart`:
     - Passo 1: `WidgetsFlutterBinding.ensureInitialized()`.
     - Passo 2: `AppConfig.fromEnvironment()`.
     - Passo 3: Inicialização imediata e síncrona do banco local SQLite Drift (`AppDatabase`).
     - Passo 4: Instanciação do `AppRepository`.
     - Passo 5: Inicialização condicional, assíncrona e não-bloqueante (`unawaited(initializeSupabaseIfConfigured(...))`).
     - Passo 6: Injeção de dependências desacopladas Riverpod (`ProviderScope` com overrides).
     - Passo 7: `runApp()`.
  3. Garantir idempotência e proteção de concorrência com trava `Completer<SupabaseStateInfo>` em `SupabaseInitializer.initialize(...)`.
  4. Blindar o acesso ao SDK Supabase via `SupabaseInitializer.clientOrNull`, retornando `null` com segurança em vez de lançar `AssertionError`.
  5. Adicionar escuta reativa a eventos de autenticação (`onAuthStateChange`) para detectar tokens expirados (`authenticationExpired`) e deslogamentos (`authenticationRequired`).
  6. Adicionar probe ativo de conectividade `checkConnectivity()` para validação de reachability contra `/rest/v1/` com timeout de 4 segundos.
  7. Implementar ciclo de vida com `WidgetsBindingObserver` em `SupabaseSyncService` e escuta a `SupabaseInitializer.stateStream` para disparar reavaliação de conectividade e sincronização imediata no retorno de segundo plano (`handleAppResume()`) e restauração automática de rede (`handleReconnection()`).
  8. Preservar durabilidade absoluta da outbox em `AppRepository.getPendingSyncOperations()` incluindo status `failed` com menos de 5 tentativas.
  9. Blindar a mesclagem remota em `_applyRemoteRecord` para incluir operações na outbox com status `failed` (tentativas < 5) na resolução 3-way merge, prevenindo sobrescrita inadvertida de edições locais após falhas transitórias de envio.
  10. Implementar trava de reentrância assíncrona (`isSyncing` e `_activeSyncCompleter`) em `SupabaseSyncService.processQueue` e `fetchRemoteChanges`, serializando chamadas concorrentes sem duplicação de requisições REST nem contenção SQLite.
  11. Implementar algoritmo de backoff exponencial com jitter aleatório (2^tentativas clamped em 300s + jitter até 25%) em `calculateBackoffSeconds`.
  12. Abortar imediatamente o lote em falhas de rede (`_isNetworkError`) para manter `SyncStatus.waitingConnection` e evitar queima prematura de tentativas nos itens subsequentes da fila.
  13. Evitar loops infinitos de rede pausando o processamento automático daquelas operações que atingem 5 tentativas consecutivas de falha, retendo-as fisicamente na tabela `sync_queue` para auditoria manual.
- **Justificativa:** Assegura que o aplicativo abra instantaneamente e funcione com 100% de capacidade local independente do status da rede ou do backend, enquanto orquestra sincronização transparente, segura e sem regressões na outbox.
- **Consequências:** Zero dependência de rede no boot, zero crashes por `AssertionError`, durabilidade garantida da outbox local, reatividade Riverpod e recuperação automática de conectividade. Validado por 30 testes dedicados em `test/core/supabase_initializer_test.dart` e `test/sync/supabase_lifecycle_test.dart`.

---

### ADR-020: Schema Remoto Supabase, Storage Privado de Áudio e Validação RLS
- **Data:** 02 de Novembro de 2026 (Fase 2 — Unidade U3)
- **Status:** Aprovado e Implementado
- **Contexto:** A auditoria inicial identificou o bloqueador crítico P0-02: ausência das tabelas `voice_notes`, `phone_contacts` e `territory_landmarks` e do bucket de Storage `voice_notes` na migração remota do Supabase (`supabase/migrations/20261026000000_initial_schema.sql`). Embora o sincronizador (`SupabaseSyncService`) já incluísse essas entidades em `syncTables` e realizasse a sanitização e upload de binários, qualquer tentativa de sincronização real dessas 3 entidades contra o Supabase falharia por falta das tabelas remotas ou do bucket de armazenamento.
- **Decisão:**
  1. Criar a migração versionada `supabase/migrations/20261102000000_u3_missing_tables_storage.sql` definindo as 3 tabelas com schema 100% compatível com Drift (`id UUID`, `owner_id UUID REFERENCES auth.users(id) DEFAULT auth.uid()`, chaves estrangeiras apropriadas, campos de auditoria `created_at`, `updated_at`, `deleted_at`, `revision`).
  2. Ativar Row-Level Security (RLS) estrito nas 3 tabelas com políticas granulares para SELECT, INSERT, UPDATE e DELETE, garantindo isolamento total por `auth.uid() = owner_id` e bloqueio de usuários anônimos.
  3. Vincular triggers para atualização automática de `updated_at` e incremento de `revision` via `handle_update_audit()`.
  4. Configurar o bucket de Supabase Storage `voice_notes` como estritamente privado (`public = false`), limitando o tamanho dos arquivos a 10 MB e restringindo aos MIME types de áudio (`audio/m4a`, `audio/x-m4a`, `audio/mp4`, `audio/aac`).
  5. Definir políticas RLS em `storage.objects` restringindo leitura, upload, atualização e exclusão aos usuários proprietários (`owner = auth.uid()` ou dono da nota de voz vinculada).
  6. Implementar método `requeueFailedSyncOperations()` em `AppRepository` para recuperação segura de itens em estado `failed` com 5 tentativas, sem descarte de histórico.
- **Consequências:** Bloqueador crítico P0-02 categoricamente eliminado. O schema remoto do Supabase agora cobre todas as 10 entidades mapeadas no sincronizador. Validado por 15 novos testes dedicados em `test/sync/supabase_u3_schema_storage_test.dart`.

---

### ADR-021: Integridade de Exclusões Lógicas (Soft Delete), Propagação via Tombstones e Prevenção de Ressurreição
- **Data:** 02 de Novembro de 2026 (Fase 2 — Unidade U3.1)
- **Status:** Aprovado e Implementado
- **Contexto:** A operação `DELETE` na outbox executava `activeClient.from(table).delete().eq('id', op.entityId)` fisicamente no Supabase. Isso destruía o histórico, impedia a propagação de exclusões para outros dispositivos via `fetchRemoteChanges` (já que a linha não existia mais para ter `updated_at > last_synced_at`), arriscava cascatas indesejadas no PostgreSQL e permitia que nós desconectados ressuscitassem registros excluídos via upsert antigo.
- **Decisão:**
  1. Eliminar completamente a chamada `.delete()` no cliente Supabase.
  2. Implementar soft delete via `.update({'deleted_at': ..., 'updated_at': ..., 'revision': ...})` na outbox para todas as 10 tabelas sincronizadas.
  3. Preservar `deleted_at` em operações de `INSERT` e `UPDATE` quando o registro local já for um tombstone, impedindo sobrescritas acidentais com `deleted_at = null`.
  4. Implementar barreira contra ressurreição no cliente (`_applyRemoteRecord`): registros remotos ativos não sobrescrevem tombstones locais a menos que comprovem restauração deliberada mais recente (`remoteRev > localRev` e `remoteUpdated > localDeletedAt`).
  5. Implementar barreira contra ressurreição no PostgreSQL (`handle_soft_delete_and_resurrection_guard()` na migração `20261102010000_u3_1_soft_delete_tombstones.sql`) com tratamento rigoroso de `NULL` via `COALESCE` e script de reversão.
  6. Migrar o cursor incremental para ordenação e filtro composto `(updated_at, id)`, assegurando que tombstones criados no mesmo instante nunca sejam ignorados na paginação, interrompendo antecipadamente se `rows.length < pageSize` e congelando o cursor caso ocorra falha de aplicação na tabela.
  7. Desacoplar a aplicação de tombstones recebidos (`_softDeleteLocalEntry`) dos métodos de negócio do `AppRepository`, garantindo atualização atômica de `deletedAt`, `updatedAt` e `revision` no Drift, sem download inútil de áudio e com zero loop de outbox.
  8. Fornecer fallbacks seguros em `_prepareEntryMap` para colunas obrigatórias de contatos telefônicos, marcos e notas de voz em tombstones parciais.
- **Consequências:** Exclusão física remota abolida. Propagação confiável de exclusões entre dispositivos heterogêneos. Proteção contra ressurreição por upserts antigos. Validado por 11 testes em `test/sync/supabase_soft_delete_test.dart` (Testes A a K). Detalhes em `docs/engineering/ADR_U3_1_SOFT_DELETE_TOMBSTONES.md`.

---

### ADR-022: Hardening Definitivo de Sincronização, 3-Way Merge e Segurança Supabase Storage
- **Data:** 02 de Novembro de 2026 (Fase 2 — Unidade U3.2)
- **Status:** Aprovado e Implementado
- **Contexto:** Após as Unidades U3 e U3.1, a auditoria detalhada de resiliência identificou 9 apontamentos (BUG-U3-02 a BUG-U3-10) e duas melhorias arquiteturais de U2 pendentes (ISSUE-U2-01 e ISSUE-U2-02). Especificamente:
  1. `PhoneContactsManager`, `LandmarkManager` e `VoiceNotesManager` enfileiravam operações de edição na `sync_queue` sem o snapshot `_base` e sem incrementar `revision`, tornando a resolução 3-way merge cega.
  2. As políticas RLS do Supabase Storage no bucket `voice_notes` permitiam upload quando `owner` fosse `NULL`, criando risco de sobrescrita.
  3. Atualizações remotas de notas de voz apagavam o caminho de áudio local em disco (`audioFilePath`) quando o servidor não retornava caminho remoto de arquivo.
  4. Migrações PostgreSQL usavam `timezone('utc'::text, now())` em colunas `TIMESTAMPTZ`, gerando inconsistências de timezone.
  5. Campo `tags` em `phone_contacts` era serializado como string JSON (`jsonEncode`) em vez de array nativo JSONB aceito pelo Supabase.
  6. `requeueFailedSyncOperations` não possuía guarda contra lista vazia, não era atômico e sobrescrevia contadores indevidamente.
- **Decisão:**
  1. **3-Way Merge Real:** Capturar o snapshot pré-edição (`existing.toMap()`) e gravá-lo no payload como `_base` em `updatePhoneContact`, `updateLandmark` e `saveVoiceNote`, incrementando atômica e monotonicamente `revision: Value(existing.revision + 1)`. Em `_applyRemoteRecord`, passar esse `baseData` real para `SyncEngine.mergeEntities`.
  2. **Transacionalidade Local:** Envolver todas as operações de mutação de managers em `db.transaction`, garantindo atomicidade entre a gravação na tabela primária e o enfileiramento na `sync_queue`.
  3. **Preservação de Áudio Local:** Em `_updateLocalEntry` e `_applyRemoteRecord` para `voice_notes`, consultar a entidade local prévia e preservar explicitamente `existing.audioFilePath` caso a resposta remota seja nula ou vazia.
  4. **Segurança Supabase Storage e RLS:** Criar migração versionada `20261102020000_u3_2_storage_and_hardening.sql`:
     - Nova política `voice_notes_storage_insert` que valida estritamente a posse da nota de voz vinculada via `EXISTS (SELECT 1 FROM public.voice_notes vn WHERE vn.id::text = regexp_replace(storage.objects.name, '\.[^.]+$', '') AND vn.owner_id = auth.uid())`.
     - Suporte multi-extensão (.mp4, .aac, .m4a) na validação de nome do arquivo via regex.
     - Substituição de `timezone('utc'::text, now())` por `now()` padrão de PostgreSQL em defaults e triggers de todas as tabelas.
  5. **Normalização JSONB:** Em `toRemotePayload`, decodificar strings JSON de `tags` para `List<dynamic>` nativo do Dart antes do envio via PostgREST, além de converter inteiros para booleanos nas flags de WhatsApp e Redes Sociais.
  6. **Resiliência do Requeue:** Proteger `requeueFailedSyncOperations` com retorno precoce se `operationIds.isEmpty`, envolver em `db.transaction`, e limitar tentativas com clamping: `attempts < 4 ? attempts : 4`.
  7. **Recuperação de Boot (ISSUE-U2-01):** Implementar `SupabaseInitializer.retryInitialization()` e `retrySupabaseInitializationIfConfigured()`.
  8. **Reatividade da Outbox (ISSUE-U2-02):** Implementar e expor `OutboxRecoveryNotifier`, `outboxRecoveryProvider` e `failedSyncOperationsStreamProvider`.
  9. **Tratamento de Migrações Drift:** Registrar erros estruturados com `AppLogger.error` e emitir `rethrow` de exceções de DDL em `_migrateLandmarksColumns`, `_migrateCustomTablesColumns` e `_migrateLegacyKvStore`.
- **Consequências:** Eliminação categórica de todos os 9 defeitos auditados. Sistema atinge consistência determinística multidispositivo sem sobrescrita cega, sem vazamento de arquivos de áudio, com RLS estrito e resiliência completa da outbox. Validado por 13 testes em `test/sync/supabase_hardening_u3_2_test.dart`.

---

### ADR-023: Otimização Cartográfica GIS, Isolamento Multiplataforma de Calendários Web e Automação de Agenda
- **Data:** 03 de Novembro de 2026 (Fase 2 Conclusão — Sessão Handoff & Deploy Remoto)
- **Status:** Aprovado e Implementado
- **Contexto:** 
  1. Durante a navegação no mapa ministerial (`contacts_map_screen.dart`), ao alterar zoom rapidamente geravam-se até 121 requisições HTTP na fila FIFO sem cancelamento, travando a thread da interface por espera de timeouts e gerando congelamentos de tela.
  2. Na plataforma Web (navegador), o plugin `device_calendar` (utilizado por `AppleEventKitProvider`) não possui implementação registrada, lançando `MissingPluginException` na abertura da tela `ConnectedCalendarsScreen` ou na tentativa de autenticação Google.
  3. A tela de Agenda (`AppointmentsScreen`) apresentava poluição visual com banners fixos de importação/exportação `.ics` e ausência de sincronização automática com o ciclo de vida da aplicação.
- **Decisão:**
  1. **Fluidez Cartográfica GIS (`TileCacheCancellable`):**
     - Implementar interface `TileCacheCancellable` com cancelamento imediato de requisições de download pertencentes a níveis de zoom anteriores que o usuário já ultrapassou (`cancelZoomExcept`).
     - Desacoplar a escrita em disco com salvamento assíncrono em segundo plano (`_saveTileAsync`), liberando a fila de rede instantaneamente.
     - Ordenar requisições pelo ponto focal real visualizado no viewport (`focalTileX, focalTileY`), priorizando blocos centrais visíveis.
     - Implementar `getFallbackTileAsync` para recuperar blocos ancestrais do disco em ~1ms enquanto os novos blocos carregam.
     - Implementar cache negativo com bloqueio de 20s para falhas repetidas (429/404) e cancelamento no `dispose()`.
  2. **Isolamento de Plataforma Web (`_isWebPlatform`):**
     - Adicionar guarda `_isWebPlatform` em `AppleEventKitProvider`, interceptando todas as chamadas nativas (`isAuthorized`, `requestAuthorization`, `getAvailableCalendars`, `syncEvents`, etc.) quando executado na Web e retornando imediatamente sem acessar o canal de plataforma.
     - Exibir card com badge informativo "Apenas iOS" na interface Web.
     - Adicionar suporte ao fluxo moderno Google Identity Services (GIS) Web OAuth em `GoogleCalendarProvider` (`authorizationClient.authorizeScopes`), contornando a indisponibilidade de `authenticate()` nativo no navegador.
  3. **Centralização de ICS em Ajustes e Automação de Sync:**
     - Criar componente modal desacoplado `showIcsManagementModal` (`lib/appointments/ics_management_sheet.dart`) com suporte a exportação e importação, centralizado na tela de Ajustes (`SettingsScreen`) e atalho em `ConnectedCalendarsScreen`.
     - Limpar `AppointmentsScreen` e integrar escuta com `WidgetsBindingObserver` para executar pull automático de compromissos ao retornar ao app (`AppLifecycleState.resumed`) e push imediato ao criar, editar ou excluir compromissos.
- **Justificativa:** Proporciona navegação a 60 fps no mapa sem retenção de requisições obsoletas, elimina exceções de plugins na Web e simplifica o fluxo de trabalho da agenda.
- **Consequências:** Navegação fluida no mapa, compatibilidade Web completa sem exceções de plugins e sincronização automatizada da agenda em background. Validado por 41 testes automatizados dedicados em `test/map_tiles_and_performance_hardening_test.dart` (9 testes), `test/appointments/web_calendar_platform_isolation_test.dart` (15 testes) e `test/appointments/ics_settings_management_test.dart` (7 testes) e `test/sync/u3_2_integrated_acceptance_test.dart` (11 testes).
