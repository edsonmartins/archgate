#!/usr/bin/env bash
# Validates task 1.1: warpgate and guacamole databases/roles exist and accept login.
set -euo pipefail

HOST="${POSTGRES_HOST:-127.0.0.1}"
PORT="${POSTGRES_PORT:-5432}"
SUPERUSER="${POSTGRES_SUPERUSER:-archgate}"
: "${POSTGRES_SUPERUSER_PASSWORD:?Set POSTGRES_SUPERUSER_PASSWORD}"
: "${POSTGRES_WARPGATE_PASSWORD:?Set POSTGRES_WARPGATE_PASSWORD}"
: "${POSTGRES_GUACAMOLE_PASSWORD:?Set POSTGRES_GUACAMOLE_PASSWORD}"

export PGPASSWORD="$POSTGRES_SUPERUSER_PASSWORD"

echo "==> Checking superuser connectivity on ${HOST}:${PORT}"
psql -h "$HOST" -p "$PORT" -U "$SUPERUSER" -d archgate -c 'SELECT version();' >/dev/null

echo "==> Checking databases warpgate and guacamole"
psql -h "$HOST" -p "$PORT" -U "$SUPERUSER" -d archgate -tAc \
  "SELECT datname FROM pg_database WHERE datname IN ('warpgate','guacamole') ORDER BY 1;" \
  | tr -d ' ' | grep -qx warpgate
psql -h "$HOST" -p "$PORT" -U "$SUPERUSER" -d archgate -tAc \
  "SELECT datname FROM pg_database WHERE datname IN ('warpgate','guacamole') ORDER BY 1;" \
  | tr -d ' ' | grep -qx guacamole

echo "==> Checking role login: warpgate"
export PGPASSWORD="$POSTGRES_WARPGATE_PASSWORD"
psql -h "$HOST" -p "$PORT" -U warpgate -d warpgate -c 'SELECT current_user, current_database();' >/dev/null

echo "==> Checking role login: guacamole"
export PGPASSWORD="$POSTGRES_GUACAMOLE_PASSWORD"
psql -h "$HOST" -p "$PORT" -U guacamole -d guacamole -c 'SELECT current_user, current_database();' >/dev/null

echo "OK: PostgreSQL externo validado (schemas/DBs warpgate + guacamole)."
