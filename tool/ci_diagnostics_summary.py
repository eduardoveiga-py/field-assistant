"""Expose concise CI diagnostics as a check annotation when full logs are unavailable."""
import re
import sys
from pathlib import Path

mode, filename = sys.argv[1:]
lines = Path(filename).read_text(encoding='utf-8', errors='replace').splitlines()
if mode == 'analyze':
    relevant = [line for line in lines if line.startswith(('ERROR|', 'WARNING|'))]
    infos = sum(line.startswith('INFO|') for line in lines)
    selected = [f'Errors/warnings: {len(relevant)}. Informational diagnostics: {infos}.']
    selected += relevant[:100]
    if len(relevant) > 100:
        selected.append(f'... {len(relevant) - 100} more; see full job log.')
else:
    hits = [i for i, line in enumerate(lines)
            if re.search(r'\[E\]|Error:|Exception:|Some tests failed|Failed to load|timed out', line, re.I)]
    positions = sorted({n for i in hits[:35] for n in range(max(0, i-2), min(len(lines), i+8))})
    selected = [lines[n] for n in positions] if positions else lines[-35:]
    selected += ['Final test output:'] + lines[-8:]
text = '\n'.join(selected)[:40000]
text = text.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
print(f'::error title=CI diagnostic summary::{text}')
