#!/usr/bin/env bash
# Smoke mock oracle-proxy HTTP API (no Oracle DB).
# Usage:
#   # proxy already running on :9040
#   bash deploy/oracle-proxy/smoke-oracle-proxy-mock.sh
#   ORACLE_PROXY_URL=http://127.0.0.1:9040 bash ...
set -euo pipefail

BASE="${ORACLE_PROXY_URL:-http://127.0.0.1:9040}"
USER="v_smoke$(date +%s | tail -c 6)"
PASS='SmokeTest123!'

log() { echo "  [OK] $*"; }
fail() { echo "  [FAIL] $*" >&2; exit 1; }

curl -sfS "$BASE/actuator/health" | grep -qi UP || fail "health not UP"
log "health UP"

code=$(curl -sS -o /tmp/or-create.json -w '%{http_code}' -X POST "$BASE/v1/oracle/users" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$USER\",\"password\":\"$PASS\",\"statements\":{\"creation_statements\":\"CREATE USER {{username}} IDENTIFIED BY \\\"{{password}}\\\"\"}}")
[[ "$code" == "200" ]] || fail "create HTTP $code $(cat /tmp/or-create.json)"
log "create $USER"

code=$(curl -sS -o /tmp/or-del.json -w '%{http_code}' -X POST "$BASE/v1/oracle/users/delete" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$USER\"}")
[[ "$code" == "200" ]] || fail "delete HTTP $code"
log "delete $USER"

# oversize username
long="u$(python3 -c 'print("x"*40)')"
code=$(curl -sS -o /tmp/or-long.json -w '%{http_code}' -X POST "$BASE/v1/oracle/users" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$long\",\"password\":\"x\"}")
[[ "$code" == "400" ]] || fail "expected 400 for long user got $code"
log "reject long username"

echo "=============================================="
echo " ORACLE PROXY MOCK SMOKE PASSED"
echo "=============================================="
