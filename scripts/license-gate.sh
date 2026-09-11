#!/usr/bin/env bash
# Gate mínimo de licenças: o produto não incorpora AGPL/BUSL.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if rg -n -i --hidden \
  -g '!**/.git/**' -g '!**/target/**' -g '!**/node_modules/**' \
  -g '!documentos/**' -g '!adr/**' -g '!openspec/**' \
  -g '!CONSTITUTION.md' -g '!PLATAFORMA_ACESSO_PRIVILEGIADO.md' \
  -g '!scripts/license-gate.sh' \
  '(AGPL|BUSL|BUSL-1\.1|BUSINESS SOURCE LICENSE)' "$ROOT"; then
  echo "license-gate: prohibited AGPL/BUSL marker found" >&2
  exit 1
fi

echo "license-gate: no AGPL/BUSL markers in active source/manifests"
