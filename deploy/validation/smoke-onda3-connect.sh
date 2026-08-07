#!/usr/bin/env bash
# Onda 3 smoke suite: catalog + F4 Guac token path + F15 MySQL bastion + version manifest.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONSOLE_BASE="${CONSOLE_BASE:-https://console.archgate.com.br}"
# Lab bearer = lab-<user>:<shared secret>. The console refuses a bare
# "lab-<user>", so this smoke needs the same secret it was deployed with
# (ARCHGATE_CONNECT_LAB_TOKEN in bootstrap.env). Audit 2026-07-28, P0-1.
LAB_USER="${LAB_USER:-uat-op-a}"
if [ -z "${LAB_BEARER:-}" ]; then
  if [ -z "${ARCHGATE_CONNECT_LAB_TOKEN:-}" ]; then
    echo "ERROR: set ARCHGATE_CONNECT_LAB_TOKEN (or LAB_BEARER) — lab path is fail-closed" >&2
    exit 2
  fi
  LAB_BEARER="lab-${LAB_USER}:${ARCHGATE_CONNECT_LAB_TOKEN}"
fi
API="${CONSOLE_BASE%/}/api"
BASTION_HOST="${BASTION_HOST:-217.196.60.108}"
PASS=0
FAIL=0

log()  { echo "  [OK] $*"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $*"; FAIL=$((FAIL + 1)); }
step() { echo -e "\n=== $* ==="; }

step "1. Catalog (Bearer lab)"
CAT=$(curl -sk -H "Authorization: Bearer ${LAB_BEARER}" -H "Accept: application/json" \
  "${API}/unified/v1/connections" || true)
if echo "$CAT" | python3 -c 'import sys,json; d=json.load(sys.stdin); assert "connections" in d and len(d["connections"])>0' 2>/dev/null; then
  N=$(echo "$CAT" | python3 -c 'import sys,json; print(len(json.load(sys.stdin)["connections"]))')
  log "connections n=$N"
else
  fail "catalog broken: ${CAT:0:160}"
fi

if echo "$CAT" | python3 -c 'import sys,json; cs=json.load(sys.stdin)["connections"];
sys.exit(0 if any(c.get("target")=="lab-mysql" and c.get("protocol")=="mysql" for c in cs) else 1)' 2>/dev/null; then
  log "lab-mysql protocol=mysql"
else
  fail "lab-mysql missing or wrong protocol"
fi

if echo "$CAT" | python3 -c 'import sys,json; cs=json.load(sys.stdin)["connections"];
sys.exit(0 if any(c.get("target")=="lab-ssh-browser" and c.get("engine")=="guacamole" for c in cs) else 1)' 2>/dev/null; then
  log "lab-ssh-browser guacamole in catalog"
else
  fail "lab-ssh-browser missing"
fi

step "2. F4 sessions mint (Guac)"
SESS=$(curl -sk -X POST -H "Authorization: Bearer ${LAB_BEARER}" -H "Content-Type: application/json" \
  -d '{"connection_id":"rio_quality_lab:lab-ssh-browser","target":"lab-ssh-browser","protocol":"ssh"}' \
  "${API}/unified/v1/sessions" || true)
if echo "$SESS" | python3 -c 'import sys,json; d=json.load(sys.stdin);
assert d.get("embed_mode")=="websocket"
assert "token=" in (d.get("connect_data") or "")
assert "GUAC_ID=" in (d.get("connect_data") or "")' 2>/dev/null; then
  log "Guac connect_data token+GUAC_ID"
else
  fail "F4 sessions: ${SESS:0:200}"
fi

step "3. F15 MySQL bastion TCP"
python3 - <<PY || fail "TCP 33306"
import socket
s=socket.create_connection(("${BASTION_HOST}", 33306), timeout=8)
b=s.recv(48)
s.close()
assert b and b"Warpgate" in b, b
print("greeting", b[5:20])
PY
log "MySQL proxy greeting Warpgate"

step "4. Version manifest"
MAN="${ROOT}/clients/archgate-connect/version-manifest.json"
if [[ -f "$MAN" ]]; then
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["latest"]["version"]' "$MAN"
  log "local version-manifest.json ok"
else
  fail "manifest missing"
fi
# remote (best-effort; may lag until push)
if curl -skf "https://raw.githubusercontent.com/edsonmartins/archgate/main/clients/archgate-connect/version-manifest.json" \
  | python3 -c 'import sys,json; d=json.load(sys.stdin); assert d.get("latest",{}).get("version")' 2>/dev/null; then
  log "remote manifest fetch ok"
else
  echo "  [WARN] remote manifest not yet on main (push first)"
fi

step "5. Sub-smokes (optional)"
if [[ "${SKIP_SUB:-0}" != "1" ]]; then
  if [[ -x "${ROOT}/deploy/validation/smoke-f4-guac-ws.sh" ]]; then
    if bash "${ROOT}/deploy/validation/smoke-f4-guac-ws.sh" >/tmp/smoke-f4-sub.log 2>&1; then
      log "smoke-f4-guac-ws PASS"
    else
      fail "smoke-f4-guac-ws (see /tmp/smoke-f4-sub.log)"
    fi
  fi
fi

step "Summary"
echo "  PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
echo "SMOKE_ONDA3_CONNECT_PASS"
