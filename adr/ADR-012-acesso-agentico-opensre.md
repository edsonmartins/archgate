# ADR-012 — Acesso agêntico (OpenSRE)

| Campo | Valor |
|-------|--------|
| Status | **Aceito (W5)** |
| Data | 2026-07-17 |
| Relacionados | CONSTITUTION §, ADR-006, ADR-011, `add-agentic-access` |

## Contexto

OpenSRE (e futuros agentes) precisam operar o bastion **sem** ser um super-admin opaco. O modelo deve reutilizar identidade, credencial efêmera, gravação e offboarding.

## Decisão

| Princípio | Implementação |
|-----------|----------------|
| Principal | Service account archguard (`opensre` / `sa-opensre`) escopo mínimo |
| Confiança | **Não-confiável por padrão** — política no gateway, não no LLM |
| Read | Diagnóstico/listagem automática (allow-list) |
| Write / mutante | **HITL** obrigatório (`services/agent-control`) |
| On-behalf-of | Toda ação: `agent_sa` + `approver_human` na auditoria |
| JIT | Credencial OpenBao escopada a incidente/target + TTL curto |
| Kill-switch | `POST …/kill-switch` → revoke SA (mesmo primitivo offboarding) |
| Inferência | **Local-first** se tocar dado de cliente (sem SaaS LLM) |

Superfície de API: `services/agent-control` (Spring). Orquestração Axis continua em `services/orchestration` para pessoas/tenants; o agente usa agent-control + bastion.

## Consequências

- Dois clients OIDC/SA: humanos (UnifiedUI/console) vs `sa-opensre`.  
- Allow-list versionada em `deploy/agentic/policies/`.  
- E2E: request → HITL → sessão → revoke / kill-switch.  
- Prompt injection mitigado por gateway (comando fora da lista = deny).

## Alternativas rejeitadas

- Agente com token admin ArchGuard no browser/runtime.  
- Confiar no system prompt do modelo para “não fazer merda”.  
- Enviar logs/PII de cliente a API LLM pública.
