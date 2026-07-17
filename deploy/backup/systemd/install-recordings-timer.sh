#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$(cd "$SCRIPT_DIR/.." && pwd)/backup-recordings.sh"
install -m 755 "$SRC" /usr/local/sbin/archgate-recordings-backup
install -m 644 "$SCRIPT_DIR/archgate-recordings-backup.service" /etc/systemd/system/
install -m 644 "$SCRIPT_DIR/archgate-recordings-backup.timer" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now archgate-recordings-backup.timer
systemctl status archgate-recordings-backup.timer --no-pager | head -12
echo "Run once: systemctl start archgate-recordings-backup.service"
