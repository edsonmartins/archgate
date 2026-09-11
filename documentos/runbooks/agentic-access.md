# Runbook — Acesso agêntico OpenSRE (W5-AG)

## Autenticação (obrigatória)

| Credencial | Uso | Rotas |
|------------|-----|-------|
| `AGENT_API_TOKEN` | Service account do agente (OpenSRE) | `POST /agentic/v1/sessions/request`, `POST /agentic/v1/actions`, leituras |
| `AGENT_APPROVER_TOKEN` | Plano humano/ops — **distinto** do token do agente | `POST /approvals/{id}/approve`, `/deny`, `POST /kill-switch` |

- `agent_id` vem da credencial apresentada; divergência no corpo → **403**.
- Aprovações exigem `X-ArchGate-Actor: <pessoa>` para registrar o aprovador.
- Sem nenhuma credencial configurada, a API responde **503** (fail-closed).
- A API é interna; não é publicada na borda.

Motivo: até a auditoria de 2026-07-28 todas as rotas eram anônimas e o chamador
declarava o próprio `agent_id`, o que anulava o HITL (qualquer um aprovava as
próprias ações e desligava o kill-switch).

| Campo | Valor |
|-------|--------|
| ADR | [ADR-012](../../adr/ADR-012-acesso-agentico-opensre.md) |
| API | `services/agent-control` |
| Policies | `deploy/agentic/policies/opensre-allowlist.yaml` |

## Modelo

```
OpenSRE (SA) ──request──► agent-control ──policy──► allow | deny | pending_hitl
                              │                         │
                              │ approve (humano)        │
                              ▼                         ▼
                         OpenBao JIT              audit chain
                              │
                              ▼
                         Warpgate / bastion (gravação)
```

## Bootstrap SA (lab)

```bash
# dry-run:
DRY_RUN=1 bash deploy/agentic/bootstrap-opensre-sa.sh

# live (host com archguard tools + bootstrap.env):
bash deploy/agentic/bootstrap-opensre-sa.sh
```

Cria (intent): person/service `sa-opensre`, grupo `archgate_agents`, membership mínima.

## Fluxos API (mock/local)

```bash
# subir
cd services/agent-control && mvn -q spring-boot:run
# :8091

# pedir sessão read-only (auto)
curl -s -X POST localhost:8091/agentic/v1/sessions/request \
  -H 'Content-Type: application/json' \
  -d '{"agent_id":"sa-opensre","action":"diag.read","target":"rio-lab-ssh","incident_id":"INC-1","mode":"read"}'

# ação mutante → HITL
curl -s -X POST localhost:8091/agentic/v1/actions \
  -H 'Content-Type: application/json' \
  -d '{"agent_id":"sa-opensre","action":"shell.write","target":"rio-lab-ssh","command":"systemctl restart nginx","incident_id":"INC-1"}'

# aprovar
curl -s -X POST localhost:8091/agentic/v1/approvals/{id}/approve \
  -H 'Content-Type: application/json' \
  -d '{"approver":"ops.human","reason":"authorized change"}'

# kill-switch
curl -s -X POST localhost:8091/agentic/v1/kill-switch \
  -H 'Content-Type: application/json' \
  -d '{"agent_id":"sa-opensre","reason":"runaway","actor":"secops"}'
```

Smoke: `bash deploy/validation/smoke-agent-control-mock.sh`

## Kill-switch

1. API agent-control marca SA como **disabled**.  
2. Em live: chama orchestration revoke / archguard expire (mesmo offboarding).  
3. OpenBao deixa de emitir leases para a SA; TTLs ativos expiram.

## Consentimento cliente

Operação agêntica em ambiente de cliente exige registro de consentimento (ticket/contrato). Ver `agentic-inference-local.md` (dado não sai para SaaS LLM).
