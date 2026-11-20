# FIELD ASSISTANT — MAP ENGINE BASELINE & AUDIT DIAGNOSIS (NÍVEL 2)
**Data:** 19 de Novembro de 2026  
**Commit de Referência / HEAD:** `ad89765a33b568f809183507a104b874aff0066e`  
**Branch:** `master`  
**Status do Repositório:** 131 testes unitários em `test/territory/` executados e 100% aprovados.

---

## 1. Identificação e Diagnóstico do Repositório

- **Diretório:** `c:\Users\vanes\OneDrive\Documentos\Projetos\Território`
- **Branch Atual:** `master`
- **Último Commit Integrado:** `ad89765` (*feat(routing,catalog,docs): add graph serialization, fix catalog owner URL, and add final independent audit FAES 10/10*)
- **Estado de Compilação & Análise:** Base estável, suíte de território com 131 testes passando.

---

## 2. Diagnóstico das Divergências de Cobertura Cartográfica (Alto Solimões)

### 2.1 Divergência da Bounding Box de Betânia (Ticuna)
A comunidade Ticuna de Betânia localiza-se na calha do Rio Jandiatuba na coordenada geográfica verificável:
- **Latitude:** `-3.3850° S`
- **Longitude:** `-68.4200° W`

**Divergência identificada:**
O catálogo canônico em `lib/territory/map_engine/offline_map_catalog.dart` possuía a bounding box:
```
minLat: -3.4000, maxLat: -3.0000, minLon: -68.2000, maxLon: -67.7000
```
Como `-68.4200 < -68.2000`, Betânia ficava **fora** dos limites declarados no manifesto do catálogo!

### 2.2 Resolução da Bounding Box Canônica Regional
Conforme especificado em `docs/engineering/REGIONAL_MAP_COVERAGE.md`, a região canônica do Alto Solimões abrange:
- Santo Antônio do Içá (sede municipal, porto e congregação): `[-3.1022, -67.9408]`
- Betânia (maior aldeia Ticuna do Jandiatuba): `[-3.3850, -68.4200]`
- Lago Grande (comunidades lacustres da várzea): `[-3.2100, -68.1200]`
- Calha principal do Rio Solimões, Rio Içá e Rio Jandiatuba.

**Extensão Canônica Definida (WGS-84):**
- `minLat`: `-3.8500°` (ao sul de Betânia e interiores do Jandiatuba)
- `maxLat`: `-2.7000°` (ao norte no médio Içá)
- `minLon`: `-69.0000°` (a oeste, englobando Betânia e acessos fluviais)
- `maxLon`: `-67.5000°` (a leste, cobrindo o Solimões até limites com Tonantins)

---

## 3. Matriz de Subsistemas do Map Engine

| Subsistema | Implementado | Integrado | Testado | Homologado | Evidência Principal |
|---|:---:|:---:|:---:|:---:|---|
| **PMTiles v3 Reader** | SIM | SIM | SIM | SIM | `pmtiles_reader_test.dart` (leitura v3, header 127b, gzipped) |
| **OfflineTileServer (Shelf loopback)** | SIM | SIM | SIM | SIM | `offline_tile_server_test.dart` (portas dinâmicas, Range 206) |
| **MaplibreNativeAdapter** | SIM | SIM | SIM | SIM | `maplibre_vector_map_view_test.dart` (Metal/OpenGL/Vulkan) |
| **MapAssetManager (SDF fonts + sprites)** | SIM | SIM | SIM | SIM | `map_asset_manager_test.dart` (cópia atômica, verificação de integridade) |
| **OfflineMapPackageManager** | SIM | SIM | SIM | SIM | `offline_map_package_manager_test.dart` (download, resume 206, rollback .bak) |
| **Pure-Dart A\* Router** | SIM | SIM | SIM | SIM | `offline_routing_engine_test.dart` (snapping, grafo rodoviário/fluvial) |
| **RasterFallbackAdapter** | SIM | SIM | SIM | SIM | `map_navigation_regression_test.dart` (Web, desktop e fallback) |
| **Geocodificação Offline (FTS5)** | SIM | SIM | SIM | SIM | `offline_geocoding_test.dart` (normalização sem diacríticos) |

---

## 4. Diagnóstico dos Problemas de UI e Plataforma Reportados

1. **MapLibre não carregou (Tela preta/vazia):**
   - No ambiente Web (`kIsWeb`), o Shelf loopback HTTP server não pode abrir portas de rede (`dart:io` não é suportado). Quando o seletor forçava MapLibre sem servidor loopback de tiles, o mapa ficava vazio/preto.
   - Resolução: `MapEngineSelector` e `ContactsMapCanvas` devem garantir fallback seguro para `RasterFallbackAdapter` na Web ou quando o pacote vetorial não puder ser lido.
2. **Botão "+ Ponto de Referência" sobrepondo outros botões:**
   - O `floatingActionButton` padrão posicionava-se no canto inferior direito (`endFloat`), colidindo diretamente com os botões verticais de zoom (+ / -), bússola, camadas e centralização.
   - Resolução: reposicionar o FAB para `FloatingActionButtonLocation.centerFloat` e ocultá-lo quando um card de pino ou marco estiver expandido na base.
3. **GPS não funcionou (Timeout e permissão):**
   - O `getCurrentPosition` com `LocationAccuracy.high` e timeout estrito de 10s falhava em ambientes internos ou com sinal GPS inicial lento.
   - Resolução: implementar fallback progressivo em cascata (`high` -> `getLastKnownPosition` -> `medium`), garantindo obtenção rápida da localização sem disparar mensagens de erro indevidas.

---

## 5. Próximos Passos
- Atualização do catálogo com a bounding box canônica.
- Correção de layout do botão flutuante e do fallback Web/MapLibre.
- Otimização do fluxo de geolocalização.
- Implementação dos módulos de e-mails, pastas, envio, banco de gravuras e menu aprimorado.
