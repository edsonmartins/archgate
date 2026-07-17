# Testes de failover por componente (W5-HA05)

| Campo | Valor |
|-------|--------|
| Script apoio | `deploy/validation/ha-failover-checklist.sh` |
| Frequência | a cada promoção HA / trimestral |

## Procedimento geral

1. Baseline: `bash deploy/validation/health-monitor.sh` (ou `w0-validate.sh`).  
2. Injetar falha **um** componente.  
3. Medir tempo até serviço recuperado (RTO).  
4. Verificar RPO (dados perdidos).  
5. Registrar evidência (timestamp, comandos, PASS/FAIL).

## Casos

### F1 — OpenBao nó down

| Passo | Ação |
|-------|------|
| 1 | Em cluster Raft: stop 1 follower; `bao status` em survivor |
| 2 | Emitir lease teste (`smoke-ephemeral` / broker) |
| 3 | Stop leader → eleição; revalidar emissão |
| Critério | Emissão continua sem unseal manual (auto-unseal) |

Lab single-node: **SKIP** com nota “sem Raft”.

### F2 — Kanidm down

| Passo | Ação |
|-------|------|
| 1 | Parar réplica secundária; login OIDC ainda ok via primário |
| 2 | Failover DNS/VIP se aplicável |
| Critério | `id.archgate.com.br` authorize responde |

### F3 — Gateway Warpgate restart

| Passo | Ação |
|-------|------|
| 1 | `docker service update --force archgate-gw_warpgate` |
| 2 | SSH bastion após healthy |
| Critério | Targets intactos (PG); sessão nova ok |

### F4 — Guacamole restart

| Passo | Ação |
|-------|------|
| 1 | Force update guacamole + guacd |
| 2 | SSO + list connections |
| Critério | Users/connections no PG intactos |

### F5 — Traefik node

| Passo | Ação |
|-------|------|
| 1 | Drain 1 node de Traefik |
| 2 | HTTPS public hosts |
| Critério | Edge continua (segundo node / CF) |

### F6 — Postgres primary (cuidado)

| Passo | Ação |
|-------|------|
| 1 | Em ambiente de **teste** com replica: promote |
| 2 | Reapontar services |
| Critério | Dentro do RTO; restore drill documentado |

**Não** rodar F6 destrutivo em lab de homolog sem janela.

## Template de evidência

```text
Data:
Componente:
Início falha:
Recuperado em:
RTO medido:
RPO observado:
Operador:
PASS/FAIL:
```
