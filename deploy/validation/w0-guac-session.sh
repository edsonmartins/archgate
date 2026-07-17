#!/usr/bin/env bash
# W0-A02 automated path: Guacamole SSO gate + header-auth session for UAT personas.
# Does not replace a human opening the browser once, but proves API session + ACL.
set -euo pipefail

BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
PASS=0
FAIL=0

log()  { echo "  [OK] $*"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }
step() { echo -e "\n=== $* ==="; }

[[ -f "$BOOTSTRAP" ]] && { set -a; # shellcheck disable=SC1090
  source "$BOOTSTRAP"; set +a; }

GUAC_CID=$(docker ps -q --filter name=archgate-gw_guacamole | head -1)
[[ -n "$GUAC_CID" ]] || { fail "guacamole container missing"; exit 1; }
GUAC_IP=$(docker inspect "$GUAC_CID" --format '{{(index .NetworkSettings.Networks "archgate-public").IPAddress}}')
[[ -n "$GUAC_IP" ]] || { fail "guac IP missing"; exit 1; }

gcurl() {
  docker run --rm --network archgate-public curlimages/curl:8.5.0 -sS "$@"
}

step "1. SSO gate"
CODE=$(curl -sk -o /dev/null -w '%{http_code}' -H 'Host: guac.archgate.com.br' https://127.0.0.1/)
[[ "$CODE" == "302" || "$CODE" == "303" || "$CODE" == "307" ]] && log "unauth → $CODE" || fail "gate http=$CODE"

step "2. Header-auth sessions (proxy hop simulation)"
for user in testuser uat-op-a uat-admin uat-viewer; do
  TOK=$(gcurl -H "X-Forwarded-User: ${user}" -H "Content-Type: application/x-www-form-urlencoded" \
    -d "" "http://${GUAC_IP}:8080/api/tokens" || true)
  if ! echo "$TOK" | python3 -c 'import sys,json; d=json.load(sys.stdin); assert d.get("authToken") and d.get("username")==sys.argv[1]' "$user" 2>/dev/null; then
    fail "token for $user: ${TOK:0:120}"
    continue
  fi
  AUTH=$(echo "$TOK" | python3 -c 'import sys,json; print(json.load(sys.stdin)["authToken"])')
  # Header provider + connection inventory on postgresql DS (ADR-007A e2e pattern)
  CONNS=$(gcurl -H "Guacamole-Token: $AUTH" \
    "http://${GUAC_IP}:8080/api/session/data/postgresql/connections?token=${AUTH}")
  NAMES=$(echo "$CONNS" | python3 -c 'import sys,json
d=json.load(sys.stdin)
if not isinstance(d,dict) or d.get("message"):
  print("ERR")
else:
  print(",".join(sorted(v.get("name","") for v in d.values() if isinstance(v,dict))))
' 2>/dev/null || echo "ERR")
  if [[ "$NAMES" == "ERR" ]]; then
    fail "$user token OK but connections failed: ${CONNS:0:120}"
  else
    log "$user → token OK; connections=[$NAMES]"
  fi
done

step "3. Tenant ACL (uat-op-a: rio only, no marra)"
TOK=$(gcurl -H "X-Forwarded-User: uat-op-a" -H "Content-Type: application/x-www-form-urlencoded" -d "" \
  "http://${GUAC_IP}:8080/api/tokens")
AUTH=$(echo "$TOK" | python3 -c 'import sys,json; print(json.load(sys.stdin)["authToken"])')
CONNS=$(gcurl -H "Guacamole-Token: $AUTH" \
  "http://${GUAC_IP}:8080/api/session/data/postgresql/connections?token=${AUTH}")
echo "$CONNS" | python3 -c '
import sys,json
d=json.load(sys.stdin)
assert isinstance(d,dict) and not d.get("message"), d
names=[v.get("name","") for v in d.values() if isinstance(v,dict)]
print("    uat-op-a sees:", names)
bad=[n for n in names if "marra" in n.lower()]
sys.exit(1 if bad else 0)
' && log "uat-op-a ACL: no marra connections exposed" || fail "uat-op-a sees marra connections"

step "4. Browser SSH connection for uat-op-a"
echo "$CONNS" | python3 -c '
import sys,json
d=json.load(sys.stdin)
names=[v.get("name","") for v in d.values() if isinstance(v,dict)]
ok=any("rio" in n.lower() or "ssh" in n.lower() or "browser" in n.lower() for n in names)
sys.exit(0 if ok else 1)
' && log "browser SSH connection available for uat-op-a" || fail "no browser SSH connection for uat-op-a"

echo ""
echo "=============================================="
echo " W0 guac session API: PASS=$PASS FAIL=$FAIL"
echo " Human optional: open https://guac.archgate.com.br once (SSO) for visual sign-off"
echo "=============================================="
[[ "$FAIL" -eq 0 ]]
