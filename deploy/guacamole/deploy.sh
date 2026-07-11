#!/usr/bin/env bash
# Fase 1 tasks 4.1–4.5: Guacamole + guacd + Postgres + OIDC (Kanidm) + recording.
#
# Nota de arquitetura: a extensão OpenID stock do Guacamole usa OIDC *implicit flow*,
# incompatível com Kanidm (só authorization_code) e com CONSTITUTION §4.4.
# Estratégia Fase 1: PostgreSQL auth + gravação + conexão browser (SSH lab);
# Portão SSO na borda: oauth2-proxy (ADR-007A) — ver oauth2-proxy-deploy.sh.
# SSO nativo Guacamole / UnifiedUI: ADR-007 + Fase 4.
set -euo pipefail

BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
REPO="${REPO_ROOT:-/root/archgate/repo}"
DATA="${GUACAMOLE_DATA:-/var/lib/archgate/guacamole}"
GUAC_IMAGE="${GUACAMOLE_IMAGE:-guacamole/guacamole:1.6.0}"
GUACD_IMAGE="${GUACD_IMAGE:-guacamole/guacd:1.6.0}"
DOMAIN_GUAC="${GUACAMOLE_DOMAIN:-guac.archgate.com.br}"

set -a
# shellcheck disable=SC1090
source "$BOOTSTRAP"
# shellcheck disable=SC1091
source "$REPO/deploy/versions.env" 2>/dev/null || true
set +a

: "${POSTGRES_HOST:?}"
: "${POSTGRES_PORT:?}"
: "${POSTGRES_GUACAMOLE_PASSWORD:?}"

mkdir -p "$DATA/recordings" "$DATA/drive" "$DATA/init"
chmod 755 "$DATA" "$DATA/recordings"

echo "==> 4.1 init Guacamole PostgreSQL schema (if empty)"
export PGPASSWORD="$POSTGRES_GUACAMOLE_PASSWORD"
TABLES=$(psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U guacamole -d guacamole -tAc \
  "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='guacamole_user';" || echo 0)
if [[ "${TABLES// /}" == "0" ]]; then
  docker run --rm "$GUAC_IMAGE" /opt/guacamole/bin/initdb.sh --postgresql > "$DATA/init/initdb.sql"
  psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U guacamole -d guacamole -v ON_ERROR_STOP=1 -f "$DATA/init/initdb.sql"
  echo "schema applied"
else
  echo "schema already present"
fi

# Discover Kanidm OIDC endpoints for documentation / future bridge
ISSUER="https://id.archgate.com.br/oauth2/openid/guacamole"
DISC=$(curl -sk "$ISSUER/.well-known/openid-configuration" || true)
echo "$DISC" | python3 -c 'import sys,json
try:
 d=json.load(sys.stdin)
 print("oidc_issuer", d.get("issuer"))
 print("auth", d.get("authorization_endpoint"))
 print("jwks", d.get("jwks_uri"))
except Exception as e:
 print("oidc discovery failed", e)
' || true

echo "==> deploy guacd"
docker service rm archgate-gw_guacd 2>/dev/null || true
docker service rm archgate-gw_guacamole 2>/dev/null || true
sleep 2

docker service create \
  --name archgate-gw_guacd \
  --network archgate-data \
  --constraint 'node.labels.archgate.runtime == true' \
  --mount type=bind,source="$DATA/recordings",target=/recordings \
  --env GUACD_LOG_LEVEL=info \
  --restart-condition on-failure \
  --detach=true \
  "$GUACD_IMAGE"

echo "==> deploy guacamole webapp"
# PostgreSQL JDBC URL for Guacamole docker image
# Uses POSTGRES_* env vars documented by guacamole/guacamole image
docker service create \
  --name archgate-gw_guacamole \
  --network archgate-public \
  --network archgate-data \
  --constraint 'node.labels.archgate.runtime == true' \
  --host "id.archgate.com.br:192.168.1.180" \
  --env POSTGRESQL_HOSTNAME="$POSTGRES_HOST" \
  --env POSTGRESQL_PORT="$POSTGRES_PORT" \
  --env POSTGRESQL_DATABASE=guacamole \
  --env POSTGRESQL_USER=guacamole \
  --env POSTGRESQL_PASSWORD="$POSTGRES_GUACAMOLE_PASSWORD" \
  --env GUACD_HOSTNAME=archgate-gw_guacd \
  --env GUACD_PORT=4822 \
  --env WEBAPP_CONTEXT=ROOT \
  --env REMOTE_IP_VALVE_ENABLED=true \
  --env RECORDING_SEARCH_PATH=/recordings \
  --env TOTAL_CONNECT_BACKENDS=true \
  --env EXTENSION_PRIORITY=header \
  --env HTTP_AUTH_ENABLED=true \
  --env HTTP_AUTH_HEADER=X-Forwarded-User \
  --mount type=bind,source="$DATA/recordings",target=/recordings \
  --label traefik.enable=false \
  --restart-condition on-failure \
  --detach=true \
  "$GUAC_IMAGE"
# Public TLS route is owned by oauth2-proxy (ADR-007A). After this script:
#   bash "$REPO/deploy/guacamole/oauth2-proxy-deploy.sh"

grep -q "$DOMAIN_GUAC" /etc/hosts || echo "127.0.0.1 $DOMAIN_GUAC" >> /etc/hosts

echo "==> wait for guacamole HTTP"
for i in $(seq 1 40); do
  code=$(curl -sk -o /dev/null -w '%{http_code}' -H "Host: ${DOMAIN_GUAC}" https://127.0.0.1/ || true)
  echo "try $i code=$code"
  if echo "$code" | grep -qE '200|302|301|307|308'; then
    echo GUACAMOLE_UP
    break
  fi
  sleep 3
done

docker service ls --filter name=archgate-gw
docker service ps archgate-gw_guacamole --format '{{.CurrentState}} {{.Error}}' | head -5
docker logs "$(docker ps -q --filter name=archgate-gw_guacamole | head -1)" 2>&1 | tail -30 || true
echo "DONE deploy guacamole"
