# Impact Assessment & Design — Biblioteca Offline Multi-Tradução (Bíblias e Publicações), Comparação Estilo JW Library e Exportação PDF (E-mails e Base de Conhecimento)

- **Task ID:** `FA-BIBLE-MULTI-PUBLICATIONS-PDF-EXPORTS`
- **Branch:** `feat/bible-library-comparison-and-pdf-exports` (ramificada de `origin/master` @ `91331f2`)
- **Compliance:** `AGENTS.md`, `.agents/rules/field-assistant-ci-gate.md`, `.agents/skills/field-assistant-engineering-standard/SKILL.md`, `.agents/skills/flutter-pre-pr-gate/SKILL.md`, `.agents/skills/github-pr-guardian/SKILL.md`

---

## 1. Problem Statement & Desired Outcome

1. **Multi-Translation Bibles & Publications Offline Library (Settings + Reference Picker + JW Library-style Comparison Popup):**
   - **Current state:** `NwtBibleService` (`lib/bible/nwt_bible_service.dart`) stores only a single Bible (`bible_nwt_catalog_v1` + `bible_nwt_book_<n>`), overwriting it on every import. `BibleVersePopupDialog` displays only that single translation and embeds import buttons inside the reading popup and inside `AppReferencePickerDialog`. Non-Bible `.epub` publications cannot be imported into an offline library or referenced via `app://ref/publication/...`.
   - **User need:**
     - Move all Bible and publication import workflows into a dedicated window/area in **Configurações** (`SettingsScreen`), removing import buttons from other screens (`BibleVersePopupDialog`, `AppReferencePickerDialog`).
     - Support importing multiple Bibles across different languages/translations (`.epub`, `.json`) and other `.epub` publications (books, brochures, study guides).
     - Make imported Bibles and imported publications visible and selectable in the cross-reference list (`AppReferencePickerDialog` / `AppRefCategory`), opening an offline reader popup when clicked (`AppReferenceViewer`).
     - Evolve `BibleVersePopupDialog` so the user can read **1 translation** or **compare 2+ translations** stacked/side-by-side (JW Library *"Comparar versões"* style), preserving per-translation highlights, copy, manual verse fallback, and font-size controls.
   - **Critical verified constraint / blocker regarding `.jwpub` / `.jwlpub` (`sbi1_TCN.jwpub`):**
     - Verified locally in `C:\Users\vanes\Downloads\sbi1_TCN.jwpub` (`Tupanaãrü Ore (Perú)`, `MepsLanguageIndex: 733`, `contentFormat: "z-a"`): `.jwpub` packages store `manifest.json`, `Publication`, `BibleBook`, `Document` titles, and cover images in plaintext inside the nested SQLite database, **but** all `BibleVerse.Content`, `BibleChapter.Content`, and `Document.Content` blobs are encrypted (`z-a` proprietary JW Library encryption).
     - Decrypting `.jwpub` body blobs requires reverse-engineered proprietary keys to bypass Watchtower's cryptographic content protection, which is prohibited by repository policy (`docs/JW_LIBRARY_LINKS.md` — *"Sem Raspagem Indevida"*) and engineering/security boundaries.
     - Therefore, `.jwpub`/`.jwlpub` files can have their unencrypted metadata inspected to produce an explicit, accurate user notice explaining why encrypted `.jwpub` bodies cannot be extracted and recommending `.epub` (from `jw.org`) or `.json`/manual entry. No `.jwpub` decryption or copyright circumvention is implemented.

2. **Email Export to PDF:**
   - **Current state:** `InboxScreen._showExportEmailModal` and `JwEmailService.exportEmail` only export emails to `.md`, `.eml`, and `.txt`.
   - **Desired outcome:** Add **Documento PDF (.pdf)** export option to `_showExportEmailModal`, `JwEmailService.exportEmail(..., format: 'pdf')`, and `_showExportInboxModal`, generating a clean A4 PDF with embedded Unicode TTF fonts (`OfficialDocFonts` supporting Portuguese and Ticuna diacritics) via `BinaryFileSaver` (cross-platform Web PWA + iOS + Windows + Android).

3. **Knowledge Base Export to PDF in ALL 5 Tabs:**
   - **Current state:** Notes and Questions only offer Markdown copy/download; Documents, Resources, and the Knowledge Base tab header lack a consistent PDF export button across all 5 tabs (`Notas`, `Perguntas & Dúvidas`, `Documentos`, `Recursos`, `Cartas & Atas`).
   - **Desired outcome:** Expose a clear **"Exportar PDF"** action across **all 5 tabs** of `KnowledgeBaseScreen`, plus per-item PDF export in Notes (`_exportNote` + wide split-pane header), Questions (`_exportQuestion`), Documents (card menu), Resources (card menu), `KnowledgeItemReaderDialog`, and quick-access PDF button in `OfficialDocumentsScreen`.

4. **UI/UX Review of Knowledge Base Screenshot 2:**
   - Provide a factual, codebase-grounded visual and UX critique of the Notes split-view (left list cards + right note detail pane) and actionable improvement proposals without introducing unrequested breaking layout changes.

---

## 2. User Journey & Component Map

### Journey 1: Importing Bibles & Publications in Settings -> Referencing -> Reading/Comparing
1. **Settings (`SettingsScreen` -> `OfflineLibraryDialog`):**
   - User opens **Configurações > Biblioteca Offline (Bíblias e Publicações)**.
   - Tabs: **Bíblias (Traduções)** and **Publicações (EPUB)**.
   - User imports one or more Bible `.epub` / `.json` files (multi-language book detection via canonical `biblechapternav(\d+)\.xhtml` / `bibleversenav(\d+)_` links + multilingual book names in `NwtBibleBooks`).
   - User imports `.epub` publications (`lff_T.epub`, `ll_T.epub`, etc.); `ImportedPublicationsService` parses OPF metadata, small cover thumbnail (`<= 150 KB`), TOC (`toc.ncx` / `toc.xhtml`), and clean chapter paragraphs sharded in `AppKvStore`.
   - If user selects `.jwpub`/`.jwlpub`, service safely inspects unencrypted `manifest.json` (or `%PDF-` header) and surfaces a clear `BibleImportException` / `PublicationImportException` explaining JW Library encryption and guiding to `.epub`/`.json`.
   - User can set a primary Bible, preview a Bible or Publication, or remove an imported item.
2. **References List (`AppReferencePickerDialog`):**
   - Import buttons are removed from `AppReferencePickerDialog` and `BibleVersePopupDialog`.
   - In `AppRefCategory.bible`, available imported Bible translations are visible for selection/preview.
   - New `AppRefCategory.publication` (`📚 Biblioteca — Publicações Importadas`) lists all imported publications and lets the user insert either the publication link (`app://ref/publication/<pubId>`) or a specific chapter/lesson (`app://ref/publication/<pubId>/<chapterIndex>`).
3. **Reading & Comparing (`AppReferenceViewer` -> `BibleVersePopupDialog` / `PublicationReaderDialog`):**
   - Clicking a Bible link opens `BibleVersePopupDialog`:
     - Supports **Single Translation mode** (dropdown/selector chip) and **Compare Versions mode** (`Comparar versões`, inspired by JW Library), showing 1 or more selected translations with cover/icon header, title, language subtitle, verse text, per-translation JW Library text highlights, copy, font size controls, and manual verse override/edit.
   - Clicking a publication link opens `PublicationReaderDialog` with chapter navigation, clean readable paragraphs, copy, and font size controls.

### Journey 2: Email & Knowledge Base PDF Exports
- `KnowledgeAndEmailPdfService` (`lib/reports/knowledge_and_email_pdf_service.dart`):
  - Pure Web-safe + Native-safe PDF generator using `pdf` + `OfficialDocFonts` (`PT Sans` / `PT Serif` TTFs with Type1 fallback in unit tests) + `BinaryFileSaver.saveBytes`.
  - Renders Email PDF, Inbox capture PDF, Single Knowledge Item PDF (Note, Question, Document summary, Resource), and Tab Collection PDFs (Notes, Questions, Documents, Resources, Official Docs index).

---

## 3. Data Flow, Persistence & Trust Boundaries

- **Drift Schema:** Zero schema version bump required (`schemaVersion` stays `8`). Sharded persistence in `AppKvStore`:
  - `bible_nwt_catalog_v1`, `bible_nwt_book_<n>`, `bible_nwt_highlights_v1`, `bible_nwt_manual_v1` (preserved for backward compatibility with existing single-Bible installations & tests).
  - `bible_translations_catalog_v1` (JSON list of `BibleNwtCatalog`), `bible_tr_<id>_book_<n>`, `bible_tr_highlights_<id>`, `bible_compare_selected_ids_v1`.
  - `pub_library_catalog_v1` (JSON list of `ImportedPublicationSummary`), `pub_item_<id>_ch_<idx>`.
- **Sync / Privacy / Copyright Boundary:**
  - `AppKvStore` Bible and publication keys are **local-only** and never queued to `sync_queue` or uploaded to Supabase, avoiding cloud storage bloat and unauthorized distribution of user-imported copyrighted EPUBs.
  - `BackupService` preserves `appKvStore` excluding protected auth/E2EE keys.
  - Zero copyrighted text bundled in repository or tests (tests use minimal synthetic ZIP/EPUB/JSON payloads).
- **Web Safety:** Zero unconditional `dart:io` or `sqlite3` imports; file saving uses `BinaryFileSaver` conditional import; file picking uses `file_picker` bytes API.
- **No silent catches:** All user-facing import and PDF export paths catch, log via `AppLogger`, and display clear feedback in UI.

---

## 4. Affected Files

- `lib/bible/nwt_bible_books.dart`
- `lib/bible/nwt_bible_service.dart`
- `lib/publications/imported_publications_service.dart` (new)
- `lib/references/app_reference.dart`
- `lib/reports/knowledge_and_email_pdf_service.dart` (new)
- `lib/inbox/jw_email_service.dart`
- `lib/ui/widgets/settings/offline_library_dialog.dart` (new)
- `lib/ui/screens/settings_screen.dart`
- `lib/ui/widgets/app_reference_picker_dialog.dart`
- `lib/ui/widgets/publication_reader_dialog.dart` (new)
- `lib/ui/widgets/app_reference_viewer.dart`
- `lib/ui/widgets/bible_verse_popup_dialog.dart`
- `lib/ui/widgets/knowledge_item_reader_dialog.dart`
- `lib/ui/widgets/highlight_text_helper.dart`
- `lib/ui/widgets/knowledge/knowledge_ui_components.dart` (new)
- `lib/ui/screens/inbox_screen.dart`
- `lib/ui/screens/knowledge_base_screen.dart`
- `lib/ui/screens/official_documents_screen.dart`
- Tests:
  - `test/bible/nwt_bible_service_test.dart`
  - `test/publications/imported_publications_service_test.dart` (new)
  - `test/references/app_reference_test.dart`
  - `test/reports/knowledge_and_email_pdf_service_test.dart` (new)
  - `test/ui/widgets/highlight_text_helper_test.dart`
  - `test/ui/bible_multi_translation_and_library_ui_test.dart` (new)
  - `test/ui/knowledge_and_email_pdf_ui_test.dart` (new)

---

## 5. Edge Cases, Failure Modes & Rollback

- **Edge cases:**
  - EPUB in non-Portuguese language (e.g., Spanish/English/French/German/Ticuna): solved by parsing `biblechapternav(\d+)\.xhtml` / `bibleversenav(\d+)_` canonical book numbers in JW EPUBs plus expanded `NwtBibleBooks` aliases (`tca`/`tcn` -> `Ticuna`).
  - Partial/selection Bible translations (missing books/chapters/verses): `_loadImportedChapter` never falls back to `bible_nwt_book_*` for a distinct non-default `translationId`, preventing false verse bleed across translations; `BibleVersePopupDialog` consistently displays *"O versículo selecionado não aparece nesta versão da Bíblia."* per translation card when absent.
  - Legacy single-Bible installation upgrading to multi-translation: automatically detected from `bible_nwt_catalog_v1` / `bible_nwt_book_*` with zero data loss.
  - Large EPUBs (e.g. `lff_T.epub` ~103 MB): images other than compact cover (`<= 150 KB`) are skipped so `AppKvStore` stays compact and fast on Web IndexedDB / iOS SQLite.
  - `.jwpub`/`.jwlpub` or PDF masquerading as `.jwpub`: cleanly detected and rejected with explicit user-friendly explanation.
  - Special characters (Portuguese accents & Ticuna diacritics/glottal `ꞌ`) in PDF: rendered via embedded TTF (`OfficialDocFonts`) with test fallback.
  - Empty tabs when exporting Knowledge Base to PDF: generates an informative empty-state notice or clean snackbar without crashing.
- **Rollback:** Revert feature branch or commits; zero Drift schema migration to unwind, and legacy single-Bible KV keys remain untouched.

---

## 6. Knowledge Base Modern UI Redesign (`KB-UI-2026`)

- **Problem:** Users reported the Knowledge Base list cards, note reading panel, Questions, Documents, and Resources tabs appeared overly flat/dated, with bloated 180px fixed-height Note cards around short notes, plain borders, low-contrast Indigo Bible links on dark surfaces, and single-column rows stretched too wide on PWA/iPad screens.
- **Chosen Design:**
  - Extract cohesive reusable UI widgets into `lib/ui/widgets/knowledge/knowledge_ui_components.dart` (category/status/type visual identity system, modern cards hugging content dynamically with `mainAxisSize: MainAxisSize.min`, category color stripe, elevated reading sheet on wide Note split-view, clickable linked-reference pills dock, interactive empty states, and responsive 2-column grid cards for Questions/Documents/Resources on `>= 900px` viewports while keeping single-column mobile touch ergonomics `>= 48dp`).
  - Boost Dark Mode link contrast in `lib/ui/widgets/highlight_text_helper.dart` (`#A5B4FC` Bible refs, `#5EEAD4` internal app refs, `#93C5FD` web URLs) while preserving exact character offset parity and Sun Mode readability.
  - Preserve 100% of existing test `Key`s, `Semantics` labels, tab labels, `VerticalDivider` split-view invariants, and offline-first behavior.
