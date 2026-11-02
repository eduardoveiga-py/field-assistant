# REGISTRO HISTÓRICO DE DECISÕES DE ENGENHARIA (ADRs)

Este registro preserva o contexto, as alternativas ponderadas e as consequências de todas as decisões arquiteturais tomadas durante a estabilização e evolução do **Field Assistant**.

---

## ADR-001: Eliminação de Fallback Silencioso para `Directory.systemTemp`
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** Em `lib/settings/backup_service.dart`, `_getDocsDir()` capturava `MissingPluginException` e retornava `Directory.systemTemp`.
- **Decisão:** Rejeitar qualquer uso de diretórios temporários para snapshots de segurança e arquivos de mídia. Lançar explicitamente `StorageUnavailableException`.
- **Justificativa:** O sistema operacional pode expurgar o diretório temporário a qualquer momento para liberar espaço, destruindo notas de voz e inviabilizando restaurações.
- **Consequências:** Aplicação falha de maneira controlada com aviso de erro em vez de perder dados silenciosamente. Validado por `TC-BAK-ADV-03`.

---

## ADR-002: Staging em Três Etapas para Restauração de Áudios
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

## ADR-003: Ordenação Determinística Composta no Cursor de Sincronização Supabase
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** A paginação remota em `lib/sync/supabase_sync_service.dart` ordenava apenas por `updated_at`. Quando múltiplos registros compartilhavam o mesmo milissegundo, a fronteira de página pulava registros não processados.
- **Decisão:** Ordenar estritamente por `.order('updated_at', ascending: true).order('id', ascending: true)`. O cursor no KV store só avança até o carimbo de data/hora do último registro efetivamente aplicado no banco local.
- **Justificativa:** Elimina perda silenciosa de dados em cargas em lote.
- **Consequências:** Sincronização incremental 100% determinística. Validado por `TC-SYNC-ADV-01`.

---

## ADR-004: Enfileiramento Obrigatório de Mutações Indiretas na Outbox
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** O método `createVisit()` em `lib/database/repository.dart` atualizava `people` (alterando `lastContactAt` e `nextActionNote`), mas só enfileirava a operação para `visits`. O outro aparelho recebia a visita, mas o contato permanecia desatualizado.
- **Decisão:** Toda mutação em qualquer tabela secundária dentro de uma transação local deve enfileirar sua respectiva operação na `sync_queue` contendo snapshot `baseData`.
- **Justificativa:** Previne divergências de estado entre múltiplos dispositivos.
- **Consequências:** Atualização síncrona de metadados em todos os nós. Validado por `TC-SYNC-ADV-04`.

---

## ADR-005: Ativação Obrigatória de `PRAGMA foreign_keys = ON;` e `WAL`
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

## ADR-006: Proteção contra Consultas Parciais Truncadas no Apple EventKit
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** Quando o iOS ou `device_calendar` sofria limitação ou retornava um subconjunto parcial de eventos, o sincronizador interpretava os eventos ausentes como exclusões externas e apagava os vínculos pastorais.
- **Decisão:** Detectar anomalias de exclusão em massa (>25% de ausência súbita sem exclusão confirmada) e suspender a remoção automática, solicitando confirmação.
- **Justificativa:** Protege os dados ministeriais contra instabilidades transitórias da API do sistema operacional.
- **Consequências:** Zero perda indevida de agendamentos. Validado por `TC-APPLE-ADV-01`.

---

## ADR-007: Inclusão da Regra de Recorrência no Fingerprint SHA-256
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** O cálculo do hash de alteração de eventos de calendário ignorava a string de regra de recorrência (`RRULE`). Alterações de frequência não eram detectadas.
- **Decisão:** Incluir o campo `recurrenceRuleStr` determinístico no cálculo de `computeEventFingerprint()`.
- **Justificativa:** Garante reconciliação exata entre compromissos recorrentes e avulsos.
- **Consequências:** Reconciliação imediata ao alterar repetição de compromissos. Validado por `TC-APPLE-ADV-02`.

---

## ADR-008: Não Substituição do Hourglass para Gestão de Territórios
- **Data:** Novembro de 2026
- **Status:** Aprovado e Mantido
- **Contexto:** O usuário utiliza a plataforma consolidada Hourglass para gerenciamento cartográfico e de designação de territórios.
- **Decisão:** Manter o escopo do mapa no Field Assistant estritamente como visualizador geográfico de contatos próprios (`contacts_map_screen.dart`), sem tentar reinventar módulos de controle de congregação do Hourglass.
- **Justificativa:** Evita duplicação de esforço e preserva a especialização ministerial do aplicativo.

---

## ADR-009: Proibição de Migrações Destrutivas por Feature Flags
- **Data:** Novembro de 2026
- **Status:** Aprovado e Mantido
- **Contexto:** Em `customize_features_screen.dart`, o usuário pode desativar telas ou submódulos (ex: experiências, publicações, notas de voz).
- **Decisão:** A desativação de uma funcionalidade na interface apenas oculta seus pontos de entrada na UI. É expressamente proibido disparar `DROP TABLE` ou `DELETE` em dados históricos. Ao reativar a flag, todos os dados devem reaparecer intactos.
- **Justificativa:** Preservação categórica do patrimônio de registros do publicador.

---

## ADR-010: Centralização e Validação Imutável de Ambiente via `AppConfig`
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
- **Consequências:** Inicialização 100% determinística, logs higienizados sem segredos e distinção formal entre modo offline e queda de rede. Validado pela suíte `test/core/app_config_test.dart` (9 testes dedicados, totalizando 517 testes no repositório).

---

## ADR-011: Inicialização Resiliente, Desacoplada e Ciclo de Vida do Supabase
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
- **Consequências:** Zero dependência de rede no boot, zero crashes por `AssertionError`, durabilidade garantida da outbox local, reatividade Riverpod e recuperação automática de conectividade. Validado por 30 testes dedicados em `test/core/supabase_initializer_test.dart` e `test/sync/supabase_lifecycle_test.dart`, elevando o total da suíte para 547 testes 100% aprovados.

---

### ADR-012: Schema Remoto Supabase, Storage Privado de Áudio e Validação RLS (Unidade U3)
- **Status:** Aprovado
- **Data:** 02 de Novembro de 2026
- **Contexto:** A auditoria inicial (Fase 1) identificou o bloqueador crítico P0-02: ausência das tabelas `voice_notes`, `phone_contacts` e `territory_landmarks` e do bucket de Storage `voice_notes` na migração remota do Supabase (`supabase/migrations/20261026000000_initial_schema.sql`). Embora o sincronizador (`SupabaseSyncService`) já incluísse essas entidades em `syncTables` e realizasse a sanitização e upload de binários, qualquer tentativa de sincronização real dessas 3 entidades contra o Supabase falharia por falta das tabelas remotas ou do bucket de armazenamento.
- **Decisão:**
  1. Criar a migração versionada `supabase/migrations/20261102000000_u3_missing_tables_storage.sql` definindo as 3 tabelas com schema 100% compatível com Drift (`id UUID`, `owner_id UUID REFERENCES auth.users(id) DEFAULT auth.uid()`, chaves estrangeiras apropriadas, campos de auditoria `created_at`, `updated_at`, `deleted_at`, `revision`).
  2. Ativar Row-Level Security (RLS) estrito nas 3 tabelas com políticas granulares para SELECT, INSERT, UPDATE e DELETE, garantindo isolamento total por `auth.uid() = owner_id` e bloqueio de usuários anônimos.
  3. Vincular triggers para atualização automática de `updated_at` e incremento de `revision` via `handle_update_audit()`.
  4. Configurar o bucket de Supabase Storage `voice_notes` como estritamente privado (`public = false`), limitando o tamanho dos arquivos a 10 MB e restringindo aos MIME types de áudio (`audio/m4a`, `audio/x-m4a`, `audio/mp4`, `audio/aac`).
  5. Definir políticas RLS em `storage.objects` restringindo leitura, upload, atualização e exclusão aos usuários proprietários (`owner = auth.uid()` ou dono da nota de voz vinculada).
  6. Implementar método `requeueFailedSyncOperations()` em `AppRepository` para recuperação segura de itens em estado `failed` com 5 tentativas, atendendo à pendência ISSUE-U2-02 sem descarte de histórico.
  7. Manter abertas e documentadas as pendências ISSUE-U2-01 (recuperação automática de falha crítica no boot de `Supabase.initialize()`), ISSUE-U2-03 (teste E2E contínuo com reinicialização em disco) e ISSUE-U2-04 (listener de interfaces de rede).
- **Consequências:** Bloqueador crítico P0-02 categoricamente eliminado. O schema remoto do Supabase agora cobre todas as 10 entidades mapeadas no sincronizador. Validado por 15 novos testes dedicados em `test/sync/supabase_u3_schema_storage_test.dart`, elevando a suíte para 562 testes automatizados 100% aprovados, análise estática limpa (`No issues found!`) e build web release aprovado.

---

### ADR-013: Integridade de Exclusões Lógicas (Soft Delete), Propagação via Tombstones e Prevenção de Ressurreição (Unidade U3.1)
- **Status:** Aprovado
- **Data:** 02 de Novembro de 2026
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
- **Consequências:** Exclusão física remota abolida. Propagação confiável de exclusões entre dispositivos heterogêneos. Proteção contra ressurreição por upserts antigos. Validado por 11 novos testes formais em `test/sync/supabase_soft_delete_test.dart` (Testes A a K), elevando a suíte para 573 testes aprovados (100%), 0 issues de análise estática e build web release aprovado. Detalhes em `docs/engineering/ADR_U3_1_SOFT_DELETE_TOMBSTONES.md`.




