#!/usr/bin/env bash
# Smoke — agent-control mock (W5-AG)
set -euo pipefail

BASE="${AGENT_URL:-http://127.0.0.1:8091}"
fail() { echo "  [FAIL] $1" >&2; exit 1; }
ok()   { echo "  [OK] $1"; }

# Agent and approver credentials are distinct on purpose: holding the agent
# token must not let anyone approve its actions (audit 2026-07-28, P1-2).
: "${AGENT_API_TOKEN:?set AGENT_API_TOKEN (agent service account credential)}"
: "${AGENT_APPROVER_TOKEN:?set AGENT_APPROVER_TOKEN (human/ops credential)}"
AGENT_AUTH=(-H "Authorization: Bearer ${AGENT_API_TOKEN}")
APPROVER_AUTH=(-H "Authorization: Bearer ${AGENT_APPROVER_TOKEN}"
               -H "X-ArchGate-Actor: ${APPROVER_ACTOR:-ops.smoke}")

echo "=== smoke-agent-control-mock ($BASE) ==="

curl -sf "$BASE/actuator/health" | grep -q UP || fail "health"
ok "health UP (no credential required)"

CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/agentic/v1/kill-switch" \
  -H 'Content-Type: application/json' -d '{"agent_id":"sa-opensre","reason":"anon"}')
[[ "$CODE" == "401" ]] || fail "anonymous kill-switch must be 401, got $CODE"
ok "anonymous call rejected"

READ=$(curl -sf -X POST "$BASE/agentic/v1/sessions/request" \
  "${AGENT_AUTH[@]}" -H 'Content-Type: application/json' \
  -d '{"agent_id":"sa-opensre","action":"diag.read","target":"rio-lab-ssh","incident_id":"SMOKE-1","mode":"read"}')
echo "$READ" | grep -q '"status":"issued"' || fail "read session: $READ"
ok "read session issued"

MUT=$(curl -sf -X POST "$BASE/agentic/v1/actions" \
  "${AGENT_AUTH[@]}" -H 'Content-Type: application/json' \
  -d '{"agent_id":"sa-opensre","action":"shell.write","target":"rio-lab-ssh","command":"systemctl restart nginx","incident_id":"SMOKE-1"}')
echo "$MUT" | grep -q 'PENDING_HITL' || fail "mutant: $MUT"
AID=$(echo "$MUT" | sed -n 's/.*"approvalId":"\([^"]*\)".*/\1/p')
[[ -n "$AID" ]] || fail "no approvalId"
ok "mutant pending HITL ($AID)"

CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/agentic/v1/approvals/$AID/approve" \
  "${AGENT_AUTH[@]}" -H 'X-ArchGate-Actor: sa-opensre' \
  -H 'Content-Type: application/json' -d '{"reason":"self-approval"}')
[[ "$CODE" == "403" ]] || fail "agent must not approve its own action (got $CODE)"
ok "self-approval refused"

curl -sf -X POST "$BASE/agentic/v1/approvals/$AID/approve" \
  "${APPROVER_AUTH[@]}" -H 'Content-Type: application/json' \
  -d '{"reason":"smoke"}' | grep -q APPROVED || fail "approve"
ok "HITL approve"

curl -sf "${APPROVER_AUTH[@]}" "$BASE/agentic/v1/audit?incident_id=SMOKE-1" \
  | grep -q hitl.approved || fail "audit chain"
ok "audit chain"

curl -sf -X POST "$BASE/agentic/v1/kill-switch" \
  "${APPROVER_AUTH[@]}" -H 'Content-Type: application/json' \
  -d '{"agent_id":"sa-opensre","reason":"smoke"}' | grep -q '"killed":true' || fail "kill"
ok "kill-switch"

DENY=$(curl -sf -X POST "$BASE/agentic/v1/sessions/request" \
  "${AGENT_AUTH[@]}" -H 'Content-Type: application/json' \
  -d '{"agent_id":"sa-opensre","action":"diag.read","target":"rio-lab-ssh","incident_id":"SMOKE-2","mode":"read"}')
echo "$DENY" | grep -q '"status":"denied"' || fail "post-kill should deny: $DENY"
ok "post-kill denied"

echo "=== PASS smoke-agent-control-mock ==="
