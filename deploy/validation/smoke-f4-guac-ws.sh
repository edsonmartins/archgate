#!/usr/bin/env bash
# F4 E2E: BFF mint real Guac token + WebSocket open (HTTP/1.1 upgrade).
# Usage (from laptop or VPS):
#   bash deploy/validation/smoke-f4-guac-ws.sh
#   CONSOLE_BASE=https://console.archgate.com.br \
#   GUAC_BASE=https://guac.archgate.com.br \
#   LAB_BEARER=lab-uat-op-a \
#   TARGET=lab-ssh-browser \
#   bash deploy/validation/smoke-f4-guac-ws.sh
set -euo pipefail

CONSOLE_BASE="${CONSOLE_BASE:-https://console.archgate.com.br}"
GUAC_BASE="${GUAC_BASE:-https://guac.archgate.com.br}"
LAB_BEARER="${LAB_BEARER:-lab-uat-op-a}"
TARGET="${TARGET:-lab-ssh-browser}"
CONNECTION_ID="${CONNECTION_ID:-rio_quality_lab:${TARGET}}"
API="${CONSOLE_BASE%/}/api"

PASS=0
FAIL=0
log()  { echo "  [OK] $*"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $*"; FAIL=$((FAIL + 1)); }
step() { echo -e "\n=== $* ==="; }

step "1. Catalog (Bearer lab)"
CAT=$(curl -sk -H "Authorization: Bearer ${LAB_BEARER}" \
  -H "Accept: application/json" \
  "${API}/unified/v1/connections" || true)
if echo "$CAT" | python3 -c 'import sys,json; d=json.load(sys.stdin); assert "connections" in d' 2>/dev/null; then
  N=$(echo "$CAT" | python3 -c 'import sys,json; print(len(json.load(sys.stdin).get("connections",[])))')
  log "connections n=$N"
else
  fail "catalog: ${CAT:0:160}"
fi

if echo "$CAT" | python3 -c 'import sys,json; cs=json.load(sys.stdin).get("connections",[]);
sys.exit(0 if any(c.get("target")==sys.argv[1] for c in cs) else 1)' "$TARGET" 2>/dev/null; then
  log "target «${TARGET}» in catalog"
else
  fail "target «${TARGET}» missing (seed site / Guac apply first)"
fi

step "2. Mint session (POST /unified/v1/sessions)"
SESS=$(curl -sk -X POST \
  -H "Authorization: Bearer ${LAB_BEARER}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "{\"connection_id\":\"${CONNECTION_ID}\",\"target\":\"${TARGET}\",\"protocol\":\"ssh\"}" \
  "${API}/unified/v1/sessions" || true)

printf '%s' "$SESS" > /tmp/archgate-f4-session.json
python3 - <<'PY' || { fail "sessions parse: ${SESS:0:200}"; exit 1; }
import json
from urllib.parse import parse_qs
from pathlib import Path
d=json.loads(Path("/tmp/archgate-f4-session.json").read_text())
assert d.get("embed_mode")=="websocket", d
assert "websocket-tunnel" in (d.get("tunnel_url") or ""), d
cd=d.get("connect_data") or ""
qs=parse_qs(cd)
assert qs.get("token"), qs
assert qs.get("GUAC_ID"), qs
assert qs.get("GUAC_DATA_SOURCE"), qs
print("token_len", len(qs["token"][0]))
print("guac_id", qs["GUAC_ID"][0])
print("ds", qs["GUAC_DATA_SOURCE"][0])
print("tunnel", d["tunnel_url"])
PY
log "mint websocket token"

step "3. WebSocket upgrade (HTTP/1.1) to Guac"
# Build wss URL with connect_data query (same as guacamole-common-js Client.connect)
python3 - <<'PY'
import json, ssl, sys, urllib.parse
from pathlib import Path

d = json.loads(Path("/tmp/archgate-f4-session.json").read_text())
base = d["tunnel_url"]  # wss://…
# Prefer public GUAC from env override already in tunnel_url
cd = d["connect_data"]
if "?" in base:
    url = base + "&" + cd
else:
    url = base + "?" + cd

# websockets may not be installed — use stdlib
import http.client
import base64
import os
import hashlib

u = urllib.parse.urlparse(url)
assert u.scheme in ("wss", "ws"), u
host = u.hostname
port = u.port or (443 if u.scheme == "wss" else 80)
path = u.path or "/"
if u.query:
    path = path + "?" + u.query

key = base64.b64encode(os.urandom(16)).decode()
headers = {
    "Host": host,
    "Upgrade": "websocket",
    "Connection": "Upgrade",
    "Sec-WebSocket-Key": key,
    "Sec-WebSocket-Version": "13",
}
ctx = ssl.create_default_context()
# lab / some edge certs
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

if u.scheme == "wss":
    conn = http.client.HTTPSConnection(host, port, context=ctx, timeout=8)
else:
    conn = http.client.HTTPConnection(host, port, timeout=8)

# Force HTTP/1.1 path (required for WS upgrade; h2 returns 404 on this stack)
conn._http_vsn = 11
conn._http_vsn_str = "HTTP/1.1"
conn.putrequest("GET", path, skip_host=True, skip_accept_encoding=True)
for k, v in headers.items():
    conn.putheader(k, v)
conn.endheaders()
resp = conn.getresponse()
status = resp.status
body = resp.read(200)
print(f"ws_status={status}")
if status != 101:
    print("body", body[:120])
    sys.exit(1)
# Optional: read one frame timeout
conn.sock.settimeout(2)
try:
    peek = conn.sock.recv(64)
    print(f"first_bytes={len(peek)}")
except Exception as e:
    print(f"first_frame={type(e).__name__}")
conn.close()
print("WS_UPGRADE_OK")
PY
log "WebSocket 101 + connect_data"

step "4. Summary"
echo "  console=$CONSOLE_BASE target=$TARGET"
echo "  PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
echo "SMOKE_F4_GUAC_WS_PASS"
