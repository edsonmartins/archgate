#!/usr/bin/env bash
# Enable SSH CA + Postgres dynamic + audit + minimal policy (Fase 2 lab)
set -euo pipefail

BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
set -a
# shellcheck disable=SC1090
source "$BOOTSTRAP"
set +a

: "${OPENBAO_ROOT_TOKEN:?}"
: "${POSTGRES_HOST:?}"
: "${POSTGRES_PORT:?}"
BAO="${OPENBAO_ADDR:-http://127.0.0.1:8200}"
TOK="$OPENBAO_ROOT_TOKEN"

bao() {
  local method="$1" path="$2" data="${3:-}"
  if [[ -n "$data" ]]; then
    curl -sk -X "$method" -H "X-Vault-Token: $TOK" -H "Content-Type: application/json" \
      -d "$data" "${BAO}/v1/${path}"
  else
    curl -sk -X "$method" -H "X-Vault-Token: $TOK" "${BAO}/v1/${path}"
  fi
}

log()  { echo "  [OK] $1"; }
warn() { echo "  [!!] $1"; }

# Unseal if needed
SEALED=$(curl -s "$BAO/v1/sys/health" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("sealed",True))' 2>/dev/null || echo true)
if [[ "$SEALED" == "True" || "$SEALED" == "true" ]]; then
  curl -s -X PUT "$BAO/v1/sys/unseal" -H 'Content-Type: application/json' \
    -d "$(python3 -c "import json,os; print(json.dumps({'key':os.environ['OPENBAO_UNSEAL_KEY']}))")" >/dev/null
  log "unsealed"
fi

echo "=== audit ==="
bao PUT sys/audit/file '{"type":"file","options":{"file_path":"/openbao/audit/audit.log"}}' >/dev/null 2>&1 || true
log "audit device file (or already enabled)"

echo "=== SSH secrets engine ==="
bao POST sys/mounts/ssh '{"type":"ssh"}' >/dev/null 2>&1 || true
bao POST ssh/config/ca '{"generate_signing_key":true}' >/dev/null 2>&1 || true
CA_PUB=$(bao GET ssh/config/ca | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["public_key"])')
echo "$CA_PUB" > /var/lib/archgate/openbao/ssh_ca.pub
chmod 644 /var/lib/archgate/openbao/ssh_ca.pub
log "SSH CA public key → /var/lib/archgate/openbao/ssh_ca.pub"

# Role: sign user certs for labuser (and wildcard principals)
bao POST ssh/roles/lab-user "$(python3 - <<'PY'
import json
print(json.dumps({
  "key_type": "ca",
  "allow_user_certificates": True,
  "allowed_users": "labuser",
  "default_user": "labuser",
  "ttl": "15m",
  "max_ttl": "30m",
  "allow_user_key_ids": True,
  "default_extensions": [{"permit-pty": ""}],
  "allowed_extensions": "permit-pty,permit-port-forwarding",
}))
PY
)" >/dev/null
log "SSH role lab-user (TTL 15m)"

echo "=== Database secrets engine (Postgres lab) ==="
# Need a superuser/admin for dynamic users on archgate_lab DB
# Use postgres superuser if available, else create openbao_admin
# Prefer cluster superuser from bootstrap
ADMIN_U=""; ADMIN_P=""
for attempt in \
  "${POSTGRES_SUPERUSER:-postgres}:${POSTGRES_SUPERUSER_PASSWORD:-}" \
  "postgres:${POSTGRES_ADMIN_PASSWORD:-}" \
  "postgres:${POSTGRES_SUPERUSER_PASSWORD:-}" \
  "warpgate:${POSTGRES_WARPGATE_PASSWORD:-}"; do
  U="${attempt%%:*}"; P="${attempt#*:}"
  [[ -z "$P" || -z "$U" ]] && continue
  if PGPASSWORD="$P" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$U" -d postgres -tAc 'select 1' >/dev/null 2>&1; then
    ADMIN_U="$U"; ADMIN_P="$P"
    log "postgres admin probe ok as $U"
    break
  fi
done

if [[ -z "${ADMIN_U:-}" ]]; then
  echo "  [!!] no postgres admin — skip database engine (set POSTGRES_ADMIN_PASSWORD)"
else
  PGPASSWORD="$ADMIN_P" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$ADMIN_U" -d postgres -v ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'openbao_admin') THEN
    CREATE ROLE openbao_admin LOGIN PASSWORD 'OpenBaoLabAdmin2026!';
  ELSE
    ALTER ROLE openbao_admin WITH LOGIN PASSWORD 'OpenBaoLabAdmin2026!';
  END IF;
END
\$\$;
GRANT CONNECT ON DATABASE archgate_lab TO openbao_admin;
SQL
  PGPASSWORD="$ADMIN_P" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$ADMIN_U" -d archgate_lab -v ON_ERROR_STOP=1 <<'SQL'
GRANT CREATE ON DATABASE archgate_lab TO openbao_admin;
GRANT USAGE, CREATE ON SCHEMA public TO openbao_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO openbao_admin;
-- openbao needs CREATEROLE-ish: use SUPERUSER only in lab if needed
SQL
  # Lab: grant createrole via superuser
  PGPASSWORD="$ADMIN_P" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$ADMIN_U" -d postgres -c \
    "ALTER ROLE openbao_admin CREATEROLE;" 2>/dev/null || \
  PGPASSWORD="$ADMIN_P" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$ADMIN_U" -d postgres -c \
    "ALTER ROLE openbao_admin WITH SUPERUSER;" 2>/dev/null || true

  bao POST sys/mounts/database '{"type":"database"}' >/dev/null 2>&1 || true
  bao POST database/config/archgate-lab "$(python3 - <<PY
import json
print(json.dumps({
  "plugin_name": "postgresql-database-plugin",
  "allowed_roles": "lab-readonly",
  "connection_url": "postgresql://{{username}}:{{password}}@${POSTGRES_HOST}:${POSTGRES_PORT}/archgate_lab?sslmode=disable",
  "username": "openbao_admin",
  "password": "OpenBaoLabAdmin2026!",
}))
PY
)" >/dev/null
  bao POST database/roles/lab-readonly "$(python3 - <<'PY'
import json
print(json.dumps({
  "db_name": "archgate-lab",
  "creation_statements": [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT CONNECT ON DATABASE archgate_lab TO \"{{name}}\";",
    "GRANT USAGE ON SCHEMA public TO \"{{name}}\";",
    "GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
  ],
  "default_ttl": "30m",
  "max_ttl": "2h",
}))
PY
)" >/dev/null
  log "database role lab-readonly (TTL 30m)"
  grep -v '^OPENBAO_DB_ADMIN_PASSWORD=' "$BOOTSTRAP" > /tmp/bs.bao2 || true
  mv /tmp/bs.bao2 "$BOOTSTRAP"
  echo "OPENBAO_DB_ADMIN_PASSWORD=OpenBaoLabAdmin2026!" >> "$BOOTSTRAP"
  chmod 600 "$BOOTSTRAP"
fi

echo "=== policy archgate-operator-ephemeral ==="
bao PUT sys/policy/archgate-operator-ephemeral "$(python3 - <<'PY'
import json
policy = '''
path "ssh/sign/lab-user" {
  capabilities = ["create", "update"]
}
path "database/creds/lab-readonly" {
  capabilities = ["read"]
}
path "sys/leases/*" {
  capabilities = ["update"]
}
'''
print(json.dumps({"policy": policy}))
PY
)" >/dev/null
log "policy archgate-operator-ephemeral"

# Token for automation (not root)
TOKEN_OUT=$(bao POST auth/token/create "$(python3 - <<'PY'
import json
print(json.dumps({
  "policies": ["archgate-operator-ephemeral"],
  "ttl": "720h",
  "display_name": "archgate-lab-ephemeral",
  "renewable": True,
}))
PY
)")
APP_TOKEN=$(echo "$TOKEN_OUT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["auth"]["client_token"])' 2>/dev/null || true)
if [[ -n "$APP_TOKEN" ]]; then
  grep -v '^OPENBAO_APP_TOKEN=' "$BOOTSTRAP" > /tmp/bs.bao3 || true
  mv /tmp/bs.bao3 "$BOOTSTRAP"
  echo "OPENBAO_APP_TOKEN=${APP_TOKEN}" >> "$BOOTSTRAP"
  chmod 600 "$BOOTSTRAP"
  log "OPENBAO_APP_TOKEN written (policy-limited)"
fi

echo "=== trust CA on site piloto SSH (if running) ==="
if docker ps -q --filter name=archgate-site-piloto_ssh | head -1 | grep -q .; then
  CID=$(docker ps -q --filter name=archgate-site-piloto_ssh | head -1)
  # linuxserver image: inject trusted CA via custom — often /config/sshd/ or modify
  docker cp /var/lib/archgate/openbao/ssh_ca.pub "$CID:/tmp/ssh_ca.pub" || true
  docker exec "$CID" sh -c '
    mkdir -p /config/sshd /etc/ssh
    cp /tmp/ssh_ca.pub /etc/ssh/archgate_ca.pub 2>/dev/null || true
    if ! grep -q TrustedUserCAKeys /etc/ssh/sshd_config 2>/dev/null; then
      echo "TrustedUserCAKeys /etc/ssh/archgate_ca.pub" >> /etc/ssh/sshd_config
    fi
    # linuxserver may use /config
    mkdir -p /config
    cp /tmp/ssh_ca.pub /config/archgate_ca.pub 2>/dev/null || true
    pkill -HUP sshd 2>/dev/null || true
  ' 2>/dev/null || warn "could not inject CA into piloto ssh"
  log "attempted CA trust on piloto ssh"
else
  echo "  [!!] piloto ssh not running — skip CA inject"
fi

echo "DONE: OpenBao engines bootstrapped"
echo "  CA pub: /var/lib/archgate/openbao/ssh_ca.pub"
echo "  next: bash deploy/openbao/smoke-ephemeral.sh"
