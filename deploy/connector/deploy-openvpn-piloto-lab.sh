#!/usr/bin/env bash
# Fase 3 — piloto OpenVPN (tunnel_agent pattern)
# Server no "site" + client no connector plataforma (sem dual-home site-net no connector).
set -euo pipefail

BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
SITE_NET="${SITE_NET:-archgate-site-piloto}"
SITE_SUBNET="${SITE_SUBNET:-10.77.10.0/24}"
OVPN_NET="${OVPN_NET:-archgate-ovpn-lab}"
OVPN_SUBNET="${OVPN_SUBNET:-10.66.77.0/24}"
TARGET_NAME="${TARGET_NAME:-piloto-lab-ssh}"
TARGET_ROLE="${TARGET_ROLE:-tenant-rio-quality}"
SSH_IMAGE="${SSH_IMAGE:-lscr.io/linuxserver/openssh-server:latest}"
LAB_USER="${LAB_USER:-labuser}"
LAB_PASS="${LAB_PASS:-ArchGatePilotoSsh2026}"
CONNECTOR_PORT="${CONNECTOR_PORT:-2223}"
STATE_DIR="${STATE_DIR:-/var/lib/archgate/connector}"
PKI="${STATE_DIR}/openvpn-pki"
CFG="${STATE_DIR}/openvpn"

set -a
# shellcheck disable=SC1090
[[ -f "$BOOTSTRAP" ]] && source "$BOOTSTRAP"
set +a

log() { echo "  [OK] $1"; }
step() { echo -e "\n=== $1 ==="; }
fail() { echo "  [FAIL] $1" >&2; exit 1; }

mkdir -p "$PKI" "$CFG"
chmod 700 "$STATE_DIR" "$PKI" "$CFG"

step "0. PKI lab (openssl + keyUsage for OpenVPN 2.6 remote-cert-tls)"
# Always refresh if missing server KU (old lab certs fail VERIFY KU ERROR)
NEED_PKI=0
[[ -f "$PKI/server.crt" ]] || NEED_PKI=1
if [[ -f "$PKI/server.crt" ]] && ! openssl x509 -in "$PKI/server.crt" -noout -text 2>/dev/null | grep -q "TLS Web Server"; then
  NEED_PKI=1
fi
if [[ "$NEED_PKI" == "1" ]]; then
  rm -rf "$PKI"
  mkdir -p "$PKI"
  cat > "$PKI/ext-ca.cnf" <<'EOF'
basicConstraints=critical,CA:TRUE
keyUsage=critical,keyCertSign,cRLSign
subjectKeyIdentifier=hash
EOF
  cat > "$PKI/ext-server.cnf" <<'EOF'
basicConstraints=CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
EOF
  cat > "$PKI/ext-client.cnf" <<'EOF'
basicConstraints=CA:FALSE
keyUsage=critical,digitalSignature
extendedKeyUsage=clientAuth
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
EOF
  openssl req -x509 -newkey rsa:2048 -nodes -keyout "$PKI/ca.key" -out "$PKI/ca.crt" \
    -days 3650 -subj "/CN=ArchGate-OVPN-Lab-CA" -extensions v3_ca -config <(cat /etc/ssl/openssl.cnf <(echo -e "[v3_ca]\nbasicConstraints=critical,CA:TRUE\nkeyUsage=critical,keyCertSign,cRLSign")) 2>/dev/null \
    || openssl req -x509 -newkey rsa:2048 -nodes -keyout "$PKI/ca.key" -out "$PKI/ca.crt" \
      -days 3650 -subj "/CN=ArchGate-OVPN-Lab-CA" 2>/dev/null
  for name in server client; do
    openssl req -newkey rsa:2048 -nodes -keyout "$PKI/${name}.key" -out "$PKI/${name}.csr" \
      -subj "/CN=archgate-ovpn-${name}" 2>/dev/null
    openssl x509 -req -in "$PKI/${name}.csr" -CA "$PKI/ca.crt" -CAkey "$PKI/ca.key" \
      -CAcreateserial -out "$PKI/${name}.crt" -days 3650 \
      -extfile "$PKI/ext-${name}.cnf" 2>/dev/null
  done
  openvpn --genkey secret "$PKI/ta.key" 2>/dev/null || openvpn --genkey --secret "$PKI/ta.key"
  log "PKI generated in $PKI (with EKU)"
else
  log "reusing PKI $PKI"
fi
chmod 600 "$PKI"/* 2>/dev/null || true

# Server/client configs (UDP on OVPN_NET; tunnel 10.8.0.0/24)
cat > "$CFG/server.conf" <<'EOF'
port 1194
proto udp
dev tun
topology subnet
server 10.8.0.0 255.255.255.0
keepalive 10 60
persist-key
persist-tun
duplicate-cn
verb 3
# certs mounted at /pki
ca /pki/ca.crt
cert /pki/server.crt
key /pki/server.key
dh none
ecdh-curve prime256v1
tls-crypt /pki/ta.key
cipher AES-256-GCM
data-ciphers AES-256-GCM
explicit-exit-notify 1
EOF

cat > "$CFG/client.conf" <<'EOF'
client
dev tun
proto udp
# remote filled at runtime
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
verb 3
ca /pki/ca.crt
cert /pki/client.crt
key /pki/client.key
tls-crypt /pki/ta.key
cipher AES-256-GCM
data-ciphers AES-256-GCM
EOF

cat > "$CFG/run-server.sh" <<'EOS'
#!/bin/sh
set -eu
apk add --no-cache openvpn iptables iproute2 socat bind-tools >/dev/null
mkdir -p /dev/net
[ -e /dev/net/tun ] || mknod /dev/net/tun c 10 200
# openvpn server
openvpn --config /cfg/server.conf --daemon --writepid /tmp/ovpn.pid
sleep 2
# wait tun
i=0
while [ $i -lt 30 ]; do
  ip addr show tun0 >/dev/null 2>&1 && break
  i=$((i+1)); sleep 1
done
ip addr show tun0 || { echo "tun0 missing"; cat /tmp/openvpn.log 2>/dev/null; exit 1; }
echo "OVPN server up; socat on 10.8.0.1:2222 -> site SSH DNS"
# DNS to site ssh on same site-net
exec socat TCP-LISTEN:2222,bind=10.8.0.1,fork,reuseaddr TCP:archgate-site-piloto_ssh:2222
EOS
chmod +x "$CFG/run-server.sh"

cat > "$CFG/run-client.sh" <<'EOS'
#!/bin/sh
set -eu
apk add --no-cache openvpn iptables iproute2 socat bind-tools >/dev/null
mkdir -p /dev/net
[ -e /dev/net/tun ] || mknod /dev/net/tun c 10 200

SRV=""
i=0
while [ $i -lt 60 ]; do
  SRV=$(getent hosts tasks.archgate-site-piloto_ovpn-srv 2>/dev/null | awk '{print $1; exit}')
  [ -z "$SRV" ] && SRV=$(getent hosts archgate-site-piloto_ovpn-srv 2>/dev/null | awk '{print $1; exit}')
  [ -n "$SRV" ] && [ "$SRV" != "127.0.0.1" ] && break
  i=$((i+1)); sleep 2
done
echo "OpenVPN server endpoint=$SRV"
cp /cfg/client.conf /tmp/client.conf
echo "remote $SRV 1194" >> /tmp/client.conf
openvpn --config /tmp/client.conf --daemon --writepid /tmp/ovpn.pid
i=0
while [ $i -lt 40 ]; do
  ip addr show tun0 >/dev/null 2>&1 && break
  i=$((i+1)); sleep 1
done
ip addr show tun0 || exit 1
# wait server-side socat
i=0
while [ $i -lt 40 ]; do
  if nc -z -w 2 10.8.0.1 2222 2>/dev/null; then break; fi
  i=$((i+1)); sleep 1
done
echo "client tun up; socat :${CONNECTOR_PORT:-2223} -> 10.8.0.1:2222"
exec socat TCP-LISTEN:${CONNECTOR_PORT:-2223},fork,reuseaddr TCP:10.8.0.1:2222
EOS
# inject port for client
sed -i "s/\${CONNECTOR_PORT:-2223}/${CONNECTOR_PORT}/g" "$CFG/run-client.sh" 2>/dev/null || \
  sed -i '' "s/\${CONNECTOR_PORT:-2223}/${CONNECTOR_PORT}/g" "$CFG/run-client.sh" 2>/dev/null || true
# rewrite client with fixed port
cat > "$CFG/run-client.sh" <<EOS
#!/bin/sh
set -eu
apk add --no-cache openvpn iptables iproute2 socat bind-tools busybox-extras >/dev/null
mkdir -p /dev/net
[ -e /dev/net/tun ] || mknod /dev/net/tun c 10 200

SRV=""
i=0
while [ \$i -lt 60 ]; do
  SRV=\$(getent hosts tasks.archgate-site-piloto_ovpn-srv 2>/dev/null | awk '{print \$1; exit}')
  [ -z "\$SRV" ] && SRV=\$(getent hosts archgate-site-piloto_ovpn-srv 2>/dev/null | awk '{print \$1; exit}')
  [ -n "\$SRV" ] && [ "\$SRV" != "127.0.0.1" ] && break
  i=\$((i+1)); sleep 2
done
echo "OpenVPN server endpoint=\$SRV"
cp /cfg/client.conf /tmp/client.conf
echo "remote \$SRV 1194" >> /tmp/client.conf
# foreground log then daemonize via script control
openvpn --config /tmp/client.conf --log /tmp/ovpn-client.log --daemon --writepid /tmp/ovpn.pid || true
i=0
while [ \$i -lt 40 ]; do
  ip addr show tun0 >/dev/null 2>&1 && break
  i=\$((i+1)); sleep 1
done
if ! ip addr show tun0 >/dev/null 2>&1; then
  echo "tun0 failed; openvpn log:"
  cat /tmp/ovpn-client.log 2>/dev/null || true
  # retry foreground once for diagnostics then exit
  openvpn --config /tmp/client.conf --verb 4 || true
  exit 1
fi
i=0
while [ \$i -lt 40 ]; do
  if nc -z -w 2 10.8.0.1 2222 2>/dev/null; then break; fi
  i=\$((i+1)); sleep 1
done
echo "client tun up; socat :${CONNECTOR_PORT} -> 10.8.0.1:2222"
exec socat TCP-LISTEN:${CONNECTOR_PORT},fork,reuseaddr TCP:10.8.0.1:2222
EOS
chmod +x "$CFG/run-client.sh" "$CFG/run-server.sh"

step "1. Networks"
for net_sub in "$SITE_NET:$SITE_SUBNET" "$OVPN_NET:$OVPN_SUBNET"; do
  net="${net_sub%%:*}"; sub="${net_sub##*:}"
  if ! docker network ls --format '{{.Name}}' | grep -qx "$net"; then
    docker network create --driver overlay --attachable --subnet "$sub" "$net"
    log "created $net"
  else
    log "$net exists"
  fi
done

step "2. Tear old piloto connector variants (keep data nets)"
for s in archgate-site-piloto_ssh archgate-site-piloto_connector archgate-site-piloto_agent \
         archgate-site-piloto_ovpn-srv; do
  docker service rm "$s" 2>/dev/null || true
done
sleep 3

step "3. Site SSH"
docker service create \
  --name archgate-site-piloto_ssh \
  --network "$SITE_NET" \
  --constraint 'node.labels.archgate.runtime == true' \
  --env PUID=1000 --env PGID=1000 --env TZ=America/Sao_Paulo \
  --env USER_NAME="$LAB_USER" --env USER_PASSWORD="$LAB_PASS" \
  --env PASSWORD_ACCESS=true --env SUDO_ACCESS=false \
  --restart-condition on-failure --detach=true \
  "$SSH_IMAGE"
log "site ssh"

step "4. OpenVPN server (site-net + transport) + socat on tunnel"
docker service create \
  --name archgate-site-piloto_ovpn-srv \
  --network "$SITE_NET" \
  --network "$OVPN_NET" \
  --constraint 'node.labels.archgate.runtime == true' \
  --cap-add NET_ADMIN \
  --cap-add NET_RAW \
  --mount type=bind,source="$PKI",target=/pki,readonly \
  --mount type=bind,source="$CFG",target=/cfg,readonly \
  --restart-condition on-failure --detach=true \
  alpine:3.20 \
  sh /cfg/run-server.sh
log "ovpn server"

sleep 5
step "5. Platform connector = OpenVPN client (data + transport) — NOT on site-net"
docker service create \
  --name archgate-site-piloto_connector \
  --network archgate-data \
  --network "$OVPN_NET" \
  --constraint 'node.labels.archgate.runtime == true' \
  --cap-add NET_ADMIN \
  --cap-add NET_RAW \
  --mount type=bind,source="$PKI",target=/pki,readonly \
  --mount type=bind,source="$CFG",target=/cfg,readonly \
  --restart-condition on-failure --detach=true \
  alpine:3.20 \
  sh /cfg/run-client.sh
log "ovpn client connector"

step "6. Wait path"
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
          -o ConnectTimeout=5 -p $CONNECTOR_PORT ${LAB_USER}@${CONN_IP} 'echo OVPN_PATH_OK'" 2>/dev/null | grep -q OVPN_PATH_OK; then
      log "OpenVPN path OK $CONN_IP:$CONNECTOR_PORT"
      break
    fi
  fi
  echo "  wait path try $i conn=$CONN_IP"
  sleep 3
done
[[ -n "$CONN_IP" ]] || fail "no connector IP"
CONN_CID=$(docker ps -q --filter name=archgate-site-piloto_connector | head -1)
CONN_NETS=$(docker inspect "$CONN_CID" --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}')
echo "    connector networks: $CONN_NETS"
echo "$CONN_NETS" | grep -q 'archgate-site-piloto' && fail "connector must NOT be on site-net" || log "connector not on site-net"

step "7. Warpgate target (recreate to refresh host key)"
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
if [[ -n "$TID" ]]; then
  curl -sk -b "$CK" -H "Host: wg.archgate.com.br" -X DELETE \
    "https://127.0.0.1/@warpgate/admin/api/targets/${TID}" >/dev/null || true
  log "deleted old target (host key refresh)"
fi
BODY=$(python3 - <<PY
import json
print(json.dumps({
  "name": "$TARGET_NAME",
  "description": "Site piloto via OpenVPN client no connector (tunnel_agent lab)",
  "options": {
    "kind": "Ssh",
    "host": "archgate-site-piloto_connector",
    "port": $CONNECTOR_PORT,
    "username": "$LAB_USER",
    "auth": {"kind": "Password", "password": "$LAB_PASS"},
  }
}))
PY
)
curl -sk -b "$CK" -H "Host: wg.archgate.com.br" -H "Content-Type: application/json" \
  -X POST -d "$BODY" "https://127.0.0.1/@warpgate/admin/api/targets" >/dev/null
EXIST=$(curl -sk -b "$CK" -H "Host: wg.archgate.com.br" "https://127.0.0.1/@warpgate/admin/api/targets")
TID=$(echo "$EXIST" | python3 -c "
import sys,json
for t in json.load(sys.stdin):
  if t.get('name')=='$TARGET_NAME':
    print(t['id']); break
")
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
fi
rm -f "$CK"
log "target $TARGET_NAME ready"

SITE_SSH_IP=$(docker inspect "$(docker ps -q --filter name=archgate-site-piloto_ssh | head -1)" \
  --format "{{(index .NetworkSettings.Networks \"${SITE_NET}\").IPAddress}}" 2>/dev/null || true)

cat > "$STATE_DIR/piloto.env" <<EOF
SITE_NET=$SITE_NET
OVPN_NET=$OVPN_NET
SITE_SSH_IP=$SITE_SSH_IP
CONN_IP=$CONN_IP
CONNECTOR_PORT=$CONNECTOR_PORT
TARGET_NAME=$TARGET_NAME
TARGET_ROLE=$TARGET_ROLE
LAB_USER=$LAB_USER
LAB_PASS=$LAB_PASS
MODE=openvpn
EOF
chmod 600 "$STATE_DIR/piloto.env"

echo ""
echo "=============================================="
echo " OPENVPN PILOTO LAB DEPLOYED"
echo "=============================================="
echo "  stack:     openvpn (tunnel_agent)"
echo "  server:    site-net + $OVPN_NET"
echo "  client:    archgate-data + $OVPN_NET (NOT site-net)"
echo "  path:      data → connector ~~~ OVPN ~~~ site → SSH"
echo "  warpgate:  $TARGET_NAME"
echo "  smoke:     MODE=openvpn bash deploy/connector/smoke-connector-piloto.sh"
echo "=============================================="
