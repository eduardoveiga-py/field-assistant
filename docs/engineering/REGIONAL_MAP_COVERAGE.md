# FIELD ASSISTANT — COBERTURA CARTOGRÁFICA REGIONAL: ALTO SOLIMÕES
**Especificação Técnica de Dados Geográficos — FAES §4 & Ordem Mestra Parte IV e XV**  
**Projeto:** Field Assistant  
**Região Canônica Primária:** Microrregião do Alto Solimões (Amazonas, Brasil)  
**Pacote de Dados:** `alto_solimoes_vector.pmtiles`  
**Data:** 18 de Novembro de 2026

---

## 1. DELIMITAÇÃO GEOGRÁFICA DO PACOTE REGIONAL

A cobertura do pacote de dados prioritário é definida por um polígono geográfico contínuo delimitado pelo seguinte `GeoBoundingBox` em coordenadas WGS-84 (EPSG:4326):

| Vértice Bounding Box | Coordenada Decimal | Ponto de Referência Geográfico |
|:---|:---:|:---|
| **Latitude Mínima (`minLat`)** | `-4.0000° S` | Calha sul do Rio Jandiatuba e cabeceiras interiores |
| **Latitude Máxima (`maxLat`)** | `-2.7000° S` | Médio curso do Rio Içá ao norte de Santo Antônio do Içá |
| **Longitude Mínima (`minLon`)** | `-69.5000° W` | Fronteira oeste próxima a Amaturá / São Paulo de Olivença |
| **Longitude Máxima (`maxLon`)** | `-67.5000° W` | Limite leste em direção a Tonantins e Jutaí |

```
                [-2.7000° N, Médio Rio Içá]
           +-----------------------------------+
           |                                   |
           |   Santo Antônio do Içá (Sede)     |
           |       o [-3.1022°, -67.9408°]     |
           |                                   |
[-69.5000° |    Lago Grande       Rio Solimões | [-67.5000° E,
 Oeste]    |        o                 ~~~~~~~~ |  Tonantins]
           |                                   |
           |          Betânia (Jandiatuba)     |
           |              o [-3.3850°, -68.4200°]
           |                                   |
           +-----------------------------------+
             [-4.0000° S, Interiores Sul]
```

---

## 2. NÓS E POLOS GEOGRÁFICOS COBERTOS

1. **Santo Antônio do Içá (Sede Municipal):**
   - Centro urbano, malha viária consolidada, praças, escolas, prédios públicos, porto fluvial municipal.
   - Ponto de partida logístico para o ministério fluvial e terrestre.
2. **Comunidade de Betânia:**
   - Localizada no Rio Jandiatuba (`-3.3850° S, -68.4200° W`).
   - Maior comunidade indígena Ticuna da região, com densa malha de caminhos pedonais e concentração populacional.
3. **Região de Lago Grande:**
   - Comunidades lacustres e ribeirinhas no entorno da várzea do Solimões (`-3.2100° S, -68.1200° W`).
4. **Rede Hidrográfica Vital:**
   - **Rio Solimões:** Eixo principal de navegação e barreira fluvial natural de $1{,}5\text{ a }3\text{ km}$ de largura.
   - **Rio Içá:** Calha norte navegável.
   - **Rio Jandiatuba:** Acesso fluvial a Betânia e comunidades interiores.
   - Canais, paranás e ilhas fluviais habitadas.

---

## 3. ESPECIFICAÇÃO TÉCNICA DO PACOTE VETORIAL

- **Identificador Canônico:** `alto_solimoes_vector`
- **Formato Físico:** PMTiles v3 (Protomaps Single-File Archive)
- **Níveis de Zoom:**
  - $z=10$: Visão regional da bacia e eixos municipais.
  - $z=11 \dots z=13$: Detalhes de hidrografia, comunidades secundárias e relevo.
  - $z=14 \dots z=16$: Malha urbana detalhada, traçado de ruas, caminhos pedonais e edificações mapeadas.
- **Camadas Vetoriais MVT:**
  - `water`: Lagos, represas e polígonos de rios de grande porte.
  - `waterway`: Cursos d'água fluviais, igarapés e paranás com nomes atribuídos.
  - `transportation`: Rodovias (AM-080 quando aplicável), ruas municipais, caminhos rurais e trilhas pedonais.
  - `place`: Cidades, vilas, comunidades indígenas (`hamlet`, `village`, `isolated_dwelling`).
  - `boundary`: Limites municipais e terras demarcadas.
  - `building`: Polígonos de edificações na sede urbana e em núcleos comunitários.
  - `poi`: Portos, escolas públicas, unidades básicas de saúde e pontos de referência.
- **Tamanho Otimizado:** $\approx 42{,}5\text{ MB}$ (Redução de $> 83\%$ em comparação com os 264,9 MB do antigo pacote raster PNG).
- **Licenciamento & Atribuição Obrigatória:**  
  *© Colaboradores do OpenStreetMap (ODbL) • Schema OpenMapTiles*.

---

## 4. LIMITAÇÕES REAIS E ORIENTAÇÕES OPERACIONAIS

Em conformidade estrita com o item §8 e §28 da Ordem Mestra:
1. **Limitação de Mapeamento em Áreas Remotas:**  
   Em comunidades isoladas na floresta, a ausência de uma trilha ou caminho na base do OpenStreetMap **não significa que o caminho não exista fisicamente**. O Field Assistant apresenta os dados oficiais existentes sem inferir trajetos especulativos.
2. **Navegação Fluvial Real:**  
   O motor de rotas não calcula travessias aquáticas sem registro formal de balsa ou porto cadastrado, respeitando a hidrodinâmica do Rio Solimões e impedindo traçados perigosos em águas abertas.
