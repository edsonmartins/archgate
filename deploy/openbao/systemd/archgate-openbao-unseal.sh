#!/usr/bin/env bash
# Unseal OpenBao using key from bootstrap.env (lab). Safe to re-run.
set -euo pipefail
BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
ADDR="${OPENBAO_ADDR:-http://127.0.0.1:8200}"

set -a
# shellcheck disable=SC1090
source "$BOOTSTRAP"
set +a

: "${OPENBAO_UNSEAL_KEY:?OPENBAO_UNSEAL_KEY missing in bootstrap}"

for i in $(seq 1 60); do
  code=$(curl -s -o /tmp/bao_h.json -w '%{http_code}' "$ADDR/v1/sys/health" 2>/dev/null || echo 000)
  # 200 unsealed, 503 sealed, 501 not init, 000 down
  if [[ "$code" == "200" || "$code" == "503" || "$code" == "429" ]]; then
    break
  fi
  sleep 2
done

SEALED=$(python3 -c 'import json; d=json.load(open("/tmp/bao_h.json")); print(d.get("sealed", True))' 2>/dev/null || echo True)
if [[ "$SEALED" == "False" || "$SEALED" == "false" ]]; then
  echo "OpenBao already unsealed"
  exit 0
fi

curl -sf -X PUT "$ADDR/v1/sys/unseal" \
  -H 'Content-Type: application/json' \
  -d "$(python3 -c "import json,os; print(json.dumps({'key':os.environ['OPENBAO_UNSEAL_KEY']}))")" \
  | python3 -c 'import sys,json; d=json.load(sys.stdin); assert d.get("sealed") is False, d; print("unsealed OK t=", d.get("t"))'
