#!/usr/bin/env bash
# Sync Kanidm operators → Guacamole users + multi-tenant connection ACLs (ADR-007A / ADR-008).
#
# - Creates/enables Guacamole users for members of SYNC_GROUPS (default archguard_users)
# - Ensures tenant-scoped browser connections (rio / marra)
# - Grants READ only for connections matching the user's Kanidm tenant groups
# - Super admins (archguard_super_admins) get all connections
#
# Usage:
#   bash deploy/guacamole/provision-kanidm-users.sh
#   DRY_RUN=1 bash ...
set -euo pipefail

BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
KANIDM_URL="${KANIDM_URL:-https://id.archgate.com.br}"
SYNC_GROUPS="${SYNC_GROUPS:-archguard_users}"
DRY_RUN="${DRY_RUN:-0}"
DISABLE_STALE="${DISABLE_STALE:-1}"
LAB_SSH_HOST="${LAB_SSH_HOST:-}"   # auto-detect if empty
LAB_SSH_PORT="${LAB_SSH_PORT:-2222}"
LAB_SSH_USER="${LAB_SSH_USER:-labuser}"
LAB_SSH_PASS="${LAB_SSH_PASS:-ArchGateLabSsh2026}"

log()  { echo "  [OK] $1" >&2; }
warn() { echo "  [!!] $1" >&2; }
fail() { echo "  [FAIL] $1" >&2; exit 1; }

if [[ -f "$BOOTSTRAP" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$BOOTSTRAP"
  set +a
fi
: "${ARCHGUARD_SA_TOKEN:?}"
LAB_SSH_PASS="${LAB_SSH_PASS:-${LAB_SSH_PASSWORD:-ArchGateLabSsh2026}}"

# --- Guacamole internal API ---
GUAC_IP=$(docker inspect "$(docker ps -q --filter name=archgate-gw_guacamole | head -1)" \
  --format '{{(index .NetworkSettings.Networks "archgate-public").IPAddress}}' 2>/dev/null || true)
[[ -n "$GUAC_IP" ]] || fail "guacamole public IP not found"

gcurl() {
  docker run --rm --network archgate-public curlimages/curl:8.5.0 -sS "$@"
}

TOK=$(gcurl -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'username=guacadmin&password=guacadmin' "http://${GUAC_IP}:8080/api/tokens")
AUTH=$(echo "$TOK" | python3 -c 'import sys,json; print(json.load(sys.stdin)["authToken"])')
DS=$(echo "$TOK" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("dataSource","postgresql"))')
[[ -n "$AUTH" ]] || fail "guacadmin login failed"

gapi() {
  local method="$1" path="$2" data="${3:-}"
  if [[ -n "$data" ]]; then
    gcurl -X "$method" -H "Guacamole-Token: $AUTH" -H "Content-Type: application/json" \
      -d "$data" "http://${GUAC_IP}:8080${path}?token=${AUTH}"
  else
    gcurl -X "$method" -H "Guacamole-Token: $AUTH" \
      "http://${GUAC_IP}:8080${path}?token=${AUTH}"
  fi
}

# Detect lab SSH IP on archgate-data (exclude archgate-lab_ssh-ca)
if [[ -z "$LAB_SSH_HOST" ]]; then
  CID=$(docker ps --format '{{.ID}} {{.Names}}' | awk '$2 ~ /archgate-lab_ssh\./ && $2 !~ /ssh-ca/ {print $1; exit}')
  [[ -n "$CID" ]] || CID=$(docker ps --format '{{.ID}} {{.Names}}' | awk '$2 ~ /archgate-lab_ssh/ && $2 !~ /ssh-ca|piloto/ {print $1; exit}')
  if [[ -n "$CID" ]]; then
    LAB_SSH_HOST=$(docker inspect "$CID" --format '{{(index .NetworkSettings.Networks "archgate-data").IPAddress}}' 2>/dev/null || true)
  fi
fi
[[ -n "$LAB_SSH_HOST" ]] || LAB_SSH_HOST="10.0.2.99"
log "using LAB_SSH_HOST=$LAB_SSH_HOST"

echo "=== Guacamole multi-tenant sync ==="
echo "  lab_ssh=$LAB_SSH_HOST:$LAB_SSH_PORT dry_run=$DRY_RUN"

# --- Ensure tenant connections ---
ensure_connection() {
  local name="$1" desc="$2"
  local conns cid body
  conns=$(gapi GET "/api/session/data/${DS}/connections")
  cid=$(echo "$conns" | python3 -c "
import sys,json
name=sys.argv[1]
d=json.load(sys.stdin)
for k,v in (d.items() if isinstance(d,dict) else []):
  if isinstance(v,dict) and v.get('name')==name:
    print(k); break
" "$name")
  if [[ -n "$cid" ]]; then
    echo "$cid"
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log "DRY would create connection $name"
    echo "NEW"
    return 0
  fi
  body=$(LAB_SSH_HOST="$LAB_SSH_HOST" LAB_SSH_PORT="$LAB_SSH_PORT" LAB_SSH_USER="$LAB_SSH_USER" LAB_SSH_PASS="$LAB_SSH_PASS" NAME="$name" python3 - <<'PY'
import json,os
print(json.dumps({
  "parentIdentifier": "ROOT",
  "name": os.environ["NAME"],
  "protocol": "ssh",
  "parameters": {
    "hostname": os.environ["LAB_SSH_HOST"],
    "port": os.environ["LAB_SSH_PORT"],
    "username": os.environ["LAB_SSH_USER"],
    "password": os.environ["LAB_SSH_PASS"],
    "recording-path": "/recordings",
    "recording-name": "${GUAC_DATE}-${GUAC_TIME}-${GUAC_USERNAME}-"+os.environ["NAME"],
    "create-recording-path": "true",
    "typescript-path": "/recordings",
    "typescript-name": "${GUAC_DATE}-${GUAC_TIME}-${GUAC_USERNAME}-"+os.environ["NAME"]+"-ts",
    "create-typescript-path": "true",
  },
  "attributes": {},
}))
PY
)
  resp=$(gapi POST "/api/session/data/${DS}/connections" "$body")
  cid=$(echo "$resp" | python3 -c 'import sys,json
try:
 d=json.load(sys.stdin)
 print(d.get("identifier") or d.get("name") or "")
except Exception:
 print("")
' 2>/dev/null || true)
  # re-list
  conns=$(gapi GET "/api/session/data/${DS}/connections")
  cid=$(echo "$conns" | python3 -c "
import sys,json
name=sys.argv[1]
d=json.load(sys.stdin)
for k,v in (d.items() if isinstance(d,dict) else []):
  if isinstance(v,dict) and v.get('name')==name:
    print(k); break
" "$name")
  [[ -n "$cid" ]] || fail "failed to create connection $name: $resp"
  log "created connection $name id=$cid"
  echo "$cid"
}

CONN_RIO=$(ensure_connection "rio-lab-ssh-browser" "Tenant Rio Quality SSH browser")
CONN_MARRA=$(ensure_connection "marra-lab-ssh-browser" "Tenant Grupo Marra SSH browser")
# Keep legacy lab-ssh-browser as shared break-glass for super admins only
CONN_LAB=$(ensure_connection "lab-ssh-browser" "Shared lab SSH browser")

echo "  connections: rio=$CONN_RIO marra=$CONN_MARRA lab=$CONN_LAB"

# --- Kanidm: users + tenant membership ---
# shellcheck disable=SC2206
GROUP_ARR=($SYNC_GROUPS)

export ARCHGUARD_SA_TOKEN KANIDM_URL
# Build JSON map: username -> {super:bool, tenants:[...]}
USER_MAP=$(
  python3 - <<PY
import json,os,re,urllib.request,ssl

token=os.environ["ARCHGUARD_SA_TOKEN"]
base=os.environ.get("KANIDM_URL","https://id.archgate.com.br")
ctx=ssl._create_unverified_context()

def api(path):
  req=urllib.request.Request(base+path, headers={"Authorization":"Bearer "+token})
  with urllib.request.urlopen(req, context=ctx, timeout=30) as r:
    return json.loads(r.read().decode())

groups = """$SYNC_GROUPS""".split()
members=set()
for g in groups:
  try:
    arr=api(f"/v1/group/{g}/_attr/member")
    if isinstance(arr,list):
      for m in arr:
        if isinstance(m,str):
          short=m.split("@")[0]
          if short and not re.match(r"^[0-9a-f]{8}-", short) and not re.search(r"^(idm_|archguard-sa|archgate-agent)", short, re.I):
            members.add(short)
  except Exception as e:
    pass

# super admins
supers=set()
try:
  arr=api("/v1/group/archguard_super_admins/_attr/member")
  if isinstance(arr,list):
    for m in arr:
      if isinstance(m,str):
        supers.add(m.split("@")[0])
except Exception:
  pass

out={}
for u in sorted(members):
  tenants=[]
  try:
    mem=api(f"/v1/person/{u}/_attr/memberof")
    names=[]
    if isinstance(mem,list):
      names=[x.split("@")[0] if isinstance(x,str) else x for x in mem]
    if "tenant_rio_quality" in names:
      tenants.append("rio")
    if "tenant_grupo_marra" in names:
      tenants.append("marra")
  except Exception:
    # try with spn
    try:
      mem=api(f"/v1/person/{u}@id.archgate.com.br/_attr/memberof")
      names=[x.split("@")[0] for x in mem if isinstance(x,str)]
      if "tenant_rio_quality" in names: tenants.append("rio")
      if "tenant_grupo_marra" in names: tenants.append("marra")
    except Exception:
      pass
  out[u]={"super": u in supers, "tenants": tenants}

print(json.dumps(out, indent=2))
PY
)

echo "  user_map:"
echo "$USER_MAP" | python3 -m json.tool | head -80

ensure_user() {
  local u="$1"
  local pass body getu
  pass=$(openssl rand -base64 18 | tr -d '/+=' | head -c 20)
  if [[ "$DRY_RUN" == "1" ]]; then
    log "DRY user $u"
    return 0
  fi
  body=$(python3 -c "import json; print(json.dumps({
    'username': '''$u''',
    'password': '''$pass''',
    'attributes': {'disabled':'','expired':'','access-window-start':'','access-window-end':'','valid-from':'','valid-until':'','timezone': None}
  }))")
  gapi POST "/api/session/data/${DS}/users" "$body" >/dev/null 2>&1 || true
  getu=$(gapi GET "/api/session/data/${DS}/users/${u}" || true)
  echo "$getu" | grep -q "\"username\":\"${u}\"" || fail "user $u missing"
  # enable
  gapi PUT "/api/session/data/${DS}/users/${u}" "$(python3 -c "
import json
print(json.dumps({'username':'''$u''','attributes':{'disabled':'','expired':'','access-window-start':'','access-window-end':'','valid-from':'','valid-until':'','timezone':None}}))
")" >/dev/null 2>&1 || true
  log "user $u present"
}

set_permissions() {
  local u="$1"
  shift
  local cids=("$@")
  if [[ "$DRY_RUN" == "1" ]]; then
    log "DRY perms $u → ${cids[*]}"
    return 0
  fi
  # Diff-based: remove only extras, add only missing (remove requires value=READ)
  local ops
  ops=$(gapi GET "/api/session/data/${DS}/users/${u}/permissions" | WANT="${cids[*]}" python3 -c '
import sys, json, os
want = set(x for x in os.environ.get("WANT", "").split() if x and x != "NEW")
try:
    have = set((json.load(sys.stdin).get("connectionPermissions") or {}).keys())
except Exception:
    have = set()
ops = []
for c in sorted(have - want):
    ops.append({"op": "remove", "path": f"/connectionPermissions/{c}", "value": "READ"})
for c in sorted(want - have):
    ops.append({"op": "add", "path": f"/connectionPermissions/{c}", "value": "READ"})
print(json.dumps(ops))
')
  if [[ "$ops" != "[]" ]]; then
    gapi PATCH "/api/session/data/${DS}/users/${u}/permissions" "$ops" >/dev/null || true
  fi
  log "perms $u → cids=[${cids[*]}]"
}

# Iterate users
echo "$USER_MAP" | python3 -c 'import sys,json; d=json.load(sys.stdin); print("\n".join(d.keys()))' | while read -r u; do
  [[ -z "$u" ]] && continue
  ensure_user "$u"
  meta=$(echo "$USER_MAP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get(sys.argv[1],{})))" "$u")
  is_super=$(echo "$meta" | python3 -c 'import sys,json; print("1" if json.load(sys.stdin).get("super") else "0")')
  tenants=$(echo "$meta" | python3 -c 'import sys,json; print(" ".join(json.load(sys.stdin).get("tenants",[])))')

  grant=()
  if [[ "$is_super" == "1" ]]; then
    grant=("$CONN_RIO" "$CONN_MARRA" "$CONN_LAB")
  else
    echo " $tenants " | grep -q " rio " && grant+=("$CONN_RIO") || true
    # also match without spaces
    [[ " $tenants " == *" rio "* ]] || [[ "$tenants" == "rio" || "$tenants" == *"rio"* ]] && grant+=("$CONN_RIO") || true
    [[ "$tenants" == *marra* ]] && grant+=("$CONN_MARRA") || true
    # de-dup
    grant=($(printf '%s\n' "${grant[@]:-}" | awk 'NF && !s[$0]++'))
  fi
  if [[ ${#grant[@]} -eq 0 ]]; then
    warn "user $u has no tenant mapping — no connection grants"
    set_permissions "$u"  # clear only
  else
    set_permissions "$u" "${grant[@]}"
  fi
done

# Authoritative ACL pass (env-based; do not pipe JSON into heredoc stdin)
if [[ "$DRY_RUN" != "1" ]]; then
  USER_MAP="$USER_MAP" CONN_RIO="$CONN_RIO" CONN_MARRA="$CONN_MARRA" CONN_LAB="$CONN_LAB" \
  DS="$DS" GUAC_IP="$GUAC_IP" AUTH="$AUTH" python3 - <<'PY'
import json, os, subprocess, sys

user_map = json.loads(os.environ["USER_MAP"])
conn_rio = os.environ["CONN_RIO"]
conn_marra = os.environ["CONN_MARRA"]
conn_lab = os.environ["CONN_LAB"]
ds = os.environ["DS"]
guac = os.environ["GUAC_IP"]
auth = os.environ["AUTH"]

def gapi(method, path, data=None):
    cmd = [
        "docker", "run", "--rm", "--network", "archgate-public",
        "curlimages/curl:8.5.0", "-sS", "-X", method,
        "-H", f"Guacamole-Token: {auth}",
    ]
    url = f"http://{guac}:8080{path}?token={auth}"
    if data is not None:
        cmd += ["-H", "Content-Type: application/json", "-d", json.dumps(data), url]
    else:
        cmd += [url]
    return subprocess.check_output(cmd, text=True)

for u, meta in user_map.items():
    if meta.get("super"):
        want = [conn_rio, conn_marra, conn_lab]
    else:
        want = []
        if "rio" in meta.get("tenants", []):
            want.append(conn_rio)
        if "marra" in meta.get("tenants", []):
            want.append(conn_marra)
    # Diff-based
    try:
        cur = json.loads(gapi("GET", f"/api/session/data/{ds}/users/{u}/permissions"))
        have = set((cur.get("connectionPermissions") or {}).keys())
    except Exception:
        have = set()
    want_s = set(c for c in want if c and c != "NEW")
    ops = []
    for c in sorted(have - want_s):
        ops.append({"op": "remove", "path": f"/connectionPermissions/{c}", "value": "READ"})
    for c in sorted(want_s - have):
        ops.append({"op": "add", "path": f"/connectionPermissions/{c}", "value": "READ"})
    try:
        if ops:
            gapi("PATCH", f"/api/session/data/{ds}/users/{u}/permissions", ops)
        print(f"  [OK] acl {u} → {sorted(want_s)}", file=sys.stderr)
    except Exception as e:
        print(f"  [!!] acl {u}: {e}", file=sys.stderr)
PY
fi

# Disable stale
if [[ "$DISABLE_STALE" == "1" && "$DRY_RUN" != "1" ]]; then
  ALL=$(gapi GET "/api/session/data/${DS}/users")
  echo "$ALL" | USER_MAP="$USER_MAP" python3 -c '
import sys,json,os
keep=set(json.loads(os.environ["USER_MAP"]).keys())|{"guacadmin","admin"}
users=json.load(sys.stdin)
for n in (users.keys() if isinstance(users,dict) else []):
  if n not in keep:
    print(n)
' | while read -r stale; do
    [[ -z "$stale" ]] && continue
    gapi PUT "/api/session/data/${DS}/users/${stale}" "$(python3 -c "
import json
print(json.dumps({'username':'''$stale''','attributes':{'disabled':'true','expired':'','access-window-start':'','access-window-end':'','valid-from':'','valid-until':'','timezone':None}}))
")" >/dev/null 2>&1 || true
    log "disabled stale $stale"
  done
fi

log "guacadmin remains break-glass"
echo "DONE: multi-tenant Guacamole sync"
