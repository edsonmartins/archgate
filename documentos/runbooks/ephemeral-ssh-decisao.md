# Decisão W1-EPH03 — SSH cert nativo Warpgate vs broker

| Opção | Status | Nota |
|-------|--------|------|
| **A. Warpgate pede cert SSH ao OpenBao no connect** | Bloqueado upstream | warpgate#2105 / integração Vault nativa incompleta |
| **B. Broker / password dinâmico (lab atual)** | **Padrão W1** | OpenBao DB dyn + broker timer; SSH lab com password/key por target `TARGET_SECRET_*` ou cert emitido offline |

## Decisão (2026-07-17)

**Padrão operacional W1:** opção **B** — credenciais efêmeras via OpenBao (DB) + secrets por target; **não** bloquear go-live à espera de cert nativo Warpgate.

**Revisitar** quando upstream permitir emissão de cert no connect; então migrar targets SSH para CA OpenBao e reduzir passwords de alvo.

## Critérios de aceite com B

- [x] JWT archguard → OpenBao  
- [x] DB dinâmico + broker Warpgate PG  
- [x] Sem senha de alvo no inventário de sites (só secret_ref / env)  
- [ ] SSH só com cert CA (pós-upstream)  
