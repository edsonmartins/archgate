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

## Dump (no host com rede ao PG)

```bash
set -a
source /root/archgate/bootstrap.env   # ou export manual
set +a

STAMP=$(date +%Y%m%d-%H%M%S)
OUT=/var/backups/archgate-pg
mkdir -p "$OUT"
chmod 700 "$OUT"

export PGPASSWORD="$POSTGRES_SUPERUSER_PASSWORD"
HOST="${POSTGRES_HOST:-192.168.1.110}"
PORT="${POSTGRES_PORT:-5434}"
USER="${POSTGRES_SUPERUSER:-postgres}"

for db in warpgate guacamole archguard_console; do
  pg_dump -h "$HOST" -p "$PORT" -U "$USER" -Fc -f "$OUT/${db}-${STAMP}.dump" "$db"
  ls -lh "$OUT/${db}-${STAMP}.dump"
done
```

## Restore dry-run (lab only — DB de teste)

```bash
# NÃO rodar em produção sem janela. Exemplo em DB temporário:
# createdb -h ... archguard_console_restore_test
# pg_restore -h ... -d archguard_console_restore_test /var/backups/archgate-pg/archguard_console-….dump
```

## Checklist F4.1 / F4.2

- [ ] Dump dos 3 DBs executado (data: ________)
- [ ] Arquivos em path com permissão 700
- [ ] Restore dry-run documentado (data: ________)
- [ ] Retenção / cópia off-host definida

## Notas

- Gravações Warpgate (`/var/lib/archgate/warpgate/recordings`) **não** estão no PG — backup de filesystem à parte.
- SQLite activity log: `/var/lib/archgate/console/archguard.sqlite` no runtime.
