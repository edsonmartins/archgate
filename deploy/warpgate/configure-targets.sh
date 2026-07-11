#!/usr/bin/env bash
# Tasks 3.5–3.7: roles, SSH/PG lab targets, validate no secret leak to user API.
set -euo pipefail

BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
WG_HOST="${WG_HOST:-wg.archgate.com.br}"
BASE="https://127.0.0.1"

set -a
# shellcheck disable=SC1090
source "$BOOTSTRAP"
set +a

: "${WARPGATE_ADMIN_PASSWORD:?}"
: "${LAB_SSH_PASSWORD:?}"
: "${LAB_PG_PASSWORD:?}"
: "${LAB_PG_HOST:?}"
: "${LAB_PG_PORT:?}"
: "${LAB_PG_USER:?}"
: "${LAB_PG_DB:?}"

CK=$(mktemp)
trap 'rm -f "$CK"' EXIT

api() {
  local method="$1" path="$2" data="${3:-}"
  if [[ -n "$data" ]]; then
    curl -sk -b "$CK" -c "$CK" -H "Host: ${WG_HOST}" -H "Content-Type: application/json" \
      -X "$method" -d "$data" "${BASE}${path}"
  else
    curl -sk -b "$CK" -c "$CK" -H "Host: ${WG_HOST}" -H "Content-Type: application/json" \
      -X "$method" "${BASE}${path}"
  fi
}

echo "==> admin login"
LOGIN=$(api POST /@warpgate/api/auth/login \
  "{\"username\":\"admin\",\"password\":$(python3 -c 'import json,os; print(json.dumps(os.environ["WARPGATE_ADMIN_PASSWORD"]))')}")
echo "$LOGIN" | python3 -c 'import sys,json; d=json.load(sys.stdin); print("user", d.get("username", d))'

SSH_CID=$(docker ps -q --filter name=archgate-lab_ssh | head -1)
SSH_IP=$(docker inspect "$SSH_CID" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
echo "SSH lab IP: $SSH_IP"
export SSH_IP LAB_SSH_PASSWORD LAB_PG_HOST LAB_PG_PORT LAB_PG_USER LAB_PG_PASSWORD LAB_PG_DB

echo "==> 3.5 ensure role archgate-operators"
ROLES=$(api GET /@warpgate/admin/api/roles)
ROLE_ID=$(echo "$ROLES" | python3 -c '
import sys,json
for r in json.load(sys.stdin):
  if r.get("name")=="archgate-operators":
    print(r["id"]); break
')
if [[ -z "$ROLE_ID" ]]; then
  ROLE_ID=$(api POST /@warpgate/admin/api/roles \
    '{"name":"archgate-operators","description":"Mapped from Kanidm archguard_users","is_default":true}' \
    | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])')
  echo "created role $ROLE_ID"
else
  echo "role exists $ROLE_ID"
fi

echo "==> 3.6 create/update SSH target lab-ssh"
TARGETS=$(api GET /@warpgate/admin/api/targets)
SSH_TARGET_ID=$(echo "$TARGETS" | python3 -c '
import sys,json
for t in json.load(sys.stdin):
  if t.get("name")=="lab-ssh":
    print(t["id"]); break
')
SSH_BODY=$(python3 -c '
import json,os
print(json.dumps({
  "name": "lab-ssh",
  "description": "Lab OpenSSH (credenciais no gateway)",
  "options": {
    "kind": "Ssh",
    "host": os.environ["SSH_IP"],
    "port": 2222,
    "username": "labuser",
    "auth": {"kind": "Password", "password": os.environ["LAB_SSH_PASSWORD"]}
  }
}))
')
if [[ -z "$SSH_TARGET_ID" ]]; then
  RESP=$(api POST /@warpgate/admin/api/targets "$SSH_BODY")
  echo "ssh: $(echo "$RESP" | head -c 300)"
  SSH_TARGET_ID=$(echo "$RESP" | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])')
else
  api PUT "/@warpgate/admin/api/targets/${SSH_TARGET_ID}" "$SSH_BODY" >/dev/null
fi
echo "lab-ssh=$SSH_TARGET_ID"

echo "==> 3.6 create/update Postgres target lab-postgres"
PG_TARGET_ID=$(echo "$TARGETS" | python3 -c '
import sys,json
for t in json.load(sys.stdin):
  if t.get("name")=="lab-postgres":
    print(t["id"]); break
')
PG_BODY=$(python3 -c '
import json,os
print(json.dumps({
  "name": "lab-postgres",
  "description": "Lab PostgreSQL (credenciais no gateway)",
  "options": {
    "kind": "Postgres",
    "host": os.environ["LAB_PG_HOST"],
    "port": int(os.environ["LAB_PG_PORT"]),
    "username": os.environ["LAB_PG_USER"],
    "default_database_name": os.environ["LAB_PG_DB"],
    "tls": {"mode": "Disabled", "verify": False},
    "auth": {"kind": "Password", "password": os.environ["LAB_PG_PASSWORD"]}
  }
}))
')
if [[ -z "$PG_TARGET_ID" ]]; then
  RESP=$(api POST /@warpgate/admin/api/targets "$PG_BODY")
  echo "pg: $(echo "$RESP" | head -c 400)"
  PG_TARGET_ID=$(echo "$RESP" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("id",""))')
else
  api PUT "/@warpgate/admin/api/targets/${PG_TARGET_ID}" "$PG_BODY" >/dev/null
fi
echo "lab-postgres=$PG_TARGET_ID"

echo "==> assign role to targets"
for tid in "$SSH_TARGET_ID" "$PG_TARGET_ID"; do
  [[ -n "$tid" ]] || continue
  code=$(curl -sk -o /tmp/role_assign.json -w '%{http_code}' -b "$CK" -c "$CK" \
    -H "Host: ${WG_HOST}" -H "Content-Type: application/json" \
    -X POST "${BASE}/@warpgate/admin/api/targets/${tid}/roles/${ROLE_ID}")
  echo "assign target $tid -> role: HTTP $code $(cat /tmp/role_assign.json | head -c 120)"
done

echo "==> user testadmin + SSO email + role"
USERS=$(api GET /@warpgate/admin/api/users)
USER_ID=$(echo "$USERS" | python3 -c '
import sys,json
for u in json.load(sys.stdin):
  if u.get("username")=="testadmin":
    print(u["id"]); break
')
if [[ -z "$USER_ID" ]]; then
  USER_ID=$(api POST /@warpgate/admin/api/users \
    '{"username":"testadmin","description":"SSO operator (Kanidm)"}' \
    | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])')
fi
echo "user=$USER_ID"
api POST "/@warpgate/admin/api/users/${USER_ID}/credentials/sso" \
  '{"email":"testadmin@archgate.com.br","provider":"kanidm"}' >/dev/null 2>&1 || true
api POST "/@warpgate/admin/api/users/${USER_ID}/roles/${ROLE_ID}" >/dev/null 2>&1 || true

echo "==> 3.7 secrets not in user-facing targets"
export LAB_SSH_PASSWORD LAB_PG_PASSWORD
api GET /@warpgate/api/targets | python3 -c '
import sys,json,os
data=json.load(sys.stdin)
items=data if isinstance(data,list) else data.get("targets",[])
s=json.dumps(data)
for b in [os.environ["LAB_SSH_PASSWORD"], os.environ["LAB_PG_PASSWORD"]]:
    if b and b in s:
        raise SystemExit("FAIL: secret leaked in /api/targets")
print("OK: secrets not in user /api/targets")
if isinstance(items, list):
    print("user_visible_targets", [t.get("name") for t in items])
'

echo "==> admin view of targets (credentials only server-side)"
api GET /@warpgate/admin/api/targets | python3 -c '
import sys,json
for t in json.load(sys.stdin):
  if t.get("name") in ("lab-ssh","lab-postgres"):
    o=t.get("options") or {}
    print(t["name"], "kind="+str(o.get("kind")), "host="+str(o.get("host")), "port="+str(o.get("port")))
'

# minimize password UI (optional global)
echo "==> list SSO providers from config (running)"
curl -sk -o /dev/null -w "login_page=%{http_code}\n" -H "Host: ${WG_HOST}" "$BASE/"

echo ""
echo "DONE"
echo "  role archgate-operators=$ROLE_ID"
echo "  lab-ssh=$SSH_TARGET_ID"
echo "  lab-postgres=$PG_TARGET_ID"
echo "  SSO: https://${WG_HOST} → ArchGuard (Kanidm)"
echo "  Zero-credencial-no-dev: LAB_* passwords only in Warpgate admin config"
