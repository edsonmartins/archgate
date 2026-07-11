#!/usr/bin/env bash
# Point ArchGate console to Axis (prefer Spring lab, fallback stub).
set -euo pipefail
BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
[[ -f "$BOOTSTRAP" ]] && set -a && source "$BOOTSTRAP" && set +a

# Prefer Spring service if running
if docker service ls --format '{{.Name}}' | grep -qx 'archgate-axis-spring'; then
  AXIS_URL="${MENTORS_AXIS_URL:-http://archgate-axis-spring:9030}"
  EMAIL="${MENTORS_AXIS_EMAIL:-admin@mentorsaxis.com}"
  PASS="${MENTORS_AXIS_PASSWORD:-AxisLab2026!}"
  TENANT="${MENTORS_AXIS_TENANT_ID:-a9f814d2-4dae-41f3-851b-8aa3d4706561}"
  docker service update \
    --env-rm MENTORS_AXIS_TOKEN \
    --env-add "MENTORS_AXIS_MOCK=0" \
    --env-add "MENTORS_AXIS_URL=${AXIS_URL}" \
    --env-add "MENTORS_AXIS_EMAIL=${EMAIL}" \
    --env-add "MENTORS_AXIS_PASSWORD=${PASS}" \
    --env-add "MENTORS_AXIS_TENANT_ID=${TENANT}" \
    archgate-id_archguard-console
  echo "OK: console → Spring Axis ${AXIS_URL}"
else
  AXIS_URL="${MENTORS_AXIS_URL:-http://archgate-axis_stub:9030}"
  EMAIL="${MENTORS_AXIS_EMAIL:-admin@axis.lab}"
  PASS="${MENTORS_AXIS_PASSWORD:-AxisLab2026!}"
  TOKEN="${MENTORS_AXIS_TOKEN:-archgate-lab-axis-token}"
  docker service update \
    --env-add "MENTORS_AXIS_MOCK=0" \
    --env-add "MENTORS_AXIS_URL=${AXIS_URL}" \
    --env-add "MENTORS_AXIS_EMAIL=${EMAIL}" \
    --env-add "MENTORS_AXIS_PASSWORD=${PASS}" \
    --env-add "MENTORS_AXIS_TOKEN=${TOKEN}" \
    archgate-id_archguard-console
  echo "OK: console → stub Axis ${AXIS_URL}"
fi
echo "  UI: https://console.archgate.com.br/integrations/mentors-axis"
