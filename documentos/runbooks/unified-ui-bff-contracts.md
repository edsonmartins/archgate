# Contratos BFF — UnifiedUI (W4)

API consumida pelo SPA `frontend/unified-ui`. Preferir **mesmo origin** via reverse-proxy ou cookie session no console.

## Auth

### `POST /api/unified/v1/auth/callback`

Exchange OIDC code+PKCE no server (recomendado).

```json
{
  "code": "…",
  "code_verifier": "…",
  "redirect_uri": "https://app.archgate.com.br/auth/callback"
}
```

Resposta (JSON + `Set-Cookie` session HttpOnly):

```json
{
  "display_name": "Dev Silva",
  "email": "dev.silva@integrall.tech",
  "username": "dev.silva",
  "tenants": ["tenant_rio_quality"]
}
```

## Catálogo

### `GET /api/unified/v1/connections`

Filtrado por sessão (RBAC / memberships archguard `tenant_*`). **Sem** IPs de alvo.

```json
{
  "connections": [
    {
      "id": "1",
      "name": "Rio Lab SSH",
      "site": "Rio Quality (lab)",
      "tenant": "tenant_rio_quality",
      "protocol": "ssh",
      "engine": "warpgate",
      "target": "rio-lab-ssh",
      "description": "Shell via Warpgate"
    }
  ]
}
```

## Sessão Guacamole (W4-UI11)

### `POST /api/unified/v1/sessions`

Emite token de túnel **opaco** (curta duração). O SPA usa `guacamole-common-js` com WebSocket.

```json
{
  "connection_id": "3",
  "target": "rio-lab-ssh-browser",
  "protocol": "ssh"
}
```

Resposta:

```json
{
  "tunnel_url": "wss://guac.archgate.com.br/websocket-tunnel",
  "connect_data": "token=<authToken>&GUAC_DATA_SOURCE=postgresql&GUAC_ID=<id>&GUAC_TYPE=c",
  "expires_in": 120,
  "embed_url": "https://guac.archgate.com.br/?token=…#/client/…",
  "embed_mode": "websocket"
}
```

- BFF emite **authToken do operador** via header-auth interno (`X-Forwarded-User` = username archguard; ADR-007A) — **não** usa `guacadmin`.  
- `connect_data` é a query string de `Guacamole.Client.connect()`.  
- `embed_mode: "websocket"` quando o mint OK; `"iframe"` se Guac inacessível / ACL sem conexão.  
- SPA/Connect nunca recebe token admin, senha de alvo ou JWT de serviço.  
- **oauth2-proxy:** `SKIP_AUTH_ROUTES=^/websocket-tunnel` (token Guac ainda obrigatório no túnel).  
- Lab: sem BFF → erro claro; `VITE_GUAC_DEMO=1` só para chrome local.

## Princípios

| Princípio | Nota |
|-----------|------|
| W4-UI05 | Tokens admin nunca no browser |
| ADR-008 | Só nomes de target / bastion público |
| Lab | SPA usa mock se BFF 4xx/rede |

## Estado

| Op | Lab | Target |
|----|-----|--------|
| callback | SPA PKCE direto + mock | **BFF** `POST /api/unified/v1/auth/callback` (cookie `archguard_session`) |
| connections | mock fixture fallback | **BFF** `GET /api/unified/v1/connections` (sites SoT + RBAC) |
| guac tunnel token | SPA client + contract | **BFF** `POST /api/unified/v1/sessions` |

Implementação: `archguard-console` — `src/server/unified-bff.ts` + `src/routes/api/unified/v1/*`.

Env: `UNIFIED_UI_ORIGIN` (CORS), `UNIFIED_OIDC_CLIENT_ID` (default compartilha fluxo token com console se mesmo client).

## Contrato de mutações do Manager (P0-05)

Toda mutação administrativa do BFF segue o envelope abaixo. A UI nunca chama
Warpgate, RustGuac, OpenBao ou connectors diretamente.

### Autorização por ação

- O BFF valida a sessão ArchGuard, `org_id`, identidade ativa e membership do
  tenant antes de executar a ação.
- Cada rota declara uma permissão explícita (`sites:create`, `sites:update`,
  `connectors:enroll`, `sessions:close`, etc.). Não existe fallback por papel
  genérico.
- Ausência de contexto ou falha do provider retorna `401/403/503` fail-closed.

### Idempotência

- Mutações externas exigem `Idempotency-Key` UUID/ULID, entre 16 e 128 bytes.
- A chave é vinculada a `org_id`, identidade, método, rota e hash do corpo.
- Repetição com o mesmo hash devolve a resposta original; colisão de hash
  retorna `409`.
- O armazenamento deve ser transacional e compartilhado (PostgreSQL/Redis),
  nunca apenas memória de processo quando houver mais de uma réplica.

### Auditoria

Cada tentativa autorizada ou negada gera evento server-side com:

```json
{
  "event_id": "uuid",
  "occurred_at": "RFC3339",
  "org_id": "uuid",
  "actor_subject": "archguard-subject",
  "action": "connectors.enroll",
  "resource_type": "connector",
  "resource_id": "uuid",
  "decision": "allow|deny|error",
  "request_id": "uuid",
  "idempotency_key": "uuid",
  "metadata": {}
}
```

Segredos, tokens, CSR, credenciais e conteúdo de requests nunca entram em
`metadata`. O evento é gravado junto da mudança ou enviado para outbox
transacional antes de responder `2xx`.

### Jobs assíncronos

Operações que ultrapassam o timeout do BFF retornam `202`:

```json
{ "job_id": "uuid", "status": "queued", "poll_url": "/api/org/v1/jobs/<id>" }
```

`GET /api/org/v1/jobs/:id` só revela jobs da mesma organização e retorna
`queued|running|succeeded|failed|cancelled`, com `error_code` redigido. Cada
transição também gera evento de auditoria. Jobs são retomáveis por
`Idempotency-Key` e não podem duplicar efeitos externos.
