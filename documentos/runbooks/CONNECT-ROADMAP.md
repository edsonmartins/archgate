# ArchGate Connect — roadmap de melhorias (funcional + visual)

| Campo | Valor |
|-------|--------|
| Status | Ativo |
| Data | 2026-07-25 |
| Produto | ArchGate Connect (CLI + desktop Tauri) |
| ADRs | [ADR-008A](../../adr/ADR-008A-archgate-connect-cliente-operador.md) · [ADR-008B](../../adr/ADR-008B-connect-sessoes-embutidas.md) |
| Código | `clients/archgate-connect/` |

## Estado atual (baseline)

| Área | Estado |
|------|--------|
| Modelo bastion-first | Feito |
| CLI (login/SSO/refresh/keychain/ls/doctor/go) | Feito |
| Desktop multi-aba | Feito |
| SSH embutido (xterm + PTY) | Feito |
| DB embutido (psql PTY) | Feito |
| Guac/Web embutido (iframe/WS) | Parcial (token Guac real pendente) |
| Prefs terminal global + por target | Feito |
| Tray macOS | Feito |
| Notarize / auto-update | Pendente (org) |

## Onda 1 — Operador confiante *(implementar agora)*

| ID | Item | Tipo |
|----|------|------|
| **F1** | Mapa SSO → usuário Warpgate (campo UI + persistência) | funcional |
| **F3** | Reconnect / reauth (banner expiração, reconectar, fechar PTYs) | funcional |
| **V1** | Login lab fora do happy path (SSO-first; homolog em “Avançado”) | visual/UX |
| **V2** | Identidade compacta (header + menu de ações) | visual/UX |
| **V8** | First-run onboarding (SSO → doctor → 1ª conexão) | visual/UX |
| **V12** | Overlay “digite senha Warpgate” na 1ª sessão SSH/DB | visual/UX |

**Critério de saída Onda 1:** operador em SSO vê fluxo limpo; define WG user; entende expiração; first-run guia os 3 passos; senha WG não é misteriosa.

## Onda 2 — RDM de verdade

F4 Guac token REST · F6–F10 favoritos/grupos/atalhos/health · F13 notificações · V3–V7 catálogo e chrome de sessão · V11 chrome Guac.

## Onda 3 — Ship

F5 notarize + auto-update · F15–F17 MySQL/Oracle/HTTP · F20 multi-OS · V10 theme app · V17 marca.

## Fora de escopo próximo

Vault local de senhas de alvo · FreeRDP nativo · VPN cliente no notebook · full SIEM.

## Tracking

| Data | Nota |
|------|------|
| 2026-07-25 | Roadmap criado; Onda 1 implementada (F1, F3, V1, V2, V8, V12) |
