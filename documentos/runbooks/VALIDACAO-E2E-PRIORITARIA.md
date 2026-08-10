# Validação E2E prioritária — RustGuac e Connectors

Este runbook é a validação final dos itens W1-08..W1-10 e W2-02..W2-05.
Nenhum segredo deve ser commitado ou colado em logs.

## Pré-requisitos

```bash
export ARCHGATE_E2E_BASE_URL=https://console.archgate.com.br
export ARCHGATE_E2E_SESSION_COOKIE='<cookie HttpOnly temporário>'
export ARCHGATE_E2E_RUSTGUAC_TARGET=archgate-lab-ssh
export CONNECTOR_ROTATION_TOKEN='<token single-use de laboratório>'
```

O cookie e o token devem ter TTL curto e ser revogados após o smoke.

## Execução

No Console:

```bash
npm ci
ARCHGATE_E2E_BASE_URL="$ARCHGATE_E2E_BASE_URL" \
  ARCHGATE_E2E_SESSION_COOKIE="$ARCHGATE_E2E_SESSION_COOKIE" \
BASE_URL="$ARCHGATE_E2E_BASE_URL" E2E_NO_SERVER=1 \
  npx playwright test tests/e2e/rustguac-session.spec.ts --reporter=line
```

Validar no mesmo ciclo:

1. SSH abre WebSocket, recebe resize e encerra server-side.
2. RDP/VNC abrem pelo mesmo BFF quando os targets de laboratório estiverem
   provisionados.
3. Clipboard, drive, upload/download respeitam a política do target.
4. Uma sessão com gravação gera artefato `.guac`, aparece no catálogo,
   reproduz autenticadamente e respeita retenção.
5. O connector envia heartbeat/inventory; o Manager mostra o inventário.
6. Rotação `action=rotate` substitui o certificado e o serial anterior é
   revogado no OpenBao; uma conexão com o certificado antigo falha.

## Evidência mínima

Guardar somente status HTTP, `request_id`, `session_id`, serial truncado e
timestamps. Nunca guardar cookie, token, CSR, chave privada ou segredo de alvo.
