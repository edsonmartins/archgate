# ADR-006 — Estratégia de frontend (UnifiedUI)

| Campo | Valor |
|-------|--------|
| Status | **Aceito (W4)** |
| Data | 2026-07-17 |
| Relacionados | ADR-007, ADR-007A, ADR-009, `add-unified-ui-and-orchestration` |

## Contexto

Há duas superfícies:

1. **Console ArchGuard** (`archguard-console`) — admin: identidades, sites, gateways, secrets, platform.  
2. **UnifiedUI** (Fase 4) — **operador**: catálogo “minhas conexões” + sessão embutida (SSH/RDP).

## Decisão

| Superfície | Stack | Repo path |
|------------|-------|-----------|
| Admin | TanStack Start + React (existente) | `../archguard/archguard-console` |
| **UnifiedUI operador** | **Vite + React 19 + TypeScript** | `frontend/unified-ui` |

Motivos:

- Admin já maduro no monorepo archguard; não reescrever.  
- UnifiedUI é produto operador com ciclo próprio (guacamole-common-js, catálogo).  
- Vite permite iterar o chrome de sessão sem acoplar ao server TanStack.  
- Auth: OIDC Kanidm (Code+PKCE); tokens admin **não** no browser — catálogo via BFF futuro no console ou API Axis.

## Sessão remota (ADR-007 path)

- **Curto prazo:** portão Guac stock (oauth2-proxy) permanece break-glass.  
- **UnifiedUI:** `guacamole-common-js` + túnel WebSocket até guacd (via proxy server-side).  
- **Não** exigir Guac 1.7 OIDC nativo se o fluxo dev for só UnifiedUI (ADR-007A + este ADR).

## Consequências

- Dois deploys (console admin + unified-ui).  
- Design system: reutilizar tokens/cores IntegrAllTech; Mantine/shadcn opcional na UnifiedUI v0.  
- Orquestração Axis continua server-side (API), não no SPA.

## Estado de implementação (2026-07-17)

| Item | Status |
|------|--------|
| Scaffold Vite/React em `frontend/unified-ui` | done |
| Auth mock lab + OIDC PKCE scaffold | done (OIDC lab real TBD) |
| Catálogo BFF contract + mock fallback | done (`unified-ui-bff-contracts.md`) |
| Launch Warpgate SSH/PG (W4-UI07) | done |
| guacamole-common-js embed | done (BFF token; lab BFF TBD) |
| Offboarding / provision API | done mock + live dry-run adapters |

## Alternativas rejeitadas

- Reescrever admin em Vite agora.  
- Embutir tudo só no Guacamole stock.  
