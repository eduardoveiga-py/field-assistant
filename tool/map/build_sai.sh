#!/usr/bin/env bash
set -euo pipefail
export QT_QPA_PLATFORM=offscreen
work="${1:?usage: build_sai.sh WORKDIR}"
mkdir -p "$work" "$work/output"
work="$(cd "$work" && pwd)"
source_url='https://download.openstreetmap.fr/extracts/south-america/brazil/north/amazonas-latest.osm.pbf'
curl -fL --retry 3 --connect-timeout 30 "$source_url" -o "$work/amazonas.osm.pbf"
sha256sum "$work/amazonas.osm.pbf" > "$work/output/source-sha256.txt"
osmium fileinfo "$work/amazonas.osm.pbf" > "$work/output/source-info.txt"
osmium extract --strategy=smart --bbox=-69.95,-3.85,-67.65,-2.32 \
  "$work/amazonas.osm.pbf" -o "$work/sai.osm.pbf" --overwrite
input="$work/sai.osm.pbf"
gpkg="$work/sai.gpkg"
# Extrações de dados brutos, não de blocos do servidor público OSM.
ogr2ogr -f GPKG "$gpkg" "$input" multipolygons -nln water \
  -where "natural IN ('water','bay') OR other_tags LIKE '%riverbank%'" -lco SPATIAL_INDEX=YES
ogr2ogr -update "$gpkg" "$input" multipolygons -nln land \
  -where "landuse IS NOT NULL OR natural IN ('wood','scrub','wetland')" -lco SPATIAL_INDEX=YES
ogr2ogr -update "$gpkg" "$input" lines -nln waterways -where "waterway IS NOT NULL" -lco SPATIAL_INDEX=YES
ogr2ogr -update "$gpkg" "$input" lines -nln roads -where "highway IS NOT NULL" -lco SPATIAL_INDEX=YES
ogr2ogr -update "$gpkg" "$input" points -nln places -where "place IS NOT NULL AND name IS NOT NULL" -lco SPATIAL_INDEX=YES
/usr/bin/python3 tool/map/render_sai_qgis.py "$gpkg" "$work/output/sai-experimental.mbtiles"
/usr/bin/python3 tool/map/verify_sai.py "$work/output/sai-experimental.mbtiles"
cp tool/map/README.md "$work/output/LEIA-ME.txt"
(cd "$work/output" && sha256sum sai-experimental.mbtiles > SHA256SUMS.txt)
