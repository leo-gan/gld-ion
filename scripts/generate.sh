#!/usr/bin/env bash
# Generate testdata/schema/* into tests/generated/.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
mkdir -p tests/generated
if command -v pixi >/dev/null 2>&1; then
  MOJO=(pixi run mojo)
elif command -v mojo >/dev/null 2>&1; then
  MOJO=(mojo)
else
  echo "mojo not found; run scripts/ci-setup.sh" >&2
  exit 1
fi
shopt -s nullglob
for schema in testdata/schema/*.json testdata/schema/*.ion; do
  "${MOJO[@]}" run -I src src/codegen/cli.mojo -- --schema "$schema" --out tests/generated
done
