#!/usr/bin/env bash
# Deploy Mentors Axis HTTP stub (contrato live para CP-7 lab)
set -euo pipefail

REPO="${REPO_ROOT:-/root/archgate/repo}"
SRC="${REPO}/deploy/mentors-axis/stub-api"
SVC="${AXIS_STUB_SERVICE:-archgate-axis_stub}"
DATA="${AXIS_STUB_DATA:-/var/lib/archgate/axis-stub}"
PORT="${AXIS_STUB_PORT:-9030}"

mkdir -p "$DATA"
cp -f "$SRC/server.py" "$DATA/server.py"
chmod 755 "$DATA/server.py"

docker service rm "$SVC" 2>/dev/null || true
sleep 2

docker service create \
  --name "$SVC" \
  --network archgate-data \
  --network archgate-public \
  --constraint 'node.labels.archgate.runtime == true' \
  --publish mode=host,target="${PORT}",published="${PORT}" \
  --env AXIS_STUB_PORT="${PORT}" \
  --env AXIS_STUB_EMAIL="${AXIS_STUB_EMAIL:-admin@axis.lab}" \
  --env AXIS_STUB_PASSWORD="${AXIS_STUB_PASSWORD:-AxisLab2026!}" \
  --env AXIS_STUB_TOKEN="${AXIS_STUB_TOKEN:-archgate-lab-axis-token}" \
  --mount type=bind,source="${DATA}/server.py",target=/app/server.py,readonly \
  --restart-condition on-failure \
  --detach=true \
  python:3.12-slim \
  python /app/server.py

echo "==> wait :${PORT}"
for i in $(seq 1 30); do
  if curl -sf "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
    echo "OK: axis stub on http://127.0.0.1:${PORT}"
    curl -s "http://127.0.0.1:${PORT}/health"
    echo
    exit 0
  fi
  sleep 1
done
echo "FAIL: stub not healthy" >&2
docker service ps "$SVC" --no-trunc | head -5
exit 1
