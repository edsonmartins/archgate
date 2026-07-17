#!/usr/bin/env bash
# W0-A partial: programmatic console session checks (lab only).
# Requires ARCHGUARD_E2E_LOGIN=1 and test-login route with uat-* support.
#
# Usage (on runtime):
#   bash deploy/validation/w0-console-session.sh
set -euo pipefail

BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
UAT_CREDS="${UAT_CREDS_FILE:-/root/archgate/uat-credentials.env}"
CONSOLE="${CONSOLE_URL:-https://console.archgate.com.br}"
PASS=0
FAIL=0

log()  { echo "  [OK] $*"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }
step() { echo -e "\n=== $* ==="; }

[[ -f "$BOOTSTRAP" ]] && { set -a; # shellcheck disable=SC1090
  source "$BOOTSTRAP"; set +a; }
[[ -f "$UAT_CREDS" ]] && { set -a; # shellcheck disable=SC1090
  source "$UAT_CREDS"; set +a; }

step "0. Ensure E2E login + UAT passwords on console service"
SVC=archgate-id_archguard-console
# shellcheck disable=SC2016
ENV_LINES=$(docker service inspect "$SVC" --format '{{range .Spec.TaskTemplate.ContainerSpec.Env}}{{println .}}{{end}}' 2>/dev/null || true)
if ! echo "$ENV_LINES" | grep -qx 'ARCHGUARD_E2E_LOGIN=1'; then
  echo "  enabling ARCHGUARD_E2E_LOGIN=1 (lab)..."
  docker service update --env-add ARCHGUARD_E2E_LOGIN=1 "$SVC" >/dev/null
fi
# inject UAT passwords if present on host
if [[ -n "${UAT_PASS_uat_admin:-}" ]]; then
  docker service update \
    --env-add "UAT_PASS_uat_admin=${UAT_PASS_uat_admin}" \
    --env-add "UAT_PASS_uat_op_a=${UAT_PASS_uat_op_a}" \
    --env-add "UAT_PASS_uat_op_b=${UAT_PASS_uat_op_b}" \
    --env-add "UAT_PASS_uat_viewer=${UAT_PASS_uat_viewer}" \
    "$SVC" >/dev/null
fi
# wait converge
for i in $(seq 1 30); do
  rep=$(docker service ls --format '{{.Name}} {{.Replicas}}' | awk '$1=="archgate-id_archguard-console"{print $2}')
  [[ "$rep" == "1/1" ]] && break
  sleep 2
done
sleep 3
log "console service ready"

login_user() {
  local user="$1"
  local jar
  jar=$(mktemp)
  # Do NOT use -L on test-login: first response is 307 + Set-Cookie; -L can confuse checks.
  local login_code
  login_code=$(curl -sk -c "$jar" -b "$jar" -o /dev/null -w '%{http_code}' \
    "${CONSOLE}/test-login?u=${user}" 2>/dev/null || echo ERR)
  local code
  code=$(curl -sk -c "$jar" -b "$jar" -o /tmp/console-body.html -w '%{http_code}' \
    "${CONSOLE}/dashboard" 2>/dev/null || echo ERR)
  local has_cookie=0
  grep -q archguard_session "$jar" 2>/dev/null && has_cookie=1 || true
  echo "$user|login=${login_code}|dash=${code}|cookie=${has_cookie}|$jar"
}

step "1. Session login per persona"
for u in testadmin uat-admin uat-op-a uat-op-b uat-viewer; do
  row=$(login_user "$u")
  IFS='|' read -r user login_code dash_code has_cookie jar <<<"$row"
  # row format: user|login=307|dash=200|cookie=1|jarpath
  login_code=${login_code#login=}
  dash_code=${dash_code#dash=}
  has_cookie=${has_cookie#cookie=}
  if [[ "$has_cookie" == "1" && "$dash_code" == "200" ]]; then
    log "login $user → session + dashboard 200 (login HTTP $login_code)"
  elif [[ "$has_cookie" == "1" ]]; then
    log "login $user → cookie set (dashboard HTTP $dash_code login $login_code)"
  else
    fail "login $user failed login=$login_code dash=$dash_code cookie=$has_cookie"
  fi
  rm -f "$jar"
done

step "2. Authenticated page probes (uat-admin)"
jar=$(mktemp)
curl -sk -c "$jar" -b "$jar" -o /dev/null "${CONSOLE}/test-login?u=uat-admin" 2>/dev/null || true
for path in /dashboard /sites /platform /gateways /audit /secrets; do
  code=$(curl -sk -b "$jar" -o /tmp/p.html -w '%{http_code}' "${CONSOLE}${path}" 2>/dev/null || echo ERR)
  if [[ "$code" == "200" ]]; then
    if grep -q 'ArchGuard Console' /tmp/p.html 2>/dev/null; then
      log "GET $path → $code (HTML shell)"
    else
      log "GET $path → $code"
    fi
  else
    fail "GET $path → $code"
  fi
done
rm -f "$jar"

step "3. Tenant scope smoke (uat-op-a vs uat-viewer)"
for u in uat-op-a uat-viewer; do
  jar=$(mktemp)
  curl -sk -c "$jar" -b "$jar" -o /dev/null "${CONSOLE}/test-login?u=$u" 2>/dev/null || true
  code=$(curl -sk -b "$jar" -o /tmp/sites-$u.html -w '%{http_code}' "${CONSOLE}/sites" 2>/dev/null || echo ERR)
  bytes=$(wc -c < /tmp/sites-$u.html | tr -d ' ')
  if [[ "$code" == "200" ]]; then
    log "/sites as $u → HTTP $code (${bytes}b)"
  else
    fail "/sites as $u → $code"
  fi
  rm -f "$jar"
done

step "4. Record activity (uat-admin) via sites list server path"
# Opening /platform after login is enough to keep session; activity rows from prior W0 remain.
jar=$(mktemp)
curl -sk -c "$jar" -b "$jar" -o /dev/null "${CONSOLE}/test-login?u=uat-admin" 2>/dev/null || true
code=$(curl -sk -b "$jar" -o /dev/null -w '%{http_code}' "${CONSOLE}/audit" 2>/dev/null || echo ERR)
[[ "$code" == "200" ]] && log "audit page shell $code" || fail "audit page $code"
CCID=$(docker ps -q -f name=archgate-id_archguard-console | head -1)
if [[ -n "$CCID" ]]; then
  cnt=$(docker exec "$CCID" node -e 'const D=require("better-sqlite3");const d=new D(process.env.ARCHGUARD_DB_PATH||"/app/data/archguard.sqlite");console.log(d.prepare("select count(*) as c from activity_log").get().c)' 2>/dev/null || echo 0)
  [[ "${cnt:-0}" -ge 1 ]] && log "activity_log rows=$cnt" || fail "activity_log empty"
fi
rm -f "$jar"

echo ""
echo "=============================================="
echo " W0 console session: PASS=$PASS FAIL=$FAIL"
echo " Note: full OIDC browser path still recommended once for revisor"
echo " Reminder: disable ARCHGUARD_E2E_LOGIN after UAT if desired"
echo "=============================================="
[[ "$FAIL" -eq 0 ]]
