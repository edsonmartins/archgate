#!/usr/bin/env bash
# Build ArchGuard Console image from archguard source and deploy Swarm service.
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-/root/archgate/repo}"
ARCHGUARD_SRC="${ARCHGUARD_SRC:-/root/archgate/archguard-src}"
BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
IMAGE="${ARCHGUARD_CONSOLE_IMAGE:-archguard-console:local}"
KANIDM_DOMAIN="${KANIDM_DOMAIN:-id.archgate.com.br}"
CONSOLE_DOMAIN="${CONSOLE_DOMAIN:-console.archgate.com.br}"
CONSOLE_DATA_DIR="${CONSOLE_DATA_DIR:-/var/lib/archgate/console}"

set -a
# shellcheck disable=SC1090
source "$BOOTSTRAP"
set +a

: "${ARCHGUARD_SA_TOKEN:?run bootstrap-kanidm.sh first}"
: "${SESSION_SECRET:?run bootstrap-kanidm.sh first}"

echo "==> Build console image (VITE_ARCHGUARD_ID_URL=https://${KANIDM_DOMAIN})"
[[ -d "$ARCHGUARD_SRC/archguard-console" ]] || {
  echo "Missing $ARCHGUARD_SRC/archguard-console — rsync archguard repo first" >&2
  exit 1
}

docker build \
  -f "$REPO_ROOT/deploy/archguard/console.Dockerfile" \
  --build-arg "VITE_ARCHGUARD_ID_URL=https://${KANIDM_DOMAIN}" \
  -t "$IMAGE" \
  "$ARCHGUARD_SRC/archguard-console"

echo "==> Persist console SQLite on host (${CONSOLE_DATA_DIR})"
mkdir -p "$CONSOLE_DATA_DIR"
chown -R 100:101 "$CONSOLE_DATA_DIR" 2>/dev/null || true
chmod 750 "$CONSOLE_DATA_DIR"

echo "==> Deploy / update console service"
if docker service ls --format '{{.Name}}' | grep -qx 'archgate-id_archguard-console'; then
  # Control plane: Warpgate admin API (ADR-009) — password never in browser
  WG_ENV=(
    --env-add "ARCHGUARD_ID_URL=https://${KANIDM_DOMAIN}"
    --env-add "ARCHGUARD_SA_TOKEN=${ARCHGUARD_SA_TOKEN}"
    --env-add "SESSION_SECRET=${SESSION_SECRET}"
    --env-add "NODE_ENV=production"
    --env-add "PORT=3000"
    --env-add "HOST=0.0.0.0"
    --env-add "LOG_LEVEL=info"
    --env-add "ARCHGUARD_DB_PATH=/app/data/archguard.sqlite"
    # Public UI URL vs Swarm connect host (SNI via Traefik — see warpgate-proxy)
    --env-add "WARPGATE_PUBLIC_URL=${WARPGATE_PUBLIC_URL:-https://wg.archgate.com.br}"
    --env-add "WARPGATE_URL=${WARPGATE_URL:-https://wg.archgate.com.br}"
    --env-add "WARPGATE_HOST=${WARPGATE_HOST:-wg.archgate.com.br}"
    --env-add "WARPGATE_CONNECT_HOST=${WARPGATE_CONNECT_HOST:-archgate-edge_traefik}"
    --env-add "WARPGATE_ADMIN_USER=${WARPGATE_ADMIN_USER:-admin}"
  )
  if [[ -n "${WARPGATE_ADMIN_PASSWORD:-}" ]]; then
    WG_ENV+=(--env-add "WARPGATE_ADMIN_PASSWORD=${WARPGATE_ADMIN_PASSWORD}")
  fi
  # Per-target secrets (TARGET_SECRET_<NAME>) — no global LAB_SSH_PASSWORD
  if [[ -n "${TARGET_SECRET_RIO_LAB_SSH:-}" ]]; then
    WG_ENV+=(--env-add "TARGET_SECRET_RIO_LAB_SSH=${TARGET_SECRET_RIO_LAB_SSH}")
  fi
  WG_ENV+=(--env-add "GUACAMOLE_URL=${GUACAMOLE_URL:-http://archgate-gw_guacamole:8080}")
  WG_ENV+=(--env-add "GUACAMOLE_PUBLIC_URL=${GUACAMOLE_PUBLIC_URL:-https://guac.archgate.com.br}")
  WG_ENV+=(--env-add "GUACAMOLE_ADMIN_USER=${GUACAMOLE_ADMIN_USER:-guacadmin}")
  if [[ -n "${GUACAMOLE_ADMIN_PASSWORD:-}" ]]; then
    WG_ENV+=(--env-add "GUACAMOLE_ADMIN_PASSWORD=${GUACAMOLE_ADMIN_PASSWORD}")
  elif [[ -n "${GUACADMIN_PASSWORD:-}" ]]; then
    WG_ENV+=(--env-add "GUACAMOLE_ADMIN_PASSWORD=${GUACADMIN_PASSWORD}")
  fi
  # Sites SoT (CP-6) — PostgreSQL when provisioned; else SQLite on volume
  if [[ -n "${CONSOLE_DATABASE_URL:-}" ]]; then
    WG_ENV+=(--env-add "CONSOLE_DATABASE_URL=${CONSOLE_DATABASE_URL}")
  elif [[ -n "${CONSOLE_PG_PASSWORD:-}" && -n "${POSTGRES_HOST:-}" ]]; then
    CONSOLE_PG_USER="${CONSOLE_PG_USER:-archguard_console}"
    CONSOLE_PG_DB="${CONSOLE_PG_DB:-archguard_console}"
    WG_ENV+=(--env-add "CONSOLE_DATABASE_URL=postgresql://${CONSOLE_PG_USER}:${CONSOLE_PG_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT:-5432}/${CONSOLE_PG_DB}")
  fi
  # OpenBao control plane (CP-4) — prefer APP_TOKEN.
  # W1: root/unseal never on console unless ARCHGATE_LAB=1 (ops unseal via systemd).
  ARCHGATE_LAB="${ARCHGATE_LAB:-0}"
  WG_ENV+=(--env-add "OPENBAO_ADDR=${OPENBAO_INTERNAL_ADDR:-http://archgate-secrets_openbao:8200}")
  WG_ENV+=(--env-add "ARCHGATE_LAB=${ARCHGATE_LAB}")
  if [[ -n "${OPENBAO_APP_TOKEN:-}" ]]; then
    WG_ENV+=(--env-add "OPENBAO_APP_TOKEN=${OPENBAO_APP_TOKEN}")
  elif [[ -n "${OPENBAO_TOKEN:-}" ]]; then
    WG_ENV+=(--env-add "OPENBAO_APP_TOKEN=${OPENBAO_TOKEN}")
  fi
  if [[ "${ARCHGATE_LAB}" == "1" ]]; then
    if [[ -n "${OPENBAO_ROOT_TOKEN:-}" ]]; then
      WG_ENV+=(--env-add "OPENBAO_ROOT_TOKEN=${OPENBAO_ROOT_TOKEN}")
    fi
    if [[ -n "${OPENBAO_UNSEAL_KEY:-}" ]]; then
      WG_ENV+=(--env-add "OPENBAO_UNSEAL_KEY=${OPENBAO_UNSEAL_KEY}")
    fi
  else
    docker service update \
      --env-rm OPENBAO_ROOT_TOKEN \
      --env-rm OPENBAO_UNSEAL_KEY \
      --env-rm ARCHGUARD_E2E_LOGIN \
      archgate-id_archguard-console 2>/dev/null || true
  fi
  # TLS: lab may set NODE_TLS_REJECT_UNAUTHORIZED=0; prod leave unset (default verify)
  if [[ "${ARCHGATE_LAB}" == "1" && "${NODE_TLS_REJECT_UNAUTHORIZED:-}" == "0" ]]; then
    WG_ENV+=(--env-add "NODE_TLS_REJECT_UNAUTHORIZED=0")
  elif [[ "${ARCHGATE_LAB}" != "1" ]]; then
    docker service update --env-rm NODE_TLS_REJECT_UNAUTHORIZED \
      archgate-id_archguard-console 2>/dev/null || true
  fi
  # Mentors Axis (CP-7) — prefer bootstrap; else keep existing service URL
  if [[ -z "${MENTORS_AXIS_URL:-}" ]]; then
    MENTORS_AXIS_URL="$(
      docker service inspect archgate-id_archguard-console \
        --format '{{range .Spec.TaskTemplate.ContainerSpec.Env}}{{println .}}{{end}}' \
        2>/dev/null | sed -n 's/^MENTORS_AXIS_URL=//p' | head -1
    )"
  fi
  # URL set ⇒ live; force MOCK=0 (never leave stale MOCK=1 with live URL)
  if [[ -n "${MENTORS_AXIS_URL:-}" ]]; then
    WG_ENV+=(--env-add "MENTORS_AXIS_URL=${MENTORS_AXIS_URL}")
    WG_ENV+=(--env-add "MENTORS_AXIS_MOCK=0")
    # Prefer JWT password login for Spring; only set TOKEN if non-empty (stub/API key)
    if [[ -n "${MENTORS_AXIS_TOKEN:-}" ]]; then
      WG_ENV+=(--env-add "MENTORS_AXIS_TOKEN=${MENTORS_AXIS_TOKEN}")
    else
      # drop residual stub token from prior deploys
      docker service update --env-rm MENTORS_AXIS_TOKEN archgate-id_archguard-console 2>/dev/null || true
    fi
    [[ -n "${MENTORS_AXIS_EMAIL:-}" ]] && WG_ENV+=(--env-add "MENTORS_AXIS_EMAIL=${MENTORS_AXIS_EMAIL}")
    [[ -n "${MENTORS_AXIS_PASSWORD:-}" ]] && WG_ENV+=(--env-add "MENTORS_AXIS_PASSWORD=${MENTORS_AXIS_PASSWORD}")
    [[ -n "${MENTORS_AXIS_TENANT_ID:-}" ]] && WG_ENV+=(--env-add "MENTORS_AXIS_TENANT_ID=${MENTORS_AXIS_TENANT_ID}")
  else
    WG_ENV+=(--env-add "MENTORS_AXIS_MOCK=${MENTORS_AXIS_MOCK:-1}")
  fi

  # Drop residual env that violates remediations
  docker service update --env-rm LAB_SSH_PASSWORD archgate-id_archguard-console 2>/dev/null || true

  MOUNT_ARGS=()
  if ! docker service inspect archgate-id_archguard-console \
    --format '{{json .Spec.TaskTemplate.ContainerSpec.Mounts}}' 2>/dev/null \
    | grep -q '"Target":"/app/data"'; then
    MOUNT_ARGS=(--mount-add "type=bind,source=${CONSOLE_DATA_DIR},destination=/app/data")
  fi

  docker service update \
    --image "$IMAGE" \
    "${MOUNT_ARGS[@]}" \
    "${WG_ENV[@]}" \
    archgate-id_archguard-console
else
  docker service create \
    --name archgate-id_archguard-console \
    --network archgate-public \
    --network archgate-data \
    --constraint 'node.labels.archgate.runtime == true' \
    --mount "type=bind,source=${CONSOLE_DATA_DIR},destination=/app/data" \
    --env "NODE_ENV=production" \
    --env "PORT=3000" \
    --env "HOST=0.0.0.0" \
    --env "ARCHGUARD_ID_URL=https://${KANIDM_DOMAIN}" \
    --env "ARCHGUARD_SA_TOKEN=${ARCHGUARD_SA_TOKEN}" \
    --env "SESSION_SECRET=${SESSION_SECRET}" \
    --env "LOG_LEVEL=info" \
    --env "ARCHGUARD_DB_PATH=/app/data/archguard.sqlite" \
    --env "CONSOLE_DATABASE_URL=${CONSOLE_DATABASE_URL:-}" \
    --env "WARPGATE_PUBLIC_URL=${WARPGATE_PUBLIC_URL:-https://wg.archgate.com.br}" \
    --env "WARPGATE_URL=${WARPGATE_URL:-https://wg.archgate.com.br}" \
    --env "WARPGATE_HOST=${WARPGATE_HOST:-wg.archgate.com.br}" \
    --env "WARPGATE_CONNECT_HOST=${WARPGATE_CONNECT_HOST:-archgate-edge_traefik}" \
    --env "WARPGATE_ADMIN_USER=${WARPGATE_ADMIN_USER:-admin}" \
    --env "WARPGATE_ADMIN_PASSWORD=${WARPGATE_ADMIN_PASSWORD:-}" \
    --env "GUACAMOLE_URL=${GUACAMOLE_URL:-http://archgate-gw_guacamole:8080}" \
    --env "GUACAMOLE_PUBLIC_URL=${GUACAMOLE_PUBLIC_URL:-https://guac.archgate.com.br}" \
    --env "GUACAMOLE_ADMIN_USER=${GUACAMOLE_ADMIN_USER:-guacadmin}" \
    --env "GUACAMOLE_ADMIN_PASSWORD=${GUACAMOLE_ADMIN_PASSWORD:-${GUACADMIN_PASSWORD:-}}" \
    --env "OPENBAO_ADDR=${OPENBAO_INTERNAL_ADDR:-http://archgate-secrets_openbao:8200}" \
    --env "ARCHGATE_LAB=${ARCHGATE_LAB:-0}" \
    --env "OPENBAO_APP_TOKEN=${OPENBAO_APP_TOKEN:-${OPENBAO_TOKEN:-}}" \
    --env "OPENBAO_ROOT_TOKEN=$( [[ "${ARCHGATE_LAB:-0}" == "1" ]] && echo "${OPENBAO_ROOT_TOKEN:-}" || echo "" )" \
    --env "OPENBAO_UNSEAL_KEY=$( [[ "${ARCHGATE_LAB:-0}" == "1" ]] && echo "${OPENBAO_UNSEAL_KEY:-}" || echo "" )" \
    --env "MENTORS_AXIS_URL=${MENTORS_AXIS_URL:-}" \
    --env "MENTORS_AXIS_TOKEN=${MENTORS_AXIS_TOKEN:-}" \
    --env "MENTORS_AXIS_EMAIL=${MENTORS_AXIS_EMAIL:-}" \
    --env "MENTORS_AXIS_PASSWORD=${MENTORS_AXIS_PASSWORD:-}" \
    --env "MENTORS_AXIS_TENANT_ID=${MENTORS_AXIS_TENANT_ID:-}" \
    --env "MENTORS_AXIS_MOCK=$( [[ -n "${MENTORS_AXIS_URL:-}" ]] && echo 0 || echo "${MENTORS_AXIS_MOCK:-1}" )" \
    --label 'traefik.enable=true' \
    --label 'traefik.docker.network=archgate-public' \
    --label "traefik.http.routers.console.rule=Host(\`${CONSOLE_DOMAIN}\`)" \
    --label 'traefik.http.routers.console.entrypoints=websecure' \
    --label 'traefik.http.routers.console.tls=true' \
    --label 'traefik.http.routers.console.tls.certresolver=letsencrypt' \
    --label 'traefik.http.routers.console.service=console' \
    --label 'traefik.http.services.console.loadbalancer.server.port=3000' \
    --restart-condition on-failure \
    "$IMAGE"
fi

echo "==> Wait for console"
for i in $(seq 1 30); do
  if curl -sk -o /dev/null -w '%{http_code}' -H "Host: ${CONSOLE_DOMAIN}" "https://127.0.0.1/" | grep -qE '200|302|301|307|308'; then
    echo "    console responding via Traefik"
    break
  fi
  sleep 3
done

echo "OK: console deployed at https://${CONSOLE_DOMAIN}"
