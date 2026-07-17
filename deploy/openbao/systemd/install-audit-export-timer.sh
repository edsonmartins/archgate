#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$(cd "$SCRIPT_DIR/.." && pwd)/export-audit.sh"
install -m 755 "$SRC" /usr/local/sbin/archgate-openbao-audit-export
install -m 644 "$SCRIPT_DIR/archgate-openbao-audit-export.service" /etc/systemd/system/
install -m 644 "$SCRIPT_DIR/archgate-openbao-audit-export.timer" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now archgate-openbao-audit-export.timer
systemctl status archgate-openbao-audit-export.timer --no-pager | head -12
echo "Run once: systemctl start archgate-openbao-audit-export.service"
