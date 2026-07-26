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
| Guac/Web embutido (iframe/WS) | Feito (token BFF real + iframe fallback) |
| Prefs terminal global + por target | Feito |
| Tray macOS | Feito |
| Notarize / auto-update | Bloqueado (Developer ID) · theme app Feito |

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

| ID | Item | Status |
|----|------|--------|
| **F6** | Favoritos + recentes | Feito (2026-07-26) |
| **F7** | Agrupar por site (+ pins) | Feito |
| **F8** | Atalhos ⌘K / Enter / ⌘W / ⌘1–9 | Feito |
| **F9** | Badge pending apply | Feito (via description) |
| **F10** | Copiar SSH/psql | Feito |
| **V3–V6** | Lista + chrome sessão polish | Feito (parcial) |
| **F4** | Guac token REST real | Feito (2026-07-26) — header-auth mint + connect_data; WS skip oauth2-proxy |
| **F13** | Notificações nativas | Feito (Web Notification: sessão / SSO) |
| **V11** | Chrome Guac fullscreen | Feito (⛶ / Esc) |

## Onda 3 — Ship

| ID | Item | Status |
|----|------|--------|
| **F5** | Notarize + auto-update | Bloqueado org (falta Developer ID Application) — runbook pronto |
| **V10** | Theme app dark/light | Feito (2026-07-26) |
| **F15** | MySQL embutido (CLI + PTY) | Feito — cliente + bastion `:33306` + target `lab-mysql` (2026-07-26) |
| **F16–F17** | Oracle / HTTP embutidos | Parcial (iframe web/oracle) |
| **F20** | Multi-OS (Win/Linux) | Parcial (docs + CLI; desktop macOS first) |
| **V17** | Marca / packaging polish | Feito parcial (versão + IntegrAllTech na topbar) |

Smoke F4 E2E: `bash deploy/validation/smoke-f4-guac-ws.sh`

## Fora de escopo próximo

Vault local de senhas de alvo · FreeRDP nativo · VPN cliente no notebook · full SIEM.

## Tracking

| Data | Nota |
|------|------|
| 2026-07-25 | Roadmap criado; Onda 1 implementada (F1, F3, V1, V2, V8, V12) |
| 2026-07-26 | Onda 2 parcial: favoritos, grupos, ⌘K, copiar, chrome sessão |
| 2026-07-26 | Onda 2: F4 token Guac, F13 notify, V11 fullscreen; redeploy console + oauth2-proxy skip `/websocket-tunnel` |
| 2026-07-26 | Smoke F4 Hostinger: mint PASS + WS Traefik h1 PASS — evidence `smoke-f4-guac-token-2026-07-26.md` |
| 2026-07-26 | Onda 3 start: V10 theme; smoke-f4-guac-ws.sh; F5 ainda bloqueado sem Developer ID |
| 2026-07-26 | F15 MySQL embutido (CLI/JSON/PTY) + V17 marca; runbook warpgate-mysql-bastion.md |
| 2026-07-26 | F15 bastion: WG mysql.enable + UFW 33306 + lab-mysql + catalog protocol fix |
