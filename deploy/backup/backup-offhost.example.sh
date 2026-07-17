#!/usr/bin/env bash
# W1-OPS01 follow-up — copy local backups off-host (NAS/S3/rsync).
# Example only: fill REMOTE and enable from cron after lab validation.
#
#   REMOTE=backup@nas:/data/archgate bash deploy/backup/backup-offhost.example.sh
set -euo pipefail

REMOTE="${REMOTE:?set REMOTE=user@host:/path}"
SRC_DIRS=(
  /var/backups/archgate-pg
  /var/backups/archgate-recordings
  /var/backups/archgate-openbao-audit
)

for d in "${SRC_DIRS[@]}"; do
  [[ -d "$d" ]] || continue
  echo "[offhost] rsync $d → $REMOTE/"
  rsync -a --partial --inplace "$d/" "$REMOTE/$(basename "$d")/"
done
echo "[offhost] done"
