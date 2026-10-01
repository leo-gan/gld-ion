#!/usr/bin/env bash
# Install pixi and the Mojo 1.1.0 environment for this repo.
# The Modular channel may require a token. If pixi install returns 401,
# export PREFIX_API_KEY and retry. Never commit .env.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if [[ -f "$root/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$root/.env"
  set +a
fi

if ! command -v pixi >/dev/null 2>&1; then
  echo "pixi not found; installing to ~/.pixi/bin" >&2
  curl -fsSL https://pixi.sh/install.sh | bash
  export PATH="${HOME}/.pixi/bin:${PATH}"
fi

echo "pixi: $(pixi --version)"
echo "pin: mojo == 1.1.0"

if ! pixi install; then
  echo "pixi install failed. If the error is 401 on conda.modular.com, set PREFIX_API_KEY." >&2
  exit 1
fi
