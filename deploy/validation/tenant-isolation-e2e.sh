#!/usr/bin/env bash
# Task 6.2 — Isolamento multi-tenant
# WHEN usuário do tenant A lista targets no Warpgate
# THEN não enxerga targets do tenant B
set -euo pipefail

BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
archguard_URL="${archguard_URL:-https://127.0.0.1:8443}"
DOMAIN="${archguard_DOMAIN:-id.archgate.com.br}"
TOOLS="${archguard_TOOLS_IMAGE:-archguard/tools:1.10.4}"
WG_HOST="${WG_HOST:-wg.archgate.com.br}"
BASE="https://127.0.0.1"

set -a
# shellcheck disable=SC1090
source "$BOOTSTRAP"
set +a

log()  { echo "  [OK] $1" >&2; }
fail() { echo "  [FAIL] $1" >&2; exit 1; }
step() { echo -e "\n=== $1 ===" >&2; }

CID=$(docker ps --filter name=archgate-id_archguardd --format '{{.ID}}' | head -1)
[[ -n "$CID" ]] || fail "archguard down"
[[ -n "${WARPGATE_ADMIN_PASSWORD:-}" ]] || fail "WARPGATE_ADMIN_PASSWORD missing"
[[ -n "${LAB_SSH_PASSWORD:-}" && -n "${LAB_PG_PASSWORD:-}" ]] || fail "lab secrets missing"

if [[ -z "${archguard_IDM_ADMIN_PASSWORD:-}" ]]; then
  archguard_IDM_ADMIN_PASSWORD=$(docker exec "$CID" /sbin/archguardd recover-account idm_admin -c /data/server.toml 2>&1 \
    | sed -n 's/.*new_password: "\([^"]*\)".*/\1/p' | tail -1)
fi
IDM_PASS="$archguard_IDM_ADMIN_PASSWORD"

SSH_IP=$(docker inspect "$(docker ps -q --filter name=archgate-lab_ssh | head -1)" \
  --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
export SSH_IP LAB_SSH_PASSWORD LAB_PG_HOST LAB_PG_PORT LAB_PG_USER LAB_PG_PASSWORD LAB_PG_DB

rest_auth() {
  local user="$1" pass="$2" hdr cookie response
  hdr=$(mktemp)
  curl -sk -X POST "$archguard_URL/v1/auth" -H "Content-Type: application/json" \
    -d "{\"step\":{\"init\":\"$user\"}}" -D "$hdr" -o /dev/null
  cookie=$(grep -i set-cookie "$hdr" | sed 's/.*auth-session-id=\([^;]*\).*/\1/' | tr -d '\r' | head -1)
  rm -f "$hdr"
  [[ -n "$cookie" ]] || { echo ""; return 0; }
  curl -sk -X POST "$archguard_URL/v1/auth" -H "Content-Type: application/json" \
    -H "Cookie: auth-session-id=$cookie" -d '{"step":{"begin":"password"}}' >/dev/null
  response=$(curl -sk -X POST "$archguard_URL/v1/auth" -H "Content-Type: application/json" \
    -H "Cookie: auth-session-id=$cookie" \
    -d "$(python3 -c 'import json,sys; print(json.dumps({"step":{"cred":{"password":sys.argv[1]}}}))' "$pass")")
  echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('state',{}).get('success',''))" 2>/dev/null || true
}

api_k() {
  local token="$1" method="$2" path="$3" body="${4:-}"
  if [[ -n "$body" ]]; then
    curl -sk -X "$method" "$archguard_URL$path" -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" -d "$body"
  else
    curl -sk -X "$method" "$archguard_URL$path" -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json"
  fi
}

TOKENS=$(mktemp)
CK_ADMIN=$(mktemp)
trap 'rm -f "$TOKENS" "$CK_ADMIN"' EXIT

klogin() {
  expect <<EOF >/dev/null
set timeout 60
spawn docker run --rm -it --network host -v $TOKENS:/root/.cache/archguard_tokens -e archguard_URL=$archguard_URL $TOOLS /sbin/archguard login --accept-invalid-certs --name idm_admin
expect -re "password:"
send "$IDM_PASS\r"
expect eof
EOF
}

kcli() {
  docker run --rm --network host -v "$TOKENS:/root/.cache/archguard_tokens" -e "archguard_URL=$archguard_URL" \
    $TOOLS /sbin/archguard "$@" --accept-invalid-certs --name idm_admin 2>&1 | grep -v WARN || true
}

set_pw() {
  local person="$1" pass="$2"
  expect <<EOF >/dev/null
set timeout 60
spawn docker run --rm -it --network host -v $TOKENS:/root/.cache/archguard_tokens -e archguard_URL=$archguard_URL $TOOLS /sbin/archguard person credential update --accept-invalid-certs --name idm_admin $person
expect "cred update"
send "password\r"
expect "New password:"
send "$pass\r"
expect "Confirm password:"
send "$pass\r"
expect "cred update"
send "commit\r"
expect {
  -re "y/n" { send "y\r" }
  eof {}
}
expect eof
EOF
}

wg_login() {
  local user="$1" pass="$2" ck="$3"
  curl -sk -c "$ck" -b "$ck" -H "Host: ${WG_HOST}" -H "Content-Type: application/json" \
    -d "$(python3 -c 'import json,sys; print(json.dumps({"username":sys.argv[1],"password":sys.argv[2]}))' "$user" "$pass")" \
    "${BASE}/@warpgate/api/auth/login" >/dev/null
}

wg_api() {
  local ck="$1" method="$2" path="$3" data="${4:-}"
  if [[ -n "$data" ]]; then
    curl -sk -b "$ck" -c "$ck" -H "Host: ${WG_HOST}" -H "Content-Type: application/json" \
      -X "$method" -d "$data" "${BASE}${path}"
  else
    curl -sk -b "$ck" -c "$ck" -H "Host: ${WG_HOST}" -H "Content-Type: application/json" \
      -X "$method" "${BASE}${path}"
  fi
}

ensure_role() {
  local name="$1" desc="$2"
  local roles id
  roles=$(wg_api "$CK_ADMIN" GET /@warpgate/admin/api/roles)
  id=$(echo "$roles" | python3 -c "import sys,json
for r in json.load(sys.stdin):
  if r.get('name')==sys.argv[1]:
    print(r['id']); break" "$name")
  if [[ -z "$id" ]]; then
    id=$(wg_api "$CK_ADMIN" POST /@warpgate/admin/api/roles \
      "$(python3 -c 'import json,sys; print(json.dumps({"name":sys.argv[1],"description":sys.argv[2],"is_default":False}))' "$name" "$desc")" \
      | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])')
    log "created role $name"
  else
    log "role exists $name"
  fi
  echo "$id"
}

ensure_target() {
  local name="$1" kind="$2"  # kind=Ssh|Postgres
  local targets id body
  targets=$(wg_api "$CK_ADMIN" GET /@warpgate/admin/api/targets)
  id=$(echo "$targets" | python3 -c "import sys,json
for t in json.load(sys.stdin):
  if t.get('name')==sys.argv[1]:
    print(t['id']); break" "$name")
  if [[ "$kind" == "Ssh" ]]; then
    body=$(python3 -c 'import json,os,sys
print(json.dumps({"name":sys.argv[1],"description":sys.argv[2],"options":{
  "kind":"Ssh","host":os.environ["SSH_IP"],"port":2222,"username":"labuser",
  "auth":{"kind":"Password","password":os.environ["LAB_SSH_PASSWORD"]}
}}))' "$name" "Tenant target $name")
  else
    body=$(python3 -c 'import json,os,sys
print(json.dumps({"name":sys.argv[1],"description":sys.argv[2],"options":{
  "kind":"Postgres","host":os.environ["LAB_PG_HOST"],"port":int(os.environ["LAB_PG_PORT"]),
  "username":os.environ["LAB_PG_USER"],"default_database_name":os.environ["LAB_PG_DB"],
  "tls":{"mode":"Disabled","verify":False},
  "auth":{"kind":"Password","password":os.environ["LAB_PG_PASSWORD"]}
}}))' "$name" "Tenant target $name")
  fi
  if [[ -z "$id" ]]; then
    id=$(wg_api "$CK_ADMIN" POST /@warpgate/admin/api/targets "$body" \
      | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])')
    log "created target $name"
  else
    wg_api "$CK_ADMIN" PUT "/@warpgate/admin/api/targets/${id}" "$body" >/dev/null
    log "updated target $name"
  fi
  echo "$id"
}

link_target_role() {
  local tid="$1" rid="$2"
  curl -sk -o /dev/null -w '' -b "$CK_ADMIN" -c "$CK_ADMIN" -H "Host: ${WG_HOST}" -H "Content-Type: application/json" \
    -d '{}' -X POST "${BASE}/@warpgate/admin/api/targets/${tid}/roles/${rid}" || true
}

unlink_target_role() {
  local tid="$1" rid="$2"
  curl -sk -o /dev/null -w '' -b "$CK_ADMIN" -c "$CK_ADMIN" -H "Host: ${WG_HOST}" \
    -X DELETE "${BASE}/@warpgate/admin/api/targets/${tid}/roles/${rid}" || true
}

ensure_wg_user() {
  local username="$1" email="$2" password="$3" role_id="$4"
  local users uid
  users=$(wg_api "$CK_ADMIN" GET /@warpgate/admin/api/users)
  uid=$(echo "$users" | python3 -c "import sys,json
for u in json.load(sys.stdin):
  if u.get('username')==sys.argv[1]:
    print(u['id']); break" "$username")
  if [[ -z "$uid" ]]; then
    uid=$(wg_api "$CK_ADMIN" POST /@warpgate/admin/api/users \
      "$(python3 -c 'import json,sys; print(json.dumps({"username":sys.argv[1],"description":sys.argv[2]}))' "$username" "tenant isolation test")" \
      | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])')
    log "created warpgate user $username"
  fi
  wg_api "$CK_ADMIN" POST "/@warpgate/admin/api/users/${uid}/credentials/sso" \
    "$(python3 -c 'import json,sys; print(json.dumps({"email":sys.argv[1],"provider":"archguard"}))' "$email")" >/dev/null 2>&1 || true
  wg_api "$CK_ADMIN" POST "/@warpgate/admin/api/users/${uid}/credentials/passwords" \
    "$(python3 -c 'import json,sys; print(json.dumps({"password":sys.argv[1]}))' "$password")" >/dev/null 2>&1 || true
  # strip other roles then assign only tenant role
  local roles
  roles=$(wg_api "$CK_ADMIN" GET "/@warpgate/admin/api/users/${uid}/roles")
  echo "$roles" | python3 -c "import sys,json
for r in json.load(sys.stdin):
  print(r['id'])" | while read -r rid; do
    curl -sk -o /dev/null -b "$CK_ADMIN" -H "Host: ${WG_HOST}" \
      -X DELETE "${BASE}/@warpgate/admin/api/users/${uid}/roles/${rid}" || true
  done
  curl -sk -o /dev/null -b "$CK_ADMIN" -c "$CK_ADMIN" -H "Host: ${WG_HOST}" -H "Content-Type: application/json" \
    -d '{}' -X POST "${BASE}/@warpgate/admin/api/users/${uid}/roles/${role_id}" || true
  echo "$uid"
}

# ---------------------------------------------------------------------------
step "0. Admin sessions"
IDM_TOKEN=$(rest_auth idm_admin "$IDM_PASS")
[[ -n "$IDM_TOKEN" ]] || fail "archguard admin auth"
wg_login admin "$WARPGATE_ADMIN_PASSWORD" "$CK_ADMIN"
log "admins OK"

step "1. archguard: tenant users A (rio) and B (marra)"
# tenant-a = testuser (rio only) — ensure memberships
# tenant-b = tenant-b-user (marra only)
api_k "$IDM_TOKEN" POST /v1/person \
  '{"attrs":{"name":["tenant-b-user"],"displayname":["Tenant B User"],"mail":["tenant-b-user@archgate.com.br"]}}' >/dev/null 2>&1 || true
api_k "$IDM_TOKEN" POST /v1/group/archguard_users/_attr/member \
  "[\"testuser@${DOMAIN}\",\"tenant-b-user@${DOMAIN}\"]" >/dev/null 2>&1 || true
# remove B from rio if present; ensure A only rio, B only marra
api_k "$IDM_TOKEN" DELETE "/v1/group/tenant_grupo_marra/_attr/member" \
  "[\"testuser@${DOMAIN}\"]" >/dev/null 2>&1 || true
api_k "$IDM_TOKEN" POST /v1/group/tenant_rio_quality/_attr/member \
  "[\"testuser@${DOMAIN}\"]" >/dev/null 2>&1 || true
api_k "$IDM_TOKEN" DELETE "/v1/group/tenant_rio_quality/_attr/member" \
  "[\"tenant-b-user@${DOMAIN}\"]" >/dev/null 2>&1 || true
api_k "$IDM_TOKEN" POST /v1/group/tenant_grupo_marra/_attr/member \
  "[\"tenant-b-user@${DOMAIN}\"]" >/dev/null 2>&1 || true

klogin
set_pw testuser "TenantA-RioQuality-2026"
set_pw tenant-b-user "TenantB-GrupoMarra-2026"
PASS_A="TenantA-RioQuality-2026"
PASS_B="TenantB-GrupoMarra-2026"
[[ -n "$(rest_auth testuser "$PASS_A")" ]] || fail "testuser auth"
[[ -n "$(rest_auth tenant-b-user "$PASS_B")" ]] || fail "tenant-b-user auth"
log "archguard users ready: testuser→rio, tenant-b-user→marra"

step "2. Warpgate roles per tenant"
ROLE_RIO=$(ensure_role "tenant-rio-quality" "Operators for tenant Rio Quality")
ROLE_MARRA=$(ensure_role "tenant-grupo-marra" "Operators for tenant Grupo Marra")
# keep archgate-operators for backward compat but unlink from isolation targets

step "3. Tenant-scoped targets"
T_RIO_SSH=$(ensure_target "rio-lab-ssh" Ssh)
T_RIO_PG=$(ensure_target "rio-lab-postgres" Postgres)
T_MARRA_SSH=$(ensure_target "marra-lab-ssh" Ssh)
T_MARRA_PG=$(ensure_target "marra-lab-postgres" Postgres)

# Find old shared role/targets
ROLES_JSON=$(wg_api "$CK_ADMIN" GET /@warpgate/admin/api/roles)
ROLE_SHARED=$(echo "$ROLES_JSON" | python3 -c "import sys,json
for r in json.load(sys.stdin):
  if r.get('name')=='archgate-operators':
    print(r['id']); break")
TARGETS_JSON=$(wg_api "$CK_ADMIN" GET /@warpgate/admin/api/targets)

# Unlink shared operators from tenant targets; link correct roles
for tid in "$T_RIO_SSH" "$T_RIO_PG"; do
  [[ -n "$ROLE_SHARED" ]] && unlink_target_role "$tid" "$ROLE_SHARED"
  link_target_role "$tid" "$ROLE_RIO"
done
for tid in "$T_MARRA_SSH" "$T_MARRA_PG"; do
  [[ -n "$ROLE_SHARED" ]] && unlink_target_role "$tid" "$ROLE_SHARED"
  link_target_role "$tid" "$ROLE_MARRA"
done
# Legacy shared lab-* targets: only admin/super, not tenant operators
for name in lab-ssh lab-postgres; do
  tid=$(echo "$TARGETS_JSON" | python3 -c "import sys,json
for t in json.load(sys.stdin):
  if t.get('name')==sys.argv[1]:
    print(t['id']); break" "$name")
  if [[ -n "$tid" && -n "$ROLE_SHARED" ]]; then
    unlink_target_role "$tid" "$ROLE_SHARED"
    unlink_target_role "$tid" "$ROLE_RIO"
    unlink_target_role "$tid" "$ROLE_MARRA"
    log "legacy $name unlinked from tenant roles (admin-only)"
  fi
done
log "targets scoped: rio→{rio-lab-*}, marra→{marra-lab-*}"

step "4. SSO role_mappings: archguard groups → Warpgate roles"
python3 - <<'PY'
from pathlib import Path
import re
p = Path("/var/lib/archgate/warpgate/warpgate.yaml")
text = p.read_text()
# Replace role_mappings block under archguard provider
new_map = """      role_mappings:
        archguard_super_admins: "warpgate:admin"
        tenant_rio_quality: "tenant-rio-quality"
        tenant_grupo_marra: "tenant-grupo-marra"
"""
if "role_mappings:" in text:
    text = re.sub(
        r"(\n\s*role_mappings:\n)(?:\s+[^\n]+\n)+",
        "\n" + new_map,
        text,
        count=1,
    )
else:
    text = text.replace("groups_claim: groups\n", "groups_claim: groups\n" + new_map)
p.write_text(text)
print("sso role_mappings patched")
# show snippet
for line in p.read_text().splitlines():
    if "role_mappings" in line or "tenant_" in line or "archguard_super" in line:
        print(" ", line)
PY
# restart warpgate to reload config
docker service update --force archgate-gw_warpgate >/dev/null
sleep 8
# re-login admin after restart
wg_login admin "$WARPGATE_ADMIN_PASSWORD" "$CK_ADMIN"
log "Warpgate reloaded with tenant SSO mappings"

step "5. Warpgate users bound to single tenant role"
UID_A=$(ensure_wg_user "testuser" "testuser@archgate.com.br" "$PASS_A" "$ROLE_RIO")
UID_B=$(ensure_wg_user "tenant-b-user" "tenant-b-user@archgate.com.br" "$PASS_B" "$ROLE_MARRA")
log "users: testuser=$UID_A (rio), tenant-b-user=$UID_B (marra)"

step "6. VALIDATE isolation"
CK_A=$(mktemp); CK_B=$(mktemp)
wg_login testuser "$PASS_A" "$CK_A"
wg_login tenant-b-user "$PASS_B" "$CK_B"

TARGETS_A=$(wg_api "$CK_A" GET /@warpgate/api/targets)
TARGETS_B=$(wg_api "$CK_B" GET /@warpgate/api/targets)

echo "$TARGETS_A" | python3 -c '
import sys,json
items=json.load(sys.stdin)
names=sorted(t.get("name") for t in items)
print("  tenant A (rio) sees:", names)
assert "rio-lab-ssh" in names and "rio-lab-postgres" in names, names
assert "marra-lab-ssh" not in names and "marra-lab-postgres" not in names, names
assert "lab-ssh" not in names and "lab-postgres" not in names, names
print("  [OK] A only sees Rio targets")
'
echo "$TARGETS_B" | python3 -c '
import sys,json
items=json.load(sys.stdin)
names=sorted(t.get("name") for t in items)
print("  tenant B (marra) sees:", names)
assert "marra-lab-ssh" in names and "marra-lab-postgres" in names, names
assert "rio-lab-ssh" not in names and "rio-lab-postgres" not in names, names
assert "lab-ssh" not in names and "lab-postgres" not in names, names
print("  [OK] B only sees Marra targets")
'

# Cross-check secrets still not leaked
echo "$TARGETS_A$TARGETS_B" | python3 -c '
import sys,os
s=sys.stdin.read()
for k in ["LAB_SSH_PASSWORD","LAB_PG_PASSWORD"]:
  v=os.environ.get(k,"")
  if v and v in s:
    raise SystemExit(f"LEAK {k}")
print("  [OK] no target secrets in either tenant list")
'

rm -f "$CK_A" "$CK_B"

echo ""
echo "=============================================="
echo " TENANT ISOLATION E2E (6.2) PASSED"
echo "=============================================="
echo "  Tenant A (testuser / rio): rio-lab-ssh, rio-lab-postgres"
echo "  Tenant B (tenant-b-user / marra): marra-lab-ssh, marra-lab-postgres"
echo "  Cross-tenant visibility: DENIED"
echo "  SSO role_mappings: tenant_rio_quality / tenant_grupo_marra"
echo "=============================================="
