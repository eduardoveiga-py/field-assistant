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
    selected += [line for line in info_lines if '|DEPRECATED_MEMBER_USE|' not in line][:30]
else:
    failures = [i for i, line in enumerate(lines) if '[E]' in line]
    names = [lines[i] for i in failures]
    selected = ['Failing test markers:'] + names + ['Final test output:'] + lines[-6:]
    # Actual assertions normally precede the [E] marker. Separate annotations
    # preserve context despite GitHub's per-message length limit.
    for i in failures[:8]:
        context = lines[max(0, i-24):min(len(lines), i+4)]
        text = '\n'.join(context)[-3400:]
        text = text.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
        print(f'::error title=Failure detail::{text}')
text = '\n'.join(selected)[:3500]
text = text.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
print(f'::error title=CI diagnostic summary::{text}')
