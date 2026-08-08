#!/usr/bin/env bash
# W5-AG01 — Bootstrap service account OpenSRE no archguard (idempotent intent)
# DRY_RUN=1 only prints actions (default if no bootstrap.env / tools).
set -euo pipefail

SA_NAME="${OPENSRE_SA:-sa-opensre}"
SA_GROUP="${OPENSRE_GROUP:-archgate_agents}"
DOMAIN="${archguard_DOMAIN:-id.archgate.com.br}"
BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
DRY_RUN="${DRY_RUN:-}"

log() { echo "  [OK] $1"; }
info() { echo "  → $1"; }
fail() { echo "  [FAIL] $1" >&2; exit 1; }

if [[ ! -f "$BOOTSTRAP" ]] && [[ -z "${DRY_RUN}" ]]; then
  DRY_RUN=1
  info "bootstrap.env não encontrado — forçando DRY_RUN=1"
fi

if [[ -n "$DRY_RUN" ]]; then
  echo "=== bootstrap-opensre-sa DRY_RUN ==="
  info "would ensure group: $SA_GROUP"
  info "would ensure service account / person: $SA_NAME@$DOMAIN"
  info "would add $SA_NAME to $SA_GROUP + archguard_users (read scope)"
  info "would NOT grant archguard_admins"
  info "would create OAuth2/API token scope minimal (agents:read + agents:request)"
  info "policy file: deploy/agentic/policies/opensre-allowlist.yaml"
  log "dry-run complete"
  exit 0
fi

# shellcheck disable=SC1090
set -a; source "$BOOTSTRAP"; set +a

archguard_URL="${archguard_URL:-https://127.0.0.1:8443}"
TOOLS="${archguard_TOOLS_IMAGE:-archguard/tools:1.10.4}"
TOKENS=$(mktemp -d)
trap 'rm -rf "$TOKENS"' EXIT

CID=$(docker ps --filter name=archgate-id_archguardd --format '{{.ID}}' | head -1)
[[ -n "$CID" ]] || fail "archguard not running"

IDM_PASS=$(docker exec "$CID" /sbin/archguardd recover-account idm_admin -c /data/server.toml 2>&1 \
  | sed -n 's/.*new_password: "\([^"]*\)".*/\1/p' | tail -1)
[[ -n "$IDM_PASS" ]] || fail "could not recover idm_admin"

# Login tools (non-interactive best-effort; lab may need expect like offboarding-e2e)
info "login idm_admin via tools image (see offboarding-e2e for expect pattern if needed)"
docker run --rm --network host \
  -v "$TOKENS:/root/.cache/archguard_tokens" \
  -e "archguard_URL=$archguard_URL" \
  "$TOOLS" /sbin/archguard login --accept-invalid-certs --name idm_admin <<EOF || true
$IDM_PASS
EOF

k() {
  docker run --rm --network host \
    -v "$TOKENS:/root/.cache/archguard_tokens" \
    -e "archguard_URL=$archguard_URL" \
    "$TOOLS" /sbin/archguard "$@" --accept-invalid-certs --name idm_admin 2>&1 | grep -v WARN || true
}

info "ensure group $SA_GROUP"
k group create "$SA_GROUP" || true

info "ensure person $SA_NAME"
k person create "$SA_NAME" "OpenSRE Agent" || true

info "membership $SA_GROUP"
k group add-members "$SA_GROUP" "$SA_NAME" || true
k group add-members archguard_users "$SA_NAME" || true

log "SA $SA_NAME bootstrap attempted — validate in archguard UI/API"
log "Next: issue API token; configure agent-control OPENSRE_AGENT_ID=$SA_NAME"
