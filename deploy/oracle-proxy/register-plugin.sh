#!/usr/bin/env bash
# Register openbao-oracle-plugin in OpenBao catalog (lab/prod).
# Usage:
#   PLUGIN_BIN=/path/to/openbao-oracle-plugin BAO_ADDR=https://... BAO_TOKEN=... ./register-plugin.sh
set -euo pipefail

PLUGIN_BIN="${PLUGIN_BIN:-./openbao-oracle-plugin}"
PLUGIN_NAME="${PLUGIN_NAME:-oracle-archgate}"
BAO="${BAO_ADDR:-${OPENBAO_ADDR:-http://127.0.0.1:8200}}"
TOKEN="${BAO_TOKEN:-${OPENBAO_TOKEN:-${OPENBAO_ROOT_TOKEN:-}}}"
PROXY_URL="${ORACLE_PROXY_URL:-http://oracle-proxy:9040}"

if [[ ! -x "$PLUGIN_BIN" && ! -f "$PLUGIN_BIN" ]]; then
  echo "Build plugin first: (cd services/openbao-oracle-plugin && go build -o openbao-oracle-plugin .)" >&2
  exit 1
fi
if [[ -z "$TOKEN" ]]; then
  echo "BAO_TOKEN / OPENBAO_TOKEN required" >&2
  exit 1
fi

SHA=$(shasum -a 256 "$PLUGIN_BIN" | awk '{print $1}')
echo "sha256=$SHA"

# Copy into OpenBao plugin_directory if PLUGIN_DIR set
if [[ -n "${PLUGIN_DIR:-}" ]]; then
  install -m 0755 "$PLUGIN_BIN" "$PLUGIN_DIR/openbao-oracle-plugin"
  echo "Installed to $PLUGIN_DIR/openbao-oracle-plugin"
fi

export VAULT_ADDR="$BAO"
export BAO_ADDR="$BAO"
export VAULT_TOKEN="$TOKEN"
export BAO_TOKEN="$TOKEN"

if command -v bao >/dev/null 2>&1; then
  CLI=bao
elif command -v vault >/dev/null 2>&1; then
  CLI=vault
else
  echo "bao or vault CLI required" >&2
  exit 1
fi

$CLI write "sys/plugins/catalog/database/${PLUGIN_NAME}" \
  sha256="$SHA" \
  command=openbao-oracle-plugin

echo "Registered plugin ${PLUGIN_NAME}. Configure connection:"
echo "  $CLI write database/config/oracle-consico \\"
echo "    plugin_name=${PLUGIN_NAME} \\"
echo "    allowed_roles=oracle-readonly \\"
echo "    url=${PROXY_URL} \\"
echo "    username=unused password=unused"
echo "See openbao-oracle.example.hcl for roles + JWT policy sketch."
