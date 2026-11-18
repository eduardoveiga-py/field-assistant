# Arquitetura do Map Engine — Nível 2 (Estado Real & Alvo)

- **Task IDs:** `FA-MAP-01`, `FA-MAP-02`, `M3`
- **Atualizado em:** 2026-11-18 (Verificação Forense Independente)
- **Decisão de Produto:** Nível 2 — Experiência Cartográfica Completa, 100% offline para mapas instalados e contatos privados.

---

## 1. Estado Real Verificado no Código vs. Alvo Nível 2

> **Transparência FAES:** Este documento substitui descrições legadas que mencionavam `flutter_map` (que nunca esteve em `pubspec.yaml`). Abaixo consta estritamente o que está compilado e testado hoje vs. o que falta ativar na UI e homologar em hardware Apple.

| Componente | Estado Real no Código (`master`) | Evidência no Repositório |
|---|---|---|
| **Renderizador ativo na UI (`ContactsMapScreen`, `MapLocationPickerDialog`)** | **Motor Raster em Dart (`InteractiveViewer` + `DynamicTileLayer` + `RasterFallbackAdapter`)** com contra-rotação individual de pinos de contatos e marcos (`Transform.rotate(angle: -rotation)`). | `lib/ui/screens/contacts_map_screen.dart:107, 4159, 4298`<br>`lib/ui/widgets/map/dynamic_tile_layer.dart`<br>`lib/territory/map_engine/raster_fallback_adapter.dart` |
| **Dependência `maplibre_gl`** | Declarada em `pubspec.yaml` (`maplibre_gl: ^0.28.0`), porém **ainda não importada em `lib/`** e não ativa como widget na UI (`MapLibreMap`). | `pubspec.yaml:79` |
| **Adaptador `MaplibreNativeAdapter`** | Implementado com controle de câmera (zoom fracionário, rotação 360°, tilt 0°–60°), camadas GeoJSON (contatos, marcos, setores) e gerador de Style JSON v8 apontando para o servidor loopback (`/pmtiles/:id/{z}/{x}/{y}.pbf`, `/mbtiles/:id/{z}/{x}/{y}.pbf`, `/tiles/mbtiles/{z}/{x}/{y}`). **Não instanciado na UI ainda.** | `lib/territory/map_engine/maplibre_native_adapter.dart`<br>`test/territory/map_engine/maplibre_advanced_test.dart`<br>`test/territory/map_engine_adapter_test.dart` |
| **Servidor Local Loopback (`OfflineTileServer`)** | Implementado com `shelf` em `127.0.0.1` (porta efêmera): suporta RFC 7233/9110 HTTP 206 Partial Content para `.pmtiles`, extração direta `/pmtiles/:id/:z/:x/:y.pbf` via `PmtilesReader` (PMTiles v3 + curva de Hilbert) e `/mbtiles/:id/:z/:x/:y.pbf` via SQLite. | `lib/territory/map_engine/offline_tile_server.dart`<br>`lib/territory/map_engine/pmtiles_reader.dart`<br>`test/territory/offline_tile_server_test.dart`<br>`test/territory/map_engine/pmtiles_reader_test.dart` |
| **Validador MBTiles (`MBTilesNative`)** | Aceita pacotes raster (PNG/JPEG/WebP) **e** vetoriais (MVT/PBF comprimidos com gzip/zlib ou brutos). | `lib/territory/mbtiles/mbtiles_native.dart:341-376`<br>`test/territory/map_engine/mbtiles_vector_test.dart` |
| **Ativos Offline Empacotados (`assets/map/`)** | `style_offline_light.json`, `style_offline_dark.json`, sprites RGBA 1x (`32x16`) e 2x (`64x32`) + JSONs sem colisão, e glifos SDF autênticos `Noto Sans Regular/0-255.pbf` (76.049 bytes, 195 glifos, 188 bitmaps SDF distintos no formato `(w+6)*(h+6)`), gerenciados por `MapAssetManager`. | `assets/map/`<br>`lib/territory/map_engine/map_asset_manager.dart`<br>`test/territory/map_engine/map_asset_authenticity_test.dart` |
| **Geocodificação Híbrida & Busca Offline** | `OfflineGeocodingService` (cache persistente Drift `AppKvStore` com TTL de 30 dias, rate-limit estrito 1 req/s Nominatim, busca local offline em `people`, `territory_landmarks` e `territory_sectors`). `GeocodingService` delega diretamente a ele e os pontos de UI passam `db`. | `lib/territory/geocoding/offline_geocoding_service.dart`<br>`lib/territory/geocoding_service.dart`<br>`test/territory/geocoding/offline_geocoding_test.dart` |

---

## 2. Arquitetura em Camadas

```
Flutter UI (ContactsMapScreen, DownloadMapsScreen, MapLocationPickerDialog)
  -> Map Presentation Layer (camadas, bússola, filtros, contra-rotação de pinos)
  -> MapEngineAdapter (lib/territory/map_engine_adapter.dart)
       ├─ Ativo hoje na UI: RasterFallbackAdapter + DynamicTileLayer (MBTilesNative)
       └─ Infraestrutura pronta (aguardando widget MapLibreMap + homologação GPU Metal iOS/iPadOS):
            MaplibreNativeAdapter + OfflineTileServer (Shelf 127.0.0.1) + PmtilesReader + MapAssetManager

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
| Renderização GPU Vetorial MapLibre Native em iPhone/iPad | **NÃO VERIFICADA / NÃO ATIVA NA UI** (requer integração do widget `MapLibreMap` e homologação em hardware Apple) | **NÃO VERIFICADA** |
