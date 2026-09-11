# ADR-011 — Alta disponibilidade proporcional ao risco

| Campo | Valor |
|-------|--------|
| Status | **Aceito (W5)** |
| Data | 2026-07-17 |
| Relacionados | ADR-003, `add-agentic-access` / high-availability |

## Contexto

Lab/staging roda single-node (OpenBao file storage + unseal timer, um archguard, um Traefik). Produção multi-cliente exige HA **proporcional**: o centro de gravidade (OpenBao + IdP) tem requisitos mais rígidos que gateways.

## Decisão

| Camada | Modelo alvo | Lab atual | Transição |
|--------|-------------|-----------|-----------|
| **OpenBao** | Raft HA ≥3 nós + **auto-unseal** (Transit/KMS/HSM) | file + unseal key em host | `deploy/openbao/ha/*` |
| **archguard** | Replicação (write-leader + read replicas ou cluster suportado) | single `archguardd` | runbook topologia |
| **Postgres apps** | PG gerenciado/HA (já externo — ADR-003) | `.110:5434` | manter off-host backup |
| **Warpgate / Guac / guacd** | Stateless (N réplicas) + PG | 1 réplica Swarm | scale service |
| **Traefik** | ≥2 nodes / edge redundante | 1 | Swarm placement + VIP |
| **Orchestration / agent-control** | Stateless + store de idempotência/HITL em PG/Redis | in-memory | W5 store externo |

Princípios:

1. **Persistência fora do container** (ADR-003).  
2. **Segredos de unseal fora do app** (nunca root token no console em prod).  
3. **Failover testado por componente** com evidência (runbook).  
4. **RPO/RTO explícitos** e aceitos (`ha-rpo-rto.md`).

## Consequências

- Lab **não** precisa de 3 nós OpenBao para homolog MVP; HA é gate de M5.  
- Auto-unseal KMS pode ser Transit OpenBao isolado ou cloud KMS interno IntegrAllTech.  
- Idempotência Axis (W4) e fila HITL (W5) migram de memória para PG/Redis sob HA.

## Alternativas rejeitadas

- HA “tudo active-active” no dia 1 sem RPO/RTO.  
- Manter SQLite Warpgate em prod (já rejeitado por ADR-003).  
- Unseal key no mesmo repositório de código ou no browser.
