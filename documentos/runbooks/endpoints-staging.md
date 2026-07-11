# Endpoints — staging / lab IntegrAllTech

> Consumido pelos runbooks ADR-008. Atualizar quando DNS/portas mudarem.

| Serviço | Endpoint | Notas |
|---------|----------|--------|
| Runtime host | `192.168.1.180` | Swarm ArchGate (`edson-ai`) |
| Kanidm / OIDC | `https://id.archgate.com.br` | Issuer |
| Console ArchGuard | `https://console.archgate.com.br` | Browser |
| Warpgate UI | `https://wg.archgate.com.br` | Browser |
| Warpgate SSH | `192.168.1.180:2222` / `wg.archgate.com.br:2222` | OpenSSH Parte B |
| Warpgate Postgres | `192.168.1.180:55432` / `wg.archgate.com.br:55432` | `sslmode=require` |
| Guacamole | `https://guac.archgate.com.br` | Browser Parte A |

## Targets lab de referência

| Target Warpgate | Kind | Tenant / uso |
|-----------------|------|----------------|
| `rio-lab-ssh` | SSH | tenant Rio Quality |
| `rio-lab-postgres` | Postgres | tenant Rio Quality |
| `marra-lab-ssh` | SSH | tenant Grupo Marra |
| `marra-lab-postgres` | Postgres | tenant Grupo Marra |
| `lab-ssh` / `lab-postgres` | SSH / Postgres | lab genérico |

## Guacamole lab

| Connection | Protocol |
|------------|----------|
| `lab-ssh-browser` | SSH (browser) |

## Forma de usuário no proxy

```
SSH:      ssh -p 2222 'OPERADOR:TARGET@HOST'
Postgres: user = OPERADOR:TARGET   (password = senha do operador no Warpgate)
```
