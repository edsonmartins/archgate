# Runbook — Backup PostgreSQL (lab / pré-homologação)

| Campo | Valor |
|-------|--------|
| Plano | [`../PLAN-HOMOLOGACAO-MVP.md`](../PLAN-HOMOLOGACAO-MVP.md) **F4.1** |
| Host PG | inventário: `192.168.1.110:5434` (externo ao Swarm) |
| Databases | `warpgate`, `guacamole`, `archguard_console` |
| Credencial | `POSTGRES_SUPERUSER` / `POSTGRES_SUPERUSER_PASSWORD` em `bootstrap.env` (não no git) |

## Tamanhos observados (2026-07-11)

| Database | Tamanho approx. |
|----------|-----------------|
| warpgate | ~10 MB |
| guacamole | ~9 MB |
| archguard_console | ~8 MB |

## Dump automático (recomendado — W1-OPS01)

No runtime:

```bash
# instalar timer diário 03:15
bash deploy/postgres/systemd/install-backup-timer.sh
# ou uma vez:
bash deploy/postgres/backup-archgate-pg.sh
# dumps em /var/backups/archgate-pg/  RETENTION_DAYS=14 (default)
```

## Dump manual (no host com rede ao PG)

```bash
bash deploy/postgres/backup-archgate-pg.sh
# ou equivalente legado com pg_dump (ver script)
```

## Restore dry-run (lab only — DB de teste)

**Executado 2026-07-11:** restore de `archguard_console-20260711-141705.dump` → DB temporário `archguard_console_restore_uat` → `sites count=6` → **DROP** do DB de teste. **PASS.**

```bash
set -a; source /root/archgate/bootstrap.env; set +a
export PGPASSWORD="$POSTGRES_SUPERUSER_PASSWORD"
HOST="${POSTGRES_HOST:-192.168.1.110}"
PORT="${POSTGRES_PORT:-5434}"
USER="${POSTGRES_SUPERUSER:-postgres}"
TESTDB=archguard_console_restore_uat
DUMP=/var/backups/archgate-pg/archguard_console-20260711-141705.dump

psql -h "$HOST" -p "$PORT" -U "$USER" -d postgres -c "DROP DATABASE IF EXISTS ${TESTDB};"
psql -h "$HOST" -p "$PORT" -U "$USER" -d postgres -c "CREATE DATABASE ${TESTDB};"
pg_restore -h "$HOST" -p "$PORT" -U "$USER" -d "$TESTDB" --no-owner "$DUMP"
psql -h "$HOST" -p "$PORT" -U "$USER" -d "$TESTDB" -c 'SELECT count(*) FROM sites;'
psql -h "$HOST" -p "$PORT" -U "$USER" -d postgres -c "DROP DATABASE ${TESTDB};"
```

## Checklist F4.1 / F4.2

- [x] Dump dos 3 DBs executado (data: **2026-07-11** · stamp `20260711-141705` em `/var/backups/archgate-pg/`)
- [x] Arquivos em path `/var/backups/archgate-pg` (dir 700 recomendado no host)
- [x] Restore dry-run documentado (data: **2026-07-11** · sites=6)
- [x] Retenção local **14 dias** via `RETENTION_DAYS` no script/timer
- [ ] Cópia off-host (S3/NAS) — W1 follow-up

## Notas

- Gravações Warpgate (`/var/lib/archgate/warpgate/recordings`) **não** estão no PG — backup de filesystem à parte.
- SQLite activity log: `/var/lib/archgate/console/archguard.sqlite` no runtime.
