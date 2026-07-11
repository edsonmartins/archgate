#!/usr/bin/env bash
# Install OpenBao unseal + DB broker timer on ArchGate runtime host (root).
set -euo pipefail
REPO="${REPO_ROOT:-/root/archgate/repo}"
BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
UNIT_DIR="$(cd "$(dirname "$0")" && pwd)"

[[ -f "$BOOTSTRAP" ]] || { echo "missing $BOOTSTRAP" >&2; exit 1; }
[[ -f "$REPO/deploy/openbao/broker-warpgate-db.sh" ]] || { echo "missing broker script" >&2; exit 1; }

# --- scripts ---
install -m 755 "$REPO/deploy/openbao/broker-warpgate-db.sh" /usr/local/sbin/archgate-broker-warpgate-db
install -m 700 "$UNIT_DIR/archgate-openbao-unseal.sh" /usr/local/sbin/archgate-openbao-unseal

cat > /usr/local/sbin/archgate-broker-warpgate-db-run <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export BOOTSTRAP=/root/archgate/bootstrap.env
set -a
# shellcheck disable=SC1091
source "$BOOTSTRAP"
set +a
export OPENBAO_ADDR="${OPENBAO_ADDR:-http://127.0.0.1:8200}"
# All lab Postgres targets share OpenBao role lab-readonly
export TARGETS="${TARGETS:-rio-lab-postgres lab-postgres marra-lab-postgres}"
# Ensure unsealed before issue
/usr/local/sbin/archgate-openbao-unseal || true
exec /usr/local/sbin/archgate-broker-warpgate-db issue
EOF
chmod 700 /usr/local/sbin/archgate-broker-warpgate-db-run

# --- units ---
install -m 644 "$UNIT_DIR/archgate-openbao-unseal.service" /etc/systemd/system/
install -m 644 "$UNIT_DIR/archgate-openbao-unseal.timer" /etc/systemd/system/
install -m 644 "$UNIT_DIR/archgate-broker-db.timer" /etc/systemd/system/

cat > /etc/systemd/system/archgate-broker-db.service <<'EOF'
[Unit]
Description=ArchGate OpenBao to Warpgate DB credential broker
After=network-online.target docker.service archgate-openbao-unseal.service
Wants=network-online.target archgate-openbao-unseal.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/archgate-broker-warpgate-db-run
Nice=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
# Drop stale "active (exited)" from older RemainAfterExit=yes so start/timer re-run
systemctl stop archgate-openbao-unseal.service 2>/dev/null || true
systemctl reset-failed archgate-openbao-unseal.service 2>/dev/null || true
systemctl enable archgate-openbao-unseal.service
systemctl enable --now archgate-openbao-unseal.timer
systemctl enable --now archgate-broker-db.timer
systemctl start --no-block archgate-openbao-unseal.service 2>/dev/null || systemctl start archgate-openbao-unseal.service
systemctl start archgate-broker-db.service || true

echo "=== timers ==="
systemctl list-timers archgate-openbao-unseal.timer archgate-broker-db.timer --no-pager 2>/dev/null \
  || systemctl list-timers --all | grep archgate || true
echo "=== last unseal ==="
journalctl -u archgate-openbao-unseal.service -n 8 --no-pager || true
echo "=== last broker ==="
journalctl -u archgate-broker-db.service -n 12 --no-pager || true
echo "OK: unseal on boot + every 2m; broker every 20m (targets: rio/lab/marra postgres)"
