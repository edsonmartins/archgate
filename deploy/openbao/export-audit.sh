#!/usr/bin/env bash
# W1-EPH05 — export OpenBao audit log (file backend) to backup dir.
# Run on runtime host as root.
#
#   bash deploy/openbao/export-audit.sh
set -euo pipefail

BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
AUDIT_SRC="${OPENBAO_AUDIT_PATH:-/var/lib/archgate/openbao/audit}"
OUT="${BACKUP_DIR:-/var/backups/archgate-openbao-audit}"
STAMP=$(date +%Y%m%d-%H%M%S)
RETENTION_DAYS="${RETENTION_DAYS:-30}"

mkdir -p "$OUT"
chmod 700 "$OUT"

if [[ ! -d "$AUDIT_SRC" ]]; then
  # try common alternate
  if [[ -f /var/lib/archgate/openbao/audit.log ]]; then
    AUDIT_SRC=/var/lib/archgate/openbao
  else
    echo "audit path not found: $AUDIT_SRC" >&2
    exit 1
  fi
fi

dest="$OUT/openbao-audit-${STAMP}.tar.gz"
echo "[export] $AUDIT_SRC → $dest"
tar -czf "$dest" -C "$(dirname "$AUDIT_SRC")" "$(basename "$AUDIT_SRC")" 2>/dev/null \
  || tar -czf "$dest" -C "$AUDIT_SRC" .
ls -lh "$dest"

if [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] && [[ "$RETENTION_DAYS" -gt 0 ]]; then
  find "$OUT" -type f -name 'openbao-audit-*.tar.gz' -mtime "+${RETENTION_DAYS}" -delete || true
fi
echo "[export] done"
