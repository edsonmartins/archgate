# Smoke F4 — Guacamole real token (BFF)

| Campo | Valor |
|-------|--------|
| Data | 2026-07-26 |
| Host | Hostinger `217.196.60.108` |
| Console | `archgate-console` (rebuilt 61-deploy-console) |
| Guac | `archgate-guacamole:1.6.0` (Traefik direto; **sem** oauth2-proxy neste host) |

## Deploy

- `sync-to-vps` → archgate `e8b6730`
- `61-deploy-console` com source `_archguard/archguard-console` commits `9911b9c` → `8b2b479` → `2a511f7`
- Env console: `GUACAMOLE_URL=http://archgate-guacamole:8080`, `ARCHGATE_CONNECT_LAB=1`

## Seed lab (só smoke)

- Conexão Guac JDBC `lab-ssh-browser` (id=`1`, SSH → lab container)
- User Guac `uat-op-a` + READ
- Target SoT `rio_quality_lab` + engine `guacamole` / `lab-ssh-browser`

## Resultados

### PASS — `POST /api/unified/v1/sessions` (lab bearer)

```http
Authorization: Bearer lab-uat-op-a
{"connection_id":"rio_quality_lab:lab-ssh-browser","target":"lab-ssh-browser","protocol":"ssh"}
```

Resposta (redigida):

```json
{
  "tunnel_url": "wss://guac.archgate.com.br/websocket-tunnel",
  "connect_data": "token=<64-hex>&GUAC_DATA_SOURCE=postgresql&GUAC_ID=1&GUAC_TYPE=c",
  "expires_in": 120,
  "embed_url": "https://guac.archgate.com.br/?token=<…>#/client/MQBjAHBvc3RncmVzcWw",
  "embed_mode": "websocket",
  "launch": { "engine": "guacamole", "target": "lab-ssh-browser", "protocol": "ssh" }
}
```

Log console:

```
unified session guacamole token issued user=uat-op-a target=lab-ssh-browser guac_id=1 mode=websocket
```

### PASS — catálogo Bearer

`GET /api/unified/v1/connections` com `lab-uat-op-a` lista `lab-ssh-browser` (engine guacamole).  
(Fix: route usava só cookie; agora `resolveOperatorSession`.)

### PASS — WS interno Guacamole

`http://archgate-guacamole:8080/websocket-tunnel` + Upgrade → **HTTP 101**.

### PASS — WS via Traefik (HTTP/1.1)

| Path | Resultado |
|------|-----------|
| Interno guac container + Upgrade | **101** |
| Traefik `Host: guac…` **HTTP/1.1** + Upgrade | **101** (curl hang = upgrade ok) |
| Traefik **HTTP/2** + Upgrade | **404** (Tomcat; browsers usam h1 p/ WS) |
| `https://guac.archgate.com.br/` | **200** |

File router adicionado: `/opt/linktor-devops/traefik/dynamic/archgate-guac-router.yml`.

guacamole-common-js / browsers abrem WebSocket em HTTP/1.1 → path público **OK**.

### oauth2-proxy

Não aplicável neste host (Guac exposto direto). Script `oauth2-proxy-deploy.sh` no monorepo já tem `SKIP_AUTH_ROUTES=^/websocket-tunnel` para o lab Swarm (180) quando o proxy for reaplicado.

## Critério F4

| Check | Status |
|-------|--------|
| Mint header-auth operador (não guacadmin) | **PASS** |
| `connect_data` com token + GUAC_ID + DS | **PASS** |
| `embed_mode: websocket` | **PASS** |
| Catálogo Connect Bearer | **PASS** |
| Túnel WS via Traefik (h1) | **PASS** |

## Commits

| Repo | SHA | Nota |
|------|-----|------|
| archguard | `2a511f7` | connections Bearer + mint F4 |
| archgate | `e8b6730` | Connect client F4/F13/V11 |
