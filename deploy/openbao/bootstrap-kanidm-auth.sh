#!/usr/bin/env bash
# OpenBao JWT auth ← Kanidm OIDC (Fase 2 task 5.3)
set -euo pipefail

BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
DOMAIN="${KANIDM_DOMAIN:-id.archgate.com.br}"
CLIENT_ID="${OPENBAO_OIDC_CLIENT_ID:-openbao}"
CONSOLE_ORIGIN="${OPENBAO_OIDC_ORIGIN:-https://console.archgate.com.br}"
REDIRECT_LOCAL="${OPENBAO_OIDC_REDIRECT:-http://127.0.0.1:8250/oidc/callback}"
TOOLS="${KANIDM_TOOLS_IMAGE:-kanidm/tools:1.10.4}"
BAO="${OPENBAO_ADDR:-http://127.0.0.1:8200}"
DATA="${OPENBAO_DATA:-/var/lib/archgate/openbao}"

set -a
# shellcheck disable=SC1090
source "$BOOTSTRAP"
set +a

: "${OPENBAO_ROOT_TOKEN:?}"
: "${KANIDM_IDM_ADMIN_PASSWORD:?}"

log() { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1" >&2; exit 1; }

if ! curl -s "$BAO/v1/sys/health" | python3 -c 'import sys,json; d=json.load(sys.stdin); sys.exit(0 if not d.get("sealed") else 1)' 2>/dev/null; then
  curl -s -X PUT "$BAO/v1/sys/unseal" -H 'Content-Type: application/json' \
    -d "$(python3 -c "import json,os; print(json.dumps({'key':os.environ['OPENBAO_UNSEAL_KEY']}))")" >/dev/null
  log "unsealed"
fi

bao() {
  local method="$1" path="$2" data="${3:-}"
  if [[ -n "$data" ]]; then
    curl -s -X "$method" -H "X-Vault-Token: $OPENBAO_ROOT_TOKEN" -H "Content-Type: application/json" \
      -d "$data" "${BAO}/v1/${path}"
  else
    curl -s -X "$method" -H "X-Vault-Token: $OPENBAO_ROOT_TOKEN" "${BAO}/v1/${path}"
  fi
}

echo "=== 1. Kanidm OAuth2 client ${CLIENT_ID} ==="
TOKENS=$(mktemp)
trap 'rm -f "$TOKENS"' EXIT
expect <<EOF >/dev/null
set timeout 60
spawn docker run --rm -it --network host -v ${TOKENS}:/root/.cache/kanidm_tokens -e KANIDM_URL=https://127.0.0.1:8443 ${TOOLS} /sbin/kanidm login --accept-invalid-certs --name idm_admin
expect -re "password:"
send "${KANIDM_IDM_ADMIN_PASSWORD}\r"
expect eof
EOF
kcli() {
  docker run --rm --network host -v "${TOKENS}:/root/.cache/kanidm_tokens" \
    -e "KANIDM_URL=https://127.0.0.1:8443" "$TOOLS" /sbin/kanidm "$@" \
    --accept-invalid-certs --name idm_admin 2>&1 | grep -v WARN || true
}
kcli system oauth2 create-public "$CLIENT_ID" "ArchGate OpenBao" "$CONSOLE_ORIGIN" >/dev/null 2>&1 || true
kcli system oauth2 set-landing-url "$CLIENT_ID" "$CONSOLE_ORIGIN" || true
kcli system oauth2 add-redirect-url "$CLIENT_ID" "$REDIRECT_LOCAL" || true
kcli system oauth2 add-redirect-url "$CLIENT_ID" "http://127.0.0.1:8250/callback" || true
kcli system oauth2 update-scope-map "$CLIENT_ID" archguard_users openid profile email groups || true
kcli system oauth2 prefer-short-username "$CLIENT_ID" || true
log "Kanidm client $CLIENT_ID"

ISSUER="https://${DOMAIN}/oauth2/openid/${CLIENT_ID}"

echo "=== 2. Import Kanidm OIDC public key (lab: avoid OpenBao TLS to discovery) ==="
mkdir -p "$DATA"
python3 <<PY
import json,ssl,urllib.request,base64
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend
ctx=ssl._create_unverified_context()
jwks=json.loads(urllib.request.urlopen("${ISSUER}/public_key.jwk", context=ctx).read())
k=jwks["keys"][0]
def b64url_to_int(s):
    s+="="*((4-len(s)%4)%4)
    return int.from_bytes(base64.urlsafe_b64decode(s),"big")
pub=ec.EllipticCurvePublicNumbers(b64url_to_int(k["x"]), b64url_to_int(k["y"]), ec.SECP256R1()).public_key(default_backend())
pem=pub.public_bytes(serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo).decode()
open("${DATA}/kanidm_oidc.pem","w").write(pem)
print(pem[:60],"...")
PY
log "PEM saved ${DATA}/kanidm_oidc.pem"

echo "=== 3. OpenBao auth/jwt ==="
bao POST sys/auth/jwt '{"type":"jwt","description":"Kanidm OIDC"}' >/dev/null 2>&1 || true
PEM=$(cat "${DATA}/kanidm_oidc.pem")
bao POST auth/jwt/config "$(python3 -c "
import json
print(json.dumps({
  'bound_issuer': '''$ISSUER''',
  'jwt_validation_pubkeys': [open('''$DATA/kanidm_oidc.pem''').read()],
  'jwt_supported_algs': ['ES256'],
  'default_role': 'archgate-operator',
}))
")" >/dev/null
log "jwt config (issuer + ES256 pubkey)"

# Kanidm OIDC "groups" claim uses full SPNs (name@domain), not short names
GROUP_USERS="${OPENBAO_BOUND_GROUP_USERS:-archguard_users@${DOMAIN}}"
GROUP_ADMINS="${OPENBAO_BOUND_GROUP_ADMINS:-archguard_super_admins@${DOMAIN}}"

bao POST auth/jwt/role/archgate-operator "$(python3 - <<PY
import json
print(json.dumps({
  "role_type": "jwt",
  "user_claim": "preferred_username",
  "groups_claim": "groups",
  "bound_audiences": ["$CLIENT_ID"],
  "bound_claims": {"groups": "$GROUP_USERS"},
  "claim_mappings": {"preferred_username": "kanidm_username", "email": "email"},
  "policies": ["archgate-operator-ephemeral"],
  "ttl": "30m",
  "max_ttl": "2h",
  "clock_skew_leeway": 120,
}))
PY
)" >/dev/null
log "role archgate-operator (groups=${GROUP_USERS} → ephemeral policy)"

bao POST auth/jwt/role/archgate-admin "$(python3 - <<PY
import json
print(json.dumps({
  "role_type": "jwt",
  "user_claim": "preferred_username",
  "groups_claim": "groups",
  "bound_audiences": ["$CLIENT_ID"],
  "bound_claims": {"groups": "$GROUP_ADMINS"},
  "policies": ["archgate-operator-ephemeral"],
  "ttl": "1h",
  "max_ttl": "4h",
  "clock_skew_leeway": 120,
}))
PY
)" >/dev/null 2>&1 || true

grep -vE '^OPENBAO_OIDC_CLIENT_ID=|^OPENBAO_OIDC_ISSUER=|^OPENBAO_OIDC_REDIRECT=' "$BOOTSTRAP" > /tmp/bs.jwt || true
mv /tmp/bs.jwt "$BOOTSTRAP"
{
  echo "OPENBAO_OIDC_CLIENT_ID=${CLIENT_ID}"
  echo "OPENBAO_OIDC_ISSUER=${ISSUER}"
  echo "OPENBAO_OIDC_REDIRECT=${REDIRECT_LOCAL}"
} >> "$BOOTSTRAP"
chmod 600 "$BOOTSTRAP"

# Ensure OpenBao can reach IdP later if discovery re-enabled
docker service update --host-add "${DOMAIN}:192.168.1.180" archgate-secrets_openbao >/dev/null 2>&1 || true

echo "DONE: OpenBao JWT ← Kanidm"
echo "  next: bash deploy/openbao/smoke-kanidm-jwt.sh"
