# ArchGate UnifiedUI (operador)

Scaffold W4 — catálogo de conexões + chrome de sessão (ADR-006).

## Stack

- Vite 6 + React 19 + TypeScript  
- React Router 7  
- Auth: mock lab → OIDC Kanidm (próximo)  
- Sessão: stub canvas → `guacamole-common-js` (próximo)

## Dev

```bash
cd frontend/unified-ui
npm install
npm run dev
# http://localhost:5174
```

## Build

```bash
npm run build
npm run preview
```

## Princípios

- Sem IPs internos de alvo no browser (ADR-008).  
- Tokens admin **nunca** no SPA (W4-UI05).  
- Admin continua em `archguard-console`.
