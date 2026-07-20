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
| Connect desktop | Layout RDM; dependências xterm / guac |
| CLI | Opcional `session ssh` / PTY sidecar |
| BFF | Bearer em `/unified/v1/sessions` |
| Segurança | Prompt senha WG no app (não persistir MVP) |
