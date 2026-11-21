# Impact Assessment & Design: Map Engine Evolution (Phases 2, 3, 4 — Organic Maps Pattern)

**Task ID:** `FA-MAP-ENGINE-PHASES-2-3-4`  
**Date:** 2026-11-21  
**Target Branch:** `feat/map-engine-phases-2-3-4` (based on `origin/master`)

---

## 1. Problem and Desired Outcomes

### Phase 2: Offline Tile Server Performance (`lib/territory/map_engine/offline_tile_server_io.dart`)
- **Current Behavior:** Every PMTiles or MBTiles tile fetch decodes from disk/SQLite from scratch. In MBTiles, a SQLite read-only connection is opened and closed for every single tile, causing file lock cycles and high CPU/IO overhead. MBTiles queries use `(tile_row = ? OR tile_row = ?)` which defeats primary key index optimization on SQLite. HTTP responses lack client-side cache directives.
- **Desired Outcome:** 
  1. Memory LRU tile cache (`LinkedHashMap<String, Uint8List>` with 256 entries capacity) with eviction of least recently accessed tiles.
  2. Read-only SQLite connection reuse (`_mbtilesDatabases`) per MBTiles package, with clean disposal in `stop()` and unregister methods.
  3. Index-friendly query with strict single-row selection (`zoom_level = ? AND tile_column = ? AND tile_row = ? LIMIT 1`), trying standard TMS row first, falling back to XYZ row.
  4. HTTP header `'Cache-Control': 'public, max-age=86400, immutable'` on 200 OK tile responses.

### Phase 3: Offline FTS5 Geocoding for Streets, Communities, and OSM POIs (`lib/territory/geocoding/offline_geocoding_service.dart`)
- **Current Behavior:** `OfflineGeocodingService.searchOffline` searches only the local app DB (`People`, `TerritoryLandmarks`, `TerritorySectors`).
- **Desired Outcome:** Support optional regional offline search databases (conforming to `<region_id>.search.db`), using FTS5 table `osm_places_fts(name, category, subtitle, lat UNINDEXED, lng UNINDEXED, tokenize='unicode61 remove_diacritics 2')`. Resilient query execution, merging, and deduplication with local app data, preserving origin and categories (`street`, `place`, `poi`). Clean SQLite descriptor closing to avoid Windows file locks.

### Phase 4: External 1-Tap Navigation Launcher (`lib/territory/routing/external_navigation_launcher.dart`)
- **Current Behavior:** Navigation routes from map pins open Google Maps search in browser or app. No direct integration with Organic Maps (100% offline OSM routing app) or Apple Maps on iOS.
- **Desired Outcome:** 
  1. Testable `ExternalNavigationLauncher` supporting Organic Maps (`om://map` and `om://route`), Apple Maps (`https://maps.apple.com`), and Google Maps (`https://www.google.com/maps/dir`).
  2. Declare `om` scheme in `ios/Runner/Info.plist` inside `LSApplicationQueriesSchemes`.
  3. Add "Navegar (Mapas externos)" button in contact and landmark map cards opening a `ModalBottomSheet` with Organic Maps, Apple Maps (iOS/macOS), and Google Maps.

---

## 2. Component and Dependency Map

- `lib/territory/map_engine/offline_tile_server_io.dart`:
  - `LinkedHashMap<String, Uint8List> _tileCache`
  - `Map<String, sql.Database> _mbtilesDatabases`
  - LRU methods: `_getCachedTile`, `_putCachedTile`
  - MBTiles TMS/XYZ index queries and `Cache-Control` header.
- `lib/territory/geocoding/offline_geocoding_service.dart`:
  - `LocalResultType` enum extended with `street`, `place`, `poi`.
  - `LocalSearchResult` model supporting `origin`.
  - `searchOffline` supporting `packagesDir` / `searchDatabases` scanning for `*.search.db`.
  - Safe FTS5 query escaping and tokenizing.
  - Graceful degradation when `*.search.db` is missing, damaged, or empty.
- `lib/territory/routing/external_navigation_launcher.dart`:
  - Helper methods: `buildOrganicMapsUri`, `buildAppleMapsUri`, `buildGoogleMapsUri`.
  - Launch methods with fallback: `launchOrganicMaps`, `launchAppleMaps`, `launchGoogleMaps`.
- `ios/Runner/Info.plist`:
  - `LSApplicationQueriesSchemes` includes `om`.
- `lib/ui/screens/contacts_map/contacts_map_canvas.dart` & `contacts_map_screen.dart`:
  - Button "Navegar (Mapas externos)" on selected person card and landmark card.
  - Bottom sheet with options: Organic Maps (offline recommendation), Apple Maps (on iOS/macOS), Google Maps (universal fallback).

---

## 3. Data Flow and Invariants

- Offline-first: No network requirement for tile serving, FTS5 geocoding, or generating navigation intents to Organic Maps.
- Safe resource management: All SQLite connections opened for `.search.db` or MBTiles are cleanly disposed in `finally` blocks or during server `stop()`, avoiding Windows `FileSystemException`.
- Backward compatibility: Existing method signatures and return models remain compatible. No existing tests broken.

---

## 4. Test Plan

1. **Phase 2:**
   - Tile cache hit, eviction when reaching 256 entries.
   - Cache invalidation on package unregister / replace / server stop.
   - MBTiles connection pooling and disposal on `stop()`, ensuring temp DB file can be safely removed on Windows.
   - MBTiles TMS query with XYZ fallback.
   - Response header `Cache-Control` verification.
2. **Phase 3:**
   - Temporary SQLite FTS5 database creation with accent/diacritic sample entries (ruas, comunidades, POIs, Portuguese/Ticuna accents).
   - Search with accents and without accents matching correctly.
   - Merging and deduplication with app database records.
   - Missing or corrupted `.search.db` graceful degradation.
3. **Phase 4:**
   - URI encoding verification (special characters, accents, spaces).
   - Origin coordinate handling in Organic Maps (`om://route?sll=...&dll=...`).
   - Fallback execution when target app cannot be launched.
4. **Regression:**
   - `flutter test test/territory/`
   - `dart analyze lib test`
