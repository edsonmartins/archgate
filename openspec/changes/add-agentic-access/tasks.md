# Tasks — Add Agentic Access & HA (Fase 5)

## 1. Alta disponibilidade
- [x] 1.1 OpenBao HA design + Raft/auto-unseal exemplos (`deploy/openbao/ha/*`) — 2026-07-17
- [x] 1.2 Kanidm topologia HA documentada (`ha-topology.md`)
- [x] 1.3 Persistência externa confirmada (ADR-003 + topologia)
- [x] 1.4 Gateways stateless pattern documentado (Traefik multi-node)
- [x] 1.5 Runbook failover + checklist (`ha-failover-tests.md`, `ha-failover-checklist.sh`)
- [x] 1.6 RPO/RTO documentados (`ha-rpo-rto.md`) — aceite assinatura pendente
- [ ] 1.7 Deploy multi-node real (OpenBao Raft + Kanidm replica) em lab/prod

## 2. Identidade do agente
- [x] 2.1 Bootstrap SA OpenSRE (`deploy/agentic/bootstrap-opensre-sa.sh`) + policy YAML
- [x] 2.2 On-behalf-of na auditoria (`humanApprover` + `agentId`) — agent-control
- [ ] 2.3 Token/API live no Kanidm lab

## 3. Política no gateway (não no modelo)
- [x] 3.1 Allow-list de ações (`opensre-allowlist.yaml` + PolicyEngine)
- [x] 3.2 Escopo por target allow-list + incident_id obrigatório
- [x] 3.3 TTL curto (policy max_ttl) + rate limit in-memory
- [x] 3.4 JIT session ticket mock (`POST /sessions/request`) — OpenBao lease live TBD

## 4. HITL e read-only
- [x] 4.1 Read actions auto-allow
- [x] 4.2 Mutant → PENDING_HITL + approve/deny
- [x] 4.3 Approver registrado na audit chain
- [ ] 4.4 Integração UI admin “aprovações pendentes”

## 5. Kill-switch e inferência local
- [x] 5.1 Kill-switch API + bloqueio subsequente; best-effort orchestration revoke
- [x] 5.2 Política inferência local (`agentic-inference-local.md`); `allow_cloud_llm=false`
- [ ] 5.3 Consentimento formal do cliente (processo comercial/ops)

## 6. Validação
- [x] 6.1 Unit: read sem write não aprovado
- [x] 6.2 Unit/MockMvc: mutante bloqueado até approve
- [x] 6.3 Kill-switch + audit chain em testes; smoke script
- [x] 6.4 Prompt injection surface: action/command fora da lista = DENY
- [ ] 6.5 E2E lab com SA real + bastion gravação
