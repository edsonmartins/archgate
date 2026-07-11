#!/usr/bin/env bash
# Fase 3 — piloto WireGuard (substitui socat dual-homed)
# Padrão ADR-008: tunnel agent no "site" + connector na plataforma (sem site-net no connector).
#
#   archgate-data → platform-connector (WG) ~~~ WG ~~~ site-agent → site SSH (só site-net)
#
set -euo pipefail

BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
SITE_NET="${SITE_NET:-archgate-site-piloto}"
SITE_SUBNET="${SITE_SUBNET:-10.77.10.0/24}"
WG_NET="${WG_NET:-archgate-wg-lab}"
WG_SUBNET="${WG_SUBNET:-10.66.66.0/24}"
WG_TUN_PLATFORM="${WG_TUN_PLATFORM:-10.200.0.1/24}"
WG_TUN_SITE="${WG_TUN_SITE:-10.200.0.2/24}"
TARGET_NAME="${TARGET_NAME:-piloto-lab-ssh}"
TARGET_ROLE="${TARGET_ROLE:-tenant-rio-quality}"
SSH_IMAGE="${SSH_IMAGE:-lscr.io/linuxserver/openssh-server:latest}"
LAB_USER="${LAB_USER:-labuser}"
LAB_PASS="${LAB_PASS:-ArchGatePilotoSsh2026}"
CONNECTOR_PORT="${CONNECTOR_PORT:-2223}"
STATE_DIR="${STATE_DIR:-/var/lib/archgate/connector}"
WG_DIR="${STATE_DIR}/wg"

set -a
# shellcheck disable=SC1090
[[ -f "$BOOTSTRAP" ]] && source "$BOOTSTRAP"
set +a

log() { echo "  [OK] $1"; }
step() { echo -e "\n=== $1 ==="; }
fail() { echo "  [FAIL] $1" >&2; exit 1; }

command -v wg >/dev/null || fail "wireguard-tools missing (apt install wireguard-tools)"

mkdir -p "$WG_DIR"
chmod 700 "$WG_DIR"

step "0. WireGuard keys (lab — regenerated if missing)"
if [[ ! -f "$WG_DIR/platform.key" ]]; then
  umask 077
  wg genkey | tee "$WG_DIR/platform.key" | wg pubkey > "$WG_DIR/platform.pub"
  wg genkey | tee "$WG_DIR/site.key" | wg pubkey > "$WG_DIR/site.pub"
  log "generated platform+site keypairs"
else
  log "reusing keys in $WG_DIR"
fi
PLATFORM_PRIV=$(cat "$WG_DIR/platform.key")
PLATFORM_PUB=$(cat "$WG_DIR/platform.pub")
SITE_PRIV=$(cat "$WG_DIR/site.key")
SITE_PUB=$(cat "$WG_DIR/site.pub")

step "1. Networks: site + WG transport (not client LAN on platform)"
if ! docker network ls --format '{{.Name}}' | grep -qx "$SITE_NET"; then
  docker network create --driver overlay --attachable --subnet "$SITE_SUBNET" "$SITE_NET"
  log "created $SITE_NET"
else
  log "$SITE_NET exists"
fi
if ! docker network ls --format '{{.Name}}' | grep -qx "$WG_NET"; then
  docker network create --driver overlay --attachable --subnet "$WG_SUBNET" "$WG_NET"
  log "created $WG_NET (WG handshake path)"
else
  log "$WG_NET exists"
fi

step "2. Site SSH (ONLY site network)"
docker service rm archgate-site-piloto_ssh 2>/dev/null || true
# remove old dual-homed socat connector if present
docker service rm archgate-site-piloto_connector 2>/dev/null || true
docker service rm archgate-site-piloto_agent 2>/dev/null || true
sleep 2

docker service create \
  --name archgate-site-piloto_ssh \
  --network "$SITE_NET" \
  --constraint 'node.labels.archgate.runtime == true' \
  --env PUID=1000 --env PGID=1000 --env TZ=America/Sao_Paulo \
  --env USER_NAME="$LAB_USER" --env USER_PASSWORD="$LAB_PASS" \
  --env PASSWORD_ACCESS=true --env SUDO_ACCESS=false \
  --restart-condition on-failure --detach=true \
  "$SSH_IMAGE"
log "archgate-site-piloto_ssh"

step "3. Wait site SSH IP"
SITE_SSH_IP=""
for i in $(seq 1 45); do
  CID=$(docker ps -q --filter name=archgate-site-piloto_ssh | head -1)
  if [[ -n "$CID" ]]; then
    SITE_SSH_IP=$(docker inspect "$CID" --format "{{(index .NetworkSettings.Networks \"${SITE_NET}\").IPAddress}}" 2>/dev/null || true)
  fi
  [[ -n "$SITE_SSH_IP" ]] && break
  sleep 2
done
[[ -n "$SITE_SSH_IP" ]] || fail "site ssh IP not ready"
log "site ssh IP=$SITE_SSH_IP"

# conf files mounted into containers
cat > "$WG_DIR/platform.conf" <<EOF
[Interface]
Address = ${WG_TUN_PLATFORM}
ListenPort = 51820
PrivateKey = ${PLATFORM_PRIV}
PostUp = sysctl -w net.ipv4.ip_forward=1; iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT

[Peer]
PublicKey = ${SITE_PUB}
AllowedIPs = 10.200.0.2/32, ${SITE_SUBNET}
EOF

cat > "$WG_DIR/site.conf" <<EOF
[Interface]
Address = ${WG_TUN_SITE}
ListenPort = 51820
PrivateKey = ${SITE_PRIV}
PostUp = sysctl -w net.ipv4.ip_forward=1; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; iptables -A FORWARD -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE || true

[Peer]
PublicKey = ${PLATFORM_PUB}
# Endpoint filled at runtime with platform container IP on WG_NET
AllowedIPs = 10.200.0.0/24
PersistentKeepalive = 15
EOF
chmod 600 "$WG_DIR"/*.conf "$WG_DIR"/*.key

# Entrypoint scripts (kernel WireGuard + NET_ADMIN)
cat > "$WG_DIR/run-platform.sh" <<EOS
#!/bin/sh
set -eu
apk add --no-cache wireguard-tools iptables iproute2 socat >/dev/null
ip link del wg0 2>/dev/null || true
ip link add dev wg0 type wireguard
PRIV=\$(awk '/^PrivateKey/{print \$3}' /cfg/platform.conf)
SITEPUB=\$(awk '/^PublicKey/{print \$3}' /cfg/platform.conf)
echo "\$PRIV" > /tmp/p.key
chmod 600 /tmp/p.key
wg set wg0 private-key /tmp/p.key listen-port 51820
wg set wg0 peer "\$SITEPUB" allowed-ips 10.200.0.2/32,10.77.10.0/24
ip address add 10.200.0.1/24 dev wg0
ip link set mtu 1280 dev wg0
ip link set wg0 up
# Tunnel-only path: platform reaches site agent at 10.200.0.2 (no L3 forward into site subnet)
sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true
echo "platform WG ready; socat :${CONNECTOR_PORT} -> 10.200.0.2:2222 (via WG)"
wg show
# wait for site peer handshake before accepting traffic
i=0
while [ \$i -lt 40 ]; do
  if wg show wg0 | grep -q 'latest handshake'; then break; fi
  i=\$((i+1)); sleep 1
done
exec socat TCP-LISTEN:${CONNECTOR_PORT},fork,reuseaddr TCP:10.200.0.2:2222
EOS
chmod +x "$WG_DIR/run-platform.sh"

# Resolve site SSH by Swarm DNS (IPs change on task recreate)
cat > "$WG_DIR/run-site.sh" <<'EOS'
#!/bin/sh
set -eu
apk add --no-cache wireguard-tools iptables iproute2 bind-tools socat >/dev/null

resolve() {
  name="$1"
  ip=""
  ip=$(getent hosts "tasks.$name" 2>/dev/null | awk '{print $1; exit}')
  if [ -z "$ip" ]; then
    ip=$(getent hosts "$name" 2>/dev/null | awk '{print $1; exit}')
  fi
  if [ -z "$ip" ]; then
    ip=$(nslookup "$name" 2>/dev/null | awk '/^Address: / && $2 !~ /:/ {print $2; exit}')
  fi
  echo "$ip"
}

# wait for platform + site ssh DNS
PLAT=""
SITE_SSH_IP=""
i=0
while [ $i -lt 60 ]; do
  [ -z "$PLAT" ] && PLAT=$(resolve archgate-site-piloto_connector)
  [ -z "$SITE_SSH_IP" ] && SITE_SSH_IP=$(resolve archgate-site-piloto_ssh)
  if [ -n "$PLAT" ] && [ -n "$SITE_SSH_IP" ]; then break; fi
  i=$((i+1)); sleep 2
done
echo "platform endpoint IP=$PLAT site_ssh=$SITE_SSH_IP"

ip link del wg0 2>/dev/null || true
ip link add dev wg0 type wireguard
PRIV=$(awk '/^PrivateKey/{print $3}' /cfg/site.conf)
PLATPUB=$(awk '/^PublicKey/{print $3}' /cfg/site.conf)
echo "$PRIV" > /tmp/s.key
chmod 600 /tmp/s.key
wg set wg0 private-key /tmp/s.key listen-port 51820
if [ -n "$PLAT" ]; then
  wg set wg0 peer "$PLATPUB" endpoint "${PLAT}:51820" allowed-ips 10.200.0.0/24 persistent-keepalive 15
else
  wg set wg0 peer "$PLATPUB" allowed-ips 10.200.0.0/24 persistent-keepalive 15
fi
ip address add 10.200.0.2/24 dev wg0
ip link set mtu 1280 dev wg0
ip link set wg0 up
echo "site agent WG up; socat :2222 on tunnel -> ${SITE_SSH_IP}:2222"
wg show
# DNS name for TCP target is more stable than IP when tasks restart mid-flight
exec socat TCP-LISTEN:2222,bind=10.200.0.2,fork,reuseaddr TCP:archgate-site-piloto_ssh:2222
EOS
chmod +x "$WG_DIR/run-site.sh"

# Host forward (containers often cannot write sysctl)
sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true

step "4. Platform connector (archgate-data + WG transport) — NOT on site net"
docker service create \
  --name archgate-site-piloto_connector \
  --network archgate-data \
  --network "$WG_NET" \
  --constraint 'node.labels.archgate.runtime == true' \
  --cap-add NET_ADMIN \
  --cap-add SYS_MODULE \
  --cap-add NET_RAW \
  --sysctl net.ipv4.ip_forward=1 \
  --mount type=bind,source="$WG_DIR",target=/cfg,readonly \
  --mount type=bind,source=/lib/modules,target=/lib/modules,readonly \
  --restart-condition on-failure \
  --detach=true \
  alpine:3.20 \
  sh /cfg/run-platform.sh
log "platform connector (WG + socat)"

step "5. Site agent (site net + WG transport) — tunnel agent no cliente"
# short delay so platform DNS exists
sleep 5
docker service create \
  --name archgate-site-piloto_agent \
  --network "$SITE_NET" \
  --network "$WG_NET" \
  --constraint 'node.labels.archgate.runtime == true' \
  --cap-add NET_ADMIN \
  --cap-add SYS_MODULE \
  --cap-add NET_RAW \
  --sysctl net.ipv4.ip_forward=1 \
  --mount type=bind,source="$WG_DIR",target=/cfg,readonly \
  --mount type=bind,source=/lib/modules,target=/lib/modules,readonly \
  --restart-condition on-failure \
  --detach=true \
  alpine:3.20 \
  sh /cfg/run-site.sh
log "site agent (WG)"

step "6. Wait handshake + path"
CONN_IP=""
for i in $(seq 1 50); do
  CID=$(docker ps -q --filter name=archgate-site-piloto_connector | head -1)
  if [[ -n "$CID" ]]; then
    CONN_IP=$(docker inspect "$CID" --format '{{(index .NetworkSettings.Networks "archgate-data").IPAddress}}' 2>/dev/null || true)
  fi
  if [[ -n "$CONN_IP" ]]; then
    if docker run --rm --network archgate-data alpine:3.20 \
      sh -c "apk add --no-cache openssh-client sshpass >/dev/null 2>&1 && \
        sshpass -p '$LAB_PASS' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          -o ConnectTimeout=5 -p $CONNECTOR_PORT ${LAB_USER}@${CONN_IP} 'echo WG_PATH_OK'" 2>/dev/null | grep -q WG_PATH_OK; then
      log "WG path OK via connector $CONN_IP:$CONNECTOR_PORT"
      break
    fi
  fi
  echo "  wait path try $i conn=$CONN_IP"
  sleep 3
done
[[ -n "$CONN_IP" ]] || fail "connector data IP missing"

# confirm connector not on site net
CONN_CID=$(docker ps -q --filter name=archgate-site-piloto_connector | head -1)
CONN_NETS=$(docker inspect "$CONN_CID" --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}')
echo "    connector networks: $CONN_NETS"
echo "$CONN_NETS" | grep -q 'archgate-site-piloto' && fail "connector must NOT be on site net" || log "connector isolated from site-net (WG only)"

step "7. Warpgate target ${TARGET_NAME}"
: "${WARPGATE_ADMIN_PASSWORD:?}"
CK=$(mktemp)
curl -sk -c "$CK" -b "$CK" -H "Host: wg.archgate.com.br" -H "Content-Type: application/json" \
  -d "$(python3 -c "import json,os; print(json.dumps({'username':'admin','password':os.environ['WARPGATE_ADMIN_PASSWORD']}))")" \
  "https://127.0.0.1/@warpgate/api/auth/login" >/dev/null

EXIST=$(curl -sk -b "$CK" -H "Host: wg.archgate.com.br" "https://127.0.0.1/@warpgate/admin/api/targets")
TID=$(echo "$EXIST" | python3 -c "
import sys,json
for t in json.load(sys.stdin):
  if t.get('name')=='$TARGET_NAME':
    print(t['id']); break
")
WG_HOST_TARGET="archgate-site-piloto_connector"
BODY=$(WG_HOST_TARGET="$WG_HOST_TARGET" CONNECTOR_PORT="$CONNECTOR_PORT" LAB_USER="$LAB_USER" LAB_PASS="$LAB_PASS" TARGET_NAME="$TARGET_NAME" python3 - <<'PY'
import json,os
print(json.dumps({
  "name": os.environ["TARGET_NAME"],
  "description": "Site piloto via WireGuard (connector_peer lab) — not on client LAN",
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
  log "updated $TARGET_NAME"
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
  log "created $TARGET_NAME"
fi
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
  log "role $TARGET_ROLE bound"
fi
rm -f "$CK"

cat > "$STATE_DIR/piloto.env" <<EOF
SITE_NET=$SITE_NET
WG_NET=$WG_NET
SITE_SSH_IP=$SITE_SSH_IP
CONN_IP=$CONN_IP
CONNECTOR_PORT=$CONNECTOR_PORT
TARGET_NAME=$TARGET_NAME
TARGET_ROLE=$TARGET_ROLE
LAB_USER=$LAB_USER
LAB_PASS=$LAB_PASS
MODE=wireguard
EOF
chmod 600 "$STATE_DIR/piloto.env"

echo ""
echo "=============================================="
echo " WG PILOTO LAB DEPLOYED"
echo "=============================================="
echo "  site SSH:     $SITE_SSH_IP ($SITE_NET only)"
echo "  site agent:   WG + forward (tunnel_agent)"
echo "  platform:     $CONN_IP:$CONNECTOR_PORT (archgate-data + WG)"
echo "  connector on site-net? NO (required)"
echo "  warpgate:     $TARGET_NAME → connector"
echo "  smoke:        bash deploy/connector/smoke-connector-piloto.sh"
echo "=============================================="
