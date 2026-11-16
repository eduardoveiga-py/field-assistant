"""Verify coverage and metadata of the actual generated MBTiles artifact."""
import math
import sqlite3
import sys

west, south, east, north = -69.95, -3.85, -67.65, -2.32

def xyz(lon, lat, z):
    x = int((lon + 180) / 360 * (1 << z))
    y = int((1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * (1 << z))
    return x, y

with sqlite3.connect(f'file:{sys.argv[1]}?mode=ro', uri=True) as db:
    assert db.execute('PRAGMA quick_check').fetchone()[0] == 'ok'
    meta = dict(db.execute('SELECT name,value FROM metadata'))
    assert meta.get('scheme') == 'tms' and meta.get('format') == 'png', meta
    assert 'OpenStreetMap' in meta.get('attribution', '')
    counts = []
    for z in range(8, 17):
        x0, y0 = xyz(west, north, z)
        x1, y1 = xyz(east, south, z)
        row0, row1 = (1 << z) - 1 - y1, (1 << z) - 1 - y0
        expected = (x1-x0+1) * (y1-y0+1)
        actual = db.execute('''SELECT count(DISTINCT tile_column || ':' || tile_row)
            FROM tiles WHERE zoom_level=? AND tile_column BETWEEN ? AND ? AND tile_row BETWEEN ? AND ?''',
            (z, x0, x1, row0, row1)).fetchone()[0]
        if actual != expected:
            raise AssertionError(f'zoom {z}: {actual} of {expected} tiles in extent')
        counts.append(f'z{z}={actual}')
    print('::notice title=SAI coverage::Validated entire rectangle -69.95,-3.85,-67.65,-2.32; ' + ', '.join(counts))
