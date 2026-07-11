#!/usr/bin/env bash
# Deploy Mentors Axis Spring (lab) against existing MySQL/MQTT on 192.168.1.110
# Image: mentors-axis:lab (build with Dockerfile.lab in axis-src)
set -euo pipefail

SVC="${AXIS_SPRING_SERVICE:-archgate-axis-spring}"
IMAGE="${AXIS_SPRING_IMAGE:-mentors-axis:lab}"
PUBLISH_PORT="${AXIS_SPRING_PUBLISH_PORT:-9031}"
MYSQL_HOST="${AXIS_MYSQL_HOST:-192.168.1.110}"
MYSQL_PORT="${AXIS_MYSQL_PORT:-3308}"
MYSQL_DB="${AXIS_MYSQL_DB:-axis}"
MYSQL_USER="${AXIS_MYSQL_USER:-axis}"
MYSQL_PASS="${AXIS_MYSQL_PASSWORD:-axis@727204}"
MQTT_URL="${AXIS_MQTT_BROKER_URL:-tcp://192.168.1.110:1883}"
MQTT_USER="${AXIS_MQTT_BROKER_USERNAME:-admin}"
MQTT_PASS="${AXIS_MQTT_BROKER_PASSWORD:-admin}"

docker image inspect "$IMAGE" >/dev/null 2>&1 || {
  echo "Image $IMAGE missing — build first (Dockerfile.lab)" >&2
  exit 1
}

docker service rm "$SVC" 2>/dev/null || true
sleep 2

docker service create \
  --name "$SVC" \
  --network archgate-data \
  --network archgate-public \
  --constraint 'node.labels.archgate.runtime == true' \
  --publish "mode=host,target=9030,published=${PUBLISH_PORT}" \
  --env "SERVER_SSL_ENABLED=false" \
  --env "SERVER_PORT=9030" \
  --env "SPRING_DATASOURCE_URL=jdbc:mysql://${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DB}" \
  --env "SPRING_DATASOURCE_USERNAME=${MYSQL_USER}" \
  --env "SPRING_DATASOURCE_PASSWORD=${MYSQL_PASS}" \
  --env "SPRING_DATASOURCE_DRIVER_CLASS_NAME=com.mysql.cj.jdbc.Driver" \
  --env "SPRING_JPA_HIBERNATE_DDL_AUTO=none" \
  --env "APPLICATION_MQTT_BROKERURL=${MQTT_URL}" \
  --env "APPLICATION_MQTT_USERNAME=${MQTT_USER}" \
  --env "APPLICATION_MQTT_PASSWORD=${MQTT_PASS}" \
  --env "APPLICATION_INSTANCE=0" \
  --restart-condition on-failure \
  "$IMAGE"

echo "==> wait :${PUBLISH_PORT}"
for i in $(seq 1 60); do
  if curl -sf --max-time 2 "http://127.0.0.1:${PUBLISH_PORT}/actuator/health" >/dev/null; then
    echo "OK: Spring Axis UP on http://127.0.0.1:${PUBLISH_PORT}"
    curl -s "http://127.0.0.1:${PUBLISH_PORT}/actuator/health"
    echo
    exit 0
  fi
  sleep 3
done
echo "FAIL: not healthy" >&2
docker service logs "$SVC" --tail 50
exit 1
