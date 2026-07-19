# ArchGate Connect — Desktop (Tauri)

Tray/UI que invoca o CLI `archgate` (ADR-008A).

## Pré-requisitos

```bash
# CLI no PATH
cd ../
go build -o archgate ./cmd/archgate
sudo cp archgate /usr/local/bin/   # ou export PATH

# deps UI
cd desktop
npm install
```

Tauri 2 também precisa do toolchain Rust e libs nativas:
https://v2.tauri.app/start/prerequisites/

## Dev

```bash
# só UI no browser (mock do CLI)
npm run dev

# app nativo (chama archgate real)
export ARCHGATE_MOCK=1
npm run tauri:dev
```

## Princípio

**Bastion, not VPN** — não configura Forti/OpenVPN do cliente.
