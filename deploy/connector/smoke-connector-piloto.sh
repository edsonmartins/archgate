#!/usr/bin/env bash
# Prove site connector path (Fase 3 parcial)
set -euo pipefail
BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
ENVF="${ENVF:-/var/lib/archgate/connector/piloto.env}"
set -a
# shellcheck disable=SC1090
[[ -f "$BOOTSTRAP" ]] && source "$BOOTSTRAP"
[[ -f "$ENVF" ]] && source "$ENVF"
set +a

log()  { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1" >&2; exit 1; }
step() { echo -e "\n=== $1 ==="; }

TARGET_NAME="${TARGET_NAME:-piloto-lab-ssh}"
CONNECTOR_PORT="${CONNECTOR_PORT:-2223}"
LAB_USER="${LAB_USER:-labuser}"
LAB_PASS="${LAB_PASS:-ArchGatePilotoSsh2026}"
WG_USER="${WG_USER:-testuser}"
WG_PASS="${WG_PASS:-${AUDIT_WG_PASS:-TenantA-RioQuality-2026}}"
MARKER="CONN_PILOTO_$(date +%s)"

MODE="${MODE:-socat}"
step "1. Services up (mode=${MODE})"
docker service ls --format '{{.Name}} {{.Replicas}}' | grep -E 'piloto' || fail "piloto services missing"
docker service ls --format '{{.Name}} {{.Replicas}}' | grep 'archgate-site-piloto_ssh' | grep -q '1/1' || fail "site ssh not 1/1"
docker service ls --format '{{.Name}} {{.Replicas}}' | grep 'archgate-site-piloto_connector' | grep -q '1/1' || fail "connector not 1/1"
case "$MODE" in
  wireguard)
    docker service ls --format '{{.Name}} {{.Replicas}}' | grep 'archgate-site-piloto_agent' | grep -q '1/1' || fail "site agent not 1/1"
    log "piloto ssh + connector + WG agent 1/1"
    ;;
  openvpn)
    docker service ls --format '{{.Name}} {{.Replicas}}' | grep 'archgate-site-piloto_ovpn-srv' | grep -q '1/1' || fail "ovpn server not 1/1"
    log "piloto ssh + connector + OpenVPN server 1/1"
    ;;
  *)
    log "piloto ssh + connector 1/1 (mode=$MODE)"
    ;;
esac

step "2. Site SSH is NOT on archgate-data"
CID=$(docker ps -q --filter name=archgate-site-piloto_ssh | head -1)
[[ -n "$CID" ]] || fail "site ssh container missing"
NETS=$(docker inspect "$CID" --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}')
echo "    networks: $NETS"
echo "$NETS" | grep -q 'archgate-site-piloto' || fail "site ssh not on site net"
echo "$NETS" | grep -q 'archgate-data' && fail "site ssh must NOT be on archgate-data" || true
log "site SSH isolated from archgate-data"

step "3. Warpgate container cannot SSH site IP directly (optional if SITE_SSH_IP known)"
if [[ -n "${SITE_SSH_IP:-}" ]]; then
  # from warpgate network namespace: try connect site IP:2222 should fail/timeout
  set +e
  docker run --rm --network archgate-data alpine:3.20 \
    sh -c "apk add --no-cache busybox-extras >/dev/null 2>&1; nc -z -w 2 $SITE_SSH_IP 2222" 2>/dev/null
  RC=$?
  set -e
  if [[ $RC -eq 0 ]]; then
    warn() { echo "  [!!] $1"; }
    warn "site IP reachable from data (unexpected for pure isolation)"
  else
    log "site IP :2222 not reachable from archgate-data (expected)"
  fi
else
  log "SITE_SSH_IP unknown — skip direct reachability check"
fi

step "4. Connector forwards from archgate-data"
CONN_CID=$(docker ps -q --filter name=archgate-site-piloto_connector | head -1)
CONN_IP=$(docker inspect "$CONN_CID" --format '{{(index .NetworkSettings.Networks "archgate-data").IPAddress}}')
[[ -n "$CONN_IP" ]] || fail "connector data IP missing"
if [[ "$MODE" == "wireguard" || "$MODE" == "openvpn" ]]; then
  CNETS=$(docker inspect "$CONN_CID" --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}')
  echo "    connector networks: $CNETS"
  echo "$CNETS" | grep -q 'archgate-site-piloto' && fail "$MODE connector must NOT attach site-net" || true
  log "connector not on site-net ($MODE tunnel path)"
fi
docker run --rm --network archgate-data alpine:3.20 \
  sh -c "apk add --no-cache openssh-client sshpass >/dev/null 2>&1 && \
    sshpass -p '$LAB_PASS' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -p $CONNECTOR_PORT ${LAB_USER}@${CONN_IP} 'echo PATH_OK'" | grep -q PATH_OK \
  || fail "connector forward failed"
log "data → connector → site SSH works"

step "5. Operator path: Warpgate SSH target ${TARGET_NAME}"
command -v sshpass >/dev/null || apt-get install -y -qq sshpass >/dev/null
set +e
timeout 30 sshpass -p "$WG_PASS" ssh -tt \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -o PreferredAuthentications=password -o PubkeyAuthentication=no \
  -p 2222 "${WG_USER}:${TARGET_NAME}@127.0.0.1" \
  "echo ${MARKER}; hostname; whoami" 2>/tmp/piloto_ssh.err | tee /tmp/piloto_ssh.out
set -e
grep -q "$MARKER" /tmp/piloto_ssh.out || { tail -20 /tmp/piloto_ssh.err; fail "Warpgate session to $TARGET_NAME failed"; }
log "operator via Warpgate → connector → site (marker $MARKER)"

step "6. Summary"
echo ""
echo "=============================================="
echo " CONNECTOR PILOTO SMOKE PASSED"
echo "=============================================="
echo "  Isolation: site SSH not on archgate-data"
case "$MODE" in
  wireguard) echo "  Path:      data → connector ~~~ WG ~~~ site-agent → site" ;;
  openvpn)   echo "  Path:      data → connector ~~~ OpenVPN ~~~ site → SSH" ;;
  *)         echo "  Path:      data → connector → site (socat dual-homed)" ;;
esac
echo "  Bastion:   $WG_USER:$TARGET_NAME via Warpgate"
echo "  Pattern:   1 path institucional, N operadores (SSO) — ADR-008"
echo "  Mode:      $MODE"
echo "=============================================="
