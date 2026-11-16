"""Verificações estruturais mínimas; não asseguram qualidade cartográfica."""
import math
import sqlite3
import sys

path = sys.argv[1]
with sqlite3.connect(f'file:{path}?mode=ro', uri=True) as db:
    assert db.execute('PRAGMA quick_check').fetchone()[0] == 'ok'
    counts = dict(db.execute('SELECT zoom_level,count(*) FROM tiles GROUP BY zoom_level'))
    assert all(counts.get(z, 0) > 0 for z in range(8, 17)), counts
    z, lon, lat = 16, -67.94, -3.10194
    x = int((lon + 180) / 360 * (1 << z))
    y = int((1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * (1 << z))
    tile = db.execute('SELECT tile_data FROM tiles WHERE zoom_level=? AND tile_column=? AND tile_row=?',
                      (z, x, (1 << z) - 1 - y)).fetchone()
    assert tile and tile[0].startswith(b'\x89PNG\r\n\x1a\n'), 'tile raster TMS da sede ausente'
    print('Integridade estrutural OK; tiles por zoom:', counts)
