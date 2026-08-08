#!/usr/bin/env bash
# Deploy Warpgate with Postgres + ArchGuard OIDC.
set -euo pipefail

BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
DATA="${WARPGATE_DATA:-/var/lib/archgate/warpgate}"
IMAGE="${WARPGATE_IMAGE:-ghcr.io/warp-tech/warpgate:0.26.1}"
DOMAIN_WG="${WARPGATE_DOMAIN:-wg.archgate.com.br}"

set -a
# shellcheck disable=SC1090
source "$BOOTSTRAP"
# shellcheck disable=SC1091
source /root/archgate/repo/deploy/versions.env 2>/dev/null || true
set +a

: "${POSTGRES_HOST:?}"
: "${POSTGRES_PORT:?}"
: "${POSTGRES_WARPGATE_PASSWORD:?}"
: "${WARPGATE_OIDC_CLIENT_SECRET:?run bootstrap-identity-axis first}"

ADMIN_PASSWORD="${WARPGATE_ADMIN_PASSWORD:-$(openssl rand -base64 24)}"
DATABASE_URL="postgres://warpgate:${POSTGRES_WARPGATE_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/warpgate"

mkdir -p "$DATA"
chown -R 1000:1000 "$DATA" 2>/dev/null || true
chmod 700 "$DATA"

if [[ ! -f "$DATA/warpgate.yaml" ]]; then
  echo "==> unattended-setup (Postgres + session recording)"
  docker run --rm \
    --add-host "${POSTGRES_HOST}:${POSTGRES_HOST}" \
    -v "$DATA:/data" \
    -e WARPGATE_ADMIN_PASSWORD="$ADMIN_PASSWORD" \
    "$IMAGE" unattended-setup \
      --data-path /data \
      --http-port 8888 \
      --ssh-port 2222 \
      --postgres-port 55432 \
      --record-sessions \
      --external-host "$DOMAIN_WG" \
      --database-url "$DATABASE_URL" \
      --admin-password "$ADMIN_PASSWORD"
else
  echo "==> config exists, skip setup"
fi

echo "==> patch SSO (custom OIDC)"
ARCHGATE_IDP_URL="${ARCHGATE_IDP_URL:-https://app.archguard.com.br}"
export DATA DOMAIN_WG WARPGATE_OIDC_CLIENT_SECRET ARCHGATE_IDP_URL
python3 - <<'PY'
import os, re, pathlib
path = pathlib.Path(os.environ["DATA"]) / "warpgate.yaml"
text = path.read_text()
domain = os.environ["DOMAIN_WG"]
secret = os.environ["WARPGATE_OIDC_CLIENT_SECRET"]
idp_url = os.environ["ARCHGATE_IDP_URL"].rstrip("/")
issuer = idp_url

# Warpgate matches group values from the claim EXACTLY. ArchGuard qualifies them
gprefix = f"{os.environ.get('ARCHGATE_IDP_ORG', 'archgate')}/"

if re.search(r"^external_host:", text, re.M):
    text = re.sub(r"^external_host:.*$", f"external_host: {domain}", text, flags=re.M)
else:
    text = f"external_host: {domain}\n" + text

sso_block = f"""
sso_providers:
  - name: archguard
    label: ArchGuard
    auto_create_users: true
    provider:
      type: custom
      client_id: warpgate
      client_secret: "{secret}"
      issuer_url: {issuer}
      scopes: ["openid", "profile", "email", "groups"]
      groups_claim: groups
      role_mappings:
        {gprefix}archguard_super_admins: "warpgate:admin"
        {gprefix}archguard_users: "archgate-operators"
"""
if "sso_providers:" in text:
    text = re.sub(r"\nsso_providers:[\s\S]*?(?=\n[a-zA-Z_]|\Z)", "\n" + sso_block.strip() + "\n", text)
else:
    text = text.rstrip() + "\n" + sso_block

# Always enforce session recording (audit/replay — task 6.4)
rec_block = "recordings:\n  enable: true\n  path: /data/recordings\n"
if re.search(r"(?m)^recordings:", text):
    text = re.sub(r"(?m)^recordings:\n(?:  .*\n)*", rec_block, text)
elif "\nlog:\n" in text:
    text = text.replace("\nlog:\n", "\n" + rec_block + "log:\n", 1)
else:
    text = text.rstrip() + "\n" + rec_block

path.write_text(text)
print("SSO + recordings patched OK")
PY
mkdir -p "$DATA/recordings"
chown -R 1000:1000 "$DATA/recordings" 2>/dev/null || true
chmod 700 "$DATA/recordings"

grep -v '^WARPGATE_ADMIN_PASSWORD=' "$BOOTSTRAP" > /tmp/bs.env || true
mv /tmp/bs.env "$BOOTSTRAP"
echo "WARPGATE_ADMIN_PASSWORD=${ADMIN_PASSWORD}" >> "$BOOTSTRAP"
chmod 600 "$BOOTSTRAP"

echo "==> deploy Swarm service"
docker service rm archgate-gw_warpgate 2>/dev/null || true
sleep 2
docker service create \
  --name archgate-gw_warpgate \
  --network archgate-public \
  --network archgate-data \
  --constraint 'node.labels.archgate.runtime == true' \
  --mount type=bind,source="$DATA",target=/data \
  --publish mode=host,target=2222,published=2222 \
  --publish mode=host,target=55432,published=55432 \
  --label traefik.enable=true \
  --label traefik.docker.network=archgate-public \
  --label "traefik.http.routers.warpgate.rule=Host(\`${DOMAIN_WG}\`)" \
  --label traefik.http.routers.warpgate.entrypoints=websecure \
  --label traefik.http.routers.warpgate.tls=true \
  --label traefik.http.routers.warpgate.tls.certresolver=letsencrypt \
  --label traefik.http.routers.warpgate.service=warpgate \
  --label traefik.http.services.warpgate.loadbalancer.server.port=8888 \
  --label traefik.http.services.warpgate.loadbalancer.server.scheme=https \
  --label traefik.http.services.warpgate.loadbalancer.serverstransport=insecure-skip-verify@file \
  --restart-condition on-failure \
  --detach=true \
  "$IMAGE"

for i in $(seq 1 40); do
  code=$(curl -sk -o /dev/null -w '%{http_code}' -H "Host: ${DOMAIN_WG}" https://127.0.0.1/ || true)
  echo "try $i http=$code"
  if echo "$code" | grep -qE '200|301|302|307|308|401|403'; then
    echo WARPGATE_UP
    break
  fi
  sleep 3
done
docker service ls
docker service ps archgate-gw_warpgate --format '{{.CurrentState}} {{.Error}}' | head -5
echo "Admin password in bootstrap: WARPGATE_ADMIN_PASSWORD"
