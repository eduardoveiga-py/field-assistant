# Impact Assessment: Inbox Sync Errors, Folder Selector, and Map GPS Centering

**Task ID**: `FA-INBOX-SYNC-FOLDERS-AND-MAP-GPS-CENTER`  
**Date**: 2026-11-22  
**Target Branch**: `fix/inbox-sync-errors-folders-and-map-gps-center`  
**Standard**: Field Assistant Engineering Standard (FAES)  

---

## 1. Problem and Desired Outcome
1. **Inbox Sync Errors**: Currently, in `lib/ui/screens/inbox_screen.dart`, when email account synchronization fails (e.g. missing password, bad credentials, HTTP 401 auth issues), exceptions are swallowed into log warnings, and a green success SnackBar is presented even when 0 accounts or 0 messages synced. The desired outcome is accurate error tracking via `failedDetails`, actionable error messages (including hints for Gmail App Passwords and Hotmail/Outlook OAuth2/Modern Auth), proper SnackBar feedback (error SnackBar on total failure, warning SnackBar on partial failure), and clear informational messaging on Flutter Web (`kIsWeb`).
2. **Dedicated Folder Selector**: Email folder filtering is currently mixed into the same row as the unread filter, missing the Spam folder, and disappears when no emails are present. Furthermore, Caixa de Entrada fails to exclude spam messages. The desired outcome is a dedicated, always-visible horizontal folder selector bar (`Caixa de Entrada`, `Enviadas`, `Rascunhos`, `Spam`, `Lixeira`, `Todas as pastas`) with deterministic keys, proper icon affordances, and strict folder isolation logic.
3. **Map Initial GPS Centering**: `lib/ui/screens/contacts_map_screen.dart` currently defaults initial camera coordinates to Santo Antônio do Içá (`GeolocationHelper.defaultLat` / `defaultLng`) without consulting previous user GPS coordinates or fetching the live device location on screen open. The desired outcome is caching the last known GPS coordinates in `appKvStore` (`last_known_user_lat`, `last_known_user_lng`), restoring cached coordinates on screen open if available, asynchronously fetching live GPS via `GeolocationHelper.getCurrentLocation()` when `widget.highlightPersonId == null`, and updating the camera and cache seamlessly.

---

## 2. Current Behavior and Evidence
- **Sync Failure Silencing**: In `lib/ui/screens/inbox_screen.dart:152, 173`, if `pass == null || pass.isEmpty`, the account is silently skipped without any notice. In lines 186-188, `catch (e)` logs to `AppLogger.warning` without collecting errors. Lines 198-206 display a green success SnackBar even if 0 accounts succeeded.
- **Folder Filtering Defects**: In lines 2133-2176, `'Spam'` does not exist in `standardFolders`. In `'Caixa de Entrada'`, filter check only filters `enviad`, `sent`, `lixeir`, `trash`, `delet`, `rascunh`, `draft`, allowing spam/junk emails into the inbox. Chips lack deterministic keys and disappear if `emails.isEmpty`.
- **Map Camera Behavior**: In `lib/ui/screens/contacts_map_screen.dart:143-144, 174-215`, camera initialization defaults to `GeolocationHelper.defaultLat` / `defaultLng`. It never queries `appKvStore` on `initState` and does not query device GPS on screen entry. In `contacts_map_canvas.dart:218-219`, `centerPx` and `centerPy` are computed against `centerLng` instead of `effectiveCenterLng`.

---

## 3. User Journey
1. **User with multiple email accounts**:
   - Taps "Sincronizar Agora".
   - If an account has an empty password or bad credentials, a clear SnackBar explains which account failed and why (e.g., advising a 16-digit App Password for Gmail).
   - If all accounts fail, an error SnackBar appears (never a misleading success).
2. **User browsing email folders**:
   - Sees a dedicated row of folder chips: Caixa de Entrada, Enviadas, Rascunhos, Spam, Lixeira.
   - Tapping "Spam" shows only junk/spam emails.
   - Tapping "Caixa de Entrada" shows only inbox emails, strictly excluding drafts, sent, trash, and spam.
   - Toggling "Não lidos" filters unread emails within the active folder without resetting the folder.
3. **User opening Contacts Map**:
   - Opens the map screen to view territories/contacts.
   - Map immediately centers on the user's last known location from `appKvStore` (if previously acquired), or default coordinates.
   - Asynchronously, the device GPS updates camera position to the live location and saves coordinates in `appKvStore`.
   - If opening a specific contact via `highlightPersonId`, the map focuses on that contact, without GPS interference.

---

## 4. Component & Dependency Map
- `InboxScreen` (`lib/ui/screens/inbox_screen.dart`)
  - `EmailAccountsManager` & `FlutterSecureStorage`
  - `JwEmailService` & `ExchangeReadService`
  - `SupabaseSyncService`
- `ContactsMapScreen` (`lib/ui/screens/contacts_map_screen.dart`)
  - `AppDatabase` (`appKvStore`)
  - `GeolocationHelper` (`getCurrentLocation()`, `getCurrentLocationWithStatus()`, `locationOverride`)
  - `MapEngineAdapter` (`moveCamera()`)
  - `_ContactsMapCanvas` (`lib/ui/screens/contacts_map/contacts_map_canvas.dart`)

---

## 5. Data Flow and Trust Boundaries
- **Email Credentials**: Passwords remain protected inside `FlutterSecureStorage`. No passwords or sensitive tokens are included in SnackBar messages or logs.
- **GPS Coordinates**: Stored locally in `appKvStore` in Drift SQLite. Validated for finite double and bounds: latitude in [-90, 90], longitude in [-180, 180], not 0,0.
- **Offline Integrity**: All operations operate offline-first. IMAP/Exchange sync runs when network is present; cached emails and coordinates remain accessible offline.

---

## 6. Affected Files
- `lib/ui/screens/inbox_screen.dart` (R2 & R3)
- `lib/ui/screens/contacts_map_screen.dart` (R4)
- `lib/ui/screens/contacts_map/contacts_map_canvas.dart` (R4)
- `test/ui/screens/inbox_screen_test.dart` (R5 - new test suite)
- `test/ui/screens/contacts_map_screen_test.dart` (R5 - new test suite)

---

## 7. Edge Cases & Failure Modes
- **No Internet / Network Error**: Friendly message: "Falha de conexão. Servidor inacessível ou rede indisponível."
- **Authentication 401**: Differentiates Gmail (App Password hint) and Hotmail/Outlook (Modern Auth / OAuth2 hint).
- **Web Browser (`kIsWeb`)**: Informs that raw TCP sockets are unsupported in browsers and sync occurs via Supabase.
- **Empty Cache & No GPS Hardware**: Gracefully falls back to Santo Antônio do Içá (`GeolocationHelper.defaultLat`, `defaultLng`).
- **Contact Highlighted (`highlightPersonId != null`)**: Bypasses GPS centering and camera override to protect the contact inspection workflow.
- **Corrupt Cache Coordinates**: Validates parse, finiteness, and coordinate ranges before setting camera.

---

## 8. Test Plan
- Unit tests in `test/ui/screens/inbox_screen_test.dart`:
  - Sync failure when password missing produces error SnackBar.
  - Gmail auth error produces App Password guidance.
  - Hotmail auth error produces Modern Auth guidance.
  - Partial sync produces warning SnackBar.
  - All accounts fail produces error SnackBar (never green).
  - Folder filtering for Caixa de Entrada, Enviadas, Rascunhos, Spam, Lixeira.
  - Orthogonality between folder filter, unread filter, and search.
- Unit tests in `test/ui/screens/contacts_map_screen_test.dart`:
  - Map opens at default coordinates when cache and GPS are empty.
  - Map centers on cached coordinates from `appKvStore`.
  - Map fetches live GPS asynchronously and updates camera and `appKvStore`.
  - Highlighted person overrides GPS centering.
- Regression tests:
  - `test/layout_fixes_and_map_highlight_test.dart`
  - `test/territory/map_navigation_regression_test.dart`
- Pre-push validation:
  - `powershell -ExecutionPolicy Bypass -File .\tool\pre_push.ps1`

---

## 9. Rollback & Recovery Plan
- All changes are contained within the dedicated branch `fix/inbox-sync-errors-folders-and-map-gps-center`.
- In case of critical regression, branch can be cleanly reset to `master` (`528cdbd`).
- SQLite data in `appKvStore` uses benign key-value entries that do not affect relational foreign keys or table schemas.
