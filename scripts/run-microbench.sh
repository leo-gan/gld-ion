#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
if command -v pixi >/dev/null 2>&1; then
  MOJO=(pixi run mojo)
else
  MOJO=(mojo)
fi
"${MOJO[@]}" run -I src -I tests/generated benches/microbench.mojo
