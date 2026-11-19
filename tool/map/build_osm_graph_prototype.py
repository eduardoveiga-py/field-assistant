#!/usr/bin/env python3
"""Build a bounded OSM graph prototype; output must never be used to navigate.

Input is a small, complete local OSM XML (optionally gzip), not a PBF. This
research tool rejects known unsupported restrictions rather than ignoring them.
Even accepted extracts can omit critical data; the output is NOT production-safe.
"""
import argparse
import gzip
import hashlib
import json
import math
import os
from pathlib import Path
import re
import sys
import tempfile
import xml.etree.ElementTree as ET
import zlib

MAX_INPUT_BYTES = 16 * 1024 * 1024
MAX_ELEMENTS = 500_000
# Research defaults only; actual legal access varies by region and other tags.
ROAD_DEFAULTS = {
    'motorway': (False, True), 'motorway_link': (False, True),
    'trunk': (False, True), 'trunk_link': (False, True),
    'primary': (True, True), 'primary_link': (True, True),
    'secondary': (True, True), 'secondary_link': (True, True),
    'tertiary': (True, True), 'tertiary_link': (True, True),
    'unclassified': (True, True), 'residential': (True, True),
    'living_street': (True, True), 'service': (True, True),
    'pedestrian': (True, False), 'footway': (True, False),
    'path': (True, False), 'steps': (True, False),
    'cycleway': (False, False),
}
ALLOW = {'yes', 'designated', 'permissive'}
DENY = {'no', 'private', 'destination', 'customers', 'delivery', 'agricultural', 'forestry'}
DIRECTION = {'yes': 1, 'true': 1, '1': 1, 'no': 0, 'false': 0, '0': 0, '-1': -1}


def _id(value, label):
    if not isinstance(value, str) or not re.fullmatch(r'[1-9][0-9]{0,18}', value):
        raise ValueError(f'{label}: identificador inválido')
    if int(value) > 9223372036854775807:
        raise ValueError(f'{label}: identificador fora do limite')
    return value


def _tags(element):
    result = {}
    for item in element.findall('tag'):
        key, value = item.get('k'), item.get('v')
        if key is None or value is None or not key or key in result:
            raise ValueError('Tag ausente ou duplicada')
        result[key] = value
    return result


def _access(tags, hierarchy, default):
    allowed = default
    for key in hierarchy:
        if key not in tags:
            continue
        value = tags[key].lower()
        if value in ALLOW:
            allowed = True
        elif value in DENY:
            allowed = False
        else:
            raise ValueError(f'Restrição de acesso não suportada: {key}')
    return allowed


def _direction(tags, keys, default=0):
    result = default
    for key in keys:
        if key in tags:
            value = tags[key].lower()
            if value not in DIRECTION:
                raise ValueError(f'Sentido não suportado: {key}')
            result = DIRECTION[value]
    return result


def _distance(a, b):
    lat1, lon1, lat2, lon2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    angle = math.sin((lat2-lat1)/2)**2 + math.cos(lat1)*math.cos(lat2)*math.sin((lon2-lon1)/2)**2
    return 2 * 6371008.8 * math.asin(min(1.0, math.sqrt(max(0.0, angle))))


def build_graph(xml_bytes, *, source_sha256, source_info, license_name, attribution):
    if len(xml_bytes) > MAX_INPUT_BYTES:
        raise ValueError('XML descompactado excede limite experimental')
    if b'\x00' in xml_bytes:
        raise ValueError('XML deve usar UTF-8 sem bytes NUL')
    try:
        xml_bytes.decode('utf-8')
    except UnicodeDecodeError as exc:
        raise ValueError('XML deve usar UTF-8') from exc
    if re.search(br'<!\s*(DOCTYPE|ENTITY)\b', xml_bytes, re.IGNORECASE):
        raise ValueError('DTD ou entidade XML não é permitida')
    try:
        root = ET.fromstring(xml_bytes)
    except ET.ParseError as exc:
        raise ValueError('XML OSM inválido') from exc
    if root.tag != 'osm' or root.get('version') != '0.6':
        raise ValueError('Exige snapshot osm version 0.6, não diff')
    if len(root) > MAX_ELEMENTS:
        raise ValueError('Extrato excede limite de elementos')
    nodes, ways = {}, []
    way_ids, restricted_nodes = set(), set()
    for element in root:
        if element.tag not in {'node', 'way', 'relation', 'bounds'}:
            raise ValueError('Elemento OSM desconhecido')
        if element.tag == 'bounds':
            continue
        if element.get('action') or element.get('visible') == 'false':
            raise ValueError('Diff ou item removido não é snapshot utilizável')
        identifier = _id(element.get('id'), element.tag)
        tags = _tags(element)
        if element.tag == 'node':
            if identifier in nodes:
                raise ValueError('Nó duplicado')
            try:
                lat, lon = float(element.attrib['lat']), float(element.attrib['lon'])
            except (KeyError, ValueError) as exc:
                raise ValueError('Coordenada ausente ou inválida') from exc
            if not all(math.isfinite(x) for x in (lat, lon)) or not (-90 <= lat <= 90 and -180 <= lon <= 180):
                raise ValueError('Coordenada inválida')
            nodes[identifier] = (lat, lon)
            if 'barrier' in tags or 'ford' in tags or any('conditional' in k for k in tags):
                restricted_nodes.add(identifier)
        elif element.tag == 'relation':
            if tags.get('type', '').startswith('restriction') or any(k.startswith('restriction') for k in tags):
                raise ValueError('Restrições de manobra não implementadas')
        else:
            if identifier in way_ids:
                raise ValueError('Via duplicada')
            way_ids.add(identifier)
            if tags.get('route') == 'ferry':
                raise ValueError('Balsa não suportada')
            if 'highway' not in tags:
                continue
            kind = tags['highway']
            if kind not in ROAD_DEFAULTS:
                raise ValueError(f'Tipo de via não suportado: {kind}')
            if tags.get('area') == 'yes':
                raise ValueError('Área não é uma via linear suportada')
            if any('conditional' in k for k in tags):
                raise ValueError('Restrição condicional não suportada')
            if any(k in tags for k in ('ford', 'impassable', 'maxheight', 'maxwidth', 'maxweight', 'maxaxleload')):
                raise ValueError('Restrição física ou travessia não suportada')
            relevant = ('access', 'foot', 'vehicle', 'motor_vehicle', 'motorcar')
            if any(k.startswith(tuple(f'{x}:' for x in relevant)) for k in tags):
                raise ValueError('Restrição direcional ou específica não suportada')
            refs = [_id(nd.get('ref'), 'referência') for nd in element.findall('nd')]
            if len(refs) < 2:
                raise ValueError('Via sem dois nós')
            ways.append((identifier, refs, tags))
    if not nodes or not ways:
        raise ValueError('Extrato sem nós ou vias reconhecidas')
    edges, used = [], set()
    for way_id, refs, tags in ways:
        if any(ref not in nodes for ref in refs):
            raise ValueError('Via possui referência de nó ausente')
        if any(ref in restricted_nodes for ref in refs):
            raise ValueError('Via contém barreira ou condição não suportada')
        walk_default, drive_default = ROAD_DEFAULTS[tags['highway']]
        walk = _access(tags, ('access', 'foot'), walk_default)
        drive = _access(tags, ('access', 'vehicle', 'motor_vehicle', 'motorcar'), drive_default)
        default_oneway = 1 if tags['highway'] in {'motorway', 'motorway_link'} or tags.get('junction') in {'roundabout', 'circular'} else 0
        drive_dir = _direction(tags, ('oneway', 'oneway:vehicle', 'oneway:motor_vehicle', 'oneway:motorcar'), default_oneway)
        walk_dir = _direction(tags, ('oneway:foot',))
        for a, b in zip(refs, refs[1:]):
            if a == b:
                raise ValueError('Segmento com nó repetido')
            distance = _distance(nodes[a], nodes[b])
            if not math.isfinite(distance) or distance <= 0:
                raise ValueError('Segmento sem comprimento válido')
            for start, end, sign in ((a, b, 1), (b, a, -1)):
                pedestrian = walk and walk_dir in (0, sign)
                vehicle = drive and drive_dir in (0, sign)
                if pedestrian or vehicle:
                    edges.append({'from': start, 'to': end, 'wayId': way_id,
                                  'distanceMeters': distance,
                                  'pedestrian': pedestrian, 'vehicle': vehicle,
                                  'name': tags.get('name', '')})
                    used.update((start, end))
    if not edges:
        raise ValueError('Nenhum segmento acessível no protótipo')
    return {
        'format': 'field-assistant-osm-graph-research-v1',
        'status': 'experimental-not-for-navigation',
        'sourceSha256': source_sha256,
        'sourceDescription': source_info,
        'license': license_name,
        'attribution': attribution,
        'coverageVerified': False,
        'restrictionsSupported': False,
        'nodes': [{'id': n, 'latitude': nodes[n][0], 'longitude': nodes[n][1]} for n in sorted(used, key=int)],
        'edges': edges,
    }


def build_file(source, output, *, expected_sha256, source_info, license_name, attribution):
    if not re.fullmatch(r'[a-fA-F0-9]{64}', expected_sha256):
        raise ValueError('SHA-256 de origem inválido')
    if not all(x.strip() for x in (source_info, license_name, attribution)):
        raise ValueError('Origem, licença e atribuição são obrigatórias')
    with source.open('rb') as stream:
        data = stream.read(MAX_INPUT_BYTES + 1)
    if len(data) > MAX_INPUT_BYTES:
        raise ValueError('Arquivo de entrada excede limite experimental')
    digest = hashlib.sha256(data).hexdigest()
    if digest != expected_sha256.lower():
        raise ValueError('SHA-256 da origem não confere')
    if data.startswith(b'\x1f\x8b'):
        import io
        try:
            with gzip.GzipFile(fileobj=io.BytesIO(data)) as stream:
                xml_bytes = stream.read(MAX_INPUT_BYTES + 1)
        except (OSError, EOFError, zlib.error) as exc:
            raise ValueError('Gzip inválido') from exc
    else:
        xml_bytes = data
    graph = build_graph(xml_bytes, source_sha256=digest, source_info=source_info,
                        license_name=license_name, attribution=attribution)
    payload = (json.dumps(graph, ensure_ascii=False, separators=(',', ':'), allow_nan=False) + '\n').encode('utf-8')
    # Exclusive hard link in same directory: never overwrite an existing file.
    # Temporary bytes are removed even if the link fails.
    tmp = None
    try:
        with tempfile.NamedTemporaryFile(prefix='.osm-graph-', dir=output.parent, delete=False) as file:
            tmp = Path(file.name)
            file.write(payload)
            file.flush()
            os.fsync(file.fileno())
        os.link(tmp, output)
    finally:
        if tmp is not None:
            tmp.unlink(missing_ok=True)
    return graph


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--source-sha256', required=True)
    parser.add_argument('--source-description', required=True)
    parser.add_argument('--license', required=True)
    parser.add_argument('--attribution', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    build_file(args.source, args.output, expected_sha256=args.source_sha256,
               source_info=args.source_description, license_name=args.license,
               attribution=args.attribution)
    print('Grafo experimental gerado; não utilizar para navegação.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError) as exc:
        print(f'Falha: {exc}', file=sys.stderr)
        sys.exit(1)
