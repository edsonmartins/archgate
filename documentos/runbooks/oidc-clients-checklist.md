# Checklist OIDC clients — Kanidm (W1-ID04)

Revisar em cada promoção de DNS/ambiente. Issuer base: `https://id.archgate.com.br`.

## Clients

| Client ID | Tipo | Redirect / landing | Scopes típicos | PKCE |
|-----------|------|--------------------|----------------|------|
| `archguard-console` | public | `https://console.archgate.com.br/callback` | openid profile email groups | sim |
| `warpgate` | confidential | UI WG + callback configurado no WG | openid profile email groups | conforme WG |
| `guacamole` | public (oauth2-proxy) | `https://guac.archgate.com.br/oauth2/callback` | openid profile email groups | S256 |
| `openbao` | public/JWT | redirect bootstrap (CLI/lab) | openid profile email groups | sim |

## Verificações

- [ ] Discovery:  
  `curl -sk https://id.archgate.com.br/oauth2/openid/<client>/.well-known/openid-configuration`
- [ ] `issuer` e `jwks_uri` HTTPS e estáveis  
- [ ] Redirect URIs **exatos** (sem path errado, com/sem trailing slash)  
- [ ] Scope map no Kanidm: grupo `archguard_users` (ou equivalente) → scopes  
- [ ] Secret de clients confidential só em bootstrap/Swarm secret — não no git  
- [ ] Logout / post-logout URLs se o client usar  
- [ ] Grupos no token (`groups` claim) — SPN completo vs short name (OpenBao JWT já usa SPN)

## Smoke por client

| Client | Smoke |
|--------|--------|
| console | login OIDC ou suite `w0-console-session` (lab e2e) |
| warpgate | SSO UI / smoke-operator |
| guacamole | `guacamole-sso-proxy-e2e` + `w0-guac-session` |
| openbao | `smoke-kanidm-jwt.sh` |

## Última revisão

| Campo | Valor |
|-------|--------|
| Data | 2026-07-17 |
| Ambiente | staging lab |
| Revisor | |
