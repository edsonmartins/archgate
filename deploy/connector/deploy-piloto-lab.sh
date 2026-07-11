#!/usr/bin/env bash
# Fase 3 parcial — site connector lab "piloto"
# Rede isolada do cliente + connector no path do bastion (ADR-008 tunnel_agent).
set -euo pipefail

BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
SITE_NET="${SITE_NET:-archgate-site-piloto}"
SITE_SUBNET="${SITE_SUBNET:-10.77.10.0/24}"
TARGET_NAME="${TARGET_NAME:-piloto-lab-ssh}"
TARGET_ROLE="${TARGET_ROLE:-tenant-rio-quality}"
SSH_IMAGE="${SSH_IMAGE:-lscr.io/linuxserver/openssh-server:latest}"
LAB_USER="${LAB_USER:-labuser}"
LAB_PASS="${LAB_PASS:-ArchGatePilotoSsh2026}"
CONNECTOR_PORT="${CONNECTOR_PORT:-2223}"

set -a
# shellcheck disable=SC1090
[[ -f "$BOOTSTRAP" ]] && source "$BOOTSTRAP"
set +a

log() { echo "  [OK] $1"; }
step() { echo -e "\n=== $1 ==="; }

step "1. Site network (${SITE_NET} ${SITE_SUBNET})"
if ! docker network ls --format '{{.Name}}' | grep -qx "$SITE_NET"; then
  docker network create \
    --driver overlay \
    --attachable \
    --subnet "$SITE_SUBNET" \
    "$SITE_NET"
  log "created overlay $SITE_NET"
else
  log "network $SITE_NET exists"
fi

step "2. Site SSH target (ONLY on site network — not archgate-data)"
docker service rm archgate-site-piloto_ssh 2>/dev/null || true
sleep 2
docker service create \
  --name archgate-site-piloto_ssh \
  --network "$SITE_NET" \
  --constraint 'node.labels.archgate.runtime == true' \
  --env PUID=1000 \
  --env PGID=1000 \
  --env TZ=America/Sao_Paulo \
  --env USER_NAME="$LAB_USER" \
  --env USER_PASSWORD="$LAB_PASS" \
  --env PASSWORD_ACCESS=true \
  --env SUDO_ACCESS=false \
  --restart-condition on-failure \
  --detach=true \
  "$SSH_IMAGE"
log "service archgate-site-piloto_ssh (site-only)"

step "3. Wait for site SSH task IP"
SITE_SSH_IP=""
for i in $(seq 1 40); do
  CID=$(docker ps -q --filter name=archgate-site-piloto_ssh | head -1)
  if [[ -n "$CID" ]]; then
    SITE_SSH_IP=$(docker inspect "$CID" --format "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" | awk 'NF{print; exit}')
    # prefer site net
    SITE_SSH_IP=$(docker inspect "$CID" --format "{{(index .NetworkSettings.Networks \"${SITE_NET}\").IPAddress}}" 2>/dev/null || echo "$SITE_SSH_IP")
  fi
  if [[ -n "$SITE_SSH_IP" ]]; then
    log "site ssh IP=$SITE_SSH_IP"
    break
  fi
  sleep 2
done
[[ -n "$SITE_SSH_IP" ]] || { echo "site ssh not ready"; docker service ps archgate-site-piloto_ssh; exit 1; }

step "4. Connector (archgate-data + site) — TCP forward ${CONNECTOR_PORT} → site:2222"
# linuxserver openssh listens 2222 inside container
docker service rm archgate-site-piloto_connector 2>/dev/null || true
sleep 2
docker service create \
  --name archgate-site-piloto_connector \
  --network archgate-data \
  --network "$SITE_NET" \
  --constraint 'node.labels.archgate.runtime == true' \
  --restart-condition on-failure \
  --detach=true \
  alpine:3.20 \
  sh -c "apk add --no-cache socat >/dev/null && \
    echo \"connector forwarding :${CONNECTOR_PORT} -> archgate-site-piloto_ssh:2222\" && \
    exec socat TCP-LISTEN:${CONNECTOR_PORT},fork,reuseaddr TCP:archgate-site-piloto_ssh:2222"

log "connector service created"

step "5. Resolve connector IP on archgate-data"
CONN_IP=""
for i in $(seq 1 40); do
  CID=$(docker ps -q --filter name=archgate-site-piloto_connector | head -1)
  if [[ -n "$CID" ]]; then
    CONN_IP=$(docker inspect "$CID" --format '{{(index .NetworkSettings.Networks "archgate-data").IPAddress}}' 2>/dev/null || true)
  fi
  if [[ -n "$CONN_IP" ]]; then
    log "connector data IP=$CONN_IP"
    break
  fi
  sleep 2
done
[[ -n "$CONN_IP" ]] || { echo "connector not ready"; docker service ps archgate-site-piloto_connector; exit 1; }

# Smoke: from a data-network helper, reach connector port
step "6. Path smoke (data → connector → site)"
docker run --rm --network archgate-data alpine:3.20 \
  sh -c "apk add --no-cache openssh-client sshpass >/dev/null 2>&1; \
    sshpass -p '$LAB_PASS' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -p $CONNECTOR_PORT ${LAB_USER}@${CONN_IP} 'echo CONNECTOR_PATH_OK; hostname'" \
  && log "connector path OK" || echo "  [!!] direct path smoke failed (warpgate may still work after DNS settle)"

step "7. Warpgate target ${TARGET_NAME} → connector"
: "${WARPGATE_ADMIN_PASSWORD:?}"
CK=$(mktemp)
curl -sk -c "$CK" -b "$CK" -H "Host: wg.archgate.com.br" -H "Content-Type: application/json" \
  -d "$(python3 -c "import json,os; print(json.dumps({'username':'admin','password':os.environ['WARPGATE_ADMIN_PASSWORD']}))")" \
  "https://127.0.0.1/@warpgate/api/auth/login" >/dev/null

# Find existing target id
EXIST=$(curl -sk -b "$CK" -H "Host: wg.archgate.com.br" "https://127.0.0.1/@warpgate/admin/api/targets")
TID=$(echo "$EXIST" | python3 -c "
import sys,json
for t in json.load(sys.stdin):
  if t.get('name')=='$TARGET_NAME':
    print(t['id']); break
")

# Prefer Swarm DNS name (stable across task restarts) on archgate-data
WG_HOST_TARGET="archgate-site-piloto_connector"
BODY=$(WG_HOST_TARGET="$WG_HOST_TARGET" CONNECTOR_PORT="$CONNECTOR_PORT" LAB_USER="$LAB_USER" LAB_PASS="$LAB_PASS" TARGET_NAME="$TARGET_NAME" python3 - <<'PY'
import json,os
print(json.dumps({
  "name": os.environ["TARGET_NAME"],
  "description": "Site piloto via connector (Fase 3 parcial) — host is connector DNS, not client LAN",
  "options": {
    "kind": "Ssh",
    "host": os.environ["WG_HOST_TARGET"],
    "port": int(os.environ["CONNECTOR_PORT"]),
    "username": os.environ["LAB_USER"],
    "auth": {"kind": "Password", "password": os.environ["LAB_PASS"]},
  }
}))
PY
)

if [[ -n "$TID" ]]; then
  curl -sk -b "$CK" -H "Host: wg.archgate.com.br" -H "Content-Type: application/json" \
    -X PUT -d "$BODY" "https://127.0.0.1/@warpgate/admin/api/targets/${TID}" >/dev/null
  log "updated target $TARGET_NAME id=$TID host=${WG_HOST_TARGET}:$CONNECTOR_PORT"
else
  curl -sk -b "$CK" -H "Host: wg.archgate.com.br" -H "Content-Type: application/json" \
    -X POST -d "$BODY" "https://127.0.0.1/@warpgate/admin/api/targets" >/dev/null
  EXIST=$(curl -sk -b "$CK" -H "Host: wg.archgate.com.br" "https://127.0.0.1/@warpgate/admin/api/targets")
  TID=$(echo "$EXIST" | python3 -c "
import sys,json
for t in json.load(sys.stdin):
  if t.get('name')=='$TARGET_NAME':
    print(t['id']); break
")
  log "created target $TARGET_NAME id=$TID"
fi

# Bind role
ROLES=$(curl -sk -b "$CK" -H "Host: wg.archgate.com.br" "https://127.0.0.1/@warpgate/admin/api/roles")
RID=$(echo "$ROLES" | python3 -c "
import sys,json
for r in json.load(sys.stdin):
  if r.get('name')=='$TARGET_ROLE':
    print(r['id']); break
")
if [[ -n "$RID" && -n "$TID" ]]; then
  curl -sk -b "$CK" -H "Host: wg.archgate.com.br" -H "Content-Type: application/json" -d '{}' \
    -X POST "https://127.0.0.1/@warpgate/admin/api/targets/${TID}/roles/${RID}" >/dev/null || true
  log "role $TARGET_ROLE bound to $TARGET_NAME"
fi
rm -f "$CK"

# Persist for smoke
mkdir -p /var/lib/archgate/connector
cat > /var/lib/archgate/connector/piloto.env <<EOF
SITE_NET=$SITE_NET
SITE_SSH_IP=$SITE_SSH_IP
CONN_IP=$CONN_IP
CONNECTOR_PORT=$CONNECTOR_PORT
TARGET_NAME=$TARGET_NAME
TARGET_ROLE=$TARGET_ROLE
LAB_USER=$LAB_USER
LAB_PASS=$LAB_PASS
EOF
chmod 600 /var/lib/archgate/connector/piloto.env

echo ""
echo "=============================================="
echo " CONNECTOR PILOTO LAB DEPLOYED"
echo "=============================================="
echo "  site net:    $SITE_NET ($SITE_SUBNET)"
echo "  site ssh:    $SITE_SSH_IP (not on archgate-data)"
echo "  connector:   $CONN_IP:$CONNECTOR_PORT on archgate-data"
echo "  warpgate:    $TARGET_NAME → connector (role $TARGET_ROLE)"
echo "  operator:    ssh -p 2222 'USER:${TARGET_NAME}@wg...'"
echo "  smoke:       bash deploy/connector/smoke-connector-piloto.sh"
echo "=============================================="
