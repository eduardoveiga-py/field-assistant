---
name: offline-first-sync
description: Protocolo de sincronização offline-first com fila persistente, idempotência e resolução de conflitos para Supabase e Drift.
---

# Skill: Sincronização Offline-First e Conflitos

## Diretrizes Fundamentais
1. **Local-First Imediato:** O dispositivo móvel ou web grava sempre primeiro no banco local Drift. A interface reage instantaneamente sem esperar a rede.
2. **Outbox Transacional:** Na mesma transação SQLite/Drift da mutação da entidade, registra a operação na tabela `sync_queue` (INSERT/UPDATE/DELETE) com payload estruturado e snapshot `_base` para 3-way merge.
3. **Idempotência Estrita:** As operações devem ser idempotentes: retentativas de rede e reenvios de outbox não podem duplicar nem corromper dados no PostgreSQL.
4. **Mesclagem Determinística de 3 Vias (3-Way Merge):** Conflitos de edição em campos distintos entre instâncias locais e remotas são mesclados automaticamente no `SyncEngine` sem perda de dados.
5. **Visibilidade Explícita de Conflitos:** Conflitos no mesmo campo retêm ambas as versões, marcam sinalização de conflito e acionam a resolução explícita pelo usuário.
6. **Soft Delete via Tombstones:** Deleções são lógicas com timestamp `deleted_at` e incremento de `revision`. O trigger PostgreSQL `prevent_stale_resurrection` bloqueia que nós desatualizados ressuscitem registros excluídos.
7. **Detecção Semântica na Agenda:** Compromissos concorrentes com sobreposição de horário criados em dispositivos distintos são detectados após o sync, marcando status `conflito` e `isProvisional: true` na base local e atualizando a outbox.
8. **Segurança de Mídia e Sanitização:** Mídias binárias (áudio de notas de voz) são enviadas exclusivamente para o bucket privado `voice_notes` de Supabase Storage. O caminho local absoluto é rigorosamente removido do payload de metadados (`sanitizePayload`).
9. **Isolamento RLS Multi-tenant:** Todas as operações utilizam `owner_id = auth.uid()`. Nenhum dado é compartilhado entre contas distintas.
10. **Resiliência e Backoff:** Retentativas de push utilizam backoff exponencial com jitter (clamped a 300s). Operações que atingem 5 tentativas são marcadas como `failed` na outbox, preservando o histórico para posterior requeue seguro.
