---
name: flutter-drift-architecture
description: Instruções e padrões arquiteturais para desenvolvimento Flutter e banco de dados local com Drift (SQLite e Wasm).
---

# Skill: Arquitetura Flutter e Drift

## Diretrizes Fundamentais
1. **Modelagem Fortemente Tipada:** Toda entidade do domínio possui mapeamento tipado em classes de tabela Drift (`lib/database/tables.dart`, 22 tabelas fortemente tipadas no schemaVersion 4).
2. **Identificadores UUID:** Chaves primárias de domínio são geradas no cliente via `uuid.v4()`, garantindo idempotência e criação offline autônoma.
3. **Arquitetura de Repositório por Mixins:** O `AppRepository` é composto por Mixins de Domínio em `lib/database/domains/` (`PeopleDomainMixin`, `VisitsDomainMixin`, `StudiesDomainMixin`, `AppointmentsDomainMixin`, `ActivitiesDomainMixin`, `TrashDomainMixin`, `SyncQueueDomainMixin`), herdando de `BaseRepository`. Essa estrutura elimina acoplamento e queries duplicadas enquanto preserva 100% de compatibilidade com os `providers.dart`.
4. **Camada de Apresentação Desacoplada:** Widgets NUNCA executam chamadas diretas `db.select` ou `db.into`. Toda leitura e escrita passa por StateNotifiers Riverpod e métodos encapsulados do Repositório.
5. **Multiplataforma (Nativo e Web Wasm):**
   - Nativo (Mobile / Desktop): `NativeDatabase` com `PRAGMA foreign_keys = ON;`, `PRAGMA journal_mode = WAL;`, `PRAGMA synchronous = NORMAL;` e `busy_timeout = 5000;`.
   - Web: SQLite compilado para WebAssembly (`drift/wasm.dart`) com armazenamento persistente em IndexedDB e worker canônico único `web/drift_worker.js`.
6. **Integridade Transacional Atômica:** Operações compostas no banco (como criação de estudo com múltiplos participantes ou registro de visita com atualização de pessoa) devem ser encapsuladas em transações atômicas `db.transaction(() async { ... })`, registrando concomitantemente as operações na outbox (`sync_queue`).
