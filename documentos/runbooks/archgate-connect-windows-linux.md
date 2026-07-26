# ArchGate Connect — Windows / Linux (CLI + desktop roadmap)

> **ADR-008A:** macOS first (desktop tray). CLI is multi-OS; tray Windows/Linux is residual.  
> **Bastion, not VPN** — never install customer Forti/OpenVPN as the Connect happy path.

| Superfície | macOS | Linux | Windows |
|------------|-------|-------|---------|
| CLI `archgate` | Feito | Feito | Feito |
| Desktop Tauri (RDM) | Feito (0.2.x) | Residual (build experimental) | Residual |
| Keychain / secret store | Keychain | libsecret / file | Credential Manager |
| MySQL client (F15) | `brew install mysql-client` | `mysql-client` distro | MySQL Shell / PATH |
| Postgres client | `brew install libpq` | `postgresql-client` | PATH |
| Notarize / SmartScreen | Developer ID | N/A (sigstore/GPG later) | Authenticode later |

## Build CLI

### Linux / macOS

```bash
cd clients/archgate-connect
go build -o archgate ./cmd/archgate
# install
mkdir -p ~/.local/bin && cp archgate ~/.local/bin/
# ensure PATH includes ~/.local/bin
archgate version
```

### Windows (PowerShell)

```powershell
cd clients\archgate-connect
go build -o archgate.exe .\cmd\archgate
# optional: copy to a PATH folder
$env:Path += ";$PWD"
.\archgate.exe version
```

Requires [Go 1.22+](https://go.dev/dl/).

## Config directory

| OS | Path |
|----|------|
| Linux | `~/.config/archgate/` |
| macOS | `~/.config/archgate/` |
| Windows | `%USERPROFILE%\.config\archgate\` (via `UserHomeDir`) |

Override: `ARCHGATE_CONFIG_DIR=C:\path\to\dir`

Files:

| File | Content |
|------|---------|
| `config.json` | API base + bastion endpoints (no secrets) |
| `oidc.env` | `ARCHGATE_OIDC_CLIENT_SECRET=…` (chmod 600 / ACLs) |
| `credentials.json` | lab token **or** keychain pointer |

### Credential storage

| Mode | Env | Behavior |
|------|-----|----------|
| Keychain (default on desktop OS) | (unset) | OIDC tokens in OS store (`archgate-connect` service) |
| File | `ARCHGATE_KEYCHAIN=file` | tokens in `credentials.json` 0600 |

- **macOS:** Keychain Access  
- **Windows:** Credential Manager (via go-keyring)  
- **Linux:** Secret Service / libsecret (or file fallback if DBus unavailable)

## Daily commands (same on all OS)

```bash
archgate login --lab --user operator     # homolog
# or
archgate login                           # SSO browser PKCE (opens default browser)

archgate status
archgate ls
archgate doctor
archgate go <target> --terminal          # Linux needs x-terminal-emulator or gnome-terminal
archgate print-ssh <target>
archgate db <target> --clipboard         # Linux: wl-copy or xclip
archgate config apply
archgate logout
```

### Terminal backends

| OS | `--terminal` |
|----|----------------|
| macOS | Terminal.app via `osascript` |
| Linux | `x-terminal-emulator` or `gnome-terminal` |
| Windows | **not supported** — run `archgate ssh <target>` in an existing terminal (Windows Terminal / PowerShell) |

### Clipboard (`--clipboard`)

| OS | Tool |
|----|------|
| macOS | `pbcopy` |
| Linux | `wl-copy` or `xclip -selection clipboard` |
| Windows | not yet — use printed `psql`/`mysql` line |

### MySQL via bastion (F15)

```bash
# same on Linux/macOS once mysql client is on PATH
archgate db lab-mysql --json
mysql -h $ARCHGATE_WG_MYSQL_HOST -P 33306 -u 'OPERADOR:lab-mysql' -p \
  --ssl-mode=REQUIRED --enable-cleartext-plugin
```

Windows: install MySQL Shell or Oracle MySQL client; same flags if the CLI supports them.

### Desktop experimental (Linux)

```bash
cd clients/archgate-connect/desktop
# need webkitgtk + rust; not CI-gated yet
npm install && npm run tauri build
```

Do **not** ship Linux/Windows desktop as production until macOS notarize path is green.

## Browser open

| OS | Command used by CLI |
|----|---------------------|
| macOS | `open` |
| Linux | `xdg-open` |
| Windows | `rundll32 url.dll,FileProtocolHandler` |

## Environment (common)

| Variable | Purpose |
|----------|---------|
| `ARCHGATE_API_BASE` | BFF base URL |
| `ARCHGATE_WG_SSH_HOST` / `_PORT` | Bastion SSH (VPS IP if CF blocks TCP) |
| `ARCHGATE_WG_USER` | Warpgate operator override |
| `ARCHGATE_MOCK=1` | offline catalog |
| `ARCHGATE_KEYCHAIN=file` | force file credentials |
| `ARCHGATE_OIDC_*` | see `oidc.env` |

## Smoke

```bash
# mock
ARCHGATE_MOCK=1 ARCHGATE_KEYCHAIN=file archgate login --lab --user smoke
ARCHGATE_MOCK=1 ARCHGATE_KEYCHAIN=file archgate ls

# live lab (needs network)
./scripts/smoke-h4-h5.sh --h5-only
```

## Desktop tray

| OS | Status |
|----|--------|
| macOS | Supported (`ArchGate Connect.app` + menu bar) |
| Windows / Linux | **Residual** — use CLI |

## Known gaps

1. Windows `--terminal` and `--clipboard` not implemented.  
2. No MSI/AppImage packaging yet.  
3. Linux keyring needs a running Secret Service; otherwise set `ARCHGATE_KEYCHAIN=file`.  
4. Official Apple notarization is separate (macOS only) — see packaging runbook.

## Related

- [archgate-connect.md](./archgate-connect.md)  
- [forti-mac-xor-vps.md](./forti-mac-xor-vps.md)  
- ADR-008A  
