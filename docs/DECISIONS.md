# Registro Canônico de Decisões de Arquitetura (ADR): Field Assistant

Este documento constitui o **registro canônico unificado** de todas as Decisões de Arquitetura (Architectural Decision Records — ADRs) do projeto **Field Assistant (Ministério Pessoal)**. 

Ele consolida as decisões fundamentais de concepção do sistema (ADR-001 a ADR-008) e as decisões de engenharia, resiliência e estabilização (ADR-009 a ADR-023), eliminando duplicidades históricas e colisões de numeração anteriores entre a documentação de nível raiz e os arquivos de engenharia.

---

## Índice Sequencial de Decisões

| ADR | Título | Categoria | Status |
|:---:|---|---|:---:|
| [ADR-001](#adr-001-adoção-do-flutter-com-suporte-a-web-e-ios) | Adoção do Flutter com Suporte a Web e iOS | Fundação Arquitetural | Aprovado |
| [ADR-002](#adr-002-banco-de-dados-local-drift-sqlite--wasm) | Banco de Dados Local Drift (SQLite & Wasm) | Fundação Arquitetural | Aprovado |
| [ADR-003](#adr-003-backend-supabase-com-row-level-security-rls-via-owner_id) | Backend Supabase com Row Level Security (RLS) via `owner_id` | Fundação Arquitetural | Aprovado |
| [ADR-004](#adr-004-fila-de-sincronização-transacional-com-resolução-de-conflitos) | Fila de Sincronização Transacional com Resolução de Conflitos | Fundação Arquitetural | Aprovado |
| [ADR-005](#adr-005-formatação-de-horários-e-agenda-tipo-consultório) | Formatação de Horários e Agenda Tipo Consultório | Fundação Arquitetural | Aprovado |
| [ADR-006](#adr-006-envelope-criptográfico-de-backup-v2-com-pbkdf2-hmac-sha256-e-aes-256-gcm) | Envelope Criptográfico de Backup v2 com PBKDF2-HMAC-SHA256 e AES-256-GCM | Fundação Arquitetural | Aprovado |
| [ADR-007](#adr-007-serviços-reais-de-áudio-e-ditado-com-degradação-graciosa) | Serviços Reais de Áudio e Ditado com Degradação Graciosa | Fundação Arquitetural | Aprovado |
| [ADR-008](#adr-008-evolução-do-esquema-drift-v2-com-tabelas-fortemente-tipadas) | Evolução do Esquema Drift v2 com Tabelas Fortemente Tipadas | Fundação Arquitetural | Aprovado |
| [ADR-009](#adr-009-eliminação-de-fallback-silencioso-para-directorysystemtemp) | Eliminação de Fallback Silencioso para `Directory.systemTemp` | Engenharia & Resiliência | Aprovado |
| [ADR-010](#adr-010-staging-em-três-etapas-para-restauração-de-áudios) | Staging em Três Etapas para Restauração de Áudios | Engenharia & Resiliência | Aprovado |
| [ADR-011](#adr-011-ordenação-determinística-composta-no-cursor-de-sincronização-supabase) | Ordenação Determinística Composta no Cursor de Sincronização Supabase | Engenharia & Resiliência | Aprovado |
| [ADR-012](#adr-012-enfileiramento-obrigatório-de-mutações-indiretas-na-outbox) | Enfileiramento Obrigatório de Mutações Indiretas na Outbox | Engenharia & Resiliência | Aprovado |
| [ADR-013](#adr-013-ativação-obrigatória-de-pragma-foreign_keys--on-e-wal) | Ativação Obrigatória de `PRAGMA foreign_keys = ON;` e `WAL` | Engenharia & Resiliência | Aprovado |
| [ADR-014](#adr-014-proteção-contra-consultas-parciais-truncadas-no-apple-eventkit) | Proteção contra Consultas Parciais Truncadas no Apple EventKit | Engenharia & Resiliência | Aprovado |
| [ADR-015](#adr-015-inclusão-da-regra-de-recorrência-no-fingerprint-sha-256) | Inclusão da Regra de Recorrência no Fingerprint SHA-256 | Engenharia & Resiliência | Aprovado |
| [ADR-016](#adr-016-não-substituição-do-hourglass-para-gestão-de-territórios) | Não Substituição do Hourglass para Gestão de Territórios | Engenharia & Resiliência | Aprovado |
| [ADR-017](#adr-017-proibição-de-migrações-destrutivas-por-feature-flags) | Proibição de Migrações Destrutivas por Feature Flags | Engenharia & Resiliência | Aprovado |
| [ADR-018](#adr-018-centralização-e-validação-imutável-de-ambiente-via-appconfig) | Centralização e Validação Imutável de Ambiente via `AppConfig` | Engenharia & Resiliência | Aprovado |
| [ADR-019](#adr-019-inicialização-resiliente-desacoplada-e-ciclo-de-vida-do-supabase) | Inicialização Resiliente, Desacoplada e Ciclo de Vida do Supabase | Engenharia & Resiliência | Aprovado |
| [ADR-020](#adr-020-schema-remoto-supabase-storage-privado-de-áudio-e-validação-rls) | Schema Remoto Supabase, Storage Privado de Áudio e Validação RLS | Engenharia & Resiliência | Aprovado |
| [ADR-021](#adr-021-integridade-de-exclusões-lógicas-soft-delete-propagação-via-tombstones-e-prevenção-de-ressurreição) | Integridade de Exclusões Lógicas (Soft Delete), Propagação via Tombstones e Prevenção de Ressurreição | Engenharia & Resiliência | Aprovado |
| [ADR-022](#adr-022-hardening-definitivo-de-sincronização-3-way-merge-e-segurança-supabase-storage) | Hardening Definitivo de Sincronização, 3-Way Merge e Segurança Supabase Storage | Engenharia & Resiliência | Aprovado |
| [ADR-023](#adr-023-otimização-cartográfica-gis-isolamento-multiplataforma-de-calendários-web-e-automação-de-agenda) | Otimização Cartográfica GIS, Isolamento Multiplataforma de Calendários Web e Automação de Agenda | Engenharia & Resiliência | Aprovado |

---

## Seção 1: Fundações Arquiteturais (ADR-001 a ADR-008)

### ADR-001: Adoção do Flutter com Suporte a Web e iOS
- **Contexto:** Necessidade de aplicação executável no Windows (Web/Desktop) e em dispositivos móveis da Apple (iPhone XR e iPad 11 A16), com uma base de código compartilhada.
- **Decisão:** Utilizar Flutter com Dart estável.
- **Consequências:**
  - Código único para interface, modelo de domínio, lógica de sincronização e testes.
  - Testabilidade automatizada via `flutter test` direto no ambiente Windows de desenvolvimento.
  - Preparado para compilação nativa iOS via runner macOS em GitHub Actions.

### ADR-002: Banco de Dados Local Drift (SQLite & Wasm)
- **Contexto:** Sistema estritamente offline-first. Necessidade de integridade relacional, consultas tipadas, migrações versionadas e persistência real no navegador.
- **Decisão:** Adotar Drift com backend SQLite nativo (`NativeDatabase`) e SQLite Wasm com IndexedDB na Web (`WasmDatabase`).
- **Consequências:**
  - Zero risco de perda de dados ao recarregar a página web ou ficar sem rede móvel.
  - Consultas reativas nativas com streams automáticos para atualização de telas.
  - Não dependência de arquivos monolíticos para sincronização.

### ADR-003: Backend Supabase com Row Level Security (RLS) via `owner_id`
- **Contexto:** Sincronização multi-dispositivo segura sem expor dados a outros usuários, mantendo esquema relacional e escalabilidade.
- **Decisão:** Adotar Supabase com PostgreSQL e autenticação por email/senha, aplicando isolamento rigoroso de Row Level Security onde cada tabela possui coluna `owner_id = auth.uid()`.
- **Consequências:**
  - Aplicação estrita de regras de segurança por linha em todas as tabelas remotas via `owner_id = auth.uid()`.
  - Zero uso ou exposição de chaves secretas de administrador (`service_role`) no cliente.
  - Abstração local que permite funcionamento com modo offline-only sem requerer credenciais na inicialização.

### ADR-004: Fila de Sincronização Transacional com Resolução de Conflitos
- **Contexto:** Riscos de concorrência e perdas silenciosas quando o usuário edita anotações no campo (offline) e no iPad em casa.
- **Decisão:** Fila persistente `sync_queue` com operações atômicas, controle de revisão monotônica e algoritmo de 3-way merge determinístico com retenção de versões conflitantes para decisão humana consciente.
- **Consequências:**
  - Proibição de "last-write-wins" cego em anotações de conversas.
  - Histórico de revisitas e sessões de estudos preservado como registros imutáveis pontuais.

### ADR-005: Formatação de Horários e Agenda Tipo Consultório
- **Contexto:** No ministério de campo, o usuário combina retornos com o morador e precisa de verificação instantânea de disponibilidade.
- **Decisão:** Motor de disponibilidade (`AvailabilityEngine`) que analisa intervalos `[start, end]` contra a base de dados local antes da confirmação, gerando opções alternativas em caso de colisão e marcando `is_provisional: true` e status `conflito` em colisões recebidas da nuvem.
- **Consequências:**
  - Impossibilidade de sobreposição involuntária de visitas na interface.
  - Suporte resiliente a agendamentos provisórios quando criados offline ou em conflito pós-sincronização.

### ADR-006: Envelope Criptográfico de Backup v2 com PBKDF2-HMAC-SHA256 e AES-256-GCM
- **Contexto:** Garantir integridade e confidencialidade máxima das exportações de dados do ministério, com chave mestra do dispositivo e compatibilidade retroativa com arquivos v1.
- **Decisão:** Adotar envelope criptográfico versão 2 contendo salt de 16 bytes gerado via `Random.secure()`, derivação de chave por PBKDF2-HMAC-SHA256 com 100.000 iterações, cifra autenticada AES-256-GCM com tag de 128 bits e IV aleatório de 16 bytes. Backups silenciosos utilizam segredo de dispositivo gerado e persistido no `app_kv_store` local.
- **Consequências:**
  - Impossibilidade matemática de adulteração silenciosa do arquivo de backup (autenticação de integridade integrada no GCM).
  - Proteção robusta contra força bruta por meio das 100.000 iterações de derivação de chave.
  - Compatibilidade com restauração de arquivos v1 legados (AES-CBC + checksum SHA-256).

### ADR-007: Serviços Reais de Áudio e Ditado com Degradação Graciosa
- **Contexto:** Necessidade de gravação de notas rápidas pós-visita no ministério de campo utilizando hardware real (microfone e reconhecimento de voz), mantendo fakes de teste headless.
- **Decisão:** Implementação de `RealAudioRecordingService` (`package:record`), `RealAudioPlayerService` (`package:audioplayers`) e `RealVoiceDictationService` (`package:speech_to_text`), com timer físico que comanda parada compulsória de hardware aos 30 segundos, mantendo fakes completos para testes automatizados.
- **Consequências:**
  - Suporte a gravação m4a/aac nativa no diretório de documentos do app com parada comprovada do hardware aos 30s.
  - Tratamento de negação de permissão de microfone com feedback explícito em tela e fallback para entrada manual digitada.
  - Ditado contínuo em pt-BR com orientação em tela caso o modelo de voz offline do iOS não esteja instalado.

### ADR-008: Evolução do Esquema Drift v2 com Tabelas Fortemente Tipadas
- **Contexto:** Módulos de notas de voz, importação de contatos da agenda, marcos territoriais e armazenamento chave-valor utilizavam consultas SQL cruas ou criação manual de tabelas.
- **Decisão:** Evoluir o esquema Drift para versão 2 com as tabelas tipadas `VoiceNotes`, `PhoneContacts`, `TerritoryLandmarks` e `AppKvStore`, integradas ao repositório transacional e ao mecanismo de migração segura.
- **Consequências:**
  - Tipagem estrita de colunas no Dart com DAOs nativos.
  - Suporte a transações atômicas multi-entidade (ex: `saveQuickVisitFromVoiceNote` grava visita, nota e atualiza estudante/participante em uma única transação).
  - Reconstituição fiel de entidades adicionais no backup e no sync remoto.

---

## Seção 2: Engenharia, Resiliência e Hardening (ADR-009 a ADR-023)

### ADR-009: Eliminação de Fallback Silencioso para `Directory.systemTemp`
- **Contexto:** Em `lib/settings/backup_service.dart`, `_getDocsDir()` capturava `MissingPluginException` e recorria silenciosamente a `Directory.systemTemp`.
- **Decisão:** Rejeitar categoricamente o uso de armazenamento temporário para snapshots e áudios. Lançar `StorageUnavailableException` de forma explícita caso o sistema operacional não forneça armazenamento persistente seguro.
- **Justificativa:** Armazenamento temporário pode ser limpo pelo SO a qualquer momento para liberar espaço, destruindo notas de voz e inviabilizando restaurações.
- **Consequências:** Aplicação falha de maneira controlada com aviso de erro em vez de perder dados silenciosamente. Validado por `TC-BAK-ADV-03`.

### ADR-010: Staging em Três Etapas para Restauração de Áudios
- **Contexto:** Arquivos de notas de voz eram descompactados diretamente na pasta final `/voice_notes/`. Se a transação SQLite falhasse depois, o bloco catch chamava `deleteSync()`, apagando áudios que já existiam antes da restauração.
- **Decisão:** Implementar fluxo de staging em 3 etapas:
  1. Extrair para pasta temporária de staging (`safety_staging/<uuid>/`).
  2. Fazer backup prévio de qualquer arquivo existente que vá ser substituído (`safety_audio_backup/<uuid>/`).
  3. Mover atomicamente para o destino apenas após a confirmação da transação do banco relacional.
  4. Em caso de falha, reverter os arquivos substituídos a partir do backup e limpar o staging.
- **Justificativa:** Garante transacionalidade mútua entre o sistema de arquivos e o banco relacional.
- **Consequências:** Zero perda de mídias originais durante restaurações com falha. Validado por `TC-BAK-ADV-01` e `TC-BAK-ADV-02`.

### ADR-011: Ordenação Determinística Composta no Cursor de Sincronização Supabase
- **Contexto:** A paginação remota em `lib/sync/supabase_sync_service.dart` ordenava apenas por `updated_at`. Quando múltiplos registros compartilhavam o mesmo milissegundo, a fronteira de página pulava registros não processados.
- **Decisão:** Ordenar estritamente por `.order('updated_at', ascending: true).order('id', ascending: true)`. O avanço do cursor no `app_kv_store` ocorre apenas até o timestamp do último registro persistido com sucesso no SQLite local.
- **Justificativa:** Elimina perda silenciosa de dados em sincronizações de múltiplos registros.
- **Consequências:** Sincronização incremental 100% determinística. Validado por `TC-SYNC-ADV-01`.

### ADR-012: Enfileiramento Obrigatório de Mutações Indiretas na Outbox
- **Contexto:** Métodos como `createVisit()` em `lib/database/repository.dart` atualizavam a tabela `people` (alterando `lastContactAt` e `nextActionNote`), mas só enfileiravam uma operação de sincronização para `visits`. O outro dispositivo recebia a visita mas o contato ficava desatualizado.
- **Decisão:** Toda mutação local em qualquer entidade dentro de uma transação deve registrar sua respectiva operação na `sync_queue` com seu snapshot `baseData`.
- **Justificativa:** Previne divergências de estado entre múltiplos dispositivos.
- **Consequências:** Atualização síncrona de metadados em todos os nós. Validado por `TC-SYNC-ADV-04`.

### ADR-013: Ativação Obrigatória de `PRAGMA foreign_keys = ON;` e `WAL`
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

### ADR-014: Proteção contra Consultas Parciais Truncadas no Apple EventKit
- **Contexto:** Quando o iOS ou `device_calendar` sofria limitação ou retornava um subconjunto parcial de eventos, o sincronizador interpretava os eventos ausentes como exclusões externas e apagava os vínculos pastorais.
- **Decisão:** Detectar anomalias de exclusão em massa (>25% de ausência súbita sem evento explícito de cancelamento) e suspender a remoção automática, solicitando confirmação.
- **Justificativa:** Protege os dados ministeriais contra instabilidades transitórias da API do sistema operacional.
- **Consequências:** Zero perda indevida de agendamentos. Validado por `TC-APPLE-ADV-01`.

### ADR-015: Inclusão da Regra de Recorrência no Fingerprint SHA-256
- **Contexto:** O cálculo do hash de alteração de eventos de calendário ignorava a string de regra de recorrência (`RRULE`). Alterações de frequência não eram detectadas.
- **Decisão:** Incluir o campo `recurrenceRuleStr` determinístico no cálculo de `computeEventFingerprint()`.
- **Justificativa:** Garante reconciliação exata entre compromissos recorrentes e avulsos.
- **Consequências:** Reconciliação imediata ao alterar repetição de compromissos. Validado por `TC-APPLE-ADV-02`.

### ADR-016: Não Substituição do Hourglass para Gestão de Territórios
- **Contexto:** O usuário utiliza a plataforma consolidada Hourglass para gerenciamento cartográfico e de designação de territórios da congregação.
- **Decisão:** Manter o escopo do mapa no Field Assistant estritamente como visualizador geográfico de contatos próprios (`contacts_map_screen.dart`), sem tentar reinventar módulos de controle de congregação do Hourglass.
- **Justificativa:** Evita duplicação de esforço e preserva a especialização ministerial do aplicativo.
- **Consequências:** Foco no fluxo de trabalho pessoal do publicador.

### ADR-017: Proibição de Migrações Destrutivas por Feature Flags
- **Contexto:** Em `customize_features_screen.dart`, o usuário pode desativar telas ou submódulos (ex: experiências, publicações, notas de voz).
- **Decisão:** A desativação de uma funcionalidade na interface apenas oculta seus pontos de entrada na UI. É expressamente proibido disparar `DROP TABLE` ou `DELETE` em dados históricos. Ao reativar a flag, todos os dados devem reaparecer intactos.
- **Justificativa:** Preservação categórica do patrimônio de registros do publicador.
- **Consequências:** Inviolabilidade total do banco de dados local.

### ADR-018: Centralização e Validação Imutável de Ambiente via `AppConfig`
- **Contexto:** A injeção de parâmetros do backend Supabase (`SUPABASE_URL` e `SUPABASE_ANON_KEY`) dependia de chamadas dispersas a `String.fromEnvironment()`. Quando variáveis não eram injetadas via `--dart-define-from-file`, o app assumia strings vazias sem distinção clara entre modo offline e falha de conectividade. Havia risco de injeção acidental de credenciais administrativas (`service_role`).
- **Decisão:**
  1. Centralizar a modelagem de ambiente na classe imutável `AppConfig` (`lib/core/app_config.dart`).
  2. Implementar validação estrita com status explícito (`unconfigured`, `valid`, `invalid`).
  3. Rejeitar categoricamente qualquer chave contendo a role `service_role`, `supabase_admin` ou prefixos `sbp_`.
  4. Exigir estritamente HTTPS em ambiente de produção.
  5. Implementar mascaramento compulsório de segredos em logs e `toString()`.
  6. Tratar o modo sem configuração como um estado operacional offline legítimo e seguro (`isOfflineOnly`).
- **Justificativa:** Garante a inviolabilidade do modelo offline-first e elimina vazamento de credenciais.
- **Consequências:** Inicialização 100% determinística e logs limpos. Validado por `test/core/app_config_test.dart`.

### ADR-019: Inicialização Resiliente, Desacoplada e Ciclo de Vida do Supabase
- **Contexto:** O aplicativo dependia de inicialização remota que, se realizada de forma bloqueante no `main()`, travava ou falhava em ambientes sem rede, violando o princípio offline-first. Acessos a `client` não inicializado lançavam `AssertionError`.
- **Decisão:**
  1. Criar o orquestrador `SupabaseInitializer` (`lib/core/supabase_initializer.dart`) com enum de estados granular.
  2. Implementar ordem de boot estrita: SQLite Drift inicializa de forma síncrona imediata; inicialização remota do Supabase ocorre de forma condicional, assíncrona e não-bloqueante (`unawaited`).
  3. Proteger o acesso ao SDK via `clientOrNull` e adicionar escuta ao ciclo de vida (`WidgetsBindingObserver`) para reconexão automática e reavaliação no retorno de segundo plano.
  4. Implementar trava de reentrância assíncrona e algoritmo de backoff exponencial com jitter aleatório (2^tentativas clamped em 300s + jitter 25%).
  5. Pausar o reenvio automático em 5 falhas consecutivas, preservando a durabilidade da fila para auditoria e requeue seguro.
- **Justificativa:** Assegura abertura instantânea e funcionamento local pleno independente de rede.
- **Consequências:** Zero dependência de rede no boot e recuperação automática da outbox. Validado por 30 testes em `test/core/supabase_initializer_test.dart` e `test/sync/supabase_lifecycle_test.dart`.

### ADR-020: Schema Remoto Supabase, Storage Privado de Áudio e Validação RLS
- **Contexto:** O schema remoto do Supabase não possuía as tabelas `voice_notes`, `phone_contacts`, `territory_landmarks` nem o bucket de Storage `voice_notes`, impedindo a sincronização em nuvem dessas entidades (Bloqueador P0-02).
- **Decisão:**
  1. Criar a migração versionada `20261102000000_u3_missing_tables_storage.sql` definindo as 3 tabelas compatíveis com o Drift (`id UUID`, `owner_id UUID REFERENCES auth.users(id) DEFAULT auth.uid()`, auditoria `created_at`, `updated_at`, `deleted_at`, `revision`).
  2. Ativar Row-Level Security (RLS) estrito com isolamento por `owner_id = auth.uid()` em todas as operações (SELECT, INSERT, UPDATE, DELETE).
  3. Configurar o bucket de Storage `voice_notes` como privado (10 MB máximo, MIME types restritos a áudio) com políticas RLS exigindo que o usuário seja dono da nota de voz vinculada.
  4. Implementar método `requeueFailedSyncOperations()` para recuperação segura de itens pausados na outbox.
- **Justificativa:** Garante consistência de esquema entre a base local e o backend em nuvem.
- **Consequências:** Todas as 10 entidades mapeadas sincronizam com segurança. Validado por `test/sync/supabase_u3_schema_storage_test.dart`.

### ADR-021: Integridade de Exclusões Lógicas (Soft Delete), Propagação via Tombstones e Prevenção de Ressurreição
- **Contexto:** A operação `DELETE` na outbox executava `.delete()` físico no Supabase. Isso destruía o histórico, impedia a propagação de exclusões para outros dispositivos via `fetchRemoteChanges` (a linha apagada não gerava delta de atualização) e permitia que nós desconectados ressuscitassem registros excluídos via upserts antigos.
- **Decisão:**
  1. Eliminar completamente chamadas físicas `.delete()` no cliente Supabase.
  2. Implementar soft delete via `.update({'deleted_at': ..., 'updated_at': ..., 'revision': ...})` para todas as 10 tabelas sincronizadas.
  3. Implementar barreira contra ressurreição no PostgreSQL (`handle_soft_delete_and_resurrection_guard()`) impedindo que `deleted_at` seja anulado por registros desatualizados.
  4. Implementar barreira contra ressurreição no cliente (`_applyRemoteRecord`), rejeitando registros ativos sobre tombstones a menos que comprovem restauração deliberada mais recente.
  5. Migrar o cursor incremental para filtro e ordenação composta `(updated_at, id)`.
- **Justificativa:** Garante integridade histórica e propagação confiável de exclusões entre dispositivos heterogêneos.
- **Consequências:** Abolição da perda de dados por deleção física e zero ressurreição indevida. Validado por `test/sync/supabase_soft_delete_test.dart`.

### ADR-022: Hardening Definitivo de Sincronização, 3-Way Merge e Segurança Supabase Storage
- **Contexto:** `PhoneContactsManager`, `LandmarkManager` e `VoiceNotesManager` enfileiravam operações de edição sem o snapshot `_base` e sem incrementar `revision`. As políticas de Storage permitiam upload quando `owner` fosse nulo. Atualizações remotas apagavam caminhos de áudio locais caso o servidor não retornasse o caminho do arquivo.
- **Decisão:**
  1. Capturar o snapshot pré-edição (`_base: existing.toMap()`) e incrementar monotonicamente `revision` dentro de `db.transaction`.
  2. Passar o `baseData` real para `SyncEngine.mergeEntities` com normalização profunda por valor em coleções (`tags`).
  3. Preservar `existing.audioFilePath` local quando o retorno remoto for nulo ou vazio.
  4. Blindar a política RLS do bucket `voice_notes` com validação de posse via subquery relacional (`EXISTS (SELECT 1 FROM public.voice_notes vn WHERE vn.id::text = regexp_replace(...) AND vn.owner_id = auth.uid())`).
  5. Normalizar tags JSONB e flags booleanas em `toRemotePayload`.
  6. Substituir silenciamento `catch (_) {}` em migrações Drift por `AppLogger.error` e `rethrow`.
- **Justificativa:** Assegura consistência determinística sem sobrescrita cega e protege arquivos de áudio contra acesso não autorizado.
- **Consequências:** Sincronização 3-way merge robusta e outbox reativa no Riverpod. Validado por `test/sync/supabase_hardening_u3_2_test.dart`.

### ADR-023: Otimização Cartográfica GIS, Isolamento Multiplataforma de Calendários Web e Automação de Agenda
- **Contexto:** Durante a navegação no mapa, o zoom concorrente gerava até 121 requisições HTTP simultâneas na fila FIFO sem cancelamento, travando a renderização. Na Web, o plugin `device_calendar` disparava `MissingPluginException` na abertura da tela de calendários e na autenticação Google. A tela de Agenda possuía banners fixos de importação .ics que geravam poluição visual.
- **Decisão:**
  1. Criar a interface `TileCacheCancellable` com cancelamento imediato de requisições de níveis de zoom abandonados (`cancelZoomExcept`), ordenação focal pelo centro do viewport (`focalTileX, focalTileY`), escrita assíncrona desacoplada em disco e cache negativo de 20s para falhas de rede.
  2. Implementar barreira de plataforma `_isWebPlatform` em `AppleEventKitProvider`, interceptando todas as chamadas nativas na Web sem acessar canais de plataforma, e suportar fluxo Google Identity Services (GIS) Web OAuth nativo no navegador.
  3. Desacoplar a importação/exportação de arquivos `.ics` em modal dedicado (`showIcsManagementModal`) centralizado em Ajustes, e automatizar a sincronização da agenda com push imediato na mutação de compromissos e pull automático na retomada da aplicação (`AppLifecycleState.resumed`).
- **Justificativa:** Garante fluidez de 60 fps na navegação cartográfica, compatibilidade multiplataforma limpa sem exceções no navegador e interface de agenda despoluída.
- **Consequências:** Mapa rápido e responsivo, zero exceções de plugins na Web e sincronização transparente de calendário. Validado por 41 testes dedicados em `test/map_tiles_and_performance_hardening_test.dart`, `test/appointments/web_calendar_platform_isolation_test.dart` e `test/appointments/ics_settings_management_test.dart`.
