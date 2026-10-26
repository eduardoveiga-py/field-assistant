---
name: flutter-drift-architecture
description: Instruções e padrões arquiteturais para desenvolvimento Flutter e banco de dados local com Drift (SQLite e Wasm).
---

# Skill: Arquitetura Flutter e Drift

## Diretrizes
1. Toda entidade do domínio deve possuir mapeamento tipado em tabelas Drift (`DriftTable`).
2. Utilize UUIDs (`uuid.v4()`) gerados localmente para as chaves primárias.
3. Não faça chamadas diretas de banco dentro de Widgets; utilize Repositórios intermediários e State Notifiers.
4. Para a Web, utilize suporte SQLite compilado para WebAssembly (`drift/wasm.dart`) com armazenamento persistente em IndexedDB.
5. Transações devem encapsular mutações de entidades juntamente com a inserção na fila de sincronização (`sync_queue`).
