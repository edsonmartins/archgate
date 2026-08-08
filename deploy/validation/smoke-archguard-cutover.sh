#!/usr/bin/env bash
# Smoke de virada archguard → ArchGuard.
#
# Roda ANTES de mexer no staging. Valida as premissas de que dependem três
# configurações (Warpgate role_mappings, OpenBao bound_claims/bound_audiences e
# a normalização de grupos do console) — todas deduzidas de leitura de código na
# auditoria de 2026-08-01, nenhuma exercitada contra um ArchGuard real.
#
# Duas camadas:
#
#   A. sem interação — discovery, JWKS, credencial de máquina, escrita via SA
#   B. exige um token de usuário (ARCHGATE_SMOKE_TOKEN) — formato do claim
#      `groups`, `aud`, vazamento de segredo de MFA, login no OpenBao
#
# Obter o token da camada B:
#   ARCHGATE_IDP=archguard ARCHGATE_IDP_URL=https://app.archguard.com.br \
#     archgate login
#   export ARCHGATE_SMOKE_TOKEN="$(archgate auth-header | sed 's/^Bearer //')"
#
# Sem o token, a camada B é PULADA (não falha) e o script diz o que faltou.
set -uo pipefail

IDP_URL="${ARCHGATE_IDP_URL:?defina ARCHGATE_IDP_URL (ex.: https://app.archguard.com.br)}"
IDP_URL="${IDP_URL%/}"
ORG="${ARCHGATE_IDP_ORG:-archgate}"
SA_CLIENT_ID="${ARCHGUARD_SA_CLIENT_ID:-}"
SA_CLIENT_SECRET="${ARCHGUARD_SA_CLIENT_SECRET:-}"
SMOKE_GROUP="${SMOKE_GROUP:-archgate-smoke-tmp}"
SMOKE_BIND_USER="${SMOKE_BIND_USER:-}"
TOKEN="${ARCHGATE_SMOKE_TOKEN:-}"
EXPECT_AUD="${EXPECT_AUD:-}"
BAO="${OPENBAO_ADDR:-}"
BAO_ROLE="${OPENBAO_ROLE:-archgate-operator}"

PASS=0
FAIL=0
SKIP=0

log()  { echo "  [OK]   $*"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $*" >&2; FAIL=$((FAIL + 1)); }
skip() { echo "  [SKIP] $*"; SKIP=$((SKIP + 1)); }
step() { echo; echo "=== $* ==="; }

need() { command -v "$1" >/dev/null 2>&1 || { echo "faltando: $1" >&2; exit 2; }; }
need curl
need python3

# jq não é premissa; python3 faz o parsing.
jget() { python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('$1',''))" 2>/dev/null; }

echo "ArchGuard cutover smoke"
echo "  idp   = $IDP_URL"
echo "  org   = $ORG"

# ─────────────────────────────────────────────────────────────────────────────
step "A1. Discovery"

DISC_URL="${IDP_URL}/.well-known/openid-configuration"
DISC=$(curl -sS -m 20 "$DISC_URL" || true)
if [ -z "$DISC" ]; then
  fail "discovery vazio em $DISC_URL"
  echo; echo "Sem discovery não há o que validar. Abortando."; exit 1
fi

ISSUER=$(echo "$DISC" | jget issuer)
JWKS_URI=$(echo "$DISC" | jget jwks_uri)
USERINFO=$(echo "$DISC" | jget userinfo_endpoint)
TOKEN_EP=$(echo "$DISC" | jget token_endpoint)

[ -n "$ISSUER" ]   && log "issuer = $ISSUER"            || fail "discovery sem issuer"
[ -n "$JWKS_URI" ] && log "jwks_uri = $JWKS_URI"        || fail "discovery sem jwks_uri"
[ -n "$TOKEN_EP" ] && log "token_endpoint = $TOKEN_EP"  || fail "discovery sem token_endpoint"

# O console deixou de montar `<issuer>/userinfo` justamente porque essa é a
# forma do archguard; no Casdoor o caminho é /api/userinfo.
if [ -z "$USERINFO" ]; then
  fail "discovery sem userinfo_endpoint — o BFF do Connect depende dele"
elif [ "$USERINFO" = "${ISSUER}/userinfo" ]; then
  skip "userinfo_endpoint == <issuer>/userinfo (forma archguard) — confirme o IdP"
else
  log "userinfo_endpoint = $USERINFO (não é a forma archguard)"
fi

if [ "$ISSUER" = "$IDP_URL" ]; then
  log "issuer único (não é por-cliente)"
else
  skip "issuer ($ISSUER) != ARCHGATE_IDP_URL ($IDP_URL) — confira o host público"
fi

# ─────────────────────────────────────────────────────────────────────────────
step "A2. JWKS"

JWKS=$(curl -sS -m 20 "$JWKS_URI" || true)
ALGS=$(echo "$JWKS" | python3 -c "
import json,sys
try:
    keys = json.load(sys.stdin).get('keys') or []
except Exception:
    keys = []
print(len(keys), ','.join(sorted({k.get('kty','?') for k in keys})), ','.join(sorted({k.get('kid','') for k in keys if k.get('kid')})))
" 2>/dev/null)
NKEYS=$(echo "$ALGS" | cut -d' ' -f1)
KTYS=$(echo "$ALGS" | cut -d' ' -f2)
KIDS=$(echo "$ALGS" | cut -d' ' -f3)

if [ "${NKEYS:-0}" -ge 1 ] 2>/dev/null; then
  log "JWKS com $NKEYS chave(s), kty=$KTYS"
else
  fail "JWKS sem chaves em $JWKS_URI"
fi
if [ -n "$KIDS" ]; then
  log "kid presente ($KIDS) — rotação com sobreposição é possível"
else
  fail "chaves sem kid — OpenBao não consegue seguir rotação"
fi

# ─────────────────────────────────────────────────────────────────────────────
step "A3. Credencial de máquina (client_credentials)"

if [ -z "$SA_CLIENT_ID" ] || [ -z "$SA_CLIENT_SECRET" ]; then
  skip "ARCHGUARD_SA_CLIENT_ID/SECRET não definidos — pulando A3/A4"
  SA_TOKEN=""
else
  SA_RESP=$(curl -sS -m 20 -X POST "${IDP_URL}/api/login/oauth/access_token" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -d "grant_type=client_credentials&client_id=${SA_CLIENT_ID}&client_secret=${SA_CLIENT_SECRET}" || true)
  SA_TOKEN=$(echo "$SA_RESP" | jget access_token)
  if [ -n "$SA_TOKEN" ]; then
    EXPIRES=$(echo "$SA_RESP" | jget expires_in)
    log "access_token obtido (expires_in=${EXPIRES:-?}s)"
    if [ -n "$EXPIRES" ] && [ "$EXPIRES" -gt 86400 ] 2>/dev/null; then
      skip "TTL de ${EXPIRES}s é longo para uma credencial de máquina"
    fi
  else
    fail "client_credentials falhou: $(echo "$SA_RESP" | head -c 200)"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
step "A4. Escrita via SA (grupo idempotente)"

sa_api() {
  local method="$1" path="$2" body="${3:-}"
  if [ -n "$body" ]; then
    curl -sS -m 20 -X "$method" "${IDP_URL}${path}" \
      -H "Authorization: Bearer ${SA_TOKEN}" \
      -H 'Content-Type: application/json' -d "$body"
  else
    curl -sS -m 20 -X "$method" "${IDP_URL}${path}" \
      -H "Authorization: Bearer ${SA_TOKEN}"
  fi
}

if [ -z "${SA_TOKEN:-}" ]; then
  skip "sem token de SA — pulando escrita"
else
  ADD=$(sa_api POST /api/add-group \
    "{\"owner\":\"${ORG}\",\"name\":\"${SMOKE_GROUP}\",\"displayName\":\"ArchGate smoke\",\"type\":\"Virtual\",\"isTopGroup\":true}" || true)
  ADD_STATUS=$(echo "$ADD" | jget status)

  GET=$(sa_api GET "/api/get-group?id=${ORG}%2F${SMOKE_GROUP}" || true)
  GET_STATUS=$(echo "$GET" | jget status)

  if [ "$GET_STATUS" = "ok" ]; then
    log "grupo ${ORG}/${SMOKE_GROUP} existe (add=${ADD_STATUS:-?})"
    echo "         remova depois: Groups → ${SMOKE_GROUP}"
  else
    fail "SA não conseguiu criar/ler o grupo: $(echo "$ADD$GET" | head -c 200)"
  fi

  if [ -n "$SMOKE_BIND_USER" ]; then
    U=$(sa_api GET "/api/get-user?id=${ORG}%2F${SMOKE_BIND_USER}" || true)
    if [ "$(echo "$U" | jget status)" = "ok" ]; then
      log "usuário ${SMOKE_BIND_USER} legível pela SA"
    else
      fail "SA não leu o usuário ${SMOKE_BIND_USER}"
    fi
  else
    skip "SMOKE_BIND_USER não definido — bind de membro não exercitado"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
step "B. Token de usuário"

if [ -z "$TOKEN" ]; then
  skip "ARCHGATE_SMOKE_TOKEN ausente — camada B inteira pulada"
  echo
  echo "  Para rodar a camada B (é ela que valida as premissas de risco):"
  echo "    ARCHGATE_IDP=archguard ARCHGATE_IDP_URL=${IDP_URL} archgate login"
  echo "    export ARCHGATE_SMOKE_TOKEN=\"\$(archgate auth-header | sed 's/^Bearer //')\""
else
  CLAIMS=$(SMOKE_JWT="$TOKEN" python3 <<'PY'
import base64, json, os
tok = (os.environ.get("SMOKE_JWT") or "").strip()
parts = tok.split(".")
if len(parts) < 2:
    print("{}")
else:
    p = parts[1] + "=" * ((4 - len(parts[1]) % 4) % 4)
    try:
        print(json.dumps(json.loads(base64.urlsafe_b64decode(p))))
    except Exception:
        print("{}")
PY
)
  if [ "$CLAIMS" = "{}" ]; then
    fail "não consegui decodificar o token (é um JWT?)"
  else
    # --- B1: aud ---------------------------------------------------------
    AUD=$(echo "$CLAIMS" | python3 -c "
import json,sys
a=json.load(sys.stdin).get('aud')
print(a[0] if isinstance(a,list) and a else (a or ''))")
    if [ -z "$AUD" ]; then
      fail "token sem aud"
    elif [ -n "$EXPECT_AUD" ] && [ "$AUD" != "$EXPECT_AUD" ]; then
      fail "aud=$AUD, esperado $EXPECT_AUD"
    else
      log "aud = $AUD"
      # No Casdoor o aud é o clientId (hex), não o nome da aplicação.
      case "$AUD" in
        archgate-connect|archguard-console|warpgate|guacamole|openbao)
          skip "aud parece nome de app, não clientId — confira bound_audiences do OpenBao" ;;
        *) log "aud tem forma de clientId (não é o nome da app)" ;;
      esac
    fi

    # --- B2: formato do claim groups (a premissa central) ----------------
    CLAIM_GROUPS=$(echo "$CLAIMS" | python3 -c "
import json,sys
g=json.load(sys.stdin).get('groups') or []
print('\n'.join(map(str,g)))")
    if [ -z "$CLAIM_GROUPS" ]; then
      fail "token sem claim groups — Warpgate/OpenBao/BFF dependem dele"
      echo "         confira scope 'groups' e tokenFields=[...,\"Groups\",...]"
    else
      echo "$CLAIM_GROUPS" | sed 's/^/         /'
      if echo "$CLAIM_GROUPS" | grep -q "^${ORG}/"; then
        log "groups qualificados como ${ORG}/<nome> — premissa CONFIRMADA"
        echo "         → Warpgate role_mappings e OpenBao bound_claims usam o prefixo"
      elif echo "$CLAIM_GROUPS" | grep -q '@'; then
        skip "groups no formato archguard (nome@domínio) — o IdP ativo ainda é o archguard?"
      else
        fail "groups SEM prefixo ${ORG}/ — premissa REFUTADA"
        echo "         → remova o prefixo de deploy/warpgate/deploy.sh e do bootstrap do OpenBao"
      fi
    fi

    # --- B3: user_claim --------------------------------------------------
    NAME=$(echo "$CLAIMS" | jget name)
    PREF=$(echo "$CLAIMS" | jget preferred_username)
    if [ -n "$NAME" ]; then
      log "claim name = $NAME (user_claim do OpenBao)"
    else
      fail "token sem claim name — OPENBAO_USER_CLAIM=name não vai casar"
    fi
    [ -n "$PREF" ] && skip "preferred_username presente ($PREF) — formato JWT-Standard?"

    # --- B4: vazamento de segredo de MFA ---------------------------------
    # refineUser() limpa só Password; TotpSecret e RecoveryCodes sobrevivem no
    # formato JWT (object/token_jwt.go). Este token viaja para Warpgate,
    # Guacamole e OpenBao.
    LEAKS=$(echo "$CLAIMS" | python3 -c "
import json,sys
d=json.load(sys.stdin)
bad=[k for k in ('totpSecret','recoveryCodes','passwordSalt','passwordType','mfaItems','ipWhitelist')
     if d.get(k) not in (None,'',[],{})]
print(','.join(bad))")
    if [ -z "$LEAKS" ]; then
      log "token não carrega segredo de MFA nem material de senha"
    else
      fail "TOKEN VAZA: $LEAKS"
      echo "         → tokenFormat deve ser JWT-Custom com tokenFields mínimos"
      echo "         → este token vai para Warpgate, Guacamole e OpenBao"
    fi

    # --- B5: campos do contrato v1 (informativo) -------------------------
    V1=$(echo "$CLAIMS" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(','.join(k for k in ('org','mid','acr','amr','sid','pcid') if k in d))")
    if [ -n "$V1" ]; then
      log "claims v1 presentes: $V1 (endpoints do pacote 006 montados)"
    else
      skip "sem claims v1 (org/mid/acr/sid) — esperado enquanto B1 do handoff não for feito"
    fi
  fi

  # --- B6: login no OpenBao ---------------------------------------------
  if [ -z "$BAO" ]; then
    skip "OPENBAO_ADDR não definido — login no cofre não exercitado"
  else
    BAO_RESP=$(curl -sS -m 20 -X POST "${BAO%/}/v1/auth/jwt/login" \
      -H 'Content-Type: application/json' \
      -d "$(SMOKE_ROLE="$BAO_ROLE" SMOKE_JWT="$TOKEN" python3 -c "
import json, os
print(json.dumps({'role': os.environ['SMOKE_ROLE'], 'jwt': os.environ['SMOKE_JWT']}))")" || true)
    CLIENT_TOKEN=$(echo "$BAO_RESP" | python3 -c "
import json,sys
try: print(json.load(sys.stdin).get('auth',{}).get('client_token',''))
except Exception: print('')" 2>/dev/null)
    if [ -n "$CLIENT_TOKEN" ]; then
      POLICIES=$(echo "$BAO_RESP" | python3 -c "
import json,sys
print(','.join(json.load(sys.stdin).get('auth',{}).get('policies') or []))" 2>/dev/null)
      log "OpenBao login role=$BAO_ROLE → policies=[$POLICIES]"
    else
      fail "OpenBao recusou: $(echo "$BAO_RESP" | head -c 240)"
      echo "         causas comuns: bound_audiences != clientId; bound_claims.groups"
      echo "         sem o prefixo ${ORG}/; user_claim errado"
    fi
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
echo
echo "───────────────────────────────────────────"
echo "  PASS=$PASS  FAIL=$FAIL  SKIP=$SKIP"
if [ "$FAIL" -gt 0 ]; then
  echo "  RESULTADO: NÃO vire o staging ainda"
  exit 1
fi
if [ "$SKIP" -gt 0 ]; then
  echo "  RESULTADO: sem falhas, mas $SKIP verificação(ões) não rodaram"
  exit 0
fi
echo "  RESULTADO: premissas confirmadas"
