# Design — ArchGate Connect

## Architecture

```
┌──────────────────────────┐
│  Tauri tray (UI)         │
│  login / list / connect  │
└────────────┬─────────────┘
             │ exec / library
┌────────────▼─────────────┐
│  CLI archgate (Go)       │
│  auth · catalog · ssh    │
│  config · doctor         │
└────────────┬─────────────┘
             │ HTTPS OIDC + API
┌────────────▼─────────────┐
│  ArchGate (Hostinger)    │
│  Kanidm · BFF · Warpgate │
│  Guac · connectors       │
└──────────────────────────┘
```

## Auth

1. Prefer **device authorization grant** no CLI.
2. Tray pode abrir browser **PKCE** (client `archgate-connect`).
3. Tokens em `~/.config/archgate/credentials.json` (0600); keychain nas iterações seguintes.

## Catalog

Reuse `listUnifiedConnections` — never include target private IPs.

Bootstrap response:

```json
{
  "bastion": {
    "ssh_host": "wg.archgate.com.br",
    "ssh_port": 2222,
    "pg_host": "wg.archgate.com.br",
    "pg_port": 55432,
    "http_base": "https://wg.archgate.com.br",
    "guac_base": "https://guac.archgate.com.br",
    "console_base": "https://console.archgate.com.br",
    "oracle_ui": "https://console.archgate.com.br/oracle"
  },
  "profile": { "username": "...", "tenants": [] },
  "connections": [ { "id": "...", "target": "...", "protocol": "ssh", "engine": "warpgate" } ]
}
```

## Materialization (MVP)

| Protocol | Action |
|----------|--------|
| ssh | `ssh -p {port} '{user}:{target}@{host}'` · write `~/.ssh/config.d/archgate` |
| postgres | print DBeaver/psql pointing at bastion PG port |
| http | open Warpgate HTTPS URL |
| rdp / guac | open guac / UnifiedUI session URL |
| oracle | open `oracle_ui` |

No L3 tunnel. Optional local TCP proxy is post-MVP.

## Security

- Bastion-only destinations
- No client VPN secrets in the app
- Session-bound catalog
- Clear UX: “Bastion, not VPN”
