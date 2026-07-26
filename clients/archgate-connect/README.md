# ArchGate Connect

Cliente do **operador** no notebook: login ArchGate → catálogo → SSH/DB via bastion.

> **Bastion, not VPN** — Forti/OpenVPN do cliente ficam no VPS (`rio-forti` / `rio-aws`).

## Instalação (macOS / Linux)

```bash
cd clients/archgate-connect
./install.sh
# garanta ~/.local/bin no PATH
```

OIDC (SSO):

```bash
# secret do client Kanidm archgate-connect (ops)
cp ~/.config/archgate/oidc.env.example ~/.config/archgate/oidc.env
chmod 600 ~/.config/archgate/oidc.env
# preencher ARCHGATE_OIDC_CLIENT_SECRET
```

## Uso diário

```bash
archgate login                 # browser Kanidm (PKCE)
# ou homolog (catalog nickname ≠ Warpgate user):
archgate login --lab --user edson
# grava warpgate_user=uat-op-a (ou ARCHGATE_WG_USER)

archgate ls
archgate ls --json             # para UI / scripts
archgate status --json         # inclui warpgate_user + bastion

archgate print-ssh rio-aws-api-b
archgate go rio-aws-api-b --terminal    # dispatcher (ssh/db/open)
archgate ssh rio-aws-api-b              # só SSH
archgate ssh rio-aws-api-b --terminal

archgate db rio-lab-postgres --clipboard
archgate open rio-oracle-prod           # console /oracle

archgate config apply          # Hosts em ~/.ssh/config.d/archgate
ssh archgate-rio-aws-api-b

archgate doctor
archgate manager                 # abre ArchGate Manager (admin) no browser
archgate manager --path /sites
archgate org-accounts            # Manager → Contas da org (OCB; sem vault no Connect)
archgate logout
```


### Identidade SSH (única fonte)

| Fonte | Uso |
|-------|-----|
| `ARCHGATE_WG_USER` | override de processo |
| `credentials.warpgate_user` | gravado no login (lab/OIDC) |
| OIDC username | default se env não setado |

O desktop Tauri **só executa o CLI** — não hardcodeia host/usuário Warpgate.

### Sessão OIDC (refresh + keychain)

| Evento | Comportamento |
|--------|----------------|
| Login SSO | grava `access_token`, `refresh_token`, `expires_at` |
| Storage | **Keychain** (macOS/Windows/Linux) por default; `ARCHGATE_KEYCHAIN=file` força JSON |
| `status` / `ls` / bootstrap | se access perto de expirar → **refresh** automático |
| HTTP 401 do BFF | tenta **um** refresh e repete; se falhar → limpa credenciais |
| Refresh falhou / sem refresh_token | `session expired — run: archgate login` |

Lab (`login --lab`) não usa refresh (token de catálogo local).

### Multi-OS / packaging

| Doc | Conteúdo |
|------|----------|
| [Windows/Linux CLI](../../documentos/runbooks/archgate-connect-windows-linux.md) | build, PATH, terminal/clipboard gaps |
| [macOS notarize](../../documentos/runbooks/archgate-connect-macos-notarize.md) | Developer ID + notarytool |
| `./scripts/package-macos.sh [--notarize]` | build + sign (+ optional notary) |
| `./scripts/smoke-sso-e2e.sh` | `--preflight` / `--interactive` SSO E2E |


## Desktop (Tauri)

### Instalado (build)

```text
clients/archgate-connect/dist/
  ArchGate Connect.app
  ArchGate Connect_0.2.0_aarch64.dmg
```

```bash
open dist/ArchGate\ Connect.app
# ou: open dist/ArchGate\ Connect_0.2.0_aarch64.dmg
```

### Dev

```bash
./install.sh                   # CLI no PATH
cd desktop
npm install
# rebuild sidecar for current arch:
#   go build -o src-tauri/binaries/archgate-$(rustc -vV | sed -n 's/^host: //p') ../cmd/archgate
npm run tauri:dev
```

UI: Login lab / SSO · lista · SSH (abre terminal) · SSH config · Doctor.

## Arquitetura

```
Notebook (Connect CLI/tray)
  → OIDC + BFF console.archgate.com.br
  → Warpgate :2222 / PG :55432
  → connectors VPS (Forti + OpenVPN)
  → alvos Rio/AWS
```

## Desenvolvimento

```bash
go test ./...
go build -o archgate ./cmd/archgate
ARCHGATE_MOCK=1 ./archgate ls
# live:
ARCHGATE_MOCK=0 ./archgate login --lab --user smoke.operator
./archgate ls --json
```

## Docs

- ADR-008A · `documentos/runbooks/archgate-connect.md`
- Residual peer: `archgate-devops/docs/RESIDUAL-SPRINT1.md`
