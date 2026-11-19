# IMPACT ASSESSMENT: E2E Tiers 2-4, Pure-Dart A* Offline Routing, PMTiles Package Generation & Offline Search UI

- **Task IDs:** `FA-ROUTING-01`, `FA-MAP-VECTOR-01`, `FA-SEARCH-UI-01`, `FA-E2E-TIERS-01`
- **Standard:** Field Assistant Engineering Standard (FAES) — `AGENTS.md`
- **Date:** 2026-11-18
- **Status:** APPROVED FOR IMPLEMENTATION

---

## 1. Problem Statement and Desired Outcome
Complete all remaining items to achieve FAES 10/10 production readiness:
1. Pure-Dart A* offline routing engine with walking/driving modes, Haversine admissible heuristic, turnaround penalty, and Amazonian fluvial barrier (Rio Solimões) impedance constraints.
2. Offline vector map package generation script (`tool/map/build_alto_solimoes_vector.sh`), PMTiles catalog manifest, style definitions, and `OfflineMapPackageManager` with resumable HTTP Range downloads and atomic rollbacks.
3. Offline geographic search UI integrated into `ContactsMapScreen` utilizing SQLite FTS5 `unicode61 remove_diacritics 2`.
4. Comprehensive E2E test suites: Tier 2 (boundary & corner cases), Tier 3 (cross-feature), and Tier 4 (real-world field scenarios) utilizing the hermetic `OpaqueBoxHarness`.
5. Full verification and documentation synchronization (`IMPLEMENTATION_STATUS.md`, `PRODUCTION_READINESS.md`, `SESSION_HANDOFF.md`, `FAES_FINAL_SCORE.md`, `README.md`).

---

## 2. Component and Dependency Map
```
lib/territory/routing/
  └── offline_routing_engine.dart (Pure-Dart A* Graph Router)
lib/territory/map_engine/
  ├── offline_map_package_manager.dart (Package Download State Machine & Range Requests)
  └── offline_map_catalog.dart (Canonical Manifests)
lib/search/
  └── offline_search_index.dart (FTS5 Unicode61 Search Index)
lib/ui/screens/contacts_map/
  └── offline_search_modal.dart (Search & Route UI)
tool/map/
  └── build_alto_solimoes_vector.sh (Vector PMTiles Extraction Script)
test/e2e_suite/tiers/
  ├── tier2_boundary_corner_cases_test.dart
  ├── tier3_cross_feature_combinations_test.dart
  └── tier4_field_scenarios_test.dart
```

---

## 3. Invariants Preserved
- 100% Offline-first: routing and search operate entirely without external APIs.
- Fail-closed security: corrupted packages or unauthorized river crossings are rejected.
- Data integrity: zero deletion of user data or sync queue pollution.
- No new external runtime dependencies: uses pure Dart and existing packages (`drift`, `shelf`, `sqlite3`, `crypto`).

---

## 4. Verification Plan
- Unit and graph tests for `OfflineRoutingEngine`.
- Unit tests for `OfflineMapPackageManager` (Range requests, checksum validation, rollback).
- UI integration tests for offline search and route modals.
- Full E2E opaque-box suites: Tiers 1, 2, 3, 4.
- Static analysis: `dart analyze lib test` with 0 issues.
