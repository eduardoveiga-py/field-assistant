# Arquitetura do Map Engine — Nível 2 (Estado Real & Alvo)

- **Task IDs:** `FA-MAP-01`, `FA-MAP-02`, `M3`
- **Atualizado em:** 2026-11-18 (Verificação Forense Independente)
- **Decisão de Produto:** Nível 2 — Experiência Cartográfica Completa, 100% offline para mapas instalados e contatos privados.

---

## 1. Estado Real Verificado no Código vs. Alvo Nível 2

> **Transparência FAES:** Este documento substitui descrições legadas que mencionavam `flutter_map` (que nunca esteve em `pubspec.yaml`). Abaixo consta estritamente o que está compilado e testado hoje vs. o que falta ativar na UI e homologar em hardware Apple.

| Componente | Estado Real no Código (`master`) | Evidência no Repositório |
|---|---|---|
| **Renderizador padrão atual (`ContactsMapScreen`, `MapLocationPickerDialog`)** | **Motor Raster em Dart (`InteractiveViewer` + `DynamicTileLayer` + `RasterFallbackAdapter`)** para desktop, testes headless e pacotes/tiles raster, com contra-rotação individual de pinos de contatos e marcos (`Transform.rotate(angle: -rotation)`). | `lib/ui/screens/contacts_map_screen.dart:107, 4225, 4364`<br>`lib/ui/widgets/map/dynamic_tile_layer.dart`<br>`lib/territory/map_engine/raster_fallback_adapter.dart` |
| **Widget Vetorial Nativo (`MapLibreVectorMapView` via `package:maplibre_gl`)** | Implementado e conectado em `ContactsMapScreen` quando um `MaplibreNativeAdapter` está ativo em plataformas suportadas (`iOS`, `Android`, `Web`), usando `MapLibreMap` com `styleString` gerado offline, sincronização de câmera e overlays GeoJSON (`contacts`, `landmarks`, `sectors`). **Homologação visual/GPU Metal em iPhone/iPad físico ainda pendente.** | `lib/ui/widgets/map/maplibre_vector_map_view.dart`<br>`lib/ui/screens/contacts_map_screen.dart`<br>`test/territory/map_engine/maplibre_vector_map_view_test.dart` |
| **Adaptador `MaplibreNativeAdapter`** | Implementado com controle de câmera (zoom fracionário, rotação 360°, tilt 0°–60°), camadas GeoJSON (contatos, marcos e setores) e gerador de Style JSON v8 completo (`sprite`, `glyphs`, camadas OpenMapTiles `water`/`landuse`/`building`/`transportation`/`place-city`, `sectors`, `landmarks-layer` e `contacts-layer` com `viewport` rotation alignment) apontando para o servidor loopback (`/pmtiles/:id/{z}/{x}/{y}.pbf`, `/mbtiles/:id/{z}/{x}/{y}.pbf`, `/assets/sprites/sprite`, `/assets/fonts/{fontstack}/{range}.pbf`). | `lib/territory/map_engine/maplibre_native_adapter.dart`<br>`test/territory/map_engine/maplibre_advanced_test.dart`<br>`test/territory/map_engine_adapter_test.dart` |
| **Servidor Local Loopback (`OfflineTileServer`) & `PmtilesReader`** | Implementado com `shelf` em `127.0.0.1` (porta efêmera): RFC 7233/9110 HTTP 206 Partial Content para `.pmtiles`, extração direta `/pmtiles/:id/:z/:x/:y.pbf` via `PmtilesReader` conforme especificação oficial PMTiles v3 (magic de 7 bytes `"PMTiles"`, header de 127 bytes, curva de Hilbert, busca binária O(log N) em RLE sem OOM e suporte a **leaf directories** `runLength == 0`), `/mbtiles/:id/:z/:x/:y.pbf` via SQLite, e rotas `/assets/sprites/:file` + `/assets/fonts/:fontstack/:range` com proteção contra path traversal. | `lib/territory/map_engine/offline_tile_server.dart`<br>`lib/territory/map_engine/pmtiles_reader.dart`<br>`test/territory/offline_tile_server_test.dart`<br>`test/territory/map_engine/pmtiles_reader_test.dart` |
| **Validador MBTiles (`MBTilesNative`)** | Aceita pacotes raster (PNG/JPEG/WebP) **e** vetoriais (MVT/PBF comprimidos com gzip/zlib ou brutos). | `lib/territory/mbtiles/mbtiles_native.dart:341-376`<br>`test/territory/map_engine/mbtiles_vector_test.dart` |
| **Ativos Offline Empacotados (`assets/map/`)** | `style_offline_light.json`, `style_offline_dark.json`, sprites RGBA 1x (`32x16`) e 2x (`64x32`) + JSONs sem colisão, e glifos SDF autênticos `Noto Sans Regular/0-255.pbf` (76.049 bytes, 195 glifos, 188 bitmaps SDF distintos no formato `(w+6)*(h+6)`), gerenciados por `MapAssetManager` e servidos por `OfflineTileServer`. | `assets/map/`<br>`lib/territory/map_engine/map_asset_manager.dart`<br>`test/territory/map_engine/map_asset_authenticity_test.dart` |
| **Geocodificação Híbrida & Busca Offline** | `OfflineGeocodingService` (cache persistente Drift `AppKvStore` com TTL de 30 dias, rejeição de respostas `{"error": ...}` sem poluir cache, rate-limit estrito 1 req/s sem timer pendente, parsing estruturado de `addressdetails=1` e busca local offline em `people`, `territory_landmarks` e `territory_sectors`). `GeocodingService` delega diretamente a ele e todos os pontos de UI (inclusive `MapLocationPickerDialog`) propagam `db`. | `lib/territory/geocoding/offline_geocoding_service.dart`<br>`lib/territory/geocoding_service.dart`<br>`lib/ui/widgets/map_location_picker_dialog.dart`<br>`test/territory/geocoding/offline_geocoding_test.dart` |

---

## 2. Arquitetura em Camadas

```
Flutter UI (ContactsMapScreen, DownloadMapsScreen, MapLocationPickerDialog)
  -> Map Presentation Layer (camadas, bússola, filtros, contra-rotação de pinos)
  -> MapEngineAdapter (lib/territory/map_engine_adapter.dart)
       ├─ Fallback / Raster / Desktop: RasterFallbackAdapter + DynamicTileLayer (MBTilesNative)
       └─ Vetorial Nativo (iOS/Android/Web quando MaplibreNativeAdapter está ativo; homologação GPU Metal Apple pendente):
            MapLibreVectorMapView (package:maplibre_gl) -> MaplibreNativeAdapter + OfflineTileServer (Shelf 127.0.0.1) + PmtilesReader (v3 + leaf dirs) + MapAssetManager

Em paralelo (Separação estrita de privacidade):
  Geo Services (local Drift SQLite criptografado via sqlite3mc — NUNCA misturado aos pacotes públicos ODbL):
    - Contatos & Coordenadas reais (`people`) — 100% offline
    - Marcos territoriais (`territory_landmarks`) — 100% offline
    - Setores territoriais (`territory_sectors`) — 100% offline
    - Geocoding Nominatim via OfflineGeocodingService (cache AppKvStore 30 dias, rate limit 1 req/s, User-Agent único)
```

---

## 3. Fluxo Obrigatório de Pacotes Offline (`OfflineMapPackageManifest`)

1. Manifesto imutável validado por `OfflineMapPackageManifest` (`id`, `regionName`, `downloadUrl` HTTPS imutável sem `@master`/`@main` e sem bulk download de `tile.openstreetmap.org`, `sizeBytes`, `sha256`, `bbox`, `minZoom`/`maxZoom`, `generatedAt`, `version`, `license: "ODbL-1.0"`, `attribution: "© OpenStreetMap contributors"`, `format: pmtiles | mbtiles`).
2. Pipeline de instalação atômica:
   `Download temporário (.tmp)` -> `Validação de tamanho` -> `Validação SHA-256` -> `Validação de cabeçalho/formato` -> `Backup do pacote anterior (.bak)` -> `Rename atômico` -> `Atualização do catálogo`.
3. Em caso de falha ou cancelamento, a versão anterior permanece funcional e `.tmp` é removido.

---

## 4. Transparência de Capacidades Online vs Offline

| Capacidade | Offline (Sem Internet) | Online |
|---|---|---|
| Visualização de contatos no mapa com coordenadas reais | **SIM** (Drift local) | **SIM** |
| Setores e marcos territoriais | **SIM** (Drift local) | **SIM** |
| Mapa base de regiões instaladas | **SIM** (MBTiles raster na UI atual; infraestrutura PMTiles/MBTiles vetorial pronta em `OfflineTileServer`) | **SIM** |
| Busca de contatos, marcos e setores no mapa | **SIM** (`OfflineGeocodingService.searchOffline` via SQLite local) | **SIM** |
| Geocodificação de novos endereços (Nominatim) | **Apenas hits em cache local (TTL 30 dias)** | **SIM** (rate limit 1 req/s, cache SQLite) |
| Roteamento turno-a-turno no app | **NÃO IMPLEMENTADO** (requer grafo offline Valhalla/GraphHopper; abrir app externo não é roteamento offline) | Apenas via app externo de mapas |
| Renderização GPU Vetorial MapLibre Native em iPhone/iPad | **IMPLEMENTADA NA UI (`MapLibreVectorMapView`), NÃO VERIFICADA EM HARDWARE** (requer catálogo PMTiles vetorial padrão + homologação Metal em iPhone/iPad físico) | **NÃO VERIFICADA** |
