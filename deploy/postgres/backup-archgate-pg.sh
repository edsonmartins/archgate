#!/usr/bin/env bash
# Automated dump of ArchGate PostgreSQL databases (W1-OPS01).
# Install on runtime host; cron/timer sources bootstrap.env (secrets never in git).
#
#   bash deploy/postgres/backup-archgate-pg.sh
#   RETENTION_DAYS=14 bash deploy/postgres/backup-archgate-pg.sh
set -euo pipefail

BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
OUT="${BACKUP_DIR:-/var/backups/archgate-pg}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
STAMP=$(date +%Y%m%d-%H%M%S)
LOG_TAG="archgate-pg-backup"

log() { echo "[$LOG_TAG] $*"; }
err() { echo "[$LOG_TAG] ERROR: $*" >&2; exit 1; }

[[ -f "$BOOTSTRAP" ]] || err "missing $BOOTSTRAP"
set -a
# shellcheck disable=SC1090
source "$BOOTSTRAP"
set +a

: "${POSTGRES_HOST:?}"
: "${POSTGRES_SUPERUSER_PASSWORD:?}"
PORT="${POSTGRES_PORT:-5434}"
USER="${POSTGRES_SUPERUSER:-postgres}"

mkdir -p "$OUT"
chmod 700 "$OUT"

export PGPASSWORD="$POSTGRES_SUPERUSER_PASSWORD"

DBS=(warpgate guacamole archguard_console)
for db in "${DBS[@]}"; do
  dest="$OUT/${db}-${STAMP}.dump"
  log "dumping $db → $dest"
  pg_dump -h "$POSTGRES_HOST" -p "$PORT" -U "$USER" -Fc -f "$dest" "$db"
  ls -lh "$dest"
done

# retention
if [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] && [[ "$RETENTION_DAYS" -gt 0 ]]; then
  log "pruning dumps older than ${RETENTION_DAYS}d in $OUT"
  find "$OUT" -type f -name '*.dump' -mtime "+${RETENTION_DAYS}" -print -delete || true
fi

log "done stamp=$STAMP"
ls -lh "$OUT" | tail -20
