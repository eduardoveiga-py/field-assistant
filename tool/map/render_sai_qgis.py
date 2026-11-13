"""Renderiza dados vetoriais OSM locais para MBTiles raster, sem baixar tiles.

Executar com Python do sistema contendo PyQGIS + processing e QT_QPA_PLATFORM=offscreen.
O GeoPackage é produzido por build_sai.sh a partir do extrato PBF autorizado.
"""
import os
import sqlite3
import sys
from pathlib import Path

os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
sys.path.extend(['/usr/share/qgis/python', '/usr/share/qgis/python/plugins'])
from qgis.core import (QgsApplication, QgsCoordinateReferenceSystem, QgsProject,
    QgsVectorLayer, QgsFillSymbol, QgsLineSymbol, QgsMarkerSymbol,
    QgsSingleSymbolRenderer, QgsPalLayerSettings, QgsVectorLayerSimpleLabeling,
    QgsTextFormat, QgsTextBufferSettings)
from qgis.PyQt.QtGui import QColor, QFont

app = QgsApplication([], True)
app.initQgis()
import processing
from processing.core.Processing import Processing
Processing.initialize()

geopackage, output = sys.argv[1:3]
project = QgsProject.instance()
project.setCrs(QgsCoordinateReferenceSystem('EPSG:3857'))


def add_layer(name, symbol, label=False):
    layer = QgsVectorLayer(f'{geopackage}|layername={name}', name, 'ogr')
    if not layer.isValid():
        raise RuntimeError(f'Camada OSM inválida: {name}')
    layer.setRenderer(QgsSingleSymbolRenderer(symbol))
    if label:
        settings = QgsPalLayerSettings()
        settings.fieldName = 'name'
        fmt = QgsTextFormat()
        fmt.setFont(QFont('DejaVu Sans', 9))
        fmt.setSize(9)
        fmt.setColor(QColor('#303b32'))
        buffer = QgsTextBufferSettings()
        buffer.setEnabled(True)
        buffer.setSize(0.8)
        buffer.setColor(QColor('#ffffff'))
        fmt.setBuffer(buffer)
        settings.setFormat(fmt)
        layer.setLabeling(QgsVectorLayerSimpleLabeling(settings))
        layer.setLabelsEnabled(True)
    project.addMapLayer(layer)
    print(f'{name}: {layer.featureCount()} elementos', flush=True)
    return layer

# Ordem de inserção: QGIS desenha a camada mais recentemente inserida no topo.
add_layer('land', QgsFillSymbol.createSimple({'color': '#dfead3', 'outline_style': 'no'}))
water = add_layer('water', QgsFillSymbol.createSimple({'color': '#a8d5e8', 'outline_style': 'no'}))
waterways = add_layer('waterways', QgsLineSymbol.createSimple({'line_color': '#75b8d6', 'line_width': '0.35'}))
roads = add_layer('roads', QgsLineSymbol.createSimple({'line_color': '#ac8d71', 'line_width': '0.28'}))
places = add_layer('places', QgsMarkerSymbol.createSimple({'name': 'circle', 'color': '#68605b', 'outline_color': '#ffffff', 'size': '1.2'}), label=True)
if water.featureCount() + waterways.featureCount() == 0:
    raise RuntimeError('Nenhum curso ou área de água: abortando para evitar mapa enganoso.')
if places.featureCount() == 0:
    raise RuntimeError('Nenhuma localidade no extrato: abortando para permitir investigação.')

registry = QgsApplication.processingRegistry()
algorithm = next((name for name in ['native:tilesxyzmbtiles', 'qgis:tilesxyzmbtiles']
                  if registry.algorithmById(name)), None)
if algorithm is None:
    raise RuntimeError('Algoritmo de MBTiles raster do QGIS não disponível')
# Retângulo envolve os limites IBGE conhecidos, com margem. Não identifica
# comunidades fora do retângulo e contém áreas vizinhas ao município.
params = {'EXTENT': '-69.95,-67.65,-3.85,-2.32 [EPSG:4326]',
          'ZOOM_MIN': 8, 'ZOOM_MAX': 16, 'DPI': 96,
          'BACKGROUND_COLOR': QColor('#f4f1e8'), 'TILE_FORMAT': 0,
          'QUALITY': 85, 'METATILESIZE': 4, 'OUTPUT_FILE': output}
print('Renderizando:', algorithm, params, flush=True)
processing.run(algorithm, params)
if not Path(output).is_file():
    raise RuntimeError('QGIS não criou MBTiles')

# MBTiles padrão usa linhas TMS. Metadados deixam explícitos fonte e limites.
with sqlite3.connect(output) as db:
    db.execute('CREATE TABLE IF NOT EXISTS metadata (name TEXT, value TEXT)')
    metadata = {'name': 'Santo Antônio do Içá e entorno - experimental',
                'description': 'Mapa experimental; dados podem estar incompletos. Não usar para navegação.',
                'attribution': '© contribuidores do OpenStreetMap; openstreetmap.org/copyright',
                'scheme': 'tms', 'format': 'png', 'minzoom': '8', 'maxzoom': '16',
                'bounds': '-69.95,-3.85,-67.65,-2.32'}
    for key, value in metadata.items():
        db.execute('DELETE FROM metadata WHERE name = ?', (key,))
        db.execute('INSERT INTO metadata (name,value) VALUES (?,?)', (key, value))
print('Arquivo criado:', output, flush=True)
app.exitQgis()
