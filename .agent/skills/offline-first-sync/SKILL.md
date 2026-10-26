---
name: offline-first-sync
description: Protocolo de sincronização offline-first com fila persistente, idempotência e resolução de conflitos para Supabase e Drift.
---

# Skill: Sincronização Offline-First e Conflitos

## Diretrizes
1. O dispositivo móvel ou web grava sempre primeiro no banco local Drift.
2. Na mesma transação, registra a operação na tabela `sync_queue`.
3. As operações devem ser idempotentes: repetições de rede não podem criar registros duplicados.
4. Conflitos de edição em campos distintos devem ser mesclados de maneira segura.
5. Conflitos no mesmo campo devem reter ambas as versões e acionar a UI de resolução explícita pelo usuário.
6. Deleções devem ser lógicas (`deleted_at`), impedindo ressurgimento inadvertido por nós atrasados.
