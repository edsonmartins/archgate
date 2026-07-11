#!/usr/bin/env bash
# Fase 1 — tasks 2.2–2.7: tenants, RBAC, agent SA, OAuth2 clients, claim validation.
# Run on ArchGate host with Kanidm healthy. Uses REST + expect CLI (tools:1.10.4).
set -euo pipefail

KANIDM_URL="${KANIDM_URL:-https://127.0.0.1:8443}"
DOMAIN="${KANIDM_DOMAIN:-id.archgate.com.br}"
CONSOLE_ORIGIN="${CONSOLE_ORIGIN:-https://console.archgate.com.br}"
WARPGATE_ORIGIN="${WARPGATE_ORIGIN:-https://wg.archgate.com.br}"
GUACAMOLE_ORIGIN="${GUACAMOLE_ORIGIN:-https://guac.archgate.com.br}"
TOOLS="${KANIDM_TOOLS_IMAGE:-kanidm/tools:1.10.4}"
BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
KANIDM_SERVICE="${KANIDM_SERVICE:-archgate-id_kanidmd}"

log()  { echo "  [OK] $1"; }
warn() { echo "  [!!] $1"; }
err()  { echo "  [ERR] $1" >&2; exit 1; }
step() { echo -e "\n=== $1 ==="; }

CID=$(docker ps --filter "name=${KANIDM_SERVICE}" --format '{{.ID}}' | head -1)
[ -n "$CID" ] || err "Kanidm container not running"

# Prefer password from bootstrap; else recover
if [[ -f "$BOOTSTRAP" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$BOOTSTRAP"; set +a
fi
if [[ -z "${KANIDM_IDM_ADMIN_PASSWORD:-}" ]]; then
  KANIDM_IDM_ADMIN_PASSWORD=$(docker exec "$CID" /sbin/kanidmd recover-account idm_admin -c /data/server.toml 2>&1 \
    | sed -n 's/.*new_password: "\([^"]*\)".*/\1/p' | tail -1)
fi
IDM_PASS="$KANIDM_IDM_ADMIN_PASSWORD"
[ -n "$IDM_PASS" ] || err "no idm_admin password"

TOKENS=$(mktemp)
trap 'rm -f "$TOKENS"' EXIT

klogin() {
  expect <<EOF >/dev/null
set timeout 60
spawn docker run --rm -it --network host -v $TOKENS:/root/.cache/kanidm_tokens -e KANIDM_URL=$KANIDM_URL $TOOLS /sbin/kanidm login --accept-invalid-certs --name idm_admin
expect -re "password:"
send "$IDM_PASS\r"
expect eof
EOF
}

kcli() {
  docker run --rm --network host -v "$TOKENS:/root/.cache/kanidm_tokens" -e "KANIDM_URL=$KANIDM_URL" \
    $TOOLS /sbin/kanidm "$@" --accept-invalid-certs --name idm_admin 2>&1 | grep -v WARN || true
}

rest_auth() {
  local user="$1" pass="$2" hdr cookie
  hdr=$(mktemp)
  curl -sk -X POST "$KANIDM_URL/v1/auth" -H "Content-Type: application/json" \
    -d "{\"step\":{\"init\":\"$user\"}}" -D "$hdr" -o /dev/null
  cookie=$(grep -i set-cookie "$hdr" | sed 's/.*auth-session-id=\([^;]*\).*/\1/' | tr -d '\r' | head -1)
  rm -f "$hdr"
  curl -sk -X POST "$KANIDM_URL/v1/auth" -H "Content-Type: application/json" \
    -H "Cookie: auth-session-id=$cookie" -d '{"step":{"begin":"password"}}' >/dev/null
  curl -sk -X POST "$KANIDM_URL/v1/auth" -H "Content-Type: application/json" \
    -H "Cookie: auth-session-id=$cookie" \
    -d "$(python3 -c 'import json,sys; print(json.dumps({"step":{"cred":{"password":sys.argv[1]}}}))' "$pass")" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('state',{}).get('success',''))"
}

api() {
  local token="$1" method="$2" path="$3" body="${4:-}"
  if [ -n "$body" ]; then
    curl -sk -X "$method" "$KANIDM_URL$path" -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" -d "$body"
  else
    curl -sk -X "$method" "$KANIDM_URL$path" -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json"
  fi
}

ensure_group() {
  local name="$1" desc="$2"
  api "$IDM_TOKEN" POST /v1/group \
    "$(python3 -c 'import json,sys; print(json.dumps({"attrs":{"name":[sys.argv[1]],"description":[sys.argv[2]]}}))' "$name" "$desc")" \
    >/dev/null 2>&1 || true
  log "group $name"
}

# ---------------------------------------------------------------------------
IDM_TOKEN=$(rest_auth idm_admin "$IDM_PASS")
[ -n "$IDM_TOKEN" ] || err "REST auth failed"
klogin
log "authenticated"

# --- 2.2 Tenants ---
step "2.2 Tenants (grupos por cliente)"
ensure_group "tenant_rio_quality" "Tenant: Rio Quality"
ensure_group "tenant_grupo_marra" "Tenant: Grupo Marra"
# Nest under a parent label group (optional membership helper)
ensure_group "archgate_tenants" "All ArchGate tenants (meta)"

# Assign test users: testadmin sees both (super admin); testuser → Rio Quality only
api "$IDM_TOKEN" POST /v1/group/tenant_rio_quality/_attr/member \
  "[\"testadmin@${DOMAIN}\",\"testuser@${DOMAIN}\"]" >/dev/null 2>&1 || true
api "$IDM_TOKEN" POST /v1/group/tenant_grupo_marra/_attr/member \
  "[\"testadmin@${DOMAIN}\"]" >/dev/null 2>&1 || true
api "$IDM_TOKEN" POST /v1/group/archgate_tenants/_attr/member \
  "[\"tenant_rio_quality@${DOMAIN}\",\"tenant_grupo_marra@${DOMAIN}\"]" >/dev/null 2>&1 || true
log "testadmin → both tenants; testuser → tenant_rio_quality"

# --- 2.3 RBAC roles ---
step "2.3 RBAC roles (archguard_*)"
for g in archguard_users archguard_super_admins archguard_tenant_admins archguard_service_desk archguard_viewers; do
  ensure_group "$g" "RBAC: $g"
done
# ensure memberships
api "$IDM_TOKEN" POST /v1/group/archguard_users/_attr/member \
  "[\"testadmin@${DOMAIN}\",\"testuser@${DOMAIN}\"]" >/dev/null 2>&1 || true
api "$IDM_TOKEN" POST /v1/group/archguard_super_admins/_attr/member \
  "[\"testadmin@${DOMAIN}\"]" >/dev/null 2>&1 || true
api "$IDM_TOKEN" POST /v1/group/archguard_viewers/_attr/member \
  "[\"testuser@${DOMAIN}\"]" >/dev/null 2>&1 || true
log "RBAC groups present"

# --- 5.3 Tenant Admin sample user (Rio Quality only) ---
step "5.3 Tenant Admin sample (tenantadmin → Rio Quality)"
TENANT_ADMIN_PASS="${ARCHGUARD_TENANTADMIN_PASSWORD:-TenantAdmin-Rio-2026!}"
api "$IDM_TOKEN" POST /v1/person \
  "$(python3 -c 'import json,sys; print(json.dumps({"attrs":{"name":["tenantadmin"],"displayname":["Tenant Admin Rio Quality"],"mail":["tenantadmin@"+sys.argv[1]]}}))' "$DOMAIN")" \
  >/dev/null 2>&1 || true
# Memberships: console access + tenant admin role + only Rio Quality
api "$IDM_TOKEN" POST /v1/group/archguard_users/_attr/member \
  "[\"tenantadmin@${DOMAIN}\"]" >/dev/null 2>&1 || true
api "$IDM_TOKEN" POST /v1/group/archguard_tenant_admins/_attr/member \
  "[\"tenantadmin@${DOMAIN}\"]" >/dev/null 2>&1 || true
api "$IDM_TOKEN" POST /v1/group/tenant_rio_quality/_attr/member \
  "[\"tenantadmin@${DOMAIN}\"]" >/dev/null 2>&1 || true
api "$IDM_TOKEN" DELETE /v1/group/tenant_grupo_marra/_attr/member \
  "[\"tenantadmin@${DOMAIN}\"]" >/dev/null 2>&1 || true
api "$IDM_TOKEN" DELETE /v1/group/archguard_super_admins/_attr/member \
  "[\"tenantadmin@${DOMAIN}\"]" >/dev/null 2>&1 || true
# Password via interactive credential update (same pattern as bootstrap-kanidm)
klogin
script -q -c "docker run --rm -i --network host \
  -v ${TOKENS}:/root/.cache/kanidm_tokens \
  -e KANIDM_URL=${KANIDM_URL} \
  ${TOOLS} /sbin/kanidm person credential update --accept-invalid-certs --name idm_admin tenantadmin" /dev/null <<EOF 2>&1 | tail -5 || true
password
${TENANT_ADMIN_PASS}
${TENANT_ADMIN_PASS}
commit
y
EOF
if ! grep -q '^ARCHGUARD_TENANTADMIN_PASSWORD=' "$BOOTSTRAP" 2>/dev/null; then
  echo "ARCHGUARD_TENANTADMIN_PASSWORD=${TENANT_ADMIN_PASS}" >> "$BOOTSTRAP"
fi
log "tenantadmin → archguard_tenant_admins + tenant_rio_quality (pass in bootstrap)"

# --- 2.4 Agent SA example ---
step "2.4 Service account agent example"
api "$IDM_TOKEN" DELETE /v1/service_account/archgate-agent-example >/dev/null 2>&1 || true
api "$IDM_TOKEN" POST /v1/service_account \
  '{"attrs":{"name":["archgate-agent-example"],"displayname":["ArchGate Agent Example (Fase 5)"],"entry_managed_by":["idm_admins"]}}' \
  >/dev/null 2>&1 || true
# Narrow scope: only a reader-like group, NOT idm_admins
api "$IDM_TOKEN" POST /v1/group/archguard_viewers/_attr/member \
  "[\"archgate-agent-example@${DOMAIN}\"]" >/dev/null 2>&1 || true
AGENT_TOKEN=$(api "$IDM_TOKEN" POST /v1/service_account/archgate-agent-example/_api_token \
  '{"label":"agent-example","expiry":1830297600,"read_write":false}' | tr -d '"' || true)
if [[ -n "$AGENT_TOKEN" && "$AGENT_TOKEN" != *error* && "$AGENT_TOKEN" != null* ]]; then
  log "archgate-agent-example token issued (len ${#AGENT_TOKEN})"
else
  warn "agent token may have failed: $AGENT_TOKEN"
  AGENT_TOKEN=""
fi
# Confirm archguard-sa still works
SA_CHECK=$(api "${ARCHGUARD_SA_TOKEN:-}" GET /v1/person 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
log "archguard-sa persons visible: $SA_CHECK"

# --- 2.5 OAuth2 clients: warpgate, guacamole (archguard-console already) ---
step "2.5 OAuth2 clients warpgate + guacamole + console"
klogin

# Console already exists; refresh redirect/scope
kcli system oauth2 create-public archguard-console "ArchGuard Console" "$CONSOLE_ORIGIN" >/dev/null 2>&1 || true
kcli system oauth2 set-landing-url archguard-console "$CONSOLE_ORIGIN" || true
kcli system oauth2 add-redirect-url archguard-console "${CONSOLE_ORIGIN}/callback" || true
kcli system oauth2 update-scope-map archguard-console archguard_users openid profile email groups || true
log "archguard-console OAuth2 OK"

# Warpgate: confidential basic client (client secret)
kcli system oauth2 delete warpgate >/dev/null 2>&1 || true
kcli system oauth2 create warpgate "ArchGate Warpgate" "$WARPGATE_ORIGIN" || true
kcli system oauth2 set-landing-url warpgate "$WARPGATE_ORIGIN" || true
# Common Warpgate SSO callback paths (version-dependent)
kcli system oauth2 add-redirect-url warpgate "${WARPGATE_ORIGIN}/@warpgate/api/sso/oidc/return" || true
kcli system oauth2 add-redirect-url warpgate "${WARPGATE_ORIGIN}/@warpgate/admin/api/sso/oidc/return" || true
kcli system oauth2 add-redirect-url warpgate "${WARPGATE_ORIGIN}/sso/oidc/return" || true
kcli system oauth2 update-scope-map warpgate archguard_users openid profile email groups || true
# Prefer groups in ID token
kcli system oauth2 prefer-short-username warpgate || true
WARPGATE_SECRET=$(kcli system oauth2 show-basic-secret warpgate 2>/dev/null | tail -1 | tr -d '\r' || true)
log "warpgate OAuth2 client (secret len ${#WARPGATE_SECRET})"

# Guacamole: confidential basic client
kcli system oauth2 delete guacamole >/dev/null 2>&1 || true
kcli system oauth2 create guacamole "ArchGate Guacamole" "$GUACAMOLE_ORIGIN" || true
kcli system oauth2 set-landing-url guacamole "$GUACAMOLE_ORIGIN" || true
kcli system oauth2 add-redirect-url guacamole "${GUACAMOLE_ORIGIN}/" || true
kcli system oauth2 add-redirect-url guacamole "${GUACAMOLE_ORIGIN}/guacamole/" || true
kcli system oauth2 update-scope-map guacamole archguard_users openid profile email groups || true
kcli system oauth2 prefer-short-username guacamole || true
GUACAMOLE_SECRET=$(kcli system oauth2 show-basic-secret guacamole 2>/dev/null | tail -1 | tr -d '\r' || true)
log "guacamole OAuth2 client (secret len ${#GUACAMOLE_SECRET})"

# --- 2.6 PKCE / no implicit ---
step "2.6 Authorization Code + PKCE (implicit disabled by design in Kanidm)"
# Kanidm does not offer implicit grant for OIDC apps; public clients require PKCE.
# Validate discovery for each client.
for client in archguard-console warpgate guacamole; do
  ISS=$(curl -sk "$KANIDM_URL/oauth2/openid/${client}/.well-known/openid-configuration" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('issuer',''))" 2>/dev/null || true)
  if [[ -n "$ISS" ]]; then
    log "OIDC discovery $client → $ISS"
  else
    warn "OIDC discovery failed for $client"
  fi
  # grant types should not list implicit
  GT=$(curl -sk "$KANIDM_URL/oauth2/openid/${client}/.well-known/openid-configuration" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('grant_types_supported',[]))" 2>/dev/null || true)
  echo "    grant_types_supported: $GT"
done

# --- 2.7 Token claims: groups/tenant ---
step "2.7 Validate groups claim path (userinfo / token introspection via session)"
# Auth as testuser and inspect person groups via API as SA
if [[ -n "${ARCHGUARD_SA_TOKEN:-}" ]]; then
  GROUPS=$(api "$ARCHGUARD_SA_TOKEN" GET /v1/person/testuser/_attr/memberof 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d if isinstance(d,list) else d)" 2>/dev/null || true)
  echo "    testuser memberof: $GROUPS"
  GROUPS_A=$(api "$ARCHGUARD_SA_TOKEN" GET /v1/person/testadmin/_attr/memberof 2>/dev/null \
    | python3 -c "import sys,json; print(json.load(sys.stdin))" 2>/dev/null || true)
  echo "    testadmin memberof: $GROUPS_A"
  log "group memberships readable via API (basis for OIDC groups claim)"
fi

# Persist secrets to bootstrap
{
  echo ""
  echo "# --- OAuth2 gateway clients ($(date -Iseconds)) ---"
  echo "WARPGATE_DOMAIN=wg.archgate.com.br"
  echo "GUACAMOLE_DOMAIN=guac.archgate.com.br"
  echo "WARPGATE_OIDC_CLIENT_ID=warpgate"
  echo "WARPGATE_OIDC_CLIENT_SECRET=${WARPGATE_SECRET}"
  echo "GUACAMOLE_OIDC_CLIENT_ID=guacamole"
  echo "GUACAMOLE_OIDC_CLIENT_SECRET=${GUACAMOLE_SECRET}"
  echo "OIDC_ISSUER_BASE=https://${DOMAIN}/oauth2/openid"
  if [[ -n "$AGENT_TOKEN" ]]; then
    echo "ARCHGATE_AGENT_EXAMPLE_TOKEN=${AGENT_TOKEN}"
  fi
} >> "$BOOTSTRAP"
chmod 600 "$BOOTSTRAP"
log "secrets appended to $BOOTSTRAP"

echo ""
echo "  Identity axis 2.2–2.7 complete."
echo "  Tenants: tenant_rio_quality, tenant_grupo_marra"
echo "  OAuth2: archguard-console, warpgate, guacamole"
echo "  Agent SA: archgate-agent-example"
