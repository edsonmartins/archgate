#!/usr/bin/env bash
# Install ArchGate Connect CLI on this Mac/Linux workstation.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "=== ArchGate Connect install ==="
if ! command -v go >/dev/null 2>&1; then
  echo "Go is required: https://go.dev/dl/" >&2
  exit 1
fi

go test ./...
go build -o archgate ./cmd/archgate

BIN_DIR="${ARCHGATE_BIN_DIR:-$HOME/.local/bin}"
mkdir -p "$BIN_DIR"
cp -f archgate "$BIN_DIR/archgate"
chmod 755 "$BIN_DIR/archgate"

CFG="$HOME/.config/archgate"
mkdir -p "$CFG"
chmod 700 "$CFG"

if [[ ! -f "$CFG/oidc.env" ]]; then
  cat > "$CFG/oidc.env.example" <<'EOF'
# Copy to oidc.env (chmod 600) — secret from platform ops / bootstrap
export ARCHGATE_OIDC_CLIENT_ID=archgate-connect
export ARCHGATE_OIDC_ISSUER=https://id.archgate.com.br/oauth2/openid/archgate-connect
export ARCHGATE_OIDC_CLIENT_SECRET=
export ARCHGATE_API_BASE=https://console.archgate.com.br/api
EOF
  echo "Wrote $CFG/oidc.env.example — fill oidc.env with client secret"
fi

echo
echo "Installed: $BIN_DIR/archgate"
if ! echo ":$PATH:" | grep -q ":$BIN_DIR:"; then
  echo "Add to PATH, e.g.:"
  echo "  export PATH=\"$BIN_DIR:\$PATH\""
fi
echo
echo "Quick start:"
echo "  archgate login --lab --user seu.user   # homolog API lab"
echo "  archgate login                         # SSO browser (needs oidc.env)"
echo "  archgate ls"
echo "  archgate ssh rio-aws-api-b"
echo "  archgate config apply"
echo
echo "Desktop (optional):"
echo "  cd desktop && npm install && npm run tauri:dev"
echo "=== OK ==="
