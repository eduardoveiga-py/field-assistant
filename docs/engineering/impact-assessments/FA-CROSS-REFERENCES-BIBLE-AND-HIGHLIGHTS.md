# Impact Assessment & Design — Cross-References, Offline NWT Bible Popup & JW-Style Colored Underlines

- **Feature ID:** `FA-CROSS-REFERENCES-BIBLE-AND-HIGHLIGHTS`
- **Branch:** `feat/cross-references-bible-and-highlights`
- **Base:** `origin/master` (including merged PR #53 `e47a9a9`)
- **Author:** Antigravity Engineering Agent

---

## 1. Problem Statement & Scope

Two major features requested by the product owner:

1. **Universal Cross-References (`app://ref/...`) + Offline NWT Bible Popup (`app://ref/bible/...`):**
   - Inside Base de Conhecimento (`Notas`, `Perguntas & Dúvidas`, `Documentos`, `Recursos`), `Banco de Gravuras`, `Tarefas`, `Projetos`, `Inbox` (`Capturas`), `JW Mail`, `Pesquisas`, `Experiências`, `Pessoas`, and `Estudos Bíblicos`, users can tap a toolbar/insert button to open a categorized selector (dropdown/filterable list of categories and their item titles) plus a **Bíblia — Tradução do Novo Mundo (TNM)** picker.
   - Selecting an item inserts a clickable reference token into the active text editor (`[prefix Title](app://ref/<type>/<id>)` or `[📖 Book Chapter:Verses](app://ref/bible/<bookNum>/<chapter>/<verseSpec>)`).
   - Clicking any reference inside readers/previews opens a popup **Reader / Visualizador** directly over the current screen with full item content/zoom viewer and a **"Ir para a aba"** button to jump directly to the referenced module/tab.
   - For **Tradução do Novo Mundo (TNM)** biblical references: zero copyrighted NWT text is bundled inside the repo; the app provides an offline-first local user importer (**`.epub` oficial do `jw.org` and `.json`**) plus manual offline verse storage/entry (`AppKvStore` chunked per book so IndexedDB/Web stays lightweight) and a transparent message if `.jwpub` (proprietary AES-128-CBC compressed SQLite) is selected, plus an `"Abrir no JW.org / JW Library"` canonical link.
   - For **JW Mail composer:** internal links stay clickable inside the app (drafts/local emails), convert cleanly into readable plain text/spans for external email recipients, and when picking an image from **Banco de Gravuras**, optionally attach the image to the outgoing e-mail (without `rawBytes` bloat).

2. **JW Library-Style Colored Underlines (`<u style="color:#hex">...</u>` + `<mark>`):**
   - Across text viewers and editors throughout the app — **explicitly excluding Estudos/Revisitas (`StudiesScreen`, `PersonDetailScreen`, `PeopleScreen` visits/study flows) and E-mails (`JW Mail`)** — users can highlight/underline passages in multiple colors (`#EAB308` Amarelo, `#10B981` Verde, `#3B82F6` Azul, `#EC4899` Rosa, `#F97316` Laranja, `#8B5CF6` Roxo) and remove underlines.
   - Works **both** from the editor toolbar (`RichMarkdownToolbar`) **and** by selecting text directly in reading mode (`KnowledgeItemReaderDialog`, split-view readers, task/project/research/experience/capture readers) which maps rendered selection offsets accurately back to the underlying Markdown source string and auto-saves via the owning domain manager.

---

## 2. User Journey & Component Map

### Modules & Files Affected
- `pubspec.yaml` — promote `archive` and `xml` (already transitive MIT-licensed packages in `pubspec.lock`) to direct dependencies so static analysis allows direct imports cleanly.
- `lib/navigation/app_navigation_controller.dart` *(new)* — Riverpod/ChangeNotifier navigation intent bridge allowing any popup viewer's **"Ir para a aba"** button to switch `MainNavigationShell` to a target `AppFeature` (plus optional sub-tab index / selected item ID) and pop intermediate routes safely.
- `lib/bible/nwt_bible_books.dart` *(new)* — 66 canonical Bible books (Portuguese & English names/abbreviations, chapter bounds, canonical JW.org book numbers `1..66`).
- `lib/bible/nwt_bible_service.dart` *(new)* — offline-first local storage (`bible_nwt_catalog_v1`, per-book `bible_nwt_book_<num>`, `bible_nwt_manual_v1`), ZIP/EPUB (`archive` + `xml`) and JSON importer with cooperative event-loop yields for Web PWA + clear `.jwpub` guidance error, verse lookup (`1..N`, ranges `16-18`, comma `6,7`), and manual verse save/delete.
- `lib/references/app_reference.dart` *(new)* — canonical `app://ref/<type>/<id>` & `app://ref/bible/<book>/<chapter>/<verses>` parser/formatter, category definitions (`AppRefCategory`: `bible`, `note`, `question`, `document`, `resource`, `picture`, `task`, `project`, `inbox`, `email`, `research`, `experience`, `person`, `study`), catalog loader across Drift/managers, and resolver to `AppResolvedReference` / reader modal.
- `lib/ui/widgets/highlight_text_helper.dart` *(new)* — JW Library underline palette + `HighlightSourceMapper` for accurate display-to-raw offset mapping + wrapping/replacing/removing `<u style="color:#hex">...</u>` and `<mark style="background:#hex">...` tags safely.
- `lib/ui/widgets/app_reference_picker_dialog.dart` *(new)* — category dropdown + search + Bible picker/importer dialog inserted from `RichMarkdownToolbar`.
- `lib/ui/widgets/bible_verse_popup_dialog.dart` *(new)* — Bible verse popup dialog (formatted verses, font scaler, copy, EPUB/JSON import trigger, manual verse editor, canonical `jw.org/finder` link).
- `lib/ui/widgets/app_reference_viewer.dart` *(new)* — universal popup dispatcher resolving `app://ref/...` URIs into `BibleVersePopupDialog`, `PictureDetailViewerScreen` (zoomable gravura + "Ir para Banco de Gravuras"), `KnowledgeItemReaderDialog` (with "Ir para a aba" button & optional inline highlight saving!), or item detail sheets.
- `lib/ui/widgets/rich_markdown_toolbar.dart` — add dedicated **Referência / Bíblia TNM** button + enhance **Sublinhar / Destaque (JW)** color picker (including colored underline + remover destaque) configurable via `enableHighlightPalette` / `enableCrossReferences` / `onReferenceInserted`.
- `lib/ui/widgets/markdown_preview_text.dart` — render colored `<u style="color:#hex">` underlines + `<mark>` cleanly, strip them in `cleanMarkdown`, make `[label](url)` spans clickable (supporting `app://ref/...` and `https?://` with disposable `TapGestureRecognizer`s in a `StatefulWidget`), and support optional inline `SelectableMarkdownBody` / selection-based underline callback!
- `lib/ui/widgets/knowledge_item_reader_dialog.dart` — route `app://ref/...` links to `AppReferenceViewer`, render `<u style="color:#hex">` underlines cleanly, add **"Ir para a aba"** optional callback, and add **direct text-selection underline toolbar / color palette (JW Library mode)** when `onContentUpdated != null`!
- `lib/inbox/email_html_sanitizer.dart` — update `stripMarkdown` to clean `<u style="color:...">` and `<mark...>` tags cleanly in plain previews; update `markdownToCleanHtml(..., preserveAppRefLinks: ...)` so external emails format `app://ref/...` cleanly without broken internal URIs while local drafts/copies retain clickable links.
- `lib/ui/main_navigation_shell.dart`, `lib/ui/screens/knowledge_base_screen.dart`, `lib/ui/screens/tasks_screen.dart`, `lib/ui/screens/project_detail_screen.dart`, `lib/ui/screens/picture_bank_screen.dart`, `lib/ui/screens/research_screen.dart`, `lib/ui/screens/experiences_screen.dart`, `lib/ui/screens/inbox_screen.dart` — wire deep-link jump state, click-to-read + direct highlight persistence on allowed modules, and keep **Studies/Revisits (`StudiesScreen`, `PersonDetailScreen`, `PeopleScreen`) and Email Composer/Viewer (`InboxScreen` email flows) explicitly free of JW underline controls**.

---

## 3. Data Flow, Security, Web/Mobile & Compatibility Invariants

- **Data Persistence & Sync:**
  - Colored underlines live inline inside each entity's existing text fields (`content`, `description`, `answer`, `summary`, `objective`, `caption`), triggering existing `update*` managers (`sync_queue` + Supabase sync automatically) with **zero Drift SQL schema migration** and **zero risk of orphaned highlight tables**.
  - NWT Bible chapters are stored locally in `AppKvStore` sharded **by book (`bible_nwt_book_<1..66>`)**, keeping IndexedDB Web reads/writes tiny (<200 KB per book) and non-blocking via cooperative `Future<void>.delayed(Duration.zero)` yields on import.
- **Legal / Copyright / Compliance:**
  - Zero copyrighted Watch Tower Bible texts embedded in the codebase/assets. Users import their own legally downloaded `.epub` from `jw.org` (or `.json` / manual excerpt) on device.
  - `.jwpub` proprietary encrypted SQLite is NOT brute-forced/bypassed; users get clear guidance to download `.epub` from `jw.org`.
- **Feature 2 Exclusion Boundary:**
  - `RichMarkdownToolbar(enableHighlightPalette: false)` in `JW Mail` Composer; `_ProfessionalEmailBodyView` and `StudiesScreen`/`PersonDetailScreen`/`PeopleScreen` have zero JW underline tools.
- **Offline-First & Web Safety:**
  - `FilePicker.platform.pickFiles(withData: true)` passes `Uint8List` directly so Web PWA, iOS, Android, Windows, macOS, and Linux all work identically without raw `dart:io File` calls in shared code.
  - `ENABLE_E2EE_SYNC` remains `defaultValue: false`. No silent `catch (_) {}` blocks in import/persistence flows.

---

## 4. Verification Plan
1. Unit tests (`test/`):
   - `test/bible/nwt_bible_service_test.dart`: EPUB ZIP+OPF+XHTML synthetic import, JSON import, `.jwpub` clear error rejection, sharded per-book storage & lookup (`single verse`, `range 16-18`, comma `6,7`), manual verse save/lookup, clear.
   - `test/references/app_reference_test.dart`: formatting/parsing all 14 `AppRefCategory` types + title escaping (`[`, `]`, `(`), catalog aggregation across all modules, `EmailHtmlSanitizer.markdownToCleanHtml(preserveAppRefLinks: false/true)` and `stripMarkdown` on `<u>`/`<mark>`.
   - `test/ui/widgets/highlight_text_helper_test.dart`: `HighlightSourceMapper` offset mapping on text with repeated words + existing bold/italic/links + wrap/replace-color/remove underline without corrupting adjacent Markdown.
2. Widget / Integration tests (`test/ui/`):
   - Selecting category & item in `AppReferencePickerDialog` inserts `app://ref/...` into controller; tapping link in `KnowledgeItemReaderDialog` / `MarkdownPreviewText` opens popup Reader / `BibleVersePopupDialog` / Image Viewer.
   - Selecting text or toggling JW color underline inside reader persists via `onContentUpdated` while `JW Mail` composer hides JW highlight palette and keeps Cross-Reference picker + optional `Banco de Gravuras` image attachment.
3. Gates:
   - `.\tool\pre_push.ps1`
   - `flutter test` + `flutter build web --release --base-href /field-assistant/`
   - PR & full GitHub Actions CI verification.
