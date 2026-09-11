# Runbook — Incidentes ArchGate (lab / pré-prod)

| Campo | Valor |
|-------|--------|
| Plano | W1-OPS04 · [`PLAN-PRODUTO-100.md`](../PLAN-PRODUTO-100.md) |
| Host runtime | `192.168.1.180` (`edson-ai`) |
| Bootstrap | `/root/archgate/bootstrap.env` (mode 600) |

## 0. Diagnóstico rápido

```bash
bash deploy/validation/health-monitor.sh
docker service ls | grep archgate
```

---

## 1. Bastion / console down

| Sintoma | Ação |
|---------|------|
| `console` 0/1 ou 502 | `docker service ps archgate-id_archguard-console`; logs `docker service logs --tail 100 …` |
| Traefik 0/1 | `docker service ps archgate-edge_traefik`; cert / rede `archgate-public` |
| Warpgate SSH recusa | `docker service ps archgate-gw_warpgate`; targets admin; PG `warpgate` no `.110` |

Recuperação típica:

```bash
docker service update --force archgate-id_archguard-console
# ou redeploy
bash deploy/archguard/deploy-console.sh
```

---

## 2. OpenBao sealed

```bash
systemctl status archgate-openbao-unseal.timer
systemctl start archgate-openbao-unseal.service
journalctl -u archgate-openbao-unseal.service -n 30 --no-pager
# manual: ver documentos/runbooks/openbao-unseal-lab.md
```

Console **não** deve carregar `OPENBAO_UNSEAL_KEY` em modo W1 (`ARCHGATE_LAB=0`).

---

## 3. archguard / SSO falha

```bash
curl -sk https://id.archgate.com.br/status
docker service logs --tail 80 archgate-id_archguardd
# OIDC discovery
curl -sk https://id.archgate.com.br/oauth2/openid/archguard-console/.well-known/openid-configuration | head
```

Break-glass: `idm_admin` via `archguardd recover-account` no container (só ops).

---

## 4. Postgres externo (.110)

```bash
# do runtime, com bootstrap
export PGPASSWORD=… # POSTGRES_SUPERUSER_PASSWORD
psql -h "$POSTGRES_HOST" -p "${POSTGRES_PORT:-5434}" -U "$POSTGRES_SUPERUSER" -d warpgate -c 'select 1'
```

Restore: [`backup-postgres-lab.md`](./backup-postgres-lab.md).

---

## 5. Disco cheio (recordings / backups)

```bash
df -h /var/lib/archgate /var/backups
# prune dumps
find /var/backups/archgate-pg -name '*.dump' -mtime +14 -ls
# recordings backup
systemctl start archgate-recordings-backup.service
```

---

## 6. Contatos (W1-OPS06)

| Papel | Contato |
|-------|--------|
| Dono plataforma | Edson Martins |
| Runtime host | `edson-ai` / `192.168.1.180` |
| PG infra | host `192.168.1.110` (coord. ops IntegrAllTech) |

_Atualizar telefones/e-mails internos conforme política da empresa._
