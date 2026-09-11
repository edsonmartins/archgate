#!/usr/bin/env bash
# Run full W0 automated suite on ArchGate runtime (root).
#   bash deploy/validation/w0-all.sh
#   SKIP_OFFBOARD=1 bash deploy/validation/w0-all.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
[[ -f "$BOOTSTRAP" ]] && { set -a; # shellcheck disable=SC1090
  source "$BOOTSTRAP"; set +a; }
[[ -f /root/archgate/uat-credentials.env ]] && { set -a; # shellcheck disable=SC1090
  source /root/archgate/uat-credentials.env; set +a; }

FAIL=0
run() {
  local name="$1"
  shift
  echo ""
  echo "########## $name ##########"
  if "$@"; then
    echo "########## $name OK ##########"
  else
    echo "########## $name FAIL ##########" >&2
    FAIL=$((FAIL+1))
  fi
}

run "w0-guac-session" bash deploy/validation/w0-guac-session.sh

echo ""
echo "=============================================="
echo " W0-ALL complete  failures=$FAIL"
echo " Remaining: human §6 signature + W0-B peer Rio real"
echo "=============================================="
[[ "$FAIL" -eq 0 ]]
