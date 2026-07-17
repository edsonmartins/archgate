# ArchGate UnifiedUI (operador)

Scaffold W4 — catálogo de conexões + chrome de sessão + launch Warpgate (ADR-006 / ADR-008).

## Stack

- Vite 6 + React 19 + TypeScript  
- React Router 7  
- Auth: mock lab → OIDC Kanidm Code+PKCE (`VITE_OIDC_ENABLED=1`)  
- Catálogo: BFF `GET /api/unified/v1/connections` com fallback mock  
- Sessão browser: stub canvas → `guacamole-common-js` (próximo)  
- Parte B: snippets SSH/psql/DBeaver + deep-link `ssh://` (W4-UI07)

## Dev

```bash
cd frontend/unified-ui
cp .env.example .env   # opcional
npm install
npm run dev
# http://localhost:5174
```

## Build

```bash
npm run build
npm run preview
```

## OIDC (Kanidm)

1. Registrar client público `archgate-unified-ui` no IdP (redirect `…/auth/callback`, PKCE).  
2. `VITE_OIDC_ENABLED=1` + issuer/client no `.env`.  
3. Preferir exchange no BFF (`POST /api/unified/v1/auth/callback`) com cookie HttpOnly; SPA guarda só perfil de exibição.

## Princípios

- Sem IPs internos de alvo no browser (ADR-008).  
- Tokens admin **nunca** no SPA (W4-UI05).  
- Admin continua em `archguard-console`.  
- Snippets alinhados a `documentos/runbooks/snippets/`.
