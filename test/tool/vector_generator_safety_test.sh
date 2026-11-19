#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
dir="$(mktemp -d)"
trap 'rm -rf "$dir"' EXIT
mkdir -p "$dir/output"
printf 'existing user file\n' > "$dir/output/alto_solimoes.pmtiles"
cp "$dir/output/alto_solimoes.pmtiles" "$dir/before"
if bash "$root/tool/map/build_alto_solimoes_vector.sh" "$dir"; then
  echo 'FAIL: gerador não validado retornou sucesso' >&2
  exit 1
fi
cmp "$dir/before" "$dir/output/alto_solimoes.pmtiles"
if [[ $(find "$dir/output" -type f | wc -l) != 1 ]]; then
  echo 'FAIL: gerador criou artefatos' >&2
  exit 1
fi
echo 'PASS: falha fechada preserva artefato existente e não cria pacote/manifesto'
