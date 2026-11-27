# Impact Assessment & Architecture Design — Desbloqueio da Fila de Sincronização, Backfill E2EE de Registros Locais e Sync Automático Fluido Multi-Dispositivos

- **Task ID:** `FA-SYNC-QUEUE-AUTO-FLUID`
- **Branch:** `fix/sync-queue-backfill-and-realtime` (baseada em `master` `83a9ab7`)
- **Governance:** `AGENTS.md`, `.agents/rules/field-assistant-ci-gate.md`, `.agents/skills/field-assistant-engineering-standard/SKILL.md`, `.agents/skills/offline-first-sync/SKILL.md`

---

## 1. Problema Observado & Evidência no Código

Relato do usuário + evidência da captura de tela (`SyncQueueManagementSheet` / `SettingsScreen`):
1. **"113 `inbox_entries • UPDATE` pendentes com `Tentativas: 0`" + subtítulo `"Sincronização bidirecional: 0 recebidos, 0 enviados."` + selo `"Local-First"`:**
   - **Causa raiz A (`lib/inbox/email_sync_coordinator.dart:389-451`, `lib/inbox/jw_email_service.dart:2685-2814`):** Ao sincronizar/reconciliar e-mails já existentes (`email_AQMkADAW...` Microsoft Graph / Gmail / Exchange), `persistSyncedMessages` detecta diferenças triviais (ordem de `labels` comparada via `listEquals`, ou `folderId == null` local vs GUID remoto quando `folderName` é idêntico) e grava `UPDATE`s na `sync_queue` **sem `_base` e sem `SyncTimestamp.normalizeMapDates(...)`** (o mesmo ocorre em `setEmailsReadStatus`, `moveEmailsToFolder` e `deleteEmails` em `jw_email_service.dart`).
   - **Causa raiz B (`lib/sync/supabase_sync_service.dart:2858-2972`, `5195-5204`):** Quando qualquer entidade acumula `>= 2` operações pendentes sem `_base`, `_coalescePendingChanges()` recusa consolidar (`valid = false`). Em seguida, `_processQueueE2ee()` cai em `if (related.length > 1) { failure++; errors.add(...); continue; }` **sem incrementar `attempts` (`Tentativas: 0`), sem gravar `lastError` e mantendo `status = 'pending'` (`Falhas: 0`, `Conflitos: 0`)**. Como `_runSync()` (`3246`) retorna apenas `'Sincronização bidirecional: X recebidos, Y enviados.'` ignorando `failureCount`/`errors` e `SyncQueueManagementSheet` exibe só `res.message`, o usuário vê `"0 recebidos, 0 enviados"` sem saber que a fila está travada.
   - **Causa raiz C (`lib/ui/screens/settings_screen.dart`):** O chip de estado em Configurações exibe `'Local-First'` de forma fixa sempre que `conflict == 0 && failed == 0`, mesmo quando E2EE e Supabase estão ativos ou com envios pendentes.
2. **E-mails sincronizaram e uma nota nova sincronizou, mas dados históricos pré-existentes ("o restante") não apareceram no outro dispositivo:**
   - **Causa raiz D:** `SupabaseSyncService` só envia registros que já possuem entrada em `sync_queue`, enquanto o pull E2EE (`_fetchRemoteChangesE2ee`) só lê envelopes já gravados no Supabase. Registros locais criados offline antes da ativação do E2EE, restaurados sem fila ou indexados sem enfileiramento (`KnowledgeBacklinkIndexer.ensureInitialBackfill(enqueueSync: false)`) não possuem nem entrada na `sync_queue` nem checkpoint (`e2ee_checkpoint_v1_*`), ficando invisíveis para outros dispositivos.
3. **Sincronização "vice e versa" lenta / não automática / não fluida entre celular, tablet e PC:**
   - **Causa raiz E (`lib/ui/main_navigation_shell.dart:49-108`):** Não existe disparo reativo quando mutações entram na `sync_queue` (espera até 2 minutos pelo `Timer.periodic`), não há listener Web para `visibilitychange`/`focus`/`online` (muito mais confiável na PWA que `AppLifecycleState.resumed`) e não há canal Supabase Realtime para acordar o outro dispositivo logo após um push E2EE.
4. **Importação de Bíblias (`.json` e `.epub`) e Publicações (`.epub`) na Biblioteca Offline falhando em Web PWA / Mobile:**
   - **Causa raiz F (`lib/ui/widgets/settings/offline_library_dialog.dart`, `file_picker_web`, `android_file_picker`, `file_picker_darwin`):** `FilePicker.pickFiles` usava `type: FileType.custom` (`['epub', 'json', 'jwpub', 'jwlpub']`) e `webOptions` padrão (`cancelUploadOnWindowBlur: true`). Na Web PWA (desktop/iOS/Android), o evento `window.focus` após abrir o seletor do sistema dispara cancelamento em 500ms retornando `[]` silenciosamente; além disso, `<input accept="...">`, Android `EXTRA_MIME_TYPES` e iOS `UTType` dinâmicos frequentemente esmaecem `.epub`/`.json` baixados com MIME genérico (`application/octet-stream`/`text/plain`).
   - **Causa raiz G (`lib/bible/nwt_bible_service.dart`, `lib/publications/imported_publications_service.dart`):** `_persistParsedBible` gravava até 66 livros + catálogos fora de `db.transaction(...)` (desempenho/contenção em IndexedDB Web WASM), `_importJsonBytes` falhava em BOM UTF-8 (`\uFEFF`), arquivos sem sufixo `.json` ou `chapter`/`verse` em string, e leitores EPUB não decodificavam `href` URL-encoded (`%20`), BOM XML ou entidades HTML comuns (`&nbsp;`, `&mdash;`, etc.).

---

## 2. Solução & Arquitetura Escolhida

1. **Prevenção de churn e integridade de payloads em `inbox_entries`:**
   - Comparação normalizada de `labels` por conjunto (`Set`) e reconciliação inteligente de `folderId` em `EmailSyncCoordinator.persistSyncedMessages`, evitando gerar 100+ `UPDATE`s redundantes quando `folderName`, `isRead`, `isDraft` e conjunto de `labels` não mudaram.
   - Normalização com `SyncTimestamp.normalizeMapDates` + snapshot `_base` em todas as mutações `UPDATE` de `EmailSyncCoordinator` e `JwEmailService` (`setEmailsReadStatus`, `moveEmailsToFolder`, `deleteEmails`).
   - Inclusão de `nextReviewAt` / `next_review_at` em `SyncTimestamp.dateFieldKeys`.
2. **Consolidação segura de cadeias `pending` (`_coalescePendingChanges`) e diagnóstico transparente:**
   - Permitir consolidar cadeias estritamente `'pending'` (`attempts == 0`, sem `'failed'`/`'conflict'`/`'in_progress'`) quando `_base` foi omitido por versões anteriores e o snapshot final coincide com o estado atual em SQLite/Drift (ou é tombamento `DELETE`), mantendo 100% da proteção contra conflitos reais e nunca descartando `_base` quando existente.
   - Em `_runSync()`, reportar falhas/bloqueios/conflitos em `message` quando `> 0`.
   - Em `SyncQueueManagementSheet`: exibir também `res.errors.first`, sincronizar reativamente via `syncStatusStreamProvider` (sem manter stream Drift local que deixe timer pendente ao desmontar), mostrar nomes legíveis de tabelas e oferecer botão **"Desbloquear & Reenviar Pendentes"**.
3. **Backfill E2EE Seguro e Idempotente (`lib/sync/e2ee_local_backfill.dart`):**
   - Varre as 29 `syncTables` (ordem pai-antes-de-filho) somente após passar pelo `_evaluateSyncGate` e após um pull inicial bem-sucedido (sem erro, preservando dados remotos).
   - Compara cada registro local contra `app_kv_store` (`e2ee_checkpoint_v1_*`) e `sync_queue` pendente/conflitante em lote; só enfileira `'INSERT'` para registros que **nunca** foram sincronizados neste cofre/conta e marca `e2ee_initial_backfill_done_v1_<ownerId>` (limpo automaticamente por `SyncOwnerGuard.resetLocalWorkspaceForAccountSwitch` porque começa com `e2ee_`).
   - Também expõe acionamento manual ("Verificar & Reenviar Dados Locais") nas Configurações e na Fila de Sincronização.
4. **Sincronização Reativa + Realtime + Visibilidade Web (`lib/sync/realtime_sync_notifier.dart`, `lib/sync/platform_sync_triggers*.dart`, `lib/ui/main_navigation_shell.dart`):**
   - **Outbox reativo:** observa `watchSyncQueueCounts()` com debounce curto (1.5s) e trava anti-loop quando o último ciclo não teve progresso com falha/bloqueio.
   - **Realtime E2EE zero-plaintext:** canal Broadcast autenticado por hash do `ownerId` (`sync_notify_<sha256_24>`) enviando apenas `{sender: instanceId}` após envios com sucesso + inscrição em `postgres_changes` em `public.encrypted_records` (filtrada por `owner_id=eq.<uid>`). Migração aditiva idempotente (`20261126000000_enable_realtime_encrypted_records.sql`) adiciona `public.encrypted_records` à publicação `supabase_realtime`.
   - **Gatilhos de plataforma multiplataforma:** conditional import (`*_stub.dart` / `*_web.dart`) escuta `visibilitychange`, `focus` e `online` no navegador sem importar `dart:js_interop` em alvos nativos; fallback periódico reduzido para 45s.
5. **Importação Resiliente da Biblioteca Offline (`lib/ui/widgets/settings/library_file_picker*.dart`, `offline_library_dialog.dart`, `nwt_bible_service.dart`, `imported_publications_service.dart`):**
   - **Picker Web sem falso cancelamento (`library_file_picker_web.dart`):** usa `<input type="file">` com `package:web` sem filtro MIME restritivo e sem cancelamento apressado de 500ms em `window.focus` (usa `change`, `cancel` nativo e fallback amplo de 3000ms), preservando gesto de clique síncrono no Safari/Chrome PWA.
   - **Picker Nativo IO (`library_file_picker_io.dart`):** usa `FileType.any` com fallback em cascata (`readAsBytes()` -> `readAsByteStream()` -> `File(path).readAsBytes()`) evitando bloqueio de MIME/UTType em Android DocumentsUI e iOS Arquivos.
   - **Endurecimento de parsers e persistência atômica:** transação única em `db.transaction(...)` no `_persistParsedBible`, detecção de JSON por conteúdo, remoção de BOM UTF-8, suporte a `href` `%20` / case-insensitive e entidades HTML comuns no EPUB, além de progresso visível no diálogo.

---

## 3. Segurança, Isolamento de Contas e Rollback

- **Zero plaintext:** Broadcast Realtime transporta exclusivamente `{sender: uuid}` sem IDs de entidades, nomes de tabelas ou conteúdo; `encrypted_records` continua protegido por RLS (`owner_id = auth.uid()`).
- **Isolamento de conta (`FA-SEC-04`):** Channel topic e chave de conclusão do backfill (`e2ee_initial_backfill_done_v1_<ownerId>`) são prefixados/hasheados por `ownerId` e limpos em `SyncOwnerGuard`.
- **Fail-closed:** Sem chave E2EE instalada ou com PIN Web bloqueado, backfill, push e pull continuam bloqueados com status explícito.
- **Rollback:** Todas as alterações no cliente são incrementais e reversíveis por git revert sem perda de registros SQLite ou remotos; a migração SQL é aditiva e idempotente (`supabase_realtime`).

---

## 4. Plano de Testes

- `test/sync/sync_queue_coalesce_and_backfill_test.dart`:
  - Reproduzir exatamente a fila travada com `inbox_entries • UPDATE` duplicados/sem `_base` -> verificar consolidação e drenagem completa E2EE com `attempts == 0` destravado;
  - Testar `EmailSyncCoordinator` sem churn de `folderId`/`labels` e com `_base` presente nos `UPDATE`s;
  - Testar `E2eeLocalBackfill` com dados locais pré-existentes + respeito estrito a registros já checkpointados, isolamento de conta e pull prévio;
  - Testar `AutoSyncCoordinator`/debouncer reativo e anti-loop de falha;
  - Testar `SyncQueueManagementSheet` (exibição de erro detalhado e botão Desbloquear & Reenviar).
- `test/bible/nwt_bible_service_test.dart`, `test/publications/imported_publications_service_test.dart` e `test/ui/bible_multi_translation_and_library_ui_test.dart`:
  - Testar BOM UTF-8, detecção automática JSON sem sufixo, `chapter`/`verse` em string, `href` `%20` / case-insensitive e entidades HTML em EPUB + fluxo completo UI do `OfflineLibraryDialog` (cancelamento, arquivo vazio, importação JSON/EPUB);
- Suite completa existente: `test/regression_audit_and_fixes_test.dart`, `test/sync/`, `test/inbox/`, `test/knowledge/`, `test/ui/`, `.\tool\pre_push.ps1`, `ci_coverage_check.py --enforce-crypto-min=90`, `flutter build web --release`.
