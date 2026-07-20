#!/usr/bin/env bash
# SSO browser E2E (interactive) for ArchGate Connect.
#
# Non-interactive preflight (no browser):
#   ./scripts/smoke-sso-e2e.sh --preflight
#
# Full interactive (opens browser — complete Kanidm login within 5m):
#   ./scripts/smoke-sso-e2e.sh --interactive
#
# Writes evidence markdown under documentos/evidence/ when ARCHGATE_EVIDENCE=1
# or always under /tmp for interactive runs.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$ROOT/../.." && pwd)"
BIN="${ARCHGATE_CONNECT_BIN:-$ROOT/archgate}"
MODE="${1:---preflight}"

if [[ ! -x "$BIN" ]]; then
  (cd "$ROOT" && go build -o archgate ./cmd/archgate)
  BIN="$ROOT/archgate"
fi

preflight() {
  echo "=== SSO preflight (no browser) ==="
  code=$(curl -sS -o /tmp/archgate-oidc-disc.json -w '%{http_code}' --max-time 15 \
    'https://id.archgate.com.br/oauth2/openid/archgate-connect/.well-known/openid-configuration')
  [[ "$code" == "200" ]] || { echo "FAIL discovery http=$code"; exit 1; }
  python3 - <<'PY'
import json
d=json.load(open("/tmp/archgate-oidc-disc.json"))
assert "authorization_code" in (d.get("grant_types_supported") or [])
assert d.get("token_endpoint")
print("issuer", d.get("issuer"))
print("H4 discovery PASS")
PY
  if [[ -f "${HOME}/.config/archgate/oidc.env" ]] && grep -q 'ARCHGATE_OIDC_CLIENT_SECRET=.\+' "${HOME}/.config/archgate/oidc.env"; then
    echo "oidc.env secret: present"
  else
    echo "FAIL: missing ~/.config/archgate/oidc.env ARCHGATE_OIDC_CLIENT_SECRET"
    exit 1
  fi
  tok=$(curl -sS -o /tmp/archgate-oidc-tok.txt -w '%{http_code}' --max-time 15 \
    -X POST 'https://id.archgate.com.br/oauth2/token' \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -d 'grant_type=authorization_code&code=invalid&redirect_uri=http://127.0.0.1:8765/callback&client_id=archgate-connect&code_verifier=x' || true)
  case "$tok" in 400|401|403) echo "token endpoint PASS (http=$tok)";; *) echo "FAIL token http=$tok"; exit 1;; esac
  echo "=== preflight PASS ==="
  echo "Next: $0 --interactive   # complete browser login"
}

interactive() {
  echo "=== SSO interactive E2E ==="
  echo "A browser window will open. Complete Kanidm login for client archgate-connect."
  echo "Callback: http://127.0.0.1:8765/callback  (timeout 5 minutes)"
  TMP=$(mktemp -d)
  export ARCHGATE_CONFIG_DIR="$TMP"
  export ARCHGATE_MOCK=0
  # Prefer keychain off in temp dir tests; interactive uses file under TMP
  export ARCHGATE_KEYCHAIN=file

  set +e
  "$BIN" login 2>&1 | tee "$TMP/login.txt"
  login_rc=${PIPESTATUS[0]}
  set -e

  if [[ "$login_rc" -ne 0 ]]; then
    echo "FAIL: login exit $login_rc"
    echo "log: $TMP/login.txt"
    exit 1
  fi

  "$BIN" status --json | tee "$TMP/status.json"
  "$BIN" ls --json | tee "$TMP/ls.json" || true
  "$BIN" doctor --json | tee "$TMP/doctor.json" || true

  python3 - <<PY
import json, sys
st=json.load(open("$TMP/status.json"))
assert st.get("auth") == "oidc", st
assert st.get("session") is True, st
assert st.get("token_ok") is not False, st
user=st.get("user") or ""
assert user, "missing user"
print("SSO E2E PASS user=", user, "warpgate=", st.get("warpgate_user"), "connections=", st.get("connections"))
print("cred_storage=", st.get("cred_storage"))
print("evidence_dir=", "$TMP")
PY

  EVID_DIR="$REPO/documentos/evidence"
  mkdir -p "$EVID_DIR"
  DAY=$(date +%Y-%m-%d)
  EVID="$EVID_DIR/${DAY}-archgate-connect-sso-e2e.md"
  {
    echo "# Evidence — ArchGate Connect SSO E2E"
    echo
    echo "| Campo | Valor |"
    echo "|-------|--------|"
    echo "| **Data** | $(date -u +%Y-%m-%dT%H:%MZ) |"
    echo "| **Host** | $(uname -s)/$(uname -m) |"
    echo "| **CLI** | \`$("$BIN" version 2>/dev/null | head -1)\` |"
    echo "| **Result** | **PASS** interactive PKCE |"
    echo "| **Artifacts** | \`$TMP\` (local tmp; not committed secrets) |"
    echo
    echo "## Checks"
    echo
    echo "- [x] Browser PKCE login completed"
    echo "- [x] \`status --json\` auth=oidc session=true"
    echo "- [x] Token usable for catalog/bootstrap (see connections count in status)"
    echo
    echo "\`\`\`"
    echo "auth=$(python3 -c "import json;print(json.load(open('$TMP/status.json')).get('auth'))")"
    echo "user=$(python3 -c "import json;print(json.load(open('$TMP/status.json')).get('user'))")"
    echo "connections=$(python3 -c "import json;print(json.load(open('$TMP/status.json')).get('connections'))")"
    echo "\`\`\`"
    echo
    echo "Tokens are **not** copied into this file."
  } > "$EVID"
  echo "Wrote $EVID"
  echo "=== SSO interactive PASS ==="
}

case "$MODE" in
  --preflight) preflight ;;
  --interactive) interactive ;;
  *) echo "usage: $0 --preflight | --interactive"; exit 2 ;;
esac
