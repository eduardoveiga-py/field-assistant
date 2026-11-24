# Impact Assessment & Design: Email Contacts Tags Hardening & Biometric PIN Test Flake Fix

**Task ID**: `FA-EMAIL-CONTACTS-TAGS-AND-CI-FIX`  
**Date**: 2026-11-24  
**Branch**: `feat/email-contacts-tags` (PR #52)  
**Standard**: Field Assistant Engineering Standard (FAES)

---

## 1. Problem and Desired Outcome

1. **Blocking CI Failure on PR #52 (`Flutter Analyze, Format & Test` run `45484214207`)**:
   - `test/core/biometric_auth_service_test.dart` failed at line 63–65 (`setPin() persiste hash e salt seguros e desbloqueia a sessão`):
     - Expected: `not contains '2580'`
     - Actual: `'2580750163639e572643f77e94ed9bc332e12c312c3bcead26caa08b151f8073'`
   - **Root cause (FACT)**: `BiometricAuthService.setPin('2580')` derives a salted 256-bit PBKDF2-HMAC-SHA256 digest encoded as 64 lowercase hex characters (`[0-9a-f]{64}`). Because `'2580'` is itself a valid 4-character hex substring, any pseudorandom 64-hex digest contains `'2580'` with probability $1 - (1 - 1/65536)^{61} \approx 0.093\%$ (~1 in 1,074 runs). In run `45484214207`, the digest happened to begin with `2580`, causing a false-positive test failure.
   - **Desired outcome**: Replace the mathematically flaky substring negation with deterministic cryptographic assertions verifying `pbkdf2_hmac_sha256:100000` KDF metadata, valid 32-hex salt and 64-hex digest format, inequality with plaintext `'2580'` and legacy single-round SHA-256, unique salt/hash regeneration on re-set, and valid `verifyPin('2580')`.

2. **PR #52 (`feat/email-contacts-tags`) Quality & Completeness Gaps**:
   - **Missing tests**: PR #52 modified `lib/inbox/email_contacts_manager.dart` and `lib/ui/screens/email_contacts_screen.dart` without adding any unit or widget tests for `tags`, `extractAllTags`, tag filtering, or dialog tag management.
   - **Accent-sensitive tag search**: `_EmailContactsScreenState._applyFilter()` normalized contact names and emails (`_normalize(...)`) but searched tags using `t.toLowerCase().contains(rawQ)`, so typing `'familia'` failed to match `'Família'` and `'congregacao'` failed to match `'Congregação'`.
   - **Tag deduplication & sorting**: `EmailContact.fromJson` and `EmailContactsManager.saveContact` did not deduplicate tags, and `extractAllTags` used case-sensitive `.sort()`.
   - **Dialog edge cases & error resilience**:
     - Typing a new tag in `Nova etiqueta` and tapping `Salvar` without first tapping `+` silently discarded the typed tag.
     - Adding a case-variant of an existing tag (e.g. `'família'` vs `'Família'`) created near-duplicate chips.
     - `_AddOrEditContactDialog` did not catch exceptions in `onSave`, which would leave `_isSaving = true` permanently.
     - `_EmailContactsScreenState._loadContacts` had no `try/catch/finally`, leaving `_isLoading = true` if a DB read failed.
     - Interactive tag chips and custom tag inputs lacked deterministic `Key`s for reliable widget testing.

---

## 2. Current Behavior and Evidence

- **PR #52 CI Checks (`gh pr checks 52`)**:
  - `Flutter Analyze, Format & Test`: **fail** (`Run Automated Tests`, `test/core/biometric_auth_service_test.dart:63`).
  - `Independent Flutter validation` (`Flutter tests (all)`, `Flutter tests (maps)`, `Dart diagnostics`, `Windows compilation check`, `iOS compilation check`): **pass**.
  - `SQL Isolation, RLS & E2EE CAS (PGlite)`, `Check Version Consistency`, `Lint GitHub Actions Workflows`, `CodeQL`, `Secret Pattern Audit & SBOM Generation`: **pass**.
- **Code Inspection**:
  - `lib/inbox/email_contacts_manager.dart`: `EmailContact.tags`, `saveContact`, `updateContact`, `extractAllTags`.
  - `lib/ui/screens/email_contacts_screen.dart`: `_selectedTag`, `_applyFilter`, horizontal `FilterChip` bar, `_AddOrEditContactDialog` tag chips & custom tag input.
  - Callers checked via `git grep`: `lib/ui/screens/inbox_screen.dart`, `lib/ui/screens/settings/settings_integration_cards.dart`, `lib/inbox/email_sync_coordinator.dart`, `lib/inbox/exchange_service.dart`, `lib/inbox/jw_email_service.dart`. All existing callers omit `tags` or rely on optional `tags` parameter, remaining backward compatible.

---

## 3. User Journey & Component Map

1. **User opens Email Contacts (`InboxScreen` -> `btn_email_contacts` -> `EmailContactsScreen`)**:
   - Loads saved contacts (`app_kv_store` key `'email_contacts_registry'`) merged with email addresses extracted from `people`.
   - Sees horizontal tag filter chips (`Todas` + unique tags from loaded contacts) whenever at least one contact has tags.
   - Types in search field (name, email, or tag — accent/case-insensitive) and/or selects a tag chip to filter the contact list.
   - Taps Add (`btn_add_contact`) or Edit (`btn_edit_contact_<email>`) to select preset/existing tags or add custom tags (`Nova etiqueta`) and save.
   - All data stays 100% offline-first in local Drift SQLite (`app_kv_store`).

---

## 4. Data Flow, Trust Boundaries & Compatibility

- **Persistence**: Tags are stored as `List<String>` in JSON inside `AppKvStore` (`email_contacts_registry`).
- **Backward Compatibility**: `EmailContact.fromJson` defaults missing/null `tags` to `const []`. Existing records without `tags` deserialize cleanly; `recordSender` and `sent_recipient` calls omit `tags` (`null`), preserving any existing tags on that contact.
- **No Drift Schema Migration Required**: Uses existing `app_kv_store` JSON registry.
- **No PII in Logs**: Only error classes/messages logged via `AppLogger.warning`; PIN test assertions avoid leaking or relying on raw substring absence in random digests.

---

## 5. Edge Cases & Failure Modes

1. **Random digest substring collision in `biometric_auth_service_test.dart`**: Eliminated by validating KDF identifier, hex regex format, inequality with plaintext/legacy hash, distinct per-call random salt/hash, and `verifyPin` roundtrip.
2. **Accent-insensitive tag search**: Searching `'familia'` matches `'Família'`; `'anciaos'` matches `'Anciãos'`.
3. **Pending custom tag on Save**: If user types a custom tag and taps `Salvar` without pressing `+`, commit the tag automatically.
4. **Case-variant duplicate tags**: Selecting/adding `'família'` reuses canonical `'Família'` if already available.
5. **Async failure in `_loadContacts` / `onSave`**: Caught, logged via `AppLogger.warning`, loading/saving flags reset, and clear feedback shown to user.
6. **Filtered empty state**: Distinguishes "no contacts saved at all" from "no contacts match current search/tag filters" with a clear reset filter button.

---

## 6. Test Plan & Rollback

- **Unit Tests (`test/inbox/email_features_extended_test.dart`)**:
  - `EmailContact` JSON serialization with/without `tags` and deduplication.
  - `saveContact` / `recordSender` tag preservation and explicit update.
  - `updateContact` tag preservation on email rename and explicit update/clear.
  - `extractAllTags` uniqueness, trimming, and alphabetical ordering.
  - `getAllSuggestions` query matching on tags.
- **Widget Tests (`test/ui/screens/email_contacts_screen_test.dart`)**:
  - Tag chips display and filter bar rendering.
  - Tag chip selection/deselection and `Todas` reset.
  - Accent-insensitive search matching tags and combined tag + text filtering.
  - Adding contact with preset and custom tags (both via `+` button and directly on Save).
  - Editing contact tags (adding/removing) and error recovery when `onSave` fails.
- **Security Test (`test/core/biometric_auth_service_test.dart`)**:
  - Deterministic PBKDF2 hash/salt/KDF validation without random digest substring flake.
- **Pre-push Gate**:
  - `.\tool\pre_push.ps1` (`dart format --output=none --set-exit-if-changed lib test integration_test` + `flutter analyze`).
  - Targeted tests + full `flutter test` verification.
- **Rollback**: Changes are isolated to branch `feat/email-contacts-tags` (no DB schema migration, no destructive data change). Reverting commits on this branch restores prior state cleanly.
