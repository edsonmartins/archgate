#!/bin/bash
# Creates isolated databases and roles for Warpgate and Guacamole.
# Runs once on first PostgreSQL container start (docker-entrypoint-initdb.d).
# Passwords: Docker secrets or env POSTGRES_WARPGATE_PASSWORD / POSTGRES_GUACAMOLE_PASSWORD.
set -euo pipefail

if [[ -f /run/secrets/postgres_warpgate_password ]]; then
  POSTGRES_WARPGATE_PASSWORD="$(tr -d '\n' < /run/secrets/postgres_warpgate_password)"
fi
if [[ -f /run/secrets/postgres_guacamole_password ]]; then
  POSTGRES_GUACAMOLE_PASSWORD="$(tr -d '\n' < /run/secrets/postgres_guacamole_password)"
fi

: "${POSTGRES_WARPGATE_PASSWORD:?Set POSTGRES_WARPGATE_PASSWORD or secret postgres_warpgate_password}"
: "${POSTGRES_GUACAMOLE_PASSWORD:?Set POSTGRES_GUACAMOLE_PASSWORD or secret postgres_guacamole_password}"

# Escape single quotes for SQL string literals
sql_escape() {
  printf "%s" "$1" | sed "s/'/''/g"
}

WG_PASS="$(sql_escape "$POSTGRES_WARPGATE_PASSWORD")"
GU_PASS="$(sql_escape "$POSTGRES_GUACAMOLE_PASSWORD")"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<EOSQL
-- Warpgate (ADR-003: external PostgreSQL, never SQLite in production)
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'warpgate') THEN
    CREATE ROLE warpgate LOGIN PASSWORD '${WG_PASS}';
  END IF;
END
\$\$;

SELECT 'CREATE DATABASE warpgate OWNER warpgate'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'warpgate')\gexec

GRANT ALL PRIVILEGES ON DATABASE warpgate TO warpgate;

-- Guacamole
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'guacamole') THEN
    CREATE ROLE guacamole LOGIN PASSWORD '${GU_PASS}';
  END IF;
END
\$\$;

SELECT 'CREATE DATABASE guacamole OWNER guacamole'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'guacamole')\gexec

GRANT ALL PRIVILEGES ON DATABASE guacamole TO guacamole;
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname warpgate <<EOSQL
GRANT ALL ON SCHEMA public TO warpgate;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO warpgate;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO warpgate;
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname guacamole <<EOSQL
GRANT ALL ON SCHEMA public TO guacamole;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO guacamole;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO guacamole;
EOSQL

echo "ArchGate: databases warpgate and guacamole ready."
