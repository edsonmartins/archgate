#!/usr/bin/env bash
# Passo 1 da virada (ADR-014): põe as aplicações do ArchGate em JWT-Custom.
#
# POR QUÊ
#   No formato `JWT` o token serializa o objeto User inteiro e o saneamento do
#   Casdoor limpa apenas a senha (`refineUser`, object/token_jwt.go). Sobrevivem
#   `totpSecret`, `recoveryCodes`, `passwordSalt` e `passwordType` — e esse token
#   trafega para o Warpgate, para o oauth2-proxy do Guacamole e para o OpenBao.
#   Quem lê o token clona o segundo fator.
#
#   `JWT-Custom` emite só os campos listados (`getClaimsCustom`), e os quatro do
#   default cobrem tudo que o ArchGate consome:
#     Name        → claim `name`        (user_claim do OpenBao)
#     Groups      → claim `groups`      (Warpgate, OpenBao, escopo de tenant)
#     Email       → claim `email`
#     DisplayName → claim `displayName` (rótulo na UI do Manager)
#
# USO
#   export ARCHGATE_IDP_URL=https://app.archguard.com.br
#   export ARCHGUARD_SA_CLIENT_ID=... ARCHGUARD_SA_CLIENT_SECRET=...
#   bash deploy/archguard/set-token-format.sh          # dry-run (padrão)
#   APPLY=1 bash deploy/archguard/set-token-format.sh  # escreve
#
# Idempotente: aplicação já correta é pulada. Escreve apenas as colunas
# token_format e token_fields — nenhum outro campo da aplicação é tocado.
set -uo pipefail

IDP_URL="${ARCHGATE_IDP_URL:?defina ARCHGATE_IDP_URL}"
IDP_URL="${IDP_URL%/}"
SA_CLIENT_ID="${ARCHGUARD_SA_CLIENT_ID:?defina ARCHGUARD_SA_CLIENT_ID}"
SA_CLIENT_SECRET="${ARCHGUARD_SA_CLIENT_SECRET:?defina ARCHGUARD_SA_CLIENT_SECRET}"

# Aplicações no Casdoor pertencem a `admin` por padrão (object/application.go).
OWNER="${ARCHGUARD_APP_OWNER:-admin}"
APPS="${APPS:-archguard-console archgate-connect warpgate guacamole openbao archgate-console-sa}"
FIELDS="${TOKEN_FIELDS:-Name,Groups,Email,DisplayName}"
FORMAT="${TOKEN_FORMAT:-JWT-Custom}"
APPLY="${APPLY:-0}"

OK=0
CHANGED=0
SKIPPED=0
FAILED=0

log()  { echo "  [OK]     $*"; OK=$((OK + 1)); }
chg()  { echo "  [CHANGE] $*"; CHANGED=$((CHANGED + 1)); }
skip() { echo "  [SKIP]   $*"; SKIPPED=$((SKIPPED + 1)); }
bad()  { echo "  [FAIL]   $*" >&2; FAILED=$((FAILED + 1)); }

command -v curl >/dev/null || { echo "faltando: curl" >&2; exit 2; }
command -v python3 >/dev/null || { echo "faltando: python3" >&2; exit 2; }

echo "ArchGuard — token format das aplicações do ArchGate"
echo "  idp    = $IDP_URL"
echo "  owner  = $OWNER"
echo "  alvo   = $FORMAT [$FIELDS]"
if [ "$APPLY" = "1" ]; then
  echo "  modo   = APLICAR"
else
  echo "  modo   = dry-run (use APPLY=1 para escrever)"
fi

# ── credencial de máquina ────────────────────────────────────────────────────
TOKEN=$(curl -sS -m 20 -X POST "${IDP_URL}/api/login/oauth/access_token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=client_credentials&client_id=${SA_CLIENT_ID}&client_secret=${SA_CLIENT_SECRET}" \
  | python3 -c "import json,sys
try: print(json.load(sys.stdin).get('access_token',''))
except Exception: print('')" 2>/dev/null)

if [ -z "$TOKEN" ]; then
  echo "não consegui obter access_token via client_credentials" >&2
  exit 1
fi

api() {
  local method="$1" path="$2" body="${3:-}"
  if [ -n "$body" ]; then
    curl -sS -m 25 -X "$method" "${IDP_URL}${path}" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H 'Content-Type: application/json' -d "$body"
  else
    curl -sS -m 25 -X "$method" "${IDP_URL}${path}" \
      -H "Authorization: Bearer ${TOKEN}"
  fi
}

# Lê o estado atual e decide, num só passo, para não duplicar o parsing em bash.
inspect() {
  APP_JSON="$1" TARGET_FORMAT="$FORMAT" TARGET_FIELDS="$FIELDS" python3 <<'PY'
import json, os

env = json.loads(os.environ["APP_JSON"] or "{}")
if env.get("status") != "ok" or not env.get("data"):
    print("ERROR\t" + (env.get("msg") or "aplicação não encontrada"))
    raise SystemExit

app = env["data"]
want_fields = [f.strip() for f in os.environ["TARGET_FIELDS"].split(",") if f.strip()]
want_format = os.environ["TARGET_FORMAT"]

cur_format = app.get("tokenFormat") or "(vazio)"
cur_fields = app.get("tokenFields") or []

if cur_format == want_format and sorted(cur_fields) == sorted(want_fields):
    print("CURRENT\t%s [%s]" % (cur_format, ",".join(cur_fields)))
    raise SystemExit

app["tokenFormat"] = want_format
app["tokenFields"] = want_fields
print("UPDATE\t%s [%s]\t%s" % (cur_format, ",".join(cur_fields), json.dumps(app)))
PY
}

echo
for app in $APPS; do
  ID=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "${OWNER}/${app}")
  RESP=$(api GET "/api/get-application?id=${ID}" || true)
  RESULT=$(inspect "$RESP")

  KIND=$(printf '%s' "$RESULT" | head -1 | cut -f1)
  DETAIL=$(printf '%s' "$RESULT" | head -1 | cut -f2)

  case "$KIND" in
    CURRENT)
      log "${app}: já em ${DETAIL}"
      ;;
    UPDATE)
      if [ "$APPLY" != "1" ]; then
        chg "${app}: ${DETAIL} → ${FORMAT} [${FIELDS}]  (dry-run)"
        continue
      fi
      BODY=$(printf '%s' "$RESULT" | head -1 | cut -f3)
      UP=$(api POST "/api/update-application?id=${ID}&columns=token_format,token_fields" "$BODY" || true)
      UP_STATUS=$(printf '%s' "$UP" | python3 -c "import json,sys
try: print(json.load(sys.stdin).get('status',''))
except Exception: print('')" 2>/dev/null)
      if [ "$UP_STATUS" != "ok" ]; then
        bad "${app}: update recusado — $(printf '%s' "$UP" | head -c 200)"
        continue
      fi
      # Confirma relendo: o Casdoor responde 200 com status error em alguns casos.
      VERIFY=$(inspect "$(api GET "/api/get-application?id=${ID}" || true)")
      if [ "$(printf '%s' "$VERIFY" | head -1 | cut -f1)" = "CURRENT" ]; then
        chg "${app}: ${DETAIL} → ${FORMAT} [${FIELDS}]"
      else
        bad "${app}: update aceito mas releitura não confere"
      fi
      ;;
    ERROR)
      bad "${app}: ${DETAIL}"
      ;;
    *)
      bad "${app}: resposta inesperada — $(printf '%s' "$RESP" | head -c 160)"
      ;;
  esac
done

echo
echo "───────────────────────────────────────────"
echo "  OK=$OK  ALTERADAS=$CHANGED  PULADAS=$SKIPPED  FALHAS=$FAILED"
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
if [ "$APPLY" != "1" ] && [ "$CHANGED" -gt 0 ]; then
  echo "  dry-run: rode de novo com APPLY=1 para escrever"
  exit 0
fi
if [ "$CHANGED" -gt 0 ]; then
  echo "  próximo: bash deploy/validation/smoke-archguard-cutover.sh (camada B)"
fi
