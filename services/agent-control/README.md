# ArchGate Agent Control (W5)

Control plane para OpenSRE: política (allow-list), HITL, kill-switch e cadeia de auditoria.

- ADR: [`ADR-012`](../../adr/ADR-012-acesso-agentico-opensre.md)  
- Runbook: [`agentic-access.md`](../../documentos/runbooks/agentic-access.md)  
- Policy: [`deploy/agentic/policies/opensre-allowlist.yaml`](../../deploy/agentic/policies/opensre-allowlist.yaml)

## API (`:8091`)

| Método | Path | Uso |
|--------|------|-----|
| POST | `/agentic/v1/sessions/request` | JIT session ticket (read auto / mutant HITL) |
| POST | `/agentic/v1/actions` | Avalia ação (deny / allow / pending_hitl) |
| POST | `/agentic/v1/approvals/{id}/approve\|deny` | HITL humano |
| POST | `/agentic/v1/kill-switch` | Desativa SA + tenta revoke orchestration |
| GET | `/agentic/v1/audit?incident_id=` | Cadeia agente→humano→ação |
| GET | `/agentic/v1/policy/cloud-llm` | Flag inferência (default false) |

## Dev

```bash
cd services/agent-control
mvn -q test
mvn -q spring-boot:run
bash ../../deploy/validation/smoke-agent-control-mock.sh
```

## Segurança

- Agente **não-confiável**; política no gateway.  
- Tokens admin nunca no runtime do modelo.  
- Kill-switch = mesmo primitivo de offboarding (orchestration revoke).  
- HA: stores in-memory → PG/Redis (ADR-011).
