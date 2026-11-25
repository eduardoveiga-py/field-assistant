# Impact Assessment & Design — Correção do Importador TNM EPUB, Referências/WYSIWYG em Estudantes e Revisitas, e Auditoria de Catálogos Oficiais

- **Task ID:** `FA-NWT-EPUB-STUDENT-REFS-CATALOGS`
- **Branch:** `fix/nwt-epub-student-refs-and-catalogs`
- **Base:** `master` (`6ef30c6`)
- **Compliance:** `AGENTS.md`, `.agents/rules/field-assistant-ci-gate.md`, `.agents/skills/field-assistant-engineering-standard/SKILL.md`

---

## 1. Problem Statement & Scope

Three user-reported gaps and enhancements on `master` (`6ef30c6`):

1. **TNM Bible EPUB Import (`lib/bible/nwt_bible_books.dart`, `lib/bible/nwt_bible_service.dart`):**
   - **Observed bug:** After importing an official Portuguese New World Translation EPUB (`nwt_T.epub`), opening Bible cross-references such as **Apocalipse 1:1** shows `"Passagem \"Apocalipse 1:1\" não localizada no arquivo TNM importado."` even though `hasImportedBible == true`.
   - **Verified root causes in `nwt_T.epub` structure:**
     1. Verse 1 of 1,183 multi-chapter chapters uses an empty anchor `<span id="chapterX_verse1"></span><span class="w_ch"><strong>X</strong> </span>...` without `<sup>1</sup>`. `_parseParagraphMarkerVerses` only looked for `sup` / `versenum` / `vl` / `v\d{6,9}`, dropping verse 1 of multi-chapter chapters (including Apocalipse 1:1 and Gênesis 1:1), while `w_ch` contains the *chapter* number (`8` in João 8:12 where `<span id="chapter8_verse12"></span><span class="w_ch"><strong>8</strong> </span><strong><sup>12</sup></strong>` starts mid-chapter).
     2. Verse-continuation paragraphs (`<p class="pN sb">`, poetic `<p class="pN sl">`, `<p class="pN sz">`) were discarded because `_parseParagraphMarkerVerses` reset `int? currentVerse = null` at the start of every `<p>`.
     3. All 5 single-chapter books (`Obadias`, `Filêmon`, `2 João`, `3 João`, `Judas`) omit a trailing chapter digit in `<title>`/`<h1>`/filename, yielding `detectedChapter == null` and skipping the chapter.
     4. Chapters `Salmo 2`..`Salmo 150` use singular `<title>Salmo N</title>` without `<h1>`; `NwtBibleBooks` `Salmos` aliases lacked `'salmo'`.
     5. Ephemeral/non-Bible files (`*-extracted*.xhtml` [1,341], `bible*nav*.xhtml` [1,251], `toc`/`cover`/`pagenav`) and non-verse blocks (`header`, `groupFootnote`, `aside[epub:type="footnote"]`, `a[epub:type="noteref"]`, `.pageNum`, `.w_navigation`, `.w_biblebookname`, `.docNav`, `.contextTtl`, `.ss`, `.st`, `.sd`, `.sw`) were parsed unnecessarily or risked polluting trailing verses.
   - **Desired outcome:** Import 66/66 books, 1,189/1,189 chapters, and all verses (including verse 1, continuation/poetry paragraphs, single-chapter books, Salmos 1–150, and mid-chapter starts like João 8:12) cleanly and fast on Web/Windows/iOS while preserving backward compatibility with simpler EPUB fixtures and zero embedded copyrighted text.

2. **App Cross-References (`app://ref/...`) & Zero-Regression WYSIWYG Formatting in Student / Interested / Return Visit / Field Notes:**
   - **User requirement & invariant:** Enable inserting app cross-references (`📖` Bible TNM + `🔖` internal tabs/notes/questions/documents/resources/pictures/tasks/studies/people) across student, interested person, return visit, study session, phone contact, field activity, and territory landmark notes, while strictly preserving PR #55's zero-raw-syntax WYSIWYG editing/viewing standard (`RichFormattedEditingController` + `RichMarkdownToolbar` + `MarkdownPreviewText`) and existing isolation boundaries:
     - Student / Person photo pickers remain untouched (device-only, NO Picture Bank inside person avatar/photo pickers).
     - JW Library colored highlight underline controls (`enableHighlightPalette` / `allowHighlights`) and direct toolbar image-uploader (`enableImagePicker`) remain disabled/excluded on Student/Person/Study/Visit/Contact flows (`enableHighlightPalette: false`, `enableImagePicker: false`, `allowHighlights: false`), while full clean formatting (bold, italic, underline, headings, quotes, lists, links, code) and universal cross-references (`enableCrossReferences: true`) work with zero visible `**`, `###`, `<u...>`, or `(app://...)`.
     - Display widgets (`person_study_and_notes_tabs.dart`, `study_detail_pane.dart`, `doorstep_briefing_card.dart`, `person_unified_timeline_section.dart`, `contacts_map_canvas.dart`, `activities_screen.dart`, `people_screen.dart`, `person_visits_tab.dart`, `global_search_screen.dart`) render clean preview / clickable references via `MarkdownPreviewText` without breaking existing JSON note arrays (`DoorstepBriefingHelper.parseNotes`).
     - External share/export text (`PersonHandOffDialog` / `PersonHandOffHelper` WhatsApp, `ReportExportService` PDF/CSV, `TerritoryModals._shareLandmark`, `GlobalSearchScreen` snippets) strips internal `(app://...)` and raw Markdown via `EmailHtmlSanitizer.stripMarkdown` and `DoorstepBriefingHelper.extractPlainNotesSummary` (decoding JSON note arrays when present).

3. **Official Publication Catalogs Audit (`lib/publications/lff_book_catalog.dart`):**
   - **Verification against user's official files (`lff_T.epub`, `lffi_T.rtf.zip`, `ll_T.epub`):**
     - `LffBookCatalog` (60 lessons): all **60/60 lessons** and their numbered subtopics (`pointTitles`) match `lff_T.epub` 100%, **EXCEPT** `LffBookCatalog.endnotes` ("Entenda Melhor", 7 entries), which incorrectly contained titles from the older *Entenda a Bíblia* book instead of the official `lff_T.epub` "Entenda Melhor" endnotes (`1. Quem é Babilônia, a Grande?` ... `7. Assuntos comerciais e jurídicos`).
     - `LffiBrochureCatalog` (brochure *Seja Feliz para Sempre!*, 3 lessons): currently **unreliable** on subtopics — uses 3 paraphrased points per lesson instead of the real 6, 5, and 6 numbered subtopics verified in `lffi_T.rtf.zip` (`lffi_T_03.rtf`, `lffi_T_04.rtf`, `lffi_T_05.rtf`). Also unused in Study logging/progress pickers when `publicationId == 'lff-brochure'`.
     - `ListenToGodCatalog` (*Escute a Deus e Viva para Sempre*, `ll-T`, 14 lessons): currently **unreliable** — all 14 titles are paraphrased rather than the exact Portuguese titles in `ll_T.epub`, subtopic Bible-point headings (`pointTitles`) are missing, and paragraph counts do not match `<div class="bodyTxt">` paragraphs in `ll_T.epub`.
   - **Desired outcome:** Update `LffBookCatalog.endnotes`, `LffiBrochureCatalog`, and `ListenToGodCatalog` with exact official structural indices (lesson numbers, official lesson titles, subtopic headings) without adding copyrighted body prose, and connect brochure/LL lesson-subtopic indices cleanly into study logging/progress UI where `publicationId` is `'lff-brochure'` or `'ll-brochure'`.

---

## 2. Affected Files

- Bible EPUB:
  - `lib/bible/nwt_bible_books.dart`
  - `lib/bible/nwt_bible_service.dart`
  - `test/bible/nwt_bible_service_test.dart`
- Cross-References & WYSIWYG Formatting:
  - `lib/ui/widgets/rich_markdown_toolbar.dart` (`enableImagePicker`, `btn_toolbar_insert_bible`, `RichMarkdownToolbar.pickAndInsertReference` helper for compact single-line fields)
  - `lib/contacts/doorstep_briefing_helper.dart` (`extractPlainNotesSummary`)
  - `lib/ui/widgets/doorstep_briefing_card.dart`
  - `lib/ui/widgets/person_detail/person_unified_timeline_section.dart`
  - `lib/ui/widgets/add_person_dialog.dart`
  - `lib/ui/widgets/person_hand_off_dialog.dart` & `lib/contacts/person_hand_off_helper.dart`
  - `lib/ui/screens/person_detail_screen.dart` & `lib/ui/screens/person_detail/person_visit_and_profile_dialogs.dart`
  - `lib/ui/screens/person_detail/person_study_and_notes_tabs.dart`
  - `lib/ui/screens/person_detail/person_study_dialogs.dart`
  - `lib/ui/screens/studies/study_dialogs.dart`
  - `lib/ui/widgets/studies/study_detail_pane.dart`
  - `lib/ui/screens/phone_contacts_screen.dart`
  - `lib/ui/screens/today_screen.dart`
  - `lib/ui/screens/activities_screen.dart`
  - `lib/ui/screens/people_screen.dart`
  - `lib/ui/screens/person_detail/person_visits_tab.dart`
  - `lib/ui/screens/global_search_screen.dart`
  - `lib/ui/screens/contacts_map_screen.dart`, `lib/ui/screens/contacts_map/territory_modals.dart`, & `lib/ui/screens/contacts_map/contacts_map_canvas.dart`
  - `lib/reports/report_export_service.dart`
- Publication Catalogs:
  - `lib/publications/lff_book_catalog.dart` (`LffBookCatalog.endnotes`, `LffiBrochureCatalog`, `ListenToGodLessonInfo`, `ListenToGodCatalog`, `StudyPublicationIndexHelper`)
  - `lib/ui/screens/studies_screen.dart`, `lib/ui/screens/studies/study_dialogs.dart`, `lib/ui/screens/person_detail/person_study_dialogs.dart`, `lib/ui/screens/person_detail/person_study_and_notes_tabs.dart` (wire `StudyPublicationIndexHelper` consistently across `lff-book`, `lff-brochure`, and `ll-brochure`)
  - `test/lff_and_priority_test.dart`
- New Regression Tests:
  - `test/ui/student_cross_references_and_wysiwyg_test.dart`

---

## 3. Data Integrity, Security, Offline-First & Rollback

- Zero Drift SQLite schema changes; all formatted notes remain stored in existing text/JSON columns (`generalNotes`, `notes`, `sessionNotes`, `nextStep`, `topicsDiscussed`, `nextTopic`), preserving sync queue, Supabase E2EE boundary (`ENABLE_E2EE_SYNC` remains `defaultValue: false`), backup/restore, and JSON note compatibility.
- Zero copyrighted text bundled in git (`nwt_T.epub`, `lff_T.epub`, `lffi_T.rtf.zip`, `ll_T.epub` remain external local user verification inputs only; unit tests use synthetic minimal XHTML fixtures).
- Rollback: revert PR commit on `master` or reset branch before merge; no persistent DB migration to unwind.
