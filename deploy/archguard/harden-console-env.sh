#!/usr/bin/env bash
# W1-SEC01/02/03 — strip privileged secrets from console service (runtime).
# Does not rebuild image. Safe to re-run.
#
#   ARCHGATE_LAB=0 bash deploy/archguard/harden-console-env.sh
#   ARCHGATE_LAB=1 bash ...   # re-enable lab tokens (from bootstrap)
set -euo pipefail

BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
SVC="${CONSOLE_SERVICE:-archgate-id_archguard-console}"
LAB="${ARCHGATE_LAB:-0}"

[[ -f "$BOOTSTRAP" ]] && { set -a; # shellcheck disable=SC1090
  source "$BOOTSTRAP"; set +a; }

echo "==> harden $SVC ARCHGATE_LAB=$LAB"

ARGS=(--env-add "ARCHGATE_LAB=${LAB}")
if [[ -n "${OPENBAO_APP_TOKEN:-}${OPENBAO_TOKEN:-}" ]]; then
  ARGS+=(--env-add "OPENBAO_APP_TOKEN=${OPENBAO_APP_TOKEN:-${OPENBAO_TOKEN}}")
fi

if [[ "$LAB" == "1" ]]; then
  [[ -n "${OPENBAO_ROOT_TOKEN:-}" ]] && ARGS+=(--env-add "OPENBAO_ROOT_TOKEN=${OPENBAO_ROOT_TOKEN}")
  [[ -n "${OPENBAO_UNSEAL_KEY:-}" ]] && ARGS+=(--env-add "OPENBAO_UNSEAL_KEY=${OPENBAO_UNSEAL_KEY}")
else
  docker service update \
    --env-rm OPENBAO_ROOT_TOKEN \
    --env-rm OPENBAO_UNSEAL_KEY \
    --env-rm ARCHGUARD_E2E_LOGIN \
    "$SVC" 2>/dev/null || true
fi
# Swarm internal HTTPS to Traefik (WARPGATE_CONNECT_HOST) often needs insecure TLS until private CA.
# Default: keep NODE_TLS_REJECT_UNAUTHORIZED=0 on runtime; set STRICT_TLS=1 to force verify.
if [[ "${STRICT_TLS:-0}" == "1" ]]; then
  docker service update --env-rm NODE_TLS_REJECT_UNAUTHORIZED "$SVC" 2>/dev/null || true
else
  ARGS+=(--env-add "NODE_TLS_REJECT_UNAUTHORIZED=0")
fi

docker service update "${ARGS[@]}" "$SVC"
echo "==> env keys (no values):"
docker service inspect "$SVC" --format '{{range .Spec.TaskTemplate.ContainerSpec.Env}}{{println .}}{{end}}' \
  | sed 's/=.*//' | grep -E 'OPENBAO|ARCHGATE|NODE_TLS|E2E' | sort
echo "OK harden done"
