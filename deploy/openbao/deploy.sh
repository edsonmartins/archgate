#!/usr/bin/env bash
# Fase 2 — OpenBao lab (single-node file storage). NÃO é HA de produção.
set -euo pipefail

BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
DATA="${OPENBAO_DATA:-/var/lib/archgate/openbao}"
IMAGE="${OPENBAO_IMAGE:-openbao/openbao:2.2.0}"
SVC="${OPENBAO_SERVICE:-archgate-secrets_openbao}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_SYSTEMD="${INSTALL_SYSTEMD:-1}"
ADDR="${OPENBAO_ADDR:-http://127.0.0.1:8200}"

set -a
# shellcheck disable=SC1090
[[ -f "$BOOTSTRAP" ]] && source "$BOOTSTRAP"
set +a

mkdir -p "$DATA/data" "$DATA/audit" "$DATA/config"
chown -R 100:100 "$DATA" 2>/dev/null || true

# Server config (file storage — lab only)
cat > "$DATA/config/local.json" <<'EOF'
{
  "storage": {
    "file": {
      "path": "/openbao/file"
    }
  },
  "listener": {
    "tcp": {
      "address": "0.0.0.0:8200",
      "tls_disable": 1
    }
  },
  "api_addr": "http://archgate-secrets_openbao:8200",
  "cluster_addr": "https://archgate-secrets_openbao:8201",
  "ui": true,
  "disable_mlock": true,
  "log_level": "info"
}
EOF

echo "==> deploy $SVC"
docker service rm "$SVC" 2>/dev/null || true
sleep 2

docker service create \
  --name "$SVC" \
  --network archgate-data \
  --constraint 'node.labels.archgate.runtime == true' \
  --mount type=bind,source="$DATA/data",target=/openbao/file \
  --mount type=bind,source="$DATA/config",target=/openbao/config,readonly \
  --mount type=bind,source="$DATA/audit",target=/openbao/audit \
  --env BAO_ADDR=http://127.0.0.1:8200 \
  --publish mode=host,target=8200,published=8200 \
  --restart-condition on-failure \
  --detach=true \
  "$IMAGE" server -config=/openbao/config/local.json

echo "==> wait for API"
for i in $(seq 1 40); do
  code=$(curl -s -o /tmp/bao_h.json -w '%{http_code}' "$ADDR/v1/sys/health" || echo 000)
  echo "  try $i http=$code $(head -c 120 /tmp/bao_h.json 2>/dev/null || true)"
  if [[ "$code" == "501" || "$code" == "503" || "$code" == "200" || "$code" == "429" ]]; then
    break
  fi
  sleep 2
done

# Init if needed
INIT_JSON=$(curl -s "$ADDR/v1/sys/init")
INITIALIZED=$(echo "$INIT_JSON" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("initialized",False))')

if [[ "$INITIALIZED" != "True" && "$INITIALIZED" != "true" ]]; then
  echo "==> init OpenBao (1 share / threshold 1 — LAB ONLY)"
  INIT_OUT=$(curl -s -X PUT "$ADDR/v1/sys/init" \
    -H 'Content-Type: application/json' \
    -d '{"secret_shares":1,"secret_threshold":1}')
  UNSEAL=$(echo "$INIT_OUT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["keys_base64"][0])')
  ROOT=$(echo "$INIT_OUT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["root_token"])')
  grep -vE '^OPENBAO_UNSEAL_KEY=|^OPENBAO_ROOT_TOKEN=|^OPENBAO_ADDR=' "$BOOTSTRAP" > /tmp/bs.bao || true
  mv /tmp/bs.bao "$BOOTSTRAP"
  {
    echo "OPENBAO_ADDR=${ADDR}"
    echo "OPENBAO_UNSEAL_KEY=${UNSEAL}"
    echo "OPENBAO_ROOT_TOKEN=${ROOT}"
  } >> "$BOOTSTRAP"
  chmod 600 "$BOOTSTRAP"
  echo "  keys written to bootstrap.env"
  export OPENBAO_UNSEAL_KEY="$UNSEAL"
  export OPENBAO_ROOT_TOKEN="$ROOT"
  export OPENBAO_ADDR="$ADDR"
else
  echo "==> already initialized"
  set -a
  # shellcheck disable=SC1090
  source "$BOOTSTRAP"
  set +a
  : "${OPENBAO_UNSEAL_KEY:?re-run with keys in bootstrap}"
  : "${OPENBAO_ROOT_TOKEN:?}"
fi

echo "==> unseal"
if [[ -f "$SCRIPT_DIR/systemd/archgate-openbao-unseal.sh" ]]; then
  BOOTSTRAP="$BOOTSTRAP" OPENBAO_ADDR="$ADDR" bash "$SCRIPT_DIR/systemd/archgate-openbao-unseal.sh"
else
  curl -s -X PUT "$ADDR/v1/sys/unseal" \
    -H 'Content-Type: application/json' \
    -d "$(python3 -c "import json,os; print(json.dumps({'key':os.environ['OPENBAO_UNSEAL_KEY']}))")" \
    | python3 -c 'import sys,json; d=json.load(sys.stdin); print("sealed", d.get("sealed"), "t", d.get("t"))'
fi

curl -s -H "X-Vault-Token: ${OPENBAO_ROOT_TOKEN}" "$ADDR/v1/sys/health" \
  | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d)'

if [[ "$INSTALL_SYSTEMD" == "1" && -f "$SCRIPT_DIR/systemd/install-timer.sh" ]]; then
  echo "==> install unseal + broker systemd (boot + periodic)"
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)" \
    BOOTSTRAP="$BOOTSTRAP" \
    bash "$SCRIPT_DIR/systemd/install-timer.sh" || echo "  [warn] install-timer failed (non-fatal if not root host)"
fi

echo "OK: OpenBao lab on :8200 — run bootstrap-engines.sh next (if first time)"
echo "    unseal: systemd oneshot on boot + timer 2m (lab recovery after recreate)"
