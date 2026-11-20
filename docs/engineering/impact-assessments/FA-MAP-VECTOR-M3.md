# Impact Assessment: Milestone 3 — Vector Maps Pipeline & Package Resilience

**Task ID**: FA-MAP-VECTOR-M3 / Milestone 3  
**Date**: 2026-11-19  
**Status**: APPROVED  
**Standard**: Field Assistant Engineering Standard (FAES)  

---

## 1. Problem and Desired Outcome

### 1.1 Problem Statement
1. **Extraction Script Fail-Open**: `tool/map/build_alto_solimoes_vector.sh` catches missing dependencies (`osmium`, `ogr2ogr`, `tippecanoe`), logs a warning to stderr, but proceeds to generate synthetic 0-byte PBF files (`touch "$sai_pbf"`) and a dummy 64 KB PMTiles file with empty directories and hardcoded fallback hashes (`61d368e5461c360877918fcf57a4a2ad554f24ef5eecde9d4ef7b5bc6082ee20`).
2. **Shallow Header Validation**: `OfflineMapPackageManager.validatePmtilesHeader` validates only the 7 magic ASCII bytes `"PMTiles"` and version byte 3. Synthetic files with 0 tiles and empty directories pass validation unnoticed. Furthermore, there is no format validation for MBTiles files.
3. **Fragile Download Resumption**: `OfflineMapPackageManager.downloadAndInstall` wipes `.tmp` staging files unconditionally inside `catch (e)`, destroying partial progress upon transient network disconnections (`ClientException`, `SocketException`, timeouts) and preventing RFC 7233 HTTP 206 resumption.
4. **Unvalidated HTTP 206 Responses**: When receiving HTTP 206, `OfflineMapPackageManager` does not inspect the `Content-Range` header (`bytes START-END/TOTAL`), risking file corruption if the server begins at an unexpected offset.
5. **Missing Backup Recovery**: In `syncWithDisk()`, if the final package file is absent from disk but a surviving backup (`.bak`) exists, the manager marks the package as uninstalled rather than validating and restoring the backup.

### 1.2 Desired Outcome
- `build_alto_solimoes_vector.sh` fails closed (`exit 1`) immediately if any required tool (`curl`, `sha256sum`, `osmium`, `ogr2ogr`, `tippecanoe`, `python3`) or input PBF is missing or invalid. Dummy fallbacks and hardcoded hashes are completely removed.
- `validatePmtilesHeader` deeply inspects the 127-byte header: root directory offset and length, tile data offset and length, tile counts (`numTileEntries > 0` or `numAddressedTiles > 0`), non-inverted WGS84 bounding box coordinates, and valid zoom levels (`0 <= minZoom <= maxZoom <= 26`).
- MBTiles format validation checks the 16-byte SQLite magic (`SQLite format 3\000`).
- Transient errors preserve the `.tmp` staging file; only irrecoverable errors purge it.
- HTTP 206 verifies `Content-Range: bytes START-...`; if missing or starting byte mismatches, download restarts safely from byte 0 with `FileMode.write`.
- `syncWithDisk()` validates and restores surviving `.bak` package files when the primary file is missing.

---

## 2. Component and Dependency Map

- `tool/map/build_alto_solimoes_vector.sh`: Cartographic data extraction and packaging CLI script.
- `lib/territory/packages/offline_map_package_manager.dart`: Package download, validation, atomic installation, and disk synchronization.
- `lib/territory/map_engine/pmtiles_reader.dart`: Canonical PMTiles v3 specification and reader.
- `test/territory/map_engine/offline_map_package_manager_test.dart`: Automated test suite for package lifecycle, validation, resumption, and backup restoration.
- `test/territory/map_engine/pmtiles_reader_test.dart`: PMTiles v3 reader and header parsing tests.
- `test/territory/map_safety_regression_test.dart`: Storage safety and backup regression tests.

---

## 3. Data Flow and Trust Boundaries

1. **Cartographic Pipeline Boundary**: Remote OpenStreetMap PBF (ODbL) -> `osmium` BBox extract -> `ogr2ogr` thematic layer extraction -> `tippecanoe` MVT vector tile compilation -> PMTiles v3 archive + SHA-256 calculation. Any anomaly in this chain fails closed.
2. **HTTP Network Download Boundary**: HTTP GET with `Range: bytes=START-` -> HTTP 206 response validation -> stream chunks into `.tmp` file -> on network error, close stream and preserve `.tmp`.
3. **Storage & Validation Boundary**: Finished `.tmp` file -> size check -> deep PMTiles header / MBTiles magic validation -> SHA-256 hash comparison -> atomic swap (primary renamed to `.bak`, `.tmp` renamed to primary) -> registration in `OfflineTileServer`.
4. **Crash Recovery Boundary**: App restart -> `syncWithDisk()` -> detects primary missing -> inspects `.bak` -> validates header -> restores `.bak` to primary.

---

## 4. Edge Cases and Failure Modes

- **Tool Missing in PATH**: Script immediately outputs descriptive error to stderr and exits 1.
- **Corrupt / Truncated Input PBF**: `osmium fileinfo` check fails; script exits 1.
- **Tippecanoe Failure**: Script exits 1; no synthetic placeholder generated.
- **Transient Network Drop Midway**: `ClientException` caught -> sink flushed and closed -> `.tmp` file preserved on disk.
- **Server Ignores Range Request (Returns 200)**: Manager detects status 200, resets `existingBytes = 0`, truncates staging file with `FileMode.write`, and downloads full payload without corruption.
- **Server Returns 206 with Misaligned Starting Byte**: `Content-Range: bytes X-Y/Z` where `X != existingBytes` -> manager resets `existingBytes = 0`, opens with `FileMode.write`, and restarts cleanly.
- **Server Returns 416 (Range Not Satisfiable)**: Staging file deleted, throws `RangeNotSatisfiableException`.
- **Synthetic Dummy PMTiles Header**: `validatePmtilesHeader` detects `rootDirLength == 0` or `numTileEntries == 0` or inverted coordinates -> throws `InvalidPackageFormatException`.
- **Corrupt Backup File**: `syncWithDisk()` fails validation on `.bak` -> logs warning -> does not restore invalid backup.

---

## 5. Verification Plan

1. Verify `build_alto_solimoes_vector.sh` in environment without tools: exits 1 with explicit error.
2. Verify PMTiles deep header validation unit test: rejects 64 KB zeroed directory synthetic file.
3. Verify MBTiles header validation unit test: rejects non-SQLite files.
4. Verify transient failure `.tmp` preservation test: `ClientException` does not delete `.tmp`.
5. Verify HTTP 206 `Content-Range` resumption test: appends correctly when range matches, truncates when range mismatches.
6. Verify backup restoration test: `syncWithDisk()` restores `.pmtiles.bak` when `.pmtiles` is absent.
7. Run `dart analyze` and full `flutter test` suite.
