# Impact Assessment: Milestone M3 — Implementação Real do MapLibre Native & Mapas Offline

**Milestone:** M3 (Nível 2 Cartográfico)  
**Data:** 2026-11-18  
**Autor:** Teamwork Worker M3 (implementer, qa, specialist)  
**Status:** Aprovado para Implementação  
**Norma:** Field Assistant Engineering Standard (FAES)  

---

## 1. Problema e Resultado Esperado

### Problema
O aplicativo declarava suporte a cartografia vetorial Nível 2 e pacotes offline PMTiles/MBTiles vetoriais, mas na realidade:
1. `maplibre_gl` e `shelf` não estavam nas dependências (`pubspec.yaml`).
2. Nenhum estilo offline (`style.json`), conjunto de glifos (`.pbf`) ou sprites estava empacotado.
3. `MBTilesNative._validateMbtilesFile` rejeitava ativamente pacotes vetoriais MVT/PBF com `FormatException`.
4. Não havia suporte para servir tiles vetoriais `/pmtiles/:regionId/:z/:x/:y.pbf` ou `/mbtiles/:regionId/:z/:x/:y.pbf` via HTTP range local.
5. Pinos em `ContactsMapScreen` giravam de cabeça para baixo em rotações do mapa.
6. A geocodificação era 100% dependente do Nominatim online sem cache SQLite persistente com TTL nem busca offline em contatos/marcos locais com indexação rápida.

### Resultado Esperado
1. `maplibre_gl: ^0.28.0` e `shelf: ^1.4.1` adicionados e configurados.
2. Ativos cartográficos offline empacotados em `assets/map/` e gerenciados por `MapAssetManager`.
3. Validação de MBTiles em `mbtiles_native.dart` atualizada para aceitar pacotes vetoriais (MVT/PBF/gzip/deflate).
4. `OfflineTileServer` aprimorado para servir endpoints REST `/pmtiles/:regionId/:z/:x/:y.pbf` e `/mbtiles/:regionId/:z/:x/:y.pbf` além do suporte completo a RFC 7233 Range requests.
5. `MapLibreNativeAdapter` implementando `MapEngineAdapter` com geração de Style spec, camadas GeoJSON de contatos, marcos e setores, zoom fracionário e pitch 3D 0°–60°.
6. `RasterFallbackAdapter` encapsulando o motor raster para compatibilidade Web/desktop e ambientes legados.
7. `OfflineGeocodingService` com cache SQLite Drift (TTL 30 dias), rate limit estrito de 1 req/s, e busca offline local em contatos, marcos territoriais e setores.
8. Integração em `ContactsMapScreen` e `MapLocationPickerDialog`.
9. 100% dos testes unitários e de integração em `test/territory/` passando com código de saída 0.

---

## 2. Componentes e Dependências Afetados

- `pubspec.yaml`: adição de `maplibre_gl: ^0.28.0`, `shelf: ^1.4.1`, e declaração de `assets/map/`.
- `assets/map/`:
  - `style_offline_light.json`
  - `style_offline_dark.json`
  - `fonts/` (glifos de fontes padrão)
  - `sprites/` (ícones vetoriais)
- `lib/territory/map_engine/`:
  - `map_asset_manager.dart` (Novo: gerencia cópia e resolução de paths `file://` locais)
  - `offline_tile_server.dart` (Atualizado com rotas PMTiles vetoriais por tile `/:z/:x/:y.pbf` e MBTiles vetoriais)
  - `maplibre_native_adapter.dart` (Atualizado com suporte a GeoJSON layers, zoom fracionário, rotação e pitch)
  - `raster_fallback_adapter.dart` (Atualizado com compatibilidade total)
- `lib/territory/mbtiles/mbtiles_native.dart`: atualização de `_validateMbtilesFile` para permitir MVT/PBF.
- `lib/territory/geocoding/offline_geocoding_service.dart` (Novo: cache Drift TTL 30 dias + rate limit 1s + busca local de contatos/marcos/setores).
- `lib/ui/screens/contacts_map_screen.dart` e `lib/ui/widgets/map_location_picker_dialog.dart`: integração do adapter.
- `test/territory/`: testes dedicados.

---

## 3. Gestão de Risco e Invariantes Offline-First

- **Compatibilidade e Fallback:** O motor raster legado é mantido sob `RasterFallbackAdapter`. Se o dispositivo ou plataforma não suportar renderização GPU MapLibre ou se houver falha de inicialização, o fallback é acionado automaticamente.
- **Fail-Closed e Integridade:** Nenhum pacote inválido ou sem SHA-256 é aceito. Validação de MBTiles reconhece MVT/PBF (bytes gzip `0x1f 0x8b` ou protobuf direto) sem comprometer a validação de formato.
- **Privacidade e Rate Limit:** Consultas ao Nominatim respeitam 1 req/s, e quando offline a busca recorre imediatamente aos dados locais já criptografados no Drift.

---

## 4. Plano de Verificação

1. `flutter pub get` limpo.
2. `flutter test test/territory/` com 100% dos testes aprovados.
3. Testes específicos cobrindo range requests PMTiles, MBTiles vetoriais, endpoints `/z/x/y.pbf`, geocodificação offline, busca FTS5/local e camadas GeoJSON.
