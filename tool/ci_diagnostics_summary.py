"""Expose concise CI diagnostics as a check annotation when full logs are unavailable."""
import re
import sys
from pathlib import Path

mode, filename = sys.argv[1:]
lines = Path(filename).read_text(encoding='utf-8', errors='replace').splitlines()
if mode == 'analyze':
    from collections import Counter
    relevant = [line for line in lines if line.startswith(('ERROR|', 'WARNING|'))]
    info_lines = [line for line in lines if line.startswith('INFO|')]
    counts = Counter(line.split('|')[2] for line in info_lines if len(line.split('|')) > 2)
    selected = [f'Errors/warnings: {len(relevant)}. Informational diagnostics: {len(info_lines)}.',
                'Info categories: ' + ', '.join(f'{k}: {v}' for k, v in counts.most_common())]
    selected += relevant[:50]
else:
    # Ordinary debug logs can contain expected exceptions. Prioritize actual
    # failed-test markers, compiler errors, and final summaries.
    failures = [i for i, line in enumerate(lines)
                if re.search(r'\[E\]|^.*Error:|Failed to load|Some tests failed|timed out', line, re.I)
                and '[DEBUG]' not in line and '[ERROR]' not in line]
    selected = ['Final test output:'] + lines[-15:] + ['Failure excerpts:']
    for i in failures[:20]:
        selected.extend(lines[max(0, i-1):min(len(lines), i+5)])
# GitHub limits annotation messages to approximately 4096 characters.
text = '\n'.join(selected)[:3500]
text = text.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
print(f'::error title=CI diagnostic summary::{text}')
