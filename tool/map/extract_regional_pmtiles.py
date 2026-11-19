#!/usr/bin/env python3
"""Extract an experimental regional PMTiles basemap, never publish it.

Requires the official pmtiles CLI and mapbox-vector-tile. The caller is
responsible for rights to the source and for testing coverage and rendering.
"""
import argparse
import datetime as dt
import gzip
import hashlib
import io
import json
import math
import os
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import urlsplit


def run(*args):
    return subprocess.run(args, check=True, stdout=subprocess.PIPE).stdout


def bbox_arg(value):
    try:
        west, south, east, north = (float(x) for x in value.split(','))
    except ValueError as exc:
        raise argparse.ArgumentTypeError('bbox deve conter oeste,sul,leste,norte') from exc
    if not all(math.isfinite(x) for x in (west, south, east, north)) or not (-180 <= west < east <= 180 and -85 <= south < north <= 85):
        raise argparse.ArgumentTypeError('bbox inválida ou cruza o antimeridiano')
    return west, south, east, north


def sample_arg(value):
    try:
        lon, lat = (float(x) for x in value.split(','))
    except ValueError as exc:
        raise argparse.ArgumentTypeError('amostra deve conter longitude,latitude') from exc
    if not math.isfinite(lon) or not math.isfinite(lat):
        raise argparse.ArgumentTypeError('coordenadas não finitas')
    return lon, lat


def tile_for(lon, lat, zoom):
    n = 2 ** zoom
    x = math.floor((lon + 180) / 360 * n)
    rad = math.radians(lat)
    y = math.floor((1 - math.asinh(math.tan(rad)) / math.pi) / 2 * n)
    return zoom, min(max(x, 0), n - 1), min(max(y, 0), n - 1)


def inspect_header(path, bbox, minzoom, maxzoom):
    with path.open('rb') as stream:
        header = stream.read(127)
    if len(header) != 127 or header[:8] != b'PMTiles\x03':
        raise ValueError('Arquivo não é PMTiles v3')
    if header[99] != 1 or header[98] not in (1, 2):
        raise ValueError('Exige tiles vetoriais MVT sem compressão ou gzip')
    if header[100] != minzoom or header[101] != maxzoom:
        raise ValueError('Intervalo de zoom do arquivo difere do solicitado')
    if any(struct.unpack_from('<Q', header, offset)[0] == 0 for offset in (16, 32, 64, 72, 80, 88)):
        raise ValueError('Arquivo sem diretório, metadados ou tiles')
    bounds = tuple(v / 1e7 for v in struct.unpack_from('<iiii', header, 102))
    if any(abs(a - b) > 0.000001 for a, b in zip(bounds, bbox)):
        raise ValueError('Limites no arquivo diferem da região solicitada')
    return {'bounds': bounds, 'minzoom': header[100], 'maxzoom': header[101], 'tileCompression': header[98]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True, help='PMTiles local ou HTTPS que autorize extração')
    parser.add_argument('--source-description', required=True)
    parser.add_argument('--license', required=True)
    parser.add_argument('--attribution', required=True)
    parser.add_argument('--bbox', required=True, type=bbox_arg)
    parser.add_argument('--sample', required=True, action='append', type=sample_arg, help='longitude,latitude dentro da bbox; repetir para locais representativos')
    parser.add_argument('--minzoom', type=int, default=0)
    parser.add_argument('--maxzoom', type=int, default=14)
    parser.add_argument('--output', required=True, type=Path, help='diretório novo, nunca sobrescrito')
    args = parser.parse_args()
    if not 0 <= args.minzoom <= args.maxzoom <= 22:
        parser.error('intervalo de zoom inválido')
    if any(not (args.bbox[0] <= lon <= args.bbox[2] and args.bbox[1] <= lat <= args.bbox[3]) for lon, lat in args.sample):
        parser.error('amostra fora da bbox')
    if not all(x.strip() for x in (args.source_description, args.license, args.attribution)):
        parser.error('fonte, licença e atribuição não podem estar vazias')
    if '://' in args.source:
        url = urlsplit(args.source)
        if url.scheme != 'https' or not url.hostname or url.username or url.password or url.query or url.fragment:
            parser.error('origem remota deve ser HTTPS sem credenciais, query ou fragmento')
    elif not Path(args.source).is_file():
        parser.error('origem local não existe')
    cli = shutil.which('pmtiles')
    if not cli:
        parser.error('pmtiles CLI não encontrado; nenhum pacote foi criado')
    try:
        import mapbox_vector_tile
    except ImportError:
        parser.error('mapbox-vector-tile não instalado; nenhum pacote foi criado')
    output = args.output.absolute()
    if output.exists():
        parser.error('diretório de saída já existe; nenhum arquivo será substituído')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.pmtiles-stage-', dir=output.parent) as tmp:
        stage = Path(tmp) / 'package'
        stage.mkdir()
        archive = stage / 'regional.pmtiles'
        bbox_string = ','.join(str(v) for v in args.bbox)
        run(cli, 'extract', args.source, str(archive), f'--bbox={bbox_string}', f'--minzoom={args.minzoom}', f'--maxzoom={args.maxzoom}')
        run(cli, 'verify', str(archive))
        header = inspect_header(archive, args.bbox, args.minzoom, args.maxzoom)
        metadata = json.loads(run(cli, 'show', str(archive), '--metadata'))
        layer_ids = {x['id'] for x in metadata.get('vector_layers', []) if isinstance(x, dict) and isinstance(x.get('id'), str)}
        if not layer_ids:
            raise ValueError('Metadados sem vector_layers')
        sample_records = []
        for lon, lat in args.sample:
            z, x, y = tile_for(lon, lat, min(args.maxzoom, max(args.minzoom, 14)))
            tile = run(cli, 'tile', str(archive), str(z), str(x), str(y))
            if len(tile) > 16 * 1024 * 1024:
                raise ValueError('Amostra de tile comprimido excede 16 MiB')
            if header['tileCompression'] == 2:
                with gzip.GzipFile(fileobj=io.BytesIO(tile)) as compressed:
                    tile = compressed.read(16 * 1024 * 1024 + 1)
            if len(tile) > 16 * 1024 * 1024:
                raise ValueError('Amostra de tile descompactado excede 16 MiB')
            decoded = mapbox_vector_tile.decode(tile)
            counts = {name: len(layer.get('features', [])) for name, layer in decoded.items() if isinstance(layer, dict)}
            if not counts or sum(counts.values()) == 0 or not set(counts).issubset(layer_ids):
                raise ValueError(f'Amostra {z}/{x}/{y} vazia ou incompatível com metadados')
            sample_records.append({'longitude': lon, 'latitude': lat, 'tile': [z, x, y], 'featureCounts': counts})
        sha = hashlib.sha256()
        with archive.open('rb') as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                sha.update(chunk)
        provenance = {
            'status': 'experimental-not-published', 'source': args.source,
            'sourceDescription': args.source_description, 'license': args.license,
            'attribution': args.attribution, 'createdAt': dt.datetime.now(dt.timezone.utc).isoformat(),
            'sizeBytes': archive.stat().st_size, 'sha256': sha.hexdigest(),
            'header': header, 'metadata': metadata, 'samples': sample_records,
            'pmtilesVersion': run(cli, 'version').decode('utf-8', errors='replace').strip(),
        }
        (stage / 'provenance.json').write_text(json.dumps(provenance, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        # Reservar diretório exclusivamente; links falham se um arquivo já
        # existir. provenance.json é criado por último como sinal de conclusão.
        # Em interrupção pode restar diretório parcial, nunca um catálogo ativo.
        os.mkdir(output)
        os.link(archive, output / 'regional.pmtiles')
        os.link(stage / 'provenance.json', output / 'provenance.json')
    print(f'Pacote experimental verificado: {output} (não publicado; não usar para navegação)')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        print(f'Falha na extração/validação: {exc}', file=sys.stderr)
        sys.exit(1)
