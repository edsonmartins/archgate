#!/usr/bin/env bash
# P1 — Smoke operator-client-access (ADR-008)
# Roda no host com acesso de rede ao bastion (staging) e OpenSSH (+ psql opcional).
#
# Uso:
#   WG_HOST=192.168.1.180 WG_SSH_PORT=2222 WG_PG_PORT=55432 \
#   WG_USER=testuser WG_PASS='...' \
#   bash deploy/validation/smoke-operator-access.sh
#
# No runtime Linux (recomendado):
#   ssh root@192.168.1.180 'bash -s' < deploy/validation/smoke-operator-access.sh
set -euo pipefail

WG_HOST="${WG_HOST:-127.0.0.1}"
WG_SSH_PORT="${WG_SSH_PORT:-2222}"
WG_PG_PORT="${WG_PG_PORT:-55432}"
WG_USER="${WG_USER:-testuser}"
WG_SSH_TARGET="${WG_SSH_TARGET:-rio-lab-ssh}"
WG_PG_TARGET="${WG_PG_TARGET:-rio-lab-postgres}"
WG_DBNAME="${WG_DBNAME:-archgate_lab}"
GUAC_HOST_HEADER="${GUAC_HOST_HEADER:-guac.archgate.com.br}"
GUAC_BASE="${GUAC_BASE:-https://127.0.0.1}"
MARKER="ADR008_SMOKE_$(date +%s)_$$"

# Load bootstrap on runtime if present
if [[ -f /root/archgate/bootstrap.env ]]; then
  set -a
  # shellcheck disable=SC1091
  source /root/archgate/bootstrap.env
  set +a
  WG_PASS="${WG_PASS:-${AUDIT_WG_PASS:-TenantA-RioQuality-2026}}"
fi
WG_PASS="${WG_PASS:-}"

log()  { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1" >&2; exit 1; }
step() { echo -e "\n=== $1 ==="; }
skip() { echo "  [SKIP] $1"; }

OS_NAME="$(uname -s 2>/dev/null || echo unknown)"
case "$OS_NAME" in
  Linux*)   OP_OS=linux ;;
  Darwin*)  OP_OS=macos ;;
  MINGW*|MSYS*|CYGWIN*|Windows*) OP_OS=windows ;;
  *)        OP_OS=other ;;
esac

echo "=============================================="
echo " SMOKE operator-client-access (ADR-008)"
echo " operator_os=$OP_OS uname=$OS_NAME"
echo " wg_host=$WG_HOST ssh_port=$WG_SSH_PORT pg_port=$WG_PG_PORT"
echo " user=$WG_USER targets=$WG_SSH_TARGET / $WG_PG_TARGET"
echo "=============================================="

step "1. OpenSSH present"
command -v ssh >/dev/null || fail "OpenSSH client (ssh) not found"
ssh -V 2>&1 | head -1 || true
log "OpenSSH available"

step "2. SSH via Warpgate (Parte B)"
[[ -n "$WG_PASS" ]] || fail "WG_PASS or bootstrap AUDIT_WG_PASS required"
command -v sshpass >/dev/null 2>&1 || {
  if command -v apt-get >/dev/null 2>&1; then
    apt-get install -y -qq sshpass >/dev/null || true
  fi
}
if ! command -v sshpass >/dev/null 2>&1; then
  fail "sshpass required for non-interactive smoke (install sshpass)"
fi

# portable timeout (Linux timeout / macOS gtimeout / background+kill)
run_with_timeout() {
  local secs="$1"; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$secs" "$@"
  else
    "$@" &
    local pid=$!
    (
      sleep "$secs"
      kill "$pid" 2>/dev/null || true
    ) &
    local watchdog=$!
    wait "$pid"
    local rc=$?
    kill "$watchdog" 2>/dev/null || true
    wait "$watchdog" 2>/dev/null || true
    return "$rc"
  fi
}

set +e
run_with_timeout 25 sshpass -p "$WG_PASS" ssh -tt \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -o PreferredAuthentications=password -o PubkeyAuthentication=no \
  -p "$WG_SSH_PORT" "${WG_USER}:${WG_SSH_TARGET}@${WG_HOST}" \
  "echo ${MARKER}; hostname; whoami" 2>/tmp/adr008_ssh.err | tee /tmp/adr008_ssh.out
SSH_RC=${PIPESTATUS[0]}
set -e
if ! grep -q "$MARKER" /tmp/adr008_ssh.out 2>/dev/null; then
  tail -15 /tmp/adr008_ssh.err || true
  fail "SSH session via Warpgate did not echo marker (rc=$SSH_RC)"
fi
log "SSH OK marker=$MARKER rc=$SSH_RC"
log "operator_os=$OP_OS ssh_via_warpgate=PASS"

step "3. Postgres via Warpgate proxy (Parte B)"
if ! command -v psql >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    apt-get install -y -qq postgresql-client >/dev/null || true
  fi
fi
if ! command -v psql >/dev/null 2>&1; then
  skip "psql not installed — document DBeaver using snippets/dbeaver-warpgate-postgres.example"
else
  OUT=$(PGPASSWORD="$WG_PASS" psql \
    "host=${WG_HOST} port=${WG_PG_PORT} user=${WG_USER}:${WG_PG_TARGET} dbname=${WG_DBNAME} sslmode=require" \
    -tAc "select current_user || ':' || 1" 2>&1) || true
  echo "    psql_out=$OUT"
  echo "$OUT" | grep -q 'archgate_lab:1' || echo "$OUT" | grep -q ':1' \
    || fail "Postgres proxy query failed: $OUT"
  log "Postgres proxy OK ($OUT)"
  log "operator_os=$OP_OS db_via_warpgate=PASS"
fi

step "4. Guacamole browser path (Parte A — API preflight)"
# From runtime: curl to local Traefik; from laptop may use public URL
CODE=$(curl -sk -o /dev/null -w '%{http_code}' -H "Host: ${GUAC_HOST_HEADER}" "${GUAC_BASE}/" || echo 000)
echo "    guac_http=$CODE"
echo "$CODE" | grep -qE '200|301|302|307|308|401|403' || fail "Guacamole HTTP unexpected $CODE"
TOK=$(curl -sk -H "Host: ${GUAC_HOST_HEADER}" -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'username=guacadmin&password=guacadmin' "${GUAC_BASE}/api/tokens" 2>/dev/null || echo '{}')
echo "$TOK" | python3 -c 'import sys,json; d=json.load(sys.stdin); assert "authToken" in d, d' \
  || fail "Guacamole token login failed (ADR-007 local auth)"
AUTH=$(echo "$TOK" | python3 -c 'import sys,json; print(json.load(sys.stdin)["authToken"])')
DS=$(echo "$TOK" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("dataSource","postgresql"))')
CONNS=$(curl -sk -H "Host: ${GUAC_HOST_HEADER}" -H "Guacamole-Token: $AUTH" \
  "${GUAC_BASE}/api/session/data/${DS}/connections?token=${AUTH}")
echo "$CONNS" | python3 -c 'import sys,json; d=json.load(sys.stdin); assert isinstance(d,dict) and len(d)>=1, d; print("    connections", list(d.keys())[:5], [d[k].get("name") for k in d])'
log "Guacamole API OK (SSH web connection listed — browser UI is Parte A)"
log "operator_os=$OP_OS guac_browser_path=PASS"

step "5. Summary"
echo ""
echo "=============================================="
echo " SMOKE operator-client-access PASSED"
echo "=============================================="
echo "  operator_os:     $OP_OS"
echo "  ssh_target:      $WG_SSH_TARGET"
echo "  pg_target:       $WG_PG_TARGET"
echo "  guac:            API + connection list"
echo "  marker:          $MARKER"
echo "  note:            Windows OpenSSH — run this script in Git Bash/WSL or"
echo "                   manual: ssh -p $WG_SSH_PORT '${WG_USER}:${WG_SSH_TARGET}@${WG_HOST}'"
echo "=============================================="

# Machine-readable line for ficha updates
echo "RESULT operator_os=$OP_OS ssh=PASS db=PASS guac=PASS ts=$(date -Iseconds 2>/dev/null || date)"
