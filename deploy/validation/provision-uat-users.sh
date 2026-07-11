#!/usr/bin/env bash
# Provision Kanidm + Warpgate personas for Homologação UAT (plano F2.2).
#
# Run on ArchGate runtime as root:
#   bash deploy/validation/provision-uat-users.sh
#
# Credentials → ${UAT_CREDS_FILE:-/root/archgate/uat-credentials.env} (mode 600)
# NEVER commit that file.
set -euo pipefail

BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
KANIDM_URL="${KANIDM_URL:-https://127.0.0.1:8443}"
KANIDM_SERVICE="${KANIDM_SERVICE:-archgate-id_kanidmd}"
DOMAIN="${KANIDM_DOMAIN:-id.archgate.com.br}"
UAT_CREDS_FILE="${UAT_CREDS_FILE:-/root/archgate/uat-credentials.env}"
WG_HOST_HEADER="${WARPGATE_HOST:-wg.archgate.com.br}"
WG_BASE="${WARPGATE_ADMIN_BASE:-https://127.0.0.1}"
CURL=(curl -sk)

PERSONAS=(
  "uat-admin|UAT Admin Platform|archguard_users,archguard_super_admins|admin,archgate-operators"
  "uat-op-a|UAT Operator Rio Quality|archguard_users,tenant_rio_quality|tenant-rio-quality"
  "uat-op-b|UAT Operator Grupo Marra|archguard_users,tenant_grupo_marra|tenant-grupo-marra"
  "uat-viewer|UAT Viewer No Tenant|archguard_users,archguard_viewers|"
)

log()  { echo "  [OK] $*"; }
warn() { echo "  [!!] $*"; }
err()  { echo "  [ERR] $*" >&2; exit 1; }
step() { echo -e "\n=== $* ==="; }

[[ -f "$BOOTSTRAP" ]] && { set -a; # shellcheck disable=SC1090
  source "$BOOTSTRAP"; set +a; }

command -v docker >/dev/null || err "docker missing"
command -v python3 >/dev/null || err "python3 missing"
command -v openssl >/dev/null || err "openssl missing"
python3 -c 'import pexpect' 2>/dev/null || err "python3-pexpect required (apt install python3-pexpect)"

gen_password() {
  openssl rand -base64 24 | tr -d '/+=' | head -c 24
}

recover_password() {
  local account="$1" cid="$2"
  docker exec "$cid" /sbin/kanidmd recover-account "$account" -c /data/server.toml 2>&1 \
    | sed -n 's/.*new_password: "\([^"]*\)".*/\1/p' | tail -1
}

kanidm_rest_auth() {
  local username="$1" password="$2"
  python3 - "$username" "$password" "$KANIDM_URL" <<'PY'
import json, subprocess, sys
user, password, url = sys.argv[1:4]
subprocess.run([
  "curl","-sk","-X","POST",f"{url}/v1/auth",
  "-H","Content-Type: application/json",
  "-d", json.dumps({"step":{"init":user}}),
  "-D","/tmp/k-h","-o","/tmp/k-b"
], check=True)
cookie=None
for line in open("/tmp/k-h"):
  if "auth-session-id=" in line:
    cookie=line.split("auth-session-id=")[1].split(";")[0].strip()
if not cookie:
  sys.exit(1)
subprocess.run([
  "curl","-sk","-X","POST",f"{url}/v1/auth",
  "-H","Content-Type: application/json",
  "-H",f"Cookie: auth-session-id={cookie}",
  "-d", json.dumps({"step":{"begin":"password"}}),
], check=True, stdout=subprocess.DEVNULL)
r=subprocess.check_output([
  "curl","-sk","-X","POST",f"{url}/v1/auth",
  "-H","Content-Type: application/json",
  "-H",f"Cookie: auth-session-id={cookie}",
  "-d", json.dumps({"step":{"cred":{"password":password}}}),
], text=True)
d=json.loads(r)
tok=d.get("state",{}).get("success","")
if not tok:
  sys.exit(1)
print(tok)
PY
}

api() {
  local token="$1" method="$2" path="$3" body="${4:-}"
  if [[ -n "$body" ]]; then
    "${CURL[@]}" -X "$method" "$KANIDM_URL$path" \
      -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d "$body"
  else
    "${CURL[@]}" -X "$method" "$KANIDM_URL$path" \
      -H "Authorization: Bearer $token" -H "Content-Type: application/json"
  fi
}

# pexpect: login + password update (kanidm CLI requires TTY)
set_passwords_pexpect() {
  local idm_pass="$1"
  shift
  # remaining: name=pass pairs as env file path
  local creds_file="$1"
  IDM_ADMIN_PASSWORD="$idm_pass" KANIDM_URL="$KANIDM_URL" UAT_CREDS_FILE="$creds_file" python3 - <<'PY'
import os, pexpect, tempfile, subprocess, time, json

idm_pass = os.environ["IDM_ADMIN_PASSWORD"]
kanidm_url = os.environ["KANIDM_URL"]
tokens = tempfile.mkdtemp()

def run_kanidm(args, send_lines=None, timeout=90):
    cmd = (
        f"docker run --rm -it --network host "
        f"-v {tokens}:/root/.cache "
        f"-e KANIDM_URL={kanidm_url} "
        f"kanidm/tools:1.10.4 /sbin/kanidm "
        + " ".join(args)
        + " --accept-invalid-certs --name idm_admin"
    )
    child = pexpect.spawn(cmd, timeout=timeout, encoding="utf-8", codec_errors="replace")
    try:
        if send_lines is None:
            child.expect(pexpect.EOF)
            return child.before
        for line in send_lines:
            time.sleep(0.25)
            child.expect([
                "Enter password", "password", "Password", "New password",
                "Confirm", "Do you want", r"\?", pexpect.TIMEOUT,
            ], timeout=20)
            child.sendline(line)
        child.expect(pexpect.EOF, timeout=timeout)
        return child.before
    except Exception as e:
        print(f"  [!!] pexpect {args}: {e}")
        try:
            child.close(force=True)
        except Exception:
            pass
        return None

mapping = {
    "UAT_PASS_uat_admin": "uat-admin",
    "UAT_PASS_uat_op_a": "uat-op-a",
    "UAT_PASS_uat_op_b": "uat-op-b",
    "UAT_PASS_uat_viewer": "uat-viewer",
}
creds = {}
with open(os.environ["UAT_CREDS_FILE"]) as f:
    for line in f:
        line=line.strip()
        if "=" in line and not line.startswith("#"):
            k,v=line.split("=",1)
            creds[k]=v

run_kanidm(["login"], send_lines=[idm_pass])
for envk, person in mapping.items():
    passw = creds.get(envk)
    if not passw:
        print(f"  [!!] missing {envk}")
        continue
    run_kanidm(["login"], send_lines=[idm_pass])
    out = run_kanidm(
        ["person", "credential", "update", person],
        send_lines=["password", passw, passw, "commit", "y"],
    )
    ok = out and "Success" in out
    print(f"  [{'OK' if ok else '!!'}] password {person}")
PY
}

ensure_warpgate_user() {
  local username="$1" password="$2" role_names_csv="$3"
  local admin_user="${WARPGATE_ADMIN_USER:-admin}"
  local admin_pass="${WARPGATE_ADMIN_PASSWORD:-}"
  [[ -n "$admin_pass" ]] || { warn "skip WG $username (no WARPGATE_ADMIN_PASSWORD)"; return 0; }

  local cj
  cj=$(mktemp)
  local code
  code=$(curl -sk -c "$cj" -b "$cj" \
    -X POST "${WG_BASE}/@warpgate/api/auth/login" \
    -H "Host: ${WG_HOST_HEADER}" \
    -H "Content-Type: application/json" \
    -d "$(python3 -c 'import json,sys; print(json.dumps({"username":sys.argv[1],"password":sys.argv[2]}))' "$admin_user" "$admin_pass")" \
    -o /tmp/wg-login.json -w '%{http_code}')
  [[ "$code" == "200" || "$code" == "201" ]] || { warn "WG admin login failed ($code)"; rm -f "$cj"; return 0; }

  local users_json uid
  users_json=$(curl -sk -b "$cj" -H "Host: ${WG_HOST_HEADER}" \
    "${WG_BASE}/@warpgate/admin/api/users")
  uid=$(echo "$users_json" | python3 -c 'import sys,json; u=sys.argv[1];
d=json.load(sys.stdin); print(next((x["id"] for x in d if x.get("username")==u),""))' "$username" 2>/dev/null || true)

  if [[ -z "$uid" ]]; then
    local created
    created=$(curl -sk -b "$cj" -H "Host: ${WG_HOST_HEADER}" \
      -X POST "${WG_BASE}/@warpgate/admin/api/users" \
      -H "Content-Type: application/json" \
      -d "$(python3 -c 'import json,sys; print(json.dumps({"username":sys.argv[1],"description":"UAT "+sys.argv[1]}))' "$username")")
    uid=$(echo "$created" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("id",""))' 2>/dev/null || true)
  fi
  [[ -n "$uid" ]] || { warn "WG no uid for $username"; rm -f "$cj"; return 0; }
  log "WG user $username id=$uid"

  curl -sk -b "$cj" -H "Host: ${WG_HOST_HEADER}" \
    -X POST "${WG_BASE}/@warpgate/admin/api/users/${uid}/credentials/passwords" \
    -H "Content-Type: application/json" \
    -d "$(python3 -c 'import json,sys; print(json.dumps({"password":sys.argv[1]}))' "$password")" \
    >/dev/null || true

  local roles_json
  roles_json=$(curl -sk -b "$cj" -H "Host: ${WG_HOST_HEADER}" \
    "${WG_BASE}/@warpgate/admin/api/roles")
  if [[ -n "$role_names_csv" ]]; then
    IFS=',' read -ra RARR <<<"$role_names_csv"
    for rn in "${RARR[@]}"; do
      rn=$(echo "$rn" | xargs)
      [[ -n "$rn" ]] || continue
      local rid
      rid=$(echo "$roles_json" | python3 -c 'import sys,json; n=sys.argv[1];
d=json.load(sys.stdin); print(next((x["id"] for x in d if x.get("name")==n),""))' "$rn" 2>/dev/null || true)
      [[ -n "$rid" ]] || { warn "WG role missing: $rn"; continue; }
      curl -sk -b "$cj" -H "Host: ${WG_HOST_HEADER}" \
        -X POST "${WG_BASE}/@warpgate/admin/api/users/${uid}/roles/${rid}" \
        -H "Content-Type: application/json" -d '{}' >/dev/null || true
      log "WG bind $username → $rn"
    done
  fi
  rm -f "$cj"
}

# ---------- main ----------
CID=$(docker ps --filter "name=${KANIDM_SERVICE}" --format '{{.ID}}' | head -1)
[[ -n "$CID" ]] || err "kanidmd not found"
STATUS=$("${CURL[@]}" "$KANIDM_URL/status" || true)
[[ "$STATUS" == "true" ]] || err "Kanidm unhealthy: $STATUS"

step "idm_admin auth"
IDM_ADMIN_PASSWORD=$(recover_password idm_admin "$CID")
[[ -n "$IDM_ADMIN_PASSWORD" ]] || err "empty idm_admin"
IDM_TOKEN=$(kanidm_rest_auth "idm_admin" "$IDM_ADMIN_PASSWORD") || err "idm_admin REST auth failed"
log "idm_admin token OK"

step "Ensure groups"
for g in tenant_rio_quality tenant_grupo_marra archguard_users archguard_super_admins archguard_viewers; do
  api "$IDM_TOKEN" POST "/v1/group" \
    "{\"attrs\":{\"name\":[\"$g\"],\"description\":[\"ArchGate $g\"]}}" >/dev/null 2>&1 || true
done

umask 077
# Keep existing passwords if file already present (re-run safe for memberships)
if [[ ! -f "$UAT_CREDS_FILE" ]]; then
  {
    echo "# ArchGate UAT credentials — $(date -Iseconds)"
    echo "# Generated by provision-uat-users.sh — DO NOT COMMIT"
    echo "DOMAIN=${DOMAIN}"
  } >"$UAT_CREDS_FILE"
  NEW_CREDS=1
else
  NEW_CREDS=0
  log "reusing passwords in $UAT_CREDS_FILE"
fi

step "Persons + memberships"
declare -A PASSWORDS
for entry in "${PERSONAS[@]}"; do
  IFS='|' read -r name display groups wg_roles <<<"$entry"
  if [[ "$NEW_CREDS" == "1" ]]; then
    pass=$(gen_password)
    {
      echo ""
      echo "# ${display}"
      echo "UAT_USER_${name//-/_}=${name}"
      echo "UAT_PASS_${name//-/_}=${pass}"
      echo "UAT_GROUPS_${name//-/_}=${groups}"
      echo "UAT_WG_ROLES_${name//-/_}=${wg_roles}"
    } >>"$UAT_CREDS_FILE"
  else
    # shellcheck disable=SC1090
    set -a; source "$UAT_CREDS_FILE"; set +a
    key="UAT_PASS_${name//-/_}"
    pass="${!key:-}"
    [[ -n "$pass" ]] || { pass=$(gen_password); echo "UAT_PASS_${name//-/_}=${pass}" >>"$UAT_CREDS_FILE"; }
  fi
  PASSWORDS["$name"]="$pass"

  api "$IDM_TOKEN" POST "/v1/person" \
    "{\"attrs\":{\"name\":[\"$name\"],\"displayname\":[\"$display\"]}}" >/dev/null 2>&1 || true
  log "person $name"

  spn="${name}@${DOMAIN}"
  IFS=',' read -ra GARR <<<"$groups"
  for g in "${GARR[@]}"; do
    g=$(echo "$g" | xargs)
    api "$IDM_TOKEN" POST "/v1/group/${g}/_attr/member" "[\"${spn}\"]" >/dev/null 2>&1 || true
  done
done
chmod 600 "$UAT_CREDS_FILE"

step "Set Kanidm passwords (pexpect + TTY)"
set_passwords_pexpect "$IDM_ADMIN_PASSWORD" "$UAT_CREDS_FILE"

step "Verify Kanidm auth"
# shellcheck disable=SC1090
set -a; source "$UAT_CREDS_FILE"; set +a
for name in uat-admin uat-op-a uat-op-b uat-viewer; do
  key="UAT_PASS_${name//-/_}"
  pass="${!key}"
  if kanidm_rest_auth "$name" "$pass" >/dev/null 2>&1; then
    log "auth OK $name"
  else
    warn "auth FAIL $name"
  fi
done

step "Warpgate users"
for entry in "${PERSONAS[@]}"; do
  IFS='|' read -r name display groups wg_roles <<<"$entry"
  ensure_warpgate_user "$name" "${PASSWORDS[$name]}" "$wg_roles"
done

step "Summary (no secrets)"
echo "  uat-admin  → super_admins · WG admin+operators"
echo "  uat-op-a   → tenant_rio_quality · WG tenant-rio-quality"
echo "  uat-op-b   → tenant_grupo_marra · WG tenant-grupo-marra"
echo "  uat-viewer → viewers only · WG no roles"
echo "  Credentials: $UAT_CREDS_FILE"
echo "  DONE F2.2"
