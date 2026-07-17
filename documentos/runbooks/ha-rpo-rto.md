# RPO / RTO — ArchGate (W5-HA06)

Valores **alvo de produto** (aceitação arquitetura). Lab pode ter RTO pior (unseal manual/timer).

## Objetivos

| Domínio | RPO (perda máx. dados) | RTO (retorno serviço) | Notas |
|---------|------------------------|------------------------|-------|
| **OpenBao secrets engine** | ≤ 5 min (Raft) | ≤ 15 min (quorum + unseal auto) | Centro crítico |
| **Kanidm identidades** | ≤ 15 min | ≤ 30 min | Auth bloqueante |
| **Postgres apps** (WG/Guac/console) | ≤ 15 min (WAL/backup) | ≤ 1 h | Restore testado |
| **Traefik / edge** | N/A (stateless) | ≤ 5 min | Multi-node |
| **Warpgate / Guac** | 0 config (PG) | ≤ 10 min scale | Sessões ativas podem cair |
| **Gravações de sessão** | ≤ 24 h (object store) | best-effort | Não bloqueia auth |
| **Audit export** | ≤ 24 h | best-effort | SIEM opcional §10 |

## Aceite

| Papel | Aceita RPO/RTO acima? | Data | Assinatura |
|-------|------------------------|------|------------|
| Arquiteto plataforma | [ ] | | |
| Ops / SRE | [ ] | | |
| Segurança | [ ] | | |

## Como medir

1. **RPO:** comparar timestamp última write vs restore point após falha simulada.  
2. **RTO:** cronômetro do `ha-failover-tests.md` por componente.  
3. Registrar evidência em `documentos/runbooks/sites/` ou ticket.

## Lab waiver

Staging single-node: RTO OpenBao depende do timer de unseal (~2 min) + boot Swarm; **não** cumpre Raft HA. Documentar como **waiver** até deploy multi-node.
