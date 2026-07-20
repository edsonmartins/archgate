# Runbook — ArchGate Connect (cliente operador)

> **ADR:** [ADR-008A](../../adr/ADR-008A-archgate-connect-cliente-operador.md) · [ADR-008](../../adr/ADR-008-cliente-operador-hibrido-multi-os.md)  
> **Código:** `clients/archgate-connect/`  
> **Mensagem:** **Bastion, not VPN** — o app não é Forti/OpenVPN do cliente.

## Para que serve

No notebook do dev:

1. Login SSO ArchGate  
2. Ver **minhas conexões** (por tenant/role)  
3. Abrir SSH/DB/HTTP **via Warpgate** (e RDP/Oracle via browser)  
4. Gerar `~/.ssh/config` gerenciado  

**Não** conecta na VPN do cliente. Quem faz isso é o **connector no VPS**.

## Instalação

```bash
cd clients/archgate-connect
./install.sh
# binário em ~/.local/bin/archgate — garanta no PATH
```

OIDC (uma vez, secret da plataforma):

```bash
# copiar secret do client Kanidm archgate-connect
# para ~/.config/archgate/oidc.env (chmod 600)
# O CLI carrega esse arquivo automaticamente.
```

## CLI (v0.2)

```bash
archgate login                    # SSO browser PKCE
archgate login --lab --user edson # homolog (BFF lab bearer)

archgate ls
archgate ls --json
archgate status                   # refresh OIDC se access perto de expirar
archgate doctor

# Sessão SSO: credentials.json guarda refresh_token + expires_at.
# 401 ou refresh falho → "session expired — run: archgate login"

archgate ssh rio-aws-api-b
archgate ssh rio-aws-api-b --terminal   # Terminal.app
archgate print-ssh rio-aws-api-b

archgate db rio-lab-postgres
archgate open rio-oracle-prod
archgate config apply                   # ~/.ssh/config.d/archgate
ssh archgate-rio-aws-api-b

archgate logout
```

Smoke:

```bash
cd archgate-devops
./scripts/68-smoke-archgate-connect.sh
```

## Desktop tray (Tauri)

```bash
./install.sh
cd desktop && npm install && npm run tauri:dev
```

Login lab / SSO · filtro · botão SSH (abre terminal) · SSH config · doctor.

## Bastion host (SSH/PG)

| Endpoint | Uso |
|----------|-----|
| `wg.archgate.com.br:443` | HTTPS UI (Cloudflare) |
| `217.196.60.108:2222` | SSH Warpgate (direto VPS — se CF não publicar TCP) |
| `217.196.60.108:55432` | Postgres proxy Warpgate |

Se `archgate doctor` mostrar FAIL em `wg.archgate.com.br:2222`, use:

```bash
export ARCHGATE_WG_SSH_HOST=217.196.60.108
export ARCHGATE_WG_PG_HOST=217.196.60.108
# ou grave em ~/.config/archgate/config.json / oidc.env
```

## Variáveis

| Env | Default | Uso |
|-----|---------|-----|
| `ARCHGATE_API_BASE` | `https://console.archgate.com.br/api` | BFF |
| `ARCHGATE_MOCK` | `0` | `1` = catálogo mock |
| `ARCHGATE_OIDC_*` | ver oidc.env | client confidential + PKCE |
| `ARCHGATE_WG_SSH_HOST` | `wg.archgate.com.br` | host SSH bastion |
| `ARCHGATE_WG_SSH_PORT` | `2222` | |

## Migração a partir do Mac “VPN do cliente”

| Antes | Depois |
|-------|--------|
| `conecta_rq` | connector `rio-forti` no VPS |
| OpenVPN Connect AS | connector `rio-aws` no VPS |
| `ssh ec2-user@10.0.x.x` + PEM | `archgate ssh rio-aws-api-b` |
| DBeaver → IP interno | bastion `:55432` user `op:target` |
| Oracle thin LAN | Console `/oracle` |

## Anti-padrões

- VPN do cliente + Connect “por precaução”  
- PEM de EC2 no app  
- Pedir full-tunnel L3 no notebook  

## Relacionados

- [Forti Mac XOR VPS](./forti-mac-xor-vps.md) — single-session SSL-VPN  
- [Checklist H6 migração Rio](./h6-migracao-rio-connect.md)  
- [Windows / Linux CLI](./archgate-connect-windows-linux.md)  
- [macOS notarize](./archgate-connect-macos-notarize.md)  
- Dispatcher: `archgate go <target>` (ssh/db/open pelo catálogo)  
- Credenciais: keychain OS (`ARCHGATE_KEYCHAIN=file` para JSON)  
