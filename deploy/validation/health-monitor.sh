#!/usr/bin/env bash
# W1-OPS05 — minimal health check (cron/timer friendly). Exit 1 if any critical fail.
#   bash deploy/validation/health-monitor.sh
#   bash deploy/validation/health-monitor.sh --json
set -euo pipefail

JSON=0
[[ "${1:-}" == "--json" ]] && JSON=1

BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
[[ -f "$BOOTSTRAP" ]] && { set -a; # shellcheck disable=SC1090
  source "$BOOTSTRAP"; set +a; }

FAIL=0
declare -a LINES=()

ok()  { LINES+=("OK|$1"); }
bad() { LINES+=("FAIL|$1"); FAIL=$((FAIL+1)); }

# Swarm critical services
for svc in archgate-edge_traefik archgate-id_archguardd archgate-id_archguard-console \
  archgate-gw_warpgate archgate-gw_guacamole archgate-gw_oauth2-proxy \
  archgate-secrets_openbao; do
  rep=$(docker service ls --format '{{.Name}} {{.Replicas}}' 2>/dev/null | awk -v s="$svc" '$1==s{print $2}')
  if [[ "$rep" == "1/1" ]]; then ok "service $svc $rep"; else bad "service $svc replicas=${rep:-missing}"; fi
done

# OpenBao unsealed
CID=$(docker ps -q -f name=archgate-secrets_openbao | head -1)
if [[ -n "$CID" ]] && docker exec "$CID" bao status 2>/dev/null | grep -q 'Sealed.*false'; then
  ok "openbao unsealed"
else
  bad "openbao sealed or down"
fi

# HTTPS edge
for h in console.archgate.com.br id.archgate.com.br wg.archgate.com.br guac.archgate.com.br; do
  code=$(curl -skS -o /dev/null -w '%{http_code}' -m 8 "https://$h/" 2>/dev/null || echo ERR)
  case "$code" in
    200|302|303|307|308) ok "https $h $code" ;;
    404)
      # transient during service update — one retry
      sleep 2
      code=$(curl -skS -o /dev/null -w '%{http_code}' -m 8 "https://$h/" 2>/dev/null || echo ERR)
      case "$code" in
        200|302|303|307|308) ok "https $h $code (retry)" ;;
        *) bad "https $h $code" ;;
      esac
      ;;
    *) bad "https $h $code" ;;
  esac
done

# Disk for recordings
for d in /var/lib/archgate/warpgate/recordings /var/backups/archgate-pg; do
  if [[ -d "$d" ]]; then
    use=$(df -P "$d" 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $5}')
    if [[ -n "$use" && "$use" -ge 90 ]]; then
      bad "disk $d ${use}% full"
    else
      ok "disk $d ${use:-?}% used"
    fi
  fi
done

if [[ "$JSON" == "1" ]]; then
  python3 - <<PY
import json
lines = """$(printf '%s\n' "${LINES[@]}")""".strip().splitlines()
items=[]
for ln in lines:
  if not ln: continue
  st, msg = ln.split("|",1)
  items.append({"status": st, "check": msg})
print(json.dumps({"fail": $FAIL, "items": items}, indent=2))
PY
else
  for ln in "${LINES[@]}"; do
    st=${ln%%|*}; msg=${ln#*|}
    echo "  [$st] $msg"
  done
  echo "health_monitor failures=$FAIL"
fi
[[ "$FAIL" -eq 0 ]]
