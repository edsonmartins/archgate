#!/usr/bin/env bash
# Install daily PG backup timer on ArchGate runtime (root).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_SRC="$(cd "$SCRIPT_DIR/.." && pwd)/backup-archgate-pg.sh"
[[ -f "$BACKUP_SRC" ]] || { echo "missing $BACKUP_SRC" >&2; exit 1; }

install -m 755 "$BACKUP_SRC" /usr/local/sbin/archgate-pg-backup
install -m 644 "$SCRIPT_DIR/archgate-pg-backup.service" /etc/systemd/system/
install -m 644 "$SCRIPT_DIR/archgate-pg-backup.timer" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now archgate-pg-backup.timer
systemctl status archgate-pg-backup.timer --no-pager | head -15
echo "Run once: systemctl start archgate-pg-backup.service && journalctl -u archgate-pg-backup.service -n 30 --no-pager"
