#!/usr/bin/env python3
"""Parse lcov.info and report real line coverage by domain (FAES FA-CI-01)."""
import sys
from pathlib import Path


def parse_lcov(path: Path):
    records = {}
    current = None
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if raw.startswith("SF:"):
            current = raw[3:].replace("\\", "/")
            records.setdefault(current, [0, 0])
        elif raw.startswith("DA:") and current is not None:
            parts = raw[3:].split(",")
            if len(parts) >= 2:
                records[current][0] += 1
                if int(parts[1]) > 0:
                    records[current][1] += 1
    return records


def summarize(records, predicate):
    total = 0
    hit = 0
    for f, (lf, lh) in records.items():
        if predicate(f):
            total += lf
            hit += lh
    pct = (hit / total * 100.0) if total else 0.0
    return hit, total, pct


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: ci_coverage_check.py <lcov.info> [--enforce-crypto-min=90]")
        return 2
    lcov_path = Path(sys.argv[1])
    if not lcov_path.is_file():
        print(f"Coverage file not found: {lcov_path}")
        return 1
    records = parse_lcov(lcov_path)
    overall = summarize(records, lambda f: True)
    crypto = summarize(records, lambda f: "lib/sync/crypto/" in f or "sync_owner_guard.dart" in f)
    sync = summarize(records, lambda f: "lib/sync/" in f)
    domain = summarize(
        records,
        lambda f: any(
            k in f
            for k in (
                "lib/core/",
                "lib/database/",
                "lib/studies/",
                "lib/appointments/",
                "lib/settings/",
                "lib/territory/",
            )
        )
        and not f.endswith(".g.dart"),
    )
    print(f"Overall coverage:      {overall[0]:5d}/{overall[1]:5d} ({overall[2]:5.2f}%)")
    print(f"Domain coverage:       {domain[0]:5d}/{domain[1]:5d} ({domain[2]:5.2f}%) [FAES target >=80%]")
    print(f"Sync total coverage:   {sync[0]:5d}/{sync[1]:5d} ({sync[2]:5.2f}%) [FAES target >=90%]")
    print(f"Crypto/Guard coverage: {crypto[0]:5d}/{crypto[1]:5d} ({crypto[2]:5.2f}%) [FAES target >=90%]")

    for arg in sys.argv[2:]:
        if arg.startswith("--enforce-crypto-min="):
            threshold = float(arg.split("=", 1)[1])
            if crypto[2] < threshold:
                print(f"::error::Crypto/Guard coverage {crypto[2]:.2f}% < {threshold:.1f}%")
                return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
