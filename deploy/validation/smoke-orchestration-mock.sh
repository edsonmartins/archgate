#!/usr/bin/env bash
# Smoke — orchestration service mock API (W4-ORCH)
set -euo pipefail

BASE="${ORCH_URL:-http://127.0.0.1:8090}"
fail() { echo "  [FAIL] $1" >&2; exit 1; }
ok()   { echo "  [OK] $1"; }

# The API authenticates every route and fails closed (audit 2026-07-28, P0-3).
: "${ORCH_API_TOKEN:?set ORCH_API_TOKEN (same value the service was deployed with)}"
: "${ORCH_WEBHOOK_SECRET:?set ORCH_WEBHOOK_SECRET for the Axis webhook signature}"
AUTH=(-H "Authorization: Bearer ${ORCH_API_TOKEN}")

# sha256=<hex HMAC of the exact body> — the service compares in constant time.
sign() {
  printf '%s' "$1" \
    | openssl dgst -sha256 -hmac "$ORCH_WEBHOOK_SECRET" \
    | sed 's/^.*= /sha256=/'
}

echo "=== smoke-orchestration-mock ($BASE) ==="

curl -sf "$BASE/actuator/health" | grep -q UP || fail "health not UP"
ok "health UP (no credential required)"

CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/orchestration/v1/tenants/sync")
[[ "$CODE" == "401" ]] || fail "anonymous call must be 401, got $CODE"
ok "anonymous call rejected"

PROV=$(curl -sf -X POST "$BASE/orchestration/v1/users/provision" \
  "${AUTH[@]}" -H 'Content-Type: application/json' \
  -d '{"tenant_slug":"rio_quality","username":"smoke.orch","email":"s@x.c","profile":"operator"}')
echo "$PROV" | grep -q '"status":"ok"' || fail "provision: $PROV"
ok "provision"

REV=$(curl -sf -X POST "$BASE/orchestration/v1/users/revoke" \
  "${AUTH[@]}" -H 'Content-Type: application/json' \
  -d '{"username":"smoke.orch","reason":"smoke"}')
echo "$REV" | grep -q 'users.revoke' || fail "revoke: $REV"
ok "revoke one-shot"

WH_BODY='{"event":"user.offboard","username":"smoke.orch2","reason":"axis"}'
WH=$(curl -sf -X POST "$BASE/orchestration/v1/webhooks/axis" \
  "${AUTH[@]}" -H 'Content-Type: application/json' \
  -H "X-ArchGate-Signature: $(sign "$WH_BODY")" \
  -H 'Idempotency-Key: smoke-evt-1' \
  -d "$WH_BODY")
echo "$WH" | grep -q 'users.revoke' || fail "webhook: $WH"
ok "webhook axis offboard"

WH2=$(curl -sf -X POST "$BASE/orchestration/v1/webhooks/axis" \
  "${AUTH[@]}" -H 'Content-Type: application/json' \
  -H "X-ArchGate-Signature: $(sign "$WH_BODY")" \
  -H 'Idempotency-Key: smoke-evt-1' \
  -d "$WH_BODY")
# same idempotency key should return cached
ID1=$(echo "$WH" | sed -n 's/.*"operationId":"\([^"]*\)".*/\1/p')
ID2=$(echo "$WH2" | sed -n 's/.*"operationId":"\([^"]*\)".*/\1/p')
[[ "$ID1" == "$ID2" ]] || fail "idempotency mismatch $ID1 vs $ID2"
ok "webhook idempotency"

CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/orchestration/v1/webhooks/axis" \
  "${AUTH[@]}" -H 'Content-Type: application/json' \
  -d "$WH_BODY")
[[ "$CODE" == "401" ]] || fail "unsigned webhook must be 401, got $CODE"
ok "unsigned webhook rejected"

echo "=== PASS smoke-orchestration-mock ==="
