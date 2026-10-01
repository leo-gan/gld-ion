#!/usr/bin/env bash
# Run unit tests, then the vendored ion-tests corpus one file per process.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if command -v pixi >/dev/null 2>&1; then
  MOJO=(pixi run mojo)
elif command -v mojo >/dev/null 2>&1; then
  MOJO=(mojo)
else
  echo "mojo not found; run scripts/ci-setup.sh" >&2
  exit 1
fi

shopt -s nullglob
fail=0
for f in "$root"/tests/test_*.mojo; do
  base="$(basename "$f")"
  if [[ "$base" == "test_ion_suite.mojo" ]]; then
    continue
  fi
  echo "=== tests/${base} ==="
  if ! "${MOJO[@]}" run -I src -I tests/generated "$f"; then
    fail=1
  fi
done
if [[ "$fail" -ne 0 ]]; then
  echo "one or more unit tests failed" >&2
  exit 1
fi

echo "=== ion-tests ==="
"${MOJO[@]}" build -I src -o /tmp/ion-suite tests/test_ion_suite.mojo
catalog="$root/testdata/ion-tests/catalog/catalog.ion"
n=0
bad=0
while IFS= read -r path; do
  n=$((n + 1))
  if ! /tmp/ion-suite "$path" "$catalog" >/tmp/ion-suite-one.out 2>/tmp/ion-suite-one.err; then
    echo "FAIL $path"
    tail -n 20 /tmp/ion-suite-one.err /tmp/ion-suite-one.out || true
    bad=$((bad + 1))
  elif ! grep -q OK /tmp/ion-suite-one.out; then
    echo "FAIL $path"
    bad=$((bad + 1))
  fi
done < <(find "$root/testdata/ion-tests/iontestdata" -type f \( -name '*.ion' -o -name '*.10n' \) | sort)
echo "ion-tests checked $n fail $bad"
if [[ "$bad" -ne 0 ]]; then
  exit 1
fi
echo "all test files passed"
