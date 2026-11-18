# Arquitetura do Map Engine — Nível 2 (Experiência Cartográfica Completa)

- **Task IDs:** `FA-MAP-01`, `FA-MAP-02`
- **Data:** 2026-11-17
- **Decisão de Produto:** Nível 2 — Experiência Cartográfica Completa, 100% offline para mapas instalados e contatos privados.

---

## 1. Comparação Técnica Objetiva

| Critério | MapLibre Native (`maplibre` / `maplibre_gl`) | `flutter_map` + MBTiles Raster (Atual) | Núcleo Organic Maps (`omim` / C++) |
|---|---|---|---|
| **Qualidade visual & vetorial** | Renderização vetorial GPU (OpenGL/Metal), labels rotacionam nitidamente em qualquer ângulo | Tiles raster 256px (borram em zoom fracionário; labels giram de cabeça para baixo) | Excelente renderização vetorial nativa |
| **Fluidez, zoom, rotação, tilt** | 60–120 FPS nativo, zoom contínuo, rotação suave, inclinação 3D | Bom em 2D, limitado em rotação e zoom intermediário | Excelente 60–120 FPS |
| **Offline (PMTiles / MBTiles)** | Suporte nativo a pacotes vetoriais PMTiles/MBTiles (~5–10x menores que raster) | MBTiles raster (ex.: Solimões = 264 MB) | Formato próprio `.mwm` (pipeline C++ complexo) |
| **Pesquisa & Roteamento offline** | Requer índice local (SQLite FTS5) + motor separado (Valhalla/GraphHopper) para roteamento offline | Mesmo cenário (não inclui roteamento offline) | Integrado no core C++, mas acoplado ao ecossistema C++/JNI/ObjC++ |
| **Compatibilidade Flutter & iOS/iPadOS** | Boa via plugin MapLibre Native (requer validação SwiftPM/Metal em iPhone/iPad reais) | 100% Dart puro, já validado em iOS/Android/Web/Windows | Muito alta complexidade de FFI/build multiplataforma |
| **Licenciamento** | BSD-2-Clause / BSD-3-Clause (compatível) | BSD-3-Clause (compatível) | Apache-2.0 (exige preservação de avisos; alto custo de manutenção de fork C++) |
| **Recomendação FAES** | **Candidato preferencial** por trás de `MapEngineAdapter`, homologado em protótipo real iOS/iPadOS antes de remover o backend raster | **Fallback seguro e estável** já operacional enquanto o backend MapLibre Native é homologado em hardware Apple | **Referência de UX/qualidade**, rejeitado como reescrita ou embedding C++ nesta etapa |

---

## 2. Arquitetura em Camadas

```
Flutter UI (ContactsMapScreen, DownloadMapsScreen, LocationPicker)
  -> Map Presentation Layer (camadas, bússola, filtros, detalhes)
  -> MapEngineAdapter (lib/territory/map_engine_adapter.dart)
       ├─ Implementação atual: Raster MBTiles (MBTilesNative + isolate _TileReader)
       └─ Implementação alvo: MapLibre Native + Vector Tile Provider (PMTiles / MBTiles vetorial)

Em paralelo (Separação estrita de privacidade):
  Geo Services (local Drift SQLite — NUNCA misturado aos pacotes públicos ODbL):
    - Contatos & Coordenadas reais (`people`) — 100% offline
    - Marcos territoriais (`territory_landmarks`) — 100% offline
    - Setores territoriais (`territory_sectors`) — 100% offline
    - Geocoding Nominatim (online com cache LRU/SQLite, rate limit 1 req/s, User-Agent único e aviso de privacidade)
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
| Mapa base de regiões instaladas | **SIM** (MBTiles / PMTiles verificados) | **SIM** |
| Busca de contatos, marcos e setores no mapa | **SIM** (SQLite local) | **SIM** |
| Geocodificação de novos endereços (Nominatim) | **NÃO** (apenas hits em cache local) | **SIM** (com aviso de privacidade e rate limit) |
| Roteamento turno-a-turno no app | **NÃO IMPLEMENTADO** (requer grafo offline Valhalla/GraphHopper; abrir app externo não é roteamento offline) | Apenas via app externo de mapas |
