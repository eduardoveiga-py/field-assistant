# Field Assistant — Session Handoff (FAES Master Program)

- **Data:** 2026-11-18
- **Branch ativa:** `master`
- **Status do Gate Global:** `NOT APPROVED / BLOCKED (8.18 / 10.0)` — **Os defeitos críticos P0-01 (SQLite fail-closed), P1-01 (mídias E2EE imutáveis), P1-02 (migração Supabase), P1-03 (iOS FileProtection Classe B), P1-04 (MBTiles vetorial + servidor loopback + glifos SDF autênticos), P1-05 (geocodificação com cache SQLite 30d) e P2-04 (conflitos de estudos e tarefas) estão remediados e verificados por testes automatizados. Permanecem bloqueadores para aprovação final (>= 9.7/10): ativação real do widget `MapLibreMap` na UI, decomposição das telas monolíticas, acessibilidade VoiceOver (`Semantics`), adaptação iPad em `studies_screen` e demais telas, homologação em hardware Apple (iPhone/iPad) e `supabase test db` em staging real.**

## Estado Consolidado e Evidências Verificadas

1. **M1 — Criptografia Local Fail-Closed & Proteção iOS (Remediado no código):**
   - `lib/database/connection/local_db_encryption_state.dart`: máquina de 5 estados (`encrypted`, `migrationRequired`, `encryptionUnavailable`, `migrationFailed`, `recoveryRequired`).
   - `lib/database/connection/native.dart` & `local_database_encryption.dart`: fallback silencioso para plaintext eliminado; `_SafeNativeUnavailableQueryExecutor` bloqueia leitura/escrita em caso de erro de chave ou ausência de `sqlite3mc`.
   - `ios/Runner/Runner.entitlements` & `AppDelegate.swift`: `NSFileProtectionCompleteUntilFirstUserAuthentication` (Classe B).

2. **M2 — Integridade de Mídias E2EE, Migrações SQL & Conflitos de Domínio (Remediado e verificado via PGlite):**
   - `lib/sync/crypto/encrypted_media_transfer.dart` & `supabase_sync_service.dart`: chunks versionados imutáveis (`v_$versionId/chunk_$index.enc`, `upsert: false`) nos 4 buckets (`voice_notes`, `ticuna_audio`, `knowledge_vault`, `person_photos`).
   - `supabase/migrations/20261112000000_hardening_storage_indexes_rls.sql`: função `public.handle_soft_delete_and_resurrection_guard()` criada formalmente com `SET search_path = public`.
   - `lib/sync/domain_conflict_detector.dart`: detecção de conflitos em agendamentos, estudos bíblicos e tarefas integrada ao pull.
   - **SQL PGlite:** 5/5 suítes em `test/sql/` passando (exit 0).

3. **M3 — Infraestrutura Cartográfica Nível 2 & Geocodificação Offline (Infraestrutura pronta; UI ainda em RasterFallback):**
   - `assets/map/fonts/Noto Sans Regular/0-255.pbf`: glifos SDF autênticos (76.049 bytes, 195 glifos, 188 bitmaps `(w+6)*(h+6)` distintos, fontstack `"Noto Sans Regular"`), validados por `test/territory/map_engine/map_asset_authenticity_test.dart` e `tool/generate_map_assets.py --verify-only`.
   - `assets/map/sprites/sprite*.png` e `sprite*.json`: atlas RGBA 1x (`32x16`) e 2x (`64x32`) não sobrepostos.
   - `lib/territory/map_engine/offline_tile_server.dart` & `pmtiles_reader.dart`: servidor Shelf `127.0.0.1` com HTTP 206 Partial Content, PMTiles v3 Hilbert e MBTiles vetoriais/raster.
   - `lib/territory/map_engine/maplibre_native_adapter.dart`: URLs de tiles corrigidas para `/{pmtiles|mbtiles}/:id/{z}/{x}/{y}.pbf`.
   - `lib/territory/geocoding_service.dart` & `lib/territory/geocoding/offline_geocoding_service.dart`: fachada unificada delegando 100% para `OfflineGeocodingService` (eliminando `dynamicDbCompanion` quebrado), com `db` propagado pelos fluxos de UI e fechamento seguro de `http.Client`.
   - `lib/ui/screens/contacts_map_screen.dart`: contra-rotação individual nos pinos de contatos e marcos; porém o renderizador ativo permanece `InteractiveViewer` + `DynamicTileLayer` (`RasterFallbackAdapter`).

4. **M4 — CI/CD, Áudio iOS & iPad UX (Parcial):**
   - `.github/workflows/ci.yml`: validação global `dart format --output=none --set-exit-if-changed lib test integration_test` ativada.
   - `lib/ui/screens/appointments_screen.dart` & `people_screen.dart`: split-view Master-Detail (`>= 900px`). `studies_screen.dart` e demais telas permanecem sem split-view.
   - `lib/voice_notes/audio_recording_service.dart`: escuta `onStateChanged()` do `record`, porém sem integração explícita de `AVAudioSession` (`audio_session`).

5. **M5 — Decomposição de Monólitos & Documentação (Pendente decomposição; docs reconciliados):**
   - Contradições em `MAP_ENGINE_ARCHITECTURE.md`, `MASTER_REAUDIT.md`, `SESSION_HANDOFF.md`, `PRODUCTION_READINESS.md` e `IMPLEMENTATION_STATUS.md` reconciliadas com o estado empírico real.
   - Monólitos ainda pendentes de extração incremental: `person_detail_screen.dart` (7.635L), `appointments_screen.dart` (4.842L), `contacts_map_screen.dart` (4.390L), `settings_screen.dart` (3.859L), `studies_screen.dart` (3.434L).

## Próximos Passos Obrigatórios para Aprovação FAES (>= 9.7/10)
1. **Ativar `MapLibreMap` (`package:maplibre_gl`) na UI** para iOS/Android/Web (com fallback seguro para desktop) e validar renderização vetorial + rotação + pitch em hardware Apple Metal.
2. **Decompor incrementalmente as telas monolíticas** (`person_detail_screen.dart`, `appointments_screen.dart`, `contacts_map_screen.dart`, `studies_screen.dart`) com testes de caracterização.
3. **Acessibilidade & iPadOS:** expandir `Semantics` (atualmente apenas 4 ocorrências em `lib/`) para cabeçalhos, botões, formulários e anúncios VoiceOver; adicionar Master-Detail em `studies_screen.dart`.
4. **Hard Gates Externos:** homologar em iPhone/iPad físico (EventKit, AVAudioSession sob chamada telefônica, Keychain + `NSFileProtectionCompleteUntilFirstUserAuthentication`, VoiceOver/Dynamic Type 200%, MapLibre Metal), executar `supabase test db` (pgTAP) contra Supabase staging real e registrar decisão do proprietário sobre licença raiz.
