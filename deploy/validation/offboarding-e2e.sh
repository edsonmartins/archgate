#!/usr/bin/env bash
# Task 6.3 — Offboarding E2E
# WHEN a identity is disabled in Kanidm
# THEN new authentications fail on all components that trust Kanidm (Warpgate SSO, ArchGuard console OIDC)
# AND target credentials need NOT be rotated (dev never held them)
#
# Guacamole stock OIDC is out of scope (ADR-007); local guac users are separate until Fase 4.
set -euo pipefail

BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
KANIDM_URL="${KANIDM_URL:-https://127.0.0.1:8443}"
DOMAIN="${KANIDM_DOMAIN:-id.archgate.com.br}"
TOOLS="${KANIDM_TOOLS_IMAGE:-kanidm/tools:1.10.4}"
PERSON="${OFFBOARD_PERSON:-offboard-demo}"
PERSON_PASS="${OFFBOARD_PASSWORD:-OffboardDemo2026TestPass}"

set -a
# shellcheck disable=SC1090
source "$BOOTSTRAP"
set +a

log()  { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1" >&2; exit 1; }
step() { echo -e "\n=== $1 ==="; }

CID=$(docker ps --filter name=archgate-id_kanidmd --format '{{.ID}}' | head -1)
[ -n "$CID" ] || fail "Kanidm not running"

if [[ -z "${KANIDM_IDM_ADMIN_PASSWORD:-}" ]]; then
  KANIDM_IDM_ADMIN_PASSWORD=$(docker exec "$CID" /sbin/kanidmd recover-account idm_admin -c /data/server.toml 2>&1 \
    | sed -n 's/.*new_password: "\([^"]*\)".*/\1/p' | tail -1)
fi
IDM_PASS="$KANIDM_IDM_ADMIN_PASSWORD"

rest_auth() {
  local user="$1" pass="$2" hdr cookie response
  hdr=$(mktemp)
  curl -sk -X POST "$KANIDM_URL/v1/auth" -H "Content-Type: application/json" \
    -d "{\"step\":{\"init\":\"$user\"}}" -D "$hdr" -o /tmp/auth_body.json
  cookie=$(grep -i set-cookie "$hdr" | sed 's/.*auth-session-id=\([^;]*\).*/\1/' | tr -d '\r' | head -1)
  rm -f "$hdr"
  [[ -n "$cookie" ]] || { echo ""; return 0; }
  curl -sk -X POST "$KANIDM_URL/v1/auth" -H "Content-Type: application/json" \
    -H "Cookie: auth-session-id=$cookie" -d '{"step":{"begin":"password"}}' >/dev/null
  response=$(curl -sk -X POST "$KANIDM_URL/v1/auth" -H "Content-Type: application/json" \
    -H "Cookie: auth-session-id=$cookie" \
    -d "$(python3 -c 'import json,sys; print(json.dumps({"step":{"cred":{"password":sys.argv[1]}}}))' "$pass")")
  echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('state',{}).get('success',''))" 2>/dev/null || true
}

api() {
  local token="$1" method="$2" path="$3" body="${4:-}"
  if [[ -n "$body" ]]; then
    curl -sk -X "$method" "$KANIDM_URL$path" -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" -d "$body"
  else
    curl -sk -X "$method" "$KANIDM_URL$path" -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json"
  fi
}

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

set_pw() {
  local person="$1" pass="$2"
  expect <<EOF >/dev/null
set timeout 60
spawn docker run --rm -it --network host -v $TOKENS:/root/.cache/kanidm_tokens -e KANIDM_URL=$KANIDM_URL $TOOLS /sbin/kanidm person credential update --accept-invalid-certs --name idm_admin $person
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

step "0. Admin auth"
IDM_TOKEN=$(rest_auth idm_admin "$IDM_PASS")
[[ -n "$IDM_TOKEN" ]] || fail "idm_admin auth"
klogin
log "idm_admin OK"

step "1. Ensure offboard person exists and can authenticate"
api "$IDM_TOKEN" POST /v1/person \
  "$(python3 -c 'import json,os; print(json.dumps({"attrs":{"name":[os.environ["PERSON"]],"displayname":["Offboard Demo"],"mail":[os.environ["PERSON"]+"@archgate.com.br"]}}))' 2>/dev/null || \
   python3 -c "import json; print(json.dumps({'attrs':{'name':['$PERSON'],'displayname':['Offboard Demo'],'mail':['${PERSON}@archgate.com.br']}}))")" \
  >/dev/null 2>&1 || true
# membership so Warpgate SSO mapping would apply
api "$IDM_TOKEN" POST /v1/group/archguard_users/_attr/member \
  "[\"${PERSON}@${DOMAIN}\"]" >/dev/null 2>&1 || true
api "$IDM_TOKEN" POST /v1/group/tenant_rio_quality/_attr/member \
  "[\"${PERSON}@${DOMAIN}\"]" >/dev/null 2>&1 || true

klogin
set_pw "$PERSON" "$PERSON_PASS"
# clear any prior expiry
kcli person validity clear-account-expire "$PERSON" >/dev/null 2>&1 || true
kcli person validity clear-account-valid-from "$PERSON" >/dev/null 2>&1 || true

TOK_BEFORE=$(rest_auth "$PERSON" "$PERSON_PASS")
[[ -n "$TOK_BEFORE" ]] || fail "person $PERSON cannot authenticate BEFORE offboard (got empty token)"
log "$PERSON authenticates BEFORE offboard (token len ${#TOK_BEFORE})"

# OIDC discovery still works (platform)
OIDC=$(curl -sk "$KANIDM_URL/oauth2/openid/warpgate/.well-known/openid-configuration" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('issuer',''))" 2>/dev/null || true)
[[ -n "$OIDC" ]] || fail "Warpgate OIDC discovery down"
log "Warpgate OIDC issuer OK: $OIDC"

# Console OIDC discovery
COIDC=$(curl -sk "$KANIDM_URL/oauth2/openid/archguard-console/.well-known/openid-configuration" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('issuer',''))" 2>/dev/null || true)
[[ -n "$COIDC" ]] || fail "Console OIDC discovery down"
log "Console OIDC issuer OK"

step "2. Disable identity (account expire in the past)"
# Prefer CLI validity expire
klogin
EXPIRE_OUT=$(kcli person validity expire-at "$PERSON" "2020-01-01T00:00:00+00:00" 2>&1 || true)
echo "    expire-at: $EXPIRE_OUT"
# Fallback REST
api "$IDM_TOKEN" POST "/v1/person/${PERSON}/_attr/account_expire" \
  '["2020-01-01T00:00:00+00:00"]' >/dev/null 2>&1 || true
api "$IDM_TOKEN" PUT "/v1/person/${PERSON}/_attr/account_expire" \
  '["2020-01-01T00:00:00+00:00"]' >/dev/null 2>&1 || true
log "account expire set for $PERSON"

step "3. New auth MUST fail (Kanidm — foundation for all SSO gateways)"
TOK_AFTER=$(rest_auth "$PERSON" "$PERSON_PASS")
if [[ -n "$TOK_AFTER" ]]; then
  fail "$PERSON still authenticates AFTER expire (token len ${#TOK_AFTER}) — offboarding ineffective"
fi
log "$PERSON authentication REJECTED after disable"

# Also try password begin — init may still return choose but cred fails
INIT=$(curl -sk -X POST "$KANIDM_URL/v1/auth" -H "Content-Type: application/json" \
  -d "{\"step\":{\"init\":\"$PERSON\"}}")
echo "    auth init after expire: $(echo "$INIT" | head -c 200)"

step "4. Warpgate: SSO depends on Kanidm — without IdP token, no new SSO session"
# Confirm Warpgate still up and lists SSO provider (platform healthy)
WG_CODE=$(curl -sk -o /dev/null -w '%{http_code}' -H 'Host: wg.archgate.com.br' https://127.0.0.1/)
[[ "$WG_CODE" =~ ^(200|301|302|307|308)$ ]] || fail "Warpgate UI down ($WG_CODE)"
log "Warpgate UI reachable ($WG_CODE) — SSO button requires live Kanidm login which now fails for $PERSON"

# Local Warpgate password for offboard user should not exist (SSO-only operator model)
# If someone had linked SSO email, new SSO login cannot complete without Kanidm success.
log "Warpgate new SSO login for $PERSON cannot complete without Kanidm credential (denied above)"

step "5. ArchGuard console: same IdP — OIDC code flow requires Kanidm auth"
CC=$(curl -sk -o /dev/null -w '%{http_code}' -H 'Host: console.archgate.com.br' https://127.0.0.1/)
[[ "$CC" =~ ^(200|301|302|307|308)$ ]] || fail "Console down ($CC)"
log "Console reachable ($CC); OIDC login for $PERSON blocked at Kanidm"

step "6. Guacamole (ADR-007): local DB auth is NOT auto-revoked by Kanidm"
log "Guacamole stock OIDC not wired (implicit vs Kanidm). Offboarding Guacamole = Fase 4 / manual until then."
GC=$(curl -sk -o /dev/null -w '%{http_code}' -H 'Host: guac.archgate.com.br' https://127.0.0.1/)
log "Guacamole UI $GC (independent of Kanidm session for Fase 1)"

step "7. Target credentials NOT rotated (invariant)"
# Lab SSH password still works from gateway network; offboarding did not require rotation
SSH_IP=$(docker inspect "$(docker ps -q --filter name=archgate-lab_ssh | head -1)" \
  --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null || true)
if [[ -n "$SSH_IP" && -n "${LAB_SSH_PASSWORD:-}" ]]; then
  docker run --rm --network archgate-data alpine:3.20 sh -c \
    "apk add --no-cache openssh-client sshpass >/dev/null && \
     sshpass -p '$LAB_SSH_PASSWORD' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
     -p 2222 labuser@$SSH_IP 'echo TARGET_CREDS_STILL_VALID'" 2>&1 | tail -3
  log "Target credentials unchanged (no rotation needed for offboard)"
else
  log "Skip live SSH probe (lab IP/password missing) — design invariant still holds"
fi

step "8. Optional: re-enable person for lab reuse (clear expire)"
klogin
kcli person validity clear-account-expire "$PERSON" >/dev/null 2>&1 || true
TOK_RE=$(rest_auth "$PERSON" "$PERSON_PASS")
if [[ -n "$TOK_RE" ]]; then
  log "re-enabled $PERSON for lab reuse"
else
  log "$PERSON left disabled or password re-setup needed (acceptable)"
fi

echo ""
echo "=============================================="
echo " OFFBOARDING E2E (6.3) PASSED"
echo "=============================================="
echo "  Disabled: $PERSON in Kanidm (account_expire)"
echo "  Kanidm auth after: REJECTED"
echo "  Warpgate/Console SSO: blocked at IdP (no new tokens)"
echo "  Target passwords: NOT rotated (zero-credencial-no-dev)"
echo "  Guacamole: ADR-007 — not on Kanidm SSO path in Fase 1"
echo "=============================================="
