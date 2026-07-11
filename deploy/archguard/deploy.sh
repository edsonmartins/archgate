#!/usr/bin/env bash
# Deploy ArchGuard (Kanidm + Console) onto ArchGate host Swarm.
# Run ON 192.168.1.180 as root, or via: ssh root@192.168.1.180 bash -s < deploy.sh
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-/root/archgate/repo}"
ARCHGUARD_SRC="${ARCHGUARD_SRC:-/root/archgate/archguard-src}"
KANIDM_DATA="${KANIDM_DATA:-/var/lib/archgate/kanidm}"
BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"

KANIDM_DOMAIN="${KANIDM_DOMAIN:-id.archgate.com.br}"
CONSOLE_DOMAIN="${CONSOLE_DOMAIN:-console.archgate.com.br}"
KANIDM_IMAGE="${KANIDM_IMAGE:-kanidm/server:1.10.4}"
ARCHGUARD_CONSOLE_IMAGE="${ARCHGUARD_CONSOLE_IMAGE:-archguard-console:local}"

cd "$REPO_ROOT"

if [[ -f "$BOOTSTRAP" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$BOOTSTRAP"
  set +a
fi

echo "==> 1. Kanidm data dir + TLS material"
mkdir -p "$KANIDM_DATA"
if [[ ! -f "$KANIDM_DATA/server.toml" ]]; then
  cp deploy/archguard/kanidm/server.toml "$KANIDM_DATA/server.toml"
fi
if [[ ! -f "$KANIDM_DATA/key.pem" || ! -f "$KANIDM_DATA/chain.pem" ]]; then
  openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
    -keyout "$KANIDM_DATA/key.pem" \
    -out "$KANIDM_DATA/chain.pem" \
    -subj "/CN=${KANIDM_DOMAIN}" \
    -addext "subjectAltName=DNS:${KANIDM_DOMAIN}"
  chmod 600 "$KANIDM_DATA/key.pem"
  echo "    generated self-signed cert for ${KANIDM_DOMAIN}"
fi
# Kanidm container runs as uid 999 typically — make data writable
chown -R 999:999 "$KANIDM_DATA" 2>/dev/null || chmod -R a+rX "$KANIDM_DATA"
chmod 644 "$KANIDM_DATA/chain.pem" "$KANIDM_DATA/server.toml" || true
chmod 600 "$KANIDM_DATA/key.pem" || true

echo "==> 2. /etc/hosts for local resolution (until public DNS/tunnel)"
for host in "$KANIDM_DOMAIN" "$CONSOLE_DOMAIN"; do
  if ! grep -qE "[[:space:]]${host}([[:space:]]|$)" /etc/hosts; then
    echo "127.0.0.1 ${host}" >> /etc/hosts
    echo "    added 127.0.0.1 ${host}"
  fi
done

echo "==> 3. Refresh Traefik (file provider for insecure backend TLS)"
set -a
# shellcheck disable=SC1091
source deploy/versions.env
set +a
export ACME_EMAIL="${ACME_EMAIL:-ops@archgate.com.br}"
docker stack deploy -c deploy/traefik/stack.yml archgate-edge

echo "==> 4. Deploy Kanidm only (console needs SA token after setup)"
# Temporary stack without console: use override via compose config if needed.
# Deploy full stack would fail without ARCHGUARD_SA_TOKEN — deploy kanidm service via docker service create if first run.
if ! docker service ls --format '{{.Name}}' | grep -qx 'archgate-id_kanidmd'; then
  docker service create \
    --name archgate-id_kanidmd \
    --network archgate-public \
    --network archgate-data \
    --constraint 'node.labels.archgate.runtime == true' \
    --mount type=bind,source="$KANIDM_DATA",target=/data \
    --publish mode=host,target=8443,published=8443 \
    --health-cmd '/sbin/kanidmd healthcheck -c /data/server.toml' \
    --health-interval 15s \
    --health-retries 10 \
    --health-start-period 40s \
    --label 'traefik.enable=true' \
    --label 'traefik.docker.network=archgate-public' \
    --label 'traefik.http.routers.kanidm.rule=Host(`'"$KANIDM_DOMAIN"'`)' \
    --label 'traefik.http.routers.kanidm.entrypoints=websecure' \
    --label 'traefik.http.routers.kanidm.tls=true' \
    --label 'traefik.http.routers.kanidm.tls.certresolver=letsencrypt' \
    --label 'traefik.http.routers.kanidm.service=kanidm' \
    --label 'traefik.http.services.kanidm.loadbalancer.server.port=8443' \
    --label 'traefik.http.services.kanidm.loadbalancer.server.scheme=https' \
    --label 'traefik.http.services.kanidm.loadbalancer.serverstransport=insecure-skip-verify@file' \
    --restart-condition on-failure \
    "$KANIDM_IMAGE"
else
  echo "    kanidmd service already exists"
fi

echo "==> 5. Wait for Kanidm /status"
for i in $(seq 1 40); do
  if curl -sk "https://127.0.0.1:8443/status" 2>/dev/null | grep -q true; then
    echo "    Kanidm healthy"
    break
  fi
  if [[ "$i" -eq 40 ]]; then
    echo "Kanidm did not become healthy" >&2
    docker service ps archgate-id_kanidmd --no-trunc | head -10
    exit 1
  fi
  sleep 3
done

echo "OK: Kanidm up. Next: run bootstrap-kanidm.sh then deploy-console.sh"
