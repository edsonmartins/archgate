#!/usr/bin/env bash
# Smoke: Kanidm OIDC (PKCE+consent) → OpenBao auth/jwt → ephemeral DB + SSH CA
set -euo pipefail
BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
set -a
# shellcheck disable=SC1090
source "$BOOTSTRAP"
set +a

BAO="${OPENBAO_ADDR:-http://127.0.0.1:8200}"
CLIENT_ID="${OPENBAO_OIDC_CLIENT_ID:-openbao}"
USER="${KANIDM_SMOKE_USER:-testuser}"
PASS="${KANIDM_SMOKE_PASS:-${ARCHGUARD_TESTUSER_PASSWORD:-TenantA-RioQuality-2026}}"
REDIRECT="${OPENBAO_OIDC_REDIRECT:-http://127.0.0.1:8250/oidc/callback}"
DOMAIN="${KANIDM_PUBLIC_URL:-https://id.archgate.com.br}"

log()  { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1" >&2; exit 1; }
step() { echo -e "\n=== $1 ==="; }

if ! curl -s "$BAO/v1/sys/health" | python3 -c 'import sys,json; d=json.load(sys.stdin); sys.exit(0 if not d.get("sealed") else 1)' 2>/dev/null; then
  : "${OPENBAO_UNSEAL_KEY:?}"
  curl -s -X PUT "$BAO/v1/sys/unseal" -H 'Content-Type: application/json' \
    -d "$(python3 -c "import json,os; print(json.dumps({'key':os.environ['OPENBAO_UNSEAL_KEY']}))")" >/dev/null
fi

step "1. Preflight"
curl -s -H "X-Vault-Token: $OPENBAO_ROOT_TOKEN" "$BAO/v1/auth/jwt/role/archgate-operator" \
  | python3 -c 'import sys,json; d=json.load(sys.stdin); assert "data" in d, d; print("    policies", d["data"].get("token_policies") or d["data"].get("policies"))'
log "OpenBao JWT role archgate-operator configured"

step "2. Kanidm OIDC token (auth + consent + PKCE, no-follow redirect)"
export USER PASS CLIENT_ID REDIRECT BAO DOMAIN
TOKENS=$(python3 <<'PY'
import base64, hashlib, json, os, re, ssl, subprocess, tempfile, urllib.parse, urllib.request

ctx = ssl._create_unverified_context()
domain = os.environ["DOMAIN"].rstrip("/")
user = os.environ["USER"]
password = os.environ["PASS"]
client_id = os.environ["CLIENT_ID"]
redirect = os.environ["REDIRECT"]

def b64url(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).decode().rstrip("=")

verifier = b64url(os.urandom(40))
challenge = b64url(hashlib.sha256(verifier.encode()).digest())
state = b64url(os.urandom(16))

def post_auth(data, headers=None):
    h = {"Content-Type": "application/json"}
    if headers:
        h.update(headers)
    req = urllib.request.Request(
        domain + "/v1/auth", data=json.dumps(data).encode(), headers=h, method="POST"
    )
    r = urllib.request.urlopen(req, context=ctx, timeout=30)
    return dict(r.headers), json.loads(r.read().decode())

h1, _ = post_auth({"step": {"init": user}})
sid = h1.get("X-Kanidm-Auth-Session-Id") or h1.get("x-kanidm-auth-session-id")
hdr = {"X-Kanidm-Auth-Session-Id": sid or ""}
post_auth({"step": {"begin": "password"}}, hdr)
_, b3 = post_auth({"step": {"cred": {"password": password}}}, hdr)
api_tok = b3.get("state", {}).get("success")
if not api_tok:
    raise SystemExit("kanidm auth failed: " + json.dumps(b3))

params = urllib.parse.urlencode(
    {
        "response_type": "code",
        "client_id": client_id,
        "redirect_uri": redirect,
        "scope": "openid profile email groups",
        "state": state,
        "code_challenge": challenge,
        "code_challenge_method": "S256",
    }
)
auth_url = domain + "/oauth2/authorise?" + params


def curl_nofollow(method, url, headers=None, data=None):
    """HTTP call that never follows redirects (callback is 127.0.0.1:8250)."""
    hdr_path = tempfile.mktemp(prefix="kjwt_hdr_")
    out_path = tempfile.mktemp(prefix="kjwt_out_")
    cmd = [
        "curl", "-sk", "--max-redirs", "0",
        "-D", hdr_path, "-o", out_path, "-w", "%{http_code}",
        "-X", method, url,
    ]
    for k, v in (headers or {}).items():
        cmd += ["-H", f"{k}: {v}"]
    body_path = None
    if data is not None:
        body_path = tempfile.mktemp(prefix="kjwt_body_")
        with open(body_path, "w") as f:
            f.write(data if isinstance(data, str) else data.decode())
        cmd += ["--data-binary", f"@{body_path}"]
    try:
        http_code = subprocess.check_output(cmd, text=True).strip()
        headers_txt = open(hdr_path).read()
        body = open(out_path).read()
    finally:
        for p in (hdr_path, out_path, body_path):
            if p:
                try:
                    os.unlink(p)
                except OSError:
                    pass
    m = re.search(r"(?im)^location:\s*(.+)$", headers_txt)
    location = m.group(1).strip() if m else ""
    return int(http_code), location, body, headers_txt


def extract_code(location: str, body: str = "") -> str | None:
    for src in (location, body):
        if not src:
            continue
        # Prefer parse_qs (handles full JWE codes); regex only as fallback
        q = urllib.parse.parse_qs(urllib.parse.urlparse(src.strip()).query)
        if "code" in q and q["code"][0]:
            return q["code"][0]
        m = re.search(r"[?&]code=([^&\s\"']+)", src)
        if m:
            return urllib.parse.unquote(m.group(1))
    return None


http_code, loc, body, _ = curl_nofollow(
    "GET", auth_url, headers={"Authorization": f"Bearer {api_tok}"}
)
code = extract_code(loc, body)

if code is None and body.strip().startswith("{"):
    consent_body = json.loads(body)
    if "ConsentRequested" in consent_body:
        consent = consent_body["ConsentRequested"]["consent_token"]
        # consent_token is typically a string — send as JSON string body
        permit_body = json.dumps(consent)
        http_code, loc, body, _ = curl_nofollow(
            "POST",
            domain + "/oauth2/authorise/permit",
            headers={
                "Authorization": f"Bearer {api_tok}",
                "Content-Type": "application/json",
            },
            data=permit_body,
        )
        code = extract_code(loc, body)
        if code is None:
            raise SystemExit(
                f"permit no code (http={http_code}): loc={loc[:200]!r} body={body[:200]!r}"
            )
    elif isinstance(consent_body, dict) and consent_body.get("code"):
        code = consent_body["code"]
    else:
        raise SystemExit(f"unexpected authorise body: {body[:400]}")

if not code:
    raise SystemExit(
        f"no auth code (http={http_code}): loc={loc[:200]!r} body={body[:200]!r}"
    )

disc = json.loads(
    urllib.request.urlopen(
        domain + f"/oauth2/openid/{client_id}/.well-known/openid-configuration",
        context=ctx,
    ).read()
)
data = urllib.parse.urlencode(
    {
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": redirect,
        "client_id": client_id,
        "code_verifier": verifier,
    }
).encode()
tok = json.loads(
    urllib.request.urlopen(
        urllib.request.Request(
            disc["token_endpoint"],
            data=data,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        ),
        context=ctx,
        timeout=30,
    ).read()
)
print(json.dumps(tok))
PY
)

ID_TOKEN=$(echo "$TOKENS" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("id_token") or "")')
ACCESS=$(echo "$TOKENS" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("access_token") or "")')
[[ -n "$ID_TOKEN" || -n "$ACCESS" ]] || fail "no OIDC tokens"
# Prefer id_token for claims; fallback access_token
JWT="${ID_TOKEN:-$ACCESS}"
# show claims
echo "$JWT" | python3 -c '
import sys,base64,json
t=sys.stdin.read().strip().split(".")[1]
t+="="*((4-len(t)%4)%4)
print("    claims", json.dumps(json.loads(base64.urlsafe_b64decode(t)), indent=2)[:800])
'
log "OIDC tokens obtained for $USER"

step "3. OpenBao JWT login"
LOGIN=$(JWT="$JWT" BAO="$BAO" python3 <<'PY'
import json, os, urllib.request, urllib.error
body = json.dumps({"role": "archgate-operator", "jwt": os.environ["JWT"]}).encode()
req = urllib.request.Request(
    os.environ["BAO"] + "/v1/auth/jwt/login",
    data=body,
    headers={"Content-Type": "application/json"},
    method="POST",
)
try:
    print(urllib.request.urlopen(req, timeout=30).read().decode())
except urllib.error.HTTPError as e:
    err = e.read().decode()
    print(err)
    raise SystemExit(f"jwt login HTTP {e.code}")
PY
)
echo "$LOGIN" | python3 -c 'import sys,json; d=json.load(sys.stdin); assert "auth" in d, d; print("    policies", d["auth"].get("policies")); print("    meta", d["auth"].get("metadata"))'
CT=$(echo "$LOGIN" | python3 -c 'import sys,json; print(json.load(sys.stdin)["auth"]["client_token"])')
log "OpenBao authenticated via Kanidm JWT"

step "4. Issue ephemeral DB cred with identity-bound token"
CRED=$(curl -s -H "X-Vault-Token: $CT" "$BAO/v1/database/creds/lab-readonly")
echo "$CRED" | python3 -c 'import sys,json; d=json.load(sys.stdin); assert "data" in d, d; print("    user", d["data"]["username"]); print("    lease", (d.get("lease_id") or "")[:56])'
log "database/creds issued under Kanidm-authenticated OpenBao session"

step "5. SSH sign with same token"
ssh-keygen -t ed25519 -f /tmp/kjwt -N '' -q
SIGN=$(curl -s -X POST -H "X-Vault-Token: $CT" -H 'Content-Type: application/json' \
  -d "$(python3 -c "import json,pathlib; print(json.dumps({'public_key':pathlib.Path('/tmp/kjwt.pub').read_text(),'valid_principals':'labuser','ttl':'5m'}))")" \
  "$BAO/v1/ssh/sign/lab-user")
echo "$SIGN" | python3 -c 'import sys,json; d=json.load(sys.stdin); assert "data" in d, d; print("    cert serial", d["data"].get("serial_number"))'
rm -f /tmp/kjwt /tmp/kjwt.pub
log "ssh/sign allowed for Kanidm-bound token"

echo ""
echo "=============================================="
echo " KANIDM → OPENBAO JWT AUTH PASSED"
echo "=============================================="
echo "  User: $USER (OIDC client $CLIENT_ID)"
echo "  OpenBao role: archgate-operator"
echo "  Issued: DB dynamic + SSH CA sign"
echo "=============================================="
