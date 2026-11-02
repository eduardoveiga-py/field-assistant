# ADR-013: Integridade de Exclusões Lógicas (Soft Delete), Propagação via Tombstones e Prevenção de Ressurreição

## Status
Aprovado e Implementado

## Data
02 de Novembro de 2026

## Contexto
Na arquitetura original de sincronização do Field Assistant (`SupabaseSyncService`), a operação `DELETE` na outbox executava:
```dart
await activeClient.from(tableName).delete().eq('id', op.entityId);
```
Essa chamada realizava uma exclusão física (`DELETE FROM ...`) direta no PostgreSQL do Supabase. Essa abordagem introduzia cinco problemas arquiteturais graves:
1. **Destruição Irreversível e Cascata no PostgreSQL:** Exclusões físicas acionavam `ON DELETE CASCADE` em chaves estrangeiras no PostgreSQL, destruindo registros dependentes sem histórico nem auditoria.
2. **Ressurreição Indesejada por Nós Offline:** Se o Dispositivo A excluísse um registro fisicamente no servidor e o Dispositivo B (que estava offline durante a exclusão) voltasse a conectar e enviasse uma edição local pendente (`UPSERT`), o registro era reinserido no Supabase como se fosse novo, ressuscitando o registro que A havia apagado.
3. **Impossibilidade de Propagação Incremental:** Um `DELETE` físico remove a linha do banco remoto. Portanto, consultas incrementais (`fetchRemoteChanges`) baseadas em `updated_at > last_synced_at` jamais detectavam linhas excluídas, fazendo com que outros dispositivos nunca tomassem ciência da exclusão via delta sync.
4. **Risco de Loop de Sincronização:** Ao puxar um tombstone do servidor, se o cliente aplicasse o soft delete invocando o repositório padrão (`deletePerson`, etc.), uma nova operação `DELETE` seria enfileirada na outbox, enviando o tombstone de volta ao servidor num ciclo infinito.
5. **Perda de Tombstones no Cursor Incremental:** Quando múltiplos registros ou tombstones eram atualizados no mesmo milissegundo na borda da consulta, o filtro estrito `gt('updated_at', last_synced_at)` ignorava registros com carimbo idêntico.

---

## Decisões Tomadas

### 1. Eliminação Completa de Exclusão Física no Supabase
Reemplaçada a chamada `.delete()` em `SupabaseSyncService._processSingleOperation` por um `update` com tombstone payload:
```dart
final tombstonePayload = {
  'deleted_at': deletedAtIso,
  'updated_at': updatedAtIso,
  'revision': revision,
};
await activeClient.from(tableName).update(tombstonePayload).eq('id', op.entityId);
```
O servidor Supabase nunca recebe comandos `DELETE` para nenhuma das 10 tabelas sincronizadas (`people`, `visits`, `bible_studies`, `study_participants`, `study_sessions`, `appointments`, `activity_records`, `voice_notes`, `phone_contacts`, `territory_landmarks`).

### 2. Preservação de Tombstones no Push da Outbox
Se um registro foi excluído localmente antes do envio de operações pendentes de `INSERT` ou `UPDATE`, o sincronizador preserva explicitamente `cleanPayload['deleted_at']` caso a linha local já possua `deletedAt != null`. Isso impede que uma inserção atrasada no cliente envie `deleted_at = null` para o servidor.

### 3. Prevenção de Ressurreição no Cliente (`_applyRemoteRecord`)
Ao receber um registro remoto ativo (`remote['deleted_at'] == null`), se o registro local correspondente for um tombstone (`local['deleted_at'] != null`), a ressurreição só é permitida se for uma restauração intencional comprovadamente mais recente:
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

### 4. Blindagem de Ressurreição no PostgreSQL via Triggers
Criada a migração `supabase/migrations/20261102010000_u3_1_soft_delete_tombstones.sql` implementando a função de trigger:
`handle_soft_delete_and_resurrection_guard()`
Ela é anexada a todas as 10 tabelas sincronizadas. Qualquer `UPDATE` que tente redefinir `deleted_at` para `NULL` em um registro já soft-deletado é barrado a menos que comprove restauração legítima e mais recente (`COALESCE(NEW.revision, 0) > COALESCE(OLD.revision, 0)` e `NEW.updated_at IS NOT NULL AND NEW.updated_at > OLD.deleted_at`). A trigger trata explicitamente valores `NULL` com `COALESCE` para impedir evasão da barreira quando mutações parciais omitem `revision` ou `updated_at`. Um script de rollback reversível é incluído no arquivo.

### 5. Cursor Incremental Composto `(updated_at, id)` com Barreira de Falha
A consulta de alterações remotas em `fetchRemoteChanges` agora persiste `last_synced_at_$table` e `last_synced_id_$table` no `AppKvStore`. A query PostgREST utiliza o filtro composto:
```dart
query = query.or('updated_at.gt.$lastSyncedAtIso,and(updated_at.eq.$lastSyncedAtIso,id.gt.$lastSyncedId)');
```
Isso garante que nenhum registro ou tombstone que compartilhe exatamente o mesmo carimbo de data/hora seja omitido na paginação. A paginação foi otimizada para interromper quando `rows.length < pageSize` (evitando round-trip HTTP redundante). Adicionalmente, caso ocorra qualquer falha não-conflitante de aplicação de registros na tabela (`hadFailuresInTable`), o cursor não é avançado, permitindo que ciclos subsequentes reexecutem a busca e apliquem registros pendentes com segurança.

### 6. Desacoplamento da Aplicação Local de Tombstones e Atualização Atômica de Metadados
Ao receber um tombstone remoto (`deleted_at != null`), o sincronizador executa `_softDeleteLocalEntry`, que atualiza diretamente a tabela do Drift no SQLite (`deletedAt`, `updatedAt` e `revision`) sem invocar os métodos de negócio do `AppRepository`, impedindo a inserção de novas operações na tabela `sync_queue` e prevenindo loops de sincronização. Caso a entidade seja uma nota de voz deletada, o download de mídia binária é explicitamente suprimido. Se houver uma operação `DELETE` pendente na outbox para o mesmo ID, o merge trilateral é ignorado para evitar que o payload parcial de exclusão branqueie campos locais.

### 7. Resiliência a Falhas de Rede, Defaults Seguros e Idempotência
Caso a chamada de `PATCH` falhe (ex: queda de rede HTTP 504), a operação na outbox permanece como `pending` (ou `failed`) com tentativa contabilizada. Na reconexão, o reenvio atualiza o mesmo registro no Supabase com idempotência garantida. O método `_prepareEntryMap` fornece fallbacks seguros para todas as colunas não-nulas de todas as 10 entidades (incluindo `phone_contacts.name`, `territory_landmarks.name` e `voice_notes.personId`), permitindo que tombstones parciais sejam ingeridos sem erros de tipo.

---

## Consequências
- **Zero Exclusões Físicas:** `server.physicalDeleteCalls` é estritamente 0 em todo o ciclo de vida.
- **Ressurreição Eliminada:** Dispositivos offline não desfazem exclusões anteriores ao subir suas filas pendentes, mesmo sob omissão de campos ou mutações com metadados nulos.
- **Auditoria Plena:** O histórico permanece íntegro no SQLite e no PostgreSQL, com carimbos e revisões sincronizados atomicamente.
- **Robustez Multidispositivo:** Dispositivo A exclui -> Supabase registra tombstone -> Dispositivo B recebe tombstone incrementalmente sem perda, sem download inútil de áudio e sem eco de fila.
- **Testes:** 11 testes exaustivos implementados em `test/sync/supabase_soft_delete_test.dart` (Testes A a K), todos aprovados com 100% de sucesso.
- **Total do Projeto:** Suíte expandida de 562 para **573 testes aprovados**, 0 issues no analisador estático (`dart analyze lib test --fatal-infos`).
