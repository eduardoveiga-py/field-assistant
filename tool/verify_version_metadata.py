#!/usr/bin/env python3
"""Validate development version and published catalogue without inventing a release."""
import json
import os
import re
from pathlib import Path


def validate(pubspec: str, app_version: str, catalog: dict, ref: str) -> str:
    version = re.search(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)', pubspec, re.M)
    app = re.search(r"static const String version\s*=\s*'([^']+)'", app_version)
    build = re.search(r'static const int buildNumber\s*=\s*(\d+)', app_version)
    if not version or not app or not build:
        raise ValueError('Versão do aplicativo ausente')
    current, build_number = version.groups()
    if app.group(1) != current or build.group(1) != build_number:
        raise ValueError('pubspec e AppVersion divergentes')
    first = catalog['apps'][0]
    published = first['version']
    if not re.fullmatch(r'\d+\.\d+\.\d+', published):
        raise ValueError('Versão do catálogo inválida')
    if tuple(map(int, published.split('.'))) > tuple(map(int, current.split('.'))):
        raise ValueError('Catálogo anuncia versão futura')
    expected = f'/releases/download/v{published}/'
    if expected not in first['downloadURL'] or first['size'] <= 0:
        raise ValueError('URL ou tamanho do pacote publicado inválido')
    if not first['versions'] or first['versions'][0]['version'] != published:
        raise ValueError('Histórico do catálogo divergente')
    if first['versions'][0]['downloadURL'] != first['downloadURL'] or first['versions'][0]['size'] != first['size']:
        raise ValueError('Artefato principal e histórico divergentes')
    for url in (catalog['iconURL'], catalog['headerURL'], first['iconURL']):
        if f'@v{published}/' not in url or '@master' in url or '@main' in url:
            raise ValueError('Ícone não está fixado na versão publicada')
    if '@master' in catalog['sourceURL'] or '@main' in catalog['sourceURL']:
        raise ValueError('Fonte usa branch mutável')
    if ref.startswith('refs/tags/v'):
        if ref != f'refs/tags/v{current}' or published != current:
            raise ValueError('Tag, build e manifesto precisam coincidir na publicação')
    return f'Build {current}+{build_number}; catálogo {published}; ref {ref or "local"}'


if __name__ == '__main__':
    print(validate(Path('pubspec.yaml').read_text(),
                   Path('lib/core/app_version.dart').read_text(),
                   json.loads(Path('apps.json').read_text()),
                   os.environ.get('GITHUB_REF', '')))
