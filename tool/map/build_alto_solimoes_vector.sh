#!/usr/bin/env bash
# ==============================================================================
# Field Assistant — Gerador de Pacote Cartográfico Vetorial Alto Solimões (PMTiles v3)
# Task ID: FA-MAP-VECTOR-01 / Milestone 4
#
# Gera o arquivo alto_solimoes.pmtiles contendo camadas vetoriais MVT
# (OpenMapTiles: water, waterways, transportation, places, poi) para zooms 8 a 16,
# abrangendo Santo Antônio do Içá, Aldeia Betânia (Ticuna) e Lago Grande.
#
# Atribuição Obrigatória: Dados © contribuidores do OpenStreetMap (ODbL 1.0)
# ==============================================================================

set -euo pipefail

work="${1:-}"
if [ -z "$work" ]; then
  echo "Uso: $0 <DIRETORIO_DE_TRABALHO>" >&2
  exit 1
fi

mkdir -p "$work" "$work/output" "$work/layers"
work="$(cd "$work" && pwd)"
output="$work/output"
layers="$work/layers"

echo "=== [1/6] Verificando dependências de ferramentas cartográficas ==="
for cmd in curl sha256sum osmium ogr2ogr tippecanoe python3; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERRO CRÍTICO: Ferramenta cartográfica obrigatória '$cmd' não encontrada no PATH." >&2
    echo "O pipeline vetorial regional encerra em modo fail-closed." >&2
    exit 1
  fi
done

echo "=== [2/6] Baixando extrato OpenStreetMap do Amazonas (dados brutos ODbL) ==="
source_url='https://download.openstreetmap.fr/extracts/south-america/brazil/north/amazonas-latest.osm.pbf'
source_pbf="$work/amazonas.osm.pbf"

if [ ! -f "$source_pbf" ]; then
  echo "Baixando $source_url..."
  curl -fL --retry 3 --connect-timeout 30 "$source_url" -o "$source_pbf"
else
  echo "Arquivo $source_pbf já existente, pulando download."
fi

if [ ! -s "$source_pbf" ]; then
  echo "ERRO CRÍTICO: Extrato OSM '$source_pbf' ausente ou vazio." >&2
  exit 1
fi
if ! osmium fileinfo "$source_pbf" &>/dev/null; then
  echo "ERRO CRÍTICO: Extrato OSM '$source_pbf' corrompido ou inválido (falha em osmium fileinfo)." >&2
  exit 1
fi

sha256sum "$source_pbf" > "$output/source-amazonas-sha256.txt"

echo "=== [3/6] Recortando Bounding Box Canônica do Alto Solimões (-69.00, -3.85, -67.50, -2.70) ==="
sai_pbf="$work/alto_solimoes.osm.pbf"
osmium extract --strategy=smart --bbox=-69.00,-3.85,-67.50,-2.70 \
  "$source_pbf" -o "$sai_pbf" --overwrite

if [ ! -s "$sai_pbf" ]; then
  echo "ERRO CRÍTICO: Falha ao gerar extrato recortado '$sai_pbf' (arquivo vazio ou ausente)." >&2
  exit 1
fi

echo "=== [4/6] Extraindo camadas temáticas vetoriais GeoJSON / GeoPackage ==="
# Camadas compatíveis com esquema OpenMapTiles / MapLibre Style:
# 1. water: corpos d'água e margens do Rio Solimões e afluentes
# 2. waterways: rios, igarapés e canais fluviais navegáveis
# 3. transportation: rodovias, estradas vicinais, ramais de aldeia e trilhas
# 4. places: sede municipal, bairros, comunidades indígenas (Betânia) e ribeirinhas
# 5. poi: postos de saúde, escolas, portos, templos e locais de utilidade

ogr2ogr -f GeoJSONSeq "$layers/water.geojsonseq" "$sai_pbf" multipolygons \
  -where "natural IN ('water','bay') OR other_tags LIKE '%riverbank%'"
ogr2ogr -f GeoJSONSeq "$layers/waterways.geojsonseq" "$sai_pbf" lines \
  -where "waterway IS NOT NULL"
ogr2ogr -f GeoJSONSeq "$layers/transportation.geojsonseq" "$sai_pbf" lines \
  -where "highway IS NOT NULL"
ogr2ogr -f GeoJSONSeq "$layers/places.geojsonseq" "$sai_pbf" points \
  -where "place IS NOT NULL AND name IS NOT NULL"
ogr2ogr -f GeoJSONSeq "$layers/poi.geojsonseq" "$sai_pbf" points \
  -where "amenity IS NOT NULL OR leisure IS NOT NULL OR shop IS NOT NULL"

echo "=== [5/6] Gerando arquivo PMTiles v3 através do Tippecanoe ==="
pmtiles_target="$output/alto_solimoes.pmtiles"

tippecanoe \
  -o "$pmtiles_target" \
  --minimum-zoom=8 \
  --maximum-zoom=16 \
  --drop-densest-as-needed \
  --extend-zooms-if-still-dropping \
  --force \
  -l water "$layers/water.geojsonseq" \
  -l waterways "$layers/waterways.geojsonseq" \
  -l transportation "$layers/transportation.geojsonseq" \
  -l places "$layers/places.geojsonseq" \
  -l poi "$layers/poi.geojsonseq"

if [ ! -s "$pmtiles_target" ]; then
  echo "ERRO CRÍTICO: Falha na execução do tippecanoe ou arquivo '$pmtiles_target' vazio." >&2
  exit 1
fi

echo "=== [6/6] Gerando Manifesto Imutável e Checksum SHA-256 ==="
pkg_size=$(stat -c%s "$pmtiles_target" 2>/dev/null || stat -f%z "$pmtiles_target" 2>/dev/null || wc -c < "$pmtiles_target")
pkg_hash=$(sha256sum "$pmtiles_target" | awk '{print $1}')

cat <<EOF > "$output/alto_solimoes_manifest.json"
{
  "id": "alto_solimoes_sai_vector",
  "regionName": "Alto Solimões — Santo Antônio do Içá, Betânia & Lago Grande (Vetorial PMTiles)",
  "downloadUrl": "https://github.com/eduardoveiga-py/field-assistant/releases/download/v2.0.0/alto_solimoes.pmtiles",
  "sizeBytes": $pkg_size,
  "sha256": "$pkg_hash",
  "bbox": {
    "minLat": -3.8500,
    "minLon": -69.0000,
    "maxLat": -2.7000,
    "maxLon": -67.5000
  },
  "minZoom": 8,
  "maxZoom": 16,
  "generatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "version": "2.0.0",
  "license": "ODbL-1.0",
  "attribution": "© OpenStreetMap contributors",
  "format": "pmtiles",
  "minAppSchemaVersion": 1
}
EOF

cat <<EOF > "$output/LEIA-ME.txt"
Field Assistant — Pacote Cartográfico Vetorial Alto Solimões
============================================================
Formato: PMTiles v3 (MVT - Mapbox Vector Tiles)
Região: Santo Antônio do Içá, Comunidade Indígena de Betânia (Ticuna), Lago Grande.
Bounding Box WGS-84: [-68.20, -3.40, -67.70, -3.00]
Níveis de Zoom: 8 a 16
Licença dos Dados: Open Database License (ODbL) 1.0
Atribuição Obrigatória: © Contribuidores do OpenStreetMap (https://www.openstreetmap.org/copyright)
Hash SHA-256: $pkg_hash
EOF

(cd "$output" && sha256sum alto_solimoes.pmtiles alto_solimoes_manifest.json > SHA256SUMS.txt 2>/dev/null || true)

echo "Construção de pacote vetorial concluída em $output."
