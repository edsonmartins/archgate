# Proposal — ArchGate Connect (cliente operador desktop + CLI)

## Why

O bastion e os connectors no VPS resolvem o alcance até as redes dos clientes. O notebook do dev ainda opera com fricção (snippets manuais) ou regride ao anti-padrão (VPN do cliente + IP direto).

Falta o **endpoint agent do operador**: login ArchGate, catálogo autorizado, materialização de acesso (SSH config, spawn, deep links) — sem VPN L3 do cliente no laptop.

## What Changes

- Capability **`operator-desktop-connect`**
- CLI **`archgate`** (Go) + tray **ArchGate Connect** (Tauri)
- BFF: bootstrap de endpoints do bastion para o cliente
- ADR-008A (emenda ADR-008 P3)
- Runbook de migração a partir de `conecta_rq` / OpenVPN Connect

## Impact

| Item | Efeito |
|------|--------|
| **ADRs** | [ADR-008A](../../../adr/ADR-008A-archgate-connect-cliente-operador.md) |
| **Repos** | `clients/archgate-connect/` |
| **BFF** | archguard `unified/v1/operator/bootstrap` |
| **Não muda** | Connectors site (ADR-010); engines Warpgate/Guac |
| **Fora** | VPN L3 no notebook; Oracle local 1521; NetBird no dev |

## Success metrics

1. Dev macOS opera targets autorizados sem Forti/OpenVPN do cliente.
2. Catálogo filtrado por identidade/tenant.
3. Sessões SSH/DB auditáveis no bastion.
4. Offboarding por Kanidm invalida o Connect.
