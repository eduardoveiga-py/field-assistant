# Protocolo de Sincronização: Ministério Pessoal

## 1. Visão Geral Offline-First
O sistema adota o paradigma **Local-First / Offline-First**:
1. Toda alteração (inserção, atualização, deleção lógica) é persistida imediatamente no banco local Drift SQLite (ou Wasm IndexedDB no Web).
2. Na mesma transação da gravação de dados, uma operação é inserida na tabela local `sync_queue`.
3. Quando houver conexão à internet e uma sessão autenticada do usuário:
   - As alterações locais pendentes são despachadas para o Supabase.
   - O backend valida permissões (Row Level Security com `user_id = auth.uid()`) e concorrência de revisão.
   - As alterações remotas são puxadas e integradas localmente via reconciliação.
   - As entradas confirmadas da `sync_queue` são marcadas como sincronizadas (`synced_at`) ou removidas.

---

## 2. Estrutura da Fila de Sincronização (`sync_queue`)
- `id`: UUID da operação.
- `entity_type`: Nome da tabela ('people', 'visits', 'studies', 'study_participants', 'study_sessions', 'appointments', 'activities').
- `entity_id`: UUID do registro afetado.
- `operation`: 'INSERT', 'UPDATE', 'DELETE'.
- `payload`: JSON completo dos campos alterados ou do registro no momento da mutação.
- `created_at`: Timestamp local ISO-8601 da operação.
- `attempts`: Quantidade de tentativas de envio.
- `last_error`: Mensagem de erro da última tentativa falha.
- `status`: 'pending', 'in_progress', 'synced', 'conflict', 'failed'.

---

## 3. Idempotência e Concorrência
- **Idempotência:** Cada operação possui um `id` de mutação único. O endpoint ou procedure remota no PostgreSQL armazena ou confere o ID da operação para evitar duplicações em caso de retransmissão de rede.
- **Revisão:** Toda entidade possui um contador `revision` inteiro (incrementado a cada alteração) e um timestamp `updated_at`.
- **Exclusão Lógica:** Deleções utilizam `deleted_at IS NOT NULL`. Uma deleção lógica sincronizada sobrepõe edições anteriores e não é revertida silenciosamente por sincronizações atrasadas.

---

## 4. Política de Resolução de Conflitos
1. **Históricos Imutáveis:** Encontros/Visitas (`visits`) e Sessões de Estudo (`study_sessions`) são registros pontuais independentes. Eles nunca devem ser sobrescritos por edições de cabeçalho da Pessoa ou do Estudo.
2. **Mesclagem em Campos Distintos (Field-Level Merge):**
   - Se o Dispositivo A alterou `phone` de uma pessoa e o Dispositivo B alterou `address`, ambos os campos são mesclados com segurança.
3. **Conflito no Mesmo Campo:**
   - Se ambos os dispositivos alterarem o mesmo campo com valores incompatíveis enquanto desconectados, o sistema **não** aplica "Last Write Wins" silencioso.
   - O registro é marcado com status `conflict` localmente.
   - A interface apresenta a tela de resolução de conflitos, exibindo lado a lado a versão local e a versão remota recebida, permitindo ao usuário escolher a versão definitiva ou combinar manualmente as anotações.
4. **Conflito de Agenda (Appointments):**
   - Se dois dispositivos criaram agendamentos em horários sobrepostos enquanto offline:
     - Ambos os agendamentos são preservados no banco.
     - O agendamento que chegou depois no backend ou cujo horário colide é marcado com `status = 'conflito'` e exibido em destaque no calendário para que o usuário decida qual manter ou reagende.

---

## 5. Estados na Interface
- **Salvo neste dispositivo:** Dados gravados localmente, offline ou aguardando fila.
- **Sincronizando:** Fila em transmissão ativa.
- **Sincronizado:** Todas as alterações confirmadas pelo Supabase.
- **Aguardando conexão:** Dispositivo sem internet ou backend inalcançável.
- **Conflito:** Requer decisão do usuário entre duas versões divergentes.
- **Erro:** Falha recuperável com opção de repetição manual.
