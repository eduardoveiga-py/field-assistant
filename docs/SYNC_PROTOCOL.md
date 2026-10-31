# Protocolo de Sincronização: Ministério Pessoal

## 1. Visão Geral Offline-First
O sistema adota o paradigma **Local-First / Offline-First**:
1. Toda alteração (inserção, atualização, deleção lógica) é persistida imediatamente no banco local Drift SQLite (ou Wasm IndexedDB no Web).
2. Na mesma transação atômica da gravação de dados, uma operação é inserida na tabela local `sync_queue`.
3. Quando houver conexão à internet e configuração ativa do Supabase:
   - O dispatcher `SupabaseSyncService` consome a fila respeitando ordem cronológica (`created_at ASC`).
   - O backend valida permissões (Row Level Security com `owner_id = auth.uid()`).
   - Conflitos em nível de campo são detectados deterministicamente pelo `SyncEngine.mergeEntities`.
   - As entradas confirmadas da `sync_queue` são marcadas como sincronizadas (`synced`).

---

## 2. Estrutura da Fila de Sincronização (`sync_queue`)
- `id`: UUID v4 da operação.
- `entity_type`: Nome da tabela ('people', 'visits', 'bible_studies', 'study_participants', 'study_sessions', 'appointments', 'activity_records', 'voice_notes').
- `entity_id`: UUID do registro afetado.
- `operation`: 'INSERT', 'UPDATE', 'DELETE'.
- `payload`: JSON completo dos campos alterados ou do registro no momento da mutação.
- `created_at`: Timestamp local ISO-8601 da operação.
- `attempts`: Quantidade de tentativas de envio executadas.
- `last_error`: Mensagem técnica de erro da última tentativa falha.
- `status`: 'pending', 'in_progress', 'synced', 'conflict', 'failed'.

---

## 3. Backoff Exponencial e Despachador de Fila (`SupabaseSyncService`)
- **Backoff Exponencial:** A cada tentativa falha, o intervalo mínimo de reenvio segue a fórmula:
  $$\text{intervalo} = \min(2^{\text{attempts}}, 300)\text{ segundos}$$
- **Limite de Retentativas:** Após 5 tentativas sem sucesso, a operação é marcada com `status = 'failed'` para investigação e auditoria sem interromper o processamento das demais entidades da fila.
- **Sanitização de Privacidade de Notas de Voz:**
  - O campo `audio_file_path` (caminho absoluto do arquivo no filesystem local do dispositivo, como `/data/user/0/...` ou `C:\Users\...`) é **estritamente removido** antes da transmissão para o Supabase.
  - Apenas metadados teocráticos (lição, ponto, pendência, gatilho empático, duração e transcrição de texto) são sincronizados na nuvem.

---

## 4. Mapeamento de Entidades Drift SQLite ↔ Supabase PostgreSQL
| Entidade Drift | Tabela Supabase | RLS Policy |
| :--- | :--- | :--- |
| `people` | `people` | `auth.uid() = owner_id` |
| `visits` | `visits` | `auth.uid() = owner_id` |
| `bibleStudies` | `bible_studies` | `auth.uid() = owner_id` |
| `studyParticipants`| `study_participants` | `auth.uid() = owner_id` |
| `studySessions` | `study_sessions` | `auth.uid() = owner_id` |
| `appointments` | `appointments` | `auth.uid() = owner_id` |
| `activityRecords`| `activity_records` | `auth.uid() = owner_id` |
| `voiceNotes` | `voice_notes` | `auth.uid() = owner_id` |

---

## 5. Política de Resolução de Conflitos (`SyncEngine`)
1. **Históricos Imutáveis:** Encontros/Visitas (`visits`), Notas de Voz (`voice_notes`) e Sessões de Estudo (`study_sessions`) são registros pontuais independentes e imutáveis.
2. **Mesclagem em Campos Distintos (Field-Level Merge):**
   - Se o Dispositivo A alterou `phone` de uma pessoa e o Dispositivo B alterou `address`, ambos os campos são integrados sem perda de informação.
3. **Conflito no Mesmo Campo:**
   - Se ambos os dispositivos alterarem o mesmo campo com valores incompatíveis enquanto desconectados, o sistema **não** aplica "Last Write Wins" silencioso.
   - O registro é marcado com status `conflict` localmente na `sync_queue`.
   - A interface sinaliza o conflito para resolução explícita pelo publicador.
4. **Conflito de Agenda (Appointments):**
   - Compromissos sobrepostos gerados offline são preservados sem exclusão, marcados com status `conflito` no calendário teocrático.

---

## 6. Estados Honesto na Interface (`SyncStatus`)
- `savedLocally`: Dados gravados com segurança localmente no SQLite. Nenhuma sincronização remota simulada.
- `waitingConnection`: Dispositivo sem internet ou Supabase não configurado. Nunca finge sucesso.
- `syncing`: Despacho ativo da fila persistente para o Supabase.
- `synced`: Fila vazia e todas as mutações confirmadas pelo backend remoto.
- `conflict`: Divergência em mesmo campo requerendo atenção.
- `error`: Falha recuperável com backoff ativo.
