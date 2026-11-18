#!/usr/bin/env python3
"""Generate a minimal CycloneDX 1.5 SBOM JSON from pubspec.lock."""
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path


def parse_pubspec_lock(text: str):
    components = []
    in_packages = False
    current = None
    for line in text.splitlines():
        if line.startswith("packages:"):
            in_packages = True
            continue
        if not in_packages:
            continue
        if line and not line.startswith(" "):
            break
        m_pkg = re.match(r"^  ([a-zA-Z0-9_]+):$", line)
        if m_pkg:
            if current:
                components.append(current)
            current = {"name": m_pkg.group(1), "version": "", "source": ""}
            continue
        if current is not None:
            m_ver = re.match(r'^    version:\s*"([^"]+)"', line)
            if m_ver:
                current["version"] = m_ver.group(1)
            m_src = re.match(r"^    source:\s*(\S+)", line)
            if m_src:
                current["source"] = m_src.group(1)
    if current:
        components.append(current)
    return components


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: generate_sbom.py <pubspec.lock> <output.json>")
        return 2
    lock_path = Path(sys.argv[1])
    out_path = Path(sys.argv[2])
    pkgs = parse_pubspec_lock(lock_path.read_text(encoding="utf-8"))
    sbom = {
        "bomFormat": "CycloneDX",
        "specVersion": "1.5",
        "version": 1,
        "metadata": {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "component": {"type": "application", "name": "field-assistant"},
        },
        "components": [
            {
                "type": "library",
                "name": p["name"],
                "version": p["version"],
                "purl": f"pkg:pub/{p['name']}@{p['version']}" if p["source"] == "hosted" else f"pkg:generic/{p['name']}@{p['version']}",
            }
            for p in pkgs
        ],
    }
    out_path.write_text(json.dumps(sbom, indent=2) + "\n", encoding="utf-8")
    print(f"Generated SBOM with {len(pkgs)} components at {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
