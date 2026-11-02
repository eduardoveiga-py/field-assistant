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
4. **Exclusões Lógicas (Tombstones):**
   - Entidades sincronizáveis utilizam `deleted_at`. A exclusão física remota sem tombstone é proibida para evitar ressurgimento indevido por sincronizações atrasadas.
5. **Cursor Determinístico:**
   - A paginação do pull deve sempre incluir desempate determinístico: `.order('updated_at', ascending: true).order('id', ascending: true)`.

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

