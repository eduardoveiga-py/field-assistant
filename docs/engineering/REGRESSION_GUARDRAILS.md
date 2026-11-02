# REGRESSION GUARDRAILS — REQUISITOS INVIOLÁVEIS E REGRAS DE INTEGRIDADE

Este documento define as regras fundamentais que **jamais podem ser violadas, enfraquecidas ou ignoradas** em nenhuma alteração de código ou refatoração no projeto **Field Assistant**.

---

## 1. Regras Invioláveis de Contagem Ministerial
1. **Diferenciação Estrita de Entidades:**
   - `BibleStudy` ≠ `StudySession` ≠ `Participant` ≠ `Visit`.
2. **Estudo com Múltiplos Participantes:**
   - Um estudo bíblico associado a dois ou mais participantes (ex: casal) conta como **exatamente 1 estudo bíblico ativo**.
   - Jamais some a quantidade de participantes ao total de estudos nos relatórios ou dashboard.
3. **Sessões Realizadas vs Participantes:**
   - Uma sessão de estudo realizada com múltiplos alunos conta como **exatamente 1 sessão de estudo realizada**.
4. **Sessões Não Realizadas ou Canceladas:**
   - Sessões marcadas com status `cancelada` ou `nao_realizada` **NÃO** entram no cômputo de sessões realizadas.
5. **Revisitas Futuras / Tentativas:**
   - Revisitas com data futura são compromissos planejados e **NÃO** contam como revisitas realizadas.
   - Tentativas sem contato no território **NÃO** contam como conversas realizadas.

---

## 2. Regras de Integridade do Banco de Dados Local (Drift / SQLite)
1. **Persistência Imediata:**
   - Toda alteração efetuada pelo usuário deve ser persistida síncrona e imediatamente no SQLite/IndexedDB antes de qualquer tentativa de envio pela rede.
2. **Chaves Estrangeiras Obrigatórias:**
   - `PRAGMA foreign_keys = ON;` deve permanecer ativado em todas as conexões nativas (`NativeDatabase`). Nenhuma exclusão em cascata pode deixar registros órfãos silenciosos.
3. **UUIDs Locais:**
   - As chaves primárias são strings UUID v4 geradas no cliente (`const Uuid().v4()`). Nunca dependa de autoincrement ou IDs remotos.
4. **Proteção de Migrações:**
   - Migrações do schema Drift **nunca podem silenciar erros com `catch (_) {}`**. Devem falhar de maneira controlada para impedir corrupção de schema.
   - É estritamente proibido emitir `dropTable` em tabelas existentes com dados de produção.

---

## 3. Regras de Sincronização e Idempotência (Supabase)
1. **Fila Local Obrigatória (Outbox):**
   - Nenhuma requisição direta de mutação deve ser enviada ao Supabase sem antes ser registrada atomicamente na tabela `sync_queue` com seu snapshot `baseData`.
2. **Idempotência Absoluta:**
   - O reenvio da mesma operação de sincronização após timeout ou queda de conexão **deve ser idempotente**. Nunca crie registros duplicados.
3. **Proibição de "Last Write Wins" Cego:**
   - Conflitos em anotações pastorais, históricos de conversas e dados de contatos devem ser detectados em nível de campo (`SyncEngine.mergeEntities`). Quando o mesmo campo for modificado em ambos os nós, as duas versões devem ser retidas.
4. **Exclusões Lógicas Estritas (Tombstones) e Prevenção de Ressurreição:**
   - Nenhuma operação DELETE na outbox pode invocar `.delete()` no Supabase. Deve sempre realizar um update preenchendo `deleted_at = now`, `updated_at = now` e incrementando `revision`.
   - Se uma entidade já estiver soft-deletada localmente, o push de operações `INSERT` ou `UPDATE` pendentes deve preservar `deleted_at` para não anular o tombstone remoto.
   - Triggers no PostgreSQL (`handle_soft_delete_and_resurrection_guard`) e a lógica de recepção no cliente (`_applyRemoteRecord`) devem rejeitar a anulação de `deleted_at` por upserts atrasados, permitindo ressurreição apenas se `remoteRev > localRev` e `remoteUpdated > localDeletedAt`.
   - Tombstones recebidos devem ser aplicados diretamente no banco local sem passar pelos métodos de negócio do repositório para evitar enfileiramento na outbox e loops de sincronização.
5. **Cursor Incremental Composto (updated_at, id):**
   - A paginação do pull e o cursor incremental (`last_synced_at_$table` e `last_synced_id_$table`) devem desemparelhar carimbos idênticos com `id.gt.$id`, prevenindo que registros e tombstones gerados no mesmo instante sejam ignorados.
6. **Durabilidade Absoluta da Outbox em Falhas Transitórias:**
   - Operações que falham por queda de rede (ex: `SocketException`, `TimeoutException` ou HTTP 5xx) **jamais podem ser descartadas** da fila local `sync_queue`. Elas devem ser marcadas como `failed` e reenviadas em tentativas subsequentes respeitando backoff exponencial com jitter.
7. **Limite de Retentativas e Prevenção de Starvation / Loop Infinito:**
   - O reprocessamento automático de operações deve ser limitado a 5 tentativas consecutivas (`attempts.isSmallerThanValue(5)` em `getPendingSyncOperations`). Ao atingir 5 falhas, a operação é pausada do envio automático para evitar saturação de bateria e rede, mas **permanece preservada no SQLite** para análise ou reativação manual.
8. **Inicialização Desacoplada e Tolerante a Falhas:**
   - O boot da interface (`runApp()`) e o banco relacional local (`AppDatabase`) **nunca podem depender** de rede ou aguardar a resposta do backend Supabase. A inicialização remota deve ser assíncrona e não-bloqueante (`unawaited`). O acesso ao SDK deve ser blindado contra `AssertionError` via `SupabaseInitializer.clientOrNull`.
9. **Reentrância e Serialização da Fila (isSyncing):**
   - Chamadas concorrentes a `processQueue()` ou `fetchRemoteChanges()` devem ser serializadas via travas assíncronas (`isSyncing` e `_activeSyncCompleter`). Nunca permita que múltiplas rotinas processem simultaneamente a mesma fila de envio ou executem escritas concorrentes redundantes no banco local.
10. **Proteção de Dados Locais em Falhas Transitórias:**
    - Operações com status `failed` (tentativas < 5) na outbox representam mutações locais ativas ainda não convergidas. O processamento de alterações remotas (`_applyRemoteRecord`) deve obrigatoriamente incluí-las na resolução 3-way merge, sendo expressamente proibido sobrescrever dados locais sem reconciliação quando houver operação com status `failed` pendente.

---

## 4. Regras de Backup e Restauração Transacional
1. **Criptografia Forte:**
   - Backups devem ser encriptados com **AES-256 GCM** e derivação de chave **PBKDF2** com no mínimo 100.000 iterações.
2. **Staging em 3 Etapas para Mídias:**
   - Durante a restauração, áudios descompactados passam primeiro por `safety_staging/`.
   - Áudios originais que seriam sobrescritos devem ser guardados em `safety_audio_backup/`.
   - A substituição real só ocorre após o sucesso do commit da transação do banco relacional.
   - Em caso de falha, o rollback restaura os arquivos originais sem perda.
3. **Proibição Categórica de Armazenamento Efêmero:**
   - NUNCA utilize `Directory.systemTemp` ou `/tmp` para snapshots ou arquivos de áudio. Se o armazenamento seguro de documentos não estiver acessível, aborte a operação lançando `StorageUnavailableException`.

---

## 5. Regras de Segurança e Privacidade
1. **Isolamento de Dados por Usuário (RLS):**
   - Todas as tabelas no Supabase devem ter Row-Level Security habilitado com política `auth.uid() = owner_id`.
2. **Proibição de Chaves Privilegiadas:**
   - NUNCA inclua, passe ou comite a chave `service_role` (Service Secret) no aplicativo cliente. Somente a chave anônima pública (`anon key`) é permitida.
3. **Telemetria Zero:**
   - Não inclua SDKs de rastreamento, publicidade ou telemetria de terceiros.
4. **Preservação de Dados em Feature Flags:**
   - Desativar módulos em `customize_features_screen.dart` **não pode apagar dados históricos**. Ao reativar o módulo, todo o histórico deve reaparecer intacto.
5. **Validação Estrita de Configuração e Injeção de Ambiente:**
   - Toda configuração remota deve ser validada por `AppConfig`. Chaves com privilégio `service_role` e tokens administrativos são ativamente bloqueados antes de qualquer inicialização de rede. Segredos nunca podem ser impressos desmascarados em logs ou no console.

