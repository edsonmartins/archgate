# Proposal — Connect embedded sessions (RDM-lite)

## Why

Operadores querem SSH/RDP **dentro** do ArchGate Connect (como Remote Desktop Manager), sem Terminal.app / browser separado para cada alvo — mantendo bastion-first.

## What Changes

- Capability **embedded-sessions** no desktop Tauri
- Multi-tab session workspace
- SSH via xterm + Warpgate; RDP/Guac via guacamole-common-js + BFF
- ADR-008B

## Impact

| Item | Efeito |
|------|--------|
| Connect desktop | Layout RDM; xterm + guacamole-common-js + iframe |
| CLI | `auth-header`, `print-open`, PTY sidecar |
| BFF | Bearer em `/unified/v1/sessions` (mesmo path Connect) |
| Segurança | Prompt senha WG no app (não persistir MVP) |

## Status 2026-07-24

Happy path embutido: SSH (PTY), RDP/VNC/Guac (display/iframe), DB (psql PTY), Web/Oracle (iframe).  
“Abrir externo” permanece só como fallback.
