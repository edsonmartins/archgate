#!/usr/bin/env bash
# Broker: OpenBao dynamic Postgres creds → Warpgate target passwords (Fase 2 bridge).
#
# Until Warpgate has native Vault/OpenBao integration, this updates target
# credentials via admin API so sessions use short-lived DB users.
#
# Usage:
#   bash broker-warpgate-db.sh              # issue + push to TARGETS
#   bash broker-warpgate-db.sh renew        # same (new lease)
#   bash broker-warpgate-db.sh revoke       # revoke last lease (does not wipe Warpgate)
#   bash broker-warpgate-db.sh status
#
# Env:
#   TARGETS="rio-lab-postgres lab-postgres"  # names to update
#   OPENBAO_ROLE=lab-readonly
set -euo pipefail

BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
STATE_DIR="${STATE_DIR:-/var/lib/archgate/openbao}"
STATE_FILE="${STATE_DIR}/broker-warpgate-db.json"
TARGETS="${TARGETS:-rio-lab-postgres}"
OPENBAO_ROLE="${OPENBAO_ROLE:-lab-readonly}"
CMD="${1:-issue}"

set -a
# shellcheck disable=SC1090
source "$BOOTSTRAP"
set +a

BAO="${OPENBAO_ADDR:-http://127.0.0.1:8200}"
TOK="${OPENBAO_APP_TOKEN:-${OPENBAO_ROOT_TOKEN:?}}"
: "${WARPGATE_ADMIN_PASSWORD:?}"

log()  { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1" >&2; exit 1; }

mkdir -p "$STATE_DIR"

# Unseal if needed
if ! curl -s "$BAO/v1/sys/health" | python3 -c 'import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get("initialized") and not d.get("sealed") else 1)' 2>/dev/null; then
  curl -s -X PUT "$BAO/v1/sys/unseal" -H 'Content-Type: application/json' \
    -d "$(python3 -c "import json,os; print(json.dumps({'key':os.environ['OPENBAO_UNSEAL_KEY']}))")" >/dev/null
  log "OpenBao unsealed"
fi

wg_login() {
  CK=$(mktemp)
  curl -sk -c "$CK" -b "$CK" -H "Host: wg.archgate.com.br" -H "Content-Type: application/json" \
    -d "$(python3 -c "import json,os; print(json.dumps({'username':'admin','password':os.environ['WARPGATE_ADMIN_PASSWORD']}))")" \
    "https://127.0.0.1/@warpgate/api/auth/login" >/dev/null
  echo "$CK"
}

issue_creds() {
  local out
  out=$(curl -s -H "X-Vault-Token: $TOK" "$BAO/v1/database/creds/${OPENBAO_ROLE}")
  echo "$out" | python3 -c 'import sys,json; d=json.load(sys.stdin); assert "data" in d, d'
  echo "$out"
}

push_target() {
  local ck="$1" name="$2" db_user="$3" db_pass="$4"
  local all tid body full
  all=$(curl -sk -b "$ck" -H "Host: wg.archgate.com.br" "https://127.0.0.1/@warpgate/admin/api/targets")
  tid=$(echo "$all" | python3 -c "
import sys,json
name=sys.argv[1]
for t in json.load(sys.stdin):
  if t.get('name')==name:
    print(t['id']); break
" "$name")
  [[ -n "$tid" ]] || fail "target not found: $name"

  full=$(curl -sk -b "$ck" -H "Host: wg.archgate.com.br" \
    "https://127.0.0.1/@warpgate/admin/api/targets/${tid}")
  body=$(echo "$full" | DB_USER="$db_user" DB_PASS="$db_pass" python3 -c '
import sys,json,os
t=json.load(sys.stdin)
o=t.get("options") or {}
o["username"]=os.environ["DB_USER"]
o["password"]=None
auth=o.get("auth") or {}
if isinstance(auth, dict):
  auth["kind"]="Password"
  auth["password"]=os.environ["DB_PASS"]
  o["auth"]=auth
else:
  o["auth"]={"kind":"Password","password":os.environ["DB_PASS"]}
payload={
  "name": t["name"],
  "description": t.get("description") or "brokered OpenBao dynamic creds",
  "options": o,
}
print(json.dumps(payload))
')
  curl -sk -b "$ck" -H "Host: wg.archgate.com.br" -H "Content-Type: application/json" \
    -X PUT -d "$body" "https://127.0.0.1/@warpgate/admin/api/targets/${tid}" >/dev/null
  log "Warpgate target $name ← user=$db_user (ephemeral)"
}

case "$CMD" in
  status)
    if [[ -f "$STATE_FILE" ]]; then
      python3 -m json.tool "$STATE_FILE"
    else
      echo "no state file"
    fi
    ;;
  revoke)
    if [[ ! -f "$STATE_FILE" ]]; then
      fail "no lease to revoke"
    fi
    # Support legacy single lease_id and new leases{} map
    python3 -c '
import json,os,urllib.request
state=json.load(open("'"$STATE_FILE"'"))
tok=os.environ["TOK"] if "TOK" in os.environ else ""
' 2>/dev/null || true
    mapfile -t LEASES < <(python3 -c '
import json
d=json.load(open("'"$STATE_FILE"'"))
if d.get("lease_id"):
  print(d["lease_id"])
for k,v in (d.get("leases") or {}).items():
  if isinstance(v,dict) and v.get("lease_id"):
    print(v["lease_id"])
')
    [[ ${#LEASES[@]} -ge 1 ]] || fail "no lease_id in state"
    for LEASE in "${LEASES[@]}"; do
      curl -s -X PUT -H "X-Vault-Token: $TOK" -H 'Content-Type: application/json' \
        -d "$(python3 -c "import json; print(json.dumps({'lease_id':'''$LEASE'''}))")" \
        "$BAO/v1/sys/leases/revoke" >/dev/null
      log "revoked lease $LEASE"
    done
    ;;
  issue|renew|*)
    # One OpenBao lease per target (isolation / independent revoke)
    CK=$(wg_login)
    # shellcheck disable=SC2206
    TARR=($TARGETS)
    STATE_JSON='{"issued_at":0,"role":"'"$OPENBAO_ROLE"'","leases":{}}'
    python3 -c "import json,time; json.dump({'issued_at':time.time(),'role':'''$OPENBAO_ROLE''','leases':{}}, open('''$STATE_FILE''','w'))"
    for t in "${TARR[@]}"; do
      CREDS=$(issue_creds)
      DB_USER=$(echo "$CREDS" | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["username"])')
      DB_PASS=$(echo "$CREDS" | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["password"])')
      LEASE=$(echo "$CREDS" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("lease_id",""))')
      TTL=$(echo "$CREDS" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("lease_duration",""))')
      log "issued OpenBao role=$OPENBAO_ROLE target=$t user=$DB_USER ttl=${TTL}s"
      push_target "$CK" "$t" "$DB_USER" "$DB_PASS"
      python3 -c "
import json
p='''$STATE_FILE'''
d=json.load(open(p))
d.setdefault('leases',{})['''$t''']={'lease_id':'''$LEASE''','db_user':'''$DB_USER''','lease_duration':'''$TTL'''}
json.dump(d, open(p,'w'), indent=2)
"
    done
    rm -f "$CK"
    chmod 600 "$STATE_FILE"
    log "state → $STATE_FILE (per-target leases)"
    echo "BROKER_OK targets=$TARGETS"
    ;;
esac
