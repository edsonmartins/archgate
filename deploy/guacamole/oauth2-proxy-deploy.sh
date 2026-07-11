#!/usr/bin/env bash
# ADR-007A — oauth2-proxy (OIDC Code+PKCE) in front of Guacamole
# Run on 192.168.1.180 as root.
set -euo pipefail

BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
DOMAIN_GUAC="${GUACAMOLE_DOMAIN:-guac.archgate.com.br}"
KANIDM_DOMAIN="${KANIDM_DOMAIN:-id.archgate.com.br}"
IMAGE="${OAUTH2_PROXY_IMAGE:-quay.io/oauth2-proxy/oauth2-proxy:v7.7.1}"
SVC_PROXY="${OAUTH2_PROXY_SERVICE:-archgate-gw_oauth2-proxy}"
SVC_GUAC="${GUACAMOLE_SERVICE:-archgate-gw_guacamole}"
UPSTREAM="${GUACAMOLE_UPSTREAM:-http://archgate-gw_guacamole:8080}"

set -a
# shellcheck disable=SC1090
source "$BOOTSTRAP"
set +a

: "${GUACAMOLE_OIDC_CLIENT_SECRET:?missing GUACAMOLE_OIDC_CLIENT_SECRET in bootstrap}"

if [[ -z "${OAUTH2_PROXY_COOKIE_SECRET:-}" ]]; then
  # Must decode to 16/24/32 bytes — url-safe base64 of 32 random bytes
  OAUTH2_PROXY_COOKIE_SECRET=$(openssl rand -base64 32 | tr '+/' '-_' | tr -d '=\n')
  grep -v '^OAUTH2_PROXY_COOKIE_SECRET=' "$BOOTSTRAP" > /tmp/bs.o2p || true
  mv /tmp/bs.o2p "$BOOTSTRAP"
  echo "OAUTH2_PROXY_COOKIE_SECRET=${OAUTH2_PROXY_COOKIE_SECRET}" >> "$BOOTSTRAP"
  chmod 600 "$BOOTSTRAP"
  echo "==> generated OAUTH2_PROXY_COOKIE_SECRET"
fi

ISSUER="https://${KANIDM_DOMAIN}/oauth2/openid/guacamole"
REDIRECT="https://${DOMAIN_GUAC}/oauth2/callback"
CLIENT_ID="${GUACAMOLE_OIDC_CLIENT_ID:-guacamole}"

echo "==> ensure Kanidm redirect URL ${REDIRECT}"
# Best-effort: tools container + idm_admin (may already exist)
if [[ -n "${KANIDM_IDM_ADMIN_PASSWORD:-}" ]]; then
  TOKENS=$(mktemp)
  TOOLS="${KANIDM_TOOLS_IMAGE:-kanidm/tools:1.10.4}"
  expect <<EOF >/dev/null 2>&1 || true
set timeout 45
spawn docker run --rm -it --network host -v ${TOKENS}:/root/.cache/kanidm_tokens -e KANIDM_URL=https://127.0.0.1:8443 ${TOOLS} /sbin/kanidm login --accept-invalid-certs --name idm_admin
expect -re "password:"
send "${KANIDM_IDM_ADMIN_PASSWORD}\r"
expect eof
EOF
  docker run --rm --network host \
    -v "${TOKENS}:/root/.cache/kanidm_tokens" \
    -e "KANIDM_URL=https://127.0.0.1:8443" \
    "$TOOLS" /sbin/kanidm system oauth2 add-redirect-url guacamole "$REDIRECT" \
    --accept-invalid-certs --name idm_admin 2>&1 | tail -5 || true
  rm -f "$TOKENS"
fi

echo "==> strip public Traefik from Guacamole (C1 fail-closed)"
if docker service ls --format '{{.Name}}' | grep -qx "$SVC_GUAC"; then
  docker service update \
    --label-rm traefik.enable \
    --label-rm "traefik.http.routers.guacamole.rule" \
    --label-rm traefik.http.routers.guacamole.entrypoints \
    --label-rm traefik.http.routers.guacamole.tls \
    --label-rm traefik.http.routers.guacamole.tls.certresolver \
    --label-rm traefik.http.routers.guacamole.service \
    --label-rm traefik.http.services.guacamole.loadbalancer.server.port \
    --label-rm traefik.docker.network \
    --label-add "traefik.enable=false" \
    "$SVC_GUAC" 2>&1 | tail -8 || true
fi

echo "==> deploy ${SVC_PROXY}"
docker service rm "$SVC_PROXY" 2>/dev/null || true
sleep 2

# allowed group: archguard_users (operators with console/gateway access)
# Kanidm groups claim may be full SPN — oauth2-proxy oidc-groups-claim=groups
docker service create \
  --name "$SVC_PROXY" \
  --network archgate-public \
  --constraint 'node.labels.archgate.runtime == true' \
  --host "${KANIDM_DOMAIN}:192.168.1.180" \
  --env "OAUTH2_PROXY_PROVIDER=oidc" \
  --env "OAUTH2_PROXY_OIDC_ISSUER_URL=${ISSUER}" \
  --env "OAUTH2_PROXY_CLIENT_ID=${CLIENT_ID}" \
  --env "OAUTH2_PROXY_CLIENT_SECRET=${GUACAMOLE_OIDC_CLIENT_SECRET}" \
  --env "OAUTH2_PROXY_REDIRECT_URL=${REDIRECT}" \
  --env "OAUTH2_PROXY_COOKIE_SECRET=${OAUTH2_PROXY_COOKIE_SECRET}" \
  --env "OAUTH2_PROXY_COOKIE_SECURE=true" \
  --env "OAUTH2_PROXY_COOKIE_HTTPONLY=true" \
  --env "OAUTH2_PROXY_COOKIE_SAMESITE=lax" \
  --env "OAUTH2_PROXY_EMAIL_DOMAINS=*" \
  --env "OAUTH2_PROXY_UPSTREAMS=${UPSTREAM}" \
  --env "OAUTH2_PROXY_HTTP_ADDRESS=0.0.0.0:4180" \
  --env "OAUTH2_PROXY_REVERSE_PROXY=true" \
  --env "OAUTH2_PROXY_PASS_HOST_HEADER=true" \
  --env "OAUTH2_PROXY_SKIP_PROVIDER_BUTTON=true" \
  --env "OAUTH2_PROXY_CODE_CHALLENGE_METHOD=S256" \
  --env "OAUTH2_PROXY_OIDC_GROUPS_CLAIM=groups" \
  --env "OAUTH2_PROXY_OIDC_EMAIL_CLAIM=preferred_username" \
  --env "OAUTH2_PROXY_SCOPE=openid profile email groups" \
  --env "OAUTH2_PROXY_ALLOWED_GROUPS=archguard_users" \
  --env "OAUTH2_PROXY_INSECURE_OIDC_ALLOW_UNVERIFIED_EMAIL=true" \
  --env "OAUTH2_PROXY_SSL_INSECURE_SKIP_VERIFY=true" \
  --env "OAUTH2_PROXY_SET_XAUTHREQUEST=true" \
  --env "OAUTH2_PROXY_PASS_USER_HEADERS=true" \
  --label traefik.enable=true \
  --label traefik.docker.network=archgate-public \
  --label "traefik.http.routers.guacamole.rule=Host(\`${DOMAIN_GUAC}\`)" \
  --label traefik.http.routers.guacamole.entrypoints=websecure \
  --label traefik.http.routers.guacamole.tls=true \
  --label traefik.http.routers.guacamole.tls.certresolver=letsencrypt \
  --label traefik.http.routers.guacamole.service=guacamole-o2p \
  --label traefik.http.services.guacamole-o2p.loadbalancer.server.port=4180 \
  --restart-condition on-failure \
  --detach=true \
  "$IMAGE"

echo "==> wait for proxy via Traefik"
for i in $(seq 1 30); do
  code=$(curl -sk -o /dev/null -w '%{http_code}' -H "Host: ${DOMAIN_GUAC}" https://127.0.0.1/ || true)
  echo "  try $i http=$code"
  # 302/307 to IdP or 403 without cookie is expected
  if echo "$code" | grep -qE '302|303|307|401|403|200'; then
    echo "OAUTH2_PROXY_UP http=$code"
    break
  fi
  sleep 3
done

docker service ps "$SVC_PROXY" --format '{{.CurrentState}} {{.Error}}' | head -5
echo "OK: ${DOMAIN_GUAC} → oauth2-proxy → ${UPSTREAM}"
echo "    Redirect URI must exist on Kanidm client guacamole: ${REDIRECT}"
echo "    Header-auth: preferred_username → X-Forwarded-User → Guacamole user (1:1)"
PROV="$(dirname "$0")/provision-kanidm-users.sh"
echo "    Sync Kanidm operators → Guacamole users: bash ${PROV}"
if [[ -f "$PROV" ]]; then
  bash "$PROV" || warn_sync=1
fi
[[ "${warn_sync:-0}" == "1" ]] && echo "  [!!] provision-kanidm-users.sh reported errors (check logs)"
