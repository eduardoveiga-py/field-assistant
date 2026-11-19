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
    progress = [line for line in lines if re.match(r'^\d\d:\d\d ', line)]
    selected = ['Failing test markers:'] + names + ['Last test progress:'] + progress[-12:] + ['Final test output:'] + lines[-15:]
    if not failures:
        for marker in ('EXCEPTION CAUGHT', 'ERROR', 'Error:', 'Exception:', 'Timed out'):
            matches = [i for i, line in enumerate(lines) if marker in line]
            if matches:
                i = matches[-1]
                text = '\n'.join(lines[max(0, i-3):i+18])[:3400]
                text = text.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
                print(f'::error title=Diagnostic context::{text}')
    # Actual assertions normally precede the [E] marker. Separate annotations
    # preserve context despite GitHub's per-message length limit.
    for i in failures[:8]:
        # Stack traces can exceed the annotation limit. Keep the exception
        # heading and assertion itself, not only the tail of the stack.
        start = max(0, i - 300)
        headings = [j for j in range(start, i) if 'EXCEPTION CAUGHT' in lines[j]]
        if headings:
            start = headings[-1]
        else:
            start = max(0, i - 24)
        context = lines[start:min(len(lines), start + 24, i + 4)]
        text = '\n'.join(context)[:3400]
        text = text.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
        print(f'::error title=Failure detail::{text}')
text = '\n'.join(selected)[:3500]
text = text.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
print(f'::error title=CI diagnostic summary::{text}')
