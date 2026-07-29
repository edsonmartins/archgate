#!/usr/bin/env bash
# Task 1.1 — provision warpgate + guacamole DBs on an existing PostgreSQL
# (no new Postgres container). Runs via local psql or docker exec.
#
# Required env:
#   POSTGRES_HOST POSTGRES_PORT POSTGRES_SUPERUSER POSTGRES_SUPERUSER_PASSWORD
#   POSTGRES_WARPGATE_PASSWORD POSTGRES_GUACAMOLE_PASSWORD
#
# Optional:
#   PSQL_VIA_DOCKER=root-postgres-1@192.168.1.110  # exec psql inside that container via SSH
set -euo pipefail

: "${POSTGRES_WARPGATE_PASSWORD:?}"
: "${POSTGRES_GUACAMOLE_PASSWORD:?}"

sql_escape() {
  printf "%s" "$1" | sed "s/'/''/g"
}

WG_PASS="$(sql_escape "$POSTGRES_WARPGATE_PASSWORD")"
GU_PASS="$(sql_escape "$POSTGRES_GUACAMOLE_PASSWORD")"

SQL=$(cat <<EOSQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'warpgate') THEN
    CREATE ROLE warpgate LOGIN PASSWORD '${WG_PASS}';
  ELSE
    ALTER ROLE warpgate WITH LOGIN PASSWORD '${WG_PASS}';
  END IF;
END
\$\$;

SELECT 'CREATE DATABASE warpgate OWNER warpgate'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'warpgate')\gexec

GRANT ALL PRIVILEGES ON DATABASE warpgate TO warpgate;

DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'guacamole') THEN
    CREATE ROLE guacamole LOGIN PASSWORD '${GU_PASS}';
  ELSE
    ALTER ROLE guacamole WITH LOGIN PASSWORD '${GU_PASS}';
  END IF;
END
\$\$;

SELECT 'CREATE DATABASE guacamole OWNER guacamole'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'guacamole')\gexec

GRANT ALL PRIVILEGES ON DATABASE guacamole TO guacamole;
EOSQL
)

SQL_WG=$(cat <<EOSQL
GRANT ALL ON SCHEMA public TO warpgate;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO warpgate;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO warpgate;
EOSQL
)

SQL_GU=$(cat <<EOSQL
GRANT ALL ON SCHEMA public TO guacamole;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO guacamole;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO guacamole;
EOSQL
)

run_psql() {
  local db="$1"
  local sql="$2"
  if [[ -n "${PSQL_VIA_SSH:-}" && -n "${PSQL_VIA_DOCKER:-}" ]]; then
    # shellcheck disable=SC2029
    ssh -o BatchMode=yes "$PSQL_VIA_SSH" \
      "docker exec -i -e PGPASSWORD=$(printf %q "$POSTGRES_SUPERUSER_PASSWORD") ${PSQL_VIA_DOCKER} \
        psql -v ON_ERROR_STOP=1 -U $(printf %q "$POSTGRES_SUPERUSER") -d $(printf %q "$db")" <<<"$sql"
  else
    : "${POSTGRES_HOST:?}"
    : "${POSTGRES_PORT:?}"
    : "${POSTGRES_SUPERUSER:?}"
    : "${POSTGRES_SUPERUSER_PASSWORD:?}"
    PGPASSWORD="$POSTGRES_SUPERUSER_PASSWORD" psql -v ON_ERROR_STOP=1 \
      -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_SUPERUSER" -d "$db" <<<"$sql"
  fi
}

echo "==> Provisioning roles/databases warpgate + guacamole"
run_psql "${POSTGRES_DB:-postgres}" "$SQL"
run_psql warpgate "$SQL_WG"
run_psql guacamole "$SQL_GU"
echo "OK: external PostgreSQL provisioned for ArchGate."
