---
name: map-engine-architect
description: Orienta desenvolvimento e manutenção do motor de mapas offline (MapLibre, PMTiles, MBTiles, servidor local de tiles, estilos OpenMapTiles e busca FTS5) no field-assistant.
---

# Skill: Map Engine Architect

Esta skill estabelece os princípios de arquitetura, integridade cartográfica offline e performance para o motor de mapas vetoriais e raster do aplicativo `field-assistant`.

## 1. Integridade de Estilos e Esquemas de Tiles (`assets/map/style_offline_*.json`)

- **IDs de Camadas Base:**
  - Preservar os 6 IDs base fundamentais de renderização nos estilos claro e escuro (`style_offline_light.json` e `style_offline_dark.json`):
    - `background`
    - `water`
    - `landuse-residential`
    - `building`
    - `road`
    - `poi-level-1` (ou camadas de anotações e rótulos vetoriais)
  - Modificações de layout ou cores nunca devem remover nem renomear esses identificadores de camadas, pois o subsistema de tematização dinâmica depende de sua existência.

- **Zoom Máximo Vetorial (`maxzoom: 16`):**
  - Manter rigorosamente `maxzoom: 16` na fonte vetorial `openmaptiles`.
  - A renderização em níveis de zoom superiores (ex.: zoom 17 e 18) é viabilizada por *overzoom* automático pelo MapLibre, sem gerar requisições de tiles ausentes para o servidor local.

## 2. Servidor Local de Tiles (`offline_tile_server_io.dart`)

- **Cache LRU e Cabeçalhos HTTP:**
  - Manter o cache LRU de tiles decodificados em memória para respostas rápidas (`< 5ms`).
  - Responder sempre com cabeçalho `Cache-Control: public, max-age=86400, immutable` para permitir que o cliente de renderização reutilize os buffers de tiles.
  - Servir o Content-Type apropriado: `application/x-protobuf` para tiles PBF e `image/png` / `image/jpeg` para raster.

- **Encerramento e Pool SQLite em `stop()`:**
  - Ao invocar o método `stop()`, o servidor HTTP deve ser fechado e todas as instâncias e conexões com o arquivo SQLite (`.mbtiles`) DEVEM ser explicitamente fechadas (`db.dispose()` ou `db.close()`).
  - O fechamento previne bloqueio de arquivo no Windows e vazamento de file descriptors no iOS/Android.

## 3. Isolamento Multiplataforma (Conditional Imports)

- Qualquer acesso ao sistema de arquivos local (`dart:io`), SQLite nativo ou pacotes de I/O em disco deve estar isolado por *conditional imports*:
  - Implementação nativa em `offline_tile_server_io.dart`.
  - Implementação Web/fallback em `offline_tile_server_web.dart`.
  - Exportação unificada através de `offline_tile_server.dart`.
- O alvo Web nunca deve quebrar ao ser inicializado sem capacidades de loopback server nativo.

## 4. Estabilidade do Widget `MapLibreMap` e Gestos de Pinça

- **Evitar `ValueKey` Destrutiva:**
  - Nunca aplique `ValueKey` que mude com frequência na raiz do widget `MapLibreMap`. Mudanças de chave forçam a destruição da `SurfaceView` / `EAGLView` nativa e do estado do GL, causando cintilação preta (black screen flicker) e reinicialização completa do motor C++.

- **Gestos de Pinça (`pointerCount >= 2`):**
  - Durante interações de zoom com múltiplos toques / pinça (`pointerCount >= 2`), NUNCA dispare chamadas contínuas de `setState()` no widget pai do mapa.
  - Delegue a transformação contínua à controladora interna do MapLibre e sincronize o estado do aplicativo apenas no evento de finalização do gesto (`onCameraIdle`).
