# Impact Assessment & Design — Inbox UX, Sent/Two-Way Email Sync & Web PWA Freeze

- **Feature / Fix ID:** `FA-INBOX-UX-TWOWAY-SYNC-AND-WEB-PWA-FREEZE`
- **Branch:** `fix/inbox-sync-ux-twoway-and-web-pwa-freeze`
- **Base:** `origin/master`
- **Priority:** P0 (Web PWA Freeze & Data Bloat) / P1 (Two-Way Server Sync, Sent Sync, UX & Preview Bugs)
- **Author:** Antigravity Engineering Agent

---

## 1. Problem Statement & User Journey Mapping

Seven distinct failures were identified in the Inbox, Email Sync, Captures, and Web PWA flows:

1. **Email stays unread after click:** Tapping an email in `JW Mail` (Master-Detail split view or mobile full-screen reader) or `Hub Restrito` selects or opens it without setting `isRead = true`, leaving the blue unread dot active and counting it under `Não lidos`. Additionally, locally composed Sent messages (`inbox_screen.dart` Graph/Gmail/Exchange branches) defaulted `JwEmailMessage.isRead` to `false`, displaying sent messages as unread.
2. **No batch selection / Delete / Move to Folder:** Users cannot multi-select emails in `JW Mail` to batch-delete or move them across folders (`Caixa de Entrada`, `Enviadas`, `Rascunhos`, `Spam`, `Lixeira`), nor move a single email to another folder.
3. **Captures tab (`Capturas`) cards & full-screen reader:** Email capture cards have oversized vertical padding/spacing without a full-screen reader action button. Cards must become compact vertically **while keeping every existing content element, badge, audio player, attachment chip, menu, and all four convert buttons (`Virar Tarefa`, `Virar Projeto`, `Virar Nota`, `Virar Pergunta`)**.
4. **Sent folder (`Enviadas`) sync gaps:**
   - `JwImapClient.fetchRemoteEmailPages` (`lib/inbox/jw_email_service.dart`) hardcodes `selectInbox()` and `'INBOX'` only, never discovering or fetching IMAP `Sent` (`\Sent` / `Sent` / `Sent Items` / `Sent Messages` / `Enviados` / `Enviadas`), `Drafts`, `Spam`, or `Trash`.
   - `MicrosoftOAuthService.fetchMessages` queries Graph without `$orderby` (`sentDateTime desc` / `receivedDateTime desc`) and breaks silently if `sentitems` differs; plus if sync freezes/aborts mid-way while downloading attachments in `INBOX`, `SENT`/`sentitems` never reaches persistence.
   - `GmailOAuthService.fetchMessages` skips messages already seen in `INBOX` (e.g., self-sent emails holding both `INBOX` and `SENT` labels), so filtering `Enviadas` misses emails with `SENT` + `INBOX` unless `labels` or Sent attribution is preserved.
5. **Lack of two-way server state reflection (External <-> App):**
   - **Pull direction:** `EmailSyncCoordinator.persistSyncedMessages` (`if (existing != null) continue;`) and `JwEmailService.syncEmails` never update `isRead`, `folderName`, `folderId`, or `isDraft` on existing messages when modified on the external server (e.g., opened in Outlook Web, Gmail Web, or Apple Mail).
   - **Push direction:** Local read/unread changes, folder moves, and deletes only updated SQLite + Supabase queue without calling provider APIs (`Gmail REST messages.modify / trash / delete`, `Microsoft Graph PATCH isRead / POST move / DELETE`, `IMAP UID STORE \Seen / UID MOVE / COPY+EXPUNGE`).
   - **Exchange ActiveSync (`ExchangeReadService`):** Must clearly stay safe/bounded: `ExchangeReadService.sync` pulls remote `read`/folder changes cleanly into existing entries without duplication, and if server-side Exchange EAS mutations are requested, either use `EasClient` safely where session permits or clearly mark Exchange Hub accounts as read-only / non-mutating per hub isolation rules while pushing full two-way mutations for Gmail, Outlook/Hotmail (Graph), and IMAP. (For offline mutations on Gmail/Graph/IMAP, queue pending remote email mutations in `appKvStore` so they push automatically when connectivity returns!)
6. **Raw `**` Markdown markers leaking in previews:**
   - `_buildEmailCard` (`lib/ui/screens/inbox_screen.dart:3091`) calls `EmailHtmlSanitizer.extractPlainText(...)` without `cleanMarkdown: true`.
   - `EmailHtmlSanitizer._stripMarkdownSyntax` leaves trailing/nested `*`, `` ` ``, `_`, `___`, `***`, `~~`, headers, blockquotes, and truncated trailing `*`/`**` markers behind (`Ol? mundo! Sistema *...`), and conversion/signature/preview helpers call `extractPlainText` without `cleanMarkdown: true`.
7. **Web PWA Freeze (`Página sem resposta`) on Sync and Splash Reload:**
   - **Root Cause A (Triple `Uint8List rawBytes` JSON explosion):** `GmailOAuthService` and `MicrosoftOAuthService` store `'rawBytes': Uint8List` in attachment maps alongside `'base64'`. `JwEmailMessage.toJson()`, `InboxEntries.attachments`, and `SyncQueue.payload` serialize every byte as a JSON integer array `[137, 80, ...]` three times per message. On Chrome Web's single JS thread + IndexedDB/SQLite WASM, this allocates hundreds of MB synchronously and freezes the page.
   - **Root Cause B (Unconditional full re-fetch & unbatched SQLite writes on Splash & Sync):** `AuthSplashScreen` runs `EmailSyncCoordinator.syncAll` + `CalendarSyncCoordinator.syncAll` + `SupabaseSyncService.sync` concurrently on every cold reload. Wait `.timeout(5000ms)` never cancels running futures; `fetchMessages` re-downloads attachment bodies even for already-known IDs; `persistSyncedMessages` performs up to 400 individual un-transacted inserts triggering hundreds of Drift stream rebuilds.
   - **Root Cause C (Concurrent `GoogleSignIn.instance.initialize` race on Web):** `GoogleCalendarProvider` and `GmailOAuthService` initialize `GoogleSignIn.instance` simultaneously inside `Future.wait`.
   - **Root Cause D (Already-corrupted IndexedDB state on existing user devices):** Simply stopping new `rawBytes` writes leaves already-persisted bloated rows in `inbox_entries` and `sync_queue`, keeping Chrome frozen on reload/sync until sanitized.
   - **Root Cause E (`InboxScreen.build()` stream/future recreation & CSS regex hardening):** Recreating `watchRetainedEmails` / `loadAccounts` inside `build()` and potential backtracking in `EmailHtmlSanitizer` CSS cleanup regexes.

---

## 2. Architecture & Design Changes

### 2.1 Web PWA Freeze Elimination & Local DB Recovery (`FA-P0`)
1. **Attachment Persistence Hygiene (`lib/inbox/jw_email_service.dart`, `lib/inbox/email_sync_coordinator.dart`, `lib/ui/screens/inbox_screen.dart`):**
   - Add `JwEmailMessage.sanitizeAttachmentsForJson(List<Map<String, dynamic>> attachments)` that drops `'rawBytes'` (and any non-JSON `Uint8List` values) when encoding `JwEmailMessage.toJson()` and `InboxEntries.attachments`, keeping `'base64'`, `'attachmentId'`, `'size'`, `'name'`, `'mimeType'`, `'contentId'`, `'isInline'`, `'type'`.
   - Keep `'rawBytes'` in-memory on freshly fetched `JwEmailMessage` instances so existing in-memory caller contracts and unit tests (`gmail_oauth_service_test`, `microsoft_oauth_service_test`) remain 100% compatible, while guaranteeing `'rawBytes'` NEVER reaches SQLite, `inbox_entries`, `sync_queue`, or Supabase.
   - Harden `_openAttachment` (`inbox_screen.dart`) to inspect `rawBytes` safely (`rawBytes is Uint8List` vs `List<int>` fallback vs `base64Decode`).
2. **Idempotent Legacy `rawBytes` Scrubbing (`EmailSyncCoordinator.sanitizeLegacyAttachmentBlobs(db)`):**
   - Run once per schema/scrub flag (`appKvStore['email_rawbytes_scrubbed_v1']`) using SQL `WHERE metadata LIKE '%"rawBytes":%' OR attachments LIKE '%"rawBytes":%'` and matching `sync_queue` rows (`WHERE payload LIKE '%"rawBytes":%'`), stripping `'rawBytes'` integer arrays in small cooperative batches with `Future<void>.delayed(Duration.zero)` yields so an already-bloated Web IndexedDB recovers smoothly without freezing UI.
3. **Incremental Fetch & Cooperative Yielding:**
   - Pass `knownMessageIds` from `EmailSyncCoordinator` into `GmailOAuthService.fetchMessages` and `MicrosoftOAuthService.fetchMessages`:
     - **Gmail:** For known IDs, call `format=metadata&metadataHeaders=From&metadataHeaders=Subject` (no payload body, **zero** attachment downloads!) only to read current `labelIds` (`isRead` + folder move detection). For new IDs, fetch `format=full`. Insert `await Future<void>.delayed(Duration.zero)` between messages on `kIsWeb`.
     - **Graph:** List endpoint already returns `id`, `isRead`, `parentFolderId`, `body` (`$top` page). Skip `_fetchAttachmentMetadata` HTTP calls when `knownMessageIds.contains(msg.id)`.
   - Batch `persistSyncedMessages` inside `db.transaction(() async { ... })` in chunks (e.g., 25 records per transaction with `Future<void>.delayed(Duration.zero)` yield between chunks).
4. **Shared `GoogleSignIn` Init Lock & Splash Web Non-Blocking Sync (`lib/core/google_sign_in_initializer.dart`, `lib/ui/screens/auth_splash_screen.dart`):**
   - Serialize `GoogleSignIn.instance.initialize(...)` behind a single static/module Future lock used by both `GmailOAuthService` and `GoogleCalendarProvider`.
   - In `AuthSplashScreen._initializeAuthGate`: run quick DB scrub + Supabase sync + Calendar sync with strict timeouts, and on `kIsWeb` do NOT block splash startup waiting for multi-hundred-email OAuth fetches — navigate immediately once essential auth/records sync completes and kick off a lightweight, non-overlapping background email sync post-navigation (guarded against concurrent `_syncEmails()` runs).
5. **Regex Linear-Time Hardening & `InboxScreen` Stream Stability:**
   - Simplify CSS cleanup regexes in `EmailHtmlSanitizer` to eliminate ambiguous nested whitespace backtracking and cap sanitization loop work safely.
   - Cache `_accountsFuture` and `_retainedEmailsStream` in `_InboxScreenState` rather than creating fresh DB subscriptions on every `build()`.

### 2.2 Sent Folder (`Enviadas`) & Two-Way Server Sync (`FA-P1`)
1. **Sent Discovery & Metadata Completeness:**
   - **Gmail (`GmailOAuthService`):** Preserve `labelIds` (including `'SENT'`) in `JwEmailMessage` / metadata (`labels`), and avoid dropping `'SENT'` attribution when a message also holds `'INBOX'` (show under `Enviadas` filter when `folderName` is Sent OR `labels.contains('SENT')`). Use `labelIds` reliably for read/folder reconciliation; continue fetching across folders if one non-inbox folder transiently errors while reporting folder errors explicitly.
   - **Microsoft Graph (`MicrosoftOAuthService`):** Order `sentitems` explicitly with `sentDateTime desc` (and other folders with `receivedDateTime desc`), falling back cleanly without `$orderby` if a test mock or endpoint rejects `$orderby`. Discover folders via `/me/mailFolders` fallback if `sentitems` alias returns 404. Use `sentDateTime ?? receivedDateTime` as primary date for `Enviadas`.
   - **IMAP (`JwImapClient` / `JwEmailService`):** Extend `JwImapClient` with multi-folder support (`\Sent`/`Sent`/`Sent Items`/`Sent Messages`/`Enviados`, `\Drafts`/`Drafts`, `\Junk`/`Spam`, `\Trash`/`Trash`), setting `folderName: 'Enviadas'`, reading `\Seen` flag into `isRead`, and tracking per-mailbox `(uidValidity, uid)` deterministically while preserving backward-compatible `JwImapSession` test doubles via an extended `JwImapFolderSession` / `JwImapWritableSession` interface.
   - **Locally Sent `JwEmailMessage` Records (`inbox_screen.dart`):** Always initialize locally created sent messages with `isRead: true`.
2. **Pull Reconciliation (`EmailSyncCoordinator.persistSyncedMessages` & `JwEmailService`):**
   - When `existing != null`, inspect persisted `email` metadata and reconcile changes to `isRead`, `folderName`, `folderId`, `isDraft`, and `labels` whenever the server state differs, preserving richer locally-cached bodies/attachments and updating `updatedAt` + `revision + 1` in the batch transaction.
3. **Push Mutations & Offline Queue (`GmailOAuthService`, `MicrosoftOAuthService`, `JwEmailService`, `EmailSyncCoordinator`):**
   - Local-first mutations: `JwEmailService.setEmailsReadStatus`, `moveEmailsToFolder`, and `deleteEmails` commit locally first inside a DB transaction (so UI and offline UX never fail).
   - **Online Server Push:**
     - **Gmail REST:** `markMessageRead` (`POST /messages/{id}/modify`), `moveMessageToFolder` (`trash` / `untrash` / `modify`), `deleteMessage` (`trash` or `DELETE` if already in Trash).
     - **Microsoft Graph:** `markMessageRead` (`PATCH /me/messages/{id}`), `moveMessageToFolder` (`POST /me/messages/{id}/move` returning new remote ID -> reconcile remote ID in local metadata!), `deleteMessage` (move to `deleteditems` or `DELETE` if already in `Lixeira`).
     - **IMAP:** Optional `JwImapWritableSession` commands (`setFlags` `\Seen`, `moveUids` / `copy` + `\Deleted` + `expunge`).
     - **Exchange Hub (`ExchangeReadService`):** Remains read-only toward the Hub server (pulling remote read/folder changes into local DB, updating locally with clear boundary honesty).
   - **Offline Remote Action Queue (`appKvStore`):** If a remote mutation fails due to offline/network error (or happens while disconnected), store pending `{accountEmail, protocol, messageId, action, payload}` in an idempotent pending queue in `appKvStore`, flushed automatically at the start of `EmailSyncCoordinator.syncAll` before pulling latest state!

### 2.3 Inbox UX & Markdown Preview Fixes (`InboxScreen` & `EmailHtmlSanitizer`)
1. **Mark Read on Click (`InboxScreen`):**
   - Single tap in `JW Mail` or `Hub Restrito` sets `_selectedEmailId = msg.id` and calls `_markEmailsReadStatus([msg.id], isRead: true)` when `!msg.isRead`.
   - Maintain `_stickyOpenedEmailId` while `_unreadOnly` is active in Master-Detail split-view so the open right pane does not vanish under the user's cursor immediately after clicking.
   - Add `"Marcar como lida / não lida"` toggle button in the detail pane, mobile reader AppBar, and card menu.
2. **Multi-Select Mode + Batch Delete / Move to Folder (`InboxScreen`):**
   - Add `_isEmailSelectionMode` and `_selectedEmailIds` in `_InboxScreenState`.
   - Entry via toolbar toggle button (`btn_toggle_email_selection`) or `onLongPress` on email card.
   - Selection bar with count, `Todas/Limpar`, `Mover para pasta` (`Caixa de Entrada`, `Enviadas`, `Rascunhos`, `Spam`, `Lixeira`), `Lida / Não lida`, `Excluir` (soft delete -> Trash, or permanent delete confirmation if already in Trash), and `Fechar`.
   - Add `"Mover para pasta..."` to single-email card menu and detail/reader actions.
3. **Captures Tab (`Capturas`) Compact Cards & Full-Screen Email Reader (`InboxScreen`):**
   - Tighten `_buildEntryCard` outer margin (`8`), padding (`fromLTRB(12, 8, 12, 8)`), internal vertical spacing (`6`), and compact chip/button density **without removing any badges, content lines, audio player, attachments, popup menu, or any of the 4 convert buttons**.
   - Add a dedicated full-screen button (`Key('btn_capture_fullscreen_${entry.id}')`, `Icons.open_in_full_rounded`, tooltip `'Ler e-mail em tela cheia'`) on email capture cards (`entry.sourceType == 'email'`) that opens `_openEmailReaderScreen(context, ...)` seamlessly.
4. **Markdown Preview Stripping (`EmailHtmlSanitizer` & `InboxScreen`):**
   - Harden `EmailHtmlSanitizer._stripMarkdownSyntax` / `extractPlainText(..., cleanMarkdown: true)` to remove `***`, `**`, `*`, `___`, `__`, `_`, `` ` ``, `~~`, headings `#`, blockquotes `>`, bullet prefixes, `[text](url)`, plus orphaned/truncated `*`/`**` markers (e.g., `"Sistema *..."`).
   - Pass `cleanMarkdown: true` in `_buildEmailCard` (`inbox_screen.dart:3091`), conversion helpers, and `_extractPlainText` helpers where plain text previews render outside `MarkdownPreviewText`.

---

## 3. Security, Privacy & Compatibility Invariants
- **Offline-First & Zero Silent Failures:** Local DB updates commit first; remote sync failures are logged via `AppLogger`, accumulated in offline queue or surfaced in UI (never empty `catch (_) {}`).
- **Web Safety:** Zero unconditional `dart:io` or `sqlite3` imports; all `Uint8List` DB serialization eliminated.
- **Data Preservation:** Deleting moves to `Lixeira` / soft-deletes unless deleting from `Lixeira` with explicit confirmation; `Exchange` / Hub Restricted isolation preserved.
- **Test Compatibility:** Existing `JwImapSession` / `ExchangeSession` / `OAuthTokenStore` / `JwEmailMessage` contracts remain backward-compatible or cleanly extended.

---

## 4. Verification Plan
1. Unit tests (`test/inbox/`):
   - `rawBytes` excluded from persisted `JwEmailMessage.toJson()` / `EmailSyncCoordinator` DB columns, legacy DB scrub helper clears bloated JSON blobs safely, and `_openAttachment` handles both `Uint8List` and JSON-decoded maps.
   - `EmailSyncCoordinator` batch transactions + pull reconciliation (updates `isRead`, `folderName`, `folderId` on existing entries).
   - `GmailOAuthService` & `MicrosoftOAuthService`: Sent folder fetch (`$orderby`, `SENT` label preservation), metadata-only fetch for known IDs, remote `markMessageRead`, `moveMessageToFolder`, `deleteMessage`, and offline queue flush.
   - `JwImapClient` / `JwEmailService`: Multi-folder Sent sync + `STORE \Seen` / folder move / delete push.
   - `EmailHtmlSanitizer`: Markdown cleaning (`**`, `*`, `_`, `` ` ``, orphan `*` at truncation) and bounded CSS sanitization runtime.
2. Widget tests (`test/ui/screens/inbox_screen_test.dart`):
   - Click unread email marks as read immediately and removes unread indicator.
   - Multi-select mode selects multiple emails and executes batch Move to Folder and batch Delete.
   - Captures tab renders compact cards retaining all 4 convert buttons + full-screen email reader button opens reader.
   - Left email list preview renders without raw `**` or `*` markers.
3. Gates:
   - `dart format lib test integration_test`
   - `.\tool\pre_push.ps1`
   - `dart analyze lib test integration_test --fatal-warnings`
   - `flutter test` across affected modules and full repository suite.
