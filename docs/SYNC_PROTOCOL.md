# Protocolo de Sincronização: Ministério Pessoal

## 1. Visão Geral Offline-First (Local-First Architecture)
O aplicativo opera sob o paradigma estrito de **Local-First / Offline-First**:
1. Toda mutação de dados (criação, edição, exclusão lógica) é persistida instantaneamente no SQLite local via Drift (ou Wasm IndexedDB na Web).
2. Na mesma transação atômica (`db.transaction`), a operação correspondente é registrada na tabela persistente `sync_queue` (padrão Transactional Outbox), contendo os dados modificados e o snapshot pré-edição (`_base`).
3. Quando o dispositivo recupera a conectividade e o Supabase está inicializado com credenciais válidas:
   - O `SupabaseSyncService` despacha as operações pendentes da `sync_queue` respeitando a ordem cronológica (`created_at ASC`).
   - O backend PostgreSQL valida as permissões através de Row Level Security (RLS) baseado em `owner_id = auth.uid()`.
   - Modificações remotas concorrentes são mescladas em nível de campo por meio do `SyncEngine.mergeEntities` (3-way merge).
   - Registros confirmados são marcados como `synced` na fila local.

---

## 2. As 10 Tabelas Sincronizadas (`syncTables`)
O serviço de sincronização remota (`SupabaseSyncService.syncTables`) processa ativamente exatamente 10 entidades:

| # | Entidade Drift | Tabela Supabase | Identificador Dono | Isolamento RLS |
|---|----------------|-----------------|--------------------|----------------|
| 1 | `people` | `people` | `owner_id` | `auth.uid() = owner_id` |
| 2 | `visits` | `visits` | `owner_id` | `auth.uid() = owner_id` |
| 3 | `bibleStudies` | `bible_studies` | `owner_id` | `auth.uid() = owner_id` |
| 4 | `studyParticipants` | `study_participants` | `owner_id` | `auth.uid() = owner_id` |
| 5 | `studySessions` | `study_sessions` | `owner_id` | `auth.uid() = owner_id` |
| 6 | `appointments` | `appointments` | `owner_id` | `auth.uid() = owner_id` |
| 7 | `activityRecords` | `activity_records` | `owner_id` | `auth.uid() = owner_id` |
| 8 | `voiceNotes` | `voice_notes` | `owner_id` | `auth.uid() = owner_id` |
| 9 | `phoneContacts` | `phone_contacts` | `owner_id` | `auth.uid() = owner_id` |
| 10 | `territoryLandmarks` | `territory_landmarks` | `owner_id` | `auth.uid() = owner_id` |

*Nota: As 12 tabelas restantes de infraestrutura local, cache, ordenação manual e calendário externo (`sync_queue`, `app_kv_store`, `family_ties`, `person_photos`, `person_publications`, `ministry_experiences`, `research_articles`, `research_tags`, `territory_sectors`, `student_manual_order`, `external_calendar_events`, `calendar_event_links`) são gerenciadas localmente ou integradas via seus respectivos conectores (Google Calendar API, Apple EventKit) sem passar pelo PostgREST do Supabase.*

---

## 3. Sincronização de Áudio com Supabase Storage (`voice_notes`)
A sincronização de notas de voz implementa separação rigorosa entre metadados relacionais e arquivos binários de mídia:

### 3.1 Upload de Binários de Áudio (`_uploadVoiceNoteAudio`)
1. **Sanitização de Metadados:** Ao despachar o JSON de `voice_notes` via PostgREST, `SupabaseSyncService.sanitizePayload` remove categoricamente os campos `audio_file_path` e `audioFilePath`, evitando vazamento de caminhos de arquivos do disco local do dispositivo.
2. **Envio Binário ao Storage:** Após o `upsert` bem-sucedido dos metadados, o arquivo local referenciado em `audioFilePath` é lido do disco.
3. **Bucket e Formatos:** O arquivo é enviado ao bucket privado `voice_notes` no Supabase Storage:
   - MIME types aceitos: `audio/m4a`, `audio/x-m4a`, `audio/mp4`, `audio/aac`.
   - Limite por arquivo: 10 MB.
   - Opções de envio: `FileOptions(upsert: true)`.
4. **Resiliência a Falha:** Se o upload do binário falhar por erro de rede ou timeout, a operação de sincronização é marcada com falha (`markSyncOperationFailed`), incrementando o contador de tentativas para reenvio seguro posterior, sem descartar os metadados já gravados.

### 3.2 Download de Binários de Áudio (`_downloadVoiceNoteAudio`)
1. **Verificação de Cache Local:** Antes de consumir rede, o serviço verifica se o arquivo de áudio já existe no sistema de arquivos local (`existingFile.exists() && length > 0`). Caso positivo, o download é dispensado.
2. **Resolução de Extensão:** Caso o ID não possua extensão explícita, o download avalia candidatos (`.m4a`, `.mp4`, `.aac`).
3. **Gravação Segura:** O arquivo baixado é gravado no diretório de documentos da aplicação (`voice_notes/<id>.m4a`), e a coluna `audioFilePath` da nota no SQLite é atualizada.
4. **Retentativa Resiliente de Downloads:** Falhas no download de áudio registram a chave `pending_audio_download_<id>` no `app_kv_store`. Quando o aplicativo retorna ao primeiro plano ou restabelece a conexão, `retryPendingMediaDownloads()` retenta automaticamente recuperar os áudios pendentes.
5. **Preservação de Áudio Local em Atualizações:** Ao receber atualizações remotas de metadados em `_applyRemoteRecord`, se o servidor não trouxer caminho de arquivo, o `audioFilePath` local previamente existente é estritamente preservado no banco Drift.

---

## 4. Soft Delete, Tombstones e Prevenção de Ressurreição (ADR-013)
A sincronização do Field Assistant aboliu qualquer comando físico `DELETE` (`DELETE FROM ...`) no Supabase, adotando propagação via tombstones:

### 4.1 Envio de Tombstone na Outbox
Quando uma exclusão ocorre localmente, a outbox executa um `update` com tombstone payload em vez de `.delete()`:
```dart
final tombstonePayload = {
  'deleted_at': deletedAtIso,
  'updated_at': updatedAtIso,
  'revision': revision,
};
await activeClient.from(tableName).update(tombstonePayload).eq('id', op.entityId);
```

### 4.2 Barreira contra Ressurreição no Cliente (`_applyRemoteRecord`)
Se um dispositivo desconectado enviar um registro antigo com `deleted_at = null`, e o registro local já for um tombstone (`deleted_at != null`), o registro **NÃO** é ressuscitado cegamente. A ressurreição só é permitida caso comprove restauração legítima e mais recente:
```dart
final isLegitimateRestore = remoteRev > localRev &&
    remoteUpdated != null &&
    localDeletedAt != null &&
    remoteUpdated.isAfter(localDeletedAt);

if (!isLegitimateRestore) {
  // Mantém o tombstone local intacto e rejeita a ressurreição
  return true;
}
```

### 4.3 Barreira contra Ressurreição no PostgreSQL
A trigger de banco `handle_soft_delete_and_resurrection_guard()` anexada a todas as 10 tabelas sincronizadas rejeita qualquer `UPDATE` que tente redefinir `deleted_at` para `NULL` a menos que `COALESCE(NEW.revision, 0) > COALESCE(OLD.revision, 0)` e `NEW.updated_at > OLD.deleted_at`.

### 4.4 Desacoplamento e Prevenção de Loops de Outbox
A aplicação local de tombstones recebidos (`_softDeleteLocalEntry`) realiza escrita direta no SQLite via companion do Drift, sem acionar os métodos de negócio de `AppRepository`, garantindo que nenhuma nova operação `DELETE` seja reinserida na `sync_queue`.

---

## 5. Cursor Incremental Determinístico Composto
A busca de atualizações remotas (`fetchRemoteChanges`) utiliza paginação estável e cursor composto ordenado por data e chave primária:

### 5.1 Ordenação e Filtro PostgREST
Para evitar omissão de múltiplos registros ou tombstones gerados no mesmo milissegundo, a ordenação e a cláusula `or` cobrem o cursor composto `(updated_at, id)`:
```dart
if (lastSyncedId != null && lastSyncedId.isNotEmpty) {
  query = query.or(
    'updated_at.gt.$lastSyncedAtIso,and(updated_at.eq.$lastSyncedAtIso,id.gt.$lastSyncedId)',
  );
} else {
  query = query.gte('updated_at', lastSyncedAtIso);
}

final res = await query
    .order('updated_at', ascending: true)
    .order('id', ascending: true)
    .range(offset, offset + pageSize - 1);
```

### 5.2 Paginação Otimizada e Barreira de Falha
- **Tamanho de Página:** 100 registros (`pageSize = 100`).
- **Interrupção Eficiente:** Se `rows.length < pageSize`, a paginação é interrompida imediatamente, dispensando requisições adicionais desnecessárias.
- **Persistência de Estado:** O cursor é persistido no `AppKvStore` sob as chaves `last_synced_at_<tabela>` e `last_synced_id_<tabela>`.
- **Barreira de Falha:** Se ocorrer qualquer falha na aplicação de um lote (`hadFailuresInTable = true`), o cursor daquela tabela não é avançado, garantindo que o próximo ciclo refaça a reconciliação sem perda de registros.

---

## 6. Backoff Exponencial com Full Jitter e Recuperação da Outbox

### 6.1 Algoritmo de Backoff com Jitter
Para evitar sobrecarga e tempestades de requisições simultâneas (thundering herd) no restabelecimento de conexão, o cálculo de intervalo entre tentativas aplica jitter aleatório de até 25%:
```dart
static int calculateBackoffSeconds(int attempts, {Random? random}) {
  if (attempts <= 0) return 0;
  final base = pow(2, min(attempts, 8)).clamp(1, 300).toInt();
  final rng = random ?? Random();
  final jitter = (rng.nextDouble() * 0.25 * base).round();
  return (base + jitter).clamp(1, 300);
}
```
- A base exponencial $2^{\min(\text{attempts}, 8)}$ é limitada a 300 segundos (5 minutos).
- O jitter adiciona até 25% de variação aleatória à base calculada.

### 6.2 Limite de Tentativas e Recuperação Supervisionada
- **Pausa Automática:** Após 5 tentativas consecutivas de falha (`attempts >= 5`), o item é marcado como `status = 'failed'` e é temporariamente ignorado pelo loop automático para não travar o restante da fila.
- **Recuperação sem Perda de Dados:** O método `requeueFailedSyncOperations()` permite reenfileirar operações com falha:
  - Executa dentro de uma transação atômica (`db.transaction`).
  - Ajusta o contador com clamping para 4 tentativas (`attempts = 4`), concedendo nova oportunidade imediata de despacho.
  - Reverte o status para `'pending'` e aciona o despachador `processQueue()`.
  - Exposto de forma reativa na interface através do provider `failedSyncOperationsStreamProvider` e do notifier `outboxRecoveryProvider`.

---

## 7. Política de Resolução de Conflitos: 3-Way Merge (`SyncEngine`)

### 7.1 Captura de Snapshot Base (`_base`)
Em toda mutação de entidade (`updatePhoneContact`, `updateLandmark`, `saveVoiceNote`, etc.), o estado anterior do registro é capturado e serializado no campo `_base` do payload da `sync_queue`. O contador de revisão é incrementado monotonicamente (`revision = existing.revision + 1`).

### 7.2 Mesclagem em Nível de Campo (Field-Level Merge)
Ao receber um registro do Supabase correspondente a uma operação pendente na outbox, o `SyncEngine.mergeEntities` compara:
- `localData`: Dados da alteração local pendente.
- `remoteData`: Dados recebidos do servidor.
- `baseData`: Estado comum anterior (`_base`).

Regras de reconciliação:
1. **Campos Não Alterados Concomitantemente:** Se apenas o cliente alterou o campo, mantém o valor do cliente. Se apenas o servidor alterou, aceita a alteração do servidor.
2. **Alterações Idênticas:** Sem conflito. O valor consolidado é mantido.
3. **Conflito no Mesmo Campo:** Se ambos os nós modificaram o mesmo campo para valores diferentes, o sistema rejeita sobrescrita silenciosa ("Last Write Wins"):
   - Marca a operação na `sync_queue` com `status = 'conflict'`.
   - Emite notificação no stream com `SyncStatus.conflict`.
   - Solicita intervenção explícita do publicador.

### 7.3 Conflitos Concorrentes na Agenda (`Appointments`)
Se dois compromissos forem criados ou alterados em nós diferentes gerando sobreposição concorrente de horários:
- Nenhum dos compromissos é apagado.
- Ambos recebem `status = 'conflito'` e a flag `is_provisional = true`.
- Os compromissos são exibidos no calendário ministerial com destaque visual de conflito para que o publicador ajuste o horário manualmente.

---

## 8. Ciclo de Vida e Reatividade na Aplicação Flutter

### 8.1 Estados Reativos do Sincronizador (`SyncStatus`)
- `savedLocally`: Mutações gravadas com segurança no SQLite local. Nenhuma operação remota simulada.
- `waitingConnection`: Dispositivo desconectado ou instabilidade transitória de rede. Nunca mascara perda de conexão.
- `syncing`: Processamento ativo da fila de outbox ou busca incremental remota.
- `synced`: Outbox vazia, cursor incremental atualizado e dados alinhados com o backend.
- `conflict`: Divergência detectada no mesmo campo ou sobreposição de agenda exigindo resolução.
- `error`: Falha recuperável registrada, mantendo a integridade da fila com backoff ativo.

### 8.2 Observação de Ciclo de Vida (`WidgetsBindingObserver`)
O `SupabaseSyncService` registra-se como observador do ciclo de vida da aplicação Flutter:
- **`AppLifecycleState.resumed`:** Ao retornar do segundo plano, dispara verificação de conectividade via `SupabaseInitializer.checkConnectivity()`, seguido por `retryPendingMediaDownloads()`, `processQueue(ignoreBackoff: true)` e `fetchRemoteChanges()`.
- **Reconexão de Rede:** Ao detectar restabelecimento de conexão, reprocessa imediatamente a fila sem esperar o tempo residual de backoff.
- **Prevenção de Execuções Concorrentes:** Mutexes baseados em `Completer` (`_activeSyncCompleter` e `_activeFetchCompleter`) impedem execuções concorrentes duplicadas de envio ou busca remota.
