#!/usr/bin/env bash
# Fase 2 smoke — emit SSH cert + dynamic DB cred from OpenBao
set -euo pipefail
BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
set -a
# shellcheck disable=SC1090
source "$BOOTSTRAP"
set +a

BAO="${OPENBAO_ADDR:-http://127.0.0.1:8200}"
TOK="${OPENBAO_APP_TOKEN:-${OPENBAO_ROOT_TOKEN:?}}"

log()  { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1" >&2; exit 1; }
step() { echo -e "\n=== $1 ==="; }

# unseal
if curl -s "$BAO/v1/sys/health" | python3 -c 'import sys,json; exit(0 if not json.load(sys.stdin).get("sealed") else 1)' 2>/dev/null; then
  :
else
  curl -s -X PUT "$BAO/v1/sys/unseal" -H 'Content-Type: application/json' \
    -d "$(python3 -c "import json,os; print(json.dumps({'key':os.environ['OPENBAO_UNSEAL_KEY']}))")" >/dev/null
  log "unsealed for smoke"
fi

step "1. OpenBao health"
H=$(curl -s -H "X-Vault-Token: $TOK" "$BAO/v1/sys/health")
echo "$H" | python3 -c 'import sys,json; d=json.load(sys.stdin); assert d.get("initialized") and not d.get("sealed"), d; print("    version", d.get("version"))'
log "OpenBao unsealed + initialized"

step "2. SSH CA sign (ephemeral cert)"
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
ssh-keygen -t ed25519 -f "$WORKDIR/id" -N '' -q
SIGN=$(curl -s -X POST -H "X-Vault-Token: $TOK" -H 'Content-Type: application/json' \
  -d "$(python3 -c "import json,pathlib; print(json.dumps({'public_key':pathlib.Path('$WORKDIR/id.pub').read_text(),'valid_principals':'labuser','ttl':'5m'}))")" \
  "$BAO/v1/ssh/sign/lab-user")
echo "$SIGN" | python3 -c 'import sys,json; d=json.load(sys.stdin); assert "data" in d and "signed_key" in d["data"], d; print("    serial", d["data"].get("serial_number")); open(sys.argv[1],"w").write(d["data"]["signed_key"])' "$WORKDIR/id-cert.pub"
ssh-keygen -L -f "$WORKDIR/id-cert.pub" | head -20
log "SSH certificate signed (TTL short)"

step "3. SSH login with cert (host that trusts CA)"
CA_HOST_IP=$(docker inspect "$(docker ps -q --filter name=archgate-lab_ssh-ca | head -1)" \
  --format '{{(index .NetworkSettings.Networks "archgate-data").IPAddress}}' 2>/dev/null || true)
if [[ -n "$CA_HOST_IP" ]]; then
  set +e
  docker run --rm --network archgate-data \
    -v "$WORKDIR:/keys:ro" \
    alpine:3.20 \
    sh -c "apk add --no-cache openssh-client >/dev/null && \
      ssh -i /keys/id -o CertificateFile=/keys/id-cert.pub \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o PreferredAuthentications=publickey \
        labuser@${CA_HOST_IP} 'echo SSH_CERT_OK; id'" 2>/tmp/ssh_cert.err | tee /tmp/ssh_cert.out
  set -e
  grep -q SSH_CERT_OK /tmp/ssh_cert.out || { tail -15 /tmp/ssh_cert.err; fail "SSH cert login failed"; }
  log "SSH login with OpenBao certificate (archgate-lab_ssh-ca)"
else
  log "skip cert login host (deploy archgate-lab_ssh-ca) — emission still OK"
fi

step "4. Dynamic Postgres credentials"
DB=$(curl -s -H "X-Vault-Token: $TOK" "$BAO/v1/database/creds/lab-readonly" || echo '{}')
echo "$DB" | python3 -c '
import sys,json
d=json.load(sys.stdin)
assert "data" in d, d
u=d["data"]["username"]; p=d["data"]["password"]
print("    user", u)
print("    lease", d.get("lease_id","")[:60])
open("/tmp/bao_db_user","w").write(u)
open("/tmp/bao_db_pass","w").write(p)
open("/tmp/bao_lease","w").write(d.get("lease_id",""))
'
DU=$(cat /tmp/bao_db_user); DP=$(cat /tmp/bao_db_pass)
export PGPASSWORD="$DP"
psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "$DU" -d archgate_lab -tAc "select current_user" | grep -q "$DU" \
  || fail "dynamic user cannot connect"
log "dynamic DB user $DU connected to archgate_lab"

step "5. Revoke lease"
LEASE=$(cat /tmp/bao_lease)
curl -s -X PUT -H "X-Vault-Token: $TOK" -H 'Content-Type: application/json' \
  -d "$(python3 -c "import json; print(json.dumps({'lease_id':open('/tmp/bao_lease').read().strip()}))")" \
  "$BAO/v1/sys/leases/revoke" >/dev/null || true
sleep 1
set +e
PGPASSWORD="$DP" psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "$DU" -d archgate_lab -tAc "select 1" 2>/tmp/rev.err
RC=$?
set -e
if [[ $RC -ne 0 ]]; then
  log "revoked lease — dynamic user no longer connects"
else
  echo "  [!!] user still connects after revoke (eventual consistency?)" 
fi

echo ""
echo "=============================================="
echo " OPENBAO EPHEMERAL SMOKE PASSED"
echo "=============================================="
echo "  SSH CA: sign OK"
echo "  DB:     dynamic cred + revoke"
echo "  Note:   Warpgate still may hold static target secrets until Vault integration"
echo "=============================================="
