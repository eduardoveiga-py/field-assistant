# FIELD ASSISTANT — ARQUITETURA FINAL DO MOTOR CARTOGRÁFICO
**Documento de Arquitetura de Software — FAES §4 & Ordem Mestra de Conclusão**  
**Projeto:** Field Assistant  
**Motor Primário:** MapLibre Native 0.28.0 (Metal no iOS / OpenGL ES no Android)  
**Formato de Dados Vetoriais:** PMTiles v3 (Protomaps Specification) & MBTiles (MVT/PBF)  
**Versão:** 2.0.0+14  
**Data:** 18 de Novembro de 2026

---

## 1. VISÃO GERAL ARQUITETURAL

O subsistema cartográfico do **Field Assistant** foi arquitetado sob o princípio da **Autonomia Offline Absoluta**. No iPhone e iPad, o motor primário oficial é o **MapLibre Native**, proporcionando renderização vetorial acelerada por hardware via Metal, renderização tipográfica dinâmica com fontes SDF (Signed Distance Fields), rotação e inclinação livres, e ausência total de dependência de conexões de rede em campo.

```mermaid
graph TD
    UI[Interface do Usuário Flutter / ContactsMapScreen] --> Selector[MapEngineSelector]
    Selector --> Adapter[MaplibreNativeAdapter]
    Adapter --> View[MapLibreVectorMapView]
    View --> Metal[Motor Nativo MapLibre / Metal iOS]
    
    Metal -- "Loopback HTTP (127.0.0.1:port)" --> TileServer[OfflineTileServer (Shelf)]
    TileServer --> Facade[offline_tile_server.dart]
    Facade -- "dart.library.io" --> ServerIO[offline_tile_server_io.dart]
    Facade -- "dart.library.html / web" --> ServerWeb[offline_tile_server_web.dart (Stub)]
    
    ServerIO --> PMTiles[PmtilesReader v3 (Hilbert TileID)]
    ServerIO --> MBTiles[MbtilesBackend (SQLite3)]
    
    PMTiles --> PackageMgr[OfflineMapPackageManager]
    PackageMgr --> Catalog[OfflineMapCatalog (Alto Solimões)]
    
    Adapter --> Router[OfflineRoutingEngine (Pure Dart A*)]
    Adapter --> Geocoder[OfflineGeocodingService (FTS5 / R-Tree)]
```

---

## 2. COMPONENTES PRINCIPAIS DO MOTOR

### 2.1. Adaptador Unificado (`MaplibreNativeAdapter`)
Localizado em `lib/territory/map_engine/maplibre_native_adapter.dart`:
- Implementa a interface canônica `MapEngineAdapter` (`lib/territory/map_engine_adapter.dart`).
- Gerencia o ciclo de vida da instância do mapa, mantendo paridade com as capacidades do Organic Maps:
  - `supportsVectorTiles: true`
  - `supportsOfflineStorage: true`
  - `supportsRotation: true`
  - `supportsPitch: true`
  - `supportsOfflineRouting: true`
  - `supportsOfflineGeocoding: true`

### 2.2. Visualizador Vetorial Nativo (`MapLibreVectorMapView`)
Localizado em `lib/ui/widgets/map/maplibre_vector_map_view.dart`:
- Hospeda o widget `MaplibreMap` do plugin nativo `maplibre_gl 0.28.0`.
- Controla interações táteis (pan, pinch-to-zoom, two-finger rotate, tilt).
- Gerencia camadas dinâmicas de marcadores vetoriais com agrupamento por cluster (`circle`, `symbol` e `fill`).
- Trata eventos de toque em pontos de interesse (contatos, estudantes da Bíblia, revisitas e limites de setores).

### 2.3. Servidor Local Loopback RFC 7233 (`OfflineTileServer`)
Localizado em `lib/territory/map_engine/offline_tile_server.dart`:
- **Isolamento de Plataforma:**
  - `offline_tile_server_io.dart`: Servidor HTTP Shelf ligado estritamente a `InternetAddress.loopbackIPv4` (`127.0.0.1`). Porta alocada dinamicamente pelo sistema operacional (`port = 0`), eliminando conflitos de porta.
  - `offline_tile_server_web.dart`: Fachada Web-safe para evitar que o compilador JavaScript/WASM importe `dart:ffi` ou bibliotecas de socket TCP inexistentes nos navegadores.
- **Suporte a RFC 7233:**
  - Processamento de cabeçalhos `Range: bytes=start-end`.
  - Respostas `206 Partial Content` com cabeçalho `Content-Range: bytes start-end/total`.
  - Respostas `416 Range Not Satisfiable` quando o offset excede os limites físicos do arquivo.
  - Headers `Content-Type: application/vnd.mapbox-vector-tile` com codificação `gzip`/`deflate`.

### 2.4. Leitor de Pacotes PMTiles v3 (`PmtilesReader`)
Localizado em `lib/territory/mbtiles/pmtiles_reader.dart`:
- Em conformidade estrita com a **Protomaps PMTiles Specification v3**:
  - Cabeçalho imutável de 127 bytes contendo número mágico `PMTiles`, versão `3`, limites `GeoBoundingBox` e zooms (`minZoom` a `maxZoom`).
  - Mapeamento de coordenadas `(z, x, y)` para Tile IDs unidimensionais via **Curva de Hilbert**.
  - Suporte a diretórios raiz compactados com gzip e busca binária em tempo logarítmico $O(\log N)$ sobre sequências compactas com codificação delta e Run Length Encoding (RLE).
  - Resolução de subdiretórios (*leaf directories*) para pacotes massivos.

---

## 3. ROTEAMENTO OFFLINE PURO DART A* (`OfflineRoutingEngine`)

Localizado em `lib/territory/routing/offline_routing_engine.dart`:
- Motor autônomo sem dependência de bibliotecas C++ externas ou serviços de backend.
- **Algoritmo A* com Heurística Haversine Admissível:**
  - $f(n) = g(n) + h(n)$
  - $h(n)$ calculada pela distância ortodrômica de Haversine dividida pela velocidade máxima possível no modal:
    $$h(n) = \frac{\text{haversine}(n, \text{goal})}{v_{\max}}$$
  - Garante que a heurística nunca superestime a distância real ($h(n) \le d^*(n, \text{goal})$), assegurando optimalidade estrita.
- **Modais de Transporte Suportados:**
  - **Caminhada (`walking`):** Velocidade base de $1{,}25\text{ m/s}$ ($4{,}5\text{ km/h}$).
  - **Veículo (`driving`):** Velocidade base de $11{,}11\text{ m/s}$ ($40\text{ km/h}$) para vias urbanas regionais.
- **Penalidades Topológicas:**
  - Detecção de manobras de retorno (turnaround em $180^\circ \pm 30^\circ$): penalidade de $60\text{ s}$ para pedestres e $120\text{ s}$ para veículos.
- **Barreiras Fluviais Amazônicas:**
  - Impedância infinita aplicada a travessias sobre águas abertas (Rio Solimões, Rio Jandiatuba) onde não haja embarcação cadastrada.
  - Roteamento inteligente forçado através de portos e pontos de embarque fluvial oficiais.

---

## 4. ESTILOS, FONTES E ATIVOS OFFLINE

O aplicativo carrega 100% de seus ativos gráficos internamente:
- **Style JSON:** `assets/map/style.json` — Esquema de cores de alto contraste solar, hierarquia visual de vias (rodovias, ruas principais, caminhos pedonais), hidrografia (rios, paranás, lagos) e áreas de proteção florestal.
- **Fontes SDF:** `assets/map/fonts/` — Glifos Signed Distance Field pré-gerados cobrindo:
  - Faixa `0-255`: Alfabeto latino básico, numerais e pontuação.
  - Faixa `256-511`: Caracteres latinos estendidos necessários para a língua indígena **Ticuna** (e.g., `ũ` - U+0169, `Ũ` - U+0168).
- **Sprites:** `assets/map/sprites/` — Ícones vetoriais de marcos de território, pessoas, residências visitadas, locais de reunião e portos de atracação fluvial.

---

## 5. RESUMO DE CONFORMIDADE E GARANTIAS

| Requisito FAES | Implementação | Evidência de Teste |
|---|---|---|
| **Zero tráfego externo** | Loopback 127.0.0.1 + `AirplaneNetworkGate` | `Tier4-Scenario2` (Betânia 100% Airplane Mode) |
| **Resiliência a cortes de rede** | HTTP Range 206 + Retomada atômica | `TC-PKGMGR-03`, `Probe 1.5` |
| **Integridade de pacotes** | SHA-256 criptográfico streaming | `TC-PKGMGR-01`, `Probe 1.4` |
| **Rollback atômico** | Substituição transacional `.bak` / `.tmp` | `Probe 1.7` |
| **Compatibilidade Web** | Isolamento FFI por exportação condicional | `flutter build web`, `run_web.ps1 -Server` |
