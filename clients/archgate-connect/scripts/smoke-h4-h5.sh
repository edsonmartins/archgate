#!/usr/bin/env bash
# H4 OIDC preflight + H5 live lab smoke for ArchGate Connect.
# Usage:
#   ./scripts/smoke-h4-h5.sh
#   ./scripts/smoke-h4-h5.sh --h4-only
#   ./scripts/smoke-h4-h5.sh --h5-only
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${ARCHGATE_CONNECT_BIN:-$ROOT/archgate}"
MODE="${1:-all}"

if [[ ! -x "$BIN" ]]; then
  (cd "$ROOT" && go build -o archgate ./cmd/archgate)
  BIN="$ROOT/archgate"
fi

h4() {
  echo "=== H4 OIDC preflight ==="
  local code
  code=$(curl -sS -o /tmp/archgate-oidc-disc.json -w '%{http_code}' --max-time 15 \
    'https://id.archgate.com.br/oauth2/openid/archgate-connect/.well-known/openid-configuration')
  [[ "$code" == "200" ]] || { echo "FAIL discovery http=$code"; exit 1; }
  python3 - <<'PY'
import json
d=json.load(open("/tmp/archgate-oidc-disc.json"))
assert d.get("authorization_endpoint"), d
assert d.get("token_endpoint"), d
assert "authorization_code" in (d.get("grant_types_supported") or [])
print("issuer", d.get("issuer"))
print("device_code", bool(d.get("device_authorization_endpoint")))
print("H4 discovery PASS")
PY
  if [[ -f "${HOME}/.config/archgate/oidc.env" ]] && grep -q 'ARCHGATE_OIDC_CLIENT_SECRET=.\+' "${HOME}/.config/archgate/oidc.env"; then
    echo "H4 oidc.env secret: present"
  else
    echo "WARN: ~/.config/archgate/oidc.env missing or empty ARCHGATE_OIDC_CLIENT_SECRET (SSO browser will fail)"
  fi
  local tok
  tok=$(curl -sS -o /tmp/archgate-oidc-tok.txt -w '%{http_code}' --max-time 15 \
    -X POST 'https://id.archgate.com.br/oauth2/token' \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -d 'grant_type=authorization_code&code=invalid&redirect_uri=http://127.0.0.1:8765/callback&client_id=archgate-connect&code_verifier=x' || true)
  case "$tok" in
    400|401|403) echo "H4 token endpoint PASS (http=$tok)";;
    *) echo "FAIL token endpoint http=$tok"; exit 1;;
  esac
  echo "=== H4 preflight PASS (interactive SSO not included) ==="
}

h5() {
  echo "=== H5 live lab (ARCHGATE_MOCK=0) ==="
  local tmp
  tmp=$(mktemp -d)
  export ARCHGATE_CONFIG_DIR="$tmp"
  export ARCHGATE_MOCK=0
  "$BIN" login --lab --user "smoke.h5"
  "$BIN" status --json | tee "$tmp/status.json"
  "$BIN" ls --json | tee "$tmp/ls.json"
  "$BIN" doctor --json | tee "$tmp/doctor.json"
  "$BIN" print-ssh rio-lab-ssh | tee "$tmp/print-ssh.txt"
  "$BIN" logout
  LIVE_TMP="$tmp" python3 - <<'PY'
import json, os, re
tmp = os.environ["LIVE_TMP"]
st = json.load(open(f"{tmp}/status.json"))
doc = json.load(open(f"{tmp}/doctor.json"))
ls = json.load(open(f"{tmp}/ls.json"))
ssh = open(f"{tmp}/print-ssh.txt").read()
assert st.get("session") is True
assert st.get("auth") == "lab"
assert st.get("mock") is False
assert (st.get("connections") or 0) >= 1 or len(ls.get("connections") or []) >= 1
checks = {c["name"]: c for c in doc.get("checks", [])}
assert checks["auth"]["ok"]
assert checks["ssh_bastion"]["ok"], checks.get("ssh_bastion")
assert "ssh -p" in ssh
assert "@" in ssh
for c in ls.get("connections") or []:
    blob = json.dumps(c)
    assert "10.0." not in blob and "192.168." not in blob, c
print("H5 live lab PASS")
print("  connections", len(ls.get("connections") or []))
print("  warpgate_user", st.get("warpgate_user"))
print("  ssh", checks["ssh_bastion"]["detail"])
print("  evidence_dir", tmp)
PY
}

case "$MODE" in
  --h4-only) h4 ;;
  --h5-only) h5 ;;
  all|"") h4; h5 ;;
  *) echo "usage: $0 [--h4-only|--h5-only]"; exit 2 ;;
esac
