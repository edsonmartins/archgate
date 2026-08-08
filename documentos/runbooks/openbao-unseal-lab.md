# Runbook — OpenBao unseal (lab)

| Campo | Valor |
|-------|--------|
| Plano | [`../PLAN-HOMOLOGACAO-MVP.md`](../PLAN-HOMOLOGACAO-MVP.md) **F4.3** |
| Ambiente | staging `edson-ai` / `192.168.1.180` |
| Storage | single-node **file** (não HA) |
| Threshold lab | 1 share |

## Estado esperado

```bash
CID=$(docker ps -q -f name=archgate-secrets_openbao | head -1)
docker exec "$CID" bao status
# Sealed false
```

## Automático (boot / recreate)

| Unidade | Papel |
|---------|--------|
| `archgate-openbao-unseal.timer` | dispara periodicamente (~2 min) |
| `archgate-openbao-unseal.service` | unseal se sealed; no-op se já unsealed |

```bash
systemctl status archgate-openbao-unseal.timer
systemctl status archgate-openbao-unseal.service
# logs
journalctl -u archgate-openbao-unseal.service -n 30 --no-pager
```

Script instalado em: `/usr/local/sbin/archgate-openbao-unseal`  
(fonte: `deploy/openbao/systemd/`)

Chave de unseal: `OPENBAO_UNSEAL_KEY` em `/root/archgate/bootstrap.env` (não no git).

## Manual (se timer falhar)

```bash
set -a; source /root/archgate/bootstrap.env; set +a
CID=$(docker ps -q -f name=archgate-secrets_openbao | head -1)
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 "$CID" \
  bao operator unseal "$OPENBAO_UNSEAL_KEY"
docker exec "$CID" bao status | head -8
```

## Após reboot do host

1. Subir Swarm services (`docker service ls` — openbao 1/1).  
2. Aguardar timer **ou** rodar unseal manual.  
3. Validar: `bao status` → Sealed false.  
4. Smoke opcional: `bash deploy/openbao/smoke-archguard-jwt.sh`.

## Limites lab (waiver homolog)

- Root token / unseal key ainda no env do console com `ARCHGATE_LAB=1` — **não** é modelo de produção.  
- Sem auto-unseal KMS / Raft HA (Fase 5 / §7 do plano).
