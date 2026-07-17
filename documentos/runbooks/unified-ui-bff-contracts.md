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

Filtrado por sessão (RBAC / memberships Kanidm `tenant_*`). **Sem** IPs de alvo.

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

## Princípios

| Princípio | Nota |
|-----------|------|
| W4-UI05 | Tokens admin nunca no browser |
| ADR-008 | Só nomes de target / bastion público |
| Lab | SPA usa mock se BFF 4xx/rede |

## Estado

| Op | Lab | Target |
|----|-----|--------|
| callback | SPA PKCE direto + mock | BFF cookie |
| connections | mock fixture | BFF + Guac/WG RBAC |
| guac tunnel token | — | BFF short-lived |
