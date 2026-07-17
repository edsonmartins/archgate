#!/usr/bin/env bash
# W5-HA05 — Checklist automatizável de pré-condições HA (não injeta falha destrutiva).
# Exit 0 = checks passed or skipped with reason; use for CI/docs gate.
set -euo pipefail

fail() { echo "  [FAIL] $1" >&2; FAILED=1; }
ok()   { echo "  [OK] $1"; }
skip() { echo "  [SKIP] $1"; }
FAILED=0

echo "=== ha-failover-checklist ==="
echo "Full procedures: documentos/runbooks/ha-failover-tests.md"
echo "RPO/RTO: documentos/runbooks/ha-rpo-rto.md"
echo

# Docs present
for f in \
  documentos/runbooks/ha-topology.md \
  documentos/runbooks/ha-rpo-rto.md \
  documentos/runbooks/ha-failover-tests.md \
  deploy/openbao/ha/raft.hcl.example \
  adr/ADR-011-alta-disponibilidade-proporcional.md
do
  if [[ -f "$f" ]]; then ok "doc $f"; else fail "missing $f"; fi
done

# Lab single-node detection (optional docker)
if command -v docker >/dev/null 2>&1; then
  OB=$(docker ps -q -f name=archgate-secrets_openbao 2>/dev/null | wc -l | tr -d ' ')
  if [[ "${OB:-0}" -ge 1 ]]; then
    ok "openbao container visible ($OB)"
    skip "Raft multi-node not asserted on lab single-node"
  else
    skip "openbao not running locally"
  fi
else
  skip "docker not available"
fi

# Agent + orch services not required for HA docs gate
if [[ -f services/agent-control/pom.xml ]]; then ok "agent-control scaffold"; else fail "agent-control missing"; fi
if [[ -f deploy/openbao/ha/README.md ]]; then ok "openbao ha README"; else fail "openbao ha README"; fi

echo
if [[ "${FAILED:-0}" -ne 0 ]]; then
  echo "=== FAIL ha-failover-checklist ==="
  exit 1
fi
echo "=== PASS ha-failover-checklist (docs/scaffold) ==="
