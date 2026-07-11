#!/usr/bin/env bash
# Load bootstrap env (plaintext, outside git) and create Docker Swarm secrets for task 1.1/1.3.
# Usage:
#   source /path/to/archgate-bootstrap.env   # or: set -a; source ...; set +a
#   ./deploy/secrets/create-swarm-secrets.sh
set -euo pipefail

require() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required env: $name" >&2
    exit 1
  fi
}

require POSTGRES_SUPERUSER_PASSWORD
require POSTGRES_WARPGATE_PASSWORD
require POSTGRES_GUACAMOLE_PASSWORD

create_or_replace_secret() {
  local name="$1"
  local value="$2"
  if docker secret inspect "$name" >/dev/null 2>&1; then
    echo "Secret $name already exists — remove manually if rotation is needed: docker secret rm $name"
    return 0
  fi
  printf '%s' "$value" | docker secret create "$name" -
  echo "Created secret: $name"
}

create_or_replace_secret postgres_superuser_password "$POSTGRES_SUPERUSER_PASSWORD"
create_or_replace_secret postgres_warpgate_password "$POSTGRES_WARPGATE_PASSWORD"
create_or_replace_secret postgres_guacamole_password "$POSTGRES_GUACAMOLE_PASSWORD"

echo "OK: Swarm secrets for PostgreSQL ready."
