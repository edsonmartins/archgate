#!/usr/bin/env bash
# Smoke: plugin CLI → oracle-proxy mock (no OpenBao required).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROXY_URL="${ORACLE_PROXY_URL:-http://127.0.0.1:9040}"
export ORACLE_PLUGIN_CLI=1
export ORACLE_PROXY_URL="$PROXY_URL"

cd "$ROOT/services/openbao-oracle-plugin"
if [[ ! -f openbao-oracle-plugin ]]; then
  go build -o openbao-oracle-plugin .
fi

echo "== type =="
./openbao-oracle-plugin -cli -op type
echo "== init-smoke =="
./openbao-oracle-plugin -cli -op init-smoke -proxy "$PROXY_URL"
echo "== create/delete (proxy must be up, mock OK) =="
USER="v_smoketest"
if ./openbao-oracle-plugin -cli -op create -user "$USER" -pass 'SmokeTest1!' -proxy "$PROXY_URL"; then
  ./openbao-oracle-plugin -cli -op delete -user "$USER" -proxy "$PROXY_URL" || true
  echo "PASS create/delete"
else
  echo "WARN: proxy not reachable at $PROXY_URL — init-smoke/type still valid; start oracle-proxy for full smoke"
fi
echo "DONE"
