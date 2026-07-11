#!/usr/bin/env bash
# Creates overlay networks used by ArchGate Swarm stacks (tasks 1.1 / 1.2).
set -euo pipefail

create_net() {
  local name="$1"
  if docker network inspect "$name" >/dev/null 2>&1; then
    echo "Network $name already exists"
  else
    docker network create -d overlay --attachable "$name"
    echo "Created network: $name"
  fi
}

create_net archgate-public
create_net archgate-data
echo "OK: overlay networks ready."
