#!/usr/bin/env bash
# Provision PostgreSQL role + DB for ArchGuard Console sites SoT (ADR-009 CP-6).
# Uses the same external Postgres as Warpgate/Guacamole.
#
# Required env (bootstrap.env):
#   POSTGRES_HOST POSTGRES_PORT POSTGRES_SUPERUSER POSTGRES_SUPERUSER_PASSWORD
# Optional:
#   CONSOLE_PG_PASSWORD  — if empty, generated and printed once
#   CONSOLE_PG_DB        — default archguard_console
#   CONSOLE_PG_USER      — default archguard_console
set -euo pipefail

: "${POSTGRES_HOST:?}"
: "${POSTGRES_PORT:?}"
: "${POSTGRES_SUPERUSER:?}"
: "${POSTGRES_SUPERUSER_PASSWORD:?}"

CONSOLE_PG_USER="${CONSOLE_PG_USER:-archguard_console}"
CONSOLE_PG_DB="${CONSOLE_PG_DB:-archguard_console}"
if [[ -z "${CONSOLE_PG_PASSWORD:-}" ]]; then
  CONSOLE_PG_PASSWORD="$(openssl rand -base64 24 | tr -d '/+=' | head -c 28)"
  GENERATED=1
else
  GENERATED=0
fi

sql_escape() {
  printf "%s" "$1" | sed "s/'/''/g"
}

PASS_ESC="$(sql_escape "$CONSOLE_PG_PASSWORD")"
USER_ESC="$(sql_escape "$CONSOLE_PG_USER")"
DB_ESC="$(sql_escape "$CONSOLE_PG_DB")"

SQL=$(cat <<EOSQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${USER_ESC}') THEN
    CREATE ROLE ${CONSOLE_PG_USER} LOGIN PASSWORD '${PASS_ESC}';
  ELSE
    ALTER ROLE ${CONSOLE_PG_USER} WITH LOGIN PASSWORD '${PASS_ESC}';
  END IF;
END
\$\$;

SELECT 'CREATE DATABASE ${CONSOLE_PG_DB} OWNER ${CONSOLE_PG_USER}'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${DB_ESC}')\gexec

GRANT ALL PRIVILEGES ON DATABASE ${CONSOLE_PG_DB} TO ${CONSOLE_PG_USER};
EOSQL
)

SQL_DB=$(cat <<EOSQL
GRANT ALL ON SCHEMA public TO ${CONSOLE_PG_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${CONSOLE_PG_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${CONSOLE_PG_USER};
EOSQL
)

run_psql() {
  local db="$1"
  local sql="$2"
  if command -v psql >/dev/null 2>&1; then
    PGPASSWORD="$POSTGRES_SUPERUSER_PASSWORD" psql -v ON_ERROR_STOP=1 \
      -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_SUPERUSER" -d "$db" <<<"$sql"
  else
    docker run --rm --network host \
      -e PGPASSWORD="$POSTGRES_SUPERUSER_PASSWORD" \
      postgres:16-alpine \
      psql -v ON_ERROR_STOP=1 \
      -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_SUPERUSER" -d "$db" <<<"$sql"
  fi
}

echo "==> Provisioning console DB ${CONSOLE_PG_DB} / role ${CONSOLE_PG_USER} @ ${POSTGRES_HOST}:${POSTGRES_PORT}"
run_psql "${POSTGRES_DB:-postgres}" "$SQL"
run_psql "$CONSOLE_PG_DB" "$SQL_DB"

URL="postgresql://${CONSOLE_PG_USER}:${CONSOLE_PG_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${CONSOLE_PG_DB}"
echo "OK: console PostgreSQL ready"
echo "CONSOLE_DATABASE_URL=${URL}"
if [[ "$GENERATED" == "1" ]]; then
  echo "==> Generated password (store in bootstrap.env):"
  echo "CONSOLE_PG_PASSWORD=${CONSOLE_PG_PASSWORD}"
  echo "CONSOLE_DATABASE_URL=${URL}"
fi
