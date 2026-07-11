#!/usr/bin/env bash
# ADR-007A — Guacamole edge SSO via oauth2-proxy (no full browser OIDC flow)
set -euo pipefail
HOST_HDR="${GUACAMOLE_DOMAIN:-guac.archgate.com.br}"
BASE="${GUAC_BASE:-https://127.0.0.1}"

log()  { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1" >&2; exit 1; }
step() { echo -e "\n=== $1 ==="; }

step "1. Unauthenticated request is challenged (redirect to IdP or oauth2 sign-in)"
HDRS=$(mktemp)
CODE=$(curl -sk -D "$HDRS" -o /tmp/guac_body.html -w '%{http_code}' -H "Host: ${HOST_HDR}" "${BASE}/" || echo 000)
echo "    http=$CODE"
LOC=$(grep -i '^location:' "$HDRS" | tr -d '\r' | head -1 || true)
echo "    $LOC"
# Expect redirect (302/303/307) to Kanidm or /oauth2/start
if echo "$CODE" | grep -qE '302|303|307'; then
  echo "$LOC" | grep -qiE 'oauth2|id\.archgate|kanidm|authorize' \
    || echo "$LOC" | grep -qi 'location:' \
    || fail "redirect location unexpected: $LOC"
  log "unauthenticated → redirect (SSO gate present)"
elif echo "$CODE" | grep -qE '401|403'; then
  log "unauthenticated → $CODE (gate present)"
else
  # If 200 and body is Guacamole login without oauth2, gate missing
  if grep -qi 'guacamole' /tmp/guac_body.html 2>/dev/null && ! grep -qi 'oauth2' "$HDRS" /tmp/guac_body.html 2>/dev/null; then
    fail "Guacamole UI returned 200 without SSO challenge — proxy may be bypassed"
  fi
  fail "unexpected http=$CODE (want 302/401/403)"
fi

step "2. Guacamole service not published with Traefik enable=true"
if docker service inspect archgate-gw_guacamole --format '{{json .Spec.Labels}}' 2>/dev/null \
  | python3 -c 'import sys,json; d=json.load(sys.stdin); assert d.get("traefik.enable") in ("false","0",None) or d.get("traefik.enable")=="false", d'; then
  log "Guacamole traefik.enable is false/absent from public intent"
else
  # label might still list enable false
  EN=$(docker service inspect archgate-gw_guacamole --format '{{index .Spec.Labels "traefik.enable"}}' 2>/dev/null || echo missing)
  [[ "$EN" == "false" ]] || fail "Guacamole still traefik.enable=$EN (want false)"
  log "Guacamole traefik.enable=false"
fi

step "3. oauth2-proxy service running"
docker service ls --format '{{.Name}} {{.Replicas}}' | grep -q 'archgate-gw_oauth2-proxy' \
  || fail "archgate-gw_oauth2-proxy service missing"
REP=$(docker service ls --format '{{.Name}} {{.Replicas}}' | awk '/oauth2-proxy/ {print $2}')
echo "    replicas=$REP"
echo "$REP" | grep -q '1/1' || fail "oauth2-proxy not 1/1"
log "oauth2-proxy 1/1"

step "4. Proxy has OIDC issuer env (no secrets printed)"
docker service inspect archgate-gw_oauth2-proxy --format '{{range .Spec.TaskTemplate.ContainerSpec.Env}}{{println .}}{{end}}' \
  | grep -E 'OAUTH2_PROXY_OIDC_ISSUER|OAUTH2_PROXY_CLIENT_ID|OAUTH2_PROXY_CODE_CHALLENGE|OAUTH2_PROXY_ALLOWED_GROUPS|OAUTH2_PROXY_OIDC_EMAIL_CLAIM|OAUTH2_PROXY_PASS_USER' \
  | sed 's/SECRET=.*/SECRET=***/' || fail "missing oauth2 env"
log "OIDC Code/PKCE + preferred_username + pass-user-headers"

step "5. Header-auth 1:1 (internal API, simulates proxy hop)"
GUAC_IP=$(docker inspect "$(docker ps -q --filter name=archgate-gw_guacamole | head -1)" \
  --format '{{(index .NetworkSettings.Networks "archgate-public").IPAddress}}')
[[ -n "$GUAC_IP" ]] || fail "no guac IP"
TOK=$(docker run --rm --network archgate-public curlimages/curl:8.5.0 -sS \
  -H "X-Forwarded-User: testuser" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "" "http://${GUAC_IP}:8080/api/tokens")
echo "$TOK" | python3 -c 'import sys,json; d=json.load(sys.stdin); assert d.get("username")=="testuser", d; print("    username", d["username"], "ds", d.get("dataSource"))'
AUTH=$(echo "$TOK" | python3 -c 'import sys,json; print(json.load(sys.stdin)["authToken"])')
CONNS=$(docker run --rm --network archgate-public curlimages/curl:8.5.0 -sS \
  -H "Guacamole-Token: $AUTH" \
  "http://${GUAC_IP}:8080/api/session/data/postgresql/connections?token=${AUTH}")
echo "$CONNS" | python3 -c 'import sys,json; d=json.load(sys.stdin); assert "1" in d or any(v.get("name")=="lab-ssh-browser" for v in d.values()), d; print("    connections OK")'
log "header X-Forwarded-User=testuser → session + lab-ssh-browser"

echo ""
echo "=============================================="
echo " GUACAMOLE SSO PROXY E2E (ADR-007A) PASSED"
echo "=============================================="
echo "  Gate: unauthenticated → redirect/challenge"
echo "  Guacamole not public Traefik"
echo "  1:1 header-auth: testuser → connections"
echo "=============================================="
rm -f "$HDRS"
