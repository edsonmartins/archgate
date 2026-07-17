#!/usr/bin/env bash
# W0 automated validation (PLAN-PRODUTO-100 / PLAN-HOMOLOGACAO-MVP).
# Run on ArchGate runtime as root:
#   bash deploy/validation/w0-validate.sh
#
# Does NOT replace human browser UAT (W0-A01..A07) or real client peer (W0-B*).
set -euo pipefail

BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
UAT_CREDS="${UAT_CREDS_FILE:-/root/archgate/uat-credentials.env}"
PASS=0
FAIL=0
SKIP=0

log()  { echo "  [OK] $*"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }
skip() { echo "  [SKIP] $*"; SKIP=$((SKIP+1)); }
step() { echo -e "\n=== $* ==="; }

[[ -f "$BOOTSTRAP" ]] && { set -a; # shellcheck disable=SC1090
  source "$BOOTSTRAP"; set +a; }
[[ -f "$UAT_CREDS" ]] && { set -a; # shellcheck disable=SC1090
  source "$UAT_CREDS"; set +a; }

step "0. Core services"
for svc in archgate-edge_traefik archgate-id_kanidmd archgate-id_archguard-console \
  archgate-gw_warpgate archgate-gw_guacamole archgate-gw_oauth2-proxy \
  archgate-secrets_openbao; do
  rep=$(docker service ls --format '{{.Name}} {{.Replicas}}' | awk -v s="$svc" '$1==s{print $2}')
  if [[ "$rep" == "1/1" ]]; then log "$svc $rep"; else fail "$svc replicas=$rep"; fi
done

step "1. OpenBao unsealed"
CID=$(docker ps -q -f name=archgate-secrets_openbao | head -1)
if [[ -n "$CID" ]] && docker exec "$CID" bao status 2>/dev/null | grep -q 'Sealed.*false'; then
  log "OpenBao Sealed false"
else
  fail "OpenBao sealed or unreachable"
fi

step "2. HTTPS edge"
for h in console.archgate.com.br id.archgate.com.br wg.archgate.com.br guac.archgate.com.br; do
  code=$(curl -skS -o /dev/null -w '%{http_code}' -m 10 "https://$h/" || echo ERR)
  case "$code" in
    200|302|303|307) log "$h HTTP $code" ;;
    *) fail "$h HTTP $code" ;;
  esac
done

step "3. Operator bastion (uat-op-a if present)"
if [[ -n "${UAT_PASS_uat_op_a:-}" ]] && command -v python3 >/dev/null; then
  python3 - <<'PY' && log "SSH uat-op-a:rio-lab-ssh" || fail "SSH uat-op-a:rio-lab-ssh"
import os, pexpect, sys
pw = os.environ["UAT_PASS_uat_op_a"]
cmd = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password -o PubkeyAuthentication=no -p 2222 uat-op-a:rio-lab-ssh@127.0.0.1 hostname"
child = pexpect.spawn(cmd, timeout=25, encoding="utf-8")
i = child.expect(["password:", "Password:", pexpect.EOF, pexpect.TIMEOUT])
if i in (0,1):
    child.sendline(pw)
    child.expect(pexpect.EOF, timeout=20)
out = child.before or ""
sys.exit(0 if out.strip() else 1)
PY
  python3 - <<'PY' && log "isolação marra denied" || fail "isolação marra"
import os, pexpect, sys
pw = os.environ["UAT_PASS_uat_op_a"]
cmd = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password -o PubkeyAuthentication=no -p 2222 uat-op-a:marra-lab-ssh@127.0.0.1 hostname"
child = pexpect.spawn(cmd, timeout=25, encoding="utf-8")
i = child.expect(["password:", "Password:", pexpect.EOF, pexpect.TIMEOUT])
if i in (0,1):
    child.sendline(pw)
    child.expect(pexpect.EOF, timeout=20)
out = (child.before or "") + str(child.after or "")
sys.exit(0 if "Permission denied" in out else 1)
PY
else
  skip "UAT_PASS_uat_op_a or pexpect missing — run provision-uat-users.sh"
fi

if command -v psql >/dev/null && [[ -n "${UAT_PASS_uat_op_a:-}" ]]; then
  export PGPASSWORD="$UAT_PASS_uat_op_a"
  if timeout 15 psql "host=127.0.0.1 port=55432 user=uat-op-a:rio-lab-postgres dbname=archgate_lab sslmode=require" \
    -t -A -c 'select 1' 2>/dev/null | grep -q 1; then
    log "PG uat-op-a:rio-lab-postgres"
  else
    fail "PG uat-op-a:rio-lab-postgres"
  fi
else
  skip "psql or UAT password missing for PG check"
fi

step "4. Guac SSO gate"
code=$(curl -skS -o /dev/null -w '%{http_code}' -m 10 "https://guac.archgate.com.br/" || echo ERR)
[[ "$code" == "302" ]] && log "guac portão $code" || fail "guac expected 302 got $code"

step "5. Warpgate admin from console container"
CCID=$(docker ps -q -f name=archgate-id_archguard-console | head -1)
if [[ -n "$CCID" ]]; then
  if docker exec "$CCID" node -e '
const https=require("https");
const c=process.env.WARPGATE_CONNECT_HOST||"archgate-edge_traefik";
const h=process.env.WARPGATE_HOST||"wg.archgate.com.br";
const u=process.env.WARPGATE_ADMIN_USER||"admin";
const p=process.env.WARPGATE_ADMIN_PASSWORD||"";
function req(m,path,hdrs,body){return new Promise((res,rej)=>{const r=https.request({hostname:c,port:443,method:m,path,servername:h,headers:Object.assign({Host:h},hdrs||{}),rejectUnauthorized:false,timeout:15000},x=>{const b=[];x.on("data",d=>b.push(d));x.on("end",()=>res({s:x.statusCode,h:x.headers,b:Buffer.concat(b).toString()}));});r.on("error",rej);if(body)r.write(body);r.end();});}
(async()=>{
  const body=JSON.stringify({username:u,password:p});
  const login=await req("POST","/@warpgate/api/auth/login",{"Content-Type":"application/json","Content-Length":String(Buffer.byteLength(body))},body);
  if(login.s<200||login.s>=300) process.exit(1);
  const raw=login.h["set-cookie"]; const list=Array.isArray(raw)?raw:(raw?[raw]:[]);
  const cookie=list.map(x=>x.split(";")[0]).join("; ");
  const t=await req("GET","/@warpgate/admin/api/targets",{Cookie:cookie});
  process.exit(t.s===200?0:1);
})().catch(()=>process.exit(1));
' 2>/dev/null; then
    log "WG admin API via console"
  else
    fail "WG admin API via console"
  fi
else
  fail "console container missing"
fi

step "6. Activity sqlite (console volume)"
if [[ -n "$CCID" ]]; then
  if docker exec "$CCID" node -e '
const Database=require("better-sqlite3");
const p=process.env.ARCHGUARD_DB_PATH||"/app/data/archguard.sqlite";
const db=new Database(p);
const row=db.prepare("SELECT name FROM sqlite_master WHERE type='\''table'\'' AND name='\''activity_log'\''").get();
process.exit(row?0:1);
' 2>/dev/null; then
    log "activity_log table present"
  else
    fail "activity_log table missing — redeploy console with db scrub fix or open /platform once"
  fi
fi

step "7. Site rio_quality SoT"
if [[ -n "${CONSOLE_DATABASE_URL:-}" ]]; then
  python3 - <<'PY' && log "rio_quality inventariado" || fail "rio_quality missing/not inventariado"
import os,re,subprocess,sys
u=os.environ["CONSOLE_DATABASE_URL"]
m=re.match(r"postgres(?:ql)?://([^:]+):([^@]+)@([^:/]+):?(\d+)?/(.+)", u)
user,pw,host,port,db=m.groups(); port=port or "5432"
env=os.environ.copy(); env["PGPASSWORD"]=pw
out=subprocess.check_output([
  "psql","-h",host,"-p",port,"-U",user,"-d",db,"-t","-A","-c",
  "select slug||'|'||stack||'|'||inventariado from sites where slug='rio_quality'"
], env=env, text=True).strip()
print(out)
sys.exit(0 if out.startswith("rio_quality|") and out.endswith("|t") or out.endswith("|1") else 1)
PY
else
  skip "CONSOLE_DATABASE_URL not in env of this shell"
fi

echo ""
echo "=============================================="
echo " W0 auto: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
echo " Human still required: W0-A (browser) + W0-B (peer real)"
echo "=============================================="
[[ "$FAIL" -eq 0 ]]
