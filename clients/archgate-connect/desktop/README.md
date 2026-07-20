# ArchGate Connect — Desktop (Tauri)

UI + **system tray** que invoca o CLI `archgate` (ADR-008A).

## Pré-requisitos

```bash
cd ../
go build -o archgate ./cmd/archgate
# sidecar (Tauri externalBin)
TRIPLE=$(rustc -vV | sed -n 's/^host: //p')
mkdir -p desktop/src-tauri/binaries
cp archgate "desktop/src-tauri/binaries/archgate-${TRIPLE}"

cd desktop
npm install
```

Tauri 2: https://v2.tauri.app/start/prerequisites/

## Dev

```bash
npm run dev              # browser mock
npm run tauri:dev        # nativo + sidecar
```

## System tray (macOS)

- Ícone na barra de menus  
- Clique esquerdo → mostrar janela  
- Menu: **Abrir Connect** · **Atualizar status…** · **Sair**  
- Fechar a janela **esconde** (app fica no tray); **Sair** encerra  

## Packaging / codesign

```bash
# from clients/archgate-connect
./scripts/package-macos.sh
# ad-hoc (local). Distribution:
# SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" ./scripts/package-macos.sh
open dist/ArchGate\ Connect.app
```

## Princípio

**Bastion, not VPN** — não configura Forti/OpenVPN do cliente.  
Connect → `archgate go` (dispatcher SSH/DB/Open).
