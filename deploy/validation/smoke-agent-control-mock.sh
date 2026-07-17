#!/usr/bin/env bash
# Smoke — agent-control mock (W5-AG)
set -euo pipefail

BASE="${AGENT_URL:-http://127.0.0.1:8091}"
fail() { echo "  [FAIL] $1" >&2; exit 1; }
ok()   { echo "  [OK] $1"; }

echo "=== smoke-agent-control-mock ($BASE) ==="

curl -sf "$BASE/actuator/health" | grep -q UP || fail "health"
ok "health UP"

READ=$(curl -sf -X POST "$BASE/agentic/v1/sessions/request" \
  -H 'Content-Type: application/json' \
  -d '{"agent_id":"sa-opensre","action":"diag.read","target":"rio-lab-ssh","incident_id":"SMOKE-1","mode":"read"}')
echo "$READ" | grep -q '"status":"issued"' || fail "read session: $READ"
ok "read session issued"

MUT=$(curl -sf -X POST "$BASE/agentic/v1/actions" \
  -H 'Content-Type: application/json' \
  -d '{"agent_id":"sa-opensre","action":"shell.write","target":"rio-lab-ssh","command":"systemctl restart nginx","incident_id":"SMOKE-1"}')
echo "$MUT" | grep -q 'PENDING_HITL' || fail "mutant: $MUT"
AID=$(echo "$MUT" | sed -n 's/.*"approvalId":"\([^"]*\)".*/\1/p')
[[ -n "$AID" ]] || fail "no approvalId"
ok "mutant pending HITL ($AID)"

curl -sf -X POST "$BASE/agentic/v1/approvals/$AID/approve" \
  -H 'Content-Type: application/json' \
  -d '{"approver":"ops.smoke","reason":"smoke"}' | grep -q APPROVED || fail "approve"
ok "HITL approve"

curl -sf "$BASE/agentic/v1/audit?incident_id=SMOKE-1" | grep -q hitl.approved || fail "audit chain"
ok "audit chain"

curl -sf -X POST "$BASE/agentic/v1/kill-switch" \
  -H 'Content-Type: application/json' \
  -d '{"agent_id":"sa-opensre","reason":"smoke","actor":"secops"}' | grep -q '"killed":true' || fail "kill"
ok "kill-switch"

DENY=$(curl -sf -X POST "$BASE/agentic/v1/sessions/request" \
  -H 'Content-Type: application/json' \
  -d '{"agent_id":"sa-opensre","action":"diag.read","target":"rio-lab-ssh","incident_id":"SMOKE-2","mode":"read"}')
echo "$DENY" | grep -q '"status":"denied"' || fail "post-kill should deny: $DENY"
ok "post-kill denied"

echo "=== PASS smoke-agent-control-mock ==="
