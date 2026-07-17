#!/usr/bin/env bash
# Smoke — orchestration service mock API (W4-ORCH)
set -euo pipefail

BASE="${ORCH_URL:-http://127.0.0.1:8090}"
fail() { echo "  [FAIL] $1" >&2; exit 1; }
ok()   { echo "  [OK] $1"; }

echo "=== smoke-orchestration-mock ($BASE) ==="

curl -sf "$BASE/actuator/health" | grep -q UP || fail "health not UP"
ok "health UP"

PROV=$(curl -sf -X POST "$BASE/orchestration/v1/users/provision" \
  -H 'Content-Type: application/json' \
  -d '{"tenant_slug":"rio_quality","username":"smoke.orch","email":"s@x.c","profile":"operator"}')
echo "$PROV" | grep -q '"status":"ok"' || fail "provision: $PROV"
ok "provision"

REV=$(curl -sf -X POST "$BASE/orchestration/v1/users/revoke" \
  -H 'Content-Type: application/json' \
  -d '{"username":"smoke.orch","reason":"smoke"}')
echo "$REV" | grep -q 'users.revoke' || fail "revoke: $REV"
ok "revoke one-shot"

WH=$(curl -sf -X POST "$BASE/orchestration/v1/webhooks/axis" \
  -H 'Content-Type: application/json' \
  -H 'Idempotency-Key: smoke-evt-1' \
  -d '{"event":"user.offboard","username":"smoke.orch2","reason":"axis"}')
echo "$WH" | grep -q 'users.revoke' || fail "webhook: $WH"
ok "webhook axis offboard"

WH2=$(curl -sf -X POST "$BASE/orchestration/v1/webhooks/axis" \
  -H 'Content-Type: application/json' \
  -H 'Idempotency-Key: smoke-evt-1' \
  -d '{"event":"user.offboard","username":"smoke.orch2","reason":"axis"}')
# same idempotency key should return cached
ID1=$(echo "$WH" | sed -n 's/.*"operationId":"\([^"]*\)".*/\1/p')
ID2=$(echo "$WH2" | sed -n 's/.*"operationId":"\([^"]*\)".*/\1/p')
[[ "$ID1" == "$ID2" ]] || fail "idempotency mismatch $ID1 vs $ID2"
ok "webhook idempotency"

echo "=== PASS smoke-orchestration-mock ==="
