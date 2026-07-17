# Runbook — Topologia HA (W5-HA)

| Campo | Valor |
|-------|--------|
| ADR | [ADR-011](../../adr/ADR-011-alta-disponibilidade-proporcional.md) |
| Lab | single-node (não-HA) |
| Alvo | produção multi-cliente |

## Diagrama lógico

```
          ┌──────────── edge (Traefik × N + VIP/DNS) ────────────┐
          │                                                       │
   console / unified-ui / wg / guac / id / secrets (TLS term)     │
          └───────────────┬───────────────────────────────────────┘
                          │
     ┌────────────────────┼────────────────────┐
     ▼                    ▼                    ▼
 Kanidm (replica)    OpenBao Raft          Gateways (stateless)
     │               (auto-unseal)         Warpgate / Guac / guacd
     │                    │                    │
     └────────── PostgreSQL apps (HA/off-host) ┘
                    archgate DBs + audit export
```

## Componentes

| Serviço | HA pattern | Storage | Notas lab → prod |
|---------|------------|---------|------------------|
| OpenBao | Raft 3/5 | integrated storage | hoje: file + unseal timer |
| Kanidm | replication | volume/DB | hoje: 1 task |
| Postgres | primary + replica / managed | externo | `.110:5434` lab |
| Warpgate | N replicas Swarm | PG only | sem SQLite |
| Guacamole | N + guacd pool | PG | sessions em PG |
| Traefik | N + placement | config | Cloudflare opcional |
| orchestration | N | PG/Redis HITL store | memória só lab |
| agent-control | N | PG/Redis | memória só lab |

## Artefatos

| Path | Uso |
|------|-----|
| `deploy/openbao/ha/raft.hcl.example` | config Raft |
| `deploy/openbao/ha/auto-unseal-transit.example.hcl` | seal stanza |
| `deploy/openbao/ha/README.md` | bootstrap cluster |
| `documentos/runbooks/ha-rpo-rto.md` | objetivos |
| `documentos/runbooks/ha-failover-tests.md` | testes |
| `deploy/validation/ha-failover-checklist.sh` | checklist automatizável |

## Pré-requisitos antes de promover lab → HA

1. Backup PG off-host validado (restore drill).  
2. Unseal keys / recovery keys em cofre offline (não só `bootstrap.env`).  
3. DNS / VIP para edge.  
4. Janela de manutenção documentada.
