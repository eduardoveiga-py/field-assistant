# Impact Assessment & Design — FAES Round 2 (MapLibre Activation, AVAudioSession, Modularization, Accessibility & iPadOS)

- **Task ID:** `FA-ROUND2-MAPLIBRE-AUDIO-UX-MODULARIZATION`
- **Date:** 2026-11-18
- **Branch:** `master`
- **Standard:** Field Assistant Engineering Standard (FAES)

---

## 1. Problem & Desired Outcome

Following Round 1 (`40a5828`, `b1afbf6`, `3fe3e20`), core security, sync, SQL migration, PMTiles v3, loopback tile/asset serving, and `MapLibreVectorMapView` foundations are in place. However, five code-fixable gaps remain open in `MASTER_REAUDIT.md`:

1. **`P0-02` (MapLibre Native Production Wiring):** `ContactsMapScreen` unconditionally instantiates `RasterFallbackAdapter()` when `widget.mapEngineAdapter == null` and omits `packageId`, `packageFormat`, and `sectors` when building `MapLibreVectorMapView`. `DownloadMapsScreen` / `MBTilesService` do not yet support local `.pmtiles` vector package import/discovery.
2. **`P1-08` (Audio Interruption Handling):** `RealAudioRecordingService` lacks explicit `audio_session` (`AVAudioSession`) configuration and `interruptionEventStream` / `becomingNoisyEventStream` handling to safeguard recordings during phone calls, alarms, Siri, or Bluetooth/headset disconnects.
3. **`P2-03` (Monolithic Screens):** The 5 largest screens remain monoliths (`person_detail_screen.dart` 7,636L, `appointments_screen.dart` 4,842L, `contacts_map_screen.dart` 4,485L, `settings_screen.dart` 3,859L, `studies_screen.dart` 3,434L).
4. **`P2-02` (Accessibility):** Only 5 `Semantics` widgets exist across `lib/`, leaving VoiceOver/TalkBack navigation, headers, map controls, and audio recorder state under-described.
5. **`P2-01` (iPadOS Adaptive Master-Detail):** Only 2 of 26 screens (`people_screen.dart`, `appointments_screen.dart`) adapt to iPad wide viewports (`>= 900px`). `studies_screen.dart`, `knowledge_base_screen.dart`, and `inbox_screen.dart` stretch phone layouts.

**Desired Outcome:** Close all code-fixable P0/P1/P2 gaps incrementally with zero data loss, zero feature regressions, full `dart format` + `dart analyze --fatal-warnings` hygiene, and real automated test coverage for each workstream — leaving only genuinely external gates (physical Apple hardware, live Supabase staging, root license decision).

---

## 2. Current Behavior & Dependency Map

- **Map Stack:** `ContactsMapScreen` -> `MapEngineAdapter` (`RasterFallbackAdapter` | `MaplibreNativeAdapter`) -> `MapLibreVectorMapView` (`package:maplibre_gl`) + `OfflineTileServer` + `MapAssetManager` + `MBTilesService` + `SectorManager` (`sectorsStreamProvider`).
- **Voice Notes Stack:** `QuickVoiceNoteDialog` -> `AudioRecordingService` (`RealAudioRecordingService` / `LocalAudioRecordingService`) + `AudioPlayerService` (`RealAudioPlayerService` / `LocalAudioPlayerService`) -> `VoiceNotesManager` -> Drift DB + encrypted media sync.
- **Navigation & Adaptive UI:** `MainNavigationShell` -> `PeopleScreen`, `AppointmentsScreen`, `StudiesScreen`, `KnowledgeBaseScreen`, `InboxScreen`, `ContactsMapScreen`, `SettingsScreen`, `PersonDetailScreen`.

---

## 3. Research & Dependency Verification

- **`audio_session: ^0.2.4`** (pub.dev, author Ryan Heise)
  - **License:** MIT License (compatible with commercial/private distribution; requires license attribution in Flutter `LicenseRegistry`, handled automatically by Flutter).
  - **Platforms:** iOS (`AVAudioSession`), Android (`AudioManager`), macOS, Web.
  - **Why chosen over custom MethodChannel:** Maintained official community standard used across the Flutter audio ecosystem (`just_audio`, `audio_service`), provides typed `AudioInterruptionEvent`, `becomingNoisyEventStream`, and iOS `AVAudioSessionCategory.playAndRecord` options without maintaining custom Objective-C/Swift/Kotlin audio focus plumbing.

---

## 4. Design & Ownership Boundaries

### 4.1 MapLibre Production Activation
- Add `MapEngineSelector` (`lib/territory/map_engine/map_engine_selector.dart`) defining `MapEnginePreference { auto, vectorMapLibre, rasterFallback }` and `ActiveVectorPackage`.
- Extend `MBTilesService` / `MBTilesBackend` / `MBTilesNative` / `MBTilesWeb` to detect installed vector packages (`.pmtiles` and vector `.mbtiles`), expose managed packages directory, and allow local `.pmtiles` import validated via `PmtilesReader.readHeader()`.
- In `ContactsMapScreen`:
  - Select `MaplibreNativeAdapter` automatically on supported platforms (`MapLibreVectorMapView.isSupportedOnCurrentPlatform`) when a vector package is installed or when the user selects Vector mode; fall back safely to `RasterFallbackAdapter` on desktop/tests or when raster-only packages are active in `auto` mode.
  - Pass `packageId`, `packageFormat`, and `sectors` into `MapLibreVectorMapView`.
  - Expose engine switcher & active vector package status in the Map Layers modal.

### 4.2 Audio Interruption Handling (`AVAudioSession`)
- Add `AudioSessionBridge` (`lib/voice_notes/audio_session_bridge.dart`) with `PlatformAudioSessionBridge` (wrapping `package:audio_session`) and `AudioSessionInterruption` model.
- Inject optional `AudioRecorder?` and `AudioSessionBridge?` into `RealAudioRecordingService` (defaulting to real implementations).
- Configure `AVAudioSessionCategory.playAndRecord` with `allowBluetooth | defaultToSpeaker` when starting a recording; listen to `interruptionEvents` and `becomingNoisyEvents`.
- On interruption begin (phone call, alarm, Siri): finalize and preserve the recorded file safely via `stopRecording()` (never deleting captured audio bytes) and emit an `AudioInterruptionNotice` event for UI feedback.
- On `RealAudioPlayerService`: pause safely on interruption begin or becoming noisy.

### 4.3 Monolithic Screen Decomposition
Extract cohesive, self-contained widget/dialog/modal modules while preserving 100% of public class names, routes, and re-exports:
- `lib/ui/widgets/person_detail/` (unified timeline section, study dialogs, visit/person dialogs, summary/timeline widgets)
- `lib/ui/widgets/calendar_views/` (monthly schedule copy wizard, calendar sync & ICS dialogs, appointment action modals)
- `lib/ui/widgets/map/` (layer/engine sheet, territory coverage/duplicate analysis modals, landmark/import modals, map pin/scale widgets)
- `lib/ui/widgets/settings/` (`SyncQueueManagementSheet`, backup/PIN dialogs, integration/config cards)
- `lib/ui/widgets/studies/` (study dialogs, priority/progress view, iPad study detail pane)

### 4.4 Accessibility (`Semantics`) & iPadOS Master-Detail
- Add semantic headers, labels, hints, button/selected roles, and live regions to primary navigation, map controls, person detail, appointments, studies, voice recorder, and settings.
- Add `LayoutBuilder` (`>= 900px`) Master-Detail split-view to `StudiesScreen`, `KnowledgeBaseScreen`, and `InboxScreen` matching `PeopleScreen` & `AppointmentsScreen` conventions.

---

## 5. Edge Cases, Failure Modes & Rollback

- **Desktop / Headless Test Safety:** `MapLibreVectorMapView.isSupportedOnCurrentPlatform` stays `false` on Windows/macOS/Linux; `PlatformAudioSessionBridge` gracefully catches `MissingPluginException` in unit/widget tests without platform channels.
- **No Data Loss:** Audio interruption ALWAYS preserves already-recorded audio (calls `stopRecording()`, never `cancelRecording()`). Screen decompositions preserve all Drift writes, sync outbox calls, and user data untouched.
- **Rollback:** Atomic commits per workstream on `master`; any workstream can be reverted cleanly with `git revert <sha>` with zero schema or storage migrations.

---

## 6. Test Plan

1. `test/territory/map_engine/map_engine_selector_test.dart`: platform/package auto-selection, manual override, `.pmtiles` import validation, `ContactsMapScreen` wiring (`packageId`, `packageFormat`, `sectors`).
2. `test/voice_notes/audio_interruption_test.dart`: `AVAudioSession` interruption begin/end, becoming noisy, non-empty file preservation, idempotent stop, player pause on interruption.
3. `test/ui/accessibility_semantics_test.dart`: `Semantics` verification across navigation, map controls, voice recorder, studies, settings.
4. `test/ui/ipad_adaptive_master_detail_test.dart`: wide (`1024x768`) vs mobile (`390x844`) layout tests for `StudiesScreen`, `KnowledgeBaseScreen`, `InboxScreen`.
5. Full regression run: existing territory, voice notes, UI, sync/crypto, database, and E2E tests + `dart format` + `dart analyze --fatal-warnings`.
