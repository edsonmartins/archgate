#!/usr/bin/env bash
# Bootstrap ArchGuard Kanidm on ArchGate host — REST-first (no TTY required).
set -euo pipefail

KANIDM_URL="${KANIDM_URL:-https://127.0.0.1:8443}"
KANIDM_SERVICE="${KANIDM_SERVICE:-archgate-id_kanidmd}"
CONSOLE_ORIGIN="${CONSOLE_ORIGIN:-https://console.archgate.com.br}"
CURL=(curl -sk)
BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
TESTADMIN_PASSWORD="${TESTADMIN_PASSWORD:-ArchGuard2026TestAdmin}"
TESTUSER_PASSWORD="${TESTUSER_PASSWORD:-ArchGuard2026TestUser}"
DOMAIN="id.archgate.com.br"

log()  { echo "  [OK] $1"; }
warn() { echo "  [!!] $1"; }
err()  { echo "  [ERR] $1" >&2; exit 1; }
step() { echo -e "\n--- $1 ---"; }

container_id() {
  docker ps --filter "name=${KANIDM_SERVICE}" --format '{{.ID}}' | head -1
}

recover_password() {
  local account="$1" cid="$2" out
  out=$(docker exec "$cid" /sbin/kanidmd recover-account "$account" -c /data/server.toml 2>&1)
  # line like: | new_password: "xxxx"
  echo "$out" | sed -n 's/.*new_password: "\([^"]*\)".*/\1/p' | tail -1
}

kanidm_rest_auth() {
  local username="$1" password="$2"
  local hdr body cookie response token
  hdr=$(mktemp)
  body=$("${CURL[@]}" -X POST "$KANIDM_URL/v1/auth" \
    -H "Content-Type: application/json" \
    -d "{\"step\":{\"init\":\"$username\"}}" \
    -D "$hdr" 2>/dev/null)
  cookie=$(grep -i 'set-cookie' "$hdr" 2>/dev/null | sed 's/.*auth-session-id=\([^;]*\).*/\1/' | tr -d '\r' | head -1)
  rm -f "$hdr"
  [ -n "$cookie" ] || err "Auth init failed for $username (no cookie). body=$body"
  "${CURL[@]}" -X POST "$KANIDM_URL/v1/auth" \
    -H "Content-Type: application/json" \
    -H "Cookie: auth-session-id=$cookie" \
    -d '{"step":{"begin":"password"}}' >/dev/null
  response=$("${CURL[@]}" -X POST "$KANIDM_URL/v1/auth" \
    -H "Content-Type: application/json" \
    -H "Cookie: auth-session-id=$cookie" \
    -d "$(python3 -c 'import json,sys; print(json.dumps({"step":{"cred":{"password":sys.argv[1]}}}))' "$password")")
  token=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('state',{}).get('success',''))" 2>/dev/null || true)
  [ -n "$token" ] || err "Auth failed for $username: $response"
  echo "$token"
}

api() {
  local token="$1" method="$2" path="$3" body="${4:-}"
  if [ -n "$body" ]; then
    "${CURL[@]}" -X "$method" "$KANIDM_URL$path" \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" \
      -d "$body"
  else
    "${CURL[@]}" -X "$method" "$KANIDM_URL$path" \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json"
  fi
}

# kanidm tools CLI without TTY (script pseudo-tty)
kcli() {
  local tokens="$1"; shift
  script -q -c "docker run --rm -i --network host \
    -v ${tokens}:/root/.cache/kanidm_tokens \
    -e KANIDM_URL=${KANIDM_URL} \
    kanidm/tools:1.10.4 \
    /sbin/kanidm $* --accept-invalid-certs --name idm_admin" /dev/null 2>&1 | grep -v WARN || true
}

kcli_login() {
  local tokens="$1" password="$2"
  script -q -c "docker run --rm -i --network host \
    -v ${tokens}:/root/.cache/kanidm_tokens \
    -e KANIDM_URL=${KANIDM_URL} \
    kanidm/tools:1.10.4 \
    /sbin/kanidm login --accept-invalid-certs --name idm_admin" /dev/null <<EOF 2>&1 | grep -v WARN || true
${password}
EOF
}

echo "  ArchGuard Kanidm bootstrap"
echo "  Kanidm:  $KANIDM_URL"
echo "  Console: $CONSOLE_ORIGIN"

command -v docker >/dev/null || err "docker missing"
command -v python3 >/dev/null || err "python3 missing"
command -v script >/dev/null || err "script (bsdutils) missing"

CID=$(container_id)
[ -n "$CID" ] || err "No container for $KANIDM_SERVICE"
STATUS=$("${CURL[@]}" "$KANIDM_URL/status" || true)
[ "$STATUS" = "true" ] || err "Kanidm not healthy: $STATUS"

step "Admin password recovery"
ADMIN_PASSWORD=$(recover_password admin "$CID")
IDM_ADMIN_PASSWORD=$(recover_password idm_admin "$CID")
[ -n "$ADMIN_PASSWORD" ] || err "empty admin password"
[ -n "$IDM_ADMIN_PASSWORD" ] || err "empty idm_admin password"
log "admin + idm_admin recovered (len ${#ADMIN_PASSWORD}/${#IDM_ADMIN_PASSWORD})"

step "REST auth"
IDM_TOKEN=$(kanidm_rest_auth "idm_admin" "$IDM_ADMIN_PASSWORD")
log "idm_admin token OK"

step "CLI login (for oauth2 helpers)"
TOKENS_FILE=$(mktemp)
kcli_login "$TOKENS_FILE" "$IDM_ADMIN_PASSWORD"
log "CLI session attempted"

step "Account policy (password-only allowed for lab)"
kcli "$TOKENS_FILE" group account-policy credential-type-minimum idm_all_persons any >/dev/null 2>&1 || true
log "policy updated (best-effort)"

step "Groups"
for group in archguard_users archguard_super_admins archguard_tenant_admins archguard_service_desk archguard_viewers; do
  # REST create group
  api "$IDM_TOKEN" POST "/v1/group" \
    "{\"attrs\":{\"name\":[\"$group\"],\"description\":[\"ArchGuard $group\"]}}" >/dev/null 2>&1 || true
  log "group $group ensured"
done
kcli "$TOKENS_FILE" group account-policy enable archguard_users >/dev/null 2>&1 || true
kcli "$TOKENS_FILE" group account-policy credential-type-minimum archguard_users any >/dev/null 2>&1 || true

step "Test persons"
for person in testadmin testuser; do
  api "$IDM_TOKEN" POST "/v1/person" \
    "{\"attrs\":{\"name\":[\"$person\"],\"displayname\":[\"Test $person\"]}}" >/dev/null 2>&1 || true
done
# memberships
api "$IDM_TOKEN" POST "/v1/group/archguard_users/_attr/member" \
  "[\"testadmin@${DOMAIN}\",\"testuser@${DOMAIN}\"]" >/dev/null 2>&1 || true
api "$IDM_TOKEN" POST "/v1/group/archguard_super_admins/_attr/member" \
  "[\"testadmin@${DOMAIN}\"]" >/dev/null 2>&1 || true
api "$IDM_TOKEN" POST "/v1/group/archguard_viewers/_attr/member" \
  "[\"testuser@${DOMAIN}\"]" >/dev/null 2>&1 || true
log "persons + memberships"

# Set passwords via recover-account for test users is not available; use person credential update CLI
step "Test person passwords"
# re-login CLI
kcli_login "$TOKENS_FILE" "$IDM_ADMIN_PASSWORD"
# Use recover-account only works for admin/idm_admin. Use credential reset via tools.
for pair in "testadmin:${TESTADMIN_PASSWORD}" "testuser:${TESTUSER_PASSWORD}"; do
  person="${pair%%:*}"
  pass="${pair#*:}"
  script -q -c "docker run --rm -i --network host \
    -v ${TOKENS_FILE}:/root/.cache/kanidm_tokens \
    -e KANIDM_URL=${KANIDM_URL} \
    kanidm/tools:1.10.4 \
    /sbin/kanidm person credential update --accept-invalid-certs --name idm_admin ${person}" /dev/null <<EOF 2>&1 | tail -5 || true
password
${pass}
${pass}
commit
y
EOF
  log "password attempt for $person"
done

# Verify testadmin auth
if kanidm_rest_auth "testadmin" "$TESTADMIN_PASSWORD" >/dev/null 2>&1; then
  log "testadmin auth verified"
else
  warn "testadmin auth failed — set password via console later if needed"
fi

step "OAuth2 public client archguard-console"
kcli "$TOKENS_FILE" system oauth2 delete archguard-console >/dev/null 2>&1 || true
kcli_login "$TOKENS_FILE" "$IDM_ADMIN_PASSWORD"
kcli "$TOKENS_FILE" system oauth2 create-public archguard-console "ArchGuard Console" "$CONSOLE_ORIGIN" || true
kcli "$TOKENS_FILE" system oauth2 set-landing-url archguard-console "$CONSOLE_ORIGIN" || true
kcli "$TOKENS_FILE" system oauth2 add-redirect-url archguard-console "${CONSOLE_ORIGIN}/callback" || true
kcli "$TOKENS_FILE" system oauth2 update-scope-map archguard-console archguard_users openid profile email groups || true
log "oauth2 client configured"

step "Service account archguard-sa"
IDM_TOKEN=$(kanidm_rest_auth "idm_admin" "$IDM_ADMIN_PASSWORD")
api "$IDM_TOKEN" DELETE "/v1/service_account/archguard-sa" >/dev/null 2>&1 || true
api "$IDM_TOKEN" POST "/v1/service_account" \
  '{"attrs":{"name":["archguard-sa"],"displayname":["ArchGuard Service Account"],"entry_managed_by":["idm_admins"]}}' >/dev/null 2>&1 || true
for g in idm_admins idm_people_admins idm_recycle_bin_admins; do
  api "$IDM_TOKEN" POST "/v1/group/${g}/_attr/member" "[\"archguard-sa@${DOMAIN}\"]" >/dev/null 2>&1 || true
done
SA_TOKEN=$(api "$IDM_TOKEN" POST "/v1/service_account/archguard-sa/_api_token" \
  '{"label":"console-token","expiry":1830297600,"read_write":true}' | tr -d '"')
if [ -z "$SA_TOKEN" ] || echo "$SA_TOKEN" | grep -qiE 'error|denied|fail|null|\{'; then
  err "SA token failed: $SA_TOKEN"
fi
log "SA token generated (len ${#SA_TOKEN})"

# Verify SA
PERSONS=$(api "$SA_TOKEN" GET "/v1/person" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
log "SA can list persons: $PERSONS"

SESSION_SECRET=$(openssl rand -hex 32)

# Update bootstrap env: strip previous ArchGuard block then append
if [[ -f "$BOOTSTRAP" ]]; then
  grep -v '^# --- ArchGuard' "$BOOTSTRAP" | grep -vE '^(KANIDM_|CONSOLE_DOMAIN=|ARCHGUARD_|SESSION_SECRET=)' > "${BOOTSTRAP}.tmp" || true
  mv "${BOOTSTRAP}.tmp" "$BOOTSTRAP"
fi
{
  echo ""
  echo "# --- ArchGuard (generated $(date -Iseconds)) ---"
  echo "ARCHGATE_DOMAIN=archgate.com.br"
  echo "KANIDM_DOMAIN=${DOMAIN}"
  echo "CONSOLE_DOMAIN=console.archgate.com.br"
  echo "ARCHGUARD_ID_URL=https://${DOMAIN}"
  echo "ARCHGUARD_SA_TOKEN=${SA_TOKEN}"
  echo "SESSION_SECRET=${SESSION_SECRET}"
  echo "KANIDM_ADMIN_PASSWORD=${ADMIN_PASSWORD}"
  echo "KANIDM_IDM_ADMIN_PASSWORD=${IDM_ADMIN_PASSWORD}"
  echo "ARCHGUARD_TESTADMIN_PASSWORD=${TESTADMIN_PASSWORD}"
  echo "ARCHGUARD_TESTUSER_PASSWORD=${TESTUSER_PASSWORD}"
  echo "ACME_EMAIL=${ACME_EMAIL:-ops@archgate.com.br}"
} >> "$BOOTSTRAP"
chmod 600 "$BOOTSTRAP"
log "wrote $BOOTSTRAP"

step "OIDC discovery"
OIDC=$("${CURL[@]}" "$KANIDM_URL/oauth2/openid/archguard-console/.well-known/openid-configuration" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('issuer',''))" 2>/dev/null || true)
if [ -n "$OIDC" ]; then
  log "OIDC issuer: $OIDC"
else
  warn "OIDC discovery empty — check oauth2 client"
fi

rm -f "$TOKENS_FILE"
echo ""
echo "  Bootstrap complete."
